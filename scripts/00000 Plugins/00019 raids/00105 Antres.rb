# Raids : antres de raid sur les cartes
#
# Un évènement dont le nom contient « antre_raid » (ou « raid_den ») est un antre : il prend l'apparence de l'antre du
# style (« antre_raid_ultra », « antre_raid_max », « antre_raid_tera » ; basique sinon) et affiche s'il est vide, s'il
# abrite un Pokémon ou un Pokémon rare. Sa page lance la commande de script « antre_raid » (options : voir 00110).
# Chaque antre garde son Pokémon jusqu'à ce qu'il soit vaincu ; tous les antres se remplissent chaque jour
# (den_daily_reset). Un Appât Raid (bait_item) jeté dans un antre vide y attire un nouveau Pokémon.
module Raids
  DEN_TAGS = /antre[_ ]raid|raid[_ ]den/i.freeze
  # Ligne du charset de l'antre : vide, Pokémon, Pokémon rare, pas encore tiré
  DEN_DIRECTIONS = { empty: 2, ready: 4, rare: 6, unknown: 8 }.freeze

  module_function

  # --- État des antres ------------------------------------------------------------------------------------------------
  # @return [Hash]
  def dens
    state = PFM.game_state
    store = state.instance_variable_get(:@pj_raid_dens) || state.instance_variable_set(:@pj_raid_dens, {})
    today = Time.now.strftime('%Y%m%d')
    if setting('den_daily_reset') && store[:day] != today
      store.delete_if { |key, data| key != :day && data.is_a?(Hash) && data[:state] == :empty }
      store[:day] = today
    end
    return store
  end

  def den_key(map_id, event_id)
    return "#{map_id}_#{event_id}"
  end

  # @param name [String] nom de l'évènement
  # @return [Symbol, nil] style de l'antre (nil : pas un antre)
  def den_style(name)
    return nil unless name.to_s =~ DEN_TAGS

    STYLES.each { |style| return style if style != :basic && name =~ /(antre[_ ]raid|raid[_ ]den)[_ ]#{style}/i }
    return :basic
  end

  # @return [Hash, nil] Pokémon de l'antre ({ state:, species:, form:, level:, rank:, style:, gmax:, tera_type: })
  def den_data(map_id, event_id)
    return dens[den_key(map_id, event_id)]
  end

  # Tire le Pokémon d'un antre
  # @param options [Hash] style:, pokemon: (espèce ou filtre), rang:
  def roll_den(map_id, event_id, style, options = {})
    rules = Rules.new(style: style, rank: options[:rank])
    rules.rank ||= random_rank
    filter = options[:pokemon]
    entry = choose_entry(rules, filter)
    data = {
      state: :ready, species: entry[:species], form: entry[:form], gmax: entry[:gmax], rank: rules.rank, style: rules.style,
      level: options[:level] || level_for_rank(rules.rank)
    }
    data[:tera_type] = options[:tera_type] || random_tera_type(PFM::Pokemon.new(entry[:species], 5, false, false, entry[:form])) if rules.style == :tera
    data[:state] = :rare if rules.rank >= 5 || boss_species?(entry[:species], rules.style)
    dens[den_key(map_id, event_id)] = data
    refresh_den_event(map_id, event_id)
    return data
  end

  def empty_den(map_id, event_id)
    dens[den_key(map_id, event_id)] = { state: :empty }
    refresh_den_event(map_id, event_id)
  end

  def refresh_den_event(map_id, event_id)
    return unless $game_map && $game_map.map_id == map_id

    $game_map.events[event_id]&.pj_raid_den_refresh
  end

  # Boss d'un antre (Pokémon tiré)
  # @return [Rules]
  def den_rules(data, options = {})
    rules = Rules.new(style: data[:style], rank: data[:rank], tera_type: data[:tera_type], den: true, size: options[:size],
                      turns: options[:turns], kos: options[:kos])
    boss = PFM::Pokemon.new(data[:species], data[:level], false, false, data[:form].to_i)
    boss.pj_gmax_factor = true if data[:gmax] && boss.respond_to?(:pj_gmax_factor=)
    make_boss(boss, rules)
    return rules
  end

  # --- Interaction --------------------------------------------------------------------------------------------------------
  # @param interpreter [Interpreter]
  # @param event_id [Integer]
  # @param options [Hash]
  def den_interaction(interpreter, event_id, options = {})
    map_id = $game_map.map_id
    event = $game_map.events[event_id]
    style = normalize_style(options[:style] || den_style(event&.event&.name) || :basic)
    style = :basic unless style_available?(style)
    data = den_data(map_id, event_id)
    den_name = style_text(style, 'den')
    if data.nil? || data[:state].nil?
      data = roll_den(map_id, event_id, style, options)
    elsif data[:state] == :empty
      return unless bait_den(interpreter, map_id, event_id, style, options)

      data = den_data(map_id, event_id)
    end
    interpreter.message(format(t('Vous regardez dans l’%s…', 'You peered into the %s...'), den_name))
    if $actors.none? { |pokemon| !pokemon.dead? }
      interpreter.message(t('Vos Pokémon ne sont pas en état de se battre.', 'Your Pokémon are in no condition to battle.'))
      return
    end
    rules = den_rules(data, options)
    choice = nil
    $scene.call_scene(DenScene, rules) { |scene| choice = scene.choice }
    return unless choice == :battle

    play_transition(rules)
    start_battle(rules) do |outcome, battle_scene|
      next unless %i[win caught].include?(outcome)

      empty_den(map_id, event_id)
      stats[:dens] += 1
      next unless setting('den_rewards')

      rewards = generate_rewards(rules)
      rewards.each { |item, count| $bag.add_item(item, count) }
      battle_scene.call_scene(RewardsScene, rules, rewards, outcome)
    end
    interpreter.instance_variable_set(:@wait_count, 2)
  end

  # Antre vide : proposer un Appât Raid
  # @return [Boolean] un Pokémon est apparu
  def bait_den(interpreter, map_id, event_id, style, options)
    interpreter.message(t('Il n’y a rien ici, on dirait…', 'There doesn’t seem to be anything here...'))
    bait = setting('bait_item').to_s
    return false if bait.empty? || !item_exists?(bait)

    name = item_name(bait)
    return false unless interpreter.yes_no_choice(format(t('Jeter un %s pour attirer un Pokémon ?', 'Want to throw in a %s to lure a Pokémon?'), name))

    unless $bag.contain_item?(bait.to_sym)
      interpreter.message(format(t('Mais vous n’avez pas de %s…', 'But you don’t have any %s...'), name))
      return false
    end
    $bag.remove_item(bait.to_sym, 1)
    interpreter.message(format(t('Vous jetez un %s dans l’antre !', 'You tossed in a %s!'), name))
    roll_den(map_id, event_id, style, options)
    return true
  end

  # Transition avant le combat (fond et emblème du style)
  # @param rules [Rules]
  def play_transition(rules)
    viewport = Viewport.create(:main, 60_000)
    bg = Sprite.new(viewport)
    bg.bitmap = RPG::Cache.interface(file("transitions/#{rules.style}_bg"))
    icon = Sprite.new(viewport)
    icon.bitmap = RPG::Cache.interface(file("transitions/#{rules.style}_icon"))
    icon.set_origin(160, 120)
    icon.set_position(160, 120)
    bg.opacity = icon.opacity = 0
    Audio.se_play('audio/se/raid_transition') rescue nil
    50.times do |i|
      bg.opacity = [i * 16, 255].min
      icon.opacity = i < 12 ? 0 : [(i - 12) * 20, 255].min
      zoom = i < 12 ? 2.0 : [2.0 - (i - 12) * 0.08, 1.0].max
      icon.zoom = zoom
      Graphics.update
    end
    20.times { Graphics.update }
  rescue StandardError => e
    log_error("Raids : transition #{e.message}") if respond_to?(:log_error, true)
  ensure
    viewport&.dispose
  end

  # --- Écran de l'antre ----------------------------------------------------------------------------------------------------
  class DenScene < GamePlay::BaseCleanUpdate
    WHITE = 10
    # @return [Symbol, nil] :battle ou nil
    attr_reader :choice

    # @param rules [Rules]
    def initialize(rules)
      super()
      @rules = rules
      @boss = rules.pokemon
      @index = 0
      @choice = nil
    end

    def update_inputs
      if Input.trigger?(:LEFT) || Input.trigger?(:RIGHT)
        @index = 1 - @index
        play_cursor_se
        refresh_buttons
      elsif Input.trigger?(:A)
        play_decision_se
        @choice = @index.zero? ? :battle : nil
        @running = false
      elsif Input.trigger?(:B)
        play_cancel_se
        @running = false
      end
      return true
    end

    def update_graphics
      @face&.update
      return true
    end

    private

    def create_graphics
      super
      style = @rules.style
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_background(Raids.file("den/bg_#{style}"))
      @stack.add_text(8, 3, 130, 16, Raids.style_text(style, 'den'), color: WHITE)
      create_stars
      @face = @stack.push(80, 176, nil, type: UI::PokemonFaceSprite)
      @face.data = @boss
      create_infos
      create_party
      @buttons = [[14, Raids.t('Combattre', 'Begin Raid')], [162, Raids.t('Partir', 'Leave Raid')]].map do |x, text|
        button = @stack.add_sprite(x, 202, Raids.file('den/buttons'))
        button.src_rect.set(0, 0, 146, 22)
        [button, @stack.add_text(x, 204, 146, 16, text, 1, color: WHITE)]
      end
      refresh_buttons
    end

    def create_stars
      7.times do |i|
        star = @stack.add_sprite(12 + i * 14, 34, Raids.file('star'))
        star.src_rect.set(0, i < @rules.rank ? 0 : 12, 12, 12)
        star.visible = i < [@rules.rank, 5].max
      end
    end

    def create_infos
      x = 166
      @stack.add_text(x, 32, 146, 16, @boss.name, color: WHITE)
      @stack.add_text(x, 32, 142, 16, format(Raids.t('Niv. %d', 'Lv. %d'), @boss.level), 2, color: WHITE)
      types = [@boss.type1, @boss.type2].reject(&:zero?)
      types.each_with_index do |type, i|
        sprite = @stack.push(x + i * 52, 52, nil, type: UI::TypeSprite)
        sprite.data = Struct.new(:type).new(type)
      end
      @stack.add_text(x, 72, 146, 16, style_line, color: WHITE)
      @stack.add_text(x, 90, 146, 16, format(Raids.t('Tours : %d   K.O. : %d', 'Turns: %d   KOs: %d'), @rules.turn_count, @rules.ko_count), color: WHITE)
      shield = @rules.shield_hp.to_i
      text = shield > 0 ? format(Raids.t('Bouclier : %d barres', 'Shield: %d bars'), shield) : Raids.t('Pas de bouclier', 'No shield')
      @stack.add_text(x, 106, 146, 16, text, color: WHITE)
      actions = Array(@rules.extra_actions).size
      @stack.add_text(x, 122, 146, 16, format(Raids.t('Actions en plus : %d', 'Extra actions: %d'), actions), color: WHITE) if actions > 0
    end

    def style_line
      case @rules.style
      when :tera
        type = data_type(@rules.tera_type || :normal)
        return format(Raids.t('Type Téra : %s', 'Tera Type: %s'), type.name)
      when :ultra
        item = @boss.item_holding.to_i > 0 ? data_item(@boss.item_holding).name : '—'
        return format(Raids.t('Cristal Z : %s', 'Z-Crystal: %s'), item)
      when :max
        return @boss.respond_to?(:pj_gmax_factor) && @boss.pj_gmax_factor ? Raids.t('Gigamax !', 'Gigantamax!') : Raids.t('Dynamax', 'Dynamax')
      end
      return Raids.style_text(@rules.style, 'name')
    end

    def create_party
      team = Raids.participants(@rules.size)
      @rules.size.times do |i|
        @stack.add_sprite(166 + i * 36, 151, Raids.file("den/slot_#{@rules.style}"))
        next unless team[i]

        icon = @stack.push(181 + i * 36, 166, nil, type: UI::PokemonIconSprite)
        icon.data = team[i]
      end
      @stack.add_text(166, 168, 146, 16, '', color: WHITE)
    end

    def refresh_buttons
      @buttons.each_with_index { |(button, _text), i| button.src_rect.y = i == @index ? 22 : 0 }
    end
  end

  # --- Récompenses ----------------------------------------------------------------------------------------------------------
  # @param rules [Rules]
  # @return [Hash{Symbol => Integer}]
  def generate_rewards(rules)
    rank = rules.rank.to_i.clamp(1, 7)
    qty = (rank * 1.5).round
    out = Hash.new(0)
    add = ->(item, count) { out[item.to_sym] += count.to_i if count.to_i > 0 && item_exists?(item) }
    candies = %i[exp_candy_xl exp_candy_l exp_candy_m exp_candy_s exp_candy_xs]
    candies.each_with_index do |candy, i|
      case candy
      when :exp_candy_xs then next if rank > 5 || (rank == 5 && rand(10) < 4)
      when :exp_candy_s then next if rank > 5 && rand(10) < 2
      when :exp_candy_m then next if rank < 3
      when :exp_candy_l then next if rank < 4 || (rank == 4 && rand(10) > 2)
      when :exp_candy_xl then next if rank < 5 || (rank == 5 && rand(10) > 2)
      end
      add.call(candy, (i.zero? ? qty / 2 : qty * i) + rand(3))
    end
    add.call(:rare_candy, qty + rand(-1..2)) if rank >= 3
    boss = rules.pokemon
    case rules.style
    when :max
      add.call(:dynamax_candy, qty + rand(-1..2)) if rank > 2
      add.call(:max_soup, 1) if boss.respond_to?(:pj_gmax_factor) && boss.pj_gmax_factor && rand(2).zero?
      add.call(:max_honey, 1) if boss.db_symbol == :vespiquen
      add.call(:max_mushrooms, 1) if %i[parasect breloom amoonguss shiinotic toedscruel].include?(boss.db_symbol)
      add.call(:wishing_star, 1) if boss.db_symbol == :eternatus
    when :tera
      add.call(:"#{rules.tera_type}_tera_shard", qty + rand(-1..2)) if rules.tera_type
    when :ultra
      add.call(:z_booster, 1) if boss.db_symbol == :necrozma
    end
    if rank >= 3 && (machine = machine_for(rules))
      add.call(machine, 1)
    end
    add.call(%i[health_feather muscle_feather resist_feather genius_feather clever_feather swift_feather].sample, [1, qty / 2 + rand(-1..2)].max)
    add.call(%i[hp_up protein iron calcium zinc carbos].sample, [1, qty / (rank > 5 ? 2 : 4) + rand(-1..2)].max) if rank >= 3
    add.call(%i[pomeg_berry kelpsy_berry qualot_berry hondew_berry grepa_berry tomato_berry].sample, [1, qty / 2 + rand(-1..2)].max)
    if rank >= 4
      add.call(%i[serious_mint lonely_mint adamant_mint naughty_mint brave_mint bold_mint impish_mint lax_mint relaxed_mint
                  modest_mint mild_mint rash_mint quiet_mint calm_mint gentle_mint careful_mint sassy_mint timid_mint hasty_mint
                  jolly_mint naive_mint].sample, 1)
    end
    add.call(%i[pp_up pp_max ability_capsule ability_patch bottle_cap gold_bottle_cap].sample, 1) if rank >= 3 && rand(10) <= 2
    if rank >= 3 && rand(10) <= 1
      list = case rank
             when 3 then %i[tiny_mushroom nugget pearl relic_copper relic_vase]
             when 4, 5 then %i[big_mushroom big_nugget big_pearl relic_silver relic_band]
             else %i[balm_mushroom pearl_string relic_gold relic_statue relic_crown]
             end
      add.call(list.sample, 1)
    end
    if rand(6) < rank
      balls = %i[poke_ball great_ball ultra_ball dusk_ball quick_ball net_ball dive_ball nest_ball repeat_ball timer_ball luxury_ball heal_ball]
      balls << :beast_ball if rules.style == :ultra
      balls += %i[dream_ball fast_ball level_ball lure_ball heavy_ball love_ball friend_ball moon_ball] if rank >= 5
      add.call(balls.sample, 1)
    end
    Array(config.rewards).each do |entry|
      next if fetch(entry, 'rank').to_i > rank
      next if (style = fetch(entry, 'style')) && !style.to_s.empty? && style.to_s != rules.style.to_s
      next if rand(100) >= (fetch(entry, 'chance') || 100).to_i

      low = (fetch(entry, 'min') || 1).to_i
      high = [(fetch(entry, 'max') || low).to_i, low].max
      add.call(fetch(entry, 'item'), rand(low..high))
    end
    Array(rules.loot).each { |item, count| add.call(item, count || 1) }
    return out
  end

  # CT (ou DT) d'une attaque d'un type du boss
  def machine_for(rules)
    types = rules.style == :tera && rules.tera_type ? [rules.tera_type.to_sym] : creature_types(rules.pokemon.db_symbol, rules.pokemon.form)
    @machines ||= begin
      list = []
      each_data_item do |item|
        next unless item.is_a?(Studio::TechItem)

        move = data_move(item.move) rescue nil
        list << [item.db_symbol, move.type.to_sym, item.db_symbol.to_s.start_with?('tr')] if move && move.db_symbol != :__undef__
      end
      list
    end
    pool = @machines.select { |_item, type, record| types.include?(type) && record }
    pool = @machines.select { |_item, type, _record| types.include?(type) } if pool.empty?
    return pool.sample&.first
  end

  class RewardsScene < GamePlay::BaseCleanUpdate
    WHITE = 10
    ROWS = 7

    # @param rules [Rules]
    # @param rewards [Hash{Symbol => Integer}]
    # @param outcome [Symbol] :win, :caught
    def initialize(rules, rewards, outcome)
      super()
      @rules = rules
      @rewards = rewards.to_a
      @outcome = outcome
      @top = 0
    end

    def update_inputs
      if Input.trigger?(:DOWN) && @top + ROWS < @rewards.size
        @top += 1
        refresh
      elsif Input.trigger?(:UP) && @top > 0
        @top -= 1
        refresh
      elsif Input.trigger?(:A) || Input.trigger?(:B)
        play_decision_se
        @running = false
      end
      return true
    end

    def update_graphics
      @face&.update
      return true
    end

    private

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_background(Raids.file("den/rewards_#{@rules.style}"))
      @stack.add_text(8, 3, 170, 16, Raids.t('Récompenses', 'Raid Rewards'), color: WHITE)
      @face = @stack.push(71, 150, nil, type: UI::PokemonFaceSprite)
      @face.data = @rules.pokemon
      result = @outcome == :caught ? Raids.t('Capturé !', 'Caught!') : Raids.t('Vaincu !', 'Defeated!')
      @stack.add_text(12, 154, 120, 16, @rules.pokemon.name, 1, color: WHITE)
      @stack.add_text(12, 168, 120, 16, format('%s  %s', result, '★' * @rules.rank.to_i), 1, color: WHITE)
      @rows = Array.new(ROWS) do |i|
        y = 34 + i * 21
        row = @stack.add_sprite(142, y, Raids.file('den/row'))
        row.src_rect.set(0, 0, 168, 18)
        icon = @stack.push(146, y - 7, nil, type: UI::ItemSprite)
        name = @stack.add_text(178, y, 100, 16, '', color: WHITE)
        count = @stack.add_text(270, y, 36, 16, '', 2, color: WHITE)
        [row, icon, name, count]
      end
      text = @rewards.empty? ? Raids.t('Pas de récompense.', 'No rewards earned.') : Raids.t('Les objets ont été mis dans le Sac.', 'The items were put in the Bag.')
      @stack.add_text(14, 196, 292, 16, text, color: WHITE)
      @stack.add_text(14, 214, 292, 16, @rewards.size > ROWS ? Raids.t('Haut / Bas : voir la suite   A : continuer', 'Up / Down: more   A: continue') : Raids.t('A : continuer', 'A: continue'), color: WHITE)
      refresh
    end

    def refresh
      @rows.each_with_index do |(row, icon, name, count), i|
        item, qty = @rewards[@top + i]
        row.visible = icon.visible = name.visible = count.visible = !item.nil?
        next unless item

        icon.data = item
        name.text = Raids.item_name(item)
        count.text = "x#{qty}"
      end
    end
  end
end

class Game_Event
  # Antre de raid : apparence selon son état
  def pj_raid_den_refresh
    style = Raids.den_style(@event&.name)
    return unless style

    data = Raids.den_data($game_map.map_id, @id)
    state = data.nil? ? :unknown : (data[:state] || :unknown)
    @character_name = Raids.fetch(Raids.style_data(style), 'charset').to_s
    @direction = Raids::DEN_DIRECTIONS[state] || 2
    @step_anime = state != :empty
    @direction_fix = true
    @pattern = 0 unless @step_anime
  rescue StandardError => e
    log_error("Raids : antre #{e.message}") if respond_to?(:log_error, true)
  end

  module RaidsDen
    private

    def refresh_page(new_page)
      result = super
      pj_raid_den_refresh if new_page
      return result
    end
  end
  prepend RaidsDen
end

# Raids : Pokémon des raids (espèces par rang et par style), création du boss et des Pokémon de location, attaques
# de raid (choisies dans les capacités de la famille, comme le plugin d'origine)
module Raids
  # Attaques jamais choisies (changement, K.O. en un coup, attaques en deux tours, recharge…)
  BANNED_METHODS = %w[s_pursuit s_u_turn s_thief s_poltergeist s_fake_out s_reload s_dragon_tail s_explosion s_ohko
                      s_2turns s_dream_eater s_hidden_power s_last_resort s_sky_drop s_upper_hand s_last_respects
                      s_tera_blast s_steel_beam s_misty_explosion s_self_destruct s_memento s_final_gambit
                      s_solar_beam s_future_sight s_focus_punch].freeze
  BANNED_MOVES = %i[overheat draco_meteor leaf_storm psycho_boost fleur_cannon misty_explosion steel_beam struggle].freeze
  # Interdites aux Pokémon de location seulement
  RENTAL_BANNED = %i[shadow_force phantom_force knock_off belch eerie_spell].freeze
  MULTI_HIT = { 's_multi_hit' => 25, 's_scale_shot' => 25, 's_triple_kick' => 25, 's_population_bomb' => 20,
                's_2hits' => 35, 's_dragon_darts' => 35, 's_3hits' => 25 }.freeze
  SPREAD_TARGETS = %w[adjacent_all_foe all_foe adjacent_all_pokemon].freeze
  # Attaques propres à une espèce (toujours dans le choix)
  SIGNATURE = {
    tauros: { signature: :raging_bull }, castform: { signature: :weather_ball }, arceus: { signature: :judgment },
    aegislash: { signature: :king_s_shield }, oricorio: { signature: :revelation_dance }, silvally: { signature: :multi_attack },
    morpeko: { signature: :aura_wheel }, zacian: { signature: :iron_head }, zamazenta: { signature: :iron_head },
    ogerpon: { signature: :ivy_cudgel }, terapagos: { signature: :tera_starstorm }, wobbuffet: { primary: :counter },
    slaking: { primary: :giga_impact }, kleavor: { secondary: :stone_axe }, meowscarada: { secondary: :flower_trick },
    garganacl: { secondary: :salt_cure }, annihilape: { secondary: :rage_fist }, greninja: { secondary: :water_shuriken },
    dragapult: { spread: :dragon_darts }
  }.freeze

  module_function

  # --- Espèces -------------------------------------------------------------------------------------------------
  # @return [Array<Hash>] entrées valides (Pokémon présents dans Studio)
  def species_entries
    @species_cache ||= Array(config.species).filter_map do |entry|
      species = fetch(entry, 'pokemon').to_s.to_sym
      next unless creature_exists?(species)

      {
        species: species, form: fetch(entry, 'form').to_i, ranks: Array(fetch(entry, 'ranks')).map(&:to_i),
        styles: Array(fetch(entry, 'styles')).map { |s| s.to_s.downcase.to_sym }, gmax: fetch(entry, 'gmax') ? true : false
      }
    end
  end

  # @param entry [Hash]
  # @param style [Symbol]
  # @return [Boolean]
  def entry_for_style?(entry, style)
    return false if entry[:ranks].empty?
    return false if !entry[:styles].empty? && !entry[:styles].include?(style)
    return false if entry[:gmax] && style != :max
    return false if style == :max && gimmick_blocked?(entry[:species], 'no_dynamax')
    return false if style == :tera && gimmick_blocked?(entry[:species], 'no_tera')

    return true
  end

  def gimmick_blocked?(species, key)
    return false unless defined?(::Gimmicks) && ::Gimmicks.respond_to?(:species_config)

    return ::Gimmicks.species_config(species)[key] ? true : false
  rescue StandardError
    return false
  end

  # @param style [Symbol]
  # @param rank [Integer]
  # @param filter [Hash] type:, generation: (n° de Studio), species: [liste]
  # @param boss_filter [Boolean] boss des aventures (légendaires…)
  # @return [Array<Hash>]
  def pool(style, rank, filter = {}, boss_filter: false)
    list = species_entries.select { |e| entry_for_style?(e, style) && (rank == 7 || e[:ranks].include?(rank)) }
    if (type = filter[:type])
      type = type.to_sym
      list.select! { |e| creature_types(e[:species], e[:form]).include?(type) }
    end
    list.select! { |e| Array(filter[:species]).map(&:to_sym).include?(e[:species]) } if filter[:species]
    list.select! { |e| boss_species?(e[:species], style) } if boss_filter && rank >= 6
    return list
  end

  # Boss des aventures (rang 6) : Pokémon rares (taux de capture très bas : légendaires, Ultra-Chimères…)
  def boss_species?(species, _style)
    return data_creature(species).forms.first.catch_rate.to_i <= 10
  rescue StandardError
    return true
  end

  def creature_types(species, form = 0)
    data = data_creature_form(species, form)
    return [data.type1, data.type2].compact.map(&:to_sym).reject { |t| t == :__undef__ }
  rescue StandardError
    return []
  end

  # --- Rang et niveau ---------------------------------------------------------------------------------------------
  # Rang au hasard selon les badges (comme le plugin d'origine)
  def random_rank
    return [1, 2, 3].sample unless setting('badge_ranks')

    odds = rand(100)
    count = badges
    return odds < 40 ? 3 : [4, 5].sample if count >= 8
    return odds < 40 ? [1, 2].sample : [3, 4].sample if count >= 6
    return odds < 40 ? 2 : [1, 3].sample if count >= 3

    return odds < 80 ? 1 : 2
  end

  def level_for_rank(rank)
    return 100 if rank >= 7

    rank = [rank, 1].max
    level = rank * 10 + rand(6)
    level += 15 if rank > 4
    return level.clamp(1, 100)
  end

  def rank_for_level(level)
    return 1 if level < 20
    return 2 if level < 30
    return 3 if level < 40
    return 4 if level < 50
    return 5 if level < 70
    return 6 if level < 100

    return 7
  end

  # PV du boss (multiplicateur des PV max) selon le rang
  def hp_multiplier(rank, level, style)
    boost = { 1 => 4, 2 => 6, 3 => 8, 4 => 12, 5 => 20, 6 => 24, 7 => 30 }[rank.clamp(1, 7)]
    boost -= ((100 - level) / 10) - 1
    boost /= 2 if style == :max
    return [boost, 2].max
  end

  # --- Attaques de raid ------------------------------------------------------------------------------------------
  # Capacités de la famille (pré-évolution, bébé, l'espèce : niveau, maîtres, CT, œufs)
  def family_moves(species, form = 0)
    moves = []
    chain = [[species, form]]
    data = data_creature_form(species, form)
    chain << [data.baby_db_symbol, data.baby_form.to_i] if data.respond_to?(:baby_db_symbol) && data.baby_db_symbol
    prev = previous_species(species)
    chain << prev if prev
    chain.uniq.each do |sp, fm|
      next unless creature_exists?(sp)

      Array(data_creature_form(sp, fm).move_set).each { |m| moves << m.move.to_sym }
    end
    return moves.uniq
  rescue StandardError
    return []
  end

  # @return [Array(Symbol, Integer), nil] espèce dont celle-ci évolue
  def previous_species(species)
    @previous ||= begin
      map = {}
      each_data_creature do |creature|
        Array(creature.forms).each do |form|
          Array(form.evolutions).each do |evo|
            target = evo.db_symbol
            map[target.to_sym] ||= [creature.db_symbol, form.form] if target
          end
        end
      end
      map
    end
    return @previous[species.to_sym]
  end

  # @param species [Symbol]
  # @param form [Integer]
  # @param style [Symbol]
  # @param rental [Boolean]
  # @param criteria [Symbol, nil] type Téra (style tera) ou attaque Z de base (style ultra)
  # @return [Hash{Symbol => Array<Symbol>}] :signature :primary :secondary :other :spread
  def compile_moves(species, form, style, rental: false, criteria: nil, category: nil)
    data = data_creature_form(species, form)
    types = [data.type1, data.type2].compact.map(&:to_sym)
    category ||= data.base_atk > data.base_ats + 25 ? :physical : (data.base_ats > data.base_atk + 25 ? :special : nil)
    sig = SIGNATURE[species.to_sym] || {}
    pool = Hash.new { |h, k| h[k] = [] }
    family_moves(species, form).each do |sym|
      next if sig.values.include?(sym)

      move = data_move(sym)
      next if move.db_symbol == :__undef__ || move.category.to_s == 'status'
      next if BANNED_METHODS.include?(move.battle_engine_method.to_s) || BANNED_MOVES.include?(sym)
      next if rental && RENTAL_BANNED.include?(sym)
      next if move.accuracy.to_i.between?(1, 60)
      next if category && move.category.to_sym != category && !%i[body_press shell_side_arm photon_geyser].include?(sym)

      target = move.battle_engine_aimed_target.to_s
      if SPREAD_TARGETS.include?(target) && !rental
        pool[:spread] << sym if move.power.to_i >= 50
        next
      end
      next if target == 'adjacent_all_pokemon'

      if (min = MULTI_HIT[move.battle_engine_method.to_s])
        next if move.power.to_i < min
      elsif move.priority.to_i > 0
        next if move.power.to_i < 40
      elsif move.power.to_i < 55
        next
      end
      type = move.type.to_sym
      if style == :tera && criteria && criteria.to_sym == type
        pool[:primary] << sym
      elsif types.include?(type)
        key = move.power.to_i < 80 ? :secondary : :primary
        key = (key == :primary ? :secondary : :other) if style == :tera
        pool[key] << sym
      elsif type != :normal || move.priority.to_i > 0
        pool[:other] << sym
      end
    end
    sig.each { |key, sym| pool[key] << sym if data_move(sym).db_symbol != :__undef__ && !pool[key].include?(sym) }
    return pool
  end

  # Choisit 4 attaques dans les groupes (signature d'abord, puis un peu de chaque groupe)
  # @return [Array<Symbol>]
  def pick_moves(pool)
    pool = pool.transform_values(&:dup)
    chosen = []
    chosen << pool.delete(:signature).first if pool[:signature]&.any?
    keys = (pool.keys - %i[spread signature]).shuffle
    until chosen.size >= 4 || keys.empty?
      keys.dup.each do |key|
        list = pool[key]
        if list.empty?
          keys.delete(key)
          next
        end
        move = list.delete(list.sample)
        chosen << move unless chosen.include?(move)
        break if chosen.size >= 4
      end
    end
    return chosen.compact
  end

  # @param pokemon [PFM::Pokemon]
  # @param moves [Array<Symbol>]
  def set_moves(pokemon, moves)
    return if moves.empty?

    pokemon.skills_set.clear
    moves.first(4).each { |sym| pokemon.skills_set << PFM::Skill.new(sym) }
  end

  # --- Boss ------------------------------------------------------------------------------------------------------
  # Données d'un raid (comme les « rules » du plugin d'origine)
  class Rules
    attr_accessor :style, :rank, :size, :turn_count, :ko_count, :shield_hp, :extra_actions, :spread_moves, :loot,
                  :pokemon, :partner, :den, :adventure, :max_turns, :max_kos, :cheers, :tera_type, :environment, :background
    # Pendant le combat : bouclier (barres restantes, déjà levé), encouragement, issue, appel de fin
    attr_accessor :shield, :shield_started, :cheer_level, :cheer_used, :cheer_offense3, :cheer_defense3,
                  :cheer_turns, :gimmick_unlocked, :outcome, :after, :capture, :final_boss

    # @param options [Hash]
    def initialize(options = {})
      @style = Raids.normalize_style(options[:style])
      @style = :basic unless Raids.style_available?(@style)
      @rank = options[:rank]
      @size = options[:size]
      @turn_count = options[:turns] || options[:turn_count]
      @ko_count = options[:kos] || options[:ko_count]
      @shield_hp = options.key?(:shield) ? options[:shield] : options[:shield_hp]
      @extra_actions = options[:extra_actions]
      @spread_moves = options[:spread_moves]
      @loot = options[:loot]
      @partner = options[:partner]
      @den = options[:den]
      @adventure = options[:adventure]
      @cheers = options.key?(:cheers) ? options[:cheers] : Raids.setting('cheers')
      @tera_type = options[:tera_type]
      @environment = options[:environment]
      @background = options[:background]
      @capture = options.key?(:capture) ? options[:capture] : true
      @final_boss = options[:final_boss]
      @cheer_turns = {}
    end

    # Remplit ce qui n'a pas été donné (comme Raid Values du plugin d'origine)
    def complete
      @rank = (@rank || Raids.random_rank).to_i.clamp(1, 7)
      party = @partner ? 1 : (@size || Raids.setting('party_size')).to_i.clamp(1, 3)
      @size = party
      players = @partner ? 2 : party
      if @ko_count.nil?
        @ko_count = players == 1 ? 1 : Raids.setting('knock_outs').to_i + (players == 2 ? 1 : 0) + (@rank > 5 ? 1 : 0)
      end
      if @turn_count.nil?
        @turn_count = Raids.setting('turn_limit').to_i + (players < 3 ? players : 0) + (@rank / 2.0).ceil
      end
      if @shield_hp.nil?
        @shield_hp = Raids.setting('shields') ? [@rank + 2 - [2, 1, 0][players - 1], 1].max.clamp(0, 8) : 0
      end
      if @extra_actions.nil?
        @extra_actions = []
        if Raids.setting('extra_actions')
          @extra_actions << :reset_drops if @rank >= 3
          @extra_actions << :reset_boosts if @rank >= 4
          @extra_actions << :drain_cheer if @rank >= 5
        end
      end
      @max_turns = @turn_count
      @max_kos = @ko_count
      @cheer_level ||= 0
      return self
    end
  end

  # Crée le boss d'un raid
  # @param rules [Rules]
  # @param species [Symbol, Hash, PFM::Pokemon, nil] espèce, filtre (type:, species:) ou Pokémon tout prêt
  # @return [PFM::Pokemon]
  def create_boss(rules, species = nil)
    rules.rank ||= species.is_a?(PFM::Pokemon) ? rank_for_level(species.level) : random_rank
    if species.is_a?(PFM::Pokemon)
      boss = species
    else
      entry = choose_entry(rules, species)
      level = level_for_rank(rules.rank)
      level = rules.adventure[:level] if rules.adventure && rules.adventure[:level]
      boss = PFM::Pokemon.new(entry[:species], level, false, false, entry[:form])
      boss.pj_gmax_factor = true if entry[:gmax] && boss.respond_to?(:pj_gmax_factor=)
    end
    boss.instance_variable_set(:@shiny, false) if rules.adventure
    make_boss(boss, rules)
    return boss
  end

  # @return [Hash] entrée d'espèce
  def choose_entry(rules, species)
    if species.is_a?(Symbol) || species.is_a?(String)
      sym = species.to_sym
      found = species_entries.select { |e| e[:species] == sym && entry_for_style?(e, rules.style) }
      entry = found.find { |e| e[:ranks].include?(rules.rank) } || found.first
      return entry || { species: sym, form: 0, ranks: [rules.rank], styles: [], gmax: false }
    end
    filter = species.is_a?(Hash) ? species : {}
    list = pool(rules.style, rules.rank, filter, boss_filter: rules.adventure && rules.rank >= 6)
    list = pool(rules.style, rules.rank) if list.empty?
    list = species_entries.select { |e| entry_for_style?(e, rules.style) } if list.empty?
    return list.sample || { species: :ditto, form: 0, ranks: [1], styles: [], gmax: false }
  end

  # Transforme un Pokémon en boss de raid (PV, IV, talent caché, attaques, Téra / cristal Z)
  def make_boss(boss, rules)
    rules.complete
    rank = rules.rank
    boss.pj_raid_hp_mult = hp_multiplier(rank, boss.level, rules.style)
    count = [1, rank - 1].max
    %i[iv_hp iv_atk iv_dfe iv_spd iv_ats iv_dfs].shuffle.first(count).each { |iv| boss.send(:"#{iv}=", 31) }
    set_hidden_ability(boss) if rank >= 3 && rand(10) < rank
    criteria = nil
    if rules.style == :tera
      type = rules.tera_type || random_tera_type(boss)
      boss.pj_tera_type = type if boss.respond_to?(:pj_tera_type=)
      criteria = type
    elsif rules.style == :ultra
      crystal = z_crystal_for(boss)
      boss.item_holding = data_item(crystal).id if crystal
    end
    pool = compile_moves(boss.db_symbol, boss.form, rules.style, criteria: criteria)
    moves = pick_moves(pool)
    set_moves(boss, moves) unless moves.empty?
    rules.spread_moves ||= pool[:spread].first(4)
    boss.hp = boss.max_hp
    boss.cure
    rules.pokemon = boss
  end

  def set_hidden_ability(pokemon)
    abilities = Array(pokemon.data.abilities)
    return if abilities.size < 3 || abilities[2].nil?

    pokemon.instance_variable_set(:@ability_index, 2)
    pokemon.instance_variable_set(:@ability, data_ability(abilities[2]).id)
  rescue StandardError
    nil
  end

  def random_tera_type(pokemon)
    types = []
    each_data_type { |type| types << type.db_symbol unless %i[__undef__ stellar shadow].include?(type.db_symbol) || type.id.zero? }
    return rand(3).zero? ? types.sample : (creature_types(pokemon.db_symbol, pokemon.form).sample || types.sample)
  rescue StandardError
    return :normal
  end

  # Cristal Z qui va avec le Pokémon (cristal exclusif, sinon celui d'un de ses types)
  def z_crystal_for(pokemon)
    return nil unless defined?(::Gimmicks::ZMove)

    found = ::Gimmicks::ZMove::EXCLUSIVE.find do |_crystal, (species, forms, base, _z, _power)|
      species.include?(pokemon.db_symbol) && (forms.nil? || forms.include?(pokemon.form)) &&
        pokemon.skills_set.any? { |skill| skill&.db_symbol == base }
    end
    return found[0] if found && item_exists?(found[0])

    types = creature_types(pokemon.db_symbol, pokemon.form)
    moves = pokemon.skills_set.compact.map { |skill| data_move(skill.db_symbol) }
    type = types.find { |t| moves.any? { |m| m.type.to_sym == t && m.power.to_i > 0 } } || types.first
    crystal = ::Gimmicks::ZMove::TYPES.find { |_c, (t, _z)| t == type }&.first
    return crystal && item_exists?(crystal) ? crystal : nil
  rescue StandardError
    return nil
  end

  # Pokémon capturé : redevient un Pokémon normal
  # @param pokemon [PFM::Pokemon]
  # @param rules [Rules]
  def reset_boss(pokemon, rules)
    pokemon.pj_raid_hp_mult = nil
    pokemon.item_holding = 0 if rules.style == :ultra && !rules.adventure
    if rules.style == :max && pokemon.respond_to?(:pj_dynamax_level=)
      pokemon.pj_dynamax_level = [rules.rank + rand(3), 10].min
    end
    pokemon.level = 75 if pokemon.level > 75 && !rules.adventure
    pokemon.hp = pokemon.max_hp
    pokemon.cure
  end

  # --- Locations (aventures) --------------------------------------------------------------------------------------
  # @param species [Symbol]
  # @param style [Symbol]
  # @param level [Integer]
  # @return [PFM::Pokemon]
  def create_rental(species, style, level, form = 0)
    pokemon = PFM::Pokemon.new(species, level, false, false, form)
    criteria = nil
    if style == :tera
      criteria = random_tera_type(pokemon)
      pokemon.pj_tera_type = criteria if pokemon.respond_to?(:pj_tera_type=)
    elsif style == :max && pokemon.respond_to?(:pj_dynamax_level=)
      pokemon.pj_dynamax_level = 5
    end
    moves = pick_moves(compile_moves(species, form, style, rental: true, criteria: criteria))
    set_moves(pokemon, moves) unless moves.empty?
    set_hidden_ability(pokemon) if rand(10) < 4
    set_rental_evs(pokemon)
    if style == :ultra
      crystal = z_crystal_for(pokemon)
      pokemon.item_holding = data_item(crystal).id if crystal
    end
    pokemon.hp = pokemon.max_hp
    return pokemon
  end

  # Répartition d'EV d'un Pokémon de location (PV au max et une autre stat)
  def set_rental_evs(pokemon)
    %i[ev_hp ev_atk ev_dfe ev_spd ev_ats ev_dfs].each { |ev| pokemon.send(:"#{ev}=", 0) }
    stats = %i[ev_dfe ev_dfs]
    stats << :ev_atk if pokemon.skills_set.any? { |s| s && data_move(s.db_symbol).category.to_s == 'physical' }
    stats << :ev_ats if pokemon.skills_set.any? { |s| s && data_move(s.db_symbol).category.to_s == 'special' }
    stats << :ev_spd if pokemon.data.base_spd > 60
    pokemon.ev_hp = 252
    pokemon.send(:"#{stats.sample}=", 252)
  rescue StandardError
    nil
  end
end

module PFM
  class Pokemon
    # @return [Integer, nil] multiplicateur des PV du boss de raid
    attr_accessor :pj_raid_hp_mult

    module RaidsBossHp
      def max_hp
        value = super
        return @pj_raid_hp_mult ? value * @pj_raid_hp_mult : value
      end
    end
    prepend RaidsBossHp

    # @return [Boolean] boss de raid
    def pj_raid_boss?
      return !@pj_raid_hp_mult.nil?
    end
  end
end

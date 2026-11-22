# encoding: utf-8
# Failles spatio-temporelles : apparition, zone temporaire, Pokémon rares et objets
module Failles
  EVENT_FAILLE = 'faille_spatiotemporelle'
  EVENT_POKEMON = 'faille_pokemon'
  EVENT_OBJET = 'faille_objet'

  module_function

  # @return [Hash] { 'steps' => pas depuis la dernière faille, 'next' => pas avant la prochaine, 'active' => zone ouverte,
  #   'left' => pas restants, 'map' => carte, 'life' => pas de vie de la faille visible }
  def state
    game = PFM.game_state
    data = game.instance_variable_get(:@pj_failles) || game.instance_variable_set(:@pj_failles, {})
    data['steps'] ||= 0
    data['next'] ||= next_gap
    return data
  end

  # Objets / Pokémon de la zone en cours (non sauvegardés : une sauvegarde rechargée referme la zone)
  def runtime
    return @runtime ||= { pokemon: {}, items: {} }
  end

  def next_gap
    base = [setting('appear_steps').to_i, 50].max
    return (base * (0.75 + rand * 0.5)).round
  end

  def active?
    return state['active'] == true
  end

  # --- Pas -----------------------------------------------------------------------------------------------------------
  def step
    return unless setting('enabled') && $game_map && PFM.game_state

    data = state
    if data['active']
      zone_step(data)
    else
      data['steps'] += 1
      faille_life(data)
      return if data['steps'] < data['next']

      data['steps'] = 0
      data['next'] = next_gap
      open_faille if rand(100) < setting('appear_chance').to_i
    end
  end

  def faille_life(data)
    return unless data['life']

    data['life'] -= 1
    return if data['life'] > 0

    data['life'] = nil
    erase_events(EVENT_FAILLE)
  end

  def zone_step(data)
    data['left'] -= 1
    banner(t('La faille se referme bientôt !', 'The rift is closing soon!')) if data['left'] == setting('warn_steps').to_i
    close_zone(true) if data['left'] <= 0 || $game_map.map_id != data['map']
  end

  # --- Faille visible ------------------------------------------------------------------------------------------------
  # @return [Boolean] une faille est apparue près du joueur
  def open_faille
    return false if active? || $game_map.nil? || !eligible?($game_map)

    erase_events(EVENT_FAILLE)
    spot = random_tile($game_map, near: true)
    return false unless spot

    add_event($game_map, EVENT_FAILLE, spot, setting('charset_faille').to_s, "faille_entrer", walk: true, fixed: true)
    state['life'] = setting('faille_lifetime').to_i
    banner(t('Une faille spatio-temporelle s’est ouverte !', 'A space-time rift has opened!'))
    return true
  rescue StandardError => e
    log_error("Failles : ouverture #{e.message}") if respond_to?(:log_error, true)
    return false
  end

  # Une carte accueille des failles si elle a des Pokémon sauvages (plugin Overworld Pokémon) ou, à défaut, toujours
  def eligible?(map)
    return true unless defined?(OverworldPokemon) && OverworldPokemon.respond_to?(:land_groups)

    return !OverworldPokemon.land_groups(OverworldPokemon.zone_of(map.map_id)).empty?
  rescue StandardError
    return true
  end

  # --- Zone temporaire -----------------------------------------------------------------------------------------------
  def enter
    return false if active?

    erase_events(EVENT_FAILLE)
    data = state
    data['life'] = nil
    data['active'] = true
    data['left'] = setting('duration_steps').to_i
    data['map'] = $game_map.map_id
    runtime[:pokemon].clear
    runtime[:items].clear
    spawn_pokemon($game_map)
    spawn_items($game_map)
    set_tone(Array(setting('tone')))
    banner(t("La zone distordue est ouverte : #{data['left']} pas !", "The distorted zone is open: #{data['left']} steps!"))
    return true
  rescue StandardError => e
    log_error("Failles : entrée #{e.message}") if respond_to?(:log_error, true)
    return false
  end

  # @param notify [Boolean]
  def close_zone(notify = false)
    data = state
    return unless data['active']

    data['active'] = false
    data['left'] = 0
    erase_events(EVENT_POKEMON)
    erase_events(EVENT_OBJET)
    runtime[:pokemon].clear
    runtime[:items].clear
    set_tone([0, 0, 0, 0])
    banner(t('La faille s’est refermée.', 'The rift has closed.')) if notify
  rescue StandardError => e
    log_error("Failles : fermeture #{e.message}") if respond_to?(:log_error, true)
  end

  def set_tone(values)
    red, green, blue, gray = values.map(&:to_i)
    $game_screen&.start_tone_change(Tone.new(red.to_i, green.to_i, blue.to_i, gray.to_i), 40)
  rescue StandardError
    nil
  end

  # --- Pokémon rares -------------------------------------------------------------------------------------------------
  # @return [Array<Array(Symbol, Integer)>] [espèce, forme] du type de la faille et des espèces ajoutées
  def species_pool
    @pool ||= begin
      list = []
      type = setting('type').to_s
      each_data_creature do |creature|
        creature.forms.each { |form| list << [creature.db_symbol, form.form] if form.type1.to_s == type.to_s || form.type2.to_s == type.to_s }
      end
      Array(config.species).each { |sym| list << [sym.to_sym, 0] unless list.any? { |(s, _)| s == sym.to_sym } }
      list.select { |(sym, form)| (data_creature_form(sym, form) rescue nil) }
    rescue StandardError => e
      log_error("Failles : liste des espèces #{e.message}") if respond_to?(:log_error, true)
      Array(config.species).map { |sym| [sym.to_sym, 0] }
    end
  end

  def reset_pool
    @pool = nil
  end

  def player_level
    return [($actors || []).compact.map(&:level).max.to_i, 5].max
  end

  # @return [PFM::Pokemon]
  def make_pokemon(species, form)
    level = [player_level + setting('level_bonus').to_i, 100].min
    if defined?(OverworldPokemon) && OverworldPokemon.respond_to?(:make_pokemon)
      encounter = Struct.new(:specie, :form).new(species, form)
      return OverworldPokemon.make_pokemon(encounter, level, setting('shiny_rate').to_i, setting('baron_rate').to_i)
    end
    rate = setting('shiny_rate').to_i
    return PFM::Pokemon.new(species, level, rate > 0 && rand(rate) == 0, false, form)
  end

  def spawn_pokemon(map)
    pool = species_pool
    return if pool.empty?

    setting('pokemon_count').to_i.times do
      species, form = pool.sample
      spot = random_tile(map)
      next unless spot

      pokemon = make_pokemon(species, form)
      id = add_event(map, EVENT_POKEMON, spot, charset_of(pokemon), 'faille_rencontre(%<id>d)', walk: true)
      runtime[:pokemon][id] = pokemon
    end
  end

  def charset_of(pokemon)
    return OverworldPokemon.charset(pokemon) if defined?(OverworldPokemon) && OverworldPokemon.respond_to?(:charset)

    return format('%04d', pokemon.id)
  end

  # --- Objets rares --------------------------------------------------------------------------------------------------
  # @return [Array<Hash>] table de butin valide
  def loot_table
    return Array(config.loot).select do |entry|
      sym = fetch(entry, 'item').to_s
      !sym.empty? && (data_item(sym.to_sym).db_symbol != :__undef__ rescue false)
    end
  end

  # @return [Array(Symbol, Integer)] un objet tiré selon les poids
  def roll_item
    table = loot_table
    return nil if table.empty?

    total = table.sum { |entry| [fetch(entry, 'weight').to_i, 1].max }
    pick = rand(total)
    table.each do |entry|
      pick -= [fetch(entry, 'weight').to_i, 1].max
      next if pick >= 0

      range = Array(fetch(entry, 'count'))
      low = [range.first.to_i, 1].max
      high = [range.last.to_i, low].max
      return [fetch(entry, 'item').to_sym, rand(low..high)]
    end
    return nil
  end

  def spawn_items(map)
    setting('item_count').to_i.times do
      loot = roll_item
      spot = random_tile(map)
      next unless loot && spot

      id = add_event(map, EVENT_OBJET, spot, setting('charset_item').to_s, 'faille_objet(%<id>d)', walk: false)
      runtime[:items][id] = loot
    end
  end

  # --- Évènements ----------------------------------------------------------------------------------------------------
  def random_tile(map, near: false)
    80.times do
      x = rand(map.width)
      y = rand(map.height)
      if near
        distance = (x - $game_player.x).abs + (y - $game_player.y).abs
        next unless distance.between?(4, 9)
      end
      return [x, y] if tile_free?(map, x, y)
    end
    return nil
  end

  def tile_free?(map, x, y)
    return false unless map.valid?(x, y)
    return false unless [2, 4, 6, 8].all? { |direction| map.passable?(x, y, direction) }
    return false if x == $game_player.x && y == $game_player.y

    return map.events.values.none? { |event| event.x == x && event.y == y }
  end

  # @return [Integer] identifiant de l'évènement créé
  def add_event(map, name, spot, charset, command, walk: false, fixed: false)
    id = [map.events.keys.max.to_i + 1, 1].max
    rpg = RPG::Event.new(spot[0], spot[1])
    rpg.id = id
    rpg.name = name
    page = rpg.pages[0]
    page.graphic.character_name = charset.to_s
    page.graphic.direction = 2
    page.graphic.pattern = 0
    page.move_type = walk && !fixed ? 1 : 0
    page.move_speed = 3
    page.move_frequency = 3
    page.walk_anime = walk
    page.step_anime = fixed
    page.direction_fix = fixed
    page.trigger = 0
    page.list = [RPG::EventCommand.new(355, 0, [format(command.to_s, id: id)]), RPG::EventCommand.new(0, 0, [])]
    map.events[id] = Game_Event.new(map.map_id, rpg)
    return id
  end

  def erase_events(name)
    return unless $game_map

    $game_map.events.values.each { |event| event.erase if event.respond_to?(:event) && event.event.name == name }
  rescue StandardError
    nil
  end

  # Pokémon touché (appelé par l'évènement) : combat puis disparition
  def encounter(interpreter, id)
    pokemon = runtime[:pokemon].delete(id)
    return unless pokemon

    $game_map.events[id]&.erase
    interpreter.call_battle_wild(pokemon, nil)
  end

  # Objet ramassé
  def pickup(interpreter, id)
    loot = runtime[:items].delete(id)
    return unless loot

    item, count = loot
    $bag.add_item(item, count)
    $game_map.events[id]&.erase
    name = data_item(item).name
    interpreter.display_message_and_wait(t("Tu trouves #{count} #{name} !", "You found #{count} #{name}!"))
  end
end

module PFM
  class GameState
    module FaillesSteps
      def increase_steps
        super
        Failles.step
      rescue StandardError => e
        log_error("Failles : pas (#{e.message})") if respond_to?(:log_error, true)
      end
    end
    prepend FaillesSteps
  end
end

class Game_Map
  module FaillesSetup
    # Une nouvelle carte (ou une sauvegarde rechargée) referme la zone : ses évènements ne sont pas sauvegardés
    def setup(map_id)
      result = super
      Failles.close_zone(false) if Failles.active?
      Failles.state['life'] = nil
      return result
    rescue StandardError => e
      log_error("Failles : carte #{e.message}") if respond_to?(:log_error, true)
      return result
    end
  end
  prepend FaillesSetup
end

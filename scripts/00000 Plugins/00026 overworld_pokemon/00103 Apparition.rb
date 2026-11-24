# Overworld Pokémon : apparition des Pokémon à l'arrivée sur une carte
#
# Les évènements sont ajoutés pendant Game_Map#setup, avant que la scène de la carte crée les sprites : ils sont donc
# affichés comme n'importe quel évènement de la carte. Le joueur n'a pas encore sa place à ce moment : un Pokémon trop
# près de lui est déplacé à sa première mise à jour (keep_away_from_player).
module OverworldPokemon
  TEMPERAMENTS = %i[wander flee charge].freeze

  module_function

  # Pokémon chromatiques sauvegardés (par carte) : { map_id => [{ pokemon:, nature:, tag:, x:, y: }] }
  # @return [Hash]
  def store
    state = PFM.game_state
    data = state.instance_variable_get(:@pj_overworld) || state.instance_variable_set(:@pj_overworld, {})
    return data[:shinies] ||= {}
  end

  # Un Pokémon qui se promène dort la nuit (sleep_rate % d'entre eux, tirés d'après leur numéro d'évènement)
  # @return [Boolean]
  def sleeper?(nature, event_id)
    rate = setting('sleep_rate').to_i
    return false unless rate > 0 && nature == :wander && $env.respond_to?(:night?) && $env.night?

    return (event_id.to_i * 37 + 11) % 100 < rate
  rescue StandardError
    return false
  end

  # @param map [Game_Map]
  def spawn(map)
    return unless enabled?
    return if setting('excluded_maps').map(&:to_i).include?(map.map_id)

    remove_all(map)
    id = setting('event_id_start').to_i
    id = spawn_saved_shinies(map, id)
    groups = land_groups(zone_of(map.map_id))
    return if groups.empty?

    count = [[(map.width * map.height) / [setting('tiles_per_pokemon').to_i, 1].max, 1].max, setting('max_per_map').to_i].min
    count.times do
      rolled = roll(groups)
      next unless rolled

      group, encounter, level = rolled
      tag = tag_value(group.system_tag)
      spot = free_tile(map, tag)
      next unless spot

      id = add_pokemon(map, id, spot, tag, make_pokemon(encounter, level, setting('shiny_rate').to_i))
    end
    id = spawn_outbreak(map, id, groups)
    spawn_herd(map, id)
  rescue StandardError => e
    log_error("apparition impossible (#{e.message})")
  end

  # Crée le Pokémon d'une rencontre (Baron / Dominant possibles)
  # @param shiny_rate [Integer] chance 1/N de chromatique (0 : chance normale du jeu)
  # @param baron_rate [Integer, nil] % de Barons (nil : réglage baron_rate)
  # @param rank [Symbol, nil] :baron ou :dominant pour forcer le rang
  # @return [PFM::Pokemon]
  def make_pokemon(encounter, level, shiny_rate, baron_rate = nil, rank = nil)
    rank ||= pick_rank(baron_rate)
    level = [level + rank_bonus(rank), 100].min
    pokemon = PFM::Pokemon.new(encounter.specie, level, shiny_rate > 0 && rand(shiny_rate) == 0, false, encounter.form.to_i)
    apply_rank(pokemon, rank)
    pokemon = AdvancedPokedex::Research.apply_charm(pokemon) if defined?(AdvancedPokedex::Research)
    return pokemon
  end

  # Ajoute le Pokémon à la carte (sauvegarde s'il est chromatique, icône s'il a un rang)
  # @return [Integer] prochain identifiant d'évènement libre
  def add_pokemon(map, id, spot, tag, pokemon)
    nature = temperament
    entry = nil
    if pokemon.shiny? && setting('shiny_persist')
      entry = { pokemon: pokemon, nature: nature, tag: tag, x: spot[0], y: spot[1] }
      (store[map.map_id] ||= []) << entry
    elsif pokemon.shiny?
      entry = { pokemon: pokemon }
    end
    return place(map, id, spot, pokemon, nature, tag, entry)
  end

  # @return [Integer] prochain identifiant libre (le Pokémon, puis son icône s'il en a une)
  def place(map, id, spot, pokemon, nature, tag, entry)
    event = build(map, id, spot, pokemon, nature, tag, entry)
    map.events[id] = event
    id += 1
    icon = rank_icon(pokemon)
    if icon
      map.events[id] = build_icon(map, id, event, icon)
      id += 1
    end
    return id
  end

  # Apparition massive tirée au sort à l'arrivée sur la carte
  def spawn_outbreak(map, id, groups)
    chance = setting('outbreak_chance').to_i
    return id unless chance > 0 && rand(100) < chance

    group, encounter, level = roll(groups)
    return id unless group

    return gather(map, id, tag_value(group.system_tag), encounter, level, setting('outbreak_count').to_i)
  end

  # Troupeau du jour annoncé par le radar du téléphone (plugin PokeSmart) : rassemblé dans sa zone
  # @return [Integer] prochain identifiant d'évènement libre
  def spawn_herd(map, id)
    return id unless defined?(UI::PokeSmart::Herds)

    herd = UI::PokeSmart::Herds.herd_for(map)
    return id unless herd

    found = land_groups(zone_of(map.map_id)).flat_map { |g| g.encounters.to_a.map { |enc| [g, enc] } }.find { |_g, enc| enc.specie.to_s == herd['species'] }
    return id unless found

    return gather(map, id, tag_value(found[0].system_tag), found[1], level_of(found[1]), UI::PokeSmart::Herds.setting('herd_count').to_i)
  rescue StandardError => e
    log_error("troupeau impossible (#{e.message})")
    return id
  end

  # Rassemble count Pokémon d'une même espèce autour d'une tuile libre
  # @return [Integer] prochain identifiant d'évènement libre
  def gather(map, id, tag, encounter, level, count)
    anchor = free_tile(map, tag)
    return id unless anchor

    radius = [setting('outbreak_radius').to_i, 1].max
    shiny = setting('outbreak_shiny_rate').to_i
    shiny = setting('shiny_rate').to_i if shiny <= 0
    placed = 0
    (count * 6).times do
      break if placed >= count

      x = anchor[0] + rand(-radius..radius)
      y = anchor[1] + rand(-radius..radius)
      next unless tile_ok?(map, x, y, tag)

      id = add_pokemon(map, id, [x, y], tag, make_pokemon(encounter, [level + rand(-1..1), 1].max, shiny, setting('outbreak_baron_rate').to_i))
      placed += 1
    end
    outbreak_alert if placed > 0
    return id
  end

  # Commande apparition_massive : rassemble des Pokémon sur la carte en cours (espèce : celle d'un groupe de la zone, sinon n'importe où)
  # @param species [Symbol, nil]
  # @param count [Integer, nil]
  # @return [Integer] nombre de Pokémon visibles ajoutés
  def force_outbreak(map, species = nil, count = nil)
    count = (count || setting('outbreak_count')).to_i
    groups = land_groups(zone_of(map.map_id))
    tag = nil
    if species
      found = groups.flat_map { |g| g.encounters.to_a.map { |enc| [g, enc] } }.find { |_g, enc| enc.specie.to_s == species.to_s }
      tag = tag_value(found[0].system_tag) if found
      encounter = found ? found[1] : Struct.new(:specie, :form).new(species, 0)
      level = found ? level_of(found[1]) : [($actors || []).compact.map(&:level).max.to_i, 2].max
    else
      group, encounter, level = roll(groups)
      return 0 unless group

      tag = tag_value(group.system_tag)
    end
    first = [map.events.keys.max.to_i + 1, setting('event_id_start').to_i].max
    before = map.events.values.count { |event| event.is_a?(Game_OverworldPokemon) }
    gather(map, first, tag, encounter, level, count)
    return map.events.values.count { |event| event.is_a?(Game_OverworldPokemon) } - before
  end

  # Remet sur la carte les Pokémon chromatiques sauvegardés
  # @return [Integer] prochain identifiant d'évènement libre
  def spawn_saved_shinies(map, id)
    list = store[map.map_id]
    return id unless list && setting('shiny_persist')

    list.each do |entry|
      spot = tile_ok?(map, entry[:x], entry[:y], entry[:tag]) ? [entry[:x], entry[:y]] : free_tile(map, entry[:tag])
      next unless spot

      id = place(map, id, spot, entry[:pokemon], entry[:nature] || :wander, entry[:tag], entry)
    end
    return id
  end

  # Retire les Pokémon visibles de la carte (nouvelle apparition)
  def remove_all(map)
    map.events.delete_if { |_id, event| event.is_a?(Game_OverworldPokemon) || event.is_a?(Game_OverworldIcon) }
  end

  # @return [Symbol]
  def temperament
    weights = { wander: setting('wander_rate').to_f, flee: setting('flee_rate').to_f, charge: setting('charge_rate').to_f }
    total = weights.values.sum
    return :wander if total <= 0

    pick = rand * total
    weights.each do |name, weight|
      pick -= weight
      return name if pick <= 0
    end
    return :wander
  end

  # @return [Array(Integer, Integer), nil] tuile libre du bon terrain (tag nil : n'importe quelle tuile libre)
  def free_tile(map, tag, away_from: nil)
    distance = setting('min_distance').to_i
    60.times do
      x = rand(map.width)
      y = rand(map.height)
      next unless tile_ok?(map, x, y, tag)
      next if away_from && (x - away_from.x).abs + (y - away_from.y).abs < distance

      return [x, y]
    end
    return nil
  end

  def tile_ok?(map, x, y, tag)
    return false unless map.valid?(x, y)
    return false if tag && !map.system_tag_here?(x, y, tag)
    return false unless [2, 4, 6, 8].all? { |d| map.passable?(x, y, d) }

    return map.events.values.none? { |event| event.x == x && event.y == y }
  end

  # @return [Game_OverworldPokemon]
  def build(map, id, spot, pokemon, nature, tag, entry = nil)
    rpg = RPG::Event.new(spot[0], spot[1])
    rpg.id = id
    rpg.name = 'pokemon_visible'
    page = rpg.pages[0]
    page.graphic.character_name = charset(pokemon)
    page.graphic.direction = [2, 4, 6, 8].sample
    page.graphic.pattern = 0
    page.move_type = nature == :wander ? 1 : 0
    page.move_speed = setting('move_speed').to_i.clamp(1, 6)
    page.move_frequency = setting('move_frequency').to_i.clamp(1, 5)
    page.walk_anime = true
    page.step_anime = false
    page.trigger = 1
    page.list = [RPG::EventCommand.new(355, 0, ["OverworldPokemon.encounter(self, #{id})"]), RPG::EventCommand.new(0, 0, [])]
    return Game_OverworldPokemon.new(map.map_id, rpg, pokemon, nature, tag, entry)
  end

  # Sprite du Pokémon suiveur (chromatique, forme, sexe selon les fichiers présents)
  # @return [String]
  def charset(pokemon)
    name = pokemon.character_name if pokemon.respond_to?(:character_name)
    return name.to_s unless name.to_s.empty?

    return format('%04d', pokemon.id)
  rescue StandardError
    return format('%04d', pokemon.id)
  end

  # Place un Pokémon trop près du joueur ailleurs
  def keep_away_from_player(event)
    distance = (event.x - $game_player.x).abs + (event.y - $game_player.y).abs
    return if distance >= setting('min_distance').to_i

    spot = free_tile($game_map, event.instance_variable_get(:@ow_tag), away_from: $game_player)
    spot ? event.moveto(*spot) : event.erase
    entry = event.ow_entry
    entry.merge!(x: spot[0], y: spot[1]) if entry && spot
  end

  # Le joueur et le Pokémon sont en contact (évènement lancé par le jeu : script « OverworldPokemon.encounter(self, id) »)
  # @param interpreter [Interpreter]
  # @param id [Integer]
  def encounter(interpreter, id)
    event = $game_map.events[id]
    pokemon = event&.ow_pokemon
    return unless pokemon

    event.erase
    forget(event)
    interpreter.call_battle_wild(pokemon, nil)
  end

  # Le combat commence : un Pokémon chromatique sauvegardé disparaît de la carte, capturé ou non
  def forget(event)
    entry = event.ow_entry
    return unless entry

    store.each_value { |list| list.delete_if { |saved| saved.equal?(entry) } }
  end

  # Son joué quand un Pokémon chromatique apparaît
  def shiny_alert(_pokemon)
    sound = setting('shiny_se').to_s
    Audio.se_play(sound) unless sound.empty?
  rescue StandardError
    nil
  end

  # Le Pokémon remarque le joueur : son cri
  def notice(event, pokemon)
    return unless setting('cry')

    Audio.se_play(pokemon.cry) if pokemon.respond_to?(:cry)
  rescue StandardError
    nil
  end

  # @return [Boolean] si un évènement, un message ou une scène occupe le joueur (les Pokémon ne bougent plus)
  def busy?
    return true if $game_system.respond_to?(:map_interpreter) && $game_system.map_interpreter&.running?
    return true if $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing
    return true if $game_temp.respond_to?(:player_transferring) && $game_temp.player_transferring

    return false
  rescue StandardError
    return false
  end
end

class Game_Map
  # Après la mise en place de la carte, les Pokémon visibles sont ajoutés aux évènements
  module OverworldPokemonSetup
    def setup(map_id)
      result = super
      OverworldPokemon.spawn(self)
      return result
    end
  end
  prepend OverworldPokemonSetup
end

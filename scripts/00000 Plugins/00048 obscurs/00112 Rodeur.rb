# encoding: utf-8
# Pokémon Obscurs : le Rôdeur
#
# Un dresseur errant (façon Miror B. dans XD) récupère les Pokémon Obscurs des dresseurs qu'on a battus sans les capturer.
# Il réapparaît dans une carte d'une zone déjà visitée, tirée au hasard : tous les rodeur_days jours, et dès qu'il vient
# de récupérer un nouveau Pokémon ou de fuir un combat. La bannière du téléphone (plugin PokeSmart, si présent) annonce sa
# zone (rodeur_hint). Lui parler propose un combat contre ses Pokémon Obscurs, capturables comme ceux des autres dresseurs
# (Snatcheur ou Snatch Ball). Un Pokémon capturé ou purifié quitte sa troupe ; s'il fuit, ses Pokémon gagnent
# rodeur_level_gain niveaux. Réglages : rodeur_enabled, rodeur_days, rodeur_level_gain, rodeur_max, rodeur_hint,
# rodeur_name, rodeur_charset (graphics/characters), rodeur_battler (graphics/battlers).
module Obscurs
  RODEUR_EVENT = 'rodeur_obscur'

  module_function

  # @return [Hash] { 'pool' => [fiches], 'zones' => { clé => { 'name', 'maps' } }, 'zone', 'map', 'day' }
  def rodeur_data
    hash = data['rodeur'] ||= {}
    hash['pool'] ||= []
    hash['zones'] ||= {}
    return hash
  end

  # Fiche d'un Pokémon Obscur raté : il passe dans la troupe du Rôdeur
  def rodeur_collect(pokemon, id)
    return unless setting('rodeur_enabled') && pokemon.respond_to?(:shadow_data) && pokemon.shadow_data

    hash = rodeur_data
    return if hash['pool'].any? { |entry| entry['id'] == id.to_s }

    shadow = pokemon.shadow_data
    hash['pool'] << { 'id' => id.to_s, 'species' => pokemon.db_symbol.to_s, 'form' => pokemon.form.to_i, 'level' => pokemon.level.to_i,
                      'gauge' => shadow['max'].to_i, 'moves' => Array(shadow['moves']) }
    hash['zone'] = nil
  rescue StandardError => e
    log_error("Obscurs : Rôdeur #{e.message}") if respond_to?(:log_error, true)
  end

  # Le Pokémon Obscur a été capturé : il quitte la troupe
  def rodeur_release(id)
    rodeur_data['pool'].reject! { |entry| entry['id'] == id.to_s }
  end

  def rodeur_present?
    return setting('rodeur_enabled') && !rodeur_data['pool'].empty?
  end

  # @param map_id [Integer]
  # @return [Object, nil] zone de la carte
  def rodeur_zone_of(map_id)
    return OverworldPokemon.zone_of(map_id) if defined?(OverworldPokemon) && OverworldPokemon.respond_to?(:zone_of)

    return $env&.current_zone_data
  rescue StandardError
    return nil
  end

  def rodeur_zone_key(zone)
    return nil unless zone

    key = zone.respond_to?(:db_symbol) ? zone.db_symbol : (zone.respond_to?(:id) ? zone.id : nil)
    return key&.to_s
  end

  # @return [String] nom de la zone où se trouve le Rôdeur ('' : introuvable)
  def rodeur_zone_name
    hash = rodeur_data
    return fetch(hash['zones'][hash['zone']], 'name').to_s
  end

  # Une carte vient d'être visitée : sa zone peut accueillir le Rôdeur
  def rodeur_register(map_id)
    return unless setting('rodeur_enabled')

    key = rodeur_zone_key(rodeur_zone_of(map_id))
    return unless key

    zone = rodeur_data['zones'][key] ||= { 'name' => $env&.current_zone_name.to_s, 'maps' => [] }
    zone['name'] = $env.current_zone_name.to_s if $game_map && $game_map.map_id == map_id && $env
    zone['maps'] |= [map_id.to_i]
  rescue StandardError
    nil
  end

  # Le Rôdeur change de zone s'il le faut (nouveau Pokémon récupéré, fuite, ou rodeur_days jours écoulés)
  # @param current_map [Integer, nil] carte où se trouve le joueur (le Rôdeur ne s'y installe pas)
  def rodeur_refresh(current_map = nil, force: false)
    return unless rodeur_present?

    hash = rodeur_data
    today = Time.now.to_i / 86_400
    wait = [setting('rodeur_days').to_i, 1].max
    return if !force && hash['zone'] && hash['day'] && today - hash['day'].to_i < wait

    here = rodeur_zone_key(rodeur_zone_of(current_map)) if current_map
    choices = hash['zones'].keys.reject { |key| key == here || key == hash['zone'] }
    choices = hash['zones'].keys.reject { |key| key == here } if choices.empty?
    return if choices.empty?

    hash['zone'] = choices.sample
    hash['map'] = Array(fetch(hash['zones'][hash['zone']], 'maps')).sample
    hash['day'] = today
    rodeur_hint
  end

  def rodeur_hint
    return unless setting('rodeur_hint') && defined?(UI::PokeSmart::Notify)

    UI::PokeSmart::Notify.push(t("#{setting('rodeur_name')} a été aperçu vers #{rodeur_zone_name} !",
                                 "A drifter was spotted around #{rodeur_zone_name}!"), title: 'Radar')
  rescue StandardError
    nil
  end

  def rodeur_tile_ok?(map, x, y)
    return false unless map.valid?(x, y)
    return false unless [2, 4, 6, 8].all? { |direction| map.passable?(x, y, direction) }

    return map.events.values.none? { |event| event.x == x && event.y == y }
  end

  # Installe le Rôdeur sur la carte s'il y est attendu
  # @param map [Game_Map]
  def rodeur_spawn(map)
    return unless rodeur_present?

    hash = rodeur_data
    return unless hash['zone'] && rodeur_zone_key(rodeur_zone_of(map.map_id)) == hash['zone']
    return if hash['map'] && hash['map'].to_i != map.map_id

    spot = nil
    80.times do
      x = rand(map.width)
      y = rand(map.height)
      (spot = [x, y]) && break if rodeur_tile_ok?(map, x, y)
    end
    return unless spot

    id = [map.events.keys.max.to_i + 1, 1].max
    rpg = RPG::Event.new(spot[0], spot[1])
    rpg.id = id
    rpg.name = RODEUR_EVENT
    page = rpg.pages[0]
    page.graphic.character_name = setting('rodeur_charset').to_s
    page.graphic.direction = 2
    page.graphic.pattern = 0
    page.move_type = 1
    page.move_speed = 3
    page.move_frequency = 3
    page.walk_anime = true
    page.trigger = 0
    page.list = [RPG::EventCommand.new(355, 0, ['rodeur_obscur']), RPG::EventCommand.new(0, 0, [])]
    map.events[id] = Game_Event.new(map.map_id, rpg)
  rescue StandardError => e
    log_error("Obscurs : apparition du Rôdeur #{e.message}") if respond_to?(:log_error, true)
  end

  # @return [Array<PFM::Pokemon>] la troupe du Rôdeur (les plus forts d'abord)
  def rodeur_party
    list = rodeur_data['pool'].sort_by { |entry| -entry['level'].to_i }.first([setting('rodeur_max').to_i.clamp(1, 6), 1].max)
    return list.map do |entry|
      create(entry['species'], entry['level'], id: entry['id'], gauge: entry['gauge'], moves: entry['moves'], form: entry['form'].to_i)
    end
  end

  # Le joueur parle au Rôdeur
  # @param scene [Scene_Map, Object] objet qui sait afficher un message à choix
  def rodeur_talk
    names = rodeur_data['pool'].map { |entry| data_creature(entry['species'].to_sym).name rescue entry['species'] }.uniq.first(4).join(', ')
    text = t("Hé, toi ! J'ai recueilli ces pauvres Pokémon (#{names}). Ils sont bien plus utiles avec moi... sauf si tu me bats.",
             "Hey, you! I took in these poor Pokémon (#{names}). They're much more useful with me... unless you beat me.")
    choice = $scene.display_message(text, 1, t('Combattre', 'Battle'), t('Partir', 'Leave'))
    return false unless choice.to_i == 0

    if $actors.none? { |pokemon| !pokemon.dead? && !pokemon.egg? }
      $scene.display_message_and_wait(t('Il te faut un Pokémon en état de se battre !', 'You need a Pokémon that can fight!'))
      return false
    end
    return rodeur_battle
  end

  def rodeur_battle
    info = ::Battle::Logic::BattleInfo.new
    info.add_party(1, rodeur_party, setting('rodeur_name').to_s, setting('rodeur_name').to_s, setting('rodeur_battler').to_s, PFM::Bag.new)
    info.add_party(0, *info.player_basic_info)
    info.pj_rodeur = true
    $game_temp.battle_can_lose = true if $game_temp.respond_to?(:battle_can_lose=)
    if $scene.is_a?(::Scene_Map)
      Graphics.freeze
      $scene = ::Battle::Scene.new(info)
      Yuki::FollowMe.set_battle_entry
    else
      $scene.call_scene(::Battle::Scene, info)
    end
    return true
  end

  # Fin du combat : le Rôdeur fuit avec ceux qui n'ont pas été capturés
  # @param result [Integer] 0 : le joueur a gagné
  def rodeur_after(result)
    gain = setting('rodeur_level_gain').to_i
    rodeur_data['pool'].each { |entry| entry['level'] = [entry['level'].to_i + gain, 100].min } if gain > 0
    rodeur_data['zone'] = nil
    rodeur_refresh($game_map&.map_id, force: true)
    return unless $game_map

    $game_map.events.values.each { |event| event.erase if event.respond_to?(:event) && event.event.name == RODEUR_EVENT }
  rescue StandardError => e
    log_error("Obscurs : fin du combat du Rôdeur #{e.message}") if respond_to?(:log_error, true)
  end
end

module Battle
  class Logic
    class BattleInfo
      # @return [Boolean, nil] combat contre le Rôdeur
      attr_accessor :pj_rodeur
    end
  end

  class Scene
    module ObscursRodeurScene
      def battle_end
        rodeur = @battle_info.respond_to?(:pj_rodeur) && @battle_info.pj_rodeur
        result = @logic.battle_result if rodeur
        super
        Obscurs.rodeur_after(result) if rodeur
      end
    end
    prepend ObscursRodeurScene
  end
end

class Game_Map
  module ObscursRodeurSetup
    def setup(map_id)
      result = super
      Obscurs.rodeur_register(map_id)
      Obscurs.rodeur_refresh(map_id)
      Obscurs.rodeur_spawn(self)
      return result
    rescue StandardError => e
      log_error("Obscurs : Rôdeur #{e.message}") if respond_to?(:log_error, true)
      return result
    end
  end
  prepend ObscursRodeurSetup
end

class Interpreter
  # Commande de l'évènement du Rôdeur (parler pour combattre)
  def rodeur_obscur
    Obscurs.rodeur_talk
    @wait_count = 2
  end

  def rodeur_obscur_present?
    return Obscurs.rodeur_present? ? true : false
  end

  # @return [String] nom de la zone du Rôdeur
  def rodeur_obscur_zone
    return Obscurs.rodeur_zone_name
  end

  # @return [Integer] Pokémon Obscurs dans sa troupe
  def rodeur_obscur_nombre
    return Obscurs.rodeur_data['pool'].size
  end
end

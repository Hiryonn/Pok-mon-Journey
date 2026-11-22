# Overworld Pokémon : des Pokémon sauvages visibles sur la carte (façon Légendes Arceus / Écarlate et Violet)
#
# À l'arrivée sur une carte, des Pokémon sont tirés dans les groupes sauvages de la zone (ceux des herbes, du sol… ; pas ceux
# de l'eau ni de la pêche), qui respectent déjà l'heure, la météo et les conditions de Studio. Ils se promènent sur les tuiles
# du bon type (herbe haute pour un groupe d'herbe haute, etc.). Trois tempéraments :
#   wander  se promène, ne s'occupe pas du joueur (le contact lance le combat)
#   flee    s'éloigne quand le joueur s'approche
#   charge  fonce sur le joueur dès qu'il le remarque (le contact lance le combat)
# Le combat est contre CE Pokémon (niveau, forme, chromatique) ; il disparaît de la carte dès que le combat commence
# (capturé ou non : le Pokémon qui s'échappe ne revient pas). Les Pokémon ordinaires sont retirés quand on quitte la carte.
# Un Pokémon chromatique, lui, fait entendre un son à son apparition et reste sauvegardé sur sa carte (même si on la quitte
# ou qu'on éteint le jeu) jusqu'au début du combat contre lui.
# Le sprite est celui du Pokémon suiveur (graphics/characters/0025.png, 0025s.png chromatique…).
#
# Réglages : Studio, Level design > Zones > Pokémon visibles (Data/configs/plugins/overworld_pokemon.json)
#   enabled           false pour tout couper                       disable_switch   n° d'interrupteur qui coupe l'apparition (0 : aucun)
#   max_per_map       Pokémon visibles au plus par carte            tiles_per_pokemon  une tuile sur N donne un Pokémon de plus
#   min_distance      distance minimale au joueur à l'apparition    notice_distance  distance à laquelle ils remarquent le joueur
#   wander_rate / flee_rate / charge_rate   poids des tempéraments (en %)
#   move_speed, move_frequency   vitesse (1-6) et fréquence des déplacements (1-5)
#   cry               joue le cri du Pokémon quand il remarque le joueur
#   shiny_se          son joué quand un Pokémon chromatique apparaît (vide : aucun)
#   shiny_persist     un Pokémon chromatique reste sur la carte (et dans la sauvegarde) tant que le combat n'a pas commencé
#   shiny_rate        chance 1/N de faire apparaître un chromatique (0 : chance normale du jeu)
#   level_variation   écart de niveau possible (+/-) autour du niveau du groupe sauvage
#   excluded_maps     [numéros de cartes sans Pokémon visibles]    excluded_species   [db_symbol des espèces jamais visibles]
#   tag_aliases       { "NomDuTagStudio": "NomDeLaConstanteGameData::SystemTags" } si un tag n'est pas reconnu
#
# Barons (Légendes Arceus) : un Pokémon visible peut être un Baron (baron_rate %). Une icône rouge flotte au-dessus de lui.
#   baron_level_bonus     niveaux en plus             baron_perfect_ivs   nombre de statistiques aux IV parfaits (31)
#   baron_exp_percent     % d'expérience gagnée en le battant (150 : une fois et demie)
#   baron_boost           statistique qui monte d'un cran à son entrée au combat (passif caché, aussi une fois capturé) :
#                         atk, dfe, spd, ats, dfs, random ou none      baron_boost_stages   crans gagnés
#   baron_icon            icône sur la carte : image de graphics/characters (4x4 cases de 32 px), vide par défaut (le Baron a
#                         alors son sprite normal)      baron_se   son à l'apparition (vide : aucun)
# Monarques : des Barons plus rares et un peu plus forts (monarch_rate %, tiré en premier). Niveaux, IV parfaits,
# expérience et passif caché comme le Baron (monarch_level_bonus, monarch_perfect_ivs, monarch_exp_percent, monarch_boost,
# monarch_boost_stages), marque dorée en combat (monarch_battle_icon) et lueur dorée autour du Pokémon en combat (monarch_glow).
# En combat, la marque (graphics/interface/rang_baron.png, rang_dominant.png, 16 px) s'affiche à côté de la barre de vie du
# Pokémon, comme la marque chromatique (battle_icon, battle_icon_zoom en %, battle_icon_x / battle_icon_y : décalage). Le rang reste sur le Pokémon une fois capturé.
# Dominants (Soleil / Lune) : un Pokémon visible peut être un Dominant (dominant_rate %), même icône en blanc. En combat,
# une aura l'enveloppe et augmente une statistique.
#   dominant_level_bonus  niveaux en plus             dominant_boost      statistique : atk, dfe, spd, ats, dfs ou random
#   dominant_boost_stages crans gagnés au début du combat                      dominant_exp_percent, dominant_icon, dominant_se
# Apparitions massives (Légendes Arceus) : à l'arrivée sur une carte, outbreak_chance % de chances qu'un groupe de
# outbreak_count Pokémon de la même espèce s'y rassemble (rayon outbreak_radius), en plus des Pokémon habituels.
#   outbreak_shiny_rate   chance 1/N de chromatique pour ces Pokémon (0 : normale)   outbreak_baron_rate   % de Barons parmi eux
#   outbreak_se           son à l'arrivée sur une carte avec apparition massive
# Sommeil : la nuit, sleep_rate % des Pokémon qui se promènent dorment (immobiles) jusqu'à ce que le joueur arrive à wake_distance
# tuiles (0 : personne ne dort). Les quêtes photo du Journal (pokesmart) s'en servent.
# Commandes d'évènement : 00110 Commandes.rb
module Configs
  class OverworldPokemonConfig
    attr_accessor :settings

    def initialize
      @settings = {}
    end
  end
  register(:overworld_pokemon, 'plugins/overworld_pokemon', :json, false, OverworldPokemonConfig)
end

module OverworldPokemon
  CONFIG_FILE = 'Data/configs/plugins/overworld_pokemon.json'
  DEFAULTS = {
    'enabled' => true, 'disable_switch' => 0, 'max_per_map' => 5, 'tiles_per_pokemon' => 350, 'min_distance' => 5,
    'notice_distance' => 4, 'wander_rate' => 70, 'flee_rate' => 15, 'charge_rate' => 15, 'move_speed' => 3,
    'move_frequency' => 3, 'cry' => true, 'level_variation' => 2, 'excluded_maps' => [], 'excluded_species' => [],
    'tag_aliases' => {}, 'event_id_start' => 9000, 'shiny_se' => 'audio/se/se_shiny', 'shiny_persist' => true,
    'shiny_rate' => 0,
    'baron_rate' => 4, 'baron_level_bonus' => 8, 'baron_perfect_ivs' => 3, 'baron_exp_percent' => 150,
    'baron_icon' => '', 'baron_se' => '', 'baron_boost' => 'random', 'baron_boost_stages' => 1,
    'battle_icon' => true, 'battle_icon_x' => 2, 'battle_icon_y' => 0, 'battle_icon_zoom' => 75, 'baron_battle_icon' => 'rang_baron',
    'dominant_battle_icon' => 'rang_dominant',
    'monarch_rate' => 1, 'monarch_level_bonus' => 10, 'monarch_perfect_ivs' => 4, 'monarch_exp_percent' => 175,
    'monarch_icon' => '', 'monarch_se' => '', 'monarch_boost' => 'random', 'monarch_boost_stages' => 1,
    'monarch_battle_icon' => 'rang_monarque', 'monarch_glow' => true,
    'dominant_rate' => 2, 'dominant_level_bonus' => 3, 'dominant_boost' => 'random', 'dominant_boost_stages' => 1,
    'dominant_exp_percent' => 150, 'dominant_icon' => '', 'dominant_se' => '',
    'outbreak_chance' => 3, 'outbreak_count' => 8, 'outbreak_radius' => 4, 'outbreak_shiny_rate' => 100,
    'outbreak_baron_rate' => 10, 'outbreak_se' => '', 'sleep_rate' => 40, 'wake_distance' => 2
  }.freeze

  module_function

  # @return [Hash] réglages (Studio : Data/configs/plugins/overworld_pokemon.json ; vide s'il n'existe pas)
  def settings
    @settings ||= begin
      if PSDK_CONFIG.release?
        Configs.overworld_pokemon.settings || {}
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        data.is_a?(Hash) && data['settings'].is_a?(Hash) ? data['settings'] : {}
      else
        {}
      end
    rescue StandardError, ScriptError => e
      log_error("réglages illisibles (#{e.message})")
      {}
    end
  end

  def reload
    @settings = nil
  end

  # @param key [String, Symbol]
  def setting(key)
    value = settings[key.to_s]
    return value.nil? ? DEFAULTS[key.to_s] : value
  end

  def log_error(message)
    Kernel.send(:log_error, "Overworld Pokémon : #{message}") if Kernel.respond_to?(:log_error, true)
  rescue StandardError
    nil
  end

  # @return [Boolean] si les Pokémon visibles sont actifs (réglage + commande pokemon_visibles + interrupteur)
  def enabled?
    return false unless setting('enabled')
    return false if @forced_off

    switch = setting('disable_switch').to_i
    return false if switch > 0 && $game_switches && $game_switches[switch]

    return true
  end

  # Commande d'évènement pokemon_visibles(true / false)
  # @param value [Boolean]
  def forced_off=(value)
    @forced_off = value
  end

  def t(fr, en = fr)
    return $options && $options.language.to_s != 'fr' ? en : fr
  end
end

# Pokémon Obscurs (façon Pokémon Colosseum / XD : le Souffle des Ténèbres)
#
# Un Pokémon Obscur a le cœur fermé : une jauge cœur (5 barres) qui doit se vider avant de pouvoir le purifier.
#   - Tant qu'il est Obscur : nature cachée (????), pas de niveau ni d'évolution (l'expérience gagnée est gardée et
#     rendue à la purification), capacités Obscures, puis ses capacités d'origine reviennent quand la jauge baisse.
#   - Capacités Obscures (type Obscur de Studio) : super efficaces sur les Pokémon normaux, peu efficaces sur les
#     Pokémon Obscurs ; Ciel Obscur (météo), Moitié Obscure, Blocage Obscur, Brume / Panique / Baisse Obscure,
#     Mue Obscure, Fin Obscure (contrecoup).
#   - Furie (mode Hyper de XD et mode Inversion de Colosseum, réglage « mode ») : le Pokémon du joueur peut entrer en
#     furie en combat ; en mode Hyper il n'écoute plus toujours les ordres (coups critiques plus fréquents), en mode
#     Inversion il se blesse à la fin de chaque tour et sa jauge remonte. L'Appel (à la place de Fuite) l'apaise.
#   - Capture (« snag ») : les Pokémon Obscurs des dresseurs se capturent avec n'importe quelle Ball si le joueur a le
#     Snatcheur (objet clé), ou avec la Snatch Ball ; le combat continue ensuite.
#   - Un Pokémon purifié garde sa marque, résiste aux capacités Obscures (shadow_vs_purified), a le bonheur au maximum
#     (purified_loyalty) et gagne plus d'expérience (purified_exp_percent).
#   - Purification : la jauge baisse en combattant, en marchant, à la Pension, avec les Parfums et l'Appel ; une fois
#     vide, la Pierre Relique (commande d'évènement) ou la Chambre de purification (9 ensembles) purifie le Pokémon.
#
# Réglages : Data/configs/plugins/obscurs.json (Studio : Données > Gimmicks > Pokémon Obscurs)
#   settings  règles (voir DEFAULTS)
#   designs   sprites propres aux Pokémon Obscurs : { species (dbSymbol), form (-1 : toutes), front, back, icon } (voir 00108)
#   trainers  Pokémon Obscurs des dresseurs : { id, trainer (dbSymbol), slot (place dans l'équipe, 0 à 5), gauge,
#             moves (capacités Obscures) }
# Commandes d'évènement : 00110 Commandes.rb
module Configs
  class ObscursConfig
    attr_accessor :settings, :trainers, :designs

    def initialize
      @settings = {}
      @trainers = []
      @designs = []
    end
  end
  register(:obscurs, 'plugins/obscurs', :json, false, ObscursConfig)
end

module Obscurs
  CONFIG_FILE = 'Data/configs/plugins/obscurs.json'
  DIR = 'obscurs/'
  DEFAULTS = {
    # 'hyper' (XD), 'reverse' (Colosseum) ou 'both' (les deux à la fois)
    'mode' => 'both',
    'gauge' => 4000,
    # chance (%) d'entrer en furie à la fin d'un tour, selon les barres de la jauge (0 à 5)
    'fury_chance' => [0, 0, 4, 6, 8, 10],
    # mode Hyper : chance (%) de ne pas écouter les ordres
    'hyper_disobey' => 40,
    # mode Inversion : perte de PV (1 / n des PV max) et remontée de la jauge à chaque tour
    'reverse_damage' => 8,
    'reverse_gauge' => 50,
    # baisse de la jauge
    'battle_gauge' => 100,
    'call_gauge' => 300,
    'walk_gauge' => 1,
    'daycare_gauge' => 2,
    'chamber_gauge' => 2,
    'scents' => { 'joy_scent' => 500, 'excite_scent' => 1000, 'vivid_scent' => 2000 },
    # capacités Obscures : multiplicateurs contre un Pokémon normal / Obscur, Ciel Obscur
    'shadow_vs_normal' => 2.0,
    'shadow_vs_shadow' => 0.5,
    # un Pokémon purifié résiste aux capacités Obscures
    'shadow_vs_purified' => 0.5,
    'shadow_sky_turns' => 5,
    'shadow_sky_boost' => 1.5,
    'default_moves' => %w[shadow_rush],
    # capture
    'snag_machine' => 'snag_machine',
    'snag_ball' => 'snag_ball',
    # purification
    'ribbon' => 'national',
    'purify_me' => '',
    # Pokémon purifié : bonheur maximal à la purification, expérience gagnée en % (100 : normale)
    'purified_loyalty' => true, 'purified_exp_percent' => 120,
    'aura' => true,
    # marque (graphics/interface, 16 px) à côté de la barre de vie en combat et dans le résumé
    'team_gauge' => true, 'team_aura' => true,
    'mark' => true, 'mark_icon' => 'rang_obscur', 'mark_zoom' => 75, 'mark_x' => 2, 'mark_y' => 0,
    # marque d'un Pokémon purifié (vide : aucune)
    'purified_mark_icon' => 'rang_purifie'
  }.freeze
  # Ensembles de la Chambre de purification
  CHAMBER_SETS = 9
  CHAMBER_SIZE = 4

  module_function

  # @return [Configs::ObscursConfig]
  def config
    @config ||= load_config
  end

  def load_config
    return Configs.obscurs if PSDK_CONFIG.release?
    return Configs::ObscursConfig.new unless File.exist?(CONFIG_FILE)

    require 'json'
    data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
    cfg = Configs::ObscursConfig.new
    data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
    return cfg
  rescue StandardError, ScriptError => e
    log_error("Obscurs : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
    return Configs::ObscursConfig.new
  end

  def reload
    @config = nil
    @design_cache = nil
  end

  def fetch(hash, key)
    return nil unless hash.is_a?(Hash)

    value = hash[key.to_s]
    return value.nil? ? hash[key.to_sym] : value
  end

  def setting(key)
    value = fetch(config.settings, key)
    return value.nil? || value == '' ? DEFAULTS[key.to_s] : value
  end

  def number(key)
    return setting(key).to_f
  end

  def fr?
    return $options.nil? || $options.language.to_s == 'fr'
  end

  def t(fr, en = fr)
    return fr? ? fr : en
  end

  def file(name)
    return "#{DIR}#{name}"
  end

  def play_se(name, volume = 100)
    Audio.se_play("audio/se/#{name}", volume)
  rescue StandardError
    nil
  end

  def hyper?
    return %w[hyper both].include?(setting('mode').to_s)
  end

  def reverse?
    return %w[reverse both].include?(setting('mode').to_s)
  end

  # @return [Array<Hash>] Pokémon Obscurs des dresseurs
  def trainer_entries
    return Array(config.trainers).select { |entry| entry.is_a?(Hash) }
  end

  # Capacités Obscures (dbSymbol des capacités de type Obscur)
  def shadow_move?(symbol)
    return data_type(data_move(symbol).type).db_symbol == :shadow
  rescue StandardError
    return false
  end

  def shadow_type_id
    @shadow_type_id ||= (data_type(:shadow).id rescue -1)
  end
end

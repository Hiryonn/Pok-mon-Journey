# Cueillette Dodrio (Pokémon Rouge Feu / Vert Feuille)
#
# Des baies tombent sur 3 colonnes devant le Dodrio du joueur : Gauche, Haut (ou A) et Droite font picorer la tête
# de gauche, du milieu ou de droite (clic : dans la colonne). Une baie attrapée rapporte 1, 2 ou 3 points selon sa
# taille ; une baie qui tombe par terre est ratée. Plus on en attrape, plus elles tombent vite. La partie s'arrête
# quand le joueur a raté trop de baies (ou à la fin du temps, s'il est réglé). Avec 2 ou 3 joueurs, les Dodrio voisins
# (dirigés par l'ordinateur) partagent une colonne avec le joueur et peuvent lui voler ses baies.
# À la fin, le joueur reçoit le lot du palier de points atteint (réglages « prizes »).
#
# Réglages : Data/configs/plugins/dodrio.json (Studio : Level design > Mini-jeux > Cueillette Dodrio)
#   settings  voir DEFAULTS
#   prizes    lots : [{ points:, item:, count: }] (le meilleur palier atteint)
module Configs
  class DodrioConfig
    attr_accessor :settings, :prizes

    def initialize
      @settings = {}
      @prizes = []
    end
  end
  register(:dodrio, 'plugins/dodrio', :json, false, DodrioConfig)
end

module Dodrio
  CONFIG_FILE = 'Data/configs/plugins/dodrio.json'
  DIR = 'dodrio/'
  DEFAULTS = {
    'players' => 3,            # Dodrio sur le terrain (1 à 3 ; le joueur est au milieu)
    'max_misses' => 10,        # baies ratées avant la fin
    'time' => 0,               # durée en secondes (0 : jusqu'aux ratés)
    'difficulty' => 2,         # adresse des Dodrio de l'ordinateur (1 à 3)
    'start_speed' => 0.9,      # vitesse de chute au départ (pixels par image)
    'speed_step' => 0.12,      # vitesse ajoutée toutes les 10 baies attrapées par le joueur
    'max_speed' => 3.2,
    'require_dodrio' => true,  # il faut un Dodrio dans l'équipe pour jouer
    'species' => 'dodrio',     # espèce demandée
    'bgm' => '',               # musique de la partie (vide : celle de la carte)
    'npc_names' => [%w[Léa Lea], %w[Tom Tom], %w[Max Max], %w[Zoé Zoe], %w[Hugo Hugo], %w[Inès Ines]]
  }.freeze
  DEFAULT_PRIZES = [
    { 'points' => 30, 'item' => 'oran_berry', 'count' => 1 },
    { 'points' => 60, 'item' => 'sitrus_berry', 'count' => 1 },
    { 'points' => 100, 'item' => 'lum_berry', 'count' => 1 },
    { 'points' => 150, 'item' => 'leppa_berry', 'count' => 3 },
    { 'points' => 220, 'item' => 'starf_berry', 'count' => 1 }
  ].freeze
  # baies : points, chance (sur 100), vitesse
  BERRIES = [[1, 60, 1.0], [2, 30, 1.0], [3, 10, 1.2]].freeze

  module_function

  def config
    @config ||= load_config
  end

  def load_config
    return Configs.dodrio if PSDK_CONFIG.release?
    return Configs::DodrioConfig.new unless File.exist?(CONFIG_FILE)

    require 'json'
    data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
    cfg = Configs::DodrioConfig.new
    data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
    return cfg
  rescue StandardError, ScriptError => e
    log_error("Dodrio : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
    return Configs::DodrioConfig.new
  end

  def reload
    @config = nil
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

  def fr?
    return $options.nil? || $options.language.to_s == 'fr'
  end

  def t(fr, en = fr)
    return fr? ? fr : en
  end

  def file(name)
    return "#{DIR}#{name}"
  end

  # Nom de PNJ : texte, [fr, en] ou { fr:, en: }
  def localized(value)
    return (fr? ? value[0] : value[1] || value[0]).to_s if value.is_a?(Array)
    return (fetch(value, fr? ? 'fr' : 'en') || fetch(value, 'fr')).to_s if value.is_a?(Hash)

    return value.to_s
  end

  def npc_names
    list = Array(setting('npc_names')).map { |n| localized(n) }.reject(&:empty?)
    return list.empty? ? DEFAULTS['npc_names'].map { |n| localized(n) } : list
  end

  # @return [Array<Hash>] paliers { points, item, count } triés
  def prizes
    list = Array(config.prizes).select { |p| p.is_a?(Hash) && !fetch(p, 'item').to_s.empty? }
    list = DEFAULT_PRIZES if list.empty? && config.prizes.nil?
    return list.map { |p| { 'points' => fetch(p, 'points').to_i, 'item' => fetch(p, 'item').to_s, 'count' => [fetch(p, 'count').to_i, 1].max } }
               .sort_by { |p| p['points'] }
  end

  def prize_for(points)
    return prizes.select { |p| points >= p['points'] }.last
  end

  # Sauvegarde : { 'record' => points, 'played' => parties, 'last' => points, 'berries' => total }
  def data
    store = ($user_data ||= {})[:pj_dodrio] ||= {}
    store['record'] ||= 0
    store['played'] ||= 0
    store['last'] ||= 0
    store['berries'] ||= 0
    return store
  end

  def species
    return setting('species').to_s.empty? ? :dodrio : setting('species').to_s.to_sym
  end

  def has_dodrio?
    return true unless setting('require_dodrio')

    return $actors.any? { |pk| !pk.egg? && pk.db_symbol == species }
  end

  SOUNDS = { 'peck' => '062-swing01', 'catch' => '056-right02', 'miss' => '057-wrong01', 'bip' => '002-system02',
             'go' => '055-right01', 'end' => '059-applause01', 'level' => '060-cheer01' }.freeze

  def play_se(name)
    Audio.se_play("audio/se/#{SOUNDS[name] || name}")
  rescue StandardError
    nil
  end
end

# Lance-Ball (d'après le Poké Transfert de Pokémon Noir / Blanc)
#
# Des Pokémon se cachent dans les buissons et derrière les arbres du pré. Viser avec les flèches (ou la souris) et
# lancer une balle avec A (ou clic) quand un Pokémon se montre : touché, il est capturé. Une balle qui tombe tout près
# l'étourdit (il reste sur place un moment) ; une balle lancée sur une cachette fait sortir ceux qui s'y cachent.
# Trois captures de suite donnent une balle dorée (points doublés, zone plus large). Il faut tout capturer avant la
# fin du temps : le temps restant rapporte des points en plus. Le joueur reçoit le lot du palier de points atteint.
#
# Réglages : Data/configs/plugins/lance_ball.json (Studio : Level design > Mini-jeux > Lance-Ball)
#   settings  voir DEFAULTS
#   prizes    lots : [{ points:, item:, count: }] (le meilleur palier atteint)
module Configs
  class LanceBallConfig
    attr_accessor :settings, :prizes

    def initialize
      @settings = {}
      @prizes = []
    end
  end
  register(:lance_ball, 'plugins/lance_ball', :json, false, LanceBallConfig)
end

module LanceBall
  CONFIG_FILE = 'Data/configs/plugins/lance_ball.json'
  DIR = 'lance_ball/'
  DEFAULTS = {
    'time' => 60,              # durée en secondes
    'count' => 6,              # Pokémon à capturer (1 à 6)
    'difficulty' => 2,         # vitesse et méfiance des Pokémon (1 à 3)
    'party' => false,          # cacher les Pokémon de l'équipe du joueur (sinon la liste « pokemon »)
    'pokemon' => %w[pidove patrat lillipup purrloin pansage pansear panpour munna sewaddle venipede cottonee petilil],
    'catch_points' => 100,     # points par capture (doublés avec la balle dorée)
    'time_points' => 10,       # points par seconde restante quand tout est capturé
    'bgm' => ''                # musique (vide : celle de la carte)
  }.freeze
  DEFAULT_PRIZES = [
    { 'points' => 300, 'item' => 'poke_ball', 'count' => 5 },
    { 'points' => 600, 'item' => 'great_ball', 'count' => 5 },
    { 'points' => 900, 'item' => 'ultra_ball', 'count' => 3 },
    { 'points' => 1200, 'item' => 'quick_ball', 'count' => 3 }
  ].freeze

  module_function

  def config
    @config ||= load_config
  end

  def load_config
    return Configs.lance_ball if PSDK_CONFIG.release?
    return Configs::LanceBallConfig.new unless File.exist?(CONFIG_FILE)

    require 'json'
    data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
    cfg = Configs::LanceBallConfig.new
    data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
    return cfg
  rescue StandardError, ScriptError => e
    log_error("Lance-Ball : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
    return Configs::LanceBallConfig.new
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

  def prizes
    list = Array(config.prizes).select { |p| p.is_a?(Hash) && !fetch(p, 'item').to_s.empty? }
    list = DEFAULT_PRIZES if list.empty? && config.prizes.nil?
    return list.map { |p| { 'points' => fetch(p, 'points').to_i, 'item' => fetch(p, 'item').to_s, 'count' => [fetch(p, 'count').to_i, 1].max } }
               .sort_by { |p| p['points'] }
  end

  def prize_for(points)
    return prizes.select { |p| points >= p['points'] }.last
  end

  # Sauvegarde : { 'record', 'played', 'last', 'caught' }
  def data
    store = ($user_data ||= {})[:pj_lance_ball] ||= {}
    %w[record played last caught].each { |k| store[k] ||= 0 }
    return store
  end

  # Pokémon cachés : ceux de l'équipe (réglage party) ou tirés dans la liste
  # @return [Array<PFM::Pokemon>]
  def make_pokemon(count)
    if setting('party')
      party = $actors.reject(&:egg?)
      return party.first(count).map(&:dup) unless party.empty?
    end
    list = Array(setting('pokemon')).map(&:to_s).reject(&:empty?)
    list = DEFAULTS['pokemon'] if list.empty?
    valid = list.select { |s| (data_creature(s.to_sym).id rescue 0) > 0 }
    valid = %w[pidgey rattata] if valid.empty?
    return Array.new(count) { PFM::Pokemon.new(valid.sample.to_sym, 10) }
  end

  SOUNDS = { 'throw' => '062-swing01', 'catch' => '056-right02', 'miss' => '045-push01', 'pop' => '015-jump01',
             'bip' => '002-system02', 'go' => '055-right01', 'end' => '059-applause01', 'dizzy' => '040-knock01',
             'gold' => '060-cheer01' }.freeze

  def play_se(name)
    Audio.se_play("audio/se/#{SOUNDS[name] || name}")
  rescue StandardError
    nil
  end
end

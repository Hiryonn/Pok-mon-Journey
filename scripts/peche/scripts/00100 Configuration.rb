# encoding: utf-8
# Pêche en mini-jeu : timing (la touche) et tension (le combat de la ligne)
#
# 1. Attente : le flotteur danse sur l'eau. Tirer trop tôt (A) fait fuir le poisson.
# 2. Touche : un « ! » apparaît, il faut appuyer sur A dans le temps imparti (plus court avec les meilleures cannes).
#    Une réaction très rapide donne une prise parfaite (le combat commence avec de l'avance).
# 3. Combat : maintenir A enroule le fil (la jauge de tension monte, la jauge de progression aussi), relâcher détend le fil.
#    Quand le poisson tire (il clignote en rouge un instant avant), il faut relâcher. Tension trop forte : le fil casse.
#    Fil trop mou trop longtemps ou progression à zéro : il s'échappe. Progression pleine : il est ferré, le combat sauvage
#    de PSDK commence comme d'habitude (les poissons de la zone viennent des groupes Studio).
# Le mini-jeu se branche sur les évènements communs des cannes (Canne, Super Canne, Méga Canne) : le plugin remplace
# la condition « une touche ? » par la commande peche_minijeu. Réglage enabled = false : pêche d'origine de PSDK.
# Réglages : Data/configs/plugins/peche.json
#   settings  enabled, bgm, perfect_frames (réaction « parfaite »), perfect_bonus (progression de départ), slack_frames
#   rods      par canne (normal : Canne, super : Super Canne, mega : Méga Canne) : wait [min, max] (images avant la touche),
#             window (images pour réagir), strength (force du poisson), gain (vitesse d'enroulement), pull_gap [min, max]
#             (images entre deux tirs), pull_len [min, max] (durée d'un tir)
# Commandes d'évènement : peche_minijeu(:normal) (renvoie true si le poisson est ferré), peche_message_fait? (le mini-jeu a déjà
#   dit pourquoi il a échoué), peche_stats (prises, échecs)
module Configs
  class PecheConfig
    attr_accessor :settings, :rods

    def initialize
      @settings = {}
      @rods = {}
    end
  end
  register(:peche, 'plugins/peche', :json, false, PecheConfig)
end

module Peche
  CONFIG_FILE = 'Data/configs/plugins/peche.json'
  DEFAULTS = { 'enabled' => true, 'bgm' => '', 'perfect_frames' => 12, 'perfect_bonus' => 25, 'slack_frames' => 180,
               'reel_up' => 1.1, 'reel_down' => 0.8, 'pull_force' => 0.35, 'snap_at' => 100.0 }.freeze
  DEFAULT_RODS = {
    'normal' => { 'wait' => [60, 220], 'window' => 50, 'strength' => 0.8, 'gain' => 0.5, 'pull_gap' => [120, 210], 'pull_len' => [28, 50] },
    'super' => { 'wait' => [50, 190], 'window' => 36, 'strength' => 1.15, 'gain' => 0.6, 'pull_gap' => [95, 170], 'pull_len' => [38, 65] },
    'mega' => { 'wait' => [40, 160], 'window' => 26, 'strength' => 1.5, 'gain' => 0.72, 'pull_gap' => [80, 150], 'pull_len' => [40, 70] }
  }.freeze
  SOUNDS = { 'bite' => '015-jump01', 'hook' => '056-right02', 'splash' => '045-push01', 'snap' => '040-knock01',
             'win' => '059-applause01', 'bip' => '002-system02' }.freeze

  module_function

  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.peche
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::PecheConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::PecheConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Pêche : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::PecheConfig.new
    end
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
    return value.nil? ? DEFAULTS[key.to_s] : value
  end

  # @param type [Symbol] :normal, :super, :mega
  # @return [Hash]
  def rod(type)
    custom = fetch(config.rods, type)
    base = DEFAULT_RODS[type.to_s] || DEFAULT_RODS['normal']
    return custom.is_a?(Hash) ? base.merge(custom.transform_keys(&:to_s)) : base
  end

  def fr?
    return $options.nil? || $options.language.to_s == 'fr'
  end

  def t(fr, en = fr)
    return fr? ? fr : en
  end

  def play_se(name)
    Audio.se_play("audio/se/#{SOUNDS[name] || name}")
  rescue StandardError
    nil
  end

  # Sauvegarde : { 'caught', 'lost', 'perfect', 'best' (meilleure réaction, en images) }
  def data
    store = ($user_data ||= {})[:pj_peche] ||= {}
    %w[caught lost perfect].each { |k| store[k] ||= 0 }
    return store
  end

  def enabled?
    return setting('enabled') != false
  end

  # Combat de tension (sans affichage : testable seul)
  class Reel
    attr_reader :tension, :progress, :mode, :result, :frames

    # @param rod [Hash] réglages de la canne
    # @param start [Float] progression de départ (prise parfaite)
    def initialize(rod, start = 0.0)
      @rod = rod
      @strength = Peche.fetch(rod, 'strength').to_f * (0.85 + rand * 0.3)
      @gain = Peche.fetch(rod, 'gain').to_f
      @tension = 40.0
      @progress = start.to_f.clamp(0, 99)
      @mode = :calm       # :calm, :warn (avertissement), :pull
      @timer = range('pull_gap')
      @slack = 0
      @result = nil
      @frames = 0
    end

    def range(key)
      low, high = Array(Peche.fetch(@rod, key)).map(&:to_i)
      return rand((low || 60)..([high || low || 60, low || 60].max))
    end

    # @param pressed [Boolean] A est maintenu
    def step(pressed)
      return if @result

      @frames += 1
      update_mode
      @tension += pressed ? Peche.setting('reel_up').to_f : -Peche.setting('reel_down').to_f
      @tension += Peche.setting('pull_force').to_f * @strength * 1.6 if @mode == :pull
      @tension = @tension.clamp(0.0, 110.0)
      if pressed
        @progress += @gain * (@tension >= 20 ? 1.0 : 0.4)
      else
        @progress -= 0.1 * @strength
      end
      @progress -= 0.12 * @strength if @mode == :pull
      @progress = @progress.clamp(0.0, 100.0)
      slack_limit = Peche.setting('slack_frames').to_i
      @slack = @tension < 8 ? @slack + 1 : 0
      @result = :snap if @tension >= Peche.setting('snap_at').to_f
      @result ||= :slack if @slack >= slack_limit
      @result ||= :escape if @progress <= 0.0 && @frames > 30
      @result ||= :win if @progress >= 100.0
    end

    def update_mode
      @timer -= 1
      return unless @timer <= 0

      case @mode
      when :calm
        @mode = :warn
        @timer = 28
      when :warn
        @mode = :pull
        @timer = range('pull_len')
      else
        @mode = :calm
        @timer = range('pull_gap')
      end
    end
  end
end

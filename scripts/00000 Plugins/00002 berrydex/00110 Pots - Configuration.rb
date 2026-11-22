# Berrydex : pots à baies (d'après « BerryPots for Essentials » de Caruban, refait pour PSDK). Fichiers 00110 à 00112
# du plugin berrydex (ancien plugin pots_baies).
#
# Des pots qu'on emporte partout pour faire pousser des baies : objet « Pots à Baies » (berry_pots) du sac ou commande
# pots_a_baies. Les pots poussent avec le temps du jeu comme les baies de PSDK : leurs données sont rangées avec les
# autres baies (PFM.game_state.berries[:pots_baies][numéro du pot]), et c'est PSDK qui les fait grandir et sécher.
#   [baie, stade (0 graine .. 4 mûre), minutes avant le stade suivant, minutes par stade, humidité restante,
#    durée de l'humidité, nombre d'arrosages, engrais]
# Réglages faits dans Studio (Données > Baies > Pots à baies) : Data/configs/plugins/pots_baies.json
#   settings  initial_pots, max_pots, growth_speed (%), water_for_max (arrosages pour la récolte max), need_can,
#             mulch_enabled, show_time, harvest_me, water_se, plant_se
#   cans      [{ item:, image: }] arrosoirs reconnus, dans l'ordre (image : graphics/interface/pots_baies/cans)
#   mulches   { engrais => { growth: %, water: %, bonus: baies en plus } }
#   excluded  [baies qui ne poussent pas en pot]
module Configs
  class PotsBaiesConfig
    attr_accessor :settings, :cans, :mulches, :excluded

    def initialize
      @settings = {}
      @cans = []
      @mulches = {}
      @excluded = []
    end
  end
  register(:pots_baies, 'plugins/pots_baies', :json, false, PotsBaiesConfig)
end

module PotsBaies
  CONFIG_FILE = 'Data/configs/plugins/pots_baies.json'
  DIR = 'pots_baies/'
  # Clé des pots dans PFM.game_state.berries (aucune carte n'a cet identifiant)
  KEY = :pots_baies
  MAX_POTS = 10
  DEFAULTS = {
    'initial_pots' => 4, 'max_pots' => 10, 'growth_speed' => 100, 'water_for_max' => 4, 'need_can' => true,
    'mulch_enabled' => true, 'show_time' => true, 'harvest_me' => 'audio/me/obtained a berry!',
    'water_se' => 'audio/se/se_gui_berrypots_water', 'plant_se' => 'audio/se/se_gui_berrypots_plant'
  }.freeze
  DEFAULT_CANS = [
    { 'item' => 'wailmer_pail', 'image' => 'wailmer_pail' }, { 'item' => 'sprinklotad', 'image' => 'sprinklotad' },
    { 'item' => 'squirt_bottle', 'image' => 'squirt_bottle' }, { 'item' => 'sprayduck', 'image' => 'sprayduck' }
  ].freeze
  DEFAULT_MULCHES = {
    'growth_mulch' => { 'growth' => 75, 'water' => 75, 'bonus' => 0 },
    'damp_mulch' => { 'growth' => 150, 'water' => 150, 'bonus' => 0 },
    'rich_mulch' => { 'growth' => 100, 'water' => 100, 'bonus' => 2 }
  }.freeze
  # Stades : texte du stade (français, anglais)
  STAGES = [
    ['Une %s a été plantée ici.', 'A %s was planted here.'],
    ['La %s a germé.', 'The %s has sprouted.'],
    ['Le plant de %s grandit.', 'The %s plant is growing bigger.'],
    ['Le plant de %s est en fleur !', 'This %s plant is in bloom!'],
    ['', '']
  ].freeze
  STAGE_NAMES = [%w[Graine Seed], %w[Germe Sprout], %w[Pousse Growing], ['En fleur', 'Blooming'], ['Prête !', 'Ready!']].freeze

  module_function

  # @return [Configs::PotsBaiesConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.pots_baies
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::PotsBaiesConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::PotsBaiesConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Pots à baies : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::PotsBaiesConfig.new
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

  def setting?(key)
    return setting(key) == true
  end

  def french?
    return !($options && $options.language.to_s != 'fr')
  end

  def t(fr, en = fr)
    return french? ? fr : en
  end

  def file(name)
    return "#{DIR}#{name}"
  end

  # --- Pots --------------------------------------------------------------------------------------
  def state
    return ($user_data[:pots_baies] ||= {})
  end

  # Nombre de pots du joueur
  def count
    max = setting(:max_pots).to_i.clamp(1, MAX_POTS)
    state[:count] ||= setting(:initial_pots).to_i
    return state[:count].clamp(0, max)
  end

  # Donne des pots en plus (jusqu'au maximum)
  # @return [Boolean] false si le joueur a déjà le maximum
  def add_pots(amount = 1)
    max = setting(:max_pots).to_i.clamp(1, MAX_POTS)
    return false if count >= max

    state[:count] = (count + amount.to_i).clamp(0, max)
    return true
  end

  # Données de tous les pots (rangées avec les baies de PSDK pour pousser avec elles)
  # @return [Hash{Integer => Array}]
  def pots
    berries = (PFM.game_state.berries ||= {})
    return berries[KEY] ||= {}
  end

  # Données d'un pot (créées vides au besoin)
  # @return [Array]
  def pot(index)
    return pots[index] ||= Array.new(8, 0)
  end

  def planted?(data)
    return data && data[0].to_i != 0
  end

  def ripe?(data)
    return planted?(data) && data[1].to_i >= 4
  end

  # Humidité du sol : 0 sec, 1 humide, 2 mouillé
  def moisture(data)
    return 0 unless planted?(data) && data[4].to_i > 0
    return data[4].to_i * 2 > data[5].to_i ? 2 : 1
  end

  # Minutes de jeu avant que la baie soit mûre (nil si elle l'est déjà ou si le pot est vide)
  def minutes_left(data)
    return nil unless planted?(data) && data[1].to_i < 4

    return [data[2].to_i, 0].max + (3 - data[1].to_i) * data[3].to_i
  end

  def time_text(minutes)
    return '' unless minutes
    return t("≈ #{minutes} min", "≈ #{minutes} min") if minutes < 60

    hours = (minutes / 60.0).round
    return t("≈ #{hours} h", "≈ #{hours} h")
  end

  # --- Baies, arrosoirs, engrais -----------------------------------------------------------------
  def item(id)
    return data_item(id)
  rescue StandardError
    return nil
  end

  def item_name(id)
    data = item(id)
    return data ? data.name : id.to_s
  end

  # La baie peut-elle être plantée en pot ?
  def plantable?(id)
    data = item(id)
    return false unless data&.is_berry && data.berry_data
    return !Array(config.excluded).map(&:to_s).include?(data.db_symbol.to_s)
  end

  # Arrosoirs reconnus (réglages, ou ceux d'Essentials par défaut)
  # @return [Array<Hash>] { 'item' =>, 'image' => }
  def can_list
    list = Array(config.cans).select { |c| c.is_a?(Hash) && !fetch(c, :item).to_s.empty? }
    list = DEFAULT_CANS if list.empty?
    return list.map { |c| { 'item' => fetch(c, :item).to_s, 'image' => (fetch(c, :image) || fetch(c, :item)).to_s } }
  end

  # Arrosoirs que le joueur a dans son sac
  def owned_cans
    return can_list.select { |c| $bag.contain_item?(c['item'].to_sym) }
  rescue StandardError
    return []
  end

  # Engrais reconnus { symbole => effets }
  def mulch_list
    list = config.mulches.is_a?(Hash) && !config.mulches.empty? ? config.mulches : DEFAULT_MULCHES
    return list.to_h { |sym, effect| [sym.to_s, effect.is_a?(Hash) ? effect : {}] }
  end

  def mulch_effect(id, key, default)
    return default if id.to_i == 0

    sym = item(id)&.db_symbol.to_s
    value = fetch(mulch_list[sym], key)
    return value.nil? ? default : value.to_i
  end

  def owned_mulches
    return mulch_list.keys.select { |sym| item(sym.to_sym) && $bag.contain_item?(sym.to_sym) }
  rescue StandardError
    return []
  end

  # --- Actions sur un pot ------------------------------------------------------------------------
  # Plante une baie (le sac n'est pas touché ici)
  def plant(index, berry)
    data = item(berry)
    return false unless data&.is_berry && data.berry_data

    pot_data = pot(index)
    mulch = pot_data[7].to_i
    speed = [setting(:growth_speed).to_i, 1].max
    stage_time = data.berry_data.growth * 15 * 100.0 / speed * mulch_effect(mulch, :growth, 100) / 100.0
    water_time = data.berry_data.drain_rate * 60 * mulch_effect(mulch, :water, 100) / 100.0
    pot_data[0] = data.id
    pot_data[1] = 0
    pot_data[3] = [stage_time.round, 1].max
    pot_data[2] = pot_data[3]
    pot_data[4] = 0
    pot_data[5] = [water_time.round, 1].max
    pot_data[6] = 0
    pot_data[7] = mulch
    seen[index] = 0
    return true
  end

  def water(index)
    data = pot(index)
    return false unless planted?(data) && !ripe?(data)

    data[4] = data[5]
    data[6] = data[6].to_i + 1
    return true
  end

  def lay_mulch(index, mulch)
    data = pot(index)
    return false if planted?(data)

    data[7] = item(mulch)&.id.to_i
    return true
  end

  # Nombre de baies à cueillir (comme PSDK : plus on a arrosé, plus il y en a, plus le bonus de l'engrais)
  def harvest_amount(data)
    berry = item(data[0])&.berry_data
    return 1 unless berry

    full = [setting(:water_for_max).to_i, 1].max
    waterings = [data[6].to_i, full].min
    amount = berry.min_yield + (berry.max_yield - berry.min_yield) * waterings / full
    return [amount + mulch_effect(data[7], :bonus, 0), 1].max
  end

  # Vide le pot après la récolte
  def clear(index)
    pots[index] = Array.new(8, 0)
    seen.delete(index)
  end

  # Stade vu la dernière fois (pour faire briller les pots qui ont grandi)
  def seen
    return (state[:seen] ||= {})
  end

  # Nombre de pots prêts à être cueillis
  def ripe_count
    return Array.new(count) { |i| pots[i] }.count { |d| ripe?(d) }
  end
end

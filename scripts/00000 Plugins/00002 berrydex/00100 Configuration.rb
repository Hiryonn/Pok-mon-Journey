# Berrydex (d'après « TDW Berry Core and Dex » d'Essentials) : encyclopédie des baies, aux couleurs du Pokédex Horizon
#
# Les baies sont les objets « baie » de Studio (Données > Objets) : taille, fermeté, saveurs, pousse, récolte,
# Don Naturel… viennent de leur fiche. Le reste se règle dans Studio (Données > Baies > Berrydex) :
# Data/configs/plugins/berrydex.json
#   show_unknown  les baies pas encore trouvées sont listées en « ????? » (sinon elles sont cachées)
#   numbering     id (ordre des objets) ou order (ordre choisi dans Studio, liste « order »)
#   berries       { baie => { hidden:, weathers: [], zones: [], unpref_zones: [], soil:, effect: { fr:, en: } } }
#                 (soil : sol préféré pour les champs de baies, voir 00120 Champs - Configuration.rb)
# Une baie est « trouvée » dès qu'elle entre dans le sac (ou avec berrydex_enregistrer).
# Graphismes : graphics/interface/berrydex/ (tools/berrydex/build_berrydex_assets.py)
module Configs
  class BerrydexConfig
    attr_accessor :show_unknown, :numbering, :order, :berries

    def initialize
      @show_unknown = true
      @numbering = 'id'
      @order = []
      @berries = {}
    end
  end
  register(:berrydex, 'plugins/berrydex', :json, false, BerrydexConfig)
end

module Berrydex
  CONFIG_FILE = 'Data/configs/plugins/berrydex.json'
  DIR = 'berrydex/'
  # Météos et lieux connus (images weather/<nom>.png)
  WEATHERS = %w[sun rain heavyrain storm snow blizzard sandstorm fog].freeze
  ZONES = %w[field city desert].freeze
  WEATHER_NAMES = {
    'sun' => %w[Soleil Sun], 'rain' => %w[Pluie Rain], 'heavyrain' => ['Forte pluie', 'Heavy rain'], 'storm' => %w[Orage Storm],
    'snow' => %w[Neige Snow], 'blizzard' => %w[Blizzard Blizzard], 'sandstorm' => ['Tempête de sable', 'Sandstorm'],
    'fog' => %w[Brouillard Fog], 'field' => %w[Prairie Field], 'city' => %w[Ville City], 'desert' => %w[Désert Desert]
  }.freeze
  FIRMNESS = {
    very_soft: ['Très tendre', 'Very soft'], soft: %w[Tendre Soft], hard: %w[Dure Hard], very_hard: ['Très dure', 'Very hard'],
    super_hard: ['Super dure', 'Super hard']
  }.freeze
  # Saveurs : clé, champ de Studio, [français, anglais]
  FLAVORS = [[:spicy, :spicy_flavor, %w[Épicé Spicy]], [:dry, :dry_flavor, %w[Sec Dry]], [:sweet, :sweet_flavor, %w[Sucré Sweet]],
             [:bitter, :bitter_flavor, %w[Amer Bitter]], [:sour, :sour_flavor, %w[Acide Sour]]].freeze

  module_function

  # @return [Configs::BerrydexConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.berrydex
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::BerrydexConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::BerrydexConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Berrydex : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::BerrydexConfig.new
    end
  end

  def reload
    @config = nil
    @list = nil
  end

  # @param hash [Hash, nil]
  def fetch(hash, key)
    return nil unless hash.is_a?(Hash)

    value = hash[key.to_s]
    return value.nil? ? hash[key.to_sym] : value
  end

  # Réglages d'une baie (Studio)
  # @return [Hash]
  def settings(db_symbol)
    return fetch(config.berries, db_symbol) || {}
  end

  # Baies du Berrydex, dans l'ordre (cachées dans Studio exclues)
  # @return [Array<Symbol>]
  def list
    return @list if @list

    all = []
    each_data_item { |item| all << item if item.is_berry && item.db_symbol != :__undef__ }
    all.sort_by!(&:id)
    symbols = all.map(&:db_symbol)
    if config.numbering.to_s == 'order' && config.order.is_a?(Array) && !config.order.empty?
      ordered = config.order.map(&:to_sym) & symbols
      symbols = ordered + (symbols - ordered)
    end
    @list = symbols.reject { |db| fetch(settings(db), :hidden) == true }
    return @list
  rescue StandardError
    return @list = []
  end

  # @return [Integer] numéro dans le Berrydex (1, 2…)
  def number(db_symbol)
    return (list.index(db_symbol.to_sym) || -1) + 1
  end

  # Données de sauvegarde : baies trouvées
  # @return [Hash{Symbol => Boolean}]
  def found_data
    return {} unless $user_data

    return $user_data[:pj_berrydex] ||= {}
  end

  def found?(db_symbol)
    return found_data[db_symbol.to_sym] == true
  end

  # Marque une baie comme trouvée
  def register(db_symbol)
    db_symbol = data_item(db_symbol).db_symbol if db_symbol.is_a?(Integer)
    return false unless data_item(db_symbol).is_berry

    found_data[db_symbol.to_sym] = true
    return true
  rescue StandardError
    return false
  end

  # Baies déjà dans le sac (parties commencées avant le Berrydex)
  def register_bag
    return unless $bag

    list.each { |db| register(db) if $bag.contain_item?(db) }
  rescue StandardError
    nil
  end

  # @return [Integer]
  def found_count
    return list.count { |db| found?(db) }
  end

  # Texte selon la langue
  def t(fr, en = fr)
    return $options && $options.language.to_s != 'fr' ? en : fr
  end

  # @param pair [Array<String>] [français, anglais]
  def tr(pair)
    return t(pair[0], pair[1] || pair[0])
  end

  # Texte réglé dans Studio ({ fr:, en: }) ou nil
  def localized(hash)
    return nil unless hash.is_a?(Hash)

    value = fetch(hash, $options&.language || 'fr')
    value = fetch(hash, :fr) if value.to_s.empty?
    value = fetch(hash, :en) if value.to_s.empty?
    return value.to_s.empty? ? nil : value.to_s
  end

  # Effet en combat (Studio) ou description de l'objet
  def effect_text(db_symbol)
    return localized(fetch(settings(db_symbol), :effect)) || data_item(db_symbol).descr.to_s
  end

  # @return [Array<String>]
  def weathers(db_symbol)
    return Array(fetch(settings(db_symbol), :weathers)).map(&:to_s) & WEATHERS
  end

  # Lieux : [[nom, préféré ?]]
  # @return [Array<Array(String, Boolean)>]
  def zones(db_symbol)
    s = settings(db_symbol)
    pref = Array(fetch(s, :zones)).map(&:to_s) & ZONES
    unpref = Array(fetch(s, :unpref_zones)).map(&:to_s) & ZONES
    return pref.map { |z| [z, true] } + (unpref - pref).map { |z| [z, false] }
  end

  # @return [String]
  def file(name)
    return "#{DIR}#{name}"
  end

  # Image de l'étiquette de la baie (sinon icône de l'objet)
  def tag_file(db_symbol)
    name = file("tags/#{db_symbol}")
    return RPG::Cache.interface_exist?(name) ? name : nil
  end

  # Nombre avec virgule (3,5)
  def decimal(value)
    text = format('%.1f', value.to_f).sub(/\.0\z/, '')
    return t(text.tr('.', ','), text)
  end
end

module PFM
  class Bag
    # Une baie qui entre dans le sac est « trouvée » dans le Berrydex
    module BerrydexRegister
      def add_item(db_symbol, nb = 1)
        result = super
        Berrydex.register(db_symbol) if nb.to_i > 0 && !@locked
        return result
      end
    end
    prepend BerrydexRegister
  end
end

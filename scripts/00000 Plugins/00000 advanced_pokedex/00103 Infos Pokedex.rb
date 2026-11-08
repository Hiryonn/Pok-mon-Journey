# Advanced Pokédex : couleur, habitat et génération des Pokémon
#
# Réglés dans Pokémon Studio : page Pokémon, bloc « Couleur, habitat, génération » (à côté du bloc Pokédex).
# Fichier : Data/configs/plugins/pokedex_infos.json
#   { "creatures": { "bulbasaur": { "color": "green", "habitat": "grassland", "generation": 1,
#                                   "forms": { "1": { "color": "…" } } } } }
# Une forme reprend les valeurs de l'espèce sauf celles qu'elle redéfinit.
# Génération 0 = Fakemon ; sans génération choisie : celle du n° national (1 à 1025), 0 au-delà.
#
# En jeu :
#   PokedexInfos.color(:bulbasaur)        -> :green        PokedexInfos.color_name(:bulbasaur) -> "Vert"
#   PokedexInfos.habitat(:bulbasaur)      -> :grassland    PokedexInfos.habitat_name(:bulbasaur) -> "Plaine"
#   PokedexInfos.generation(:bulbasaur)   -> 1             PokedexInfos.fakemon?(:my_fakemon) -> true
#   pokemon.dex_color / dex_habitat / dex_generation / fakemon?
#   PokedexInfos.creatures(color: :green, generation: 1) -> liste des db_symbol correspondants
module Configs
  # Contenu de Data/configs/plugins/pokedex_infos.json
  class PokedexInfosConfig
    attr_accessor :creatures

    def initialize
      @creatures = {}
    end
  end
  register(:pokedex_infos, 'plugins/pokedex_infos', :json, false, PokedexInfosConfig)
end

module PokedexInfos
  CONFIG_FILE = 'Data/configs/plugins/pokedex_infos.json'
  # Couleurs du Pokédex [français, anglais]
  COLORS = {
    red: %w[Rouge Red], blue: %w[Bleu Blue], yellow: %w[Jaune Yellow], green: %w[Vert Green], black: %w[Noir Black],
    brown: %w[Marron Brown], purple: %w[Violet Purple], gray: %w[Gris Gray], white: %w[Blanc White], pink: %w[Rose Pink]
  }.freeze
  # Habitats [français, anglais] (un habitat personnalisé fait dans Studio garde son nom)
  HABITATS = {
    grassland: %w[Plaine Grassland], forest: %w[Forêt Forest], 'waters-edge': ["Bord de l'eau", "Water's edge"],
    sea: %w[Mer Sea], cave: %w[Grotte Cave], mountain: %w[Montagne Mountain],
    'rough-terrain': ['Terrain accidenté', 'Rough terrain'], urban: %w[Ville Urban], rare: %w[Rare Rare]
  }.freeze
  # Dernier n° national de chaque génération
  GENERATION_LAST_ID = [151, 251, 386, 493, 649, 721, 809, 905, 1025].freeze

  module_function

  # @return [Hash{String => Hash}] données par db_symbol (clés en texte)
  def data
    @data ||= begin
      config = PSDK_CONFIG.release? || File.exist?(CONFIG_FILE) ? Configs.pokedex_infos : Configs::PokedexInfosConfig.new
      deep_stringify(config.creatures || {})
    rescue StandardError, ScriptError => e
      log_error("Infos Pokédex : fichier illisible (#{e.message})") if respond_to?(:log_error, true)
      {}
    end
  end

  # Relit le fichier
  def reload
    @data = nil
  end

  # Valeurs d'une forme (avec celles de l'espèce)
  # @param db_symbol [Symbol, String]
  # @param form [Integer]
  # @return [Hash] 'color', 'habitat', 'generation'
  def entry(db_symbol, form = 0)
    base = data[db_symbol.to_s] || {}
    own = (base['forms'] || {})[form.to_i.to_s] || {}
    return %w[color habitat generation].to_h do |key|
      value = own.key?(key) && own[key].to_s != '' ? own[key] : base[key]
      [key, value]
    end
  end

  # @return [Symbol, nil]
  def color(db_symbol, form = 0)
    value = entry(db_symbol, form)['color'].to_s
    return value.empty? ? nil : value.to_sym
  end

  # @return [Symbol, nil]
  def habitat(db_symbol, form = 0)
    value = entry(db_symbol, form)['habitat'].to_s
    return value.empty? ? nil : value.to_sym
  end

  # @return [Integer] génération (0 = Fakemon)
  def generation(db_symbol, form = 0)
    value = entry(db_symbol, form)['generation']
    return value.to_i unless value.nil? || value.to_s == ''

    return auto_generation(db_symbol)
  end

  # Génération d'après le n° national (0 au-delà du 1025)
  # @return [Integer]
  def auto_generation(db_symbol)
    id = data_creature(db_symbol.to_sym).id
    index = GENERATION_LAST_ID.index { |last| id <= last }
    return id > 0 && index ? index + 1 : 0
  rescue StandardError
    return 0
  end

  # @return [Boolean]
  def fakemon?(db_symbol, form = 0)
    return generation(db_symbol, form) == 0
  end

  # @return [String] nom de la couleur ('' si aucune)
  def color_name(db_symbol, form = 0)
    return label(COLORS, color(db_symbol, form))
  end

  # @return [String] nom de l'habitat ('' si aucun)
  def habitat_name(db_symbol, form = 0)
    return label(HABITATS, habitat(db_symbol, form))
  end

  # Pokémon correspondant aux critères (forme 0)
  # @param color [Symbol, nil]
  # @param habitat [Symbol, nil]
  # @param generation [Integer, nil]
  # @return [Array<Symbol>]
  def creatures(color: nil, habitat: nil, generation: nil)
    return each_data_creature.map(&:db_symbol).select do |db_symbol|
      (color.nil? || self.color(db_symbol) == color.to_sym) &&
        (habitat.nil? || self.habitat(db_symbol) == habitat.to_sym) &&
        (generation.nil? || self.generation(db_symbol) == generation.to_i)
    end
  end

  # @param list [Hash]
  # @param key [Symbol, nil]
  # @return [String]
  def label(list, key)
    return '' unless key

    names = list[key]
    return key.to_s.tr('-_', '  ').capitalize unless names

    return names[$options && $options.language.to_s != 'fr' ? 1 : 0]
  end

  # @param value [Object]
  # @return [Object] même valeur avec des clés en texte
  def deep_stringify(value)
    return value.to_h { |k, v| [k.to_s, deep_stringify(v)] } if value.is_a?(Hash)

    return value
  end
end

module PFM
  class Pokemon
    # @return [Symbol, nil] couleur du Pokédex (Studio : Couleur, habitat, génération)
    def dex_color
      return PokedexInfos.color(db_symbol, form)
    end

    # @return [Symbol, nil] habitat
    def dex_habitat
      return PokedexInfos.habitat(db_symbol, form)
    end

    # @return [Integer] génération (0 = Fakemon)
    def dex_generation
      return PokedexInfos.generation(db_symbol, form)
    end

    # @return [Boolean]
    def fakemon?
      return dex_generation == 0
    end
  end
end

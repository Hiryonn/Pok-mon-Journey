# Variantes : Pokémon Argentés, Dorés et Radiants
#
# Argenté / Doré : le sprite normal est recoloré en jeu (tout argent / tout or), aucune image à faire.
# Radiant : sprites recolorés dans Pokémon Studio (Plugins > Variantes), enregistrés dans
#   graphics/pokedex/pokefrontradiant, pokebackradiant et pokeiconradiant (même nom que le sprite normal).
#   Un Pokémon sans sprite Radiant ne peut pas être Radiant.
#
# Réglages : Data/configs/plugins/variantes.json (édité dans Studio)
#   silver_rate / gold_rate / radiant_rate : 1 chance sur N (0 = jamais)
#   count_as_shiny : une variante compte aussi comme chromatique (étoile, scintillement en combat)
#   silver_colors / gold_colors : dégradé du plus sombre au plus clair ("#rrggbb")
#   radiant : recolorations faites dans Studio (Studio seulement, le jeu lit les images)
module Configs
  # Contenu de Data/configs/plugins/variantes.json
  class VariantesConfig
    attr_accessor :silver_rate, :gold_rate, :radiant_rate, :count_as_shiny, :silver_colors, :gold_colors, :radiant

    def initialize
      @silver_rate = 8192
      @gold_rate = 8192
      @radiant_rate = 4096
      @count_as_shiny = true
      @silver_colors = %w[#22242f #6a7082 #b7bdcc #f6f8ff]
      @gold_colors = %w[#3c2204 #a2680e #e6b232 #fff4a6]
      @radiant = []
    end
  end
  register(:variantes, 'plugins/variantes', :json, false, VariantesConfig)
end

module Variantes
  CONFIG_FILE = 'Data/configs/plugins/variantes.json'
  # Variantes, de la plus rare à la plus commune (ordre du tirage)
  LIST = %i[radiant gold silver].freeze
  # Noms affichés [français, anglais]
  NAMES = { silver: %w[Argenté Silver], gold: %w[Doré Golden], radiant: %w[Radiant Radiant] }.freeze
  # Dossiers des sprites Radiants (faits dans Studio)
  RADIANT_DIRS = {
    front: 'graphics/pokedex/pokefrontradiant',
    back: 'graphics/pokedex/pokebackradiant',
    icon: 'graphics/pokedex/pokeiconradiant'
  }.freeze

  module_function

  # @return [Configs::VariantesConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release? || File.exist?(CONFIG_FILE)
        Configs.variantes
      else
        Configs::VariantesConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Variantes : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::VariantesConfig.new
    end
  end

  # @param variant [Symbol]
  # @return [Integer] 1 chance sur N (0 = jamais)
  def rate(variant)
    return config.send(:"#{variant}_rate").to_i
  rescue StandardError
    return 0
  end

  # @return [Boolean]
  def count_as_shiny?
    return config.count_as_shiny != false
  end

  # @param variant [Symbol, nil]
  # @return [String]
  def name(variant)
    names = NAMES[variant]
    return '' unless names

    return names[$options && $options.language.to_s != 'fr' ? 1 : 0]
  rescue StandardError
    return names ? names[0] : ''
  end

  # @param variant [Symbol] :silver ou :gold
  # @return [Array<Array<Integer>>] dégradé [[r, g, b], …] du plus sombre au plus clair
  def gradient(variant)
    defaults = Configs::VariantesConfig.new.send(:"#{variant}_colors")
    list = config.send(:"#{variant}_colors")
    list = defaults unless list.is_a?(Array) && list.size >= 2
    return list.map { |hex| hex_to_rgb(hex) }.compact
  rescue StandardError
    return defaults.map { |hex| hex_to_rgb(hex) }
  end

  # @param hex [String] "#rrggbb"
  # @return [Array<Integer>, nil]
  def hex_to_rgb(hex)
    value = hex.to_s.delete('#')
    return nil unless value.match?(/\A\h{6}\z/)

    return [value[0, 2].hex, value[2, 2].hex, value[4, 2].hex]
  end
end

# Statuts : nouveaux statuts (Saignement…), réglés dans Studio (Données > Statuts)
#
# Data/configs/plugins/statuts.json :
#   statuses [{
#     id          symbole du statut (bleeding)
#     number      numéro du statut dans la partie (10, 11… ; 1 à 9 : statuts de base)
#     name        { fr, en } nom affiché
#     short       { fr, en, es } abréviation de l'icône (graphics/interface/statuts<langue>.png, ligne = number)
#     color       couleur de l'icône et de la teinte du Pokémon en combat (#rrggbb)
#     stats       { atk, dfe, ats, dfs, spd } diviseurs (1 = rien, 1.5 = stat divisée par 1,5)
#     damage      dégâts à la fin de chaque tour : 1/damage des PV max (0 = aucun)
#     immune_types [types] types qui ne peuvent pas avoir ce statut
#     catch_rate  bonus de capture (1.5 comme le poison)
#     moves       [{ move, chance }] attaques qui l'infligent (chance en %, en plus de leurs effets)
#     messages    { inflict, already, damage, cure, immune } => { fr, en } ; [nom] = nom du Pokémon
#   }]
module Configs
  # Contenu de Data/configs/plugins/statuts.json
  class StatutsConfig
    attr_accessor :statuses

    def initialize
      @statuses = []
    end
  end
  register(:statuts, 'plugins/statuts', :json, false, StatutsConfig)
end

module Statuts
  CONFIG_FILE = 'Data/configs/plugins/statuts.json'
  # Statut fourni d'office (si Studio n'a encore rien enregistré)
  DEFAULTS = [
    {
      id: 'bleeding', number: 10, name: { fr: 'Saignement', en: 'Bleeding' }, short: { fr: 'SAI', en: 'BLD', es: 'SAN' },
      color: '#b3123a', stats: { atk: 1, dfe: 1.5, ats: 1, dfs: 1, spd: 1 }, damage: 16, immune_types: [], catch_rate: 1.5,
      moves: [],
      messages: {
        inflict: { fr: '[nom] saigne !', en: '[nom] is bleeding!' },
        already: { fr: '[nom] saigne déjà !', en: '[nom] is already bleeding!' },
        damage: { fr: '[nom] perd des PV à cause du saignement !', en: '[nom] is hurt by its bleeding!' },
        cure: { fr: '[nom] ne saigne plus !', en: '[nom] stopped bleeding!' },
        immune: { fr: 'Ça n’affecte pas [nom]…', en: 'It doesn’t affect [nom]…' }
      }
    }
  ].freeze
  STATS = %i[atk dfe ats dfs spd].freeze

  # Un statut du projet
  class Definition
    attr_reader :symbol, :number, :names, :color, :stats, :damage, :immune_types, :catch_rate, :moves, :messages

    # @param data [Hash]
    def initialize(data)
      g = ->(key) { Statuts.fetch(data, key) }
      @symbol = g.call(:id).to_s.to_sym
      @number = g.call(:number).to_i
      @names = g.call(:name) || {}
      @color = (g.call(:color) || '#b3123a').to_s
      raw = g.call(:stats) || {}
      @stats = STATS.to_h do |s|
        v = Statuts.fetch(raw, s).to_f
        [s, v > 0 ? v : 1.0]
      end
      @damage = g.call(:damage).to_i
      @immune_types = Array(g.call(:immune_types)).map { |t| t.to_s.to_sym }
      @catch_rate = (g.call(:catch_rate) || 1).to_f
      @moves = Array(g.call(:moves)).to_h { |m| [Statuts.fetch(m, :move).to_s.to_sym, Statuts.fetch(m, :chance).to_i] }
      @messages = g.call(:messages) || {}
    end

    # @return [String]
    def name
      return Statuts.localized(@names) || @symbol.to_s
    end

    # Message avec le nom du Pokémon
    # @param key [Symbol] :inflict, :already, :damage, :cure, :immune
    # @param pokemon [PFM::Pokemon]
    # @return [String]
    def message(key, pokemon)
      text = Statuts.localized(Statuts.fetch(@messages, key)) || Statuts.localized(Statuts.fetch(Statuts.fetch(DEFAULTS.first, :messages), key)) || ''
      return text.gsub('[nom]', Statuts.pokemon_name(pokemon))
    end

    # Couleur en [r, g, b] de 0 à 1
    # @return [Array<Float>]
    def rgb
      hex = @color.delete('#')
      hex = 'b3123a' unless hex.match?(/\A\h{6}\z/)
      return [0, 2, 4].map { |i| hex[i, 2].to_i(16) / 255.0 }
    end
  end

  module_function

  # @param hash [Hash, nil]
  # @param key [Symbol]
  def fetch(hash, key)
    return nil unless hash.is_a?(Hash)

    value = hash[key.to_sym]
    return value.nil? ? hash[key.to_s] : value
  end

  # @param hash [Hash, String, nil] { fr:, en: }
  # @return [String, nil]
  def localized(hash)
    return hash if hash.is_a?(String)
    return nil unless hash.is_a?(Hash)

    lang = $options&.language || 'fr'
    value = fetch(hash, lang)
    value = fetch(hash, :en) if value.to_s.empty?
    value = fetch(hash, :fr) if value.to_s.empty?
    return value.to_s.empty? ? nil : value.to_s
  end

  # Nom du Pokémon dans les messages de combat (« ennemi » / « sauvage » comme les textes de PSDK)
  # @param pokemon [PFM::Pokemon]
  # @return [String]
  def pokemon_name(pokemon)
    name = pokemon.given_name
    return name unless pokemon.is_a?(PFM::PokemonBattler) && PFM::Text.send(:enemy_pokemon?, pokemon)

    fr = ($options&.language || 'fr') == 'fr'
    if $game_temp&.trainer_battle
      return fr ? "#{name} ennemi" : "The opposing #{name}"
    end

    return fr ? "#{name} sauvage" : "The wild #{name}"
  rescue StandardError
    return pokemon.given_name
  end

  # @return [Array<Definition>]
  def list
    return @list if @list

    data = nil
    begin
      config = PSDK_CONFIG.release? || File.exist?(CONFIG_FILE) ? Configs.statuts : nil
      data = config&.statuses
    rescue StandardError, ScriptError => e
      log_error("Statuts : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
    end
    data = DEFAULTS if data.nil?
    @list = Array(data).map { |d| Definition.new(d) }.select { |d| d.number >= 10 && d.symbol != :'' }
    return @list
  end

  # @param symbol [Symbol, Integer]
  # @return [Definition, nil]
  def find(symbol)
    return list.find { |d| d.number == symbol } if symbol.is_a?(Integer)

    return list.find { |d| d.symbol == symbol }
  end
end

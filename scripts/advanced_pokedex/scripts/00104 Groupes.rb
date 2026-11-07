# Advanced Pokédex : groupes (flags) des Pokémon — starter, légendaire, fabuleux, Ultra-Chimère, paradoxe…
#
# Réglés dans Pokémon Studio : page Pokémon, bloc « Groupes » (liste des groupes libre : créer / renommer / supprimer).
# Fichier : Data/configs/plugins/pokemon_flags.json
#   { "flags": [ { "id": "legendary", "name": "Légendaire", "color": "#efcf3a" } ],
#     "creatures": { "mewtwo": { "flags": ["legendary"], "forms": { "1": { "flags": ["..."] } } } } }
# Une forme qui a sa propre liste remplace celle de l'espèce ; sinon elle reprend celle de l'espèce.
# Groupes automatiques (sans rien régler) : :gen_0 à :gen_9 d'après la génération (bloc Couleur, habitat, génération).
#
# En jeu :
#   pokemon.group?(:legendary)                    -> true / false   (aussi pokemon.flag?(:legendary))
#   pokemon.groups                                -> [:legendary, :gen_1]
#   PokemonFlags.flag?(:mewtwo, :legendary)       PokemonFlags.flags(:mewtwo)
#   PokemonFlags.creatures(:starter)              -> [:bulbasaur, :ivysaur, …] (forme 0)
#   PokemonFlags.name(:ultra_beast)               -> "Ultra-Chimère"
#   PokemonFlags.list                             -> [:starter, :legendary, …] (groupes du projet)
# Dans un évent (commande Script) :
#   pokemon_has_flag?(1, :paradox)                -> 1er Pokémon de l'équipe
#   party_has_flag?(:legendary)                   -> un Pokémon de l'équipe est légendaire
#   party_count_flag(:starter)
module Configs
  # Contenu de Data/configs/plugins/pokemon_flags.json
  class PokemonFlagsConfig
    attr_accessor :flags, :creatures

    def initialize
      @flags = []
      @creatures = {}
    end
  end
  register(:pokemon_flags, 'plugins/pokemon_flags', :json, false, PokemonFlagsConfig)
end

module PokemonFlags
  CONFIG_FILE = 'Data/configs/plugins/pokemon_flags.json'

  module_function

  # @return [Configs::PokemonFlagsConfig]
  def config
    @config ||= begin
      PSDK_CONFIG.release? || File.exist?(CONFIG_FILE) ? Configs.pokemon_flags : Configs::PokemonFlagsConfig.new
    rescue StandardError, ScriptError => e
      log_error("Groupes de Pokémon : fichier illisible (#{e.message})") if respond_to?(:log_error, true)
      Configs::PokemonFlagsConfig.new
    end
  end

  # Relit le fichier
  def reload
    @config = @creatures = @defs = nil
  end

  # @return [Hash{String => Hash}] données par db_symbol (clés en texte)
  def creature_data
    @creatures ||= PokedexInfos.deep_stringify(config.creatures || {})
  end

  # @return [Array<Hash>] groupes du projet ('id', 'name', 'color')
  def definitions
    @defs ||= (config.flags || []).map { |flag| PokedexInfos.deep_stringify(flag) }
  end

  # @return [Array<Symbol>] groupes du projet
  def list
    return definitions.map { |flag| flag['id'].to_sym }
  end

  # Groupes d'un Pokémon (groupes réglés + groupe de génération)
  # @param db_symbol [Symbol, String]
  # @param form [Integer]
  # @return [Array<Symbol>]
  def flags(db_symbol, form = 0)
    base = creature_data[db_symbol.to_s] || {}
    own = (base['forms'] || {})[form.to_i.to_s]
    ids = own && own['flags'].is_a?(Array) ? own['flags'] : (base['flags'] || [])
    result = ids.map(&:to_sym)
    result << :"gen_#{PokedexInfos.generation(db_symbol, form)}" if defined?(PokedexInfos)
    return result.uniq
  rescue StandardError
    return []
  end

  # @param db_symbol [Symbol, String]
  # @param flag [Symbol, String]
  # @param form [Integer]
  # @return [Boolean]
  def flag?(db_symbol, flag, form = 0)
    return flags(db_symbol, form).include?(flag.to_sym)
  end

  # Pokémon d'un groupe (forme 0)
  # @param flag [Symbol, String]
  # @return [Array<Symbol>]
  def creatures(flag)
    return each_data_creature.map(&:db_symbol).select { |db_symbol| flag?(db_symbol, flag) }
  end

  # @param flag [Symbol, String]
  # @return [String] nom du groupe (réglé dans Studio)
  def name(flag)
    found = definitions.find { |definition| definition['id'] == flag.to_s }
    return found['name'].to_s if found
    return format($options&.language.to_s == 'fr' ? 'Génération %d' : 'Generation %d', flag.to_s[/\d+/].to_i) if flag.to_s.start_with?('gen_')

    return flag.to_s.tr('_', ' ').capitalize
  end

  # @param flag [Symbol, String]
  # @return [String] couleur (#rrggbb)
  def color(flag)
    found = definitions.find { |definition| definition['id'] == flag.to_s }
    return found ? found['color'].to_s : ''
  end
end

module PFM
  class Pokemon
    # @return [Array<Symbol>] groupes du Pokémon (Studio : bloc Groupes)
    # (pas « flags » : PSDK s'en sert déjà pour d'autres données du Pokémon)
    def groups
      return PokemonFlags.flags(db_symbol, form)
    end

    # @param group [Symbol, String]
    # @return [Boolean]
    def group?(group)
      return PokemonFlags.flag?(db_symbol, group, form)
    end
    alias flag? group?
  end
end

class Interpreter
  # @param index [Integer] place dans l'équipe (1 = premier)
  # @param flag [Symbol, String]
  # @return [Boolean]
  def pokemon_has_flag?(index, flag)
    pokemon = $actors[index.to_i - 1]
    return pokemon ? pokemon.group?(flag) : false
  end

  # @param flag [Symbol, String]
  # @return [Boolean] un Pokémon (pas un œuf) de l'équipe a ce groupe
  def party_has_flag?(flag)
    return $actors.any? { |pokemon| pokemon && !pokemon.egg? && pokemon.group?(flag) }
  end

  # @param flag [Symbol, String]
  # @return [Integer] nombre de Pokémon de l'équipe qui ont ce groupe
  def party_count_flag(flag)
    return $actors.count { |pokemon| pokemon && !pokemon.egg? && pokemon.group?(flag) }
  end
end

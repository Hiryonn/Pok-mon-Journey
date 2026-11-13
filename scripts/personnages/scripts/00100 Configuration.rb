# Personnages : héros jouables et alliés, réglés dans Studio (Données > Personnages)
#
# Data/configs/plugins/personnages.json (écrit par Studio) :
#   heroes          [{ id, name, gender ('m' / 'f'), charset, battler, picture, description, generator }]
#                   charset : base des charsets du joueur (« player » -> player_m_walk, player_f_run…)
#                   battler : dresseur de dos (graphics/battlers, vide = celui de PSDK)
#                   picture : image de l'écran de choix (graphics/battlers, vide = le personnage de la carte)
#                   generator : l'apparence vient du générateur de personnages (personnaliser_joueur)
#   default_hero    héros donné au début d'une nouvelle partie
#   ask_name        l'écran de choix demande ensuite le nom du joueur
#   name_max_length longueur maximale du nom
#   allies          [{ id, name, trainer, charset, follow, trainer_battles, wild_battles }]
#                   trainer : dresseur de Studio (Données > Dresseurs) dont l'équipe combat au côté du héros
module Configs
  # Contenu de Data/configs/plugins/personnages.json
  class PersonnagesConfig
    attr_accessor :heroes, :default_hero, :ask_name, :name_max_length, :allies

    def initialize
      @heroes = []
      @default_hero = nil
      @ask_name = true
      @name_max_length = 12
      @allies = []
    end
  end
  register(:personnages, 'plugins/personnages', :json, false, PersonnagesConfig)
end

module Personnages
  CONFIG_FILE = 'Data/configs/plugins/personnages.json'

  module_function

  # @return [Configs::PersonnagesConfig, nil]
  def config
    return @config if defined?(@config)

    @config = PSDK_CONFIG.release? || File.exist?(CONFIG_FILE) ? Configs.personnages : nil
  rescue StandardError, ScriptError => e
    log_error("Personnages : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
    @config = nil
  end

  # @param key [Symbol]
  # @param default [Object]
  def setting(key, default)
    value = config.respond_to?(key) ? config.send(key) : nil
    return value.nil? ? default : value
  end

  # Hash du JSON (clés symboles ou chaînes) -> clés chaînes
  # @param hash [Hash, nil]
  # @return [Hash]
  def norm(hash)
    return {} unless hash.is_a?(Hash)

    return hash.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
  end

  # @return [Array<Hash>]
  def heroes
    return Array(setting(:heroes, [])).map { |hero| norm(hero) }
  end

  # @return [Array<Hash>]
  def allies
    return Array(setting(:allies, [])).map { |ally| norm(ally) }
  end

  # @param id [String, Symbol, Integer, nil] identifiant ou position (0 = premier)
  # @param list [Array<Hash>]
  # @return [Hash, nil]
  def find_in(list, id)
    return nil if id.nil?
    return list[id] if id.is_a?(Integer)

    return list.find { |entry| entry['id'].to_s == id.to_s } || list.find { |entry| entry['name'].to_s.casecmp?(id.to_s) }
  end

  # @param id [String, Symbol, Integer, nil]
  # @return [Hash, nil]
  def hero(id)
    return find_in(heroes, id)
  end

  # @param id [String, Symbol, Integer, nil]
  # @return [Hash, nil]
  def ally(id)
    return find_in(allies, id)
  end

  # @return [Hash, nil] héros du début de partie
  def default_hero
    return hero(setting(:default_hero, nil)) || heroes.first
  end

  # @return [Integer]
  def name_max_length
    return setting(:name_max_length, 12).to_i.clamp(1, 24)
  end

  # @return [Boolean]
  def ask_name?
    return setting(:ask_name, true) ? true : false
  end
end

# Berrydex : champs de baies améliorés (d'après « TDW Berry Planting Improvements » pour Essentials, de
# TheDeadWarrior). Fichiers 00120 à 00122 du plugin berrydex.
#
# Les plants de baies de la carte (évènements qui appellent l'évènement commun « Berry tree », n° 18) gagnent :
#   mutations      deux plants voisins (haut, bas, gauche, droite) peuvent donner une autre baie à la récolte, à la
#                  place d'une des baies (table « mutations ») ; « Il y a quelque chose de spécial… » quand il fleurit
#   flétrissement  un plant mûr pas cueilli finit par flétrir et se replanter tout seul (max_replants fois), puis
#                  disparaît ; il peut alors laisser un objet par terre (withered_items, « parent » : sa baie)
#   propagation    en flétrissant, une de ses baies peut se planter dans un emplacement vide voisin (pour mille)
#   plants durables après la cueillette, le plant peut repartir d'un stade au lieu de disparaître (persistent_chance)
#   déterrer       une baie qui vient d'être plantée peut être déterrée (dig_up_keep_chance : chance de la garder)
#   mauvaises herbes  poussent parfois (toutes les weed_hours heures, weed_chance %) : croissance plus lente, sol qui
#                  sèche plus vite ; on peut les arracher
#   nuisibles      des Pokémon sauvages se cachent parfois dans le plant (il tremble) : combat en le touchant
#                  (table « pests », couleur de la baie possible ; un Repousse les fait fuir)
#   sols           « berrysoil(sandy) » dans le nom de l'évènement : sol du plant (table « soils »)
#   zones          « berryzone(field) » dans le nom de l'évènement ; zones préférées / évitées réglées dans le
#                  Berrydex (zones, unpref_zones)
#   météo préférée si le joueur voit une des météos préférées de la baie (Berrydex, weathers) pendant la pousse
#   engrais        on peut mettre un engrais avant de planter (mulches : growth, drying, yield, replants, ripe,
#                  mutation, propagation, weeds, pests)
#   arrosage       avec un arrosoir (celui des pots à baies) ; la pluie arrose aussi
# Les « traits » (préférences, mauvaises herbes, nuisibles, sols) changent : yield (baies), hours_per_stage (heures par
# stade), drying_per_hour (% de séchage), mutation_chance, max_replants, weed_chance, pest_chance.
# Réglages : Data/configs/plugins/champs_baies.json ; sol préféré d'une baie : « soil » dans le Berrydex
# (Data/configs/plugins/berrydex.json, berries).
# Commandes : champ_de_baies (interaction, faite automatiquement à la place de l'évènement commun), planter_baie(id
# d'évènement, :oran_berry), baies_mures?(id d'évènement)
module Configs
  class ChampsBaiesConfig
    attr_accessor :settings, :mutations, :withered_items, :mulches, :traits, :soils, :pests

    def initialize
      @settings = {}
      @mutations = []
      @withered_items = []
      @mulches = {}
      @traits = {}
      @soils = {}
      @pests = []
    end
  end
  register(:champs_baies, 'plugins/champs_baies', :json, false, ChampsBaiesConfig)
end

module ChampsBaies
  CONFIG_FILE = 'Data/configs/plugins/champs_baies.json'
  DEFAULTS = {
    'enabled' => true, 'common_event' => 18, 'max_replants' => 5, 'ripe_stages' => 4, 'rain_waters' => true,
    'need_can' => true, 'mutations' => true, 'mutation_chance' => 20, 'mutation_count' => 1,
    'replant_resets_mutation' => true, 'propagation' => true, 'propagation_chance' => 1, 'persistent_chance' => 0,
    'persistent_stage' => 2, 'dig_up' => true, 'dig_up_keep_chance' => 25, 'weeds' => true, 'weed_hours' => 2,
    'weed_chance' => 15, 'pests' => true, 'pest_hours' => 2, 'pest_chance' => 15, 'repel_on_pests' => true,
    'zone_message' => true, 'default_soil' => 'loamy'
  }.freeze
  # Image des mauvaises herbes (graphics/characters)
  WEEDS_CHARSET = 'berrytreeweeds'
  # Météos du Berrydex -> test de l'environnement
  WEATHER_TESTS = {
    'sun' => %i[sunny? hardsun?], 'rain' => %i[rain?], 'heavyrain' => %i[hardrain?], 'storm' => %i[strong_winds?],
    'snow' => %i[snowing?], 'blizzard' => %i[hail?], 'sandstorm' => %i[sandstorm?], 'fog' => %i[fog?]
  }.freeze

  module_function

  # @return [Configs::ChampsBaiesConfig]
  def config
    @config ||= begin
      if PSDK_CONFIG.release?
        Configs.champs_baies
      elsif File.exist?(CONFIG_FILE)
        require 'json'
        data = JSON.parse(File.read(CONFIG_FILE, encoding: 'utf-8'))
        cfg = Configs::ChampsBaiesConfig.new
        data.each { |k, v| cfg.instance_variable_set("@#{k}", v) if cfg.respond_to?(k) }
        cfg
      else
        Configs::ChampsBaiesConfig.new
      end
    rescue StandardError, ScriptError => e
      log_error("Champs de baies : réglages illisibles (#{e.message})") if respond_to?(:log_error, true)
      Configs::ChampsBaiesConfig.new
    end
  end

  def reload
    @config = nil
    @mutation_table = nil
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

  def enabled?
    return setting('enabled') ? true : false
  end

  def fr?
    return $options.nil? || $options.language.to_s == 'fr'
  end

  def t(fr, en = fr)
    return fr? ? fr : en
  end

  # Texte réglé { fr:, en: } ou chaîne
  def local(value, fallback = '')
    return value.to_s unless value.is_a?(Hash)

    return (fetch(value, fr? ? 'fr' : 'en') || fetch(value, 'fr') || value.values.first || fallback).to_s
  end

  # --- Sols, engrais, traits ----------------------------------------------------------------------------
  # @return [Hash, nil] sol (avec id)
  def soil(id)
    id = (id.to_s.empty? ? setting('default_soil') : id).to_s.downcase
    entry = fetch(config.soils, id)
    return entry ? entry.merge('id' => id) : nil
  end

  def soil_name(id)
    entry = soil(id)
    return entry ? local(fetch(entry, 'name'), id.to_s) : id.to_s
  end

  # @return [Hash] effets d'un engrais
  def mulch(item)
    return {} unless item

    return fetch(config.mulches, item.to_s) || {}
  end

  def mulch?(item)
    return !fetch(config.mulches, item.to_s).nil?
  end

  # @param name [Symbol] pref_weather, pref_zone, unpref_zone, pref_soil, weeds, pests
  # @return [Hash]
  def trait(name)
    return fetch(config.traits, name) || {}
  end

  # Valeur d'un trait (yield peut être [min, max])
  def trait_value(hash, key)
    value = fetch(hash, key)
    return rand(value[0].to_i..[value[1].to_i, value[0].to_i].max) if value.is_a?(Array)

    return value.to_i
  end

  # --- Mutations -----------------------------------------------------------------------------------------
  # @return [Hash{Array(Symbol, Symbol) => Array<Symbol>}]
  def mutation_table
    @mutation_table ||= Array(config.mutations).each_with_object({}) do |entry, table|
      parents = Array(fetch(entry, 'parents')).map { |p| p.to_s.to_sym }
      results = Array(fetch(entry, 'results')).map { |r| r.to_s.to_sym }
      next unless parents.size == 2 && !results.empty?

      (table[parents.sort] ||= []).concat(results)
    end
  end

  # @return [Array<Symbol>] baies possibles entre deux plants
  def mutations_of(berry_a, berry_b)
    return mutation_table[[berry_a.to_sym, berry_b.to_sym].sort] || []
  end

  def mutation_parent?(berry)
    return mutation_table.keys.flatten.include?(berry.to_sym)
  end

  # --- Préférences du Berrydex -------------------------------------------------------------------------------
  def berrydex_entry(berry)
    return nil unless defined?(::Berrydex)

    return ::Berrydex.fetch(::Berrydex.config.berries, berry.to_s)
  rescue StandardError
    return nil
  end

  def preferred_list(berry, key)
    return Array(fetch(berrydex_entry(berry), key)).map { |v| v.to_s.downcase }
  end

  # @return [Boolean] la météo actuelle fait partie des préférées de la baie
  def preferred_weather_now?(berry)
    preferred_list(berry, 'weathers').any? do |weather|
      Array(WEATHER_TESTS[weather]).any? { |test| $env.respond_to?(test) && $env.send(test) }
    end
  rescue StandardError
    return false
  end

  # --- Nuisibles ---------------------------------------------------------------------------------------------
  # @param berry [Symbol]
  # @return [Array(Symbol, Integer), nil] Pokémon et niveau
  def pest_for(berry)
    color = begin
      data_item(berry).berry_data.pokeblock_color.to_s
    rescue StandardError
      ''
    end
    list = Array(config.pests).select do |entry|
      c = fetch(entry, 'color').to_s
      c.empty? || c == color
    end
    return nil if list.empty?

    total = list.sum { |entry| [fetch(entry, 'weight').to_i, 1].max }
    roll = rand(total)
    entry = list.find { |e| (roll -= [fetch(e, 'weight').to_i, 1].max) < 0 } || list.last
    levels = Array(fetch(entry, 'levels')).map(&:to_i)
    levels = [5, 5] if levels.empty?
    return [fetch(entry, 'pokemon').to_s.to_sym, rand(levels.min..levels.max)]
  end

  # Objet laissé par un plant complètement flétri
  def withered_item(berry)
    total = 100
    roll = rand(total)
    Array(config.withered_items).each do |entry|
      roll -= fetch(entry, 'weight').to_i
      next if roll >= 0

      item = fetch(entry, 'item').to_s
      return item == 'parent' ? berry.to_sym : item.to_sym
    end
    return nil
  end

  # Arrosoir du sac (ceux des pots à baies, sinon un des arrosoirs connus)
  def watering_can
    list = defined?(::PotsBaies) ? (::PotsBaies.can_list rescue []) : []
    list = Array(list).map { |c| (c.is_a?(Hash) ? fetch(c, 'item') : c).to_s.to_sym }
    list = %i[wailmer_pail sprinklotad squirt_bottle sprayduck] if list.empty?
    return list.find { |item| $bag.contain_item?(item) }
  end

  # Nom d'objet
  def item_name(item)
    return data_item(item).name.to_s
  rescue StandardError
    return item.to_s
  end
end

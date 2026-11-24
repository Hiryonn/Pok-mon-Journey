# Groupes d'Œuf : groupes personnalisés, ajouts à un groupe, recettes d'œufs et œufs par encens
#
# Réglés dans Pokémon Studio : Données > Pokémon > Groupes d'Œuf.
# Fichier : Data/configs/plugins/egg_groups.json
#   { "groups":   [ { "id": 100, "name": { "fr": "Fossile", "en": "Fossil" } } ],
#     "creatures": { "kabuto": { "groups": [100], "forms": { "1": { "groups": [5] } } } },
#     "recipes":  [ { "a": "pikachu", "b": "eevee", "result": "pichu", "form": 0 } ],
#     "incense":  [ { "parent": "pikachu", "item": "luck_incense", "baby": "pichu" } ],
#     "disabled_incense": [ "marill" ] }
#
# Groupes : 1 à 15 sont ceux de PSDK (Monstre, Eau 1, Insecte, Vol, Terrestre, Fée, Végétal, Humanoïde, Eau 3, Minéral,
# Amorphe, Eau 2, Métamorph, Dragon, Inconnu) ; les groupes créés dans Studio commencent à 100. Les groupes d'un Pokémon
# réglés dans Studio sont conservés : « creatures » AJOUTE des groupes (aux groupes de Studio, pour l'espèce ou une forme).
# Recettes : deux Pokémon donnent l'œuf d'une autre espèce (dans les deux sens, sans groupe commun requis).
# Encens : le Pokémon « parent » tenant (ou dont le partenaire tient) l'objet « item » donne l'œuf « baby ».
# « disabled_incense » désactive les œufs par encens de PSDK (marill, azumarill, wobbuffet, roselia, roserade, chimecho,
# sudowoodo, mr_mime, mr_rime, chansey, blissey, snorlax, mantine).
#
# En jeu :
#   EggGroups.breed_groups(:kabuto, 0, [5]) -> [5, 100]      EggGroups.members(100) -> [:kabuto, …] (groupes ajoutés)
#   EggGroups.name(100) -> "Fossile"                         EggGroups.recipe(:pikachu, :eevee) -> { result: :pichu, … }
module Configs
  # Contenu de Data/configs/plugins/egg_groups.json
  class EggGroupsConfig
    attr_accessor :groups, :creatures, :recipes, :incense, :disabled_incense

    def initialize
      @groups = []
      @creatures = {}
      @recipes = []
      @incense = []
      @disabled_incense = []
    end
  end
  register(:egg_groups, 'plugins/egg_groups', :json, false, EggGroupsConfig)
end

module EggGroups
  CONFIG_FILE = 'Data/configs/plugins/egg_groups.json'
  # Groupes de PSDK [français, anglais]
  BUILTIN = {
    1 => %w[Monstre Monster], 2 => ['Eau 1', 'Water 1'], 3 => %w[Insecte Bug], 4 => %w[Vol Flying], 5 => %w[Terrestre Field],
    6 => %w[Fée Fairy], 7 => %w[Végétal Grass], 8 => %w[Humanoïde Human-Like], 9 => ['Eau 3', 'Water 3'], 10 => %w[Minéral Mineral],
    11 => %w[Amorphe Amorphous], 12 => ['Eau 2', 'Water 2'], 13 => %w[Métamorph Ditto], 14 => %w[Dragon Dragon], 15 => %w[Inconnu Undiscovered]
  }.freeze

  # Compatibilité des données d'un Pokémon : les groupes de Studio + ceux ajoutés ici
  class DataProxy
    # @param data [Studio::CreatureForm]
    # @param groups [Array<Integer>]
    def initialize(data, groups)
      @data = data
      @groups = groups
    end

    # @return [Array<Integer>]
    def breed_groups
      return @groups
    end

    def method_missing(name, *args, &block)
      return @data.__send__(name, *args, &block)
    end

    def respond_to_missing?(name, include_private = false)
      return @data.respond_to?(name, include_private) || super
    end
  end

  module_function

  # @return [Configs::EggGroupsConfig]
  def config
    @config ||= begin
      PSDK_CONFIG.release? || File.exist?(CONFIG_FILE) ? Configs.egg_groups : Configs::EggGroupsConfig.new
    rescue StandardError, ScriptError => e
      log_error("Groupes d'Œuf : fichier illisible (#{e.message})") if respond_to?(:log_error, true)
      Configs::EggGroupsConfig.new
    end
  end

  # Relit le fichier
  def reload
    @config = @creatures = @recipes = nil
    @incense_applied = false
  end

  # @param value [Object]
  # @return [Object] même valeur avec des clés en texte
  def stringify(value)
    return value.to_h { |k, v| [k.to_s, stringify(v)] } if value.is_a?(Hash)
    return value.map { |v| stringify(v) } if value.is_a?(Array)

    return value
  end

  # @return [Hash{String => Hash}]
  def creature_data
    @creatures ||= stringify(config.creatures || {})
  end

  # @return [Array<Hash>] recettes (clés en texte)
  def recipes
    @recipes ||= (config.recipes || []).map { |r| stringify(r) }.select { |r| r['a'] && r['b'] && r['result'] }
  end

  # Groupes ajoutés à un Pokémon (espèce + forme)
  # @return [Array<Integer>]
  def extra_groups(db_symbol, form = 0)
    base = creature_data[db_symbol.to_s] || {}
    own = (base['forms'] || {})[form.to_i.to_s] || {}
    return (Array(base['groups']) + Array(own['groups'])).map(&:to_i)
  end

  # @param db_symbol [Symbol, String]
  # @param form [Integer]
  # @param native [Array<Integer>] groupes de Studio
  # @return [Array<Integer>] groupes de Studio + groupes ajoutés
  def breed_groups(db_symbol, form, native)
    return (Array(native).map(&:to_i) + extra_groups(db_symbol, form)).uniq
  end

  # @return [Array<Hash>] groupes créés dans Studio ('id', 'name')
  def definitions
    return (config.groups || []).map { |g| stringify(g) }
  end

  # @param id [Integer]
  # @return [String] nom du groupe
  def name(id)
    id = id.to_i
    if (names = BUILTIN[id])
      return names[$options && $options.language.to_s != 'fr' ? 1 : 0]
    end
    found = definitions.find { |g| g['id'].to_i == id }
    return id.to_s unless found

    names = found['name']
    return names.is_a?(Hash) ? (names[$options&.language.to_s] || names['fr'] || names.values.first).to_s : names.to_s
  end

  # @param id [Integer]
  # @return [Array<Symbol>] Pokémon à qui ce groupe est ajouté ici (pas ceux de Studio)
  def members(id)
    id = id.to_i
    return creature_data.select do |_, c|
      Array(c['groups']).map(&:to_i).include?(id) || (c['forms'] || {}).values.any? { |f| Array(f['groups']).map(&:to_i).include?(id) }
    end.keys.map(&:to_sym)
  end

  # Recette d'œuf des deux Pokémon (dans n'importe quel ordre)
  # @return [Hash{Symbol => Object}, nil] :result (Symbol), :form (Integer)
  def recipe(first, second)
    found = recipes.find do |r|
      (r['a'].to_s == first.to_s && r['b'].to_s == second.to_s) || (r['a'].to_s == second.to_s && r['b'].to_s == first.to_s)
    end
    return found && { result: found['result'].to_sym, form: found['form'].to_i }
  end

  # Applique les œufs par encens du fichier à PFM::Daycare::INCENSE_BABY (une seule fois)
  def apply_incense
    return if @incense_applied

    @incense_applied = true
    table = PFM::Daycare::INCENSE_BABY
    stringify(config.disabled_incense || []).each { |parent| table.delete(parent.to_sym) }
    (config.incense || []).each do |rule|
      rule = stringify(rule)
      next if rule['parent'].to_s.empty? || rule['item'].to_s.empty? || rule['baby'].to_s.empty?

      table[rule['parent'].to_sym] = PFM::Daycare::IncenseInfo.new(rule['item'].to_sym, rule['baby'].to_sym)
    end
  rescue StandardError => e
    log_error("Groupes d'Œuf : encens (#{e.message})") if respond_to?(:log_error, true)
  end

  # Ajouts à la Pension de PSDK (PFM::Daycare)
  module DaycarePatch
    private

    # Données de chaque parent avec leurs groupes d'œuf complétés
    def get_pokemon_data(male, female)
      male_data, female_data = super
      return EggGroups::DataProxy.new(male_data, EggGroups.breed_groups(male.db_symbol, male.form, male_data.breed_groups)),
             EggGroups::DataProxy.new(female_data, EggGroups.breed_groups(female.db_symbol, female.form, female_data.breed_groups))
    end

    # Une recette permet l'œuf même sans groupe commun
    def perform_simple_rate_calculation(male, female)
      rate = super
      return rate if rate != 0
      return rate unless EggGroups.recipe(male.db_symbol, female.db_symbol)
      return 0 if male.gender != 0 && male.gender == female.gender
      return 0 if male.db_symbol == :ditto && female.db_symbol == :ditto

      common_ot = male.trainer_id == female.trainer_id ? 1 : 0
      oval_charm = game_state.bag.contain_item?(:oval_charm) ? 1 : 0
      return self.class::EGG_RATE.dig(1, common_ot, oval_charm) || 0
    end

    # Recettes d'œufs, puis œufs par encens modifiés
    def special_lay_check(daycare, female, male)
      EggGroups.apply_incense
      if (recipe = EggGroups.recipe(male.db_symbol, female.db_symbol))
        id = data_creature(recipe[:result]).id
        return daycare[:layable] = id if id.to_i != 0
      end
      return super
    end

    # Forme de l'œuf d'une recette
    def inherit_form(pokemon, female, male)
      super
      recipe = EggGroups.recipe(male.db_symbol, female.db_symbol)
      pokemon.form = recipe[:form] if recipe && recipe[:result] == pokemon.db_symbol
    end
  end
end

PFM::Daycare.prepend(EggGroups::DaycarePatch)

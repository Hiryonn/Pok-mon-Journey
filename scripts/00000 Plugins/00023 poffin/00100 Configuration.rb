# Poffin : cuisiner des poffins avec des baies, puis les donner aux Pokémon pour améliorer leurs conditions de concours
# (cuisson inspirée de Pokémon Platine ; graphismes graphics/interface/poffin, voir tools/poffin)
#
#   cuisiner_poffin   -> choisir 1 à 4 baies du sac, puis les cuire en tournant avec les flèches (voir 00103 Commandes.rb)
#   nourrir_poffin    -> choisir un poffin, puis le Pokémon qui le mange
#
# Les saveurs viennent des données des baies de Pokémon Studio (cookingData : saveurs et douceur de chaque baie).
# Règles (simplifiées par rapport à Platine) :
#   - saveur du poffin = somme des saveurs des baies - nombre de baies ; douceur = douceur moyenne - nombre de baies
#   - bien tourner (ni trop lentement, ni trop vite) garde toute la valeur ; trop lentement le feu monte (anneau rouge) et
#     le poffin brûle ; trop vite la pâte déborde (chaque débordement retire de la valeur)
#   - saveur épicée = Sang-froid, sèche = Beauté, douce = Charme, amère = Intelligence, acide = Robustesse
#   - manger un poffin ajoute la moitié des saveurs (GAIN_FACTOR) aux conditions (255 max chacune, 510 en tout) et la douceur au lustre (255 max)
module Poffin
  # Dossier des images (dans graphics/interface/)
  DIR = 'poffin/'
  # Baies : dossier des données de Studio
  ITEMS_DIR = 'Data/Studio/items'
  # Position de l'écran de 256x192 sur l'écran de 320x240
  SCREEN_X = 32
  SCREEN_Y = 24
  # Nombre de baies d'une fournée
  MAX_BERRIES = 4
  # Poffins gardés au maximum
  MAX_POFFINS = 100
  # Clé de la liste des poffins dans $user_data (sauvegardé avec la partie)
  STORAGE_KEY = :poffins

  # --- Cuisson ------------------------------------------------------------------------
  # Durée de la cuisson (images)
  DURATION = 1200
  # Allure : pas d'un quart de tour par seconde. Dans la zone, la pâte est bien tournée.
  PACE_MIN = 4.0
  PACE_MAX = 10.0
  # Chaleur (0 à 100) : monte quand on tourne trop lentement, descend quand on tourne bien
  HEAT_START = 35.0
  HEAT_UP = 0.45
  HEAT_DOWN = 0.7
  # Anneau : bleu sous HEAT_YELLOW, jaune jusqu'à HEAT_RED, puis rouge (danger)
  HEAT_YELLOW = 40.0
  HEAT_RED = 75.0
  # Images passées à plus de HEAT_BURN pour que la pâte brûle
  HEAT_BURN = 92.0
  BURN_LIMIT = 90
  # Une pâte qui déborde (trop vite) : intervalle entre deux débordements (images), maximum retenu
  SPILL_INTERVAL = 25
  MAX_SPILLS = 6
  # Valeur retirée par débordement (part de la valeur)
  SPILL_MALUS = 0.05

  # --- Poffins ------------------------------------------------------------------------
  # Saveurs, dans l'ordre des conditions de concours : Sang-froid, Beauté, Charme, Intelligence, Robustesse
  FLAVORS = %i[spicy dry sweet bitter sour].freeze
  FLAVOR_NAMES = {
    spicy: %w[Épicé Spicy], dry: %w[Sec Dry], sweet: %w[Doux Sweet], bitter: %w[Amer Bitter], sour: %w[Acide Sour]
  }.freeze
  # Palier selon la plus forte saveur : 1 simple, 2 moelleux (à partir de TIER_2), 3 riche (à partir de TIER_3)
  TIER_2 = 25
  TIER_3 = 60
  TIER_NAMES = { 1 => %w[simple plain], 2 => %w[moelleux fluffy], 3 => %w[riche rich] }.freeze
  # Une saveur compte dans le nom si elle atteint cette part de la plus forte
  NAME_RATIO = 0.5
  # Conditions de concours, dans l'ordre des saveurs
  CONDITION_NAMES = [%w[Sang-froid Cool], %w[Beauté Beauty], %w[Charme Cute], %w[Intellig. Smart], %w[Robust. Tough]].freeze
  # Limites des conditions de concours et du lustre
  MAX_CONDITION = 255
  MAX_TOTAL = 510
  MAX_SHEEN = 255
  # Part de la saveur du poffin qui s'ajoute à la condition (1.0 = toute la saveur)
  GAIN_FACTOR = 0.5

  module_function

  # @return [Hash{Symbol => Hash}] baies cuisinables : { db_symbol => { color:, smoothness:, flavors: [5] } }
  def berries
    return @berries if @berries

    @berries = {}
    Dir.glob("#{ITEMS_DIR}/*berry*.json").sort.each do |file|
      text = File.read(file, encoding: 'UTF-8')
      next unless text.include?('"cookingData"')

      data = JSON.parse(text)
      cooking = data['cookingData']
      next unless data['isBerry'] && cooking

      flavors = %w[spicyFlavor dryFlavor sweetFlavor bitterFlavor sourFlavor].map { |key| cooking[key].to_i }
      @berries[data['dbSymbol'].to_sym] = { color: cooking['pokeblockColor'], smoothness: cooking['smoothness'].to_i, flavors: flavors }
    end
    return @berries
  rescue StandardError => e
    log_error("Poffin : baies illisibles (#{e.message})") if respond_to?(:log_error, true)
    return @berries = {}
  end

  # @param symbol [Symbol]
  # @return [Hash, nil]
  def berry(symbol)
    return berries[symbol.to_sym]
  end

  # @param symbol [Symbol]
  # @return [String] nom de la baie
  def berry_name(symbol)
    return data_item(symbol).name.to_s
  rescue StandardError
    return symbol.to_s
  end

  # @param symbol [Symbol]
  # @return [Integer] combien de cette baie dans le sac
  def berry_count(symbol)
    return $bag ? $bag.item_quantity(symbol).to_i : 0
  rescue StandardError
    return 0
  end

  # @return [Array<Symbol>] baies du sac que l'on peut cuisiner
  def available_berries
    return berries.keys.select { |symbol| berry_count(symbol) > 0 }
  end

  # --- Recette ---------------------------------------------------------------------------
  # @param symbols [Array<Symbol>] baies (1 à MAX_BERRIES, la même plusieurs fois possible)
  # @return [Hash] { flavors: [5 valeurs], smoothness: } avant la cuisson
  def recipe(symbols)
    data = symbols.map { |symbol| berry(symbol) }.compact
    return { flavors: [0] * 5, smoothness: 0 } if data.empty?

    count = data.size
    flavors = FLAVORS.each_index.map { |i| [data.sum { |entry| entry[:flavors][i] } - count, 0].max }
    smoothness = [(data.sum { |entry| entry[:smoothness] }.fdiv(count)).round - count, 1].max
    return { flavors: flavors, smoothness: smoothness }
  end

  # Poffin obtenu après la cuisson
  # @param recipe [Hash] résultat de recipe
  # @param good_ratio [Float] part de la cuisson bien tournée (0 à 1)
  # @param spills [Integer] débordements
  # @param burnt [Boolean]
  # @return [Hash] { 'kind' => 'normal' ou 'burnt', 'flavors', 'smoothness', 'tier', 'level' }
  def make(recipe, good_ratio, spills = 0, burnt = false)
    return { 'kind' => 'burnt', 'flavors' => [0] * 5, 'smoothness' => 0, 'tier' => 1, 'level' => 0 } if burnt

    multiplier = (0.6 + 0.4 * good_ratio.clamp(0.0, 1.0) - SPILL_MALUS * spills.clamp(0, MAX_SPILLS)).clamp(0.3, 1.0)
    flavors = recipe[:flavors].map { |value| (value * multiplier).floor }
    smoothness = [(recipe[:smoothness] * (0.8 + 0.2 * good_ratio.clamp(0.0, 1.0))).round, 1].max
    level = flavors.max
    tier = level >= TIER_3 ? 3 : (level >= TIER_2 ? 2 : 1)
    return { 'kind' => 'normal', 'flavors' => flavors, 'smoothness' => smoothness, 'tier' => tier, 'level' => level }
  end

  # @param index [Integer] 0 français, 1 anglais
  # @return [Integer]
  def language_index
    return $options && $options.language.to_s != 'fr' ? 1 : 0
  end

  # @param flavor [Symbol]
  # @return [String]
  def flavor_name(flavor)
    return FLAVOR_NAMES[flavor][language_index]
  end

  # @param poffin [Hash]
  # @return [Array<Symbol>] saveurs qui comptent dans le nom (les plus fortes)
  def main_flavors(poffin)
    level = poffin['flavors'].max.to_i
    return [] if level <= 0

    list = FLAVORS.each_index.select { |i| poffin['flavors'][i] >= level * NAME_RATIO }.sort_by { |i| -poffin['flavors'][i] }.first(2)
    return list.map { |i| FLAVORS[i] }
  end

  # @param poffin [Hash]
  # @return [String] ex. « Poffin moelleux Épicé-Sec »
  def name(poffin)
    en = language_index == 1
    return en ? 'Burnt Poffin' : 'Poffin brûlé' if poffin['kind'] == 'burnt'

    tier = TIER_NAMES[poffin['tier']][language_index]
    flavors = main_flavors(poffin).map { |flavor| flavor_name(flavor) }.join('-')
    return en ? "#{flavors} #{tier} Poffin".gsub('  ', ' ').strip : "Poffin #{tier} #{flavors}".strip
  end

  # @param poffin [Hash]
  # @return [String] nom sans le mot « Poffin », pour les listes (ex. « Moelleux Épicé-Sec »)
  def short_name(poffin)
    return name(poffin).sub(/\APoffin /, '').sub(/ Poffin\z/, '').sub(/\A./) { |c| c.upcase }
  end

  # --- Poffins du joueur --------------------------------------------------------------
  # @return [Array<Hash>] les poffins (sauvegardés avec la partie)
  def inventory
    return [] unless $user_data

    return $user_data[STORAGE_KEY] ||= []
  end

  # @param poffin [Hash]
  # @return [Boolean] ajouté (faux : trop de poffins)
  def add(poffin)
    return false if inventory.size >= MAX_POFFINS

    inventory << poffin
    return true
  end

  # --- Nourrir un Pokémon -------------------------------------------------------------------
  # @param pokemon [PFM::Pokemon]
  # @return [Array<Integer>] ses 5 conditions
  def conditions(pokemon)
    return pokemon.contest_conditions.to_a.first(5)
  end

  # @param pokemon [PFM::Pokemon]
  # @return [Integer]
  def sheen(pokemon)
    return pokemon.sheen.to_i
  end

  # Résultat du poffin sur le Pokémon, sans rien changer
  # @param pokemon [PFM::Pokemon]
  # @param poffin [Hash]
  # @return [Hash, nil] { gains: [5], sheen: } ; nil si le Pokémon ne peut rien manger de plus
  def effect(pokemon, poffin)
    return nil if pokemon.egg? || sheen(pokemon) >= MAX_SHEEN

    current = conditions(pokemon)
    room = MAX_TOTAL - current.sum
    gains = poffin['flavors'].each_with_index.map do |value, i|
      gain = [[(value * GAIN_FACTOR).floor, MAX_CONDITION - current[i].to_i].min, 0].max
      gain = [gain, room].min
      room -= gain
      gain
    end
    sheen_gain = [poffin['smoothness'].to_i, MAX_SHEEN - sheen(pokemon)].min
    return nil if gains.sum <= 0 && sheen_gain <= 0

    return { gains: gains, sheen: sheen_gain }
  end

  # Le Pokémon mange le poffin (le poffin n'est pas retiré de la liste)
  # @return [Hash, nil] l'effet appliqué (voir effect), nil si rien n'a changé
  def feed(pokemon, poffin)
    result = effect(pokemon, poffin)
    return nil unless result

    conditions = pokemon.contest_conditions
    result[:gains].each_with_index { |gain, i| conditions[i] = conditions[i].to_i + gain }
    new_sheen = sheen(pokemon) + result[:sheen]
    if pokemon.respond_to?(:sheen=)
      pokemon.sheen = new_sheen
    else
      pokemon.instance_variable_set(:@sheen, new_sheen)
    end
    return result
  end
end

# Triple Triad : une carte (valeurs tirées des stats de base du Pokémon, comme dans Essentials)
module TripleTriad
  class Card
    # Paliers stat -> valeur (1 à 10)
    STEPS = [[189, 10], [160, 9], [134, 8], [115, 7], [100, 6], [86, 5], [73, 4], [60, 3], [45, 2]].freeze

    # @return [Symbol]
    attr_reader :db_symbol
    # @return [Integer]
    attr_reader :form
    # @return [Array<Integer>] valeurs [haut, droite, bas, gauche]
    attr_reader :values
    # @return [Symbol] type de la carte (règle Éléments)
    attr_reader :type

    # @param db_symbol [Symbol]
    # @param form [Integer]
    def initialize(db_symbol, form = 0)
      @db_symbol = db_symbol.to_sym
      @form = form.to_i
      data = data_creature_form(@db_symbol, @form)
      hp = data.base_hp
      atk = data.base_atk
      dfe = data.base_dfe
      spd = data.base_spd
      ats = data.base_ats
      dfs = data.base_dfs
      @values = [stat_value(atk + spd / 3), stat_value(dfe + hp / 3), stat_value(ats + spd / 3), stat_value(dfs + hp / 3)]
      @type = data.type1 == :normal && data.type2 && data.type2 != :__undef__ ? data.type2 : data.type1
    end

    # Cartes déjà créées
    # @return [Card]
    def self.get(db_symbol, form = 0)
      @cache ||= {}
      return @cache[[db_symbol.to_sym, form.to_i]] ||= new(db_symbol, form)
    end

    # @param side [Integer] 0 haut, 1 droite, 2 bas, 3 gauche
    # @return [Integer]
    def value(side)
      return @values[side]
    end

    # @return [Integer] somme des valeurs
    def total
      return @values.sum
    end

    # Niveau de la carte (0 à 9) : sert à choisir les cartes de l'adversaire
    # @return [Integer]
    def level
      return ((total - 4) / 3.6).floor.clamp(0, 9)
    end

    # @return [Integer] prix en boutique (revente : moitié)
    def price
      return [((total**2) * 4 / 10 * 10).to_i, TripleTriad::MIN_PRICE].max
    end

    # @return [String]
    def name
      return data_creature(@db_symbol).name
    rescue StandardError
      return @db_symbol.to_s
    end

    # @return [String] nom de l'icône du Pokémon (graphics/pokedex/pokeicon)
    def icon_name
      return PFM::Pokemon.icon_filename(data_creature(@db_symbol).id, @form, false, false, false)
    end

    private

    def stat_value(stat)
      STEPS.each { |min, value| return value if stat >= min }
      return 1
    end
  end
end

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
      @values = TripleTriad.custom_values(@db_symbol) || Card.auto_values(@db_symbol, @form)
      @type = data.type1 == :normal && data.type2 && data.type2 != :__undef__ ? data.type2 : data.type1
    end

    # Valeurs calculées (toujours les mêmes pour un Pokémon) :
    #   haut = Attaque + Vitesse / 3, droite = Défense + PV / 3, bas = Atq. Spé. + Vitesse / 3, gauche = Déf. Spé. + PV / 3
    #   puis une évolution est toujours au moins aussi forte que le Pokémon dont elle évolue (et +1 au total sinon)
    # @return [Array<Integer>]
    def self.auto_values(db_symbol, form = 0)
      @auto ||= {}
      key = [db_symbol.to_sym, form.to_i]
      return @auto[key] if @auto[key]

      data = data_creature_form(db_symbol.to_sym, form.to_i)
      values = [base_value(data.base_atk + data.base_spd / 3), base_value(data.base_dfe + data.base_hp / 3),
                base_value(data.base_ats + data.base_spd / 3), base_value(data.base_dfs + data.base_hp / 3)]
      parent = TripleTriad.pre_evolution(db_symbol.to_sym)
      if parent && parent != db_symbol.to_sym
        @auto[key] = values # évite une boucle si les évolutions se référencent
        base = TripleTriad.custom_values(parent) || auto_values(parent)
        values = values.each_with_index.map { |v, i| [v, base[i]].max }
        if values.sum <= base.sum
          weakest = values.each_with_index.select { |v, _| v < 10 }.min_by(&:first)
          values[weakest[1]] += 1 if weakest
        end
      end
      return @auto[key] = values
    end

    # @param stat [Integer]
    # @return [Integer] 1 à 10
    def self.base_value(stat)
      STEPS.each { |min, value| return value if stat >= min }
      return 1
    end

    # Vide les caches (réglages relus)
    def self.reset
      @cache = nil
      @auto = nil
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

    # @return [Integer] prix en boutique (réglable dans Studio ; revente : prix x taux de revente)
    def price
      custom = TripleTriad.custom_price(@db_symbol)
      return custom if custom

      return [((total**2) * 4 * TripleTriad.price_factor / 10).round * 10, TripleTriad::MIN_PRICE].max
    end

    # @return [Integer] prix de revente
    def sell_price
      return (price * TripleTriad.sell_ratio).to_i
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

  end
end

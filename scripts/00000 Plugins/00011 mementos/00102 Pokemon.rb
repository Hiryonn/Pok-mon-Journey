# Souvenirs : ce que les Pokémon savent de leurs rubans et insignes
#   pokemon.add_ribbon(:rainy_mark)        donne un souvenir (titre automatique si le Pokémon n'en a pas)
#   pokemon.memento_rank(ribbon)           rang (1 + rangs précédents obtenus)
#   pokemon.mementos(:rank)                souvenirs triés (voir Mementos::FILTERS)
#   pokemon.set_title(:rainy_mark) / nil   titre du Pokémon
#   pokemon.pj_scale                       taille (0 à 255)
module Mementos
  module_function

  # Après un nouveau souvenir : rubans souvenirs (Concours, Combat) et titre automatique
  # @param pokemon [PFM::Pokemon]
  # @param symbol [Symbol]
  def after_gain(pokemon, symbol)
    memory_ribbon(pokemon, symbol, :contest_memory, :contest_memory_gold)
    memory_ribbon(pokemon, symbol, :battle_memory, :battle_memory_gold)
    return unless setting?('auto_title') && !pokemon.title? && !pokemon.egg?

    ribbon = pokemon.ribbon(symbol)
    pokemon.title_ribbon = ribbon if ribbon&.gives_title?
  end

  # Les rubans d'autrefois (Concours de Hoenn/Sinnoh, Tour de Combat) se rangent dans un ruban souvenir,
  # qui devient doré quand ils sont tous réunis
  def memory_ribbon(pokemon, symbol, memory, gold)
    ranks = prev_ranks(gold)
    return unless ranks.include?(symbol) && !pokemon.ribbon?(gold)

    ribbons = pokemon.ribbons
    if ranks.all? { |s| pokemon.ribbon?(s) }
      index = ribbons.index { |r| r.symbol == memory } || ribbons.size
      title = pokemon.title_ribbon&.symbol == memory
      ribbons[index] = PFM::RIBBONS_DATA[gold]
      pokemon.title_ribbon = ribbons[index] if title
    elsif !pokemon.ribbon?(memory)
      index = ribbons.index { |r| r.symbol == symbol } || ribbons.size
      ribbons.insert(index, PFM::RIBBONS_DATA[memory])
    end
  end
end

module PFM
  class Pokemon
    # Ajout des souvenirs (rubans souvenirs, titre automatique) et titre avec placement du nom
    module MementoRibbons
      def add_ribbon(symbol)
        symbol = symbol.to_sym
        return if symbol == :contest_memory && ribbon?(:contest_memory_gold)
        return if symbol == :battle_memory && ribbon?(:battle_memory_gold)

        had = ribbon?(symbol)
        super
        Mementos.after_gain(self, symbol) if !had && ribbon?(symbol)
      rescue StandardError => e
        log_error("Souvenirs : #{e.message}") if respond_to?(:log_error, true)
      end

      def remove_ribbon(symbol)
        symbol = symbol.to_sym
        @title_ribbon = nil if @title_ribbon&.symbol == symbol
        @ribbons.reject! { |ribbon| ribbon.symbol == symbol }
      end

      def given_name_with_title
        return given_name unless title?

        full = Mementos.full_title(@title_ribbon, self)
        return full.empty? ? given_name : full
      end
    end
    prepend MementoRibbons

    # Taille du Pokémon (0 : le plus petit, 255 : le plus grand), tirée à la première demande
    # @return [Integer]
    def pj_scale
      @pj_scale ||= rand(256)
    end

    def pj_scale=(value)
      @pj_scale = value.to_i.clamp(0, 255)
    end

    # @return [PFM::Ribbon, nil] souvenir du Pokémon
    def ribbon(symbol)
      symbol = Mementos.sym(symbol)
      return @ribbons.find { |ribbon| ribbon.symbol == symbol }
    end

    # Rang d'un souvenir : 1 + rangs précédents obtenus
    def memento_rank(ribbon)
      ranks = Mementos.prev_ranks(ribbon)
      return ([1 + ranks.count { |s| ribbon?(s) }, ranks.size + 1].min)
    end

    # Souvenirs sans les rangs dépassés (seul le plus haut rang reste)
    # @return [Array<PFM::Ribbon>]
    def collapsed_ribbons
      hidden = @ribbons.flat_map(&:prev_ranks)
      return @ribbons.reject { |ribbon| hidden.include?(ribbon.symbol) }
    end

    # @param filter [Symbol] voir Mementos::FILTERS
    # @return [Array<PFM::Ribbon>]
    def mementos(filter = :all)
      return collapsed_ribbons if filter == :rank

      return @ribbons.select { |ribbon| Mementos.match?(ribbon, filter) }
    end

    # Le Pokémon a-t-il un souvenir de ce tri ?
    def memento_type?(filter)
      return @ribbons.any? { |ribbon| ribbon.max_rank > 1 } if filter == :rank

      return @ribbons.any? { |ribbon| Mementos.match?(ribbon, filter) }
    end

    # Choisit le titre (souvenir du Pokémon qui donne un titre) ; nil le retire
    # @return [Boolean]
    def set_title(symbol)
      return (@title_ribbon = nil).nil? if symbol.nil?

      ribbon = ribbon(symbol)
      return false unless ribbon&.gives_title?

      @title_ribbon = ribbon
      return true
    end
  end
end

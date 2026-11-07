# Triple Triad : cartes du joueur (gardées dans la sauvegarde : PFM.game_state.user_data[:triple_triad])
module TripleTriad
  module_function

  # @return [Hash{Symbol => Integer}] db_symbol => nombre de cartes
  def collection
    data = PFM.game_state.user_data
    data[:triple_triad] = {} unless data[:triple_triad].is_a?(Hash)
    return data[:triple_triad]
  end

  # @param db_symbol [Symbol]
  # @return [Integer]
  def count(db_symbol)
    return collection[db_symbol.to_sym].to_i
  end

  # @return [Integer] nombre total de cartes
  def total_count
    return collection.values.sum
  end

  # @param db_symbol [Symbol]
  # @param quantity [Integer]
  # @return [Boolean]
  def add(db_symbol, quantity = 1)
    db_symbol = db_symbol.to_sym
    return false if data_creature(db_symbol).db_symbol == :__undef__

    collection[db_symbol] = count(db_symbol) + quantity.to_i
    collection.delete(db_symbol) if collection[db_symbol] <= 0
    return true
  end

  # @param db_symbol [Symbol]
  # @param quantity [Integer]
  # @return [Boolean] false s'il n'y a pas assez de cartes
  def remove(db_symbol, quantity = 1)
    return false if count(db_symbol) < quantity

    add(db_symbol, -quantity)
    return true
  end

  # Cartes possédées, triées par n° du Pokémon
  # @return [Array<Symbol>]
  def owned
    return collection.keys.select { |s| count(s) > 0 }.sort_by { |s| data_creature(s).id }
  end

  # Main au hasard tirée de la collection
  # @return [Array<Symbol>]
  def random_hand
    pool = owned.flat_map { |s| [s] * count(s) }
    return pool.sample(HAND_SIZE)
  end

  # Pokémon qui peuvent servir de cartes (avec des stats)
  # @return [Array<Symbol>]
  def all_species
    @all_species ||= each_data_creature.map(&:db_symbol).reject { |s| s == :__undef__ }
  end

  # Main de l'adversaire : cartes de niveau min..max au hasard
  # @param min_level [Integer] 0 à 9
  # @param max_level [Integer] 0 à 9
  # @return [Array<Symbol>]
  def opponent_hand(min_level, max_level)
    pool = all_species.select { |s| Card.get(s).level.between?(min_level.to_i, max_level.to_i) }
    pool = all_species.sort_by { |s| (Card.get(s).level - min_level.to_i).abs }.first(30) if pool.size < HAND_SIZE
    return Array.new(HAND_SIZE) { pool.sample }
  end
end

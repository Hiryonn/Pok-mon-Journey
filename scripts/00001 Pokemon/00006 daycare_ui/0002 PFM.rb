module PFM
  class Daycare
    # Return the full Pokemon stored in a daycare slot.
    # @param id [Integer]
    # @param index [Integer]
    # @return [PFM::Pokemon, nil]
    def get_full_pokemon(id, index)
      return @daycares.dig(id, :pokemon, index)
    end

    # Return how many levels the stored Pokemon gained.
    # @param id [Integer]
    # @param index [Integer]
    # @return [Integer]
    def lvl_earned(id, index)
      return 0 unless (pokemon = @daycares.dig(id, :pokemon, index))

      pokemon.level - @daycares.dig(id, :level, index).to_i
    end

    # Return the number of Pokemon currently stored in the daycare.
    # @param id [Integer]
    # @return [Integer]
    def pokemon_count(id)
      @daycares.dig(id, :pokemon)&.size.to_i
    end

    # Return the current egg rate of a daycare without assuming the daycare is already initialized.
    # @param id [Integer]
    # @return [Integer]
    def egg_rate(id)
      @daycares.dig(id, :rate).to_i
    end
  end
end

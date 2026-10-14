module PFM
  class Daycare
    # Turns down a Shadow Pokemon at the Day Care, which the original game does not allow. Refusing at the
    # storage closes every side effect at once, the held experience, the levels and the eggs.
    module DaycareShadowPatch
      # Store a Pokemon to a daycare
      # @param id [Integer] the ID of the daycare
      # @param pokemon [PFM::Pokemon] the pokemon to store in the daycare
      # @return [Boolean] if the pokemon could be stored in the daycare
      def store(id, pokemon)
        return false if pokemon.shadow?

        return super
      end
    end

    prepend DaycareShadowPatch
  end
end

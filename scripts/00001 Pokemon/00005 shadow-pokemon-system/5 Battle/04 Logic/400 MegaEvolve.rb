module Battle
  class Logic
    class MegaEvolve
      # A locked heart holds the creature in the shape it was caught in, the way it holds back its
      # evolution outside the battle. The call button also takes the key the Mega Evolution asks for,
      # so letting both be offered would stack the two buttons on the same corner of the screen.
      module MegaEvolveShadowPatch
        # Test if a Pokemon can Mega Evolve
        # @param pokemon [PFM::PokemonBattler] Pokemon that should mega evolve
        # @return [Boolean]
        def can_pokemon_mega_evolve?(pokemon)
          return false if pokemon.shadow?

          return super
        end
      end

      prepend MegaEvolveShadowPatch
    end
  end
end

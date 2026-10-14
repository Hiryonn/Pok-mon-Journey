module Battle
  class Move
    class SolarBeam
      # The shadowy aura swallows the sunlight like the weathers the engine already lists.
      module ShadowSkyPatch
        # Get the real base power of the move (taking in account all parameter)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @return [Integer]
        def real_base_power(user, target)
          return power / 2.0 if @logic.weather_effect.shadow_sky?

          return super
        end
      end

      prepend ShadowSkyPatch
    end
  end
end

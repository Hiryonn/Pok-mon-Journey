module Battle
  class Move
    class WeatherBall
      # Under a shadowy aura the ball loses its type; its power already doubles like under any other weather.
      module ShadowSkyPatch
        # Return the current type of the move
        # @return [Integer]
        def type
          return super unless @logic.weather_effect.shadow_sky?
          return super if @logic.weather_effects_disabled?

          return data_type(:__undef__).id
        end
      end

      prepend ShadowSkyPatch
    end
  end
end

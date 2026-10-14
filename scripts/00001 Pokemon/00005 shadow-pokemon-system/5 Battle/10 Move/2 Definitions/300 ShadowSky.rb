module Battle
  class Move
    # Number of turns the shadow sky lasts, no weather rock extending it.
    SHADOW_SKY_DURATION = 5

    WeatherMove::WEATHER_MOVES[:shadow_sky] = :shadow_sky

    # Shadow move covering the field with a sky that hurts everything but Shadow Pokemon.
    class ShadowSky < WeatherMove
      include ShadowMove

      private

      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        logic.weather_change_handler.weather_change_with_process(:shadow_sky, SHADOW_SKY_DURATION)
      end
    end

    Move.register(:s_shadow_sky, ShadowSky)
  end
end

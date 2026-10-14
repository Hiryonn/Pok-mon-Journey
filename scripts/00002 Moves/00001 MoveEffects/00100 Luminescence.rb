module Battle
    class Move
        class Luminescence < WeatherMove
          # Test if the effect is working
          # @param user [PFM::PokemonBattler] user of the move
          # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
          # @return [Boolean]
          private
          def deal_effect(user, actual_targets)
            logic.weather_change_handler.weather_change_with_process(:radiance , 5)
          end
  
        end
        Move.register(:s_luminescence, Luminescence)  
        public
    end
end

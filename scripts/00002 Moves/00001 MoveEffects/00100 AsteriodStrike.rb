module Battle
    class Move
        class AsteriodStrike < Basic
          # Test if the effect is working
          # @param user [PFM::PokemonBattler] user of the move
          # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
          # @return [Boolean]
          private
          def deal_effect(user, actual_targets)
            nb_turn = user.hold_item?(:smooth_rock) ? 8 : 5
            logic.weather_change_handler.weather_change_with_process(:sandstorm , nb_turn)
          end
  
        end
        Move.register(:s_asteriod_strike, AsteriodStrike)  
      end
  end
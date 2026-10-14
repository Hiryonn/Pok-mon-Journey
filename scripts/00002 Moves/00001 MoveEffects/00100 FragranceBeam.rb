module Battle
    class Move
        class FragranceBeam < Basic
          # Test if the effect is working
          # @param user [PFM::PokemonBattler] user of the move
          # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
          # @return [Boolean]
          private
          def deal_effect(user, actual_targets)
                turn_count = user.hold_item?(:terrain_extender) ? 8 : 5
                logic.fterrain_change_handler.fterrain_change_with_process(:grassy_terrain , turn_count)
          end
  
        end
        Move.register(:s_fragrance_beam , FragranceBeam)  
      end
  end
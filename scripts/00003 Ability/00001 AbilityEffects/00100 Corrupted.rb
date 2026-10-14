module Battle
  module Effects
        class Ability 
          class Corrupted < Ability
            # Get the base power multiplier of this move
            # @param user [PFM::PokemonBattler]
            # @param target [PFM::PokemonBattler]
            # @param move [Battle::Move]
            # @return [Float]
            def base_power_multiplier(user, target, move)
              return 1 if target != @target
              return 1.5
            end
          end
          register(:corrupted, Corrupted)
        end
  end
end
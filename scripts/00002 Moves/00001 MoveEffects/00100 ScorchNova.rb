module Battle
    class Move
        class ScorchNova < TwoTurnBase
            # Get the real base power of the move (taking in account all parameter)
            # @param user [PFM::PokemonBattler] user of the move
            # @param target [PFM::PokemonBattler] target of the move
            # @return [Integer]
            def real_base_power(user, target)
              power2 = power
              return power2
            end
            private
            # Check if the two turn move is executed in one turn
            # @param user [PFM::PokemonBattler] user of the move
            # @param targets [Array<PFM::PokemonBattler>] expected targets
            # @return [Boolean]

            def proceed_message_turn1(user, targets)
                @scene.display_message_and_wait(parse_text_with_pokemon(400002, 28, user))
            end
            
            def shortcut?(user, targets)
              return true if $env.sunny? || $env.hardsun?
              super
            end
        end
        Move.register(:s_scorch_nova, ScorchNova)
    end
end

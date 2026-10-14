module Battle
    class Move
        class SmoulderingEmbers < Move
            # Function that tests if the user is able to use the move
            # @param user [PFM::PokemonBattler] user of the move
            # @param targets [Array<PFM::PokemonBattler>] expected targets
            # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
            # @return [Boolean] if the procedure can continue
            def move_usable_by_user(user, targets)
              return false unless super
              target_bank = user.bank == 1 ? 0 : 1
              if @logic.bank_effects[target_bank]&.get(:smouldering_embers)
              show_usage_failure(user)
              return false
              end
              return true
            end
            private
            # Test if the target is immune
            # @param user [PFM::PokemonBattler]
            # @param target [PFM::PokemonBattler]
            # @return [Boolean]
            def target_immune?(user, target)
              return false
            end
            # Function that deals the effect to the pokemon
            # @param user [PFM::PokemonBattler] user of the move
            # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
            def deal_effect(user, actual_targets)
              bank = actual_targets.map(&:bank).first
              if !(effect = @logic.bank_effects[bank]&.get(:smouldering_embers))
                @logic.add_bank_effect(Effects::SmoulderingEmbers.new(@logic, bank, self))
                @scene.display_message_and_wait(parse_text(400002, bank == 0 ? 56 : 57))
              end
            end
        end
        Move.register(:s_smouldering_embers, SmoulderingEmbers)
        public
    end
end
module Battle
  class Move
      class TonneTangle < Basic
        private
        # Test if the effect is working
        # @param user [PFM::PokemonBattler] user of the move
        # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
        # @return [Boolean]
        def effect_working?(user, actual_targets)
          return (actual_targets.none? { |target| ineffective_against_target?(target) } || !logic.terrain_effects.has?(:gravity)) || actual_targets.all? { |target| !target.effects.has?(:cantswitch) }
        end
        # Function that deals the effect to the pokemon
        # @param user [PFM::PokemonBattler] user of the move
        # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
        def deal_effect(user, actual_targets)
          actual_targets.each do |target|
            if !ineffective_against_target?(target)
              target.effects.add(Effects::SmackDown.new(logic, target))
              scene.display_message_and_wait(parse_text_with_pokemon(400002, 19, target))
            else
              nil
            end
            if !target.effects.has?(:cantswitch)
              target.effects.add(Effects::CantSwitch.new(logic, target, user, self))
              scene.display_message_and_wait(message(target))
            else
              nil
            end
          end
        end
        # Test if a specific effect is ineffective against a target
        # @param target [PFM::PokemonBattler]
        # @return [Boolean]
        def ineffective_against_target?(target)
          return true if target.dead?
          return true if target.grounded? && !target.effects.has?(:out_of_reach_base)
          return true if target.effects.has?(:substitute) && !authentic? || target.effects.has?(:ingrain)
          return true if target.hold_item?(:iron_ball)
          return false
        end
        # Get the message text
        # @return [String]
        def message(target)
          return parse_text_with_pokemon(19, 875, target)
        end
      end
      Move.register(:s_tonne_tangle, TonneTangle)
  end
end
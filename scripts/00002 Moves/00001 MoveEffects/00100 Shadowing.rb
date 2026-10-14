module Battle
    class Move
        class Shadowing < Move

            def move_usable_by_user(user, targets)
                return false unless super
                return false if targets.empty?
                unless @logic.ability_change_handler.can_change_ability?(user, targets.first.ability_db_symbol, user, self) && @logic.ability_change_handler.can_change_ability?(targets.first, user.ability_db_symbol, user, self)
                  show_usage_failure(user)
                  return false
                end
                return true
              end
              # Function that deals the effect to the pokemon
              # @param user [PFM::PokemonBattler] user of the move
              # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
              def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                  next unless @logic.ability_change_handler.can_change_ability?(user, target.ability_db_symbol, user, self) && @logic.ability_change_handler.can_change_ability?(target, user.ability_db_symbol, user, self)
                  @scene.visual.show_ability(user)
                  @scene.visual.show_ability(target)
                  @scene.visual.wait_for_animation
                  @logic.ability_change_handler.change_ability(user, target.ability_db_symbol, user, self)
                  user.battle_stage.fill(0)
                  target.battle_stage.each_with_index do |value, index|
                    next if value == 0
                    user.set_stat_stage(index, value)
                  end
                  @scene.display_message_and_wait(parse_text_with_pokemon(400002, 50, user, PFM::Text::PKNICK[1] => target.given_name))
                end
              end


    
        end
            Move.register(:s_shadowing, Shadowing)
    end
end

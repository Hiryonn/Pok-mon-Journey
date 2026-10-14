module Battle
    class Move
        class Deflect < Move

            def move_usable_by_user(user, targets)
                return false unless super
                if user.turn_count > 1 && db_symbol == :mat_block
                  show_usage_failure(user)
                  return false
                end
                if logic.battler_attacks_last?(user)
                  show_usage_failure(user)
                  return false
                end
                turn = $game_temp.battle_turn
                consecutive_uses = user.successful_move_history.reverse.take_while do |history|
                  if history.move.be_method == :s_deflect
                    turn -= 1
                    next(turn == history.turn)
                  end
                end
                unless bchance?(3 ** -(consecutive_uses.size).clamp(0, 6))
                  show_usage_failure(user)
                  return false
                end
                return true
            end
  
  
          def deal_effect(user,  actual_target)
            actual_target.each do |target|
              if !target.effects.has?(:deflect)
                  target.effects.add(Effects::Deflect.new(logic, target, user, self,1))
              end
            end
          end
        end
        Move.register(:s_deflect, Deflect)
    end
  end
  
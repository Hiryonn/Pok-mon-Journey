module Battle
  class Move
    class Rehydrate < TwoTurnBase

            def can_hit_moves
                return CAN_HIT_BY_TYPE[3 || 4]
            end

            def proceed_message_turn1(user, targets)
              @scene.display_message_and_wait(parse_text_with_pokemon(19,535, user))
            end

            def deal_effect(user, targets)
                targets.each do |target|
                  if $env.normal? || $env.strong_winds?
                    hp = target.max_hp / 2
                  else
                    if $env.rain? || $env.hardrain?
                      hp = target.max_hp * 2 / 3
                    elsif $env.sunny? || $env.hardsun?
                      hp = target.max_hp / 4
                    end
                  end
                  #hp = hp * 3 / 2 if pulse? && user.has_ability?(:mega_launcher)
                  logic.damage_handler.heal(target, hp)
                end
            end
            
    end
    Move.register(:s_rehydrate, Rehydrate)
        


  end
end


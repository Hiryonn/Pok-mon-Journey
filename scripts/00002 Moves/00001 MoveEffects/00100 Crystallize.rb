module Battle
    class Move
        class Crystallize < Move

          def move_usable_by_user(user,targets)   
            return false unless super
            return show_usage_failure(user) && false if !user.move_history.empty? && user.move_history.last.db_symbol== :crystallize
            return true 
          end
  
  
          def deal_effect(user,  actual_target)
            actual_target.each do |target|
              if !target.effects.has?(:crystallize)
                  target.effects.add(Effects::Crystallize.new(logic, target, user, self,1))
                  user.battle_stage.fill(0)
                  hp = user.max_hp/2
                  logic.damage_handler.heal(user,hp)
              end
            end
          end
        end
        Move.register(:s_crystallize, Crystallize)
    end
  end
  
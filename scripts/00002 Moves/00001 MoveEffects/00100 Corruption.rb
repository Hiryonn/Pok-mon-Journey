module Battle
    class Move
        class Corruption < Move
  
          def move_usable_by_user(user, actual_targets)
            return false unless super
            return show_usage_failure(user) && false if actual_targets.all? {|target| target.effects.has?(:corruption)}
            return true 
          end
  
  
          def deal_effect(user,  actual_target)
            actual_target.each do |target|
              if !target.effects.has?(:corruption)
                  target.effects.add(Effects::Corruption.new(logic, target, user, self,3))
                  @scene.visual.show_ability(target)
                  @scene.visual.wait_for_animation
                  logic.scene.display_message_and_wait(parse_text_with_2pokemon(400002,112,user,target))
              end
            end
          end
        end
        Move.register(:s_corruption, Corruption)
    end
  end
  
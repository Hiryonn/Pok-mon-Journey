module Battle
  class Move
      class Landfall < Basic

          def effect_working?(user, actual_targets)
            return actual_targets.none? { |target| ineffective_against_target?(target) } || !logic.terrain_effects.has?(:gravity)
          end

          def ability_immunity?(user, target)
            logic.each_effects(target) do |e|
              return true if e.on_move_ability_immunity(user, target, self) 
            end
            return false
          end

          def damages(user, target)
            hp_dealt = super
            hp_dealt *= 4 if target.type_steel?
            @effectiveness = @effectiveness * 4 if target.type_steel?  
            return hp_dealt
          end


          def deal_effect(user,  actual_target)
            actual_target.each do |target|
              if !ineffective_against_target?(target)
                target.effects.add(Effects::SmackDown.new(logic, target))
                scene.display_message_and_wait(parse_text_with_2pokemon(400002, 0, user, target))
              end
            end
          end

          def ineffective_against_target?(target)
            return true if target.dead?
            return true if target.grounded? && !target.effects.has?(:out_of_reach_base)
            return true if target.effects.has?(:substitute) && !authentic? || target.effects.has?(:ingrain)
            return true if target.hold_item?(:iron_ball)
            return false
          end
          
      end
      Move.register(:s_landfall, Landfall)
  end
end

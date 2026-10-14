module Battle
    class Move
        class ChillingScythe < Basic
             def fainted_this_turn?(target)
                return false if target == nil
                return true if target.dead?
                
             end

             def effect_working?(user, actual_targets)
                if !status? && user.can_be_lowered_or_canceled?(target = actual_targets.find { |t| t.has_ability?(:shield_dust) })
                  @scene.visual.show_ability(target) if data.effect_chance > 0 && target.alive?
                  return false
                end
                if fainted_this_turn?(target = actual_targets.find{|t| t.dead?})
                    return true
                end
                n = 1
                scene.logic.each_effects(user).each do |e|
                  n *= e.effect_chance_modifier(self)
                end
                return bchance?((effect_chance * n) / 100.0) && super
            end


             def deal_effect(user, actual_target)
                actual_target.each do |target|
                    if fainted_this_turn?(target)
                        hp = (user.max_hp)/4
                        logic.damage_handler.heal(user, hp)
                    else
                        next
                    end
                end
            end


            
        end
        Move.register(:s_chilling_scythe, ChillingScythe)
        
    end
end
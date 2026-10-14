module Battle
    class Move
        class FlamePurge < Basic
            
            def effect_working?(user, actual_targets)
                actual_targets.each do |target|
                    if states.include?(Configs.states.symbol(target.status))
                        return true
                    end
                end
                n = 1
                scene.logic.each_effects(user).each do |e|
                  n *= e.effect_chance_modifier(self)
                end
                return bchance?((effect_chance * n) / 100.0) && super
            end




            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                    scene.logic.status_change_handler.status_change(:burn, target)
                end
            end

            def states 
                STATES 
            end
            
            STATES = %i[paralysis sleep freeze poison toxic]
        end
        Move.register(:s_flame_purge, FlamePurge)
    end
end

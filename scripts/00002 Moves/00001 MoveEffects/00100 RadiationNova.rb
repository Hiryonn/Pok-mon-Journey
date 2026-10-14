module Battle
    class Move
        class RadiationNova < Basic
            
            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                    if !states.include?(Configs.states.symbol(target.status)) || target.alive?
                        scene.logic.status_change_handler.status_change(:poison, target)
                    elsif states.include?(Configs.states.symbol(target.status))
                        scene.display_message_and_wait(parse_text_with_pokemon(19, 249, target))
                    end
                end
                stats.each { |stat, power| logic.stat_change_handler.stat_change_with_process(stat, power, user, user, self) }
            end

            def states 
                STATES 
            end
            def stats 
                STATS 
            end

            STATS = {ats: -2}
            STATES = %i[poison]

        end
        Move.register(:s_radiation_nova, RadiationNova)
    end
end

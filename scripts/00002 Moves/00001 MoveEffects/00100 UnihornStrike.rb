module Battle
    class Move
        class UnihornStrike < Basic 

            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                    if $env.twilight?
                        stats1.each {|stat, power| logic.stat_change_handler.stat_change_with_process(stat,power, user, user, self)}
                    elsif @logic.field_terrain_effect.misty?
                        stats2.each {|stat, power| logic.stat_change_handler.stat_change_with_process(stat,power, user, user, self)}
                    else 
                        nil
                    end
                end
            end

            def stats1 
                return {atk: 1, ats: 1}
            end
            
            def stats2
                return {dfe: 1, dfs: 1}
            end
        end
        Move.register(:s_unihorn_strike, UnihornStrike)
    end
end

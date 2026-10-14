module Battle
    class Move
        class TripleThreat < ThreeHit

            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                 random = rand(2)
                 case random
                 when 0
                    p_stats.each {|stat, power|logic.stat_change_handler.stat_change_with_process(stat, power, user, user, self)}
                 when 1 
                    ai_stats.each {|stat, power|logic.stat_change_handler.stat_change_with_process(stat, power, target, user, self)}
                 end
                end
            end

            def p_stats
                return{atk: 1}
            end

            def ai_stats
                return{atk: -1}
            end
        end
        Move.register(:s_triple_threat , TripleThreat)
        
    end
end
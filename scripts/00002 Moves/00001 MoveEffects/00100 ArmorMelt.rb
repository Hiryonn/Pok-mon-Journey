module Battle
    class Move
        class ArmorMelt < Move
            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                    if target.poisoned? ||  target.toxic?
                        stats2.each {|stat, power| logic.stat_change_handler.stat_change_with_process(stat,power,target, user, self)}
                    else
                        stats1.each {|stat, power| logic.stat_change_handler.stat_change_with_process(stat,power,target, user, self)}
                    end
                end
            end
            def stats1
                return {dfe:-1,dfs:-1}
            end
    
            def stats2
               return {dfe:-2, dfs:-2}
            end
            
        end
        Move.register(:s_armor_melt, ArmorMelt)
    end
end

         

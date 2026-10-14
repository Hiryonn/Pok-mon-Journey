module Battle
    class Move
        class CircusAct < Move


            def deal_effect(user,  actual_target)
                stats = {dfe: 1 , dfs: 1}
                stats.each_key {|stat| stats[stat] = actual_target.size}
                stats.each {|stat, power| logic.stat_change_handler.stat_change_with_process(stat,power,user, user, self)}
            end

        end
        Move.register(:s_circus_act, CircusAct)
    end
end

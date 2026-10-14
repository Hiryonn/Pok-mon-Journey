module Battle
    class Move
        class EmotionalConflict < Move

            def deal_effect(user,actual_target)
                actual_target.each do |target|
                    stats = random_2stat
                    stats.each {|stat, power| logic.stat_change_handler.stat_change_with_process(stat,power,target, user, self)}
                end
            end

           

        

            STAT_NAME = [ :atk , :dfe , :ats , :ats , :spd]

            def random_2stat
                increase_stat = 0
                decrease_stat = 0
                stats = {}
                while increase_stat == decrease_stat
                    increase_stat = rand(5)
                    decrease_stat = rand(5)
                end
                stats[STAT_NAME[increase_stat]] = 3
                stats[STAT_NAME[decrease_stat]] = -3
                return stats
            end
        end
        Move.register(:s_emotional_conflict, EmotionalConflict)
    end

end

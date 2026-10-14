module Battle
    class Move
        class MagnificentMaelstrom < Basic
            private
            def fainted_this_turn(target)
                return true if target.dead?
            end

            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                    if fainted_this_turn(target) == true
                        stats.each {|stat, power|logic.stat_change_handler.stat_change_with_process(stat, power, user, user, self)}
                    else
                        
                        next
                    end
                end
            end

            def stats 
                return {ats: 1}
            end


            
        end
        Move.register(:s_magnificent_maelstrom, MagnificentMaelstrom)
        public
        
    end
end
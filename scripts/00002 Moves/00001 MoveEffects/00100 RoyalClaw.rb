
module Battle
    class Move
        class RoyalClaw < Basic
            private
            def fainted_this_turn?(target)
                return true if target.dead?
            end

            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                    if fainted_this_turn?(target) 
                        stats.each {|stat, power|logic.stat_change_handler.stat_change_with_process(stat, power, user, user, self)}
                    else
                        next
                    end
                end
            end

            def stats 
                return {atk: 1}
            end


            
        end
        Move.register(:s_royal_claw, RoyalClaw)
        public
        
    end
end
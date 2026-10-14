module Battle
    class Move
        class Momentum < Move
            def initialize(db_symbol, pp, ppmax, scene)
                super
                @target = nil  
            end

            def move_usable_by_user(user,targets)   
                if !user.move_history.empty? && @target == targets && user.move_history.last.db_symbol== :momentum
                    show_usage_failure(user)
                    target_swap(targets)
                    return false  
                end
                @target = targets
                return true 
            end

            def deal_effect(user,actual_targets)
                actual_targets.each do |target|
                    user.effects.add(Effects::Momentum.new(logic, target, user, self,1))
                    stats.each {|stat, power| logic.stat_change_handler.stat_change_with_process(stat, power, user, user, self)}
                end
            end

            def target_swap(targets)
                @target = nil 
            end

            def stats
                return STATS
            end

            STATS = {spd: 1}
        end
        Move.register(:s_momentum, Momentum)
    end
end



module Battle
    class Move
        #Set target ot self in PS
        class Ascension < Move
            #move will not work if hp less than half or stat already at max
            def move_usable_by_user(user, actual_targets)
                return false unless super
                return show_usage_failure(user) && false if user.hp <= user.max_hp/2 || user.battle_stage[3] == 6
                return true 
            end


            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                    hp = target.max_hp/2
                    logic.damage_handler.damage_change(hp,target)
                    stats.each{|stat,power| logic.stat_change_handler.stat_change_with_process(stat,power,target, user, self)}
                end
            end

            def stats 
                return{ats:6}
            end

        end
        Move.register(:s_ascension , Ascension)
        
    end
end
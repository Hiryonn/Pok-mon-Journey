module Battle
    class Move
        class Reconstruct < Move 
            #set target self in PS
            private
            def deal_effect(user,targets)
                targets.each do |target|
                    stats.each { |stat, power| logic.stat_change_handler.stat_change_with_process(stat, power, target, user, self) }
                    hp =  3 * (target.max_hp / 4)
                    logic.damage_handler.heal(target, hp)
                    
                end
                
                
            end
            

            def stats
                return {dfe: -1, dfs: -1}
            end
            def message(user, target)
                return parse_text_with_pokemon(19, 613, target)
            end  
        end
        Move.register(:s_reconstruct,Reconstruct)
        public
    end
end    


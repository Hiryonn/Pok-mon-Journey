module Battle
    class Move
        class Sundance < TwoTurnBase
          

            def proceed_message_turn1(user, targets)
              @scene.display_message_and_wait(parse_text_with_pokemon(400002, 25, user))
            end

            def deal_effect(user, targets)
                targets.each do |target|
                statsarr1.each {|stat, power|logic.stat_change_handler.stat_change_with_process(stat, power, target, user, self)}
                end
            end
            def statsarr1
                return {atk: 1, dfe: 1, spd: 1, ats: 1 , dfs: 1}
            end
            
        end
        Move.register(:s_sundance , Sundance)
        
    end
end
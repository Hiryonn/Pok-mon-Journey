module Battle
    class Move
        class ZeroBeam < Basic
            
            def effect_working?(user, actual_targets)
                actual_targets.each do |target|
                    if states.include?(Configs.states.symbol(user.status))
                        scene.display_message_and_wait(parse_text_with_pokemon(400000, 9, user))
                        return false
                    end
                end
            end




            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                    scene.logic.status_change_handler.status_change(:freeze, user)
                end
            end

            def states 
                STATES 
            end
            
            STATES = %i[freeze]

        end
        Move.register(:s_zero_beam, ZeroBeam)
    end
end

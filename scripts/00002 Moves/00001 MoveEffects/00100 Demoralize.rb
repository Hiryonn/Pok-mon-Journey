module Battle 
    class Move
        class Demoralize < Move


            def move_usable_by_user(user, actual_targets)
                return false unless super
                return show_usage_failure(user) && false if actual_targets.all? {|target| target.effects.has?(:demoralize)}
                return true 
            end

            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                    if !target.effects.has?(:demoralize)
                        target.effects.add(Effects::Demoralize.new(logic, target, user, self))
                        logic.scene.display_message_and_wait(parse_text_with_pokemon(400002, 93, target)) 
                    end
                end
            end
        end
        Move.register(:s_demoralise, Demoralize)
    end
end


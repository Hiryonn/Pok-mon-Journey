module Battle
    class Move
        class Overload < Move
            def effect_working?(user,actual_targets)
                return false if actual_targets.all? {|target| target.effects.has?(:overload)}
                return true
            end

            def deal_effect(user,actual_targets)
                actual_targets.each do |target|
                    if !target.effects.has?(:overload)
                        target.effects.add(Effects::Overload.new(logic, target, user, self, 3))
                        logic.scene.display_message_and_wait(parse_text_with_pokemon(400002, 103, target)) 
                    end
                end
            end
        end
        Move.register(:s_overload, Overload)
    end
end



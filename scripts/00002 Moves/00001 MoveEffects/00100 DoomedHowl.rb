module Battle
    class Move
        class DoomedHowl < Move
            private

           
            def move_usable_by_user(user, actual_targets)
                return false unless super
                return show_usage_failure(user) && false if user.hp <= user.max_hp/2 || actual_targets.all? {|target| target.effects.has?(:doomedhowl)}
                return true 
            end
                


            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                    if !target.effects.has?(:doomedhowl)
                        target.effects.add(Effects::DoomedHowl.new(logic, target, user, self,2))
                        scene.display_message_and_wait(message(target))
                    end
                    hp = user.max_hp/2
                    logic.damage_handler.damage_change(hp,user)
                    scene.display_message_and_wait(parse_text_with_pokemon(19, 378, user))
                end
            end

           
            def message(target)
                return parse_text_with_pokemon(19, 878, target)
              end

        end
        Move.register(:s_doomed_howl, DoomedHowl)
        public
    end
end

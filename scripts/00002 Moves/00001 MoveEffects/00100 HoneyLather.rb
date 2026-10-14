module Battle
  class Move
      class HoneyLather < Move

        def move_usable_by_user(user, actual_targets)
          return false unless super
          return show_usage_failure(user) && false if actual_targets.all? {|target| target.effects.has?(:honey_lather)}
          return true 
        end


        def deal_effect(user,  actual_target)
          actual_target.each do |target|
            if !target.effects.has?(:honey_lather)
                target.effects.add(Effects::HoneyLather.new(logic, target, user, self))
                logic.scene.display_message_and_wait(parse_text_with_pokemon(400002,106,target))
            end
          end
        end
      end
      Move.register(:s_honey_lather, HoneyLather)
  end
end

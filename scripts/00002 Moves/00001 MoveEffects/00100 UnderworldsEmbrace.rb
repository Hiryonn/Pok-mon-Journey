module Battle
  class Move
      class UnderworldsEmbrace < Move

        def move_usable_by_user(user, actual_targets)
          return false unless super
          return show_usage_failure(user) && false if actual_targets.all? {|target| target.effects.has?(:underworlds_embrace)}
          return true 
        end


        def deal_effect(user,  actual_target)
          actual_target.each do |target|
            if !target.effects.has?(:underworlds_embrace)
                target.effects.add(Effects::UnderworldsEmbrace.new(logic, target, user, self))
                logic.scene.display_message_and_wait(parse_text_with_pokemon(400002,109,target))
            end
          end
        end
      end
      Move.register(:s_underworlds_embrace, UnderworldsEmbrace)
  end
end

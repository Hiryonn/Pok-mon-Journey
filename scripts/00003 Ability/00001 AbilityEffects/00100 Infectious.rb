module Battle
  module Effects
    class Ability
      class Infectious < Ability
        def on_post_damage(handler, hp, target, launcher, skill)
          return unless skill&.direct?

          if target == @target && launcher != target && launcher.hp > 0 && launcher.can_be_poisoned? 
            handler.scene.visual.show_ability(@target)
            handler.logic.status_change_handler.status_change_with_process(:poison, launcher)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 472, launcher))
          
          elsif launcher == @target && target != launcher && target.hp > 0 && target.can_be_poisoned?
            handler.scene.visual.show_ability(@target)
            handler.logic.status_change_handler.status_change_with_process(:poison, target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 472, target))
          end
        end
      end

      register(:infectious, Infectious)
    end
  end
end

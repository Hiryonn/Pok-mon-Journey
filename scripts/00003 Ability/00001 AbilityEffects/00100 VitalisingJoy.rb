module Battle
  module Effects
    class Ability
      class VitalisingJoy < Ability
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return unless launcher == @target
          return unless launcher.alive?

          if handler.logic.stat_change_handler.stat_increasable?(:ats, @target)
            handler.scene.visual.show_ability(@target)
            handler.scene.display_message_and_wait(
              "#{@target.given_name} became overjoyed!"
            )
            handler.logic.stat_change_handler.stat_change_with_process(:ats, 1, @target)
          end
        end
      end

      register(:vitalising_joy, VitalisingJoy)
    end
  end
end
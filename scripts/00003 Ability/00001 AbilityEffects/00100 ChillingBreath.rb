module Battle
  module Effects
    class Ability
      class ChillingBreath < Ability
        def on_post_damage(handler, hp, target, launcher, skill)
          # return unless launcher == @target
          return unless skill&.special? 
          return unless target.can_be_frozen?
          return if target.frozen?

          if rand < 0.25
            handler.scene.visual.show_ability(@target)
            handler.scene.display_message_and_wait(
              "#{target.given_name} was frozen by Chilling Breath!"
            )
            handler.logic.status_change_handler.status_change(:freeze, target)
          end
        end
      end

      register(:chilling_breath, ChillingBreath)
    end
  end
end

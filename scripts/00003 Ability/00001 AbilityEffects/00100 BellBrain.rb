module Battle
  module Effects
    class Ability
      class BellBrain < Ability
        def base_power_multiplier(user, target, move)
          if user == @target
            return move.sound_attack? ? 1.3 : 1
          elsif target == @target && user.can_be_lowered_or_canceled?
            return move.sound_attack? ? 0.5 : 1
          end
          return 1
        end

        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target
          return unless status == :confusion
          return if launcher.nil? || launcher.bank == target.bank 

          return handler.prevent_change do
            handler.scene.visual.show_ability(@target)
            handler.scene.display_message_and_wait(
              parse_text_with_pokemon(19, 357, target)
            )
          end
        end
      end

      register(:bellbrain, BellBrain)
    end
  end
end

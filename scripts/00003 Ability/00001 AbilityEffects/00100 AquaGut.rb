module Battle
  module Effects
        class Ability 
          class AquaGut < Ability
            def on_damage_prevention(handler, hp, target, launcher, skill)
              return if target != @target
              return unless skill
              return unless launcher&.can_be_lowered_or_canceled?

              if skill.type_water?
                return if target.effects.has?(:heal_block)

                return handler.prevent_change do
                  handler.scene.visual.show_ability(target)
                  handler.logic.damage_handler.heal(target, target.max_hp / 4)
                  handler.scene.display_message_and_wait(
                    parse_text_with_pokemon(400003, 12, target)
                  )
                  
                end
              elsif skill.type_fire?
                return handler.prevent_change do
                  handler.scene.visual.show_ability(target)
                  handler.scene.display_message_and_wait(
                    parse_text_with_pokemon(400003, 15, target)
                  )
                end
              end
            end
          end
          register(:aqua_gut, AquaGut)
        end
  end
end
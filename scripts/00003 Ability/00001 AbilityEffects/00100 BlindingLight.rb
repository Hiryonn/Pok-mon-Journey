module Battle
  module Effects
    class Ability
      class BlindingLight < Ability

        def on_switch_event(handler, who, with)
          return if with != @target

          handler.scene.visual.show_ability(@target)

          user_spd = who.spd
          target_spd = with.spd

          if target_spd > user_spd * 2
            if handler.logic.stat_change_handler.stat_decreasable?(:acc, target)
              handler.logic.stat_change_handler.stat_change_with_process(:acc, -0.2, @target)
              handler.scene.display_message_and_wait(
                    parse_text_with_pokemon(400003, 18, @target)
              )
            end
          elsif target_spd > user_spd
            if handler.logic.stat_change_handler.stat_decreasable?(:acc, target)
              handler.logic.stat_change_handler.stat_change_with_process(:acc, -0.1, @target)
              handler.scene.display_message_and_wait(
                    parse_text_with_pokemon(400003, 21, @target)
              )
            end
          end
        end
      end
      register(:blinding_light, BlindingLight)
    end
  end
end

module Battle
  module Effects
    class Ability
      class Aftershock < Ability
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if launcher != @target
          return unless skill&.type_electric?
          return unless launcher.alive?

          handler.scene.visual.show_ability(@target)

          battlers = handler.logic.all_alive_battlers
          battlers.each do |battler|
            next if battler == target 
            if battler.type_electric?
              handler.logic.damage_handler.heal(battler, battler.max_hp / 4)
              handler.scene.display_message_and_wait(parse_text_with_pokemon(400003, 6, battler))
            else
              handler.logic.damage_handler.damage_change(battler.max_hp / 4 , battler)
              handler.scene.display_message_and_wait(parse_text_with_pokemon(400003, 9, battler))
            end
          end
        end
      end
      register(:aftershock, Aftershock)
    end
  end
end

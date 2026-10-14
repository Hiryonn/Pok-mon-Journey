module Battle
  module Effects
    class Ability
      class ChargedQuills < Ability
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0
          handler.scene.visual.show_ability(target)
          handler.logic.damage_handler.damage_change(launcher.max_hp/8, launcher)
          text = parse_text_with_pokemon(19, 430, launcher, PFM::Text::PKNICK[0] => launcher.given_name)
          handler.scene.display_message_and_wait(text)
          if launcher.can_be_paralyzed? && bchance?(0.2, handler.logic)
            handler.logic.status_change_handler.status_change_with_process(:paralysis, launcher)
          end
        end
      end
      register(:charged_quills, ChargedQuills)
    end
  end
end

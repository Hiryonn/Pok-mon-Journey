module Battle
  module Effects
    class Ability
      class Metamorphosis < Ability
        def on_post_damage(handler, hp, target, launcher, skill)
          return if launcher != @target || target == launcher
          return unless skill.type != :none
          return if target.hp <= 0
          return if target.effects.has?(:substitute) && !skill.authentic?
          return if target.type1 == skill.type && (target.type2.nil? || target.type2 == skill.type)

          handler.scene.visual.show_ability(launcher)
          target.type1 = skill.type
          target.type2 = nil
          text = parse_text_with_pokemon(19, 899, target,
            PFM::Text::PKNICK[0] => target.given_name,
            '[VAR TYPE(0001)]' => data_type(skill.type).name
          )
          handler.scene.display_message_and_wait(text)
        end
      end

      register(:metamorphosis, Metamorphosis)
    end
  end
end

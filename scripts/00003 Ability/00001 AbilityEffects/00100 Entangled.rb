module Battle
  module Effects
    class Ability
      class Entangled < Ability
        def on_post_damage(handler, hp, target, launcher, skill)
          return if launcher != @target
          return unless skill&.direct? && target && target.hp > 0
          
          heal_amount = (@target.max_hp / 16).clamp(1, Float::INFINITY)
          @target.hp += heal_amount
          @target.hp = @target.max_hp if @target.hp > @target.max_hp
          
          handler.scene.visual.show_ability(@target)
          handler.scene.visual.show_hp_animations([@target], [heal_amount])
          
          handler.scene.display_message_and_wait(parse_text_with_pokemon(400003, 33, @target))
        end
      end
      register(:entangled, Entangled)
    end
  end
end

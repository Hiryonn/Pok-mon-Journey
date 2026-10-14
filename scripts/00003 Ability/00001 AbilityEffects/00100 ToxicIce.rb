module Battle
  module Effects
    class Ability
      class ToxicIce < Ability
        def on_post_damage(handler, hp, target, launcher, skill)
          return unless skill&.type_ice?
          handler.scene.visual.show_ability(launcher)
          if launcher.can_be_frozen? && bchance?(0.2, handler.logic)
            handler.logic.status_change_handler.status_change_with_process(:poison, target)
          end
        end
      end
      register(:toxic_ice, ToxicIce)
    end
  end
end

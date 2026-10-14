module Battle
  module Effects
    class Ability
      class FerociousFury < Ability
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill
          return unless skill.effectiveness > 1

          if handler.logic.stat_change_handler.stat_increasable?(:atk, target)
            handler.scene.visual.show_ability(target)
            handler.logic.stat_change_handler.stat_change_with_process(:atk, 1, target)
          end
        end
      end

      register(:ferocious_fury, FerociousFury)
    end
  end
end

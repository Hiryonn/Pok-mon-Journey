module Battle
  module Effects
    class Ability
      class RestlessTides < Ability
        def initialize(logic, target, db_symbol)
          super
        end

        def mod3_multiplier(user, target, move)
          return 1 unless user == @target
          return 1 unless move.type_water?
          return 1.5
        end

        def on_post_damage(handler, hp, target, launcher, skill)
          return unless target == @target
          return if launcher == target
          return unless skill&.direct?
          # return if launcher.has_ability?(:clear_body) || launcher.has_ability?(:white_smoke)
          # return if launcher.effects.has?(:substitute) && !skill.authentic?

          handler.scene.visual.show_ability(target)
          handler.logic.stat_change_handler.stat_change_with_process(:spd, -1, launcher)
        end
      end
      register(:restless_tides, RestlessTides)
    end
  end
end

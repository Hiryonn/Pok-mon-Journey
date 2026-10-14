module Battle
  module Effects
    class Ability
      class Hypothermia < Ability
        def initialize(logic, target, db_symbol)
          super
        end
        def mod3_multiplier(user, target, move)
          return 1 unless user == @target
          return 1 unless move.type_ice?
          return 1.5
        end
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target) && $env.hail?
          return if @target.hp == @target.max_hp
          return if @target.dead?

          scene.visual.show_ability(@target)
          logic.damage_handler.heal(target, 0)
        end

        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct?

          handler.scene.visual.show_ability(target)
          handler.logic.status_change_handler.status_change_with_process(:freeze, launcher)
        end
      end
      register(:hypothermia, Hypothermia)
    end
  end
end

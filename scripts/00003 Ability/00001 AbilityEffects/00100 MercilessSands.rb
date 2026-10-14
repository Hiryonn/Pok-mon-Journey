module Battle
  module Effects
    class Ability
      class MercilessSands < Ability
        def initialize(logic, target, db_symbol)
          super
          @sandstorm_triggered = false
        end

        def mod3_multiplier(user, target, move)
          return 1 unless user == @target
          return 1 unless move.type_ground?
          return 1.5
        end

        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target
          return if @sandstorm_triggered
          return unless @target.hp > 0 && @target.hp < (@target.max_hp / 2)

          weather_handler = handler.logic.weather_change_handler
          return unless weather_handler.weather_appliable?(:sandstorm)

          @sandstorm_triggered = true
          handler.scene.visual.show_ability(@target)
          nb_turn = @target.hold_item?(:smooth_rock) ? 8 : 5
          weather_handler.weather_change(:sandstorm, nb_turn)
          handler.scene.visual.show_rmxp_animation(@target, 494)
        end
      end

      register(:merciless_sands, MercilessSands)
    end
  end
end

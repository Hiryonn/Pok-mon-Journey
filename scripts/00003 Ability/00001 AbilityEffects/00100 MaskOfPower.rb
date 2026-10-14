module Battle
  module Effects
    class Ability
      class MaskOfPower < Ability
        def on_move_prevention_target(user, target, move)
          return false if target != @target
          return false unless move.type_fire?
          return false unless user.can_be_lowered_or_canceled?

          move.scene.visual.show_ability(target)

          move.logic.stat_change_handler.stat_change_with_process(:dfe, 1, target, user, move)
          move.logic.stat_change_handler.stat_change_with_process(:dfs, 1, target, user, move)

          return true 
        end
      end

      register(:mask_of_power, MaskOfPower)
    end
  end
end

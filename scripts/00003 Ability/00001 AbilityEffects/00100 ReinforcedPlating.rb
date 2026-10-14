module Battle
  module Effects
    class Ability
      class ReinforcedPlating < Ability
        def base_power_multiplier(user, target, move)
          return 1 if target != self.target
          return 1 unless user.can_be_lowered_or_canceled?
          return move.physical? ? 0.5 : 1
        end

        def on_move_type_change(user, target, move, type_modifier)
          return type_modifier unless target == @target
          return type_modifier unless move.type == data_type(:fighting).id
          return type_modifier unless user.can_be_lowered_or_canceled?

          return 0 if type_modifier > 0

          return type_modifier
        end
      end

      register(:reinforced_plating, ReinforcedPlating)
    end
  end
end

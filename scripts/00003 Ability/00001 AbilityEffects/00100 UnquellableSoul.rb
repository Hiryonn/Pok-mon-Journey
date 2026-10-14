module Battle
  module Effects
    class Ability
      class UnquellableSoul < Ability
        def on_move_type_change(user, target, move, type)
          return if user != @target
          return unless target.type_normal?

          return move.type_ghost? ? 0 : nil
        end
      end
      register(:unquellable_soul, UnquellableSoul)
    end
  end
end

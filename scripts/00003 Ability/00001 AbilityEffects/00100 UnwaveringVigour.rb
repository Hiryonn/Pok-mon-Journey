module Battle
  module Effects
    class Ability
      class UnwaveringVigour < Ability
        def on_move_type_change(user, target, move, type)
          return if user != @target
          return unless target.type_ghost?

          return move.type_fighting? ? 0 : nil
        end
      end
      register(:unwavering_vigour, UnwaveringVigour)
    end
  end
end

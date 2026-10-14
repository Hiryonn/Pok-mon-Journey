module Battle
  module Effects
    class Ability
      class UnbreakableSpirit < Ability
        def on_move_type_change(user, target, move, type)
          return if user != @target
          return unless target.type_dark?

          return move.type_psychic? ? 0 : nil
        end
      end
      register(:unbreakable_spirit, UnbreakableSpirit)
    end
  end
end

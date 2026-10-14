module Battle
  module Effects
    class Ability
      class SilkWeaver < Ability
        def on_move_priority_change(user, priority, move)
          return nil if user != @target
          return nil unless move

          move_type = data_type(move.type).db_symbol

          if @target.type1 == move_type || @target.type2 == move_type
            return priority + 1
          end

          return nil
        end
      end
      register(:silkweaver, SilkWeaver)
    end
  end
end

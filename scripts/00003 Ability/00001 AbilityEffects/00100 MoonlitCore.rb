module Battle
  module Effects
    class Ability
      class MoonlitCore < Ability
        def initialize(logic, target, db_symbol)
          super
        end
        def mod3_multiplier(user, target, move)
          return 1 unless user == @target
          return 1 unless move.type_fairy?
          return 1.5
        end
      end

      register(:moonlit_core, MoonlitCore)
    end
  end
end

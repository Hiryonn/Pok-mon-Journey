module Battle
  module Effects
    class Ability
      class Brawn < Ability
        def initialize(logic, target, db_symbol)
          super
        end
        def mod3_multiplier(user, target, move)
          return 1 unless user == @target
          return 1 unless move.type_fighting?
          return 1.5
        end
      end

      register(:brawn, Brawn)
    end
  end
end

module Battle
  module Effects
    class Ability
      class MentalMight < Ability
        def sp_atk_multiplier(user, target, move)
          return 2 if user == @target
          return 1
        end
      end
      register(:mental_might, MentalMight)
    end
  end
end

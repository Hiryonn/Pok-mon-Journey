module Battle
  class Logic
    class ExpHandler
      class Gen5Formula < Gen4Formula
        # Divisor used in the base experience calculation
        # @return [Integer]
        def divisor
          return 5
        end

        # Whether Pokemon at max level can still gain effort values
        # @return [Boolean]
        def max_level_gains_ev?
          return true
        end

        # Offset added after level scaling
        # @return [Integer]
        def experience_offset
          return 1
        end

        # Level multiplier with square roots rounded to nearest 1/4096.
        # Formula: (round(sqrt(2L+10)) * (2L+10)^2) / (round(sqrt(L+Lr+10)) * (L+Lr+10)^2)
        # where L = enemy level, Lr = receiver level, round = nearest multiple of 1/4096
        # @param enemy_level [Integer] the level of the defeated enemy Pokemon
        # @param receiver_level [Integer] the level of the Pokemon receiving experience
        # @return [Float] the level multiplier
        def calculate_level_multiplier(enemy_level, receiver_level)
          enemy_base = 2.0 * enemy_level + 10
          enemy_sqrt = (Math.sqrt(enemy_base) * 4096).round / 4096.0
          enemy_term = enemy_sqrt * enemy_base**2

          combined_base = enemy_level + receiver_level + 10.0
          combined_sqrt = (Math.sqrt(combined_base) * 4096).round / 4096.0
          combined_term = combined_sqrt * combined_base**2

          return enemy_term / combined_term
        end
      end
    end
  end
end

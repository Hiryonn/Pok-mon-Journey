module Battle
  class Logic
    class ExpHandler
      class Gen1Formula < BaseFormula
        # Whether the trainer battle bonus is active
        # @return [Boolean]
        def trainer_bonus?
          return true
        end

        # Whether the trade bonus is active
        # @return [Boolean]
        def trade_bonus?
          return true
        end

        # Whether the Lucky Egg bonus is active
        # @return [Boolean]
        def lucky_egg_bonus?
          return true
        end

        # Whether Pokemon at max level can still gain effort values
        # @return [Boolean]
        def max_level_gains_ev?
          return true
        end

        # Without share receivers, splits evenly among eligible.
        # With share receivers, each fighter gets 1/(2*s) and each share receiver gets 1/share_divisor.
        # A Pokemon matching both conditions receives the sum of both shares.
        # where s = encountered count
        # @param receiver [PFM::PokemonBattler] the Pokemon receiving experience
        # @param enemy [PFM::PokemonBattler] the defeated enemy Pokemon
        # @param eligible_pokemons [Array<PFM::PokemonBattler>] all Pokemon eligible for experience
        # @return [Float] the fought multiplier
        def calculate_fought_multiplier(receiver, enemy, eligible_pokemons)
          share_receiver_count = eligible_pokemons.count { |pokemon| handler.experience_share_receiver?(pokemon) }
          return 1.0 / eligible_pokemons.size if share_receiver_count.zero?

          encountered_count = eligible_pokemons.count { |pokemon| pokemon.encountered?(enemy) }
          return 1.0 / share_receiver_count if encountered_count.zero?

          multiplier = 0.0
          multiplier += 1.0 / (2 * encountered_count) if receiver.encountered?(enemy)
          multiplier += 1.0 / calculate_share_divisor(encountered_count, share_receiver_count) if handler.experience_share_receiver?(receiver)
          return multiplier
        end

        # Calculate the divisor for the share receiver portion of the EXP split
        # @param encountered_count [Integer] the number of Pokemon that fought the enemy
        # @param share_receiver_count [Integer] the number of share receivers among eligible
        # @return [Integer] the share divisor
        def calculate_share_divisor(encountered_count, share_receiver_count)
          return 2 * encountered_count * share_receiver_count
        end
      end
    end
  end
end

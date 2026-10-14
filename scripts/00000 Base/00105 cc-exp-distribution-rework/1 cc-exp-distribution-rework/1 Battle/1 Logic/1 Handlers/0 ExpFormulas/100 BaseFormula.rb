module Battle
  class Logic
    class ExpHandler
      # Base formula providing default behavior shared by all generations.
      # Subclasses override config methods and calculation steps to implement generation-specific logic.
      # @abstract Subclass and override config methods to implement a generation-specific formula
      class BaseFormula
        # @return [Battle::Logic::ExpHandler] the parent handler (orchestrator)
        attr_reader :handler

        # Create the base formula
        # @param handler [Battle::Logic::ExpHandler] the parent handler providing access to logic and battle info
        def initialize(handler)
          @handler = handler
        end

        # Calculate the total experience a receiver gains from defeating an enemy
        # @param receiver [PFM::PokemonBattler] the Pokemon receiving experience
        # @param enemy [PFM::PokemonBattler] the defeated enemy Pokemon
        # @param eligible_pokemons [Array<PFM::PokemonBattler>] all Pokemon eligible for experience from this enemy
        # @return [Float] the calculated experience points (before flooring)
        def calculate_experience(receiver, enemy, eligible_pokemons)
          result = calculate_base_experience(enemy)
          result *= trainer_multiplier
          result *= calculate_fought_multiplier(receiver, enemy, eligible_pokemons)
          result *= calculate_level_multiplier(enemy.level, receiver.level)
          result += experience_offset
          result *= trade_multiplier(receiver)
          result *= lucky_egg_multiplier(receiver)
          result *= evolution_multiplier(receiver)
          result *= loyalty_multiplier(receiver)
          result *= experience_charm_multiplier(receiver)
          return result
        end

        # Calculate the base experience from the enemy's base_exp, level and the generation divisor
        # @param enemy [PFM::PokemonBattler] the defeated enemy Pokemon
        # @return [Float] the base experience value
        def calculate_base_experience(enemy)
          return enemy.base_exp * enemy.level / divisor
        end

        # Calculate the fought multiplier based on whether the receiver participated in battle
        # @param receiver [PFM::PokemonBattler] the Pokemon receiving experience
        # @param enemy [PFM::PokemonBattler] the defeated enemy Pokemon
        # @param eligible_pokemons [Array<PFM::PokemonBattler>] all Pokemon eligible for experience
        # @return [Float] the fought multiplier
        def calculate_fought_multiplier(receiver, enemy, eligible_pokemons)
          return 1.0 if receiver.encountered?(enemy)

          return fought_multiplier_value
        end

        # Calculate the level-based multiplier scaling experience by level difference
        # @param enemy_level [Integer] the level of the defeated enemy Pokemon
        # @param receiver_level [Integer] the level of the Pokemon receiving experience
        # @return [Float] the level multiplier
        def calculate_level_multiplier(enemy_level, receiver_level)
          return 1
        end
      end
    end
  end
end

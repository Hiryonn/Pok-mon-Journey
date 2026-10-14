module Battle
  class Logic
    # Class responsible for calculating experience & EV of Pokemon when a Pokemon faints.
    # Uses a Strategy pattern via composition: formula classes are nested inside ExpHandler
    # and encapsulate each generation's EXP calculation logic.
    # PSDK instantiates ExpHandler via ExpHandler.new(logic) and calls distribute_exp_for.
    class ExpHandler
      # @return [Battle::Logic] the logic object
      attr_reader :logic

      # Create the ExpHandler
      # @param logic [Battle::Logic] the logic object
      def initialize(logic)
        @logic = logic
      end

      # Distribute experience and effort values for a defeated enemy Pokemon
      # @param enemy [PFM::PokemonBattler] the defeated enemy Pokemon
      # @return [Hash{PFM::PokemonBattler => Integer}] mapping of Pokemon to experience gained
      def distribute_exp_for(enemy)
        return {} unless distribution_allowed?

        formula = build_formula
        eligible_for_experience = @logic.trainer_battlers.select { |pokemon| eligible_for_experience?(pokemon, enemy) }
        eligible_for_effort_values = @logic.trainer_battlers.select { |pokemon| eligible_for_effort_values?(pokemon, enemy, formula) }

        experience_data = eligible_for_experience.map do |receiver|
          experience = formula.calculate_experience(receiver, enemy, eligible_for_experience).floor
          next [receiver, experience]
        end

        update_encounter_list(eligible_for_experience, enemy)
        distribute_ev_to(eligible_for_effort_values, enemy)

        return experience_data.to_h
      end

      # Check if experience distribution is allowed
      # @return [Boolean]
      def distribution_allowed?
        return false if @logic.battle_info.disallow_exp?
        return false unless formula_generation.between?(1, 9)
        return false unless share_generation.between?(1, 9)

        return true
      end

      # Get the generation number for the experience formula from game variables
      # @return [Integer]
      def formula_generation
        return $game_variables[Yuki::Var::GEN_EXP_FORMULA]
      end

      # Get the generation number for the experience share behavior from game variables
      # @return [Integer]
      def share_generation
        return $game_variables[Yuki::Var::GEN_EXP_SHARE]
      end

      # Instantiate the formula class corresponding to the current generation
      # @return [BaseFormula]
      def build_formula
        return formula_class.new(self)
      end

      # Get the formula class corresponding to the current generation.
      # Resolved at runtime so formula files can be loaded in any order.
      # @return [Class<BaseFormula>]
      def formula_class
        case formula_generation
        when 1 then return Gen1Formula
        when 2 then return Gen2Formula
        when 3 then return Gen3Formula
        when 4 then return Gen4Formula
        when 5 then return Gen5Formula
        when 6 then return Gen6Formula
        when 7 then return Gen7Formula
        when 8 then return Gen8Formula
        when 9 then return Gen9Formula
        end
      end

      # Check if a Pokemon is eligible for experience gain
      # @param receiver [PFM::PokemonBattler] the Pokemon to check
      # @param enemy [PFM::PokemonBattler] the defeated enemy Pokemon
      # @return [Boolean]
      def eligible_for_experience?(receiver, enemy)
        return false if receiver.dead?
        return false if receiver.level == receiver.max_level
        return false unless receiver.encountered?(enemy) || experience_share_receiver?(receiver)

        return true
      end

      # Check if a Pokemon is eligible for effort value gain
      # @param receiver [PFM::PokemonBattler] the Pokemon to check
      # @param enemy [PFM::PokemonBattler] the defeated enemy Pokemon
      # @param formula [BaseFormula] the current generation formula
      # @return [Boolean]
      def eligible_for_effort_values?(receiver, enemy, formula)
        return false if receiver.dead?
        return false if receiver.level == receiver.max_level && !formula.max_level_gains_ev?
        return false unless receiver.encountered?(enemy) || experience_share_receiver?(receiver)

        return true
      end

      # Check if a Pokemon receives experience through EXP Share mechanics based on the share generation
      # @param receiver [PFM::PokemonBattler] the Pokemon to check
      # @return [Boolean]
      def experience_share_receiver?(receiver)
        case share_generation
        when 1 then return $bag.contain_item?(:exp_share)
        when 2..5 then return receiver.hold_item?(:exp_share)
        when 6..7 then return $game_switches[Yuki::Sw::EXP_SHARE]
        when 8..9 then return true
        end
      end

      # Remove the enemy from encounter lists and mark experience as distributed
      # @param pokemons [Array<PFM::PokemonBattler>] Pokemon that received experience
      # @param enemy [PFM::PokemonBattler] the defeated enemy Pokemon
      # @return [void]
      def update_encounter_list(pokemons, enemy)
        pokemons.each do |pokemon|
          next unless pokemon.encountered?(enemy)

          pokemon.delete_battler_to_encounter_list(enemy)
        end

        enemy.exp_distributed = true
      end
    end
  end
end

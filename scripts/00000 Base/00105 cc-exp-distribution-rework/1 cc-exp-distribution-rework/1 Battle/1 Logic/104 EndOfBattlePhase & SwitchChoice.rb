module Battle
  class Logic
    module EXPAfterCatchingPokemon
      # Function that process the battle end when Pokemon was caught
      def battle_phase_end_caught
        return if $game_variables[Yuki::Var::GEN_EXP_SHARE].between?(1, 5)

        super
      end
    end

    prepend EXPAfterCatchingPokemon
  end
end

module Battle
  class Visual
    # Creature the player chose to call out to instead of attacking with it
    # @return [PFM::PokemonBattler, nil] nil when the player chose a move
    def called_creature
      return nil unless @skill_choice_ui.call_requested?

      return @skill_choice_ui.pokemon
    end
  end
end

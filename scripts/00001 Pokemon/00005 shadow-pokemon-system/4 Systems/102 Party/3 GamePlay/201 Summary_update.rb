module GamePlay
  class Summary
    # Turns down the move reordering of the summary on a Shadow Pokemon. The guarantee lives on the creature
    # itself, this only spares the player a gesture that would do nothing.
    module SummaryShadowReorderPatch
      private

      # Perform the task to do when the player presses A on the skill ui
      def update_input_a_skill_ui
        # The first press only opens the move selection, which a locked heart is free to browse; the
        # ones after it pick a move up and put it down elsewhere, and those are refused.
        return play_buzzer_se if @selecting_move && @pokemon.shadow?

        return super
      end
    end

    prepend SummaryShadowReorderPatch
  end
end

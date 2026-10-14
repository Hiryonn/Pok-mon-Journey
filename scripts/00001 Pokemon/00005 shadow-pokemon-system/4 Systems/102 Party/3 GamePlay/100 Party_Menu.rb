module GamePlay
  class Party_Menu
    # Sentence of the top of the screen and the line each creature carries, for the purification.
    module PartyMenuPurificationPatch
      # Initialize the win_text according to the mode
      def init_win_text
        return super unless @mode == :purification

        purification_button_update
        @base_ui.show_win_text(PFM::ShadowTexts.message(:purify_which))
      end
    end

    prepend PartyMenuPurificationPatch
  end
end

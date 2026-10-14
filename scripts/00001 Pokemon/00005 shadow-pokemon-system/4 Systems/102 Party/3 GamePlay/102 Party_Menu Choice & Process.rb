module GamePlay
  class Party_Menu
    CHOICE_METHODS[:purification] = :show_purification_menu_choice

    # Show the choice when the party is in mode :purification
    def show_purification_menu_choice
      show_black_frame
      # @type [PFM::Pokemon]
      pokemon = @party[@index]
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices
        .register_choice(PFM::ShadowTexts.message(:purify_choice), on_validate: method(:on_purification_choice),
                                                                   disable_detect: proc { !pokemon.purifiable? })
        .register_choice(text_get(23, 4), on_validate: method(:launch_summary)) # Summary
        .register_choice(text_get(23, 1), on_validate: @base_ui.method(:hide_win_text)) # Cancel
      @base_ui.show_win_text(parse_text(23, 30, ::PFM::Text::PKNICK[0] => pokemon.given_name))
      x, y = get_choice_coordinates(choices)
      choice = choices.display_choice(@viewport, x, y, nil, choices, on_update: method(:update_menu_choice))
      hide_black_frame
      @base_ui.show_win_text(PFM::ShadowTexts.message(:purify_which)) if choice != 0
    end

    # Event that triggers when the player has chosen the creature to purify
    def on_purification_choice
      @return_data = $game_variables[Yuki::Var::Party_Menu_Sel] = @index
      @running = false
    end

    # Write on every team button whether the heart of the creature is empty enough to open
    def purification_button_update
      @team_buttons.each do |button|
        button.show_item_name
        ready = button.data.purifiable?
        button.item_text.load_color(ready ? 1 : 2).text = parse_text(22, ready ? 140 : 141)
      end
    end
  end
end

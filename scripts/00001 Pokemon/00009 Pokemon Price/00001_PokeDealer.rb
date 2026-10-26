# Script décompilé depuis le bytecode du jeu (Ruby 3.0) — fichier d'origine : RMXP/00103_PokeDealer.rb
# Les commentaires et la mise en forme d'origine ne sont pas récupérables.

module GamePlay
  class PokemonStorage
    def release_pokemon
      if @current_pokemon.db_symbol == :kyurem && @current_pokemon.absofusionned?
        display_message(text_get(33, 108))
      else
        name = @current_pokemon.given_name
        choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 0)
        choices.register_choice(send(*RELEASE_POKEMON_CHOICES[0])).register_choice(send(*RELEASE_POKEMON_CHOICES[1]))
        @base_ui.show_win_text(format(send(*RELEASE_POKEMON_MESSAGE1), name: name))
        choice = choices.display_choice(@viewport, *choice_coordinates(choices), nil, on_update: method(:update_graphics), align_right: true)
        @base_ui.hide_win_text
        if choice == 1
          display_message(get_candy_from(@current_pokemon))
          @selection.release_selected_pokemon
          refresh
        end
      end
    end

    def release_selected_pokemon
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 0)

      choices.register_choice(send(*RELEASE_POKEMON_CHOICES[0])).register_choice(send(*RELEASE_POKEMON_CHOICES[1]))
      @base_ui.show_win_text(format(send(*RELEASE_SELECTED_POKEMON_MESSAGE), count: @current_pokemons.size))
      choice = choices.display_choice(@viewport, *choice_coordinates(choices), nil, on_update: method(:update_graphics), align_right: true)
      @base_ui.hide_win_text
      if choice == 1
        for pokemon in @current_pokemons
          display_message(get_candy_from(pokemon))
        end
        @selection.release_selected_pokemon
        refresh
      end
    end

    def get_candy_from(pokemon)
      phrase = $options.language == "en" ? " has been released." : " a été relâché."
      return pokemon.given_name + phrase if pokemon.egg?
      catch_rate = pokemon.rareness
      candy_name = "\\c[2]Bonbon\\c[0]"
      chattes = $options.language == "en" ? "Exp candy" : "Bonbon exp"
      Audio.se_play("audio/me/rosa_levelup")
      quantity = pokemon.shiny? ? 2 : 1

      if catch_rate.between?(190, 255)
        candy_name = "\\c[2]#{chattes} XS\\c[0]"
        $bag.add_item(:exp_candy_xs, quantity)
      elsif catch_rate.between?(140, 180)
        candy_name = "\\c[2]#{chattes} S\\c[0]"
        $bag.add_item(:exp_candy_s, quantity)
      elsif catch_rate.between?(90, 130)
        candy_name = "\\c[2]#{chattes} M\\c[0]"
        $bag.add_item(:exp_candy_m, quantity)
      elsif catch_rate.between?(45, 75)
        candy_name = "\\c[2]#{chattes} L\\c[0]"
        $bag.add_item(:exp_candy_l, quantity)
      elsif catch_rate.between?(3, 35)
        candy_name = "\\c[2]#{chattes} XL\\c[0]"
        $bag.add_item(:exp_candy_xl, quantity)
      end

      phrase = $options.language == "en" ? " has been released. Gary receives #{quantity} #{candy_name}!" : " a été relâché. Régis reçoit #{quantity} #{candy_name} !"

      pokemon.given_name + phrase
    end
  end
end

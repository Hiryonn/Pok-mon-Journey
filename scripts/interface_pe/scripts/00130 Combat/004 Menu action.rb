# Interface PE — combat : menu d'action (Attaque / Sac / Pokémon / Fuite)
module BattleUI
  class PlayerChoice
    module PJStyle
      include PJ::Panel
      # Nom du Pokémon qui choisit (affiché à gauche)
      # @param name [String]
      def pj_pokemon_name=(name)
        self.pj_lines = [PJ.text(:what), format(PJ.text(:what_end), name), PJ.text(:hint_choice)] if @pj
      end

      private

      def create_sprites
        return super unless PJ.active?

        @pj = true
        create_pj_panel
        super
        pj_hide_special_buttons(@sub_choice)
      end

      # Boutons Attaque / Sac / Pokémon / Fuite
      def create_buttons
        return super unless @pj

        @buttons = pj_button_keys.map.with_index do |key, i|
          button = add_sprite(*pj_cell(i), nil, pj_button_image, pj_button_rows, PJ.text(key), type: PJ::GridButton)
          button.row = pj_button_row(i)
          next button
        end
      end

      # @return [Array<Symbol>]
      def pj_button_keys
        return %i[attack bag pokemon flee]
      end

      def pj_button_image
        return 'action_buttons'
      end

      def pj_button_rows
        return 2
      end

      # @param _index [Integer]
      # @return [Integer] ligne du fond (non choisi)
      def pj_button_row(_index)
        return 0
      end

      def create_cursor
        return super unless @pj

        @cursor = add_sprite(0, 0, PJ.file('button_cursor'), type: PJ::FrameCursor)
      end

      def cursor_offset_x
        return @pj ? 0 : super
      end

      def cursor_offset_y
        return @pj ? 0 : super
      end

      def update_button_opacity
        return super unless @pj

        @buttons.each_with_index do |button, index|
          button.opacity = 255
          button.selected = index == @index if button.respond_to?(:selected=) && pj_button_rows == 2
        end
      end
    end
    prepend PJStyle if PJ::ENABLED
  end
end

module Battle
  class Visual
    module PJStyle
      # Texte « Que doit faire X ? » à gauche du menu d'action
      def spc_show_message(pokemon_index)
        super
        pokemon = @scene.logic.battler(0, pokemon_index)
        @player_choice_ui.pj_pokemon_name = pokemon.given_name if pokemon && @player_choice_ui.respond_to?(:pj_pokemon_name=)
      end
    end
    prepend PJStyle if BattleUI::PJ::ENABLED
  end
end

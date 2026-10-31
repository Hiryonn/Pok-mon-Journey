# Interface PE — combat : menu d'action (Attaque / Sac / Pokémon / Fuite) et boutons communs
module BattleUI
  module PJ
    # Curseur : cadre blanc posé sur le bouton choisi (sans le va-et-vient de la flèche de PSDK)
    class FrameCursor < Cursor
      def register_positions
        super
        @target_x = x
        @target_y = y
      end
    end

    # Bouton de la grille 2 x 2 : fond (image en feuille, une ligne par état) + texte centré
    class GridButton < UI::SpriteStack
      # @param viewport [Viewport]
      # @param image [String] image dans battle_pj (feuille : 1 colonne, rows lignes de 28 px)
      # @param rows [Integer]
      # @param text [String]
      def initialize(viewport, image, rows, text)
        super(viewport)
        @background = add_sprite(0, 0, PJ.file(image), 1, rows, type: SpriteSheet)
        @text = add_text(0, 5, PJ::CELL_W, 16, text, 1, 1, color: PJ::WHITE)
      end

      # @param row [Integer] ligne de la feuille
      def row=(row)
        @background.sy = row
      end

      # @param value [Boolean] bouton choisi (fond clair, texte foncé)
      def selected=(value)
        return if @selected == value

        @selected = value
        self.row = value ? 1 : 0
        @text.load_color(value ? PJ::DARK : PJ::WHITE)
      end

      # Largeur / hauteur pour la souris
      def simple_mouse_in?(mouse_x = Mouse.x, mouse_y = Mouse.y)
        return mouse_x.between?(x, x + PJ::CELL_W - 1) && mouse_y.between?(y, y + PJ::CELL_H)
      end
    end

    # Bande sombre du bas + texte à gauche (commun aux menus)
    module Panel
      private

      # @param lines [Integer] nombre de lignes de texte à gauche
      def create_pj_panel(lines = 3)
        add_sprite(0, PJ::PANEL_Y, PJ.file('command_panel'))
        @pj_lines = Array.new(lines) { |i| add_text(8, PJ::PANEL_Y + 2 + i * 16, PJ::GRID_X - 12, 16, '', 0, 1, color: PJ::WHITE) }
      end

      # @param texts [Array<String>]
      def pj_lines=(texts)
        @pj_lines&.each_with_index { |text, i| text.text = texts[i].to_s }
      end

      # Position de la case n° index de la grille
      # @param index [Integer]
      # @return [Array(Integer, Integer)]
      def pj_cell(index)
        return PJ::GRID_X + (index % 2) * PJ::CELL_W, PJ::GRID_Y + (index / 2) * PJ::CELL_H
      end

      # Les boutons X / Y de PSDK (objet, infos, description, méga) restent actifs mais hors de l'écran
      def pj_hide_special_buttons(sub_choice)
        sub_choice&.instance_variables&.each do |ivar|
          sprite = sub_choice.instance_variable_get(ivar)
          sprite.set_position(-400, -400) if sprite.is_a?(UI::SpriteStack) && ivar.to_s.end_with?('_button')
        end
      end
    end
  end

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

  # Safari : bandes Safari Ball / Appât / Boue / Fuite
  class PlayerChoiceSafari
    module PJStyle
      private

      def create_buttons
        return super unless @pj

        @buttons = pj_button_keys.map.with_index do |key, i|
          button = add_sprite(*pj_cell(i), nil, 'safari_buttons', 4, PJ.text(key), type: PJ::GridButton)
          button.row = i
          next button
        end
      end

      def pj_button_keys
        return %i[safari_ball bait mud flee]
      end

      def pj_button_rows
        return 4
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

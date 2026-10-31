# Interface PE — combat : éléments communs aux menus (curseur, boutons de la grille, bande du bas)
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

      # @param value [Boolean] bouton choisi (fond plus clair, le texte reste blanc)
      def selected=(value)
        return if @selected == value

        @selected = value
        self.row = value ? 1 : 0
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
        @pj_lines = Array.new(lines) { |i| add_text(8, PJ::PANEL_Y + 6 + i * 18, PJ::GRID_X - 12, 16, '', 0, 1, color: PJ::WHITE) }
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
end

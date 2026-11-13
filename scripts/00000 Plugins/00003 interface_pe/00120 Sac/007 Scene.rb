# Sac PE : habillage de la scène GamePlay::Bag
module GamePlay
  class Bag
    # Habillage du sac (la logique de PSDK reste inchangée)
    module PEStyle
      public

      # Souris : clic sur une case, clic droit pour revenir
      def update_mouse(moved)
        return false if @animation
        return false if update_pe_grid_click

        return super
      end

      private

      def create_base_ui
        @base_ui = UI::BagPE::BaseUI.new(@viewport, button_texts)
      end

      def create_pocket_ui
        @pocket_ui = UI::BagPE::Tabs.new(@viewport, @pocket_indexes)
        @pocket_ui.index = @socket_index
        @pocket_name = UI::BagPE::Title.new(@viewport)
        update_pocket_name
      end

      def create_scroll_bar
        @scroll_bar = UI::BagPE::NoScrollBar.new
      end

      def update_scroll_bar
        @scroll_bar.max_index = @last_index
        @scroll_bar.index = @index
      end

      def create_bag_sprite
        @bag_sprite = UI::BagPE::NoBagSprite.new
      end

      def create_item_list
        @item_button_list = UI::BagPE::ItemGrid.new(@viewport)
        update_item_button_list
      end

      def create_arrow
        @arrow = UI::BagPE::NoArrow.new
      end

      def create_info
        @info_compact = UI::BagPE::InfoPanel.new(@viewport, @mode)
        @info_wide = UI::BagPE::NoInfo.new(@mode)
        update_info_visibility
        update_info
      end

      # X affiche / cache le panneau ; sans panneau la grille montre plus de lignes
      def update_info_visibility
        super
        @item_button_list.rows = @compact_mode == :enabled ? UI::BagPE::ROWS_WITH_PANEL : UI::BagPE::ROWS_FULL
      end

      def create_shadow
        @shadows = %i[enabled disabled].to_h do |key|
          sprite = Sprite.new(@viewport).set_bitmap(UI::BagPE.file('shadow'), :interface).set_z(3)
          sprite.visible = false
          [key, sprite]
        end
      end

      # Le cadre de PSDK (bandeau « SAC ») n'existe pas dans ce design
      def create_frame; end

      # Dernier index sélectionnable (la grille n'a pas de case « Fermer le sac »)
      # @return [Integer]
      def pe_last_item
        return [@item_list.size - 1, 0].max
      end

      # Gauche / droite : case précédente / suivante ; au bord de la grille, poche voisine
      def update_socket_input
        dir = Input.repeat?(:LEFT) ? -1 : (Input.repeat?(:RIGHT) ? 1 : 0)
        return true if dir == 0

        col = @index % UI::BagPE::COLUMNS
        at_edge = dir < 0 ? col == 0 : (col == UI::BagPE::COLUMNS - 1 || @index >= pe_last_item)
        play_cursor_se
        if at_edge
          return false if @searching

          change_pocket((@socket_index + dir) % (@last_socket_index + 1))
        else
          pe_select(@index + dir)
        end
        return false
      end

      # Haut / bas : ligne précédente / suivante
      def update_list_input
        dir = Input.repeat?(:UP) ? -1 : (Input.repeat?(:DOWN) ? 1 : 0)
        return true if dir == 0

        target = @index + dir * UI::BagPE::COLUMNS
        target = pe_last_item if dir > 0 && target > pe_last_item && @index / UI::BagPE::COLUMNS < pe_last_item / UI::BagPE::COLUMNS
        return false if target.negative? || target > pe_last_item

        play_cursor_se
        pe_select(target)
        return false
      end

      # Molette : une ligne par cran
      def update_mouse_index
        pe_select((@index - Mouse.wheel * UI::BagPE::COLUMNS).clamp(0, pe_last_item))
        Mouse.wheel = 0
        return false
      end

      # @param index [Integer]
      def pe_select(index)
        @index = index.clamp(0, pe_last_item)
        update_item_button_list
        update_info
        @scroll_bar.index = @index
      end

      # @return [Boolean] true si le clic a été utilisé
      def update_pe_grid_click
        return false if @searching

        if Mouse.trigger?(:RIGHT)
          action_b
          return true
        end
        return false unless Mouse.trigger?(:LEFT)

        position = @item_button_list.position_at(Mouse.x, Mouse.y)
        return false unless position

        position == @index ? action_a : pe_select(position)
        return true
      end
    end
    prepend PEStyle if UI::BagPE::ENABLED
  end
end

# Sac Horizon : habillage de la scène GamePlay::Bag (la logique de PSDK reste inchangée)
module GamePlay
  class Bag
    module HorizonStyle
      public

      # Souris : clic sur un objet ou une poche, clic droit pour revenir
      def update_mouse(moved)
        return false if @animation
        return false if update_horizon_click

        return super
      end

      def update_graphics
        super
        @horizon_party&.update
      end

      private

      def create_base_ui
        @base_ui = UI::BagHorizon::BaseUI.new(@viewport, button_texts)
      end

      def create_pocket_ui
        @pocket_ui = UI::BagHorizon::Pockets.new(@viewport, @pocket_indexes)
        @pocket_ui.index = @socket_index
        @pocket_name = UI::BagHorizon::Title.new(@viewport)
        update_pocket_name
      end

      def create_scroll_bar
        @scroll_bar = UI::BagHorizon::NoScrollBar.new
        update_scroll_bar
      end

      def create_bag_sprite
        @bag_sprite = UI::BagHorizon::NoBagSprite.new
      end

      def create_item_list
        @horizon_party = UI::BagHorizon::Party.new(@viewport)
        @item_button_list = UI::BagHorizon::ItemList.new(@viewport)
        update_item_button_list
      end

      def create_arrow
        @arrow = UI::BagHorizon::NoArrow.new
      end

      def create_info
        @info_compact = UI::BagHorizon::InfoBar.new(@viewport, @mode)
        @info_wide = UI::BagHorizon::NoInfo.new(@mode)
        @compact_mode = :enabled
        update_info_visibility
        update_info
      end

      # La description reste toujours affichée
      def action_x; end

      # La description et l'équipe suivent l'objet choisi
      def update_info
        super
        refresh_horizon_party
        @pocket_name&.refresh_money
      end

      # Équipe du sac (celle du combat dans le sac de combat)
      # @return [Array<PFM::Pokemon>]
      def horizon_team
        return @team || $actors || []
      end

      def refresh_horizon_party
        @horizon_party&.refresh(horizon_team, @item_list[@index], self)
        return nil
      end

      def create_shadow
        @shadows = %i[enabled disabled].to_h do |key|
          sprite = Sprite.new(@viewport).set_bitmap(UI::BagHorizon.file('shadow'), :interface).set_z(3)
          sprite.set_position(UI::BagHorizon.gauche, 0)
          sprite.zoom_x = UI::BagHorizon.largeur / 320.0
          sprite.visible = false
          [key, sprite]
        end
      end

      # Le cadre de PSDK (bandeau « SAC ») n'existe pas dans ce design
      def create_frame; end

      # Sons du sac
      def play_cursor_se
        Audio.se_play(UI::BagHorizon::SE_CURSOR)
      rescue StandardError
        super
      end

      def update_socket_input
        return true unless index_changed(:@socket_index, :LEFT, :RIGHT, @last_socket_index)

        play_horizon_pocket_se
        change_pocket(@socket_index)
        return false
      end

      def play_horizon_pocket_se
        Audio.se_play(UI::BagHorizon::SE_POCKET)
      rescue StandardError
        play_cursor_se
      end

      # Molette : une ligne par cran
      def update_mouse_index
        horizon_select((@index - Mouse.wheel).clamp(0, @last_index))
        Mouse.wheel = 0
        return false
      end

      # @param index [Integer]
      def horizon_select(index)
        @index = index.clamp(0, @last_index)
        update_item_button_list
        update_info
        @scroll_bar.index = @index
      end

      # @return [Boolean] true si le clic a été utilisé
      def update_horizon_click
        return false if @searching

        if Mouse.trigger?(:RIGHT)
          action_b
          return true
        end
        return false unless Mouse.trigger?(:LEFT)

        pocket = @pocket_ui.stack.find_index(&:simple_mouse_in?)
        if pocket
          play_horizon_pocket_se
          change_pocket(pocket) if pocket != @socket_index
          return true
        end
        position = @item_button_list.position_at(Mouse.x, Mouse.y)
        return false unless position

        if position == @index
          action_a
        else
          play_cursor_se
          horizon_select(position)
        end
        return true
      end
    end
    prepend HorizonStyle if UI::BagHorizon::ENABLED
  end
end

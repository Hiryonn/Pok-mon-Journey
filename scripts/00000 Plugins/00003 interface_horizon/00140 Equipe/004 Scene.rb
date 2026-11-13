# Équipe PE : habillage de GamePlay::Party_Menu (menu, choix, combat, objet, sélection…)
module GamePlay
  class Party_Menu
    # Habillage (la logique de PSDK reste inchangée)
    module PEStyle
      private

      def create_base_ui
        @base_ui = UI::PartyPE::BaseUI.new(@viewport, button_texts)
        @base_ui.info = party_info_text
        auto_adjust_button
      end

      # Mode « sélection » : les boutons X et B sont échangés
      def auto_adjust_button
        return unless @mode == :select

        ctrl = @base_ui.ctrl
        ctrl[3], ctrl[1] = ctrl[1], ctrl[3]
        ctrl[3].set_position(*UI::PartyPE::NavButton::COORDINATES[3])
        ctrl[1].set_position(*UI::PartyPE::NavButton::COORDINATES[1])
      end

      # @return [String] « 3 / 6 » à droite du bandeau
      def party_info_text
        return "#{@party.size} / 6"
      end

      def create_team_buttons
        @team_buttons = Array.new(@party.size) do |i|
          button = UI::PartyPE::Card.new(@viewport, i)
          button.data = @party[i]
          next button
        end
      end

      # Pas de cadre « Équipe » par-dessus : le titre est dans le bandeau
      def create_frames
        @black_frame = Sprite.new(@viewport)
        @black_frame.visible = false
        @frame = Sprite.new(@viewport)
      end

      def create_selector
        @selector = Sprite.new(@viewport).set_bitmap(UI::PartyPE.file('selector'), :interface)
        @selector.src_rect.set(0, 0, UI::PartyPE::CARD_WIDTH, UI::PartyPE::CARD_HEIGHT)
        update_selector_coordinates
      end

      # Clignotement du curseur
      def update_selector
        @counter += 1
        if @counter == 30
          @selector.src_rect.y = UI::PartyPE::CARD_HEIGHT
        elsif @counter >= 60
          @counter = 0
          @selector.src_rect.y = 0
        end
      end

      def update_selector_coordinates(*)
        button = @team_buttons[@index]
        @selector.set_position(button.x, button.y) if button
      end

      def show_black_frame
        @black_frame.set_bitmap(UI::PartyPE.file("dark#{@index + 1}"), :interface)
        @black_frame.visible = true
        @black_frame.src_rect.height = FRAME_HEIGHT if FRAME_HEIGHT
        1.upto(8) do |i|
          @black_frame.opacity = i * 255 / 8
          update_during_process
          Graphics.update
        end
      end
    end

    prepend PEStyle if UI::PartyPE::ENABLED
  end
end

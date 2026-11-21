# Résumé PE : habillage de la scène GamePlay::Summary
module GamePlay
  class Summary
    # Habillage du résumé (la logique de PSDK reste inchangée)
    module PEStyle
      private

      def create_base
        @base_ui = UI::SummaryPE::BaseUI.new(@viewport, load_texts, KEYS, ctrl_id_state)
        init_win_text
      end

      def create_uis
        @uis = [UI::SummaryPE::InfoPage.new(@viewport), UI::SummaryPE::StatsPage.new(@viewport), UI::SummaryPE::MovesPage.new(@viewport),
                UI::SummaryPE::ContestPage.new(@viewport), UI::SummaryPE::RibbonsPage.new(@viewport), UI::SummaryPE::MemoPage.new(@viewport),
                UI::SummaryPE::FamilyPage.new(@viewport)]
      end

      def create_top_ui
        @top = UI::SummaryPE::Header.new(@viewport)
      end

      def update_ui_visibility
        super
        @top.page = @index
      end

      # Les pages mémo et arbre familial utilisent les mêmes boutons que la page stats
      def ctrl_id_state
        return ctrl_id_state_stats_page if @index >= UI::SummaryPE::MEMO_PAGE

        return super
      end

      def update_inputs_view
        return update_inputs_egg if @pokemon.egg?

        if @index >= UI::SummaryPE::MEMO_PAGE
          update_inputs_basic
          return true
        end
        return super
      end

      # Un œuf n'a que deux pages : la sienne et son arbre familial
      def update_inputs_egg
        if Input.trigger?(:LEFT) || Input.trigger?(:RIGHT)
          toggle_egg_page
        else
          update_inputs_basic
        end
        return true
      end

      def toggle_egg_page
        play_cursor_se
        @index = @index == UI::SummaryPE::FAMILY_PAGE ? 0 : UI::SummaryPE::FAMILY_PAGE
        update_ui_visibility
      end

      def mouse_left
        return toggle_egg_page if @mode == :view && @pokemon.egg?

        super
      end

      def mouse_right
        return toggle_egg_page if @mode == :view && @pokemon.egg?

        super
      end

      # Les boutons du bas sont masqués : on ne les teste plus à la souris
      def update_mouse_ctrl; end

      # L'échange rapide par petits boutons de PSDK n'existe pas dans ce design
      def update_mouse_switch_skill(_skill, _index); end

      # Page Souvenirs : A sur un souvenir sélectionné ouvre son menu (titre, déplacer, trier)
      def update_input_a_ribbons_ui
        page = @uis[4]
        return super unless @selecting_ribbon && page.respond_to?(:memento_menu)
        return play_buzzer_se if page.list.empty?

        page.memento_menu(self)
      end

      # B pendant un déplacement de souvenir : annule le déplacement
      def update_input_b_ribbons_ui
        page = @uis[4]
        return super unless @selecting_ribbon && page.respond_to?(:moving?) && page.moving?

        play_cancel_se
        page.cancel_move
      end

      # Après un changement d'ordre des capacités, l'aperçu de la page stats suit
      def update_input_a_skill_ui
        result = super
        @uis[1].data = @pokemon
        return result
      end

      public

      def update_graphics
        super
        @uis[4].update_face if @uis[4].respond_to?(:update_face)
      end

      def update_mouse(moved)
        super
        update_header_mouse
      end

      private

      # Clics sur le bandeau du haut
      def update_header_mouse
        return unless Mouse.trigger?(:LEFT)

        busy = @selecting_move || @selecting_ribbon || @skill_index.to_i >= 0
        case @top.button_at(Mouse.x, Mouse.y)
        when :switch
          mouse_next if @mode == :view && @party.size > 1 && !busy
        when :prev
          mouse_left unless busy
        when :next
          mouse_right unless busy
        when :back
          busy ? mouse_cancel : mouse_quit
        end
      end
    end

    if UI::SummaryPE::ENABLED
      prepend PEStyle
      # Deux pages de plus (mémo, arbre familial) après les rubans
      remove_const(:LAST_STATE)
      LAST_STATE = UI::SummaryPE::FAMILY_PAGE
    end
  end
end

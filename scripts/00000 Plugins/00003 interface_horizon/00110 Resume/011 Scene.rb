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
                UI::SummaryPE::ContestPage.new(@viewport), UI::SummaryPE::RibbonsPage.new(@viewport), UI::SummaryPE::MemoPage.new(@viewport)]
      end

      def create_top_ui
        @top = UI::SummaryPE::Header.new(@viewport)
      end

      def update_ui_visibility
        super
        @top.page = @index
      end

      # La page mémo utilise les mêmes boutons que la page stats
      def ctrl_id_state
        return ctrl_id_state_stats_page if @index == UI::SummaryPE::MEMO_PAGE

        return super
      end

      def update_inputs_view
        if @index == UI::SummaryPE::MEMO_PAGE
          update_inputs_basic
          return true
        end
        return super
      end

      # Les boutons du bas sont masqués : on ne les teste plus à la souris
      def update_mouse_ctrl; end

      # L'échange rapide par petits boutons de PSDK n'existe pas dans ce design
      def update_mouse_switch_skill(_skill, _index); end

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
      # Une page de plus (mémo) après les rubans
      remove_const(:LAST_STATE)
      LAST_STATE = UI::SummaryPE::MEMO_PAGE
    end
  end
end

# Enhanced Battle UI — infos de l'attaque pendant le choix de l'attaque (touche X)
#
# Le panneau s'ouvre avec X, suit l'attaque choisie quand on change d'attaque, et se ferme avec X ou B.
module BattleUI
  class SkillChoice
    module EBUIMoveInfo
      # Ouvre / ferme le panneau des infos de l'attaque
      # @return [Boolean] le panneau est ouvert
      def ebui_toggle_panel
        @ebui_wanted = !@ebui_wanted
        ebui_refresh_panel
        return @ebui_wanted
      end

      # Ferme le panneau
      def ebui_close_panel
        @ebui_wanted = false
        @ebui_panel&.visible = false
      end

      # @return [Boolean]
      def ebui_panel_open?
        return @ebui_wanted && @ebui_panel&.visible ? true : false
      end

      # @param pokemon [PFM::PokemonBattler]
      def reset(pokemon)
        @ebui_wanted = false unless BattleUI::EBUI::KEEP_MOVE_PANEL
        super
        ebui_refresh_panel
      end

      def go_in
        super
        ebui_refresh_panel
      end

      def go_out(*args)
        super
        @ebui_panel&.visible = false
      end

      def dispose
        @ebui_panel&.dispose
        @ebui_panel = nil
        super
      end

      private

      # Met le panneau à jour (attaque choisie)
      def ebui_refresh_panel
        return unless BattleUI::EBUI.enabled?
        return @ebui_panel&.visible = false unless @ebui_wanted && @pokemon && in?

        @ebui_panel ||= BattleUI::EBUI::MovePanel.new(@viewport, ebui_panel_y)
        @ebui_panel.show_move(@pokemon.moveset[@index], @pokemon, @scene.logic)
      end

      # @return [Integer]
      def ebui_panel_y
        return BattleUI::EBUI::MOVE_PANEL_Y unless BattleUI::EBUI.pe_ui?

        return BattleUI::PJ::PANEL_Y - BattleUI::EBUI::MovePanel::HEIGHT - BattleUI::EBUI::MOVE_PANEL_GAP_PE
      end

      def update_cursor(*args)
        super
        ebui_refresh_panel
      end

      def validate
        super
        @ebui_panel&.visible = false if validated?
      end

      # B ferme d'abord le panneau
      def cancel
        return super unless ebui_panel_open?

        ebui_close_panel
        play_cancel_se
      end
    end
    prepend EBUIMoveInfo if BattleUI::EBUI::ENABLED

    class SubChoice
      module EBUIMoveInfo
        private

        # X : panneau des infos (à la place de la description de PSDK)
        def action_x
          return super unless BattleUI::EBUI.enabled? && BattleUI::EBUI::MOVE_INFO_KEY == :X

          ebui_action
        end

        def action_y
          return super unless BattleUI::EBUI.enabled? && BattleUI::EBUI::MOVE_INFO_KEY == :Y

          ebui_action
        end

        def ebui_action
          return play_buzzer_se unless @choice.pokemon&.moveset&.[](@choice.index)

          @choice.ebui_toggle_panel ? play_decision_se : play_cancel_se
        end
      end
      prepend EBUIMoveInfo if BattleUI::EBUI::ENABLED
    end
  end
end

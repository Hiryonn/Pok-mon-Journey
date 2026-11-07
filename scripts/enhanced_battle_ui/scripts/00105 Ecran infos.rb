# Enhanced Battle UI — écran des infos des combattants, ouvert avec Y pendant le choix de l'action
#
#   choix du Pokémon (flèches, A) → page d'infos (◄► autre Pokémon, ▲▼ effets, B retour au choix) → B ferme
module BattleUI
  module EBUI
    class InfoScreen
      # Profondeur de l'écran (au-dessus de l'interface de combat)
      Z = 5000

      # @param scene [Battle::Scene]
      def initialize(scene)
        @scene = scene
        @state = :closed
        @closed_frame = -1
      end

      # @return [Boolean]
      def open?
        return @state != :closed
      end

      # @return [Boolean] l'écran vient d'être fermé (ce tour de jeu)
      def just_closed?
        return @closed_frame == Graphics.frame_count
      end

      # Ouvre le choix du Pokémon
      # @param current [PFM::PokemonBattler, nil] Pokémon choisi au départ
      def open(current = nil)
        @battlers = field_battlers
        return false if @battlers.empty?

        create_ui
        @start = @battlers.index(current) || 0
        show(:select, @start)
        return true
      end

      # Ferme tout
      def close
        dispose_ui
        @state = :closed
        @closed_frame = Graphics.frame_count
      end

      def update
        return unless open?

        @select&.update
        @info&.update
        @state == :select ? update_select : update_info
      end

      def dispose
        dispose_ui
      end

      private

      # Pokémon sur le terrain : joueur puis adversaires
      # @return [Array<PFM::PokemonBattler>]
      def field_battlers
        logic = @scene.logic
        count = logic.battle_info.vs_type
        return [0, 1].flat_map { |bank| count.times.map { |position| logic.battler(bank, position) } }.compact.select(&:alive?)
      rescue StandardError
        return []
      end

      def create_ui
        dispose_ui
        @viewport = Viewport.create(:main, Z)
        @select = BattlerSelect.new(@viewport, @scene.logic)
        @info = BattlerInfo.new(@viewport, @scene.logic)
      end

      def dispose_ui
        @select&.dispose
        @info&.dispose
        @viewport&.dispose
        @select = @info = @viewport = nil
      end

      # @param state [Symbol] :select ou :info
      # @param index [Integer] Pokémon choisi
      def show(state, index = @select.index)
        @state = state
        @select.visible = state == :select
        @info.visible = state == :info
        @select.refresh(@battlers, index) # (aussi en mode infos : garde le Pokémon choisi)
        @select.visible = false if state == :info
        @info.show_battler(@battlers[@select.index], @battlers.size > 1) if state == :info
      end

      def update_select
        if Input.trigger?(:B)
          play_cancel_se
          return close
        end
        if Input.trigger?(:A)
          play_decision_se
          return show(:info)
        end
        play_cursor_se if @select.update_input
      end

      def update_info
        if Input.trigger?(:B)
          play_cancel_se
          return show(:select)
        end
        if (step = Input.repeat?(:LEFT) ? -1 : Input.repeat?(:RIGHT) ? 1 : 0) != 0 && @battlers.size > 1
          play_cursor_se
          return show(:info, (@select.index + step) % @battlers.size)
        end
        play_cursor_se if @info.update_input
      end
    end
  end

  class PlayerChoice
    class SubChoice
      module EBUIBattlerInfo
        def update
          return super unless @ebui_screen&.open?

          @ebui_screen.update
        end

        # Le choix de l'action attend que l'écran soit fermé (et ignore la touche qui l'a fermé)
        def done?
          return false if @ebui_screen && (@ebui_screen.open? || @ebui_screen.just_closed?)

          return super
        end

        def reset
          @ebui_screen&.close if @ebui_screen&.open?
          super
        end

        def dispose
          @ebui_screen&.dispose
          super
        end

        private

        def action_y
          return super unless BattleUI::EBUI.enabled? && BattleUI::EBUI::BATTLER_INFO_KEY == :Y

          ebui_open
        end

        def action_x
          return super unless BattleUI::EBUI.enabled? && BattleUI::EBUI::BATTLER_INFO_KEY == :X

          ebui_open
        end

        def ebui_open
          @ebui_screen ||= BattleUI::EBUI::InfoScreen.new(@scene)
          current = @scene.logic.battler(0, @scene.player_actions.size)
          @ebui_screen.open(current) ? play_decision_se : play_buzzer_se
        end
      end
      prepend EBUIBattlerInfo if BattleUI::EBUI::ENABLED
    end
  end
end

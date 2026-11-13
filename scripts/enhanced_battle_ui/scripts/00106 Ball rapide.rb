# Enhanced Battle UI — lancer rapide de Poké Ball en combat sauvage (touche X pendant le choix de l'action)
#
#   ┌ A : lancer ┐   ┌ nom de la Ball ┐   ┌ Y : descr. ┐
#    Ball  Ball        (Ball choisie)        Ball  Ball
#    [x3]  [x10]          [x5]               [x1]  [x2]
#
# ◄► : Ball précédente / suivante, A : lancer, Y : description, B : retour.
module BattleUI
  module EBUI
    class BallSelector < UI::SpriteStack
      # Hauteur du bandeau (ball_bg.png)
      HEIGHT = 66
      # Centre des icônes : Ball choisie au milieu, 2 de chaque côté
      SLOTS = [[64, 34], [105, 34], [160, 38], [215, 34], [256, 34]].freeze
      # Pastilles des quantités (x, largeur)
      PILLS = [[49, 30], [90, 30], [145, 30], [200, 30], [241, 30]].freeze

      # @return [Array<Studio::BallItem>]
      attr_reader :balls
      # @return [Integer]
      attr_reader :index

      # @param viewport [Viewport]
      # @param y [Integer]
      def initialize(viewport, y)
        super(viewport, 0, y)
        @index = 0
        @balls = []
        @description_mode = false
        create_sprites
      end

      # @param balls [Array<Studio::BallItem>]
      # @param index [Integer]
      def refresh(balls, index = @index)
        @balls = balls
        @index = balls.empty? ? 0 : index % balls.size
        SLOTS.each_index { |slot| refresh_slot(slot) }
        ball = balls[@index]
        @name.text = @desc_name.text = ball ? ball.name : ''
        @description.multiline_text = ball ? ball.descr.to_s : ''
        refresh_mode
      end

      # @return [Studio::BallItem, nil]
      def current
        return @balls[@index]
      end

      # ◄► : Ball suivante
      # @return [Boolean] le choix a changé
      def update_input
        return false if @balls.size <= 1

        step = Input.repeat?(:LEFT) ? -1 : Input.repeat?(:RIGHT) ? 1 : 0
        return false if step == 0

        refresh(@balls, @index + step)
        return true
      end

      # Montre / cache la description
      def toggle_description
        @description_mode = !@description_mode
        refresh_mode
      end

      private

      def create_sprites
        add_sprite(0, 0, EBUI.file('ball_bg'))
        @icons = SLOTS.map { |x, y| add_sprite(x - 16, y - 16, nil, type: UI::ItemSprite) }
        with_font(EBUI::SMALL_FONT) do
          @counts = PILLS.map.with_index do |(x, w), i|
            add_text(x, 50, w, 13, '', 1, color: i == 2 ? EBUI::WHITE : EBUI::DARK)
          end
          @tabs = [add_text(4, 4, 84, 13, EBUI.text(:ball_left), 0, color: EBUI::WHITE),
                   add_text(232, 4, 84, 13, EBUI.text(:ball_right), 2, color: EBUI::WHITE)]
        end
        @name = add_text(125, 3, 70, 16, '', 1, color: EBUI::DARK)
        @desc_bg = add_sprite(0, 0, EBUI.file('ball_desc'))
        @desc_name = add_text(86, 3, 148, 16, '', 1, color: EBUI::DARK)
        with_font(EBUI::SMALL_FONT) do
          @description = add_text(6, 22, 308, 13, '', 0, color: EBUI::DARK)
          @desc_tabs = [add_text(2, 4, 56, 13, EBUI.text(:ball_left), 0, color: EBUI::WHITE),
                        add_text(262, 4, 56, 13, EBUI.text(:ball_close), 2, color: EBUI::WHITE)]
        end
        @counts[2].visible = true
      end

      # @param slot [Integer] 0..4 (2 = Ball choisie ; les autres Balls : +1, -1, +2, -2)
      def refresh_slot(slot)
        offset = slot - 2
        others = @balls.size - 1
        needed = { 0 => 0, 1 => 1, -1 => 2, 2 => 3, -2 => 4 }[offset]
        ball = !@balls.empty? && others >= needed ? @balls[(@index + offset) % @balls.size] : nil
        @icons[slot].visible = !ball.nil?
        @icons[slot].data = ball.id if ball
        @counts[slot].text = ball ? "x#{$bag.item_quantity(ball.db_symbol)}" : ''
      end

      # Description affichée par-dessus le bandeau (la quantité de la Ball choisie reste visible)
      def refresh_mode
        desc = @description_mode
        [@desc_bg, @description, @desc_name, *@desc_tabs].each { |sprite| sprite.visible = desc }
        [@name, *@tabs].each { |sprite| sprite.visible = !desc }
        @icons.each_with_index { |icon, slot| icon.visible = !desc && @counts[slot].text != '' }
        @counts.each_with_index { |count, slot| count.visible = !desc || slot == 2 }
      end
    end

    module_function

    # Poké Balls du sac (ordre de la poche des Balls, sinon ordre de la base de données)
    # @return [Array<Studio::BallItem>]
    def bag_balls
      balls = each_data_item.select { |item| item.is_a?(Studio::BallItem) && $bag.contain_item?(item.db_symbol) }
      order = balls.map(&:socket).uniq.flat_map { |socket| $bag.get_order(socket) }
      return balls.sort_by { |ball| [order.index(ball.db_symbol) || 9999, ball.id] }
    rescue StandardError
      return []
    end
  end

  class PlayerChoice
    class SubChoice
      module EBUIBall
        def update
          return super unless @ebui_ball&.visible

          ebui_update_ball
        end

        # Le choix de l'action attend pendant le lancer rapide
        def done?
          return false if @ebui_ball&.visible || @ebui_ball_closed == Graphics.frame_count

          return super
        end

        def reset
          ebui_close_ball(false) if @ebui_ball&.visible
          super
        end

        def dispose
          @ebui_ball&.dispose
          super
        end

        private

        def action_x
          return super unless ebui_ball_battle?

          balls = BattleUI::EBUI.bag_balls
          return play_buzzer_se if balls.empty?

          last = balls.index { |ball| ball.db_symbol == $bag.last_battle_item&.db_symbol } || 0
          @ebui_ball ||= BattleUI::EBUI::BallSelector.new(@viewport, ebui_ball_y)
          @ebui_ball.refresh(balls, last)
          @ebui_ball.visible = true
          @ebui_ball.send(:refresh_mode)
          @choice.hide
          play_decision_se
        end

        # Lancer rapide possible : combat sauvage (pas Safari), touche X choisie
        # @return [Boolean]
        def ebui_ball_battle?
          return false unless BattleUI::EBUI.enabled? && BattleUI::EBUI::BALL_KEY == :X
          return false if @scene.battle_info.trainer_battle? || @choice.is_a?(BattleUI::PlayerChoiceSafari)

          return true
        rescue StandardError
          return false
        end

        # @return [Integer]
        def ebui_ball_y
          return BattleUI::EBUI.pe_ui? ? BattleUI::PJ::PANEL_Y - BattleUI::EBUI::BallSelector::HEIGHT : 108
        end

        def ebui_update_ball
          @ebui_ball.update
          if Input.trigger?(:B)
            play_cancel_se
            return ebui_close_ball
          end
          if Input.trigger?(:Y)
            play_decision_se
            return @ebui_ball.toggle_description
          end
          return ebui_throw_ball if Input.trigger?(:A)

          play_cursor_se if @ebui_ball.update_input
        end

        # @param show_choice [Boolean]
        def ebui_close_ball(show_choice = true)
          @ebui_ball.visible = false
          @ebui_ball_closed = Graphics.frame_count
          @choice.show if show_choice
        end

        def ebui_throw_ball
          ball = @ebui_ball.current
          return play_buzzer_se unless ball && $bag.contain_item?(ball.db_symbol)
          return unless @scene.can_display_message_be_called?

          play_decision_se
          ebui_close_ball
          @choice.use_item(ball)
        end
      end
      prepend EBUIBall if BattleUI::EBUI::ENABLED
    end
  end

  # Texte d'aide du menu d'action de l'Interface Horizon : « X : Ball » en combat sauvage
  class PlayerChoice
    module EBUIHint
      # @param lines [Array<String>]
      def pj_lines=(lines)
        if lines.is_a?(Array) && BattleUI::EBUI.enabled? && BattleUI::EBUI::BALL_KEY == :X && BattleUI::EBUI.wild_battle? &&
           !is_a?(BattleUI::PlayerChoiceSafari) && defined?(BattleUI::PJ)
          hint = BattleUI::PJ.text(:hint_choice)
          lines = lines.map { |line| line == hint ? BattleUI::EBUI.text(:hint_choice_ball) : line }
        end
        super(lines)
      end
    end
    prepend EBUIHint if BattleUI::EBUI::ENABLED
  end

  module EBUI
    module_function

    # @return [Boolean] combat contre un Pokémon sauvage
    def wild_battle?
      logic = $scene.respond_to?(:logic) ? $scene.logic : nil
      return logic ? !logic.battle_info.trainer_battle? : !$game_temp.trainer_battle
    rescue StandardError
      return false
    end
  end
end

# Enhanced Battle UI — choix du Pokémon dont on veut voir les infos
#
# Adversaires en haut (de droite à gauche comme sur le terrain), Pokémon du joueur en bas,
# avec les Poké Balls des équipes. Flèches : choisir, A : infos, B : retour.
module BattleUI
  module EBUI
    class BattlerSelect < UI::SpriteStack
      # Position du fond
      Y = 56
      # Ligne des boîtes : adversaires / joueur
      ROW_Y = [124, 76]
      # Colonnes des boîtes (1 contre 1 / 2 contre 2)
      COLS = { 1 => [118], 2 => [70, 167] }
      BOX_W = 83
      BOX_H = 26
      # Poké Balls des équipes : joueur / adversaire
      BALLS_Y = [158, 62]

      # @return [Array<PFM::PokemonBattler>] Pokémon proposés
      attr_reader :battlers
      # @return [Integer]
      attr_reader :index

      # @param viewport [Viewport]
      # @param logic [Battle::Logic]
      def initialize(viewport, logic)
        super(viewport)
        @logic = logic
        create_sprites
      end

      # @param battlers [Array<PFM::PokemonBattler>]
      # @param index [Integer]
      def refresh(battlers, index)
        @battlers = battlers
        @index = index.clamp(0, [battlers.size - 1, 0].max)
        @boxes.each_with_index { |box, i| fill_box(box, battlers[i], i == @index) }
        refresh_balls
      end

      # Déplace le curseur
      # @return [Boolean] le choix a changé
      def update_input
        return false if @battlers.empty?

        target = nearest(Input.repeat?(:LEFT) ? -1 : Input.repeat?(:RIGHT) ? 1 : 0,
                         Input.repeat?(:UP) ? -1 : Input.repeat?(:DOWN) ? 1 : 0)
        return false if target.nil? || target == @index

        refresh(@battlers, target)
        return true
      end

      private

      def create_sprites
        add_sprite(0, Y, EBUI.file('select_bg'))
        @boxes = Array.new(4) { create_box }
        @ball_pills = Array.new(2) { |bank| add_sprite(128, BALLS_Y[bank] - 1, EBUI.file('info_owner'), 1, 2, type: SpriteSheet) }
        @balls = [Array.new(6) { add_sprite(0, 0, EBUI.file('info_party'), 4, 1, type: SpriteSheet) },
                  Array.new(6) { add_sprite(0, 0, EBUI.file('info_party'), 4, 1, type: SpriteSheet) }]
      end

      # @return [Hash]
      def create_box
        box = {}
        box[:frame] = add_sprite(0, 0, EBUI.file('select_box'), 1, 2, type: SpriteSheet)
        box[:icon] = add_sprite(0, 0, nil, false, type: UI::PokemonIconSprite)
        box[:gender] = add_sprite(0, 0, EBUI.file('info_gender'), 2, 1, type: SpriteSheet)
        with_font(EBUI::SMALL_FONT) do
          box[:name] = add_text(0, 0, 48, 13, '', 0, color: EBUI::DARK)
          box[:owner] = add_text(0, 0, 48, 13, '', 0, color: EBUI::DARK)
        end
        return box
      end

      # Position d'un Pokémon : [x, y]
      # @param battler [PFM::PokemonBattler]
      def box_position(battler)
        cols = COLS[@logic.battle_info.vs_type.clamp(1, 2)]
        col = cols[battler.position.clamp(0, cols.size - 1)]
        col = cols[cols.size - 1 - battler.position.clamp(0, cols.size - 1)] if battler.bank == 1 # miroir
        return col, ROW_Y[battler.bank.clamp(0, 1)]
      end

      # @param box [Hash]
      # @param battler [PFM::PokemonBattler, nil]
      # @param selected [Boolean]
      def fill_box(box, battler, selected)
        box.each_value { |sprite| sprite.visible = !battler.nil? }
        return unless battler

        x, y = box_position(battler)
        box[:frame].set_position(x, y)
        box[:frame].sy = selected ? 1 : 0
        box[:icon].set_position(x + 1, y - 7)
        box[:icon].data = battler
        box[:name].set_position(x + 33, y - 1)
        box[:name].text = battler.given_name
        box[:owner].set_position(x + 33, y + 11)
        box[:owner].text = EBUI.owner_name(@logic, battler)
        color = selected ? EBUI::WHITE : EBUI::DARK
        box[:name].load_color(color)
        box[:owner].load_color(color)
        box[:gender].visible = battler.gender.to_i > 0
        box[:gender].sx = battler.gender.to_i == 2 ? 1 : 0
        box[:gender].set_position(x + BOX_W - 8, y - 4)
      end

      # Poké Balls de chaque équipe (6 places : en forme, statut, K.O., vide)
      def refresh_balls
        2.times do |bank|
          party = bank_party(bank)
          @ball_pills[bank].visible = !party.nil?
          @balls[bank].each_with_index do |ball, i|
            ball.visible = !party.nil?
            next unless party

            pokemon = party[i]
            ball.set_position(131 + i * 10, BALLS_Y[bank])
            ball.sx = if pokemon.nil? then 3
                      elsif pokemon.dead? then 2
                      elsif pokemon.status.to_i != 0 then 1
                      else 0
                      end
          end
        end
      end

      # Équipe d'un côté (nil pour un Pokémon sauvage)
      # @param bank [Integer]
      # @return [Array<PFM::Pokemon>, nil]
      def bank_party(bank)
        return $actors if bank == 0
        return nil unless @logic.battle_info.trainer_battle?

        return @logic.battle_info.parties[bank]&.first
      rescue StandardError
        return nil
      end

      # Pokémon le plus proche dans une direction
      # @param dx [Integer]
      # @param dy [Integer]
      # @return [Integer, nil]
      def nearest(dx, dy)
        return nil if dx == 0 && dy == 0

        cx, cy = box_position(@battlers[@index])
        candidates = @battlers.each_index.reject { |i| i == @index }.map do |i|
          x, y = box_position(@battlers[i])
          next nil if dx != 0 && (x - cx) * dx <= 0
          next nil if dy != 0 && (y - cy) * dy <= 0

          [i, (x - cx).abs + (y - cy).abs * 2]
        end
        return candidates.compact.min_by(&:last)&.first
      end
    end
  end
end

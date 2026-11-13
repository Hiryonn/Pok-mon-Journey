# Sac Horizon : icônes des poches, nom de la poche, argent
module UI
  module BagHorizon
    # Icônes des poches (même interface que UI::Bag::PocketList)
    class Pockets < SpriteStack
      # @return [Integer]
      attr_reader :index

      # @param viewport [Viewport]
      # @param pocket_indexes [Array<Integer>]
      def initialize(viewport, pocket_indexes)
        super(viewport, 0, 0, default_cache: :interface)
        @icons = pocket_indexes.map { |id| POCKET_ICONS[id] || 0 }
        x = POCKET_RIGHT - @icons.size * POCKET_STEP + (POCKET_STEP - POCKET_ICON_SIZE)
        @icons.each_with_index do |_icon, i|
          add_sprite(x + i * POCKET_STEP, POCKET_Y, BagHorizon.file('pockets')).set_z(4)
        end
        @index = 0
        self.index = 0
      end

      # Poche active : icône claire, les autres sombres
      # @param index [Integer]
      def index=(index)
        @index = index.clamp(0, [size - 1, 0].max)
        @stack.each_with_index do |sprite, i|
          sprite.src_rect.set(@icons[i] * POCKET_ICON_SIZE, (i == @index ? 1 : 0) * POCKET_ICON_SIZE, POCKET_ICON_SIZE, POCKET_ICON_SIZE)
        end
      end
    end

    # Nom de la poche (même interface que UI::Bag::WinPocket) et argent
    class Title < SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        add_sprite(0, 0, BagHorizon.file('header')).set_z(3)
        @name = add_text(6, 1, 108, 16, '', color: WHITE)
        add_sprite(PARTY_X, MONEY_Y, BagHorizon.file('money')).set_z(4)
        @money_label = add_text(PARTY_X + 4, MONEY_Y + 1, 60, 16, BagHorizon.t('Argent', 'Money'), color: WHITE)
        @money = add_text(PARTY_X + 4, MONEY_Y + 1, 103, 16, '', 2, color: WHITE)
        [@name, @money_label, @money].each { |text| text.z = 5 }
        refresh_money
      end

      # @param text [String] nom de la poche
      def text=(text)
        @name.text = text.to_s
        refresh_money
      end

      def refresh_money
        money = PFM.game_state&.money.to_i
        @money.text = begin
          parse_text(11, 9, /\[VAR NUM7[^\]]*\]/ => money.to_s)
        rescue StandardError
          money.to_s
        end
      end
    end
  end
end

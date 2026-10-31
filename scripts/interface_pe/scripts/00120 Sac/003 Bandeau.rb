# Sac PE : onglets des poches et titre
module UI
  module BagPE
    # Onglets des poches (même interface que UI::Bag::PocketList)
    class Tabs < SpriteStack
      # @return [Integer]
      attr_reader :index

      # @param viewport [Viewport]
      # @param pocket_indexes [Array<Integer>]
      def initialize(viewport, pocket_indexes)
        super(viewport, 0, 0, default_cache: :interface)
        pocket_indexes.each_with_index do |id, i|
          add_sprite(TAB_X + i * TAB_STEP, TAB_Y, BagPE.file("tab_#{POCKET_TABS[id] || 6}")).set_z(1)
        end
        @index = 0
      end

      # L'onglet actif garde sa pointe, les autres sont coupés au carré
      # @param index [Integer]
      def index=(index)
        @index = index.clamp(0, size - 1)
        @stack.each_with_index do |sprite, i|
          sprite.src_rect.set(0, 0, 28, i == @index ? 28 : TAB_HEIGHT)
        end
      end
    end

    # Titre « Sac : <poche> » et argent (même interface que UI::Bag::WinPocket)
    class Title < SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        @label = add_text(6, 3, 60, 16, "#{text_get(14, 2)} : ", color: WHITE)
        @pocket = add_text(6, 3, 150, 16, '', color: WHITE)
        @pocket.fill_color = Color.new(*POCKET_COLOR)
        add_sprite(224, 3, BagPE.file('money_box'))
        @money = add_text(228, 3, 84, 16, '', 2, color: WHITE)
        refresh_money
      end

      # @param text [String] nom de la poche
      def text=(text)
        @pocket.text = text.to_s
        @pocket.x = @label.x + @label.real_width
        @pocket.fill_color = Color.new(*POCKET_COLOR)
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

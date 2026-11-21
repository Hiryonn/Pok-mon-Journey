# Triple Triad : sprite d'une carte (fond bleu joueur / rouge adversaire, icône du Pokémon, 4 valeurs)
module UI
  module TripleTriad
    class CardSprite < SpriteStack
      # Position des valeurs [haut, droite, bas, gauche] (losange en haut à gauche, comme Essentials)
      DIGITS = [[8, 2], [14, 9], [8, 16], [2, 9]].freeze

      # @return [::TripleTriad::Card, nil]
      attr_reader :card
      # @return [Integer] 0 joueur, 1 adversaire
      attr_reader :owner
      # @return [Boolean] carte retournée (dos visible)
      attr_reader :hidden

      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        @background = add_sprite(0, 0, ::TripleTriad.file('card_player'))
        @icon = add_sprite(8, 15, NO_INITIAL_IMAGE)
        @digits = DIGITS.map { |x, y| add_sprite(x, y, ::TripleTriad.file('numbers'), 11, 1, type: SpriteSheet) }
        @owner = 0
        @hidden = false
      end

      # @param card [::TripleTriad::Card]
      # @param owner [Integer]
      # @param hidden [Boolean]
      def set(card, owner, hidden = false)
        @card = card
        @hidden = hidden
        @icon.bitmap = RPG::Cache.b_icon(card.icon_name)
        size = @icon.bitmap.height
        @icon.src_rect.set(0, 0, size, size)
        @icon.set_position(x + (::TripleTriad::CARD_W - size) / 2 + 4, y + ::TripleTriad::CARD_H - size - 1)
        @digits.each_with_index { |digit, side| digit.sx = card.value(side) % 11 }
        self.owner = owner
      end

      # @param value [Integer]
      def owner=(value)
        @owner = value
        @background.set_bitmap(::TripleTriad.file(@hidden ? 'card_back' : (value == 0 ? 'card_player' : 'card_opponent')), :interface)
        @icon.visible = !@hidden && visible
        @digits.each { |digit| digit.visible = !@hidden && visible }
      end

      # @param value [Boolean]
      def hidden=(value)
        @hidden = value
        self.owner = @owner
      end

      # @param value [Boolean]
      def visible=(value)
        super
        @icon.visible = value && !@hidden
        @digits.each { |digit| digit.visible = value && !@hidden }
      end
    end

    # Score en gros chiffres (planche numbers zoomée)
    class Score < SpriteStack
      def initialize(viewport, x, y)
        super(viewport, x, y, default_cache: :interface)
        @digits = Array.new(2) { |i| add_sprite(i * 16, 0, ::TripleTriad.file('numbers'), 11, 1, type: SpriteSheet) }
        @digits.each { |digit| digit.zoom = 2 }
      end

      # @param value [Integer]
      def value=(value)
        value = value.clamp(0, 99)
        @digits[0].visible = value >= 10
        @digits[0].sx = value / 10
        @digits[1].sx = value % 10
      end
    end
  end
end

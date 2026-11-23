# Sac Horizon : barre du bas (icône et description de l'objet choisi)
module UI
  module BagHorizon
    # Même interface que UI::Bag::InfoCompact
    class InfoBar < SpriteStack
      # Centre du cadre de l'icône dans info.png
      ICON_CENTER = 24
      # @return [Symbol]
      attr_reader :mode

      # @param viewport [Viewport]
      # @param mode [Symbol] mode du sac
      def initialize(viewport, mode)
        super(viewport, BagHorizon.gauche, INFO_Y, default_cache: :interface)
        @mode = mode
        @bar = Wide.new(viewport, 'info', BagHorizon.largeur, 48, 90)
        @bar.set_position(@x, @y)
        @bar.z = 8
        @icon = add_sprite(12, 12, NO_INITIAL_IMAGE, type: ItemSprite).set_z(9)
        with_font(SMALL_FONT) do
          @price = add_text(BagHorizon.largeur - 124, 4, 116, 13, '', 2, color: WHITE)
          @descr = add_text(46, 6, BagHorizon.largeur - 56, 13, '', color: WHITE)
        end
        [@price, @descr].each { |text| text.z = 9 }
      end

      # @param id [Integer, Symbol, nil] objet affiché (nil = « Fermer le sac »)
      def show_item(id)
        if id.nil? || id == 0
          @icon.visible = false
          @price.text = ''
          @descr.multiline_text = id.nil? ? BagHorizon.t('Fermer le sac.', 'Close the bag.') : ''
          @descr.y = @y + 6 - Text::Util::FOY
          return
        end

        item = data_item(id)
        @icon.visible = visible
        @icon.data = id
        # icône centrée dans le cadre blanc (centre à 24, 24 dans info.png), quelle que soit sa taille
        @icon.set_position(@x + ICON_CENTER - @icon.width / 2, @y + ICON_CENTER - @icon.height / 2)
        @price.text = @mode == :shop ? parse_text(11, 9, /\[VAR NUM7[^\]]*\]/ => (item.price / 2).to_s) : ''
        @descr.y = @y + (@price.text.empty? ? 6 : 17) - Text::Util::FOY
        @descr.multiline_text = item.descr.to_s
      end
    end
  end
end

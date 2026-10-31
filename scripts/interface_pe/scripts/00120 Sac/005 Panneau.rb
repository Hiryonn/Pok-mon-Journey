# Sac PE : panneau du bas (objet choisi)
module UI
  module BagPE
    # Panneau d'infos du bas (même interface que UI::Bag::InfoCompact)
    class InfoPanel < SpriteStack
      # @return [Symbol]
      attr_reader :mode

      # @param viewport [Viewport]
      # @param mode [Symbol] mode du sac
      def initialize(viewport, mode)
        super(viewport, 0, PANEL_Y, default_cache: :interface)
        @mode = mode
        add_sprite(0, 0, BagPE.file('panel_header')).set_z(5)
        add_sprite(0, 22, BagPE.file('panel')).set_z(5)
        @name = add_text(6, 2, 230, 16, '', color: WHITE)
        @trash = add_sprite(290, 4, BagPE.file('trash')).set_z(6)
        @heart = add_sprite(304, 4, BagPE.file('heart_on')).set_z(6)
        @icon = add_sprite(12, 37, NO_INITIAL_IMAGE, type: ItemSprite).set_z(6)
        with_font(SMALL_FONT) { @price = add_text(196, 25, 118, 13, '', 2, color: WHITE) }
        @descr = add_text(60, 25, 254, 16, '', color: WHITE)
        [@name, @price, @descr].each { |text| text.z = 6 }
      end

      # @param id [Integer, Symbol, nil] objet affiché (nil = rien)
      def show_item(id)
        if id.nil? || id == 0
          [@icon, @heart, @trash].each { |sprite| sprite.visible = false }
          @name.text = ''
          @price.text = ''
          @descr.text = ''
          return
        end

        item = data_item(id)
        @icon.visible = @trash.visible = visible
        @icon.data = id
        @name.text = item.is_limited ? "#{item.exact_name} x#{$bag.item_quantity(id)}" : item.exact_name
        @heart.visible = visible && $bag.shortcuts.include?(item.db_symbol)
        @price.text = @mode == :shop ? parse_text(11, 9, /\[VAR NUM7[^\]]*\]/ => (item.price / 2).to_s) : ''
        @descr.y = @price.text.empty? ? @y + 25 - Text::Util::FOY : @y + 39 - Text::Util::FOY
        @descr.multiline_text = item.descr.to_s
      end
    end
  end
end

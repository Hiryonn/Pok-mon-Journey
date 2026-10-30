# PokeSmart : le téléphone (coque, fond d'écran, barre d'état, titre)
module UI
  module PokeSmart
    # Téléphone : coque, fond d'écran, barre d'état, titre
    class Phone < SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        @theme = PokeSmart.theme
        super(viewport, *@theme[:phone], default_cache: :interface)
        add_sprite(0, 0, PokeSmart.file('phone'))
        create_screen
        create_status_bar
        tx, ty, tw, align = @theme[:title]
        @title = add_text(tx, ty, tw, 16, '', align, color: text_color)
        @clock_text = nil
        update
      end

      # @return [Hash] apparence du téléphone
      attr_reader :theme

      # Couleur des textes de l'écran (celle de la coque)
      # @return [Integer]
      def text_color
        return @theme[:color]
      end

      # @param text [String] nom de l'appli sélectionnée
      def title=(text)
        @title.text = text.to_s
      end

      # Met l'heure et la batterie à jour
      def update
        clock = Time.now.strftime('%H:%M')
        @clock.text = @clock_text = clock if clock != @clock_text
        @status_counter = (@status_counter || 0) - 1
        return if @status_counter > 0

        @status_counter = 30
        refresh_status
      end

      # Batterie, réseau et wifi
      def refresh_status
        set_icon(@battery, "battery_#{PokeSmart.battery_level}")
        set_icon(@network, "reseau_mobile_#{PokeSmart.network_level}")
        set_icon(@wifi, Internet.connected? ? 'wifi_3' : 'wifi_0')
      end

      # @return [Boolean] si la souris est sur le bouton rond du bas
      def home_button_hovered?
        range_x, range_y = @theme[:home]
        return range_x.include?(Mouse.x - x) && range_y.include?(Mouse.y - y)
      end

      private

      def create_screen
        choice = PokeSmart.wallpaper_choice
        name = choice == :auto ? PokeSmart.wallpaper_name : choice
        add_wallpaper(name) if name.is_a?(String)
      end

      # Fond d'écran posé sur l'écran de la coque, calé en bas à droite (recadré s'il dépasse)
      # @param name [String]
      def add_wallpaper(name)
        sx, sy, sw, sh = @theme[:screen]
        sprite = add_sprite(sx, sy, PokeSmart.file("wallpapers/#{name}"))
        bw = sprite.bitmap.width
        bh = sprite.bitmap.height
        return if bw == sw && bh == sh

        vw = [bw, sw].min
        vh = [bh, sh].min
        sprite.src_rect.set(bw - vw, bh - vh, vw, vh)
        sprite.set_position(x + sx + sw - vw, y + sy + sh - vh)
      end

      def create_status_bar
        @network = add_sprite(*@theme[:network], PokeSmart.file('reseau_mobile_4'))
        @wifi = add_sprite(*@theme[:wifi], PokeSmart.file('wifi_0'))
        cx, cy, cw, align = @theme[:clock]
        with_font(20) { @clock = add_text(cx, cy, cw, 13, '', align, color: @theme[:clock_color] || @theme[:color]) }
        @battery = add_sprite(*@theme[:battery], PokeSmart.file('battery_80'))
      end

      # Change l'image d'une icône seulement si elle a changé
      def set_icon(sprite, name)
        return if sprite.instance_variable_get(:@pokesmart_icon) == name

        sprite.instance_variable_set(:@pokesmart_icon, name)
        sprite.set_bitmap(PokeSmart.file(name), :interface)
      end
    end
  end
end

# Équipe PE : fond, titre, bande de message et barre du bas
module UI
  module PartyPE
    # Case de la barre du bas (remplace les boutons de PSDK : même rôle, mêmes touches)
    class NavButton < SpriteStack
      COORDINATES = PartyPE::NAV

      # @param viewport [Viewport]
      # @param coords_index [Integer]
      # @param key [Symbol]
      def initialize(viewport, coords_index, key, default_cache: :interface)
        super(viewport, *COORDINATES[coords_index], default_cache: :interface)
        @background = add_sprite(0, 0, PartyPE.file('nav_button'))
        @background.src_rect.set(0, 0, 80, 23)
        @key_button = add_sprite(8, 5, NO_INITIAL_IMAGE, key, type: KeyShortcut)
        @text = add_text(24, 5, 52, 16, '', color: PartyPE::WHITE)
        @coords_index = coords_index
        self.pressed = false
        self.z = 501
      end

      # @param pressed [Boolean]
      def pressed=(pressed)
        @background.src_rect.y = pressed ? 23 : 0
      end
      alias set_press pressed=

      # @param value [String, nil]
      def text=(value)
        return unless value.is_a?(String) || value.nil?

        @text.text = value if value
        self.visible = (value ? true : false)
      end

      # @param value [Symbol]
      def key=(value)
        return unless value.is_a?(Symbol)

        @key_button.find_key(value)
      end
    end

    # Base de l'écran d'équipe
    class BaseUI < GenericBase
      def initialize(viewport, texts = [], keys = DEFAULT_KEYS, hide_background_and_button: false)
        super
        @title = add_text(30, 3, 140, 16, PartyPE.title, color: PartyPE::WHITE)
        @title.bold = true
        @count = with_font(PartyPE::SMALL_FONT) { add_text(190, 5, 124, 13, '', 2, color: PartyPE::WHITE) }
      end

      # @param text [String]
      def title=(text)
        @title.text = text.to_s
      end

      # @param text [String] texte à droite du bandeau
      def info=(text)
        @count.text = text.to_s
      end

      def update_background_animation; end

      private

      def create_background
        @background = add_sprite(0, 0, PartyPE.file('background')).set_z(-10)
        @background_animation = nil
        @on_update_background_animation = nil
      end

      def create_button_background
        @button_background = add_sprite(0, PartyPE::NAV_Y, NO_INITIAL_IMAGE).set_z(500)
      end

      def control_button_class
        return NavButton
      end

      def win_text
        @win_text_background ||= add_sprite(0, PartyPE::MESSAGE_Y, PartyPE.file('message')).set_z(502)
        @win_text ||= add_text(8, PartyPE::MESSAGE_Y + 3, 304, 16, nil.to_s, color: PartyPE::WHITE)
        @win_text.z = 502
        @win_text
      end
    end
  end
end

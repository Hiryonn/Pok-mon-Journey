# PokeSmart : une appli de l'écran d'accueil (case + icône + nom)
module UI
  module PokeSmart
    # Appli de l'écran d'accueil (même interface que UI::PSDKMenuButtonBase)
    class AppButton < SpriteStack
      # @return [Boolean]
      attr_reader :selected
      # @return [String]
      attr_reader :name
      # @return [Symbol] action du menu (ex. :open_bag)
      attr_reader :action

      # @param viewport [Viewport]
      # @return [Array(Integer, Integer)] ligne et colonne dans la grille
      attr_accessor :grid

      # @param real_index [Integer] index de l'action dans GamePlay::Menu::ACTION_LIST
      # @param x [Integer] position à l'écran
      # @param y [Integer]
      def initialize(viewport, real_index, x = 0, y = 0)
        super(viewport, x, y, default_cache: :interface)
        @index = real_index
        @action = GamePlay::Menu::ACTION_LIST[real_index]
        @tile = add_sprite(0, 0, PokeSmart.file('tile'))
        @icon = add_sprite(0, 0, PokeSmart.app_icon(@action), 2, 1, type: SpriteSheet)
        @icon.select(0, 0)
        # icône centrée dans la case (cases de 30 x 28, icônes de 32 x 32 ou anciennes de 22 x 22)
        @icon.x = x + (@tile.width - @icon.width) / 2
        @icon_dy = (@tile.height - @icon.height) / 2
        @icon.y = y + @icon_dy
        @name = app_name
        create_badge
        @selected = false
        @counter = 0
      end

      # Petit rebond de l'icône sélectionnée
      def update
        return unless @selected

        @counter = (@counter + 1) % 40
        @icon.y = y + @icon_dy - (@counter < 20 ? 1 : 0)
      end

      # @param value [Boolean]
      def selected=(value)
        return if value == @selected

        @selected = value
        @tile.set_bitmap(PokeSmart.file(value ? 'tile_selected' : 'tile'), :interface)
        @icon.select(value ? 1 : 0, 0)
        @icon.y = y + @icon_dy
        @counter = 0
      end

      private

      # Pastille rouge sur l'appli Amis quand un message n'est pas lu
      def create_badge
        return unless @action == :open_friends && defined?(PokeSmart::Friends) && PokeSmart::Friends.unread > 0

        add_sprite(@tile.width - 6, -2, PokeSmart.file('notif_dot'))
      end

      # Même textes que le menu de PSDK pour ses boutons, sinon APP_NAMES
      # @return [String]
      def app_name
        studio = PokeSmart.studio_app_name(@action)
        return studio.sub(PFM::Text::TRNAME[0], $trainer.name) if studio

        names = APP_NAMES[@action]
        return names[PokeSmart.french? ? 0 : 1] if names

        text = case @action
               when :open_dex then text_get(14, 1)
               when :open_party then text_get(14, 0)
               when :open_bag then text_get(14, 2)
               when :open_tcard then text_get(14, 3)
               when :open_option then text_get(14, 5)
               when :open_save then text_get(14, 4)
               else @action.to_s.sub(/\Aopen_/, '').tr('_', ' ').capitalize
               end
        return text.sub(PFM::Text::TRNAME[0], $trainer.name)
      end
    end
  end
end

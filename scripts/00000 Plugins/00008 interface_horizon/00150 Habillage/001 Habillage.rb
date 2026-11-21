# Interface Horizon : habillage des autres interfaces de PSDK avec les éléments du Pokédex Horizon
#
# - fond clair à reflet du Pokédex (fixe), bandeau du haut du Pokédex avec le titre dans la pastille,
#   bandes bleues du Pokédex en bas ; plus de boutons A / B / X / Y de PSDK en bas de l'écran
#
# PC, Journal de quêtes, Carte Dresseur, Sauvegarde / chargement, Options (et le fond commun des menus,
# la barre des boutons, la zone de texte) : leurs images sont lues dans graphics/interface/horizon/<même chemin>
# quand cette version existe (ex. horizon/pc/frame.png à la place de pc/frame.png). Les originaux ne sont pas touchés.
#
# Les images « horizon » sont faites par tools/interface-horizon/build_skin_assets.py (à relancer si on change un original).
# Pour revenir aux images de PSDK : passer ENABLED à false.
module UI
  module HorizonSkin
    # Active ou non l'habillage
    ENABLED = true

    # Sous-dossier de graphics/interface/ qui contient les images habillées
    DIR = 'horizon/'

    module_function

    # Nom de l'image habillée à utiliser à la place de filename, ou nil
    # @param filename [String]
    # @return [String, nil]
    def skinned(filename)
      return nil unless ENABLED && filename.is_a?(String) && !filename.empty? && !filename.start_with?(DIR)

      @known ||= {}
      return @known[filename] if @known.key?(filename)

      name = "#{DIR}#{filename}"
      lang = $options&.language || 'en'
      found = [name, "#{name}#{lang}", "#{name}en"].any? { |n| RPG::Cache.interface_exist?(n) }
      return @known[filename] = found ? name : nil
    rescue StandardError
      return nil
    end
  end
end

module RPG
  module Cache
    # Images d'interface : version « horizon » si elle existe
    module HorizonSkinCache
      def interface(filename, hue = 0)
        skinned = UI::HorizonSkin.skinned(filename)
        return super(skinned || filename, hue)
      end

      def interface_image(filename)
        skinned = UI::HorizonSkin.skinned(filename)
        return super(skinned || filename)
      end
    end
    singleton_class.prepend(HorizonSkinCache)
  end
end

module UI
  module HorizonSkin
    # Titres écrits dans la pastille du bandeau (français, anglais)
    TITLES = {
      storage: %w[PC PC], save: %w[SAUVEGARDE SAVE], load: %w[CHARGER LOAD], options: %w[OPTIONS OPTIONS]
    }.freeze
    # Hauteur du texte du titre (le PC a un bandeau mince de 20 px pour ne pas cacher le haut de la boîte)
    TITLE_YS = { storage: 1 }.freeze
    # Centre de la pastille du bandeau (graphics/interface/horizon/header.png)
    TITLE_X = 96
    TITLE_W = 128
    TITLE_Y = 5
    TITLE_Z = 10_000

    module_function

    # Écrit le titre du bandeau
    # @param viewport [Viewport]
    # @param key [Symbol]
    def add_title(viewport, key)
      return unless ENABLED && viewport && TITLES[key]

      text = TITLES[key][$options&.language.to_s == 'fr' ? 0 : 1]
      title = Text.new(0, viewport, TITLE_X, TITLE_YS.fetch(key, TITLE_Y) - Text::Util::FOY, TITLE_W, 16, text, 1, Text::Util::DEFAULT_OUTLINE_SIZE, 9)
      title.draw_shadow = false
      title.z = TITLE_Z
      viewport.sort_z if viewport.respond_to?(:sort_z)
      return title
    rescue StandardError => e
      log_error("Interface Horizon : titre #{key} (#{e.message})") if respond_to?(:log_error, true)
      return nil
    end

    # Fond fixe et sans boutons de PSDK (A / B / X / Y en bas de l'écran)
    module BaseUIStyle
      def button_texts=(value)
        super
        hide_horizon_buttons
      end

      def hide_win_text
        super
        hide_horizon_buttons
      end

      def show_button_bar
        super
        hide_horizon_buttons
      end

      private

      # Le fond du Pokédex ne défile pas
      def create_background_animation
        super unless HorizonSkin::ENABLED
      end

      def hide_horizon_buttons
        return unless HorizonSkin::ENABLED

        @ctrl&.each { |button| button.visible = false }
      end
    end
    GenericBase.prepend(BaseUIStyle)

    # Les boutons restent cachés même quand une interface change leur texte (ex. journal de quêtes)
    module ControlButtonStyle
      def visible=(value)
        super(HorizonSkin::ENABLED ? false : value)
      end
    end
    GenericBase::ControlButton.prepend(ControlButtonStyle)
  end

  # Journal de quêtes : la catégorie (page du journal) s'affiche dans la pastille du bandeau,
  # avec les flèches de chaque côté et le numéro de page à droite
  module Quest
    class CategoryDisplay
      module HorizonStyle
        def update_category_text(category)
          super
          update_horizon_page
        end

        private

        def coordinates
          return HorizonSkin::ENABLED ? [0, 0] : super
        end

        def create_frame
          super
          @frame.visible = false if HorizonSkin::ENABLED
        end

        def create_category_text
          return super unless HorizonSkin::ENABLED

          @text = add_text(HorizonSkin::TITLE_X, HorizonSkin::TITLE_Y, HorizonSkin::TITLE_W, 16, send(*TEXT_CATEGORY[@category]), 1, color: 9)
          with_font(20) { @page = add_text(232, 7, 82, 13, '', 2, color: 9) }
          update_horizon_page
        end

        def create_arrow_frames
          return super unless HorizonSkin::ENABLED

          @left_arrow = add_sprite(HorizonSkin::TITLE_X - 12, 6, 'quest/arrow_frame_l')
          @right_arrow = add_sprite(HorizonSkin::TITLE_X + HorizonSkin::TITLE_W + 4, 6, 'quest/arrow_frame_r')
          update_arrows
        end

        # « Page 2 / 4 » à droite du bandeau
        def update_horizon_page
          return unless @page

          list = TEXT_CATEGORY.keys
          number = (list.index(@category) || 0) + 1
          @page.text = "Page #{number} / #{list.size}"
        end
      end
      prepend HorizonStyle
    end
  end

  # Options : le nom de l'option dans la description (vert dans PSDK) en blanc, comme le reste
  module Options
    class Description
      module HorizonStyle
        private

        def create_sprites
          super
          @name&.load_color(9) if HorizonSkin::ENABLED
        end
      end
      prepend HorizonStyle
    end
  end
end

# Titres dans le bandeau des interfaces habillées
module GamePlay
  {
    PokemonStorage: :storage, Load: :load, Save: :save, Options: :options
  }.each do |klass, key|
    next unless const_defined?(klass, false)

    style = Module.new do
      define_method(:create_graphics) do |*args, &block|
        result = super(*args, &block)
        @horizon_title ||= UI::HorizonSkin.add_title(@viewport, is_a?(GamePlay::Save) ? :save : key)
        result
      end
    end
    const_get(klass, false).prepend(style)
  end
end

# Menu principal (GamePlay::Menu) en smartphone, d'après le pack « PokeSmart »
#
# - Le téléphone monte du bas de l'écran ; le jeu reste visible (flouté) derrière
# - Barre d'état : réseau (selon les badges), wifi, heure réelle, batterie (selon les PV de l'équipe)
# - Fond d'écran selon le Pokémon en tête d'équipe (graphics/interface/menu_pe/wallpapers/) :
#   image dédiée à l'espèce si elle existe (01_wallpaper, 025_wallpaper, 200…), sinon le dégradé bleu
#   avec la silhouette Bulbizarre / Salamèche / Carapuce selon son type (Plante / Feu / Eau)
# - Applis en grille de 3 ; le nom de l'appli sélectionnée s'affiche en haut de l'écran
# Touches : flèches pour se déplacer, A pour ouvrir, B pour ranger le téléphone.
# Souris : survol / clic sur une appli, clic sur le bouton rond du bas pour ranger le téléphone.
# Les applis sont celles enregistrées dans GamePlay::Menu (PSDK + plugins), sauf « Quitter ».
#
# Pour revenir au menu d'origine : passer ENABLED à false.
module UI
  module MenuPE
    # Active ou non le menu smartphone
    ENABLED = true
    # Dossier des graphismes (dans graphics/interface/)
    DIR = 'menu_pe/'
    WHITE = 9
    # Position de la coque à l'écran, et de l'écran du téléphone
    PHONE_X = 99
    PHONE_Y = 8
    SCREEN_X = PHONE_X + 6
    SCREEN_Y = PHONE_Y + 34
    # Grille des applis (coordonnées dans l'écran du téléphone)
    COLUMNS = 3
    GRID_X = 7
    GRID_Y = 22
    CELL_X = 32
    CELL_Y = 32
    # Bouton rond du bas (coordonnées dans la coque)
    HOME_BUTTON = [50..66, 182..194]
    # Icône (ligne de menu_icons.png) selon l'action du menu
    APP_ICONS = {open_dex: 0, open_party: 1, open_bag: 2, open_save: 5, open_tcard: 8, open_option: 9}
    # Icône des actions inconnues (applis ajoutées par d'autres plugins)
    DEFAULT_ICON = 6
    # Nom des actions ajoutées par d'autres plugins : {action => [français, anglais]}
    APP_NAMES = {}
    # Fond d'écran forcé (nom d'un fichier de wallpapers/, nil = selon le Pokémon de tête),
    # et image ajoutée par-dessus (ex. '02_red' + '02_bottom' pour le thème rouge de Salamèche)
    FORCED_WALLPAPER = nil
    FORCED_WALLPAPER_OVERLAY = nil
    # Silhouette ajoutée au dégradé par défaut selon le type du Pokémon de tête
    TYPE_OVERLAYS = {grass: 'reflet_1', fire: 'reflet_2', water: 'reflet_3'}
    # Durée de l'animation d'entrée / sortie (secondes) et décalage vertical du téléphone
    SLIDE_DURATION = 0.25
    SLIDE_OFFSET = 236

    module_function

    # @param name [String]
    # @return [String]
    def file(name)
      return "#{DIR}#{name}"
    end

    # Pokémon en tête d'équipe (hors œufs)
    # @return [PFM::Pokemon, nil]
    def leader
      return $actors&.find { |pokemon| pokemon && !pokemon.egg? }
    end

    # Fond d'écran : image de l'espèce de tête (« 025_wallpaper », « 01_wallpaper » ou « 200 ») sinon « default »
    # @return [String]
    def wallpaper_name
      return FORCED_WALLPAPER if FORCED_WALLPAPER

      if (pokemon = leader)
        id = pokemon.id.to_i
        [format('%03d_wallpaper', id), format('%02d_wallpaper', id), id.to_s].each do |name|
          return name if RPG::Cache.interface_exist?(file("wallpapers/#{name}"))
        end
      end
      return 'default'
    rescue StandardError
      return 'default'
    end

    # Image par-dessus le fond : forcée, ou silhouette selon le type quand le fond est le dégradé
    # @param wallpaper [String]
    # @return [String, nil]
    def wallpaper_overlay(wallpaper)
      return FORCED_WALLPAPER_OVERLAY if FORCED_WALLPAPER || FORCED_WALLPAPER_OVERLAY
      return nil unless wallpaper == 'default' && (pokemon = leader)

      type = data_type(pokemon.type1).db_symbol
      return TYPE_OVERLAYS[type]
    rescue StandardError
      return nil
    end

    # Téléphone : coque, fond d'écran, barre d'état, titre
    class Phone < SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, PHONE_X, PHONE_Y, default_cache: :interface)
        create_screen
        add_sprite(0, 0, MenuPE.file('phone'))
        create_status_bar
        @title = add_text(6, 36, 104, 16, '', 1, color: WHITE)
        @clock_text = nil
        update
      end

      # @param text [String] nom de l'appli sélectionnée
      def title=(text)
        @title.text = text.to_s
      end

      # Met l'heure et la batterie à jour
      def update
        clock = Time.now.strftime('%H:%M')
        return if clock == @clock_text

        @clock_text = clock
        @clock.text = clock
        @battery.set_bitmap(MenuPE.file("battery_#{battery_level}"), :interface)
      end

      # @return [Boolean] si la souris est sur le bouton rond du bas
      def home_button_hovered?
        return HOME_BUTTON[0].include?(Mouse.x - x) && HOME_BUTTON[1].include?(Mouse.y - y)
      end

      private

      def create_screen
        wallpaper = MenuPE.wallpaper_name
        add_sprite(6, 34, MenuPE.file("wallpapers/#{wallpaper}"))
        overlay = MenuPE.wallpaper_overlay(wallpaper)
        add_sprite(6, 34, MenuPE.file("wallpapers/#{overlay}")) if overlay
      end

      def create_status_bar
        add_sprite(9, 26, MenuPE.file("reseau_mobile_#{network_level}"))
        add_sprite(18, 26, MenuPE.file('wifi_3'))
        with_font(20) { @clock = add_text(30, 23, 56, 13, '', 1, color: WHITE) }
        @battery = add_sprite(95, 26, MenuPE.file('battery_80'))
      end

      # Réseau : une barre tous les deux badges
      # @return [Integer] 0 à 4
      def network_level
        badges = $trainer.respond_to?(:badge_counter) ? $trainer.badge_counter.to_i : 8
        return ((badges + 1) / 2).clamp(0, 4)
      rescue StandardError
        return 4
      end

      # Batterie : moyenne des PV de l'équipe
      # @return [String] 20, 40, 60, 80 ou pika (pleine)
      def battery_level
        team = ($actors || []).compact.reject(&:egg?)
        return 'pika' if team.empty?

        rate = team.sum { |pokemon| pokemon.hp.to_f / [pokemon.max_hp, 1].max } / team.size
        return 'pika' if rate >= 0.95
        return '80' if rate >= 0.7
        return '60' if rate >= 0.5
        return '40' if rate >= 0.3

        return '20'
      rescue StandardError
        return '80'
      end
    end

    # Appli de l'écran d'accueil (même interface que UI::PSDKMenuButtonBase)
    class AppButton < SpriteStack
      # @return [Boolean]
      attr_reader :selected
      # @return [String]
      attr_reader :name

      # @param viewport [Viewport]
      # @param real_index [Integer] index de l'action dans GamePlay::Menu::ACTION_LIST
      # @param positional_index [Integer] place dans la grille
      def initialize(viewport, real_index, positional_index)
        col = positional_index % COLUMNS
        row = positional_index / COLUMNS
        super(viewport, SCREEN_X + GRID_X + col * CELL_X, SCREEN_Y + GRID_Y + row * CELL_Y, default_cache: :interface)
        @index = real_index
        @action = GamePlay::Menu::ACTION_LIST[real_index]
        @tile = add_sprite(0, 0, MenuPE.file('tile'))
        @icon = add_sprite(2, 2, MenuPE.file('menu_icons'), 2, 18, type: SpriteSheet)
        @icon.select(0, icon_index)
        @name = app_name
        @selected = false
        @counter = 0
      end

      # Petit rebond de l'icône sélectionnée
      def update
        return unless @selected

        @counter = (@counter + 1) % 40
        @icon.y = y + (@counter < 20 ? 1 : 2)
      end

      # @param value [Boolean]
      def selected=(value)
        return if value == @selected

        @selected = value
        @tile.set_bitmap(MenuPE.file(value ? 'tile_selected' : 'tile'), :interface)
        @icon.select(value ? 1 : 0, icon_index)
        @icon.y = y + 2
        @counter = 0
      end

      private

      # @return [Integer]
      def icon_index
        return APP_ICONS.fetch(@action, DEFAULT_ICON)
      end

      # Même textes que le menu de PSDK pour ses boutons, sinon APP_NAMES
      # @return [String]
      def app_name
        names = APP_NAMES[@action]
        return names[$options&.language == 'fr' ? 0 : 1] if names

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

module GamePlay
  class Menu
    # Menu smartphone (la logique de PSDK reste inchangée : mêmes actions, mêmes scènes)
    module PEStyle
      public

      # Déplacement en grille (gauche / droite = appli voisine, haut / bas = ligne)
      def update_inputs
        return false if @entering || @quiting

        delta = 0
        delta = -1 if Input.repeat?(:LEFT)
        delta = 1 if Input.repeat?(:RIGHT)
        delta = -UI::MenuPE::COLUMNS if Input.repeat?(:UP)
        delta = UI::MenuPE::COLUMNS if Input.repeat?(:DOWN)
        if delta != 0
          target = @index + delta
          if target.between?(0, @max_index) && target != @index
            @index = target
            play_cursor_se
            update_buttons
          end
          return false
        end
        if Input.trigger?(:A)
          action
        elsif Input.trigger?(:B)
          @quiting = true
        else
          return true
        end
        return false
      end

      # Décale le téléphone et ses applis vers le bas (0 = en place)
      # @param offset [Numeric]
      def pe_slide=(offset)
        delta = offset.to_i - (@pe_slide || 0)
        @pe_slide = offset.to_i
        return if delta == 0

        @phone.move(0, delta)
        @buttons.each { |button| button.move(0, delta) }
      end

      # Le bouton rond du bas range le téléphone
      def update_mouse(moved)
        return false if @entering || @quiting

        if Mouse.trigger?(:LEFT) && @phone.home_button_hovered?
          play_cancel_se
          @quiting = true
          return false
        end
        return super
      end

      def update_graphics
        super
        @phone.update
      end

      # Pendant la sauvegarde PSDK ne cache que les boutons : le téléphone suit
      def visible=(value)
        super
        @phone.visible = value if @in_save
      end

      private

      # « Quitter » devient le bouton rond du téléphone (et la touche B)
      def init_indexes
        super
        quit_index = ACTION_LIST.index(:open_quit)
        @image_indexes.delete(quit_index) if quit_index && @image_indexes.size > 1
      end

      def create_buttons
        @phone = UI::MenuPE::Phone.new(@viewport)
        @buttons = @image_indexes.map.with_index do |real_index, i|
          UI::MenuPE::AppButton.new(@viewport, real_index, i)
        end
        @max_index = @buttons.size - 1
        @index = @index.clamp(0, @max_index)
      end

      def update_buttons
        super
        @phone.title = @buttons[@index]&.name
      end

      def init_entering
        self.pe_slide = UI::MenuPE::SLIDE_OFFSET
      end

      def create_entering_animation
        ya = Yuki::Animation
        slide = ya.scalar(UI::MenuPE::SLIDE_DURATION, self, :pe_slide=, UI::MenuPE::SLIDE_OFFSET, 0)
        return ya.parallel(ya.opacity_change(UI::MenuPE::SLIDE_DURATION, @background, 0, 255), slide).start
      end

      def create_quitting_animation
        @__last_scene.spriteset.visible = true if @__last_scene.is_a?(Scene_Map) && !@animation
        @buttons.each { |button| button.selected = false }
        ya = Yuki::Animation
        slide = ya.scalar(UI::MenuPE::SLIDE_DURATION, self, :pe_slide=, 0, UI::MenuPE::SLIDE_OFFSET)
        return ya.parallel(ya.opacity_change(UI::MenuPE::SLIDE_DURATION, @background, 255, 0), slide).start
      end

    end
    prepend PEStyle if UI::MenuPE::ENABLED
  end
end

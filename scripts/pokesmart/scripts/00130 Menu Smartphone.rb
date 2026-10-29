# Menu principal (GamePlay::Menu) en smartphone, d'après le pack « PokeSmart »
#
# - Le téléphone monte du bas de l'écran ; le jeu reste visible (flouté) derrière
# - Barre d'état :
#   batterie selon le moment de la journée (matin 80 %, jour 60 %, soir 40 %, nuit 20 %),
#   batterie Pikachu si un Pikachu est dans l'équipe ;
#   réseau selon la zone (grotte / donjon : aucune barre, bâtiment : 2 barres, extérieur : 4 barres) ;
#   wifi allumé si l'ordinateur est connecté à Internet, éteint sinon ; heure réelle
# - Fond d'écran selon le Pokémon en tête d'équipe (graphics/interface/pokesmart/wallpapers/) :
#   image dédiée à l'espèce si elle existe (01_wallpaper, 025_wallpaper, 200…), sinon le dégradé bleu
#   avec la silhouette Bulbizarre / Salamèche / Carapuce selon son type (Plante / Feu / Eau)
# - Applis en grille de 3 ; le nom de l'appli sélectionnée s'affiche en haut de l'écran
# Touches : flèches pour se déplacer, A pour ouvrir, B pour ranger le téléphone.
# Souris : survol / clic sur une appli, clic sur le bouton rond du bas pour ranger le téléphone.
# Les applis sont celles enregistrées dans GamePlay::Menu (PSDK + plugins), sauf « Quitter ».
#
# Pour revenir au menu d'origine : passer ENABLED à false.
module UI
  module PokeSmart
    # Active ou non le menu smartphone
    ENABLED = true
    # Dossier des graphismes (dans graphics/interface/)
    DIR = 'pokesmart/'
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
    # Icône (ligne de menu_icons.png) selon l'action du menu. Les applis sont aussi rangées dans cet ordre.
    # Les actions pas encore codées sont déjà prêtes : il suffira de faire
    #   GamePlay::Menu.register_button(:open_map) { true }  (+ la méthode open_map dans GamePlay::Menu)
    APP_ICONS = {
      open_dex: 0,            # Pokédex
      open_party: 1,          # Équipe
      open_bag: 2,            # Sac
      open_map: 3,            # Carte
      open_pc: 4,             # PC
      open_quest: 5,          # Journal de quête
      open_tcard: 6,          # Carte de dresseur
      open_friends: 7,        # Liste d'amis
      open_save: 8,           # Sauvegarde
      open_option: 9,         # Options
      open_customization: 10, # Personnalisation du téléphone
      open_mystery_gift: 11,  # Cadeau mystère
      open_mount: 12,         # Appel monture
      open_herds: 13,         # Troupeaux
      open_card_game: 14,     # Jeu de cartes
      open_daycare: 15        # Pension
    }
    # Icône des actions inconnues (lignes 16 et 17 encore libres)
    DEFAULT_ICON = 16
    # Nom des actions ajoutées par d'autres plugins : {action => [français, anglais]}
    APP_NAMES = {
      open_map: ['Carte', 'Map'],
      open_pc: ['PC', 'PC'],
      open_quest: ['Journal', 'Quest log'],
      open_friends: ['Amis', 'Friends'],
      open_customization: ['Personnaliser', 'Customize'],
      open_mystery_gift: ['Cadeau Mystère', 'Mystery Gift'],
      open_mount: ['Monture', 'Mount'],
      open_herds: ['Troupeaux', 'Herds'],
      open_card_game: ['Jeu de cartes', 'Card game'],
      open_daycare: ['Pension', 'Daycare']
    }
    # Fond d'écran forcé (nom d'un fichier de wallpapers/, nil = selon le Pokémon de tête),
    # et image ajoutée par-dessus (ex. '02_red' + '02_bottom' pour le thème rouge de Salamèche)
    FORCED_WALLPAPER = nil
    FORCED_WALLPAPER_OVERLAY = nil
    # Silhouette ajoutée au dégradé par défaut selon le type du Pokémon de tête
    TYPE_OVERLAYS = {grass: 'reflet_1', fire: 'reflet_2', water: 'reflet_3'}
    # Réseau : mots qui désignent une grotte ou un donjon dans le nom de la zone (aucune barre)
    NO_NETWORK_WORDS = ['grotte', 'caverne', 'cave', 'tunnel', 'mont ', 'souterrain', 'sous-sol', 'centrale',
                        'donjon', 'mine', 'gouffre', 'tour pokémon']
    # Réseau imposé pour certaines zones (id de la zone dans Studio => nombre de barres de 0 à 4)
    NETWORK_BY_ZONE = {}
    # Barres de réseau : grotte / donjon, bâtiment, extérieur
    NETWORK_CAVE = 0
    NETWORK_BUILDING = 2
    NETWORK_OUTSIDE = 4
    # Batterie selon le moment de la journée
    BATTERY_BY_TIME = {morning: '80', day: '60', evening: '40', night: '20'}
    # Espèces qui affichent la batterie Pikachu quand elles sont dans l'équipe
    PIKA_SPECIES = %i[pikachu]
    # Test de connexion Internet (serveurs DNS publics, port 53) et intervalle entre deux tests (secondes)
    INTERNET_HOSTS = [['1.1.1.1', 53], ['8.8.8.8', 53]]
    INTERNET_TIMEOUT = 1.5
    INTERNET_CHECK_DELAY = 30
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

    # Test de connexion Internet en tâche de fond (le jeu ne se bloque pas pendant le test)
    module Internet
      @connected = false
      @checked_at = nil
      @thread = nil

      module_function

      # @return [Boolean] dernier résultat connu
      def connected?
        refresh
        return @connected
      end

      # Relance un test si le dernier date de plus de INTERNET_CHECK_DELAY secondes
      def refresh
        return if @thread&.alive?
        return if @checked_at && Time.now - @checked_at < INTERNET_CHECK_DELAY

        @checked_at = Time.now
        @thread = Thread.new do
          @connected = INTERNET_HOSTS.any? { |host, port| reachable?(host, port) }
        end
      end

      # @return [Boolean]
      def reachable?(host, port)
        require 'socket' unless defined?(Socket)
        Socket.tcp(host, port, connect_timeout: INTERNET_TIMEOUT).close
        return true
      rescue StandardError, ScriptError
        return false
      end
    end

    # Téléphone : coque, fond d'écran, barre d'état, titre
    class Phone < SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, PHONE_X, PHONE_Y, default_cache: :interface)
        create_screen
        add_sprite(0, 0, PokeSmart.file('phone'))
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
        @clock.text = @clock_text = clock if clock != @clock_text
        @status_counter = (@status_counter || 0) - 1
        return if @status_counter > 0

        @status_counter = 30
        refresh_status
      end

      # Batterie, réseau et wifi
      def refresh_status
        set_icon(@battery, "battery_#{battery_level}")
        set_icon(@network, "reseau_mobile_#{network_level}")
        set_icon(@wifi, Internet.connected? ? 'wifi_3' : 'wifi_0')
      end

      # @return [Boolean] si la souris est sur le bouton rond du bas
      def home_button_hovered?
        return HOME_BUTTON[0].include?(Mouse.x - x) && HOME_BUTTON[1].include?(Mouse.y - y)
      end

      private

      def create_screen
        wallpaper = PokeSmart.wallpaper_name
        add_sprite(6, 34, PokeSmart.file("wallpapers/#{wallpaper}"))
        overlay = PokeSmart.wallpaper_overlay(wallpaper)
        add_sprite(6, 34, PokeSmart.file("wallpapers/#{overlay}")) if overlay
      end

      def create_status_bar
        @network = add_sprite(9, 26, PokeSmart.file('reseau_mobile_4'))
        @wifi = add_sprite(18, 26, PokeSmart.file('wifi_0'))
        with_font(20) { @clock = add_text(30, 23, 56, 13, '', 1, color: WHITE) }
        @battery = add_sprite(95, 26, PokeSmart.file('battery_80'))
      end

      # Change l'image d'une icône seulement si elle a changé
      def set_icon(sprite, name)
        return if sprite.instance_variable_get(:@pokesmart_icon) == name

        sprite.instance_variable_set(:@pokesmart_icon, name)
        sprite.set_bitmap(PokeSmart.file(name), :interface)
      end

      # Réseau selon la zone : extérieur (vol autorisé) 4 barres, grotte / donjon 0, bâtiment 2.
      # Une zone sans vol mais avec des Pokémon sauvages (forêt, marais…) compte comme l'extérieur.
      # @return [Integer] 0 à 4
      def network_level
        zone = $env.current_zone_data
        forced = zone && NETWORK_BY_ZONE[zone.id]
        return forced.clamp(0, 4) if forced
        return NETWORK_OUTSIDE if $game_switches[Yuki::Sw::Env_CanFly]

        name = "#{$env.current_zone_name.to_s.downcase} "
        return NETWORK_CAVE if $env.cave? || NO_NETWORK_WORDS.any? { |word| name.include?(word) }
        return NETWORK_OUTSIDE if zone && !zone.wild_groups.to_a.empty?

        return NETWORK_BUILDING
      rescue StandardError
        return NETWORK_OUTSIDE
      end

      # Batterie selon le moment de la journée, ou Pikachu si un Pikachu est dans l'équipe
      # @return [String] 20, 40, 60, 80 ou pika
      def battery_level
        return 'pika' if ($actors || []).compact.any? { |pokemon| !pokemon.egg? && PIKA_SPECIES.include?(pokemon.db_symbol) }

        return BATTERY_BY_TIME[time_of_day]
      rescue StandardError
        return '80'
      end

      # Moment de la journée : système jour / nuit de PSDK, sinon l'heure de l'ordinateur
      # @return [Symbol] :morning, :day, :evening ou :night
      def time_of_day
        if $env
          return :morning if $env.morning?
          return :day if $env.day?
          return :evening if $env.sunset?
          return :night if $env.night?
        end
        hour = Time.now.hour
        return :morning if hour.between?(6, 10)
        return :day if hour.between?(11, 17)
        return :evening if hour.between?(18, 20)

        return :night
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
        @tile = add_sprite(0, 0, PokeSmart.file('tile'))
        @icon = add_sprite(2, 2, PokeSmart.file('menu_icons'), 2, 18, type: SpriteSheet)
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
        @tile.set_bitmap(PokeSmart.file(value ? 'tile_selected' : 'tile'), :interface)
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
    module SmartStyle
      public

      # Déplacement en grille (gauche / droite = appli voisine, haut / bas = ligne)
      def update_inputs
        return false if @entering || @quiting

        delta = 0
        delta = -1 if Input.repeat?(:LEFT)
        delta = 1 if Input.repeat?(:RIGHT)
        delta = -UI::PokeSmart::COLUMNS if Input.repeat?(:UP)
        delta = UI::PokeSmart::COLUMNS if Input.repeat?(:DOWN)
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
      def phone_slide=(offset)
        delta = offset.to_i - (@phone_slide || 0)
        @phone_slide = offset.to_i
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
        # applis rangées dans l'ordre des icônes (les inconnues à la fin, dans leur ordre d'ajout)
        icons = UI::PokeSmart::APP_ICONS
        @image_indexes = @image_indexes.each_with_index.sort_by do |real_index, i|
          [icons.fetch(ACTION_LIST[real_index], 99), i]
        end.map(&:first)
      end

      def create_buttons
        @phone = UI::PokeSmart::Phone.new(@viewport)
        @buttons = @image_indexes.map.with_index do |real_index, i|
          UI::PokeSmart::AppButton.new(@viewport, real_index, i)
        end
        @max_index = @buttons.size - 1
        @index = @index.clamp(0, @max_index)
      end

      def update_buttons
        super
        @phone.title = @buttons[@index]&.name
      end

      def init_entering
        self.phone_slide = UI::PokeSmart::SLIDE_OFFSET
      end

      def create_entering_animation
        ya = Yuki::Animation
        slide = ya.scalar(UI::PokeSmart::SLIDE_DURATION, self, :phone_slide=, UI::PokeSmart::SLIDE_OFFSET, 0)
        return ya.parallel(ya.opacity_change(UI::PokeSmart::SLIDE_DURATION, @background, 0, 255), slide).start
      end

      def create_quitting_animation
        @__last_scene.spriteset.visible = true if @__last_scene.is_a?(Scene_Map) && !@animation
        @buttons.each { |button| button.selected = false }
        ya = Yuki::Animation
        slide = ya.scalar(UI::PokeSmart::SLIDE_DURATION, self, :phone_slide=, 0, UI::PokeSmart::SLIDE_OFFSET)
        return ya.parallel(ya.opacity_change(UI::PokeSmart::SLIDE_DURATION, @background, 255, 0), slide).start
      end

    end
    prepend SmartStyle if UI::PokeSmart::ENABLED
  end
end

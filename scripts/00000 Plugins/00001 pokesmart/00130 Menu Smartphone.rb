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
# - Applis en grille de 3 ; le nom de l'appli sélectionnée s'affiche en haut de l'écran.
#   Les applis principales (icônes 0 à 9) sont au-dessus d'un trait, les autres en dessous.
# - Appli Troupeaux : radar des Pokémon sauvages de la zone (vus, capturés ou « ? »),
#   avec le nom de la zone et le moment de la journée
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
    GRID_Y = 20
    CELL_X = 32
    CELL_Y = 30
    # Les applis dont l'icône est à partir de cette ligne vont sous le trait
    SECONDARY_FROM = 10
    # Espace ajouté sous le trait
    SEPARATOR_GAP = 4
    # Affiche l'appli Troupeaux (radar des Pokémon sauvages)
    HERDS_APP = true
    # Nombre de lignes de Pokémon visibles dans le radar (3 par ligne, haut / bas pour faire défiler)
    RADAR_ROWS = 3
    # Tags systèmes / outils des groupes considérés comme « sur l'eau » (marqueur bleu du radar)
    WATER_TAGS = %w[Ocean Pond Sea Lake WetSand]
    WATER_TOOLS = %w[OldRod GoodRod SuperRod]
    # Moment de la journée affiché dans le radar : {moment => [image, français, anglais]}
    DAYNIGHT = {
      morning: ['daynight_morning', 'Matin', 'Morning'],
      day: ['daynight_daytime', 'Journée', 'Daytime'],
      evening: ['daynight_evening', 'Soirée', 'Evening'],
      night: ['daynight_night', 'Nuit', 'Night']
    }
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

    # @return [Boolean]
    def french?
      return $options.nil? || $options.language == 'fr'
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
    rescue StandardError
      return :day
    end

    # Groupes de Pokémon sauvages actifs ici (zone actuelle, conditions de carte / interrupteur remplies)
    # @return [Array<Studio::Group>]
    def wild_groups
      zone = $env&.current_zone_data
      return [] unless zone

      return zone.wild_groups.to_a.map { |db_symbol| data_group(db_symbol) }.compact.select { |group| group_active?(group) }
    rescue StandardError
      return []
    end

    # @param group [Studio::Group]
    # @return [Boolean]
    def group_active?(group)
      return group.custom_conditions.to_a.reduce(true) do |previous, condition|
        current = condition_ok?(condition)
        condition.relation_with_previous_condition.to_s.casecmp?('OR') ? (previous || current) : (previous && current)
      end
    rescue StandardError
      return true
    end

    # @return [Boolean]
    def condition_ok?(condition)
      value = condition.value.to_i
      case condition.type.to_s
      when 'mapId' then return $game_map.map_id == value
      when 'enabledSwitch' then return $game_switches[value] ? true : false
      when 'disabledSwitch' then return !$game_switches[value]
      end
      return true
    end

    # @param group [Studio::Group]
    # @return [Boolean]
    def water_group?(group)
      return WATER_TAGS.include?(group.system_tag.to_s) || WATER_TOOLS.include?(group.tool.to_s)
    end

    # Pokémon sauvages de la zone, sans doublon (ceux sur terre d'abord)
    # @return [Array<Array(Symbol, Integer)>] [espèce, forme]
    def wild_species
      groups = wild_groups.sort_by { |group| water_group?(group) ? 1 : 0 }
      list = groups.flat_map { |group| group.encounters.to_a.map { |encounter| [encounter.specie, encounter.form.to_i] } }
      return list.uniq
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
        @separator = add_sprite(13, 34, PokeSmart.file('separator'))
        @separator.visible = false
        @clock_text = nil
        update
      end

      # @param text [String] nom de l'appli sélectionnée
      def title=(text)
        @title.text = text.to_s
      end

      # Place le trait entre les applis principales et les autres (nil = pas de trait)
      # @param screen_y [Integer, nil] ordonnée dans l'écran du téléphone
      def separator_y=(screen_y)
        @separator.visible = !screen_y.nil?
        @separator.y = y + 34 + screen_y.to_i
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

        return BATTERY_BY_TIME[PokeSmart.time_of_day]
      rescue StandardError
        return '80'
      end
    end

    # Écran de l'appli Troupeaux : Pokémon sauvages de la zone
    class Radar < SpriteStack
      # @param viewport [Viewport]
      # @param phone [Phone]
      def initialize(viewport, phone)
        super(viewport, phone.x + 6, phone.y + 34, default_cache: :interface)
        @species = PokeSmart.wild_species
        @water = (groups = PokeSmart.wild_groups).any? && groups.all? { |group| PokeSmart.water_group?(group) }
        @scroll = 0
        create_panel
        create_slots
        create_daynight
        refresh
      end

      # Fait défiler d'une ligne (haut / bas)
      # @param delta [Integer]
      # @return [Boolean] si la liste a bougé
      def scroll(delta)
        max = [(@species.size + COLUMNS - 1) / COLUMNS - RADAR_ROWS, 0].max
        target = (@scroll + delta).clamp(0, max)
        return false if target == @scroll

        @scroll = target
        refresh
        return true
      end

      private

      def create_panel
        rows = ((@species.size + COLUMNS - 1) / COLUMNS).clamp(1, RADAR_ROWS)
        name = @species.empty? ? (PokeSmart.french? ? 'group_items_empty' : 'group_items_empty_en') : "group_items_#{rows}"
        add_sprite(4, 22, PokeSmart.file(name))
        return if @species.empty?

        add_sprite(-2, 16, PokeSmart.file(@water ? 'radar_water' : 'radar_ground'))
      end

      def create_slots
        @slots = Array.new(RADAR_ROWS * COLUMNS) do |i|
          x = 4 + (i % COLUMNS) * 32
          y = 22 + (i / COLUMNS) * 32
          unknown = add_sprite(x, y, nil)
          unknown.set_bitmap('000', :b_icon)
          icon = push(x + 16, y + 16, nil, true, type: UI::PokemonIconSprite)
          ball = add_sprite(x + 22, y + 22, PokeSmart.file('wild_captured'))
          [unknown, icon, ball]
        end
        @slots.flatten.each { |sprite| sprite.visible = false }
      end

      def create_daynight
        image, fr, en = DAYNIGHT[PokeSmart.time_of_day]
        add_sprite(24, 124, PokeSmart.file(image))
        add_text(46, 128, 56, 14, PokeSmart.french? ? fr : en, 0, color: WHITE)
      end

      def refresh
        @slots.each_with_index do |(unknown, icon, ball), i|
          specie, form = @species[@scroll * COLUMNS + i]
          seen = specie && $pokedex&.creature_seen?(specie)
          unknown.visible = specie && !seen ? true : false
          icon.visible = false
          ball.visible = seen && $pokedex.creature_caught?(specie) ? true : false
          icon.data = creature(specie, form) if seen
        end
      end

      # @return [PFM::Pokemon, nil]
      def creature(specie, form)
        @creatures ||= {}
        return @creatures[[specie, form]] ||= PFM::Pokemon.new(specie, 5, false, true, form)
      rescue StandardError
        return nil
      end
    end

    # Appli de l'écran d'accueil (même interface que UI::PSDKMenuButtonBase)
    class AppButton < SpriteStack
      # @return [Boolean]
      attr_reader :selected
      # @return [String]
      attr_reader :name

      # @param viewport [Viewport]
      # @return [Integer] ligne de menu_icons.png
      attr_reader :icon_index
      # @return [Array(Integer, Integer)] ligne et colonne dans la grille
      attr_accessor :grid

      # @param real_index [Integer] index de l'action dans GamePlay::Menu::ACTION_LIST
      # @param screen_x [Integer] position dans l'écran du téléphone
      # @param screen_y [Integer]
      def initialize(viewport, real_index, screen_x = 0, screen_y = 0)
        super(viewport, SCREEN_X + screen_x, SCREEN_Y + screen_y, default_cache: :interface)
        @index = real_index
        @action = GamePlay::Menu::ACTION_LIST[real_index]
        @icon_index = APP_ICONS.fetch(@action, DEFAULT_ICON)
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

      # Même textes que le menu de PSDK pour ses boutons, sinon APP_NAMES
      # @return [String]
      def app_name
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

module GamePlay
  class Menu
    # Menu smartphone (la logique de PSDK reste inchangée : mêmes actions, mêmes scènes)
    module SmartStyle
      public

      # Déplacement en grille (gauche / droite = appli voisine, haut / bas = ligne)
      def update_inputs
        return false if @entering || @quiting
        return update_radar_inputs if @radar

        target = nil
        target = @index - 1 if Input.repeat?(:LEFT)
        target = @index + 1 if Input.repeat?(:RIGHT)
        target = vertical_target(-1) if Input.repeat?(:UP)
        target = vertical_target(1) if Input.repeat?(:DOWN)
        if target
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

      # Appli Troupeaux : affiche le radar des Pokémon sauvages dans le téléphone
      def open_herds
        @radar = UI::PokeSmart::Radar.new(@viewport, @phone)
        @buttons.each { |button| button.visible = false }
        @phone.separator_y = nil
        @phone.title = $env.current_zone_name.to_s
      rescue StandardError => e
        log_error("PokeSmart radar : #{e.message}") if respond_to?(:log_error, true)
        close_herds
      end

      # Retour aux applis
      def close_herds
        @radar&.dispose
        @radar = nil
        @buttons.each { |button| button.visible = true }
        @phone.separator_y = @separator_y
        update_buttons
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

        if @radar
          if Mouse.trigger?(:LEFT) || Mouse.trigger?(:RIGHT)
            play_cancel_se
            close_herds
          end
          return false
        end
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
        @radar&.update
      end

      # Pendant la sauvegarde PSDK ne cache que les boutons : le téléphone suit
      def visible=(value)
        super
        @phone.visible = value if @in_save
      end

      private

      # Radar ouvert : A / B / bouton rond pour revenir, haut / bas pour faire défiler
      def update_radar_inputs
        if Input.trigger?(:A) || Input.trigger?(:B)
          play_cancel_se
          close_herds
        elsif Input.repeat?(:UP) || Input.repeat?(:DOWN)
          play_cursor_se if @radar.scroll(Input.repeat?(:UP) ? -1 : 1)
        else
          return true
        end
        return false
      end

      # Appli de la ligne au-dessus / en dessous, la plus proche en colonne
      # @param direction [Integer] -1 ou 1
      # @return [Integer, nil]
      def vertical_target(direction)
        row, col = @buttons[@index].grid
        candidates = @buttons.each_index.select { |i| @buttons[i].grid[0] == row + direction }
        return candidates.min_by { |i| [(@buttons[i].grid[1] - col).abs, i] }
      end

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

      # Applis principales, trait, puis les autres applis
      def create_buttons
        ps = UI::PokeSmart
        @phone = ps::Phone.new(@viewport)
        @buttons = @image_indexes.map { |real_index| ps::AppButton.new(@viewport, real_index) }
        main, extra = @buttons.partition { |button| button.icon_index < ps::SECONDARY_FROM }
        main_rows = (main.size + ps::COLUMNS - 1) / ps::COLUMNS
        extra_y = ps::GRID_Y + main_rows * ps::CELL_Y + ps::SEPARATOR_GAP
        [[main, ps::GRID_Y, 0], [extra, extra_y, main_rows]].each do |group, top, first_row|
          group.each_with_index do |button, i|
            col = i % ps::COLUMNS
            row = i / ps::COLUMNS
            button.set_position(ps::SCREEN_X + ps::GRID_X + col * ps::CELL_X, ps::SCREEN_Y + top + row * ps::CELL_Y)
            button.grid = [first_row + row, col]
          end
        end
        @buttons = main + extra
        @separator_y = main.empty? || extra.empty? ? nil : extra_y - ps::SEPARATOR_GAP / 2 - 1
        @phone.separator_y = @separator_y
        @image_indexes = @buttons.map { |button| button.instance_variable_get(:@index) }
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
    if UI::PokeSmart::ENABLED
      prepend SmartStyle
      register_button(:open_herds) { UI::PokeSmart::HERDS_APP } unless ACTION_LIST.include?(:open_herds)
    end
  end
end

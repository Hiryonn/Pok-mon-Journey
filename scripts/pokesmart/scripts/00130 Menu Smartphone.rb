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
#   Une image par icône (graphics/interface/pokesmart/icon_*.png : normale à gauche, sélectionnée à droite)
# - Appli Troupeaux : radar des Pokémon sauvages de la zone (vus, capturés ou « ? »),
#   avec le nom de la zone et le moment de la journée
# - Appli Personnaliser : choix de l'apparence du téléphone (PokeSmart, Motismart…), enregistré dans la sauvegarde.
#   Chaque apparence a son dossier (graphics/interface/pokesmart/motismart/) ; une image absente
#   de ce dossier est prise dans graphics/interface/pokesmart/
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
    DARK = 0
    # Apparences du téléphone (coordonnées dans la coque) :
    #   dir : sous-dossier des images, phone : position de la coque à l'écran, screen : écran [x, y, largeur, hauteur],
    #   wallpaper : fond d'écran selon le Pokémon de tête, network / wifi / battery : icônes de la barre d'état,
    #   clock / title : [x, y, largeur, alignement 0 gauche 1 centre], color : couleur des textes,
    #   clock_color : couleur de l'heure (sinon color),
    #   grid : première appli, cell : espacement des applis, radar : origine de l'écran Troupeaux,
    #   home : zone du bouton du bas (clic = ranger le téléphone)
    THEMES = {
      pokesmart: {
        name: 'PokeSmart', dir: '', phone: [99, 8], screen: [6, 34, 104, 148], wallpaper: true,
        network: [9, 26], wifi: [18, 26], battery: [95, 26], clock: [30, 23, 56, 1], title: [6, 36, 104, 1], color: WHITE,
        grid: [13, 54], cell: [32, 30], radar: [6, 34], home: [50..66, 182..194]
      },
      motismart: {
        name: 'Motismart', dir: 'motismart/', phone: [99, 8], screen: [7, 25, 102, 173], wallpaper: false,
        network: [10, 17], wifi: [21, 17], battery: [94, 17], clock: [30, 14, 64, 1], clock_color: WHITE,
        title: [12, 27, 92, 0], color: DARK, grid: [12, 46], cell: [33, 30], radar: [6, 25], home: [50..64, 198..209]
      }
    }
    # Apparence par défaut (avant tout choix dans l'appli Personnaliser)
    DEFAULT_THEME = :pokesmart
    # Affiche l'appli Personnaliser
    CUSTOMIZATION_APP = true
    # Nombre de colonnes d'applis
    COLUMNS = 3
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
    # Icône (image de graphics/interface/pokesmart/) selon l'action du menu.
    # Les applis sont rangées dans cet ordre. Les actions pas encore codées sont déjà prêtes : il suffira de faire
    #   GamePlay::Menu.register_button(:open_map) { true }  (+ la méthode open_map dans GamePlay::Menu)
    APP_ICONS = {
      open_dex: 'icon_pokedex',               # Pokédex
      open_party: 'icon_party',               # Équipe
      open_bag: 'icon_bag',                   # Sac
      open_map: 'icon_map',                   # Carte
      open_pc: 'icon_pc',                     # PC
      open_quest: 'icon_book',                # Journal de quête
      open_tcard: 'icon_trainercard',         # Carte de dresseur
      open_friends: 'icon_friendlist',        # Liste d'amis
      open_save: 'icon_save',                 # Sauvegarde
      open_option: 'icon_option',             # Options
      open_customization: 'icon_custom',      # Personnalisation du téléphone
      open_mystery_gift: 'icon_mysterygift',  # Cadeau mystère
      open_mount: 'icon_mount',               # Appel monture
      open_herds: 'icon_pokemon',             # Troupeaux
      open_card_game: 'icon_card',            # Jeu de cartes
      open_daycare: 'icon_egg',               # Pension
      open_camera: 'icon_camera',             # Appareil photo
      open_fishing: 'icon_fishing'            # Pêche
    }
    # Icône des actions inconnues (applis ajoutées par d'autres plugins)
    DEFAULT_ICON = 'icon_debug'
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
      open_daycare: ['Pension', 'Daycare'],
      open_camera: ['Appareil photo', 'Camera'],
      open_fishing: ['Pêche', 'Fishing']
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
      dir = theme[:dir].to_s
      unless dir.empty?
        path = "#{DIR}#{dir}#{name}"
        @exists ||= {}
        @exists[path] = RPG::Cache.interface_exist?(path) if @exists[path].nil?
        return path if @exists[path]
      end
      return "#{DIR}#{name}"
    end

    # Apparence choisie (enregistrée dans la sauvegarde)
    # @return [Symbol]
    def theme_id
      id = $user_data[:pokesmart_theme] if $user_data.is_a?(Hash)
      return THEMES.key?(id) ? id : DEFAULT_THEME
    end

    # @param id [Symbol]
    def theme_id=(id)
      $user_data[:pokesmart_theme] = id if $user_data.is_a?(Hash) && THEMES.key?(id)
    end

    # @return [Hash]
    def theme
      return THEMES[theme_id]
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
        @theme = PokeSmart.theme
        super(viewport, *@theme[:phone], default_cache: :interface)
        add_sprite(0, 0, PokeSmart.file('phone'))
        create_screen if @theme[:wallpaper]
        create_status_bar
        tx, ty, tw, align = @theme[:title]
        @title = add_text(tx, ty, tw, 16, '', align, color: @theme[:color])
        @clock_text = nil
        update
      end

      # @return [Hash] apparence du téléphone
      attr_reader :theme

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
        range_x, range_y = @theme[:home]
        return range_x.include?(Mouse.x - x) && range_y.include?(Mouse.y - y)
      end

      private

      def create_screen
        sx, sy = @theme[:screen]
        wallpaper = PokeSmart.wallpaper_name
        add_sprite(sx, sy, PokeSmart.file("wallpapers/#{wallpaper}"))
        overlay = PokeSmart.wallpaper_overlay(wallpaper)
        add_sprite(sx, sy, PokeSmart.file("wallpapers/#{overlay}")) if overlay
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
        @color = phone.theme[:color]
        super(viewport, phone.x + phone.theme[:radar][0], phone.y + phone.theme[:radar][1], default_cache: :interface)
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
        add_text(46, 128, 56, 14, PokeSmart.french? ? fr : en, 0, color: @color)
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

    # Écran de l'appli Personnaliser : liste des apparences
    class ThemePicker < SpriteStack
      ROW_WIDTH = 92
      ROW_HEIGHT = 18
      ROW_SPACING = 22
      # @return [Integer] apparence sélectionnée (index dans THEMES)
      attr_reader :index

      # @param viewport [Viewport]
      # @param phone [Phone]
      # @param index [Integer]
      def initialize(viewport, phone, index)
        theme = phone.theme
        sx, _sy, sw = theme[:screen]
        super(viewport, phone.x + sx + (sw - ROW_WIDTH) / 2, phone.y + theme[:grid][1], default_cache: :interface)
        @index = index
        @rows = THEMES.values.map.with_index do |data, i|
          bar = add_sprite(0, i * ROW_SPACING, PokeSmart.file(i == index ? 'choice_selected' : 'choice'))
          add_text(0, i * ROW_SPACING + 2, ROW_WIDTH, ROW_HEIGHT - 2, data[:name], 1, color: DARK)
          bar
        end
      end

      # @return [Integer, nil] ligne sous la souris
      def hovered_row
        mx = Mouse.x - x
        my = Mouse.y - y
        return nil unless mx.between?(0, ROW_WIDTH - 1)

        row = my / ROW_SPACING
        return nil unless row.between?(0, @rows.size - 1) && my % ROW_SPACING < ROW_HEIGHT

        return row
      end
    end

    # Appli de l'écran d'accueil (même interface que UI::PSDKMenuButtonBase)
    class AppButton < SpriteStack
      # @return [Boolean]
      attr_reader :selected
      # @return [String]
      attr_reader :name

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
        @icon = add_sprite(2, 2, PokeSmart.file(icon_name), 2, 1, type: SpriteSheet)
        @icon.select(0, 0)
        @icon_dy = (26 - @icon.height) / 2
        @icon.y = y + @icon_dy
        @name = app_name
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

      # Image de l'icône (icône générique si l'image manque)
      # @return [String]
      def icon_name
        name = APP_ICONS.fetch(@action, DEFAULT_ICON)
        return name if RPG::Cache.interface_exist?(PokeSmart.file(name))

        return DEFAULT_ICON
      end

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
        return update_picker_inputs if @picker

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
        update_buttons
      end

      # Appli Personnaliser : choix de l'apparence du téléphone (aperçu en direct)
      def open_customization
        @theme_before = UI::PokeSmart.theme_id
        open_picker(UI::PokeSmart::THEMES.keys.index(@theme_before))
      end

      # Ferme l'appli Personnaliser
      # @param keep [Boolean] garde l'apparence choisie (sinon remet celle d'avant)
      def close_customization(keep)
        rebuild_phone(@theme_before) unless keep
        @picker&.dispose
        @picker = nil
        @buttons.each { |button| button.visible = true }
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

        return update_picker_mouse if @picker
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

      # Affiche la liste des apparences (les applis sont cachées)
      # @param index [Integer]
      def open_picker(index)
        @picker&.dispose
        @picker = UI::PokeSmart::ThemePicker.new(@viewport, @phone, index)
        @buttons.each { |button| button.visible = false }
        @phone.title = @buttons[@index]&.name
      end

      # Change d'apparence : recrée le téléphone et ses applis à leur nouvelle place
      # @param theme_id [Symbol]
      def rebuild_phone(theme_id)
        UI::PokeSmart.theme_id = theme_id
        @phone.dispose
        @buttons.each(&:dispose)
        create_buttons
        update_buttons
      end

      # Aperçu de l'apparence n° index
      # @param index [Integer]
      def preview_theme(index)
        rebuild_phone(UI::PokeSmart::THEMES.keys[index])
        open_picker(index)
      end

      # Personnaliser : haut / bas pour choisir (aperçu direct), A pour garder, B pour annuler
      def update_picker_inputs
        count = UI::PokeSmart::THEMES.size
        if Input.repeat?(:UP) || Input.repeat?(:DOWN)
          target = (@picker.index + (Input.repeat?(:UP) ? -1 : 1)) % count
          if target != @picker.index
            play_cursor_se
            preview_theme(target)
          end
        elsif Input.trigger?(:A)
          play_decision_se
          close_customization(true)
        elsif Input.trigger?(:B)
          play_cancel_se
          close_customization(false)
        else
          return true
        end
        return false
      end

      # Personnaliser à la souris : clic sur une apparence pour la garder, clic droit pour annuler
      def update_picker_mouse
        if Mouse.trigger?(:RIGHT)
          play_cancel_se
          close_customization(false)
        elsif Mouse.trigger?(:LEFT) && (row = @picker.hovered_row)
          play_decision_se
          preview_theme(row) if row != @picker.index
          close_customization(true)
        end
        return false
      end

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
        order = UI::PokeSmart::APP_ICONS.keys
        @image_indexes = @image_indexes.each_with_index.sort_by do |real_index, i|
          [order.index(ACTION_LIST[real_index]) || order.size, i]
        end.map(&:first)
      end

      # Applis en grille, dans l'ordre de APP_ICONS (les inconnues à la fin)
      def create_buttons
        ps = UI::PokeSmart
        @phone = ps::Phone.new(@viewport)
        gx, gy = @phone.theme[:grid]
        cx, cy = @phone.theme[:cell]
        @buttons = @image_indexes.map.with_index do |real_index, i|
          col = i % ps::COLUMNS
          row = i / ps::COLUMNS
          button = ps::AppButton.new(@viewport, real_index, @phone.x + gx + col * cx, @phone.y + gy + row * cy)
          button.grid = [row, col]
          next button
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
    if UI::PokeSmart::ENABLED
      prepend SmartStyle
      register_button(:open_herds) { UI::PokeSmart::HERDS_APP } unless ACTION_LIST.include?(:open_herds)
      register_button(:open_customization) { UI::PokeSmart::CUSTOMIZATION_APP } unless ACTION_LIST.include?(:open_customization)
    end
  end
end

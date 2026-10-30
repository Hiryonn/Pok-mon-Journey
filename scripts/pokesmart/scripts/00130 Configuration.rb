# PokeSmart — menu principal (GamePlay::Menu) en smartphone, d'après le pack « PokeSmart »
#
# Fichiers du plugin (chargés dans l'ordre) :
#   00130 Configuration    : tous les réglages (coques, icônes, fonds, réseau, batterie…)
#   00131 Personnalisation : choix enregistrés (coque, icônes, fond d'écran) et chemins des images
#   00132 Barre d'etat     : heure du jeu, batterie, réseau, test Internet
#   00133 Telephone        : la coque, le fond d'écran, la barre d'état et le titre
#   00134 Appli            : une case d'appli de l'écran d'accueil
#   00135 Liste de choix   : liste utilisée par l'appli Personnaliser
#   00136 Radar            : Pokémon sauvages de la zone (appli Troupeaux)
#   00140 Menu             : le menu PSDK habillé en téléphone (grille, entrée / sortie)
#   00141 App Troupeaux    : ouverture / fermeture du radar
#   00142 App Personnaliser: rubriques Coque / Icônes / Fond d'écran
#
# - Le téléphone monte du bas de l'écran ; le jeu reste visible (flouté) derrière
# - Barre d'état : batterie selon le moment de la journée (Pikachu dans l'équipe = batterie Pikachu),
#   réseau selon la zone, wifi selon la connexion Internet de l'ordinateur, heure réelle
# - Fond d'écran (graphics/interface/pokesmart/wallpapers/) : image posée sur l'écran de la coque, calée en bas à droite.
#   En automatique : image de l'espèce de tête (« 025_wallpaper »…), sinon selon son type (TYPE_WALLPAPERS), sinon rien
# - Applis en grille de 3 ; le nom de l'appli sélectionnée s'affiche en haut de l'écran.
#   Une image par icône (icon_*.png : normale à gauche, sélectionnée à droite)
# - Appli Troupeaux : radar des Pokémon sauvages de la zone ; appli Personnaliser : coque, icônes, fond d'écran
# Touches : flèches pour se déplacer, A pour ouvrir, B pour ranger le téléphone.
# Souris : survol / clic sur une appli, clic sur le bouton du bas pour ranger le téléphone.
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
    #   wallpaper : fond d'écran par défaut (true = selon le Pokémon de tête, false = aucun), network / wifi / battery : icônes de la barre d'état,
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
    # Coque par défaut (avant tout choix dans l'appli Personnaliser)
    DEFAULT_THEME = :pokesmart
    # Jeux d'icônes (dossier des icon_*.png ; une icône absente est prise dans graphics/interface/pokesmart/).
    # Sans choix dans Personnaliser, le jeu qui porte le nom de la coque est utilisé.
    ICON_SETS = {
      pokesmart: {name: 'PokeSmart', dir: ''},
      motismart: {name: 'Motismart', dir: 'motismart/'}
    }
    # Fonds d'écran proposés dans Personnaliser quand le dossier wallpapers/ ne peut pas être lu
    # (normalement la liste est faite à partir des images du dossier, triées par nom)
    WALLPAPERS = %w[001_wallpaper 004_wallpaper 007_wallpaper]
    # Rubriques de Personnaliser : {réglage => [français, anglais]}
    CUSTOM_CATEGORIES = {
      case: ['Coque', 'Phone case'],
      icons: ['Icônes', 'Icons'],
      wallpaper: ["Fond d'écran", 'Wallpaper']
    }
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
    # Fond d'écran automatique selon le premier type du Pokémon de tête
    TYPE_WALLPAPERS = {grass: '001_wallpaper', fire: '004_wallpaper', water: '007_wallpaper'}
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
  end
end

# Pokédex style PE pour Pokémon Journey
#
# Remplace l'habillage du Pokédex de PSDK (GamePlay::Dex et GamePlay::DexInfo) sans toucher à sa logique :
# navigation, filtres, formes, cris, carte, souris restent ceux de PSDK.
#
# Graphismes : graphics/pokedex/pe/
#   bg_list / bg_info / bg_map : fonds 320x240 (bandeau POKÉDEX, cadres, tableau, zone de description)
#   row / row_selected / row_unseen : lignes de la liste (212x38)
#   pill_caught / pill_seen : pastilles « capturés » et « rencontrés » d'une ligne
#   ball_on / ball_off : Poké Ball allumée (capturé) ou éteinte (vu seulement)
#   scroll_track / scroll_thumb : barre de défilement
#   intro_bg / device_closed / device_open : petite animation d'ouverture
#
# Pour revenir au Pokédex d'origine : passer ENABLED à false (ou supprimer ce dossier).
module UI
  module DexPE
    # Active ou non le Pokédex Horizon
    ENABLED = true

    # Joue l'animation d'ouverture (appareil qui s'ouvre) en entrant dans le Pokédex
    PLAY_INTRO = true

    # Dossier des graphismes (dans graphics/pokedex/)
    PATH = 'pe/'

    # Fond affiché pour chaque état du Pokédex (0 = liste, 1 = infos, 2 = carte)
    PAGES = %w[bg_list bg_info bg_map]

    # Couleur de texte claire (texte blanc avec ombre) et sombre
    WHITE = 10

    DARK = 0

    # Police fine (PowerGreenSmall) utilisée pour les petits chiffres
    SMALL_FONT = 20

    # Textes de la fiche absents des fichiers de PSDK : [français, anglais]
    LABELS = {
      back: ['Retour', 'Back'],
      no_forms: ['Aucune autre forme…', 'No known forms...'],
      encountered: ['Rencontrés : %d', 'Encountered: %d']
    }

    # @return [Boolean] l'écran est plus large que 320 px
    def self.wide?
      return defined?(::Ecran) && ::Ecran.grand? ? true : false
    end

    # @return [Integer] x du bord gauche de l'écran
    def self.left
      return wide? ? ::Ecran.logique_gauche : 0
    end

    # @return [Integer] largeur de l'écran
    def self.full_width
      return wide? ? ::Ecran.logique_largeur : 320
    end

    # @return [Integer] largeur gagnée par rapport à 320
    def self.extra
      return full_width - 320
    end

    # Fond d'une page en pleine largeur (bords conservés, milieux uniformes étirés)
    # @param name [String] bg_list, bg_info ou bg_map
    # @return [Bitmap, nil] nil si l'écran n'est pas élargi
    def self.wide_background(name)
      return nil unless wide?

      w = full_width
      e = extra
      pieces = case name
               when 'bg_list'
                 plate = (w - 152) / 2
                 [[0, 0, plate, 30, 40, 0, 20, 30], [plate, 0, 152, 30, 84, 0, 152, 30],
                  [plate + 152, 0, w - plate - 152, 30, 260, 0, 20, 30],
                  [0, 30, 104, 184, 0, 30, 104, 184], [104, 30, 192 + e, 184, 110, 30, 190, 184],
                  [w - 20, 30, 20, 184, 300, 30, 20, 184], [0, 214, w, 26, 150, 214, 20, 26]]
               when 'bg_info'
                 [[0, 0, 180, 22, 0, 0, 180, 22], [180, 0, w - 300, 22, 186, 0, 14, 22], [w - 120, 0, 120, 22, 200, 0, 120, 22],
                  [0, 22, 122, 90, 0, 22, 122, 90], [122, 22, w - 242, 90, 140, 22, 60, 90], [w - 120, 22, 120, 90, 200, 22, 120, 90],
                  [0, 112, 150, 102, 0, 112, 150, 102], [150, 112, w - 170, 102, 150, 112, 150, 102], [w - 20, 112, 20, 102, 300, 112, 20, 102],
                  [0, 214, 62, 26, 0, 214, 62, 26], [62, 214, w - 114, 26, 100, 214, 100, 26], [w - 52, 214, 52, 26, 268, 214, 52, 26]]
               else
                 [[0, 0, 104, 214, 0, 0, 104, 214], [104, 0, 192 + e, 214, 110, 0, 190, 214],
                  [w - 20, 0, 20, 214, 300, 0, 20, 214], [0, 214, w, 26, 150, 214, 20, 26]]
               end
      return ::Ecran.composer(file(name), :pokedex, w, pieces)
    end

    # Charge un graphisme PE
    # @param name [String]
    # @return [String]
    def self.file(name)
      return "#{PATH}#{name}"
    end

    # @param key [Symbol]
    # @return [String]
    def self.label(key)
      return LABELS[key][$options&.language == 'fr' ? 0 : 1]
    end

    # Libellé d'une touche du Pokédex sans le « : » de PSDK (ex. « : habitat » -> « Habitat »)
    # @param text_id [Integer] texte du fichier 9000
    # @return [String]
    def self.key_label(text_id)
      text = ext_text(9000, text_id).to_s.sub(/\A[:\s]+/, '')
      return text[0].to_s.upcase + text[1..].to_s
    end
  end
end

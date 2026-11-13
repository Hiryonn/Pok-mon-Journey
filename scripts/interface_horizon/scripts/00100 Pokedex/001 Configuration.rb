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

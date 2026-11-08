# Sac (GamePlay::Bag) en grille, d'après l'exemple fourni
#
# - Bandeau : « Sac : <poche> » et l'argent ; onglets des poches (l'onglet actif garde sa pointe)
# - Grille d'objets : case grise avec l'icône, la quantité en haut à gauche, un cœur si favori
# - Panneau du bas : nom et quantité, icône dans l'hexagone, description (X l'affiche / le cache)
# Déplacements : haut / bas = ligne, gauche / droite = case ; au bord de la grille, gauche / droite
# change de poche. Souris : clic sur une case (re-clic = A), clic sur un onglet, molette, clic droit = retour.
# Pas de barre de boutons en bas. Utiliser, donner, raccourcis, trier, chercher, vendre, combat…
# restent ceux de PSDK.
#
# Graphismes : graphics/interface/bag_pe/
# Pour revenir au sac d'origine : passer ENABLED à false (ou supprimer ce dossier).
module UI
  module BagPE
    # Active ou non le nouveau sac
    ENABLED = true

    # Dossier des graphismes (dans graphics/interface/)
    DIR = 'bag_pe/'

    WHITE = 9

    SMALL_FONT = 20

    # Couleur du nom de la poche dans le titre
    POCKET_COLOR = [0xf0, 0xa0, 0x40]

    # Poche PSDK => onglet de la planche
    # (0 Balls, 1 Objets, 2 Soins, 3 Lettres, 4 Baies, 5 CT, 6 marteau, 7 Objets rares, 8 Favoris)
    POCKET_TABS = {1 => 1, 2 => 0, 3 => 5, 4 => 4, 5 => 7, 6 => 2, 7 => 3, 8 => 8}

    # Onglets : position, écart, hauteur sans la pointe
    TAB_X = 4

    TAB_Y = 22

    TAB_STEP = 29

    TAB_HEIGHT = 24

    # Grille
    COLUMNS = 7

    CELL = 44

    GRID_X = 8

    GRID_Y = 54

    # Lignes visibles avec / sans le panneau d'infos
    ROWS_WITH_PANEL = 2

    ROWS_FULL = 4

    PANEL_Y = 150

    module_function

    # @param name [String]

    # @return [String]
    def file(name)
      return "#{DIR}#{name}"
    end
  end
end

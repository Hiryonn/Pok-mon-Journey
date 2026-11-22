# Sac Horizon (GamePlay::Bag) : style « Bag Screen with Party » (Essentials), en 320 x 240
#
# - Couleurs du Pokédex Horizon : fond clair avec reflet, bandeau bleu en haut, liste et équipe bleu acier
# - Haut : nom de la poche et icônes des poches ; à gauche, l'équipe (PV, niveau ; APTE / PAS APTE pour les CT
#   et les objets qui s'utilisent sur un Pokémon) et l'argent
# - À droite : liste des objets (quantité, « SET » si l'objet est enregistré), dernière ligne « Fermer le sac »
# - Bas : icône et description de l'objet choisi
# Déplacements : haut / bas = objet, gauche / droite = poche. Souris : clic sur un objet (re-clic = A),
# clic sur une poche, molette, clic droit = retour. Utiliser, donner, trier, chercher, vendre… restent ceux de PSDK.
#
# Graphismes : graphics/interface/bag_horizon/ (faits par tools/interface-horizon/build_bag_assets.py)
# Sons : audio/se/bag_horizon/cursor.ogg et pocket.ogg
# Pour revenir au sac d'origine : passer ENABLED à false.
module UI
  module BagHorizon
    # Active ou non le nouveau sac
    ENABLED = true

    # Dossier des graphismes (dans graphics/interface/)
    DIR = 'bag_horizon/'
    # Sons (curseur, changement de poche)
    SE_CURSOR = 'audio/se/bag_horizon/cursor'
    SE_POCKET = 'audio/se/bag_horizon/pocket'

    # Couleurs des textes
    WHITE = 9
    DARK = 0
    # Petite police
    SMALL_FONT = 20

    # Fond : vitesse du motif (pixels par image) ; motif sombre la nuit
    PANORAMA_SPEED = 0.5
    PANORAMA_DARK_AT_NIGHT = false

    # Poche PSDK => icône de la planche pockets.png
    # (0 Objets, 1 Soins, 2 Balls, 3 CT, 4 Baies, 5 Lettres, 6 Objets de combat, 7 Objets rares)
    POCKET_ICONS = { 1 => 0, 2 => 2, 3 => 3, 4 => 4, 5 => 7, 6 => 1, 7 => 5, 8 => 6 }
    POCKET_ICON_SIZE = 14
    POCKET_STEP = 16
    POCKET_RIGHT = 316
    POCKET_Y = 2

    # Équipe : cadre, puis case (colonne, ligne)
    PARTY_X = 4
    PARTY_Y = 22
    PANEL_STEP_X = 57
    PANEL_STEP_Y = 48
    PANEL_HEIGHT = 50
    # Argent
    MONEY_Y = 170

    # Liste
    LIST_X = 120
    LIST_Y = 22
    LIST_WIDTH = 196
    ROW_TOP = 4
    ROW_HEIGHT = 16
    ROWS = 10

    # Barre de description
    INFO_Y = 193

    module_function

    # @param name [String]
    # @return [String]
    def file(name)
      return "#{DIR}#{name}"
    end

    # Texte selon la langue
    def t(fr, en)
      return $options && $options.language.to_s != 'fr' ? en : fr
    end
  end
end

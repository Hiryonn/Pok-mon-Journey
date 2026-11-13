# Équipe (GamePlay::Party_Menu) dans le style du Pokédex Horizon
#
# - Bandeau de la fiche du Pokédex avec le titre (« Équipe »)
# - 6 cartes bleu acier sur 2 colonnes : icône dans l'hexagone, nom, sexe, niveau, statut, objet tenu, PV
#   (carte rouge : K.O. ; carte verte : œuf ; bord jaune : Pokémon choisi pour un échange / une sélection)
# - Curseur cyan qui clignote, message dans une bande bleue, barre du bas à 4 cases (A / X / Y / B, cliquables)
# Tous les écrans d'équipe : menu, choix d'un Pokémon (objet, CT…), combat, sélection d'équipe.
# La logique de PSDK ne change pas.
#
# Graphismes : graphics/interface/party_pe/
# Pour revenir à l'écran d'origine : passer ENABLED à false.
module UI
  module PartyPE
    # Active ou non le nouvel écran d'équipe
    ENABLED = true

    # Dossier des graphismes (dans graphics/interface/)
    DIR = 'party_pe/'

    # Couleur des textes (blanc) et petite police
    WHITE = 10
    DARK = 0
    SMALL_FONT = 20

    # Cartes : position de chacune (2 colonnes, 3 lignes), taille
    CARDS = Array.new(6) { |i| [6 + (i % 2) * 157, 26 + (i / 2) * 54] }.freeze
    CARD_WIDTH = 151
    CARD_HEIGHT = 52

    # Bande de message et barre du bas
    MESSAGE_Y = 190
    NAV_Y = 214
    NAV = [[0, NAV_Y], [80, NAV_Y], [160, NAV_Y], [240, NAV_Y]].freeze

    # Titre du bandeau [français, anglais]
    TITLE = %w[Équipe Team].freeze

    module_function

    # @param name [String]
    # @return [String]
    def file(name)
      return "#{DIR}#{name}"
    end

    # @return [String]
    def title
      return TITLE[$options && $options.language.to_s != 'fr' ? 1 : 0]
    end
  end
end

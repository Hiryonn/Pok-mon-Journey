# Triple Triad (comme dans Pokémon Essentials) : jeu de cartes Pokémon sur un plateau 3x3
#
# Chaque carte = un Pokémon, avec 4 valeurs (haut, droite, bas, gauche) de 1 à 10 (A) tirées de ses stats.
# Poser une carte à côté d'une carte adverse la capture si la valeur qui la touche est plus grande.
# À la fin, celui qui possède le plus de cartes (plateau + main) gagne.
#
# Commandes d'évent (Script) : voir 00106 Commandes.rb
#   triple_triad_duel('Léo', 0, 3)              -> duel (adversaire avec des cartes de niveau 0 à 3)
#   give_triad_card(:pikachu, 2)                -> donne des cartes
#   triple_triad_collection / triple_triad_shop -> voir ses cartes / boutique
#
# Graphismes : graphics/interface/triple_triad/
module TripleTriad
  # Dossier des graphismes (dans graphics/interface/)
  DIR = 'triple_triad/'
  # Nombre de cartes par main
  HAND_SIZE = 5
  # Plateau : coin haut gauche de la 1re case, pas entre les cases
  BOARD_X = 101
  BOARD_Y = 25
  CELL_W = 39
  CELL_H = 47
  # Mains : x du joueur / de l'adversaire, y de la 1re carte, écart entre les cartes
  HAND_X = [30, 250].freeze
  HAND_Y = 18
  HAND_STEP = 30
  # Décalage de la carte choisie dans la main
  HAND_PICK_OFFSET = 10
  # Taille d'une carte
  CARD_W = 40
  CARD_H = 48
  # Règles connues (comme Essentials) :
  #   open        : la main de l'adversaire est visible
  #   random      : 5 cartes tirées au hasard dans la collection du joueur
  #   same        : « Pareil » (2 côtés égaux ou plus capturent, avec combo)
  #   samewall    : « Pareil mur » (les bords du plateau comptent comme des A pour Pareil)
  #   plus        : « Plus » (2 sommes égales ou plus capturent, avec combo)
  #   elements    : certaines cases ont un type : +1 si la carte a ce type, -1 sinon
  #   suddendeath : en cas d'égalité, on rejoue avec les cartes possédées
  #   trade_none / trade_one (par défaut) / trade_direct / trade_all : échange de cartes à la fin
  RULES = %i[open random same samewall plus elements suddendeath trade_none trade_one trade_direct trade_all].freeze
  # Prix minimum d'une carte (boutique)
  MIN_PRICE = 100

  module_function

  # @return [String]
  def file(name)
    return "#{DIR}#{name}"
  end

  # Texte selon la langue
  # @param fr [String]
  # @param en [String]
  # @return [String]
  def t(fr, en)
    return $options && $options.language.to_s != 'fr' ? en : fr
  end
end

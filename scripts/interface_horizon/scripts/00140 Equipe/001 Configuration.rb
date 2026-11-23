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

    # @return [Boolean] l'écran est plus large que 320 px
    def wide?
      return defined?(::Ecran) && ::Ecran.grand? ? true : false
    end

    # @return [Integer] x du bord gauche de l'écran
    def left
      return wide? ? ::Ecran.logique_gauche : 0
    end

    # @return [Integer] largeur de l'écran
    def full_width
      return wide? ? ::Ecran.logique_largeur : 320
    end

    # @return [Integer] largeur d'une carte (2 colonnes sur toute la largeur)
    def card_width
      return wide? ? (full_width - 18) / 2 : CARD_WIDTH
    end

    # @param index [Integer] numéro de la carte (0..5)
    # @return [Array(Integer, Integer)]
    def card_position(index)
      return [left + 6 + (index % 2) * (card_width + 6), 26 + (index / 2) * 54]
    end

    # @return [Integer] largeur d'une case de la barre du bas
    def nav_width
      return full_width / 4
    end

    # @param index [Integer] numéro de la case (0..3)
    # @return [Array(Integer, Integer)]
    def nav_position(index)
      return [left + nav_width * index, NAV_Y]
    end

    # Fond de l'écran en pleine largeur : bandeau du haut, dégradé, barre du bas à 4 cases
    # @return [Bitmap, nil] nil si l'écran n'est pas élargi
    def wide_background
      return nil unless wide?
      return @wide_background if @wide_background && !@wide_background.disposed? && @wide_width == full_width

      width = full_width
      source = Image.new(RPG::Cache.interface(file('background')).to_png, true)
      img = Image.new(width, 240)
      # Bandeau du haut : bords conservés, milieu sombre étiré
      img.blt(0, 0, source, Rect.new(0, 0, 32, 22))
      img.stretch_blt(Rect.new(32, 0, width - 32 - 152, 22), source, Rect.new(32, 0, 136, 22))
      img.blt(width - 152, 0, source, Rect.new(168, 0, 152, 22))
      # Dégradé du milieu
      img.stretch_blt(Rect.new(0, 22, width, 192), source, Rect.new(0, 22, 320, 192))
      # Barre du bas : fond uni et séparateurs obliques entre les 4 cases
      img.stretch_blt(Rect.new(0, 214, width, 26), source, Rect.new(0, 214, 8, 26))
      (1..3).each do |i|
        img.blt(nav_width * i - 10, 214, source, Rect.new(70, 214, 20, 26))
      end
      bitmap = Bitmap.new(width, 240)
      img.copy_to_bitmap(bitmap)
      img.dispose
      source.dispose
      @wide_width = width
      return @wide_background = bitmap
    end

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

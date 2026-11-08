# Interface PE — images des types : une ligne de hauteur fixe par type
#
# PSDK découpe graphics/interface/types*.png (et graphics/pokedex/types*.png) en autant de lignes
# qu'il y a de types chargés dans le jeu. Si ce nombre ne correspond pas aux lignes de l'image,
# toutes les étiquettes sont décalées. On découpe donc selon la hauteur d'une ligne :
# 14 pixels (interface) ou 16 pixels (Pokédex) ; la ligne = l'id du type dans Studio (ligne 0 : pas de type).
module UI
  class Type1Sprite
    module PEFixedRows
      # Hauteur d'une ligne : [interface, Pokédex]
      ROW_HEIGHT = [14, 16].freeze

      def initialize(viewport, from_pokedex = false)
        super
        height = ROW_HEIGHT[from_pokedex ? 1 : 0]
        self.nb_y = bitmap.height / height if bitmap && bitmap.height >= height && (bitmap.height % height).zero?
      end
    end
    prepend PEFixedRows
  end
end

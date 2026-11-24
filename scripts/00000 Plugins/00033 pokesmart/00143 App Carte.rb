# PokeSmart : appli Carte (carte du monde de PSDK)
module UI
  module PokeSmart
    # Affiche l'appli Carte
    MAP_APP = true
    # Objet nécessaire pour voir l'appli (nil = toujours visible)
    MAP_ITEM = :town_map
  end
end

module GamePlay
  class Menu
    module SmartStyle
      public

      # Appli Carte : ouvre la carte du monde sur la région du joueur
      def open_map
        GamePlay.open_town_map
      end
    end

    if UI::PokeSmart::ENABLED
      register_button(:open_map) do
        item = UI::PokeSmart::MAP_ITEM
        UI::PokeSmart::MAP_APP && (item.nil? || ($bag && $bag.contain_item?(item)))
      end unless ACTION_LIST.include?(:open_map)
    end
  end
end

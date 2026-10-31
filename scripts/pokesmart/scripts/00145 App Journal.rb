# PokeSmart : appli Journal (journal de quêtes de PSDK)
module UI
  module PokeSmart
    # Affiche l'appli Journal
    QUEST_APP = true
  end
end

module GamePlay
  class Menu
    module SmartStyle
      public

      # Appli Journal : ouvre le journal de quêtes de PSDK
      def open_quest
        GamePlay.open_quest_ui
      end
    end

    if UI::PokeSmart::ENABLED
      register_button(:open_quest) { UI::PokeSmart::QUEST_APP } unless ACTION_LIST.include?(:open_quest)
    end
  end
end

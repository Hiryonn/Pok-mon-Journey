# PokeSmart : appli PC (boîtes de Pokémon à distance, seulement avec du réseau)
module UI
  module PokeSmart
    # Affiche l'appli PC
    PC_APP = true
    # Barres de réseau nécessaires pour ouvrir le PC (0 = partout, même dans les grottes)
    PC_MIN_NETWORK = 1
    # Message affiché en titre quand il n'y a pas assez de réseau : [français, anglais]
    PC_NO_NETWORK = ['Pas de réseau', 'No signal']
  end
end

module GamePlay
  class Menu
    module SmartStyle
      public

      # Appli PC : ouvre le système de stockage des Pokémon s'il y a assez de réseau
      def open_pc
        ps = UI::PokeSmart
        if ps.network_level < ps::PC_MIN_NETWORK
          play_buzzer_se if respond_to?(:play_buzzer_se, true)
          @phone.title = ps::PC_NO_NETWORK[ps.french? ? 0 : 1]
          return
        end
        GamePlay.open_pokemon_storage_system
        Yuki::FollowMe.update if defined?(Yuki::FollowMe)
        @background.update_snapshot if @background.respond_to?(:update_snapshot)
        # l'équipe a pu changer (fond d'écran selon le Pokémon de tête)
        rebuild_phone
      end
    end

    if UI::PokeSmart::ENABLED
      register_button(:open_pc) { UI::PokeSmart::PC_APP } unless ACTION_LIST.include?(:open_pc)
    end
  end
end

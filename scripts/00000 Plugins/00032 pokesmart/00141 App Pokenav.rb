# PokeSmart : appli Pokénav (radar des Pokémon sauvages)
module GamePlay
  class Menu
    module SmartStyle
      public

      # Appli Pokénav : affiche le radar des Pokémon sauvages dans le téléphone
      def open_pokenav
        @radar = UI::PokeSmart::Radar.new(@viewport, @phone)
        hide_home_buttons
        @phone.title = $env.current_zone_name.to_s
      rescue StandardError => e
        log_error("PokeSmart radar : #{e.message}") if respond_to?(:log_error, true)
        close_pokenav
      end

      # Retour aux applis
      def close_pokenav
        @radar&.dispose
        @radar = nil
        show_home_buttons
        update_buttons
      end

      private

      # Radar ouvert : A / B / bouton rond pour revenir, haut / bas pour faire défiler
      def update_radar_inputs
        if Input.trigger?(:A) || Input.trigger?(:B)
          play_cancel_se
          close_pokenav
        elsif Input.repeat?(:UP) || Input.repeat?(:DOWN)
          play_cursor_se if @radar.scroll(Input.repeat?(:UP) ? -1 : 1)
        else
          return true
        end
        return false
      end

      # Radar ouvert : un clic (gauche ou droit) revient aux applis
      def update_radar_mouse
        if Mouse.trigger?(:LEFT) || Mouse.trigger?(:RIGHT)
          play_cancel_se
          close_pokenav
        end
        return false
      end
    end

    if UI::PokeSmart::ENABLED
      register_button(:open_pokenav) { UI::PokeSmart::POKENAV_APP } unless ACTION_LIST.include?(:open_pokenav)
    end
  end
end

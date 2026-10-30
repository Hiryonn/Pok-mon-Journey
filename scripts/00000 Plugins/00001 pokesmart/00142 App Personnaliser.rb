# PokeSmart : appli Personnaliser (coque, icônes, fond d'écran ; aperçu direct)
module GamePlay
  class Menu
    module SmartStyle
      public

      # Appli Personnaliser : rubriques Coque / Icônes / Fond d'écran
      def open_customization
        show_categories(0)
      end

      # Ferme l'appli Personnaliser
      def close_customization
        @picker&.dispose
        @picker = nil
        @buttons.each { |button| button.visible = true }
        update_buttons
      end

      private

      # Affiche une liste de choix à la place des applis
      # @param labels [Array<String>]
      # @param index [Integer]
      # @param title [String]
      def open_picker(labels, index, title)
        @picker&.dispose
        @picker = UI::PokeSmart::ListPicker.new(@viewport, @phone, labels, index)
        @buttons.each { |button| button.visible = false }
        @phone.title = title
      end

      # Liste des rubriques
      # @param index [Integer]
      def show_categories(index)
        @custom_category = nil
        labels = UI::PokeSmart::CUSTOM_CATEGORIES.values.map { |fr, en| UI::PokeSmart.french? ? fr : en }
        open_picker(labels, index, @buttons[@index]&.name)
      end

      # Choix d'une rubrique (la valeur actuelle est sélectionnée)
      # @param category [Symbol]
      def show_options(category)
        @custom_category = category
        @custom_before = UI::PokeSmart.setting(category)
        @custom_saved = UI::PokeSmart.settings[category]
        @custom_options = UI::PokeSmart.options(category)
        index = @custom_options.index { |value, _| value == @custom_before } || 0
        open_picker(@custom_options.map(&:last), index, category_title(category))
      end

      # @param category [Symbol]
      # @return [String]
      def category_title(category)
        fr, en = UI::PokeSmart::CUSTOM_CATEGORIES[category]
        return UI::PokeSmart.french? ? fr : en
      end

      # Aperçu direct du choix n° index
      # @param index [Integer]
      def preview_option(index)
        UI::PokeSmart.set_setting(@custom_category, @custom_options[index].first)
        rebuild_phone
        open_picker(@custom_options.map(&:last), index, category_title(@custom_category))
      end

      # Garde (ou annule) le choix et revient aux rubriques
      # @param keep [Boolean]
      def leave_options(keep)
        category = @custom_category
        unless keep
          UI::PokeSmart.set_setting(category, @custom_saved)
          rebuild_phone
        end
        show_categories(UI::PokeSmart::CUSTOM_CATEGORIES.keys.index(category))
      end

      # Recrée le téléphone et ses applis (nouvelle coque, icônes ou fond d'écran)
      def rebuild_phone
        @phone.dispose
        @buttons.each(&:dispose)
        create_buttons
        update_buttons
      end

      # Personnaliser : haut / bas pour choisir (aperçu direct pour les réglages), A pour valider, B pour revenir
      def update_picker_inputs
        if Input.repeat?(:UP) || Input.repeat?(:DOWN)
          target = (@picker.index + (Input.repeat?(:UP) ? -1 : 1)) % @picker.count
          return false if target == @picker.index

          play_cursor_se
          picker_select(target)
        elsif Input.repeat?(:LEFT) || Input.repeat?(:RIGHT)
          # gauche / droite : une page de la liste d'un coup (pratique pour les fonds d'écran)
          target = (@picker.index + (Input.repeat?(:LEFT) ? -@picker.page : @picker.page)).clamp(0, @picker.count - 1)
          return false if target == @picker.index

          play_cursor_se
          picker_select(target)
        elsif Input.trigger?(:A)
          play_decision_se
          picker_validate
        elsif Input.trigger?(:B)
          play_cancel_se
          picker_back
        else
          return true
        end
        return false
      end

      # Personnaliser à la souris : clic sur une ligne pour la valider, clic droit pour revenir
      def update_picker_mouse
        if Mouse.trigger?(:RIGHT)
          play_cancel_se
          picker_back
        elsif Mouse.trigger?(:LEFT) && (row = @picker.hovered_row)
          play_decision_se
          picker_select(row) if row != @picker.index
          picker_validate
        end
        return false
      end

      # @param index [Integer]
      def picker_select(index)
        if @custom_category
          preview_option(index)
        else
          show_categories(index)
        end
      end

      def picker_validate
        if @custom_category
          leave_options(true)
        else
          show_options(UI::PokeSmart::CUSTOM_CATEGORIES.keys[@picker.index])
        end
      end

      def picker_back
        if @custom_category
          leave_options(false)
        else
          close_customization
        end
      end
    end

    if UI::PokeSmart::ENABLED
      register_button(:open_customization) { UI::PokeSmart::CUSTOMIZATION_APP } unless ACTION_LIST.include?(:open_customization)
    end
  end
end

# PokeSmart : appli Personnaliser (coque, icônes appli par appli, fond d'écran ; aperçu direct)
#
# Écrans : rubriques → Coque / Fond d'écran : liste des choix (aperçu direct)
#                    → Icônes : liste des applis → variantes de l'icône de l'appli (aperçu direct)
# Haut / bas : choisir ; gauche / droite : une page ; A : valider ; B : annuler / revenir
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
        @custom_level = nil
        show_home_buttons
        update_buttons
      end

      private

      # Affiche une liste de choix à la place des applis
      # @param labels [Array<String>]
      # @param index [Integer]
      # @param title [String]
      # @param icons [Array<String>, nil] icône au début de chaque ligne
      def open_picker(labels, index, title, icons = nil)
        @picker&.dispose
        @picker = UI::PokeSmart::ListPicker.new(@viewport, @phone, labels, index, icons)
        hide_home_buttons
        @phone.title = title
      end

      # Recrée le téléphone et ses applis (nouvelle coque, icône ou fond d'écran)
      def rebuild_phone
        @phone.dispose
        @buttons.each(&:dispose)
        create_buttons
        update_buttons
      end

      # @param category [Symbol]
      # @return [String]
      def category_title(category)
        fr, en = UI::PokeSmart::CUSTOM_CATEGORIES[category]
        return UI::PokeSmart.french? ? fr : en
      end

      # --- Rubriques ---------------------------------------------------------------------------

      # @param index [Integer]
      def show_categories(index)
        @custom_level = :categories
        labels = UI::PokeSmart::CUSTOM_CATEGORIES.keys.map { |category| category_title(category) }
        open_picker(labels, index, @buttons[@index]&.name)
      end

      # @param category [Symbol]
      def back_to_category(category)
        show_categories(UI::PokeSmart::CUSTOM_CATEGORIES.keys.index(category) || 0)
      end

      # --- Coque / Fond d'écran ----------------------------------------------------------------

      # Choix d'une rubrique (la valeur actuelle est sélectionnée)
      # @param category [Symbol] :case ou :wallpaper
      def show_options(category)
        @custom_level = :options
        @custom_category = category
        @custom_saved = UI::PokeSmart.settings[category]
        @custom_options = UI::PokeSmart.options(category)
        current = UI::PokeSmart.setting(category)
        index = @custom_options.index { |value, _| value == current } || 0
        open_picker(@custom_options.map(&:last), index, category_title(category))
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
        unless keep
          UI::PokeSmart.set_setting(@custom_category, @custom_saved)
          rebuild_phone
        end
        back_to_category(@custom_category)
      end

      # --- Icônes ------------------------------------------------------------------------------

      # Liste des applis du téléphone qui ont plusieurs icônes
      # @param index [Integer]
      def show_icon_apps(index)
        @custom_level = :icon_apps
        ps = UI::PokeSmart
        buttons = @buttons.select { |button| ps.icon_variants(ps.app_base_icon(button.action)).size > 1 }
        @icon_apps = buttons.map(&:action)
        if buttons.empty?
          open_picker([ps.french? ? 'Aucune variante' : 'No variant'], 0, category_title(:icons))
        else
          open_picker(buttons.map(&:name), index, category_title(:icons), @icon_apps.map { |action| ps.app_icon(action) })
        end
      end

      # Variantes de l'icône d'une appli (celle utilisée est sélectionnée)
      # @param action [Symbol]
      def show_icon_variants(action)
        @custom_level = :icon_variants
        @icon_action = action
        @icon_saved = UI::PokeSmart.icon_choices[action]
        @icon_list = UI::PokeSmart.icon_variants(UI::PokeSmart.app_base_icon(action))
        open_icon_variants(@icon_list.index(UI::PokeSmart.icon_variant(action)) || 0)
      end

      # @param index [Integer]
      def open_icon_variants(index)
        ps = UI::PokeSmart
        title = @buttons.find { |button| button.action == @icon_action }&.name
        open_picker(@icon_list.map { |variant| ps.icon_variant_label(variant, @icon_action) }, index, title,
                    @icon_list.map { |variant| ps.app_icon(@icon_action, variant) })
      end

      # Aperçu direct de la variante n° index
      # @param index [Integer]
      def preview_icon(index)
        UI::PokeSmart.set_icon_variant(@icon_action, @icon_list[index])
        rebuild_phone
        open_icon_variants(index)
      end

      # Garde (ou annule) la variante et revient à la liste des applis
      # @param keep [Boolean]
      def leave_icon_variants(keep)
        unless keep
          UI::PokeSmart.set_icon_variant(@icon_action, @icon_saved)
          rebuild_phone
        end
        show_icon_apps(@icon_apps.index(@icon_action) || 0)
      end

      # --- Touches et souris -------------------------------------------------------------------

      # Haut / bas pour choisir, gauche / droite pour changer de page, A pour valider, B pour revenir
      def update_picker_inputs
        if Input.repeat?(:UP) || Input.repeat?(:DOWN)
          target = (@picker.index + (Input.repeat?(:UP) ? -1 : 1)) % @picker.count
          return false if target == @picker.index

          play_cursor_se
          picker_select(target)
        elsif Input.repeat?(:LEFT) || Input.repeat?(:RIGHT)
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

      # Clic sur une ligne pour la valider, clic droit pour revenir
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

      # Déplacement dans la liste (aperçu direct pour les réglages)
      # @param index [Integer]
      def picker_select(index)
        case @custom_level
        when :options then preview_option(index)
        when :icon_apps then show_icon_apps(index)
        when :icon_variants then preview_icon(index)
        else show_categories(index)
        end
      end

      # A : entrer dans la ligne choisie, ou garder le réglage
      def picker_validate
        case @custom_level
        when :options then leave_options(true)
        when :icon_apps then show_icon_variants(@icon_apps[@picker.index]) unless @icon_apps.empty?
        when :icon_variants then leave_icon_variants(true)
        else
          category = UI::PokeSmart::CUSTOM_CATEGORIES.keys[@picker.index]
          category == :icons ? show_icon_apps(0) : show_options(category)
        end
      end

      # B : annuler le réglage, ou revenir à l'écran d'avant
      def picker_back
        case @custom_level
        when :options then leave_options(false)
        when :icon_apps then back_to_category(:icons)
        when :icon_variants then leave_icon_variants(false)
        else close_customization
        end
      end
    end

    if UI::PokeSmart::ENABLED
      register_button(:open_customization) { UI::PokeSmart::CUSTOMIZATION_APP } unless ACTION_LIST.include?(:open_customization)
    end
  end
end

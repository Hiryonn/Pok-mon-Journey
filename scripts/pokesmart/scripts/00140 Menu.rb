# PokeSmart : le menu de PSDK habillé en téléphone (la logique de PSDK reste inchangée : mêmes actions, mêmes scènes)
module GamePlay
  class Menu
    module SmartStyle
      public

      # Déplacement en grille (gauche / droite = appli voisine ou page voisine au bord, haut / bas = ligne,
      # L / R = page précédente / suivante)
      def update_inputs
        return false if @entering || @quiting
        return update_radar_inputs if @radar
        return update_camera_inputs if @camera
        return update_friends_inputs if @friends_mode
        return update_picker_inputs if @picker

        target = nil
        target = horizontal_target(-1) if Input.repeat?(:LEFT)
        target = horizontal_target(1) if Input.repeat?(:RIGHT)
        target = page_target(current_page - 1) if Input.trigger?(:L)
        target = page_target(current_page + 1) if Input.trigger?(:R)
        target = vertical_target(-1) if Input.repeat?(:UP)
        target = vertical_target(1) if Input.repeat?(:DOWN)
        if target
          if target.between?(0, @max_index) && target != @index
            @index = target
            play_cursor_se
            update_buttons
          end
          return false
        end
        if Input.trigger?(:A)
          action
        elsif Input.trigger?(:B)
          @quiting = true
        else
          return true
        end
        return false
      end

      # Décale le téléphone et ses applis vers le bas (0 = en place)
      # @param offset [Numeric]
      def phone_slide=(offset)
        delta = offset.to_i - (@phone_slide || 0)
        @phone_slide = offset.to_i
        return if delta == 0

        @phone.move(0, delta)
        @buttons.each { |button| button.move(0, delta) }
      end

      # Le bouton rond du bas range le téléphone
      def update_mouse(moved)
        return false if @entering || @quiting

        return update_picker_mouse if @picker
        return update_radar_mouse if @radar
        return update_camera_mouse if @camera
        return update_friends_mouse if @friends_mode

        if Mouse.trigger?(:LEFT) && @phone.home_button_hovered?
          play_cancel_se
          @quiting = true
          return false
        end
        if Mouse.trigger?(:LEFT) && (page = @phone.hovered_page)
          go_to_page(page)
          return false
        end
        return update_home_mouse(moved)
      end

      # @return [Integer] page de l'écran d'accueil affichée
      def current_page
        return @index / UI::PokeSmart::APPS_PER_PAGE
      end

      # @return [Integer] nombre de pages de l'écran d'accueil
      def page_count
        return [(@buttons.size + UI::PokeSmart::APPS_PER_PAGE - 1) / UI::PokeSmart::APPS_PER_PAGE, 1].max
      end

      # Affiche les applis de la page en cours (et les points des pages)
      def show_home_buttons
        page = current_page
        per_page = UI::PokeSmart::APPS_PER_PAGE
        @buttons.each_with_index { |button, i| button.visible = i / per_page == page }
        @phone.pages_visible = true
        @phone.set_pages(page_count, page)
        @shown_page = page
      end

      # Cache les applis et les points des pages (une appli prend l'écran)
      def hide_home_buttons
        @buttons.each { |button| button.visible = false }
        @phone.pages_visible = false
        @shown_page = nil
      end

      # @return [Boolean] si l'écran d'accueil (les applis) est affiché
      def home_open?
        return !(@picker || @radar || @camera || @friends_mode)
      end

      def update_graphics
        super
        @phone.update
        @radar&.update
        @camera&.update
      end

      # Pendant la sauvegarde PSDK ne cache que les boutons : le téléphone suit
      def visible=(value)
        super
        return unless @in_save

        @phone.visible = value
        show_home_buttons if value && home_open?
      end

      private

      # Appli de la ligne au-dessus / en dessous (sur la même page), la plus proche en colonne
      # @param direction [Integer] -1 ou 1
      # @return [Integer, nil]
      def vertical_target(direction)
        row, col = @buttons[@index].grid
        page = current_page
        per_page = UI::PokeSmart::APPS_PER_PAGE
        candidates = @buttons.each_index.select { |i| i / per_page == page && @buttons[i].grid[0] == row + direction }
        return candidates.min_by { |i| [(@buttons[i].grid[1] - col).abs, i] }
      end

      # Appli voisine ; au bord de la page, même ligne sur la page voisine
      # @param direction [Integer] -1 ou 1
      # @return [Integer, nil]
      def horizontal_target(direction)
        row, col = @buttons[@index].grid
        last_col = UI::PokeSmart::COLUMNS - 1
        next_index = @index + direction
        on_edge = direction > 0 ? col == last_col || next_index > @max_index : col == 0
        return next_index unless on_edge

        page = current_page + direction
        return nil unless page.between?(0, page_count - 1)

        per_page = UI::PokeSmart::APPS_PER_PAGE
        target = page * per_page + row * UI::PokeSmart::COLUMNS + (direction > 0 ? 0 : last_col)
        return target.clamp(page * per_page, [page * per_page + per_page - 1, @max_index].min)
      end

      # Première appli d'une page
      # @param page [Integer]
      # @return [Integer, nil]
      def page_target(page)
        return page.between?(0, page_count - 1) ? page * UI::PokeSmart::APPS_PER_PAGE : nil
      end

      # Change de page (souris)
      # @param page [Integer]
      def go_to_page(page)
        return if page == current_page || !(target = page_target(page))

        @index = target
        play_cursor_se
        update_buttons
      end

      # Souris sur les applis de la page affichée (celles des autres pages sont cachées)
      def update_home_mouse(moved)
        per_page = UI::PokeSmart::APPS_PER_PAGE
        page = current_page
        @buttons.each_with_index do |button, index|
          next unless index / per_page == page && button.simple_mouse_in?

          if moved
            if @index != index
              @index = index
              update_buttons
              play_cursor_se
            end
          elsif Mouse.trigger?(:LEFT)
            @index = index
            update_buttons
            play_decision_se
            action
          end
          return false
        end
        return true
      end

      # « Quitter » devient le bouton rond du téléphone (et la touche B)
      def init_indexes
        super
        quit_index = ACTION_LIST.index(:open_quit)
        @image_indexes.delete(quit_index) if quit_index && @image_indexes.size > 1
        ps = UI::PokeSmart
        hidden = ps.studio_hidden_apps
        @image_indexes.reject! { |real_index| hidden.include?(ACTION_LIST[real_index]) } if @image_indexes.size > hidden.size
        studio_order = ps.studio_app_order
        order = ps::APP_ICONS.keys
        last = ps::LAST_APPS
        unlisted_at = (last.map { |action| studio_order.index(action) }.compact.min || studio_order.size) - 0.5
        @image_indexes = @image_indexes.each_with_index.sort_by do |real_index, i|
          action = ACTION_LIST[real_index]
          if studio_order.empty?
            # applis rangées dans l'ordre de APP_ICONS (les inconnues ensuite), puis LAST_APPS (Sauvegarde, Options)
            [last.index(action) || -1, order.index(action) || order.size, i]
          else
            # ordre choisi dans Studio ; les applis absentes de la liste juste avant Sauvegarde / Options
            [studio_order.index(action) || unlisted_at, order.index(action) || order.size, i]
          end
        end.map(&:first)
      end

      # Applis en grille (APPS_PER_PAGE par page, toutes les pages au même endroit de l'écran)
      def create_buttons
        ps = UI::PokeSmart
        ps::Friends.deliver if defined?(ps::Friends)
        @phone = ps::Phone.new(@viewport)
        gx, gy = @phone.theme[:grid]
        cx, cy = @phone.theme[:cell]
        @buttons = @image_indexes.map.with_index do |real_index, i|
          slot = i % ps::APPS_PER_PAGE
          col = slot % ps::COLUMNS
          row = slot / ps::COLUMNS
          button = ps::AppButton.new(@viewport, real_index, @phone.x + gx + col * cx, @phone.y + gy + row * cy)
          button.grid = [row, col]
          next button
        end
        @max_index = @buttons.size - 1
        @index = @index.clamp(0, [@max_index, 0].max)
        home_open? ? show_home_buttons : hide_home_buttons
      end

      def update_buttons
        super
        show_home_buttons if home_open? && @shown_page != current_page
        @phone.title = @buttons[@index]&.name
      end

      def init_entering
        self.phone_slide = UI::PokeSmart::SLIDE_OFFSET
      end

      def create_entering_animation
        ya = Yuki::Animation
        slide = ya.scalar(UI::PokeSmart::SLIDE_DURATION, self, :phone_slide=, UI::PokeSmart::SLIDE_OFFSET, 0)
        return ya.parallel(ya.opacity_change(UI::PokeSmart::SLIDE_DURATION, @background, 0, 255), slide).start
      end

      def create_quitting_animation
        @__last_scene.spriteset.visible = true if @__last_scene.is_a?(Scene_Map) && !@animation
        @buttons.each { |button| button.selected = false }
        ya = Yuki::Animation
        slide = ya.scalar(UI::PokeSmart::SLIDE_DURATION, self, :phone_slide=, 0, UI::PokeSmart::SLIDE_OFFSET)
        return ya.parallel(ya.opacity_change(UI::PokeSmart::SLIDE_DURATION, @background, 255, 0), slide).start
      end
    end

    if UI::PokeSmart::ENABLED
      prepend SmartStyle
    end
  end
end

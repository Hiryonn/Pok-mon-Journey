# PokeSmart : le menu de PSDK habillé en téléphone (la logique de PSDK reste inchangée : mêmes actions, mêmes scènes)
module GamePlay
  class Menu
    module SmartStyle
      public

      # Déplacement en grille (gauche / droite = appli voisine ou page voisine au bord, haut / bas = ligne,
      # bas depuis la dernière ligne = barre du bas, L / R = page précédente / suivante)
      def update_inputs
        return false if @entering || @quiting
        return update_radar_inputs if @radar
        return update_camera_inputs if @camera
        return update_friends_inputs if @friends_mode
        return update_picker_inputs if @picker

        if Input.trigger?(:L) || Input.trigger?(:R)
          go_to_page(current_page + (Input.trigger?(:L) ? -1 : 1))
          return false
        end
        target = nil
        target = horizontal_target(-1) if Input.repeat?(:LEFT)
        target = horizontal_target(1) if Input.repeat?(:RIGHT)
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
        return @page ||= 0
      end

      # @return [Integer] nombre de pages de l'écran d'accueil (sans la barre du bas)
      def page_count
        per_page = UI::PokeSmart::APPS_PER_PAGE
        return [(dock_start + per_page - 1) / per_page, 1].max
      end

      # @return [Integer] index de la première appli de la barre du bas (= nombre d'applis des pages)
      def dock_start
        return @dock_start || @buttons.size
      end

      # @param index [Integer]
      # @return [Boolean] si l'appli est dans la barre du bas (visible sur toutes les pages)
      def dock?(index)
        return index >= dock_start
      end

      # @param index [Integer]
      # @return [Integer, nil] page de l'appli (nil pour la barre du bas)
      def page_of(index)
        return dock?(index) ? nil : index / UI::PokeSmart::APPS_PER_PAGE
      end

      # @param page [Integer]
      # @return [Array<Integer>] applis d'une page
      def page_indexes(page)
        per_page = UI::PokeSmart::APPS_PER_PAGE
        return (page * per_page...[page * per_page + per_page, dock_start].min).to_a
      end

      # Affiche les applis de la page en cours, la barre du bas et les points des pages
      def show_home_buttons
        page = page_of(@index)
        @page = page if page
        @page = current_page.clamp(0, page_count - 1)
        @buttons.each_with_index { |button, i| button.visible = dock?(i) || page_of(i) == @page }
        @phone.pages_visible = true
        @phone.set_pages(page_count, @page)
        @phone.dock_visible = dock_start < @buttons.size && dock_start > 0
        @shown_page = @page
      end

      # Cache les applis, la barre du bas et les points des pages (une appli prend l'écran)
      def hide_home_buttons
        @buttons.each { |button| button.visible = false }
        @phone.pages_visible = false
        @phone.dock_visible = false
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

      # Appli de la ligne au-dessus / en dessous (sur la même page), la plus proche en colonne ;
      # sous la dernière ligne : la barre du bas, au-dessus de la barre du bas : la dernière ligne de la page
      # @param direction [Integer] -1 ou 1
      # @return [Integer, nil]
      def vertical_target(direction)
        row, col = @buttons[@index].grid
        if dock?(@index)
          return nil if direction > 0

          candidates = page_indexes(current_page)
          last_row = candidates.map { |i| @buttons[i].grid[0] }.max
          candidates = candidates.select { |i| @buttons[i].grid[0] == last_row }
        else
          candidates = page_indexes(current_page).select { |i| @buttons[i].grid[0] == row + direction }
          candidates = (dock_start..@max_index).to_a if candidates.empty? && direction > 0
        end
        return candidates.min_by { |i| [(@buttons[i].grid[1] - col).abs, i] }
      end

      # Appli voisine ; au bord de la page, même ligne sur la page voisine (la barre du bas ne change pas de page)
      # @param direction [Integer] -1 ou 1
      # @return [Integer, nil]
      def horizontal_target(direction)
        next_index = @index + direction
        return next_index.between?(dock_start, @max_index) ? next_index : nil if dock?(@index)

        row, col = @buttons[@index].grid
        last_col = UI::PokeSmart::COLUMNS - 1
        on_edge = direction > 0 ? col == last_col || next_index >= dock_start : col == 0
        return next_index unless on_edge

        page = current_page + direction
        return nil unless page.between?(0, page_count - 1)

        slots = page_indexes(page)
        target = slots.first + row * UI::PokeSmart::COLUMNS + (direction > 0 ? 0 : last_col)
        return target.clamp(slots.first, slots.last)
      end

      # Change de page (L / R, clic sur un point) ; dans la barre du bas, la sélection y reste
      # @param page [Integer]
      def go_to_page(page)
        return unless page.between?(0, page_count - 1) && page != current_page

        @page = page
        @index = page_indexes(page).first unless dock?(@index)
        play_cursor_se
        update_buttons
      end

      # Souris sur les applis de la page affichée (celles des autres pages sont cachées)
      def update_home_mouse(moved)
        page = current_page
        @buttons.each_with_index do |button, index|
          next unless (dock?(index) || page_of(index) == page) && button.simple_mouse_in?

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
        # applis « par une commande » pas encore débloquées (on en garde au moins une)
        unlocked = @image_indexes.select { |real_index| ps.app_unlocked?(ACTION_LIST[real_index]) }
        @image_indexes = unlocked unless unlocked.empty?
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

      # Applis en grille : APPS_PER_PAGE par page (toutes les pages au même endroit de l'écran),
      # puis les DOCK_APPS dernières dans la barre du bas, sous le séparateur (visibles sur toutes les pages)
      def create_buttons
        ps = UI::PokeSmart
        ps::Friends.deliver if defined?(ps::Friends)
        @phone = ps::Phone.new(@viewport)
        gx, gy = @phone.theme[:grid]
        cx, cy = @phone.theme[:cell]
        dock_y = ps.home_layout(@phone.theme)[:dock]
        dock_count = [ps::DOCK_APPS, ps::COLUMNS, @image_indexes.size - 1].min.clamp(0, ps::COLUMNS)
        @dock_start = @image_indexes.size - dock_count
        dock_row = ps::APPS_PER_PAGE / ps::COLUMNS
        @buttons = @image_indexes.map.with_index do |real_index, i|
          if i >= @dock_start
            col = i - @dock_start + (ps::COLUMNS - dock_count) / 2
            button = ps::AppButton.new(@viewport, real_index, @phone.x + gx + col * cx, @phone.y + dock_y)
            button.grid = [dock_row, col]
            next button
          end
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
        if home_open?
          page = page_of(@index)
          @page = page if page
          show_home_buttons if @shown_page != current_page
        end
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

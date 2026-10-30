# PokeSmart : le menu de PSDK habillé en téléphone (la logique de PSDK reste inchangée : mêmes actions, mêmes scènes)
module GamePlay
  class Menu
    module SmartStyle
      public

      # Déplacement en grille (gauche / droite = appli voisine, haut / bas = ligne)
      def update_inputs
        return false if @entering || @quiting
        return update_radar_inputs if @radar
        return update_camera_inputs if @camera
        return update_picker_inputs if @picker

        target = nil
        target = @index - 1 if Input.repeat?(:LEFT)
        target = @index + 1 if Input.repeat?(:RIGHT)
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

        if Mouse.trigger?(:LEFT) && @phone.home_button_hovered?
          play_cancel_se
          @quiting = true
          return false
        end
        return super
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
        @phone.visible = value if @in_save
      end

      private

      # Appli de la ligne au-dessus / en dessous, la plus proche en colonne
      # @param direction [Integer] -1 ou 1
      # @return [Integer, nil]
      def vertical_target(direction)
        row, col = @buttons[@index].grid
        candidates = @buttons.each_index.select { |i| @buttons[i].grid[0] == row + direction }
        return candidates.min_by { |i| [(@buttons[i].grid[1] - col).abs, i] }
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

      # Applis en grille, dans l'ordre de APP_ICONS (les inconnues à la fin)
      def create_buttons
        ps = UI::PokeSmart
        @phone = ps::Phone.new(@viewport)
        gx, gy = @phone.theme[:grid]
        cx, cy = @phone.theme[:cell]
        @buttons = @image_indexes.map.with_index do |real_index, i|
          col = i % ps::COLUMNS
          row = i / ps::COLUMNS
          button = ps::AppButton.new(@viewport, real_index, @phone.x + gx + col * cx, @phone.y + gy + row * cy)
          button.grid = [row, col]
          next button
        end
        @max_index = @buttons.size - 1
        @index = @index.clamp(0, @max_index)
      end

      def update_buttons
        super
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

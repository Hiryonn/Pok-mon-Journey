# Résumé PE : page Rubans
module UI
  module SummaryPE
    # Ruban avec les sélecteurs du design (blanc = curseur, or = ruban qui donne le titre)
    class RibbonIcon < RibbonSprite
      private

      def create_sprites
        @ribbon = add_sprite(0, 0, NO_INITIAL_IMAGE)
        @selector = add_sprite(0, 0, SummaryPE.file('ribbon_selector'))
        @title_selector = add_sprite(0, 0, SummaryPE.file('ribbon_title'))
      end
    end

    # Page 4 : rubans, au style de la page Mémo
    class RibbonsPage < Summary_Ribbons
      # Grille des rubans dans la bande sombre de droite
      GRID_X = 140
      GRID_Y = 84
      RIBBON_ROWS = 2
      # Zone de texte dans le cadre gris
      INFO_X = 10
      INFO_Y = 54
      INFO_WIDTH = 100
      LINE_HEIGHT = 16

      # Garde le ruban sélectionné visible dans la grille de 2 lignes
      def adjust_offset
        return if @ribbon_index.negative?

        if @ribbon_index >= @offset + COLUMNS * RIBBON_ROWS
          @offset += COLUMNS
        elsif @ribbon_index < @offset
          @offset = [@offset - COLUMNS, 0].max
        end
      end

      def update_ribbons
        super
        refresh_face
      end

      # Animation du sprite du Pokémon
      def update_face
        @face&.update
      end

      private

      def init_sprites
        add_sprite(0, 0, SummaryPE.file('page_memo'))
        add_text(146, 64, 168, 16, SummaryPE.label(:ribbons), color: WHITE)
        RIBBON_ROWS.times do |row|
          COLUMNS.times do |col|
            @ribbon_sprites << add_sprite(GRID_X + col * SPACING_X, GRID_Y + row * SPACING_Y, NO_INITIAL_IMAGE, type: RibbonIcon)
          end
        end
        @name_text = add_text(INFO_X, INFO_Y, INFO_WIDTH, 16, '', color: DARK)
        @name_text.bold = true
        @description_text = add_text(INFO_X, INFO_Y, INFO_WIDTH, 16, '', color: DARK)
        @title_text = add_text(INFO_X, INFO_Y, INFO_WIDTH, 16, '', color: DARK)
        @no_ribbon_text = add_text(146, 112, 168, 16, text_get(74, 52), 1, color: WHITE)
      end

      # Nom, description et titre du ruban sélectionné, empilés dans le cadre gris
      def update_description
        return if @data.nil?

        texts = [@name_text, @description_text, @title_text]
        if @data.ribbons.empty? || @ribbon_index.negative?
          texts.each { |text| text.text = '' }
          return
        end

        ribbon = @data.ribbons[@ribbon_index]
        title = "#{text_get(74, 53)} #{ribbon.title.empty? ? text_get(74, 54) : build_title(ribbon)}"
        y = INFO_Y
        [ribbon.name, ribbon.description, title].each_with_index do |content, i|
          text = texts[i]
          text.y = y - Text::Util::FOY
          text.multiline_text = content.to_s
          y += LINE_HEIGHT * (text.text.count("\n") + 1) + 4
        end
      end

      # Le sprite laisse la place à la description quand un ruban est sélectionné
      def refresh_face
        return unless @face

        @face.visible = visible && @ribbon_index.negative? ? true : false
      end
    end
  end
end

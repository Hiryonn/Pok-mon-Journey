# Résumé PE : page Insignes (plugin insignes)
module UI
  module SummaryPE
    # Page 6 : les insignes du Pokémon, au style de la page Rubans (grille à droite, nom et description à gauche)
    class InsignesPage < SpriteStack
      # Grille dans la bande sombre : 5 colonnes, 3 lignes visibles de médailles de 32x32
      GRID_X = 137
      GRID_Y = 86
      COLUMNS = 5
      ROWS = 3
      SPACING_X = 36
      SPACING_Y = 36
      # Le curseur (40x40) déborde de 4 pixels autour de l'insigne
      CURSOR_MARGIN = 4
      # Zone de texte dans le cadre gris
      INFO_X = 10
      INFO_Y = 54
      INFO_WIDTH = 100
      LINE_HEIGHT = 16
      # Pied du sprite du Pokémon (cadre gris)
      FACE_POSITION = [60, 205]

      # @return [Boolean] le joueur choisit un insigne (curseur visible)
      attr_reader :selecting

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 0, default_cache: :interface)
        add_sprite(0, 0, SummaryPE.file('page_memo'))
        @title = add_text(146, 64, 168, 16, '', color: WHITE)
        @face = add_sprite(*FACE_POSITION, NO_INITIAL_IMAGE, type: PokemonFaceSprite)
        @slots = Array.new(COLUMNS * ROWS) do |i|
          add_sprite(GRID_X + (i % COLUMNS) * SPACING_X, GRID_Y + (i / COLUMNS) * SPACING_Y, NO_INITIAL_IMAGE)
        end
        @cursor = add_sprite(0, 0, SummaryPE.file('ribbon_selector'))
        @name_text = add_text(INFO_X, INFO_Y, INFO_WIDTH, 16, '', color: DARK)
        @name_text.bold = true
        @description_text = add_text(INFO_X, INFO_Y, INFO_WIDTH, 16, '', color: DARK)
        @empty_text = add_text(146, 112, 168, 16, SummaryPE.label(:no_insignes), 1, color: WHITE)
        @ids = []
        @offset = 0
        @index = -1
        @selecting = false
      end

      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        @data = pokemon
        @ids = defined?(::Insignes) && pokemon ? ::Insignes.of(pokemon) : []
        @ids = [] if pokemon&.egg?
        @face.data = pokemon if pokemon
        @offset = 0
        stop_selecting
      end

      # Animation du sprite du Pokémon
      def update_face
        @face.update if visible
      end

      # @param value [Boolean]
      def visible=(value)
        super
        refresh if value && @slots
      end

      # @return [Boolean] la sélection a commencé (faux s'il n'y a aucun insigne)
      def start_selecting
        return false if @ids.empty?

        @selecting = true
        @index = 0
        @offset = 0
        refresh
        return true
      end

      def stop_selecting
        @selecting = false
        @index = -1
        refresh
      end

      # Déplace le curseur dans la grille (les lignes défilent au besoin)
      # @param dx [Integer]
      # @param dy [Integer]
      # @return [Boolean] le curseur a bougé
      def move(dx, dy)
        return false unless @selecting

        target = (@index + dx + dy * COLUMNS).clamp(0, @ids.size - 1)
        # à droite et à gauche, on ne change pas de ligne
        target = @index if dx != 0 && target / COLUMNS != @index / COLUMNS
        return false if target == @index

        @index = target
        @offset += COLUMNS while @index >= @offset + COLUMNS * ROWS
        @offset -= COLUMNS while @index < @offset
        refresh
        return true
      end

      private

      def refresh
        @title.text = "#{SummaryPE.label(:insignes)} (#{@ids.size})"
        @empty_text.visible = @ids.empty?
        @slots.each_with_index do |sprite, i|
          id = @ids[@offset + i]
          sprite.visible = id ? true : false
          sprite.set_bitmap(::Insignes.image(id), :interface) if id
        end
        refresh_cursor
        refresh_info
      end

      def refresh_cursor
        @cursor.visible = @selecting
        return unless @selecting

        slot = @index - @offset
        @cursor.set_position(GRID_X + (slot % COLUMNS) * SPACING_X - CURSOR_MARGIN, GRID_Y + (slot / COLUMNS) * SPACING_Y - CURSOR_MARGIN)
      end

      # Nom et description de l'insigne choisi dans le cadre gris, sinon le sprite du Pokémon
      def refresh_info
        @face.visible = !@selecting
        texts = [@name_text, @description_text]
        id = @selecting ? @ids[@index] : nil
        texts.each { |text| text.visible = id ? true : false }
        return unless id

        y = INFO_Y
        [::Insignes.name(id), ::Insignes.description(id)].each_with_index do |content, i|
          text = texts[i]
          text.y = y - Text::Util::FOY
          text.multiline_text = content.to_s
          y += LINE_HEIGHT * (text.text.count("\n") + 1) + 4
        end
      end
    end
  end
end

# PokeSmart : liste de choix de l'appli Personnaliser
module UI
  module PokeSmart
    # Liste de choix de l'appli Personnaliser (défile si elle dépasse de l'écran)
    class ListPicker < SpriteStack
      ROW_WIDTH = 92
      ROW_HEIGHT = 18
      ROW_SPACING = 22
      # @return [Integer] ligne sélectionnée
      attr_reader :index
      # @return [Integer] nombre de lignes
      attr_reader :count
      # @return [Integer] nombre de lignes visibles
      attr_reader :page

      # @param viewport [Viewport]
      # @param phone [Phone]
      # @param labels [Array<String>]
      # @param index [Integer]
      def initialize(viewport, phone, labels, index)
        theme = phone.theme
        sx, sy, sw, sh = theme[:screen]
        top = theme[:grid][1]
        super(viewport, phone.x + sx + (sw - ROW_WIDTH) / 2, phone.y + top, default_cache: :interface)
        @count = labels.size
        @index = index.clamp(0, [@count - 1, 0].max)
        visible = @page = [(sy + sh - top - 4) / ROW_SPACING, 1].max
        @first = (@index - visible + 1).clamp(0, [@count - visible, 0].max)
        labels[@first, visible].each_with_index do |label, i|
          add_sprite(0, i * ROW_SPACING, PokeSmart.file(@first + i == @index ? 'choice_selected' : 'choice'))
          add_text(0, i * ROW_SPACING + 2, ROW_WIDTH, ROW_HEIGHT - 2, label, 1, color: DARK)
        end
        @shown = [visible, @count - @first].min
      end

      # @return [Integer, nil] ligne sous la souris
      def hovered_row
        mx = Mouse.x - x
        my = Mouse.y - y
        return nil unless mx.between?(0, ROW_WIDTH - 1) && my >= 0

        row = my / ROW_SPACING
        return nil unless row < @shown && my % ROW_SPACING < ROW_HEIGHT

        return @first + row
      end
    end
  end
end

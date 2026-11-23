# Sac Horizon : image étirée en largeur (deux bords fixes + un milieu uniforme étiré)
module UI
  module BagHorizon
    class Wide
      # @param viewport [Viewport]
      # @param name [String] image dans graphics/interface/bag_horizon/
      # @param width [Integer] largeur voulue
      # @param cap_left [Integer] largeur du bord gauche conservé tel quel
      # @param cap_right [Integer] largeur du bord droit conservé tel quel
      def initialize(viewport, name, width, cap_left, cap_right)
        @left = Sprite.new(viewport).set_bitmap(BagHorizon.file(name), :interface)
        @mid = Sprite.new(viewport).set_bitmap(BagHorizon.file(name), :interface)
        @right = Sprite.new(viewport).set_bitmap(BagHorizon.file(name), :interface)
        source = @left.bitmap.width
        height = @left.bitmap.height
        @cap_left = cap_left
        @cap_right = cap_right
        @left.src_rect.set(0, 0, cap_left, height)
        @mid.src_rect.set(cap_left, 0, source - cap_left - cap_right, height)
        @right.src_rect.set(source - cap_right, 0, cap_right, height)
        @mid_source = source - cap_left - cap_right
        @width = width
        @x = 0
        @y = 0
        layout
      end

      # @return [Integer]
      attr_reader :width

      def set_position(x, y)
        @x = x
        @y = y
        layout
        return self
      end

      def width=(value)
        @width = value
        layout
      end

      def z=(value)
        [@left, @mid, @right].each { |sprite| sprite.z = value }
      end

      def visible=(value)
        [@left, @mid, @right].each { |sprite| sprite.visible = value }
      end

      # Ligne de l'image (images à plusieurs états empilés)
      def src_y=(value)
        [@left, @mid, @right].each { |sprite| sprite.src_rect.y = value }
      end

      def height
        return @left.bitmap.height
      end

      private

      def layout
        middle = [@width - @cap_left - @cap_right, 0].max
        @left.set_position(@x, @y)
        @mid.set_position(@x + @cap_left, @y)
        @mid.zoom_x = middle / @mid_source.to_f
        @right.set_position(@x + @cap_left + middle, @y)
      end
    end
  end
end

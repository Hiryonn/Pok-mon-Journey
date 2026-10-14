module UI
  # Aura of a Shadow Pokemon, the pattern of Pokemon XD scrolling inside its silhouette wherever the
  # creature is drawn. It is a layer of its own laid over the sprite rather than a shader on it, so
  # it never claims a shader slot the screen keeps for itself, and it composes with whatever that
  # sprite already wears, from the grey of the storage to the pulse of a boss.
  module ShadowAura
    # Pattern scrolling over the creature, under the animation folder
    PATTERN = 'shadow-aura/shadow_pattern'
    # Speed the pattern scrolls upward at, in pixels per second
    SPEED = 30
    # How much of the pattern shows over the creature, the 150 over 255 of the source
    OPACITY = 150 / 255.0

    # Layer carrying the pattern. It is kept on the sprite it dresses the way the battler keeps its
    # own drop shadow, by being told of every move rather than by guessing.
    class Layer < ShaderedSprite
      # Create a layer over a creature sprite
      # @param host [Sprite] sprite showing the creature
      # @param shader_id [Symbol] shader the layer wears
      def initialize(host, shader_id)
        super(host.viewport)
        @scroll = 0.0
        self.shader = Shader.create(shader_id)
        pattern = RPG::Cache.animation(PATTERN)
        shader.set_texture_uniform('patternTexture', pattern)
        shader.set_float_uniform('patternSize', [pattern.width, pattern.height])
        shader.set_float_uniform('patternOpacity', OPACITY)
      end

      # Scroll the pattern. The offset grows in pixels per second, so the speed never depends on the
      # frame rate, unlike the source it comes from.
      def update
        @scroll += SPEED * Graphics.delta
        shader.set_float_uniform('patternOrigin', [0, @scroll])
      end

      # Tell the shader how big the creature is drawn, the pattern being tiled in its pixels
      # @param rect [Rect] source rectangle of the creature sprite
      def creature_rect=(rect)
        src_rect.set(rect.x, rect.y, rect.width, rect.height)
        shader.set_float_uniform('spriteSize', [rect.width, rect.height])
      end

      # Give the layer the depth the camera projects the creature at, in a 3D battle
      # @param depth [Float]
      def camera_depth=(depth)
        shader.set_float_uniform('z', depth)
      end
    end

    # Update the sprite
    def update
      super
      @shadow_aura_layer&.update
    end

    # Dispose the sprite
    def dispose
      dispose_shadow_aura
      super
    end

    # Put the aura on the creature, or take it off, whichever the creature calls for
    # @param creature [PFM::Pokemon, nil]
    def refresh_shadow_aura(creature)
      return dispose_shadow_aura unless creature&.shadow?

      @shadow_aura_layer ||= Layer.new(self, shadow_aura_shader_id)
      sync_shadow_aura
    end

    # Take the aura off, doing nothing when the creature never wore one
    def dispose_shadow_aura
      return unless @shadow_aura_layer

      @shadow_aura_layer.dispose
      @shadow_aura_layer = nil
    end

    # Hand the layer everything the sprite wears. Called whenever the creature or its texture
    # changes, the setters below keeping the two together the rest of the time.
    def sync_shadow_aura
      layer = @shadow_aura_layer
      return unless layer

      # The texture is handed over here rather than through bitmap=, which would give the sprite
      # itself a texture it already wears.
      layer.bitmap = bitmap
      layer.creature_rect = src_rect
      set_position(x, y)
      set_origin(ox, oy)
      self.zoom_x = zoom_x
      self.zoom_y = zoom_y
      self.mirror = mirror
      self.opacity = opacity
      self.visible = visible
      self.z = z
    end

    # Set the x position of the sprite
    # @param value [Numeric]
    def x=(value)
      super
      @shadow_aura_layer&.x = value
    end

    # Set the y position of the sprite
    # @param value [Numeric]
    def y=(value)
      super
      @shadow_aura_layer&.y = value
    end

    # Set the z of the sprite
    # @param value [Numeric]
    def z=(value)
      super
      # The layer shares the depth of its creature and is born after it, which is what puts it on
      # top: LiteRGSS rounds a sprite depth to an integer and breaks a tie by the order of creation
      @shadow_aura_layer&.z = value
    end

    # Define the position of the sprite
    # @param x [Numeric]
    # @param y [Numeric]
    # @return [self]
    def set_position(x, y)
      result = super
      @shadow_aura_layer&.set_position(x, y)
      return result
    end

    # Define the origin of the sprite (inside the texture)
    # @param ox [Numeric]
    # @param oy [Numeric]
    # @return [self]
    def set_origin(ox, oy)
      result = super
      @shadow_aura_layer&.set_origin(ox, oy)
      return result
    end

    # Set the ox of the sprite
    # @param value [Numeric]
    def ox=(value)
      super
      @shadow_aura_layer&.ox = value
    end

    # Set the oy of the sprite
    # @param value [Numeric]
    def oy=(value)
      super
      @shadow_aura_layer&.oy = value
    end

    # Set the zoom of the sprite
    # @param value [Numeric]
    def zoom=(value)
      super
      return unless @shadow_aura_layer

      @shadow_aura_layer.zoom_x = value
      @shadow_aura_layer.zoom_y = value
    end

    # Set the zoom_x of the sprite
    # @param value [Numeric]
    def zoom_x=(value)
      super
      @shadow_aura_layer&.zoom_x = value
    end

    # Set the zoom_y of the sprite
    # @param value [Numeric]
    def zoom_y=(value)
      super
      @shadow_aura_layer&.zoom_y = value
    end

    # Set the mirror of the sprite
    # @param value [Boolean]
    def mirror=(value)
      super
      @shadow_aura_layer&.mirror = value
    end

    # Set the opacity of the sprite
    # @param value [Integer]
    def opacity=(value)
      super
      @shadow_aura_layer&.opacity = value
    end

    # Set the visibility of the sprite
    # @param value [Boolean]
    def visible=(value)
      super
      @shadow_aura_layer&.visible = visible
    end

    # Set the bitmap of the sprite
    # @param value [Texture]
    def bitmap=(value)
      super
      return unless @shadow_aura_layer

      @shadow_aura_layer.bitmap = value
      @shadow_aura_layer.creature_rect = src_rect
    end

    private

    # Shader the layer wears. Only a creature the camera projects wants the 3D one, the summary and
    # the storage drawing their creature flat.
    # @return [Symbol]
    def shadow_aura_shader_id
      return :shadow_aura
    end
  end
end

Shader.register(:shadow_aura, 'graphics/shaders/shadow_aura.frag', alpha_process: true)
Shader.register(:shadow_aura_3d, 'graphics/shaders/shadow_aura.frag', 'graphics/shaders/fake_3d.vert',
                alpha_process: true)

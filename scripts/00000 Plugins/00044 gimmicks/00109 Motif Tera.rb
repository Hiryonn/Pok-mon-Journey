# Gimmicks : motif des Pokémon Téracristallisés (graphics/interface/gimmicks/tera_patterns/<type>.png)
# et des Pokémon Dynamaxés (graphics/interface/gimmicks/dynamax_pattern.png)
#
# Un second sprite se pose sur le Pokémon : il reprend son image (images animées comprises) et la recouvre du motif,
# qui défile doucement. Le Pokémon garde ses couleurs en dessous (STRENGTH règle le mélange).
module Gimmicks
  class TeraOverlay < ShaderedSprite
    # Part du motif sur le Pokémon (0 : invisible, 1 : motif seul)
    STRENGTH = 0.62
    # Défilement du motif (par image)
    SPEED = [0.0011, 0.0007].freeze
    # Dynamax : part du motif et défilement (plus rapide, comme une énergie qui bouillonne)
    DYNAMAX_STRENGTH = 0.55
    DYNAMAX_SPEED = [0.0035, 0.0012].freeze
    # Le motif (forme du Pokémon prise dans sa propre image)
    SHADER = <<~GLSL
      uniform sampler2D texture;
      uniform sampler2D pattern;
      uniform vec2 scale;
      uniform vec2 offset;
      uniform float strength;
      const vec3 lumaF = vec3(.299, .587, .114);
      void main() {
        vec4 frag = texture2D(texture, gl_TexCoord[0].xy);
        vec4 pat = texture2D(pattern, fract(gl_TexCoord[0].xy * scale + offset));
        float luma = dot(frag.rgb, lumaF);
        vec3 lit = pat.rgb * (0.45 + 0.85 * luma);
        frag = vec4(mix(lit, pat.rgb, 0.35), frag.a * strength);
        gl_FragColor = frag;
      }
    GLSL
    Shader.register(:pj_tera_pattern, SHADER, alpha_process: true)

    # @param viewport [Viewport]
    # @param type [Symbol] type Téra (:fire…, :stellar) ou :dynamax
    def initialize(viewport, type)
      super(viewport)
      self.shader = Shader.create(:pj_tera_pattern)
      @time = rand(600)
      self.type = type
    end

    # @param type [Symbol]
    def type=(type)
      return if @type == type

      @type = type
      if type == :dynamax
        name = 'dynamax_pattern'
        @speed = DYNAMAX_SPEED
        shader.set_float_uniform('strength', DYNAMAX_STRENGTH)
      else
        name = "tera_patterns/#{type}"
        name = 'tera_patterns/default' unless RPG::Cache.interface_exist?(Gimmicks.file(name))
        @speed = SPEED
        shader.set_float_uniform('strength', STRENGTH)
      end
      @pattern = RPG::Cache.interface(Gimmicks.file(name))
      shader.set_texture_uniform('pattern', @pattern)
      @scale_for = nil
    end

    # Suit le sprite du Pokémon (position, taille, visibilité, image)
    # @param sprite [Sprite]
    # @param hidden [Boolean] cacher le motif (clone, sprite caché…)
    def sync(sprite, hidden = false)
      if sprite.nil? || sprite.disposed? || sprite.bitmap.nil? || sprite.bitmap.disposed? || hidden
        self.visible = false
        return
      end

      self.bitmap = sprite.bitmap unless bitmap.equal?(sprite.bitmap)
      refresh_scale
      set_position(sprite.x, sprite.y)
      set_origin(sprite.ox, sprite.oy)
      self.zoom_x = sprite.zoom_x
      self.zoom_y = sprite.zoom_y
      self.angle = sprite.angle
      self.mirror = sprite.mirror
      self.z = sprite.z if z != sprite.z
      self.opacity = sprite.opacity
      rect = sprite.src_rect
      src_rect.set(rect.x, rect.y, rect.width, rect.height)
      self.visible = sprite.visible
      @time += 1
      shader.set_float_uniform('offset', [(@time * @speed[0]) % 1, (@time * @speed[1]) % 1])
    end

    private

    def refresh_scale
      return if @scale_for.equal?(bitmap)

      @scale_for = bitmap
      shader.set_float_uniform('scale', [bitmap.width / @pattern.width.to_f, bitmap.height / @pattern.height.to_f])
    end
  end
end

module BattleUI
  class PokemonSprite
    module PJGimmicksTeraPattern
      def pokemon=(pokemon)
        super
        pj_refresh_tera_pattern
      end

      def update
        super
        pj_sync_tera_pattern
      end

      def dispose
        @pj_tera_overlay&.dispose
        @pj_tera_overlay = nil
        super
      end

      private

      # Motif à poser : type Téra, :dynamax ou nil
      def pj_pattern_kind
        return nil unless @pokemon
        return Gimmicks.tera_type_of(@pokemon) if @pokemon.respond_to?(:pj_tera?) && @pokemon.pj_tera?
        return :dynamax if @pokemon.respond_to?(:pj_dynamax?) && @pokemon.pj_dynamax?

        return nil
      end

      # Motif posé tant que le Pokémon est Téracristallisé ou Dynamaxé
      def pj_refresh_tera_pattern
        type = pj_pattern_kind
        @pj_pattern_kind = type
        unless type
          @pj_tera_overlay&.visible = false
          return
        end

        if @pj_tera_overlay.nil? || @pj_tera_overlay.disposed?
          @pj_tera_overlay = Gimmicks::TeraOverlay.new(viewport, type)
        else
          @pj_tera_overlay.type = type
        end
        pj_sync_tera_pattern
      rescue StandardError => e
        log_error("Gimmicks : motif Téra (#{e.message})") if respond_to?(:log_error, true)
        @pj_tera_overlay = nil
      end

      def pj_sync_tera_pattern
        kind = pj_pattern_kind
        return pj_refresh_tera_pattern if kind != @pj_pattern_kind
        return unless @pj_tera_overlay && !@pj_tera_overlay.disposed?

        @pj_tera_overlay.sync(self, !kind || under_substitute_effect?)
      end
    end
    prepend PJGimmicksTeraPattern
  end
end

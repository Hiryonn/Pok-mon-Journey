module BattleUI
  class PokemonSprite3D < PokemonSprite
    # Keeps the layer of a Shadow Pokemon in the camera, a 3D battle projecting every sprite through a depth its shader has to be told about.
    module ShadowAura3DPatch
      # Update the sprite
      def update
        super
        join_camera_sprites
      end

      # Set the z position of the sprite
      # @param z [Numeric]
      def z=(z)
        super
        @shadow_aura_layer&.camera_depth = shader_z_position
      end

      # Take the aura off, doing nothing when the creature never wore one
      def dispose_shadow_aura
        @shadow_aura_in_camera = false
        return super
      end

      # Hand the layer everything the sprite wears
      def sync_shadow_aura
        super
        @shadow_aura_layer&.camera_depth = shader_z_position
      end

      private

      # Only a sprite the camera knows about gets the projection matrix its shader needs; done lazily since
      # the visual is not on the scene yet when the layer is born.
      def join_camera_sprites
        return if @shadow_aura_in_camera
        return unless @shadow_aura_layer
        return unless @scene.visual.respond_to?(:sprites3D)

        @scene.visual.sprites3D.append(@shadow_aura_layer)
        @shadow_aura_in_camera = true
      end

      # Shader the layer wears
      # @return [Symbol]
      def shadow_aura_shader_id
        return :shadow_aura_3d
      end
    end

    prepend ShadowAura3DPatch
  end
end

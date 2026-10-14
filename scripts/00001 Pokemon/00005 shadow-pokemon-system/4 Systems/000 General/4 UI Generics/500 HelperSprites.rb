module UI
  class PokemonFaceSprite < Sprite
    prepend ShadowAura

    # Dresses the creature of a summary, a Pokedex page or a hall of fame.
    module ShadowAuraPatch
      # Set the pokemon
      # @param pokemon [PFM::Pokemon, nil]
      def data=(pokemon)
        super
        refresh_shadow_aura(pokemon)
      end
    end

    prepend ShadowAuraPatch
  end

  class PokemonIconSprite < SpriteSheet
    prepend ShadowAura

    # Dresses the icon of a creature, in the party, the storage or anywhere else it is listed.
    module ShadowAuraPatch
      # Set the pokemon
      # @param pokemon [PFM::Pokemon, nil]
      def data=(pokemon)
        super
        refresh_shadow_aura(pokemon)
      end

      # Change the x sprite index of the sheet
      # @param value [Integer] the x sprite index of the sheet
      def sx=(value)
        super
        @shadow_aura_layer&.creature_rect = src_rect
      end

      # Change the y sprite index of the sheet
      # @param value [Integer] the y sprite index of the sheet
      def sy=(value)
        super
        @shadow_aura_layer&.creature_rect = src_rect
      end
    end

    prepend ShadowAuraPatch
  end
end

module BattleUI
  class InfoBar < UI::SpriteStack
    # Refreshes the bar the moment a Shadow Pokemon breaks down or calms down, so the icon never lags a turn behind the state it announces.
    module InfoBarShadowPatch
      # Amount the HP gauge of an ally moves to sit where the enemy one sits, freeing the room the shadow icon needs at the right end of the bar.
      # @return [Integer]
      SHADOW_HP_OFFSET = -10

      # Update the InfoBar
      def update
        super
        return unless @pokemon
        return if @shown_unstable == @pokemon.unstable?
        # refresh shows the bar, so a state noted while it is hidden waits for it to come back
        return unless visible

        refresh
      end

      # Set the Creature to show in the Info Bar
      def data=(pokemon)
        super
        # The state is noted here rather than on the first update, refresh showing the bar on its
        # own and the bar being still behind the battle transition at that point.
        @shown_unstable = pokemon&.unstable?
        align_hp_gauge(pokemon)
      end

      private

      # Move the HP gauge by delta, a shift applied once surviving every later move of the bar since the stack moves its children relatively.
      # @param pokemon [PFM::Pokemon]
      def align_hp_gauge(pokemon)
        wanted = !enemy? && pokemon&.shadow? ? SHADOW_HP_OFFSET : 0
        delta = wanted - @shadow_hp_offset.to_i
        return if delta.zero?

        @hp_background.x += delta
        @hp_bar.x += delta
        @hp_text.x += delta
        @shadow_hp_offset = wanted
      end
    end

    prepend InfoBarShadowPatch

    class Background < ShaderedSprite
      # Dresses the bar of a Shadow Pokemon, in its plain form or in the one that shows it lost control.
      module BackgroundShadowPatch
        # Name of the background based on the creature shown
        # @param pokemon [PFM::PokemonBattler]
        # @return [String]
        def background_filename(pokemon)
          return super unless pokemon.shadow?

          return "battle/shadow/battlebar_shadow#{suffix_3v3}#{pokemon.unstable? ? '_unstable' : ''}"
        end
      end

      prepend BackgroundShadowPatch
    end
  end
end

module UI
  class Summary_Stat < SpriteStack
    # Keeps the nature of a Shadow Pokemon out of sight until its heart has opened enough bars to give it
    # away, the way Pokemon XD hides it behind the lock.
    module StatShadowNaturePatch
      # Shown in place of the nature of a creature that keeps it to itself
      HIDDEN_NATURE = '???'

      private

      # Fix the nature text with colors and the right nature name
      # @param creature [PFM::Pokemon]
      def fix_nature_texts(creature)
        return super if creature.nature_revealed?

        @nature_text.text = HIDDEN_NATURE
        # The colour of a stat name tells which way the nature leans, so it goes neutral as well
        @stat_name_texts.each { |text| text.load_color(0) }
      end

      # Update the Arrows used to indicate the stats boosted
      # @param creature [PFM::Pokemon]
      def refresh_nature_arrows(creature)
        return super if creature.nature_revealed?

        @up_arrow.opacity = @down_arrow.opacity = 0
        @arrows_animation = nil
      end
    end

    prepend StatShadowNaturePatch
  end
end

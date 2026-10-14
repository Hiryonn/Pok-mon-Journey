module UI
  class Summary_Skills < SpriteStack
    # Shows the slots a locked heart still holds back beside the moves the Pokemon can use. The move reminder
    # and the contest page derive from this one and read the creature directly, so only the plain move page
    # is decorated.
    module SummarySkillsShadowPatch
      # Set the data of the UI
      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        pokemon = PFM::ShadowMovesetView.wrap(pokemon) if instance_of?(UI::Summary_Skills)

        super(pokemon)
      end
    end

    prepend SummarySkillsShadowPatch
  end
end

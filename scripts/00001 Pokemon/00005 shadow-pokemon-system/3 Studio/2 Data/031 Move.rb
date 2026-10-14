module Studio
  class Move
    # Serves the labels of the moves the plugin ships, and leaves every other move to the game.
    module MoveShadowPatch
      # Get the move name
      # @return [String]
      def name
        return super unless PFM::ShadowNames.move?(db_symbol)

        return PFM::ShadowNames.move_label(db_symbol, PFM::ShadowNames::MOVE_NAME_ROW)
      end

      # Get the move description
      # @return [String]
      def description
        return super unless PFM::ShadowNames.move?(db_symbol)

        return PFM::ShadowNames.move_label(db_symbol, PFM::ShadowNames::MOVE_DESCRIPTION_ROW)
      end

      # Get the move contest description
      # @return [String]
      def contest_description
        return super unless PFM::ShadowNames.move?(db_symbol)

        return PFM::ShadowNames.move_label(db_symbol, PFM::ShadowNames::MOVE_CONTEST_ROW)
      end
    end

    prepend MoveShadowPatch
  end
end

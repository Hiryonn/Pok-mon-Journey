module Studio
  class Type
    # Serves the name of the type the plugin ships, and leaves every other type to the game.
    module TypeShadowPatch
      # Get the text name of the type
      # @return [String]
      def name
        return super unless db_symbol == PFM::ShadowNames::TYPE_DB_SYMBOL

        return PFM::ShadowNames.type_name
      end
    end

    prepend TypeShadowPatch
  end
end

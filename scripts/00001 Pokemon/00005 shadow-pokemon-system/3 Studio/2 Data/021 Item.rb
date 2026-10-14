module Studio
  class Item
    # Serves the labels of the items the plugin ships, and leaves every other item to the game.
    module ItemShadowPatch
      # Get the name of the item
      # @return [String]
      def name
        return super unless PFM::ShadowNames.item?(db_symbol)

        return PFM::ShadowNames.item_label(db_symbol, PFM::ShadowNames::ITEM_NAME_ROW)
      end

      # Description of the item
      # @return [String]
      def description
        return super unless PFM::ShadowNames.item?(db_symbol)

        return PFM::ShadowNames.item_label(db_symbol, PFM::ShadowNames::ITEM_DESCRIPTION_ROW)
      end

      # Description of the item
      # @note The engine aliases descr on description before the prepend, so the alias has to be redirected here.
      # @return [String]
      def descr
        return description
      end
    end

    prepend ItemShadowPatch
  end
end

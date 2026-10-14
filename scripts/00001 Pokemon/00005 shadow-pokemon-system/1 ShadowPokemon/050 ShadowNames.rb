module PFM
  # Labels of the entries the plugin ships. A name is not a piece of text data, it is a method:
  # Studio asks `text_get` for it with the id of the entry. Serving our own entries from our own
  # dialog file therefore gives them a complete name and description without ever writing into a
  # text file of the game hosting the plugin.
  module ShadowNames
    # Id of the dialog file holding the labels of the plugin.
    # @return [Integer]
    FILE_ID = 110_021
    # db_symbol of the moves the plugin ships, in the order of their CSV rows.
    # @note A block holds one row per shipped entry, in the alphabetical order of its db_symbol, so that
    #   the installation finds the same row by sorting the Studio files it ships without copying this list.
    # @return [Array<Symbol>]
    MOVE_DB_SYMBOLS = %i[
      shadow_blast shadow_blitz shadow_bolt shadow_break shadow_chill shadow_down shadow_end shadow_fire
      shadow_half shadow_hold shadow_mist shadow_panic shadow_rave shadow_rush shadow_shed shadow_sky
      shadow_storm shadow_wave
    ]
    # Number of moves the plugin ships.
    # @return [Integer]
    MOVE_COUNT = MOVE_DB_SYMBOLS.size
    # db_symbol of the items the plugin ships, in the order of their CSV rows.
    # @return [Array<Symbol>]
    ITEM_DB_SYMBOLS = %i[excite_scent joy_scent snag_machine vivid_scent]
    # Number of items the plugin ships.
    # @return [Integer]
    ITEM_COUNT = ITEM_DB_SYMBOLS.size
    # db_symbol of the type the plugin ships.
    # @return [Symbol]
    TYPE_DB_SYMBOL = :shadow

    # Row of the first move name in the file, the blocks following in this order: names,
    # descriptions, contest descriptions, item names, item descriptions, type name.
    # @return [Integer]
    MOVE_NAME_ROW = 0
    # Row of the first move description.
    # @return [Integer]
    MOVE_DESCRIPTION_ROW = MOVE_NAME_ROW + MOVE_COUNT
    # Row of the first move contest description.
    # @return [Integer]
    MOVE_CONTEST_ROW = MOVE_DESCRIPTION_ROW + MOVE_COUNT
    # Row of the first item name.
    # @return [Integer]
    ITEM_NAME_ROW = MOVE_CONTEST_ROW + MOVE_COUNT
    # Row of the first item description.
    # @return [Integer]
    ITEM_DESCRIPTION_ROW = ITEM_NAME_ROW + ITEM_COUNT
    # Row of the type name.
    # @return [Integer]
    TYPE_NAME_ROW = ITEM_DESCRIPTION_ROW + ITEM_COUNT

    module_function

    # Whether that move db_symbol belongs to the plugin.
    # @param db_symbol [Symbol]
    # @return [Boolean]
    def move?(db_symbol)
      return MOVE_DB_SYMBOLS.include?(db_symbol)
    end

    # Whether that item db_symbol belongs to the plugin.
    # @param db_symbol [Symbol]
    # @return [Boolean]
    def item?(db_symbol)
      return ITEM_DB_SYMBOLS.include?(db_symbol)
    end

    # Label of a move the plugin ships.
    # @param db_symbol [Symbol]
    # @param block_row [Integer] MOVE_NAME_ROW, MOVE_DESCRIPTION_ROW or MOVE_CONTEST_ROW
    # @return [String]
    def move_label(db_symbol, block_row)
      return ext_text(FILE_ID, block_row + MOVE_DB_SYMBOLS.index(db_symbol))
    end

    # Label of an item the plugin ships.
    # @param db_symbol [Symbol]
    # @param block_row [Integer] ITEM_NAME_ROW or ITEM_DESCRIPTION_ROW
    # @return [String]
    def item_label(db_symbol, block_row)
      return ext_text(FILE_ID, block_row + ITEM_DB_SYMBOLS.index(db_symbol))
    end

    # Name of the type the plugin ships.
    # @return [String]
    def type_name
      return ext_text(FILE_ID, TYPE_NAME_ROW)
    end
  end
end

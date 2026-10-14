module PFM
  # Puts the entries the plugin ships into the database the game runs on.
  #
  # The engine only compiles the Studio files when psdk.dat is missing, so a database built before the
  # installation keeps being served as it is. The entries are added to the loaded database instead,
  # which writes nothing and leaves a project compiled after the installation alone.
  module ShadowData
    # Root of the Studio files of the project.
    # @return [String]
    STUDIO_ROOT = 'Data/Studio'
    # Entries the plugin ships, by Studio folder. The folder is also the name of the store the accessors read.
    # @return [Hash{ String => Array<Symbol> }]
    SHIPPED_ENTRIES = {
      'types' => [ShadowNames::TYPE_DB_SYMBOL],
      'moves' => ShadowNames::MOVE_DB_SYMBOLS,
      'items' => ShadowNames::ITEM_DB_SYMBOLS
    }

    module_function

    # Add every shipped entry the database does not hold yet.
    def install
      missing = SHIPPED_ENTRIES.flat_map do |folder, db_symbols|
        db_symbols.reject { |db_symbol| known?(folder, db_symbol) }.map { |db_symbol| [folder, db_symbol] }
      end
      return if missing.empty?

      ScriptLoader.load_tool('Studio2PSDK')
      added = missing.count { |folder, db_symbol| add(folder, db_symbol) }
      # Missing entries mean the database of the project is older than the installation, and a game
      # compiled from it would carry none of them, the compilation reusing psdk.dat when it is there.
      log_error("cc-shadow-pokemon-system: #{added} of the #{missing.size} missing entries were added to the loaded " \
                'database. Save the project in Pokémon Studio, or delete Data/Studio/psdk.dat, so that a ' \
                'compiled game carries them.')
    end

    # Whether the database already holds that entry, which a project compiled after the installation does.
    # @param folder [String]
    # @param db_symbol [Symbol]
    # @return [Boolean]
    def known?(folder, db_symbol)
      return !__game_data.dig(folder.to_sym, db_symbol).nil?
    end

    # Convert the Studio file of an entry and put it in the two stores the accessors read, the one by
    # db_symbol and the one by id.
    # @param folder [String]
    # @param db_symbol [Symbol]
    # @return [Boolean] false when the file is absent, which a compiled game is, shipping psdk.dat alone
    def add(folder, db_symbol)
      filename = File.join(STUDIO_ROOT, folder, "#{db_symbol}.json")
      return false unless File.exist?(filename)

      entity = Studio2PSDK.json_to_psdk_studio_object(JSON.parse(File.read(filename)))
      store = folder.to_sym
      __game_data[store][entity.db_symbol] = entity
      __game_data[:"#{store}__id"] = (__game_data[:"#{store}__id"] + [entity]).sort_by(&:id)

      return true
    end
  end
end

PFM::ShadowData.install

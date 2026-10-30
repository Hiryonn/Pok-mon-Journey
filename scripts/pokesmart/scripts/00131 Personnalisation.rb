# PokeSmart : réglages de l'appli Personnaliser (enregistrés dans la sauvegarde) et chemins des images
module UI
  module PokeSmart
    module_function

    # Image de la coque choisie (dossier de la coque, sinon dossier commun)
    # @param name [String]
    # @return [String]
    def file(name)
      return file_in(theme[:dir], name)
    end

    # Icône du jeu d'icônes choisi (dossier du jeu, sinon dossier commun)
    # @param name [String]
    # @return [String]
    def icon_file(name)
      return file_in(ICON_SETS[icon_set_id][:dir], name)
    end

    # @param dir [String] sous-dossier
    # @param name [String]
    # @return [String]
    def file_in(dir, name)
      dir = dir.to_s
      return "#{DIR}#{name}" if dir.empty?

      path = "#{DIR}#{dir}#{name}"
      return exist?(path) ? path : "#{DIR}#{name}"
    end

    # @param path [String] chemin dans graphics/interface/
    # @return [Boolean]
    def exist?(path)
      @exists ||= {}
      @exists[path] = RPG::Cache.interface_exist?(path) ? true : false if @exists[path].nil?
      return @exists[path]
    end

    # Réglages de Personnaliser (enregistrés dans la sauvegarde)
    # @return [Hash]
    def settings
      return {} unless $user_data.is_a?(Hash)

      data = ($user_data[:pokesmart] ||= {})
      data[:case] ||= $user_data.delete(:pokesmart_theme) if $user_data.key?(:pokesmart_theme)
      return data
    end

    # Coque choisie
    # @return [Symbol]
    def theme_id
      id = settings[:case]
      return THEMES.key?(id) ? id : DEFAULT_THEME
    end

    # @return [Hash]
    def theme
      return THEMES[theme_id]
    end

    # Jeu d'icônes choisi (sinon celui de la coque)
    # @return [Symbol]
    def icon_set_id
      id = settings[:icons]
      return id if ICON_SETS.key?(id)

      return ICON_SETS.key?(theme_id) ? theme_id : ICON_SETS.keys.first
    end

    # Fonds d'écran présents (images du dossier wallpapers/, sinon la liste WALLPAPERS)
    # @return [Array<String>]
    def wallpapers
      @wallpapers ||= begin
        names = Dir.glob("graphics/interface/#{DIR}wallpapers/*.png").map { |path| File.basename(path, '.png') }
        names = WALLPAPERS.select { |name| exist?("#{DIR}wallpapers/#{name}") } if names.empty?
        # fonds libres d'abord (par nom), puis ceux des Pokémon (« 025_wallpaper ») par numéro
        names.sort_by { |name| (id = wallpaper_species(name)) ? [1, id, name] : [0, 0, name] }
      rescue StandardError
        WALLPAPERS.select { |name| exist?("#{DIR}wallpapers/#{name}") }
      end
    end

    # @param name [String] image de wallpapers/
    # @return [Integer, nil] numéro du Pokémon pour « 025_wallpaper », sinon nil
    def wallpaper_species(name)
      return name =~ /\A(\d+)_wallpaper\z/ ? Regexp.last_match(1).to_i : nil
    end

    # Nom affiché d'un fond d'écran : « 025 Pikachu » pour un fond de Pokémon, sinon « Fond n »
    # @param name [String]
    # @param number [Integer] place parmi les fonds libres
    # @return [String]
    def wallpaper_label(name, number)
      if (id = wallpaper_species(name))
        species = (data_creature(id).name rescue nil)
        return format('%03d %s', id, species || 'Pokémon')
      end
      return "#{french? ? 'Fond' : 'Wallpaper'} #{number}"
    end

    # Fond d'écran choisi : :auto (selon le Pokémon de tête), :none, ou le nom d'une image de wallpapers/
    # @return [Symbol, String]
    def wallpaper_choice
      choice = settings[:wallpaper]
      return choice if choice == :auto || choice == :none || wallpapers.include?(choice)

      return theme[:wallpaper] ? :auto : :none
    end

    # Valeur actuelle d'un réglage de Personnaliser
    # @param category [Symbol] :case, :icons ou :wallpaper
    def setting(category)
      case category
      when :case then return theme_id
      when :icons then return icon_set_id
      else return wallpaper_choice
      end
    end

    # @param category [Symbol]
    # @param value [Object]
    def set_setting(category, value)
      settings[category] = value
    end

    # Choix possibles d'un réglage : [[valeur, nom affiché], ...]
    # @param category [Symbol]
    # @return [Array<Array>]
    def options(category)
      case category
      when :case then return THEMES.map { |id, data| [id, data[:name]] }
      when :icons then return ICON_SETS.map { |id, data| [id, data[:name]] }
      end
      fr = french?
      list = [[:auto, fr ? 'Selon le Pokémon' : 'Lead Pokémon'], [:none, fr ? 'Aucun' : 'None']]
      wallpapers.each_with_index { |wallpaper, i| list << [wallpaper, wallpaper_label(wallpaper, i + 1)] }
      return list
    end

    # Pokémon en tête d'équipe (hors œufs)
    # @return [PFM::Pokemon, nil]
    def leader
      return $actors&.find { |pokemon| pokemon && !pokemon.egg? }
    end

    # Fond d'écran automatique : image de l'espèce de tête (« 025_wallpaper », « 25_wallpaper », « 25 »),
    # sinon selon son type (TYPE_WALLPAPERS), sinon aucun
    # @return [String, nil]
    def wallpaper_name
      return nil unless (pokemon = leader)

      id = pokemon.id.to_i
      [format('%03d_wallpaper', id), format('%02d_wallpaper', id), id.to_s].each do |name|
        return name if exist?("#{DIR}wallpapers/#{name}")
      end
      name = TYPE_WALLPAPERS[data_type(pokemon.type1).db_symbol]
      return name && exist?("#{DIR}wallpapers/#{name}") ? name : nil
    rescue StandardError
      return nil
    end

    # @return [Boolean]
    def french?
      return $options.nil? || $options.language == 'fr'
    end
  end
end

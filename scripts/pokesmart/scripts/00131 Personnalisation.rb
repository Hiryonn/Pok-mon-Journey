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

    # Icône de base d'une appli (APP_ICONS, sinon l'icône générique)
    # @param action [Symbol]
    # @return [String] nom de l'image sans variante (ex. « icon_bag »)
    def app_base_icon(action)
      name = APP_ICONS.fetch(action, DEFAULT_ICON)
      return exist?("#{DIR}#{name}") ? name : DEFAULT_ICON
    end

    # Variantes présentes d'une icône : '' (icon_bag.png), puis '01', '02'… (icon_bag_01.png…)
    # @param base [String]
    # @return [Array<String>]
    def icon_variants(base)
      @icon_variants ||= {}
      @icon_variants[base] ||= [''] + (1..MAX_ICON_VARIANTS).map { |i| format('%02d', i) }.select { |v| exist?("#{DIR}#{base}_#{v}") }
    end

    # Variantes choisies, appli par appli : {action => '01'}
    # @return [Hash]
    def icon_choices
      data = settings
      return data[:icons] if data[:icons].is_a?(Hash)

      # ancien réglage « jeu d'icônes Motismart » : les variantes 01 deviennent le choix de chaque appli
      old = data[:icons]
      data[:icons] = {}
      APP_ICONS.each_key { |action| data[:icons][action] = '01' if icon_variants(app_base_icon(action)).include?('01') } if old == :motismart
      return data[:icons]
    end

    # Variante d'icône choisie pour une appli ('' = l'icône de base)
    # @param action [Symbol]
    # @return [String]
    def icon_variant(action)
      variant = icon_choices[action].to_s
      return icon_variants(app_base_icon(action)).include?(variant) ? variant : ''
    end

    # @param action [Symbol]
    # @param variant [String, nil] nil ou '' = icône de base
    def set_icon_variant(action, variant)
      choices = icon_choices
      variant.to_s.empty? ? choices.delete(action) : choices[action] = variant
    end

    # Image de l'icône d'une appli (avec la variante choisie)
    # @param action [Symbol]
    # @param variant [String, nil] variante à afficher (par défaut celle choisie)
    # @return [String]
    def app_icon(action, variant = nil)
      base = app_base_icon(action)
      variant = icon_variant(action) if variant.nil?
      return variant.empty? ? "#{DIR}#{base}" : "#{DIR}#{base}_#{variant}"
    end

    # @param variant [String]
    # @return [String] « Classique », « Variante 1 »…
    def icon_variant_label(variant)
      return french? ? 'Classique' : 'Classic' if variant.empty?

      return "#{french? ? 'Variante' : 'Variant'} #{variant.to_i}"
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

    # Valeur actuelle d'un réglage de Personnaliser (les icônes se règlent appli par appli, voir icon_variant)
    # @param category [Symbol] :case ou :wallpaper
    def setting(category)
      case category
      when :case then return theme_id
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

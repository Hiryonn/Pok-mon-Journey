# encoding: utf-8
# Icônes des Pokémon rangées dans trois dossiers (comme les sprites de face et de dos) :
#   graphics/pokedex/pokeicon       : icônes normales
#   graphics/pokedex/pokeiconshiny  : icônes chromatiques
#   graphics/pokedex/pokeiconegg    : icônes d'œuf
# Studio les range ainsi (tools/studio-plugins/patch_studio_icons.py, ranger_icones.bat) ; PSDK ne connaît que
# pokeicon : une icône absente de pokeicon est cherchée dans pokeiconshiny puis pokeiconegg.
module RPG
  module Cache
    # Dossiers des icônes en plus de pokeicon (chemins dans graphics/)
    Pokedex_PokeIcon_Extra_Paths = ['pokedex/pokeiconshiny', 'pokedex/pokeiconegg'].freeze

    class << self
      alias pj_icons_b_icon b_icon
      alias pj_icons_b_icon_exist? b_icon_exist?
      alias pj_icons_load_b_icon load_b_icon

      # @param filename [String]
      # @param hue [Integer]
      # @return [Texture]
      def b_icon(filename, hue = 0)
        path = pj_icon_extra_path(filename)
        return pj_icons_b_icon(filename, hue) unless path

        @pj_icon_extra_cache ||= {}
        return load_image(@pj_icon_extra_cache, filename, path)
      end

      # @param filename [String]
      # @return [Boolean]
      def b_icon_exist?(filename)
        return true if pj_icons_b_icon_exist?(filename)

        return !pj_icon_extra_path(filename).nil?
      end

      # @param flush_it [Boolean]
      def load_b_icon(flush_it = false)
        if flush_it
          dispose_bitmaps_from_cache_tab(@pj_icon_extra_cache) if @pj_icon_extra_cache
        else
          @pj_icon_extra_cache = {}
        end
        @pj_icon_paths = {}
        pj_icons_load_b_icon(flush_it)
      end

      # Dossier d'une icône rangée hors de pokeicon (nil si elle est dans pokeicon ou nulle part)
      # @param filename [String]
      # @return [String, nil]
      def pj_icon_extra_path(filename)
        name = filename.to_s
        return nil if name.empty?

        @pj_icon_paths ||= {}
        return @pj_icon_paths[name] if @pj_icon_paths.key?(name)

        found = nil
        unless test_file_existence(name, Pokedex_PokeIcon_Path)
          found = Pokedex_PokeIcon_Extra_Paths.find { |path| test_file_existence(name, path) }
        end
        return @pj_icon_paths[name] = found
      rescue StandardError
        return nil
      end
    end
  end
end

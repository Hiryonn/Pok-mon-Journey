# Pokédex Horizon : page Habitat (carte des lieux où vit le Pokémon)
#
# Remplace l'habillage de la carte de PSDK (GamePlay::WorldMap en mode :pokedex) dans le Pokédex :
#   - bandeau du haut comme la fiche (Poké Ball, nom, « Habitat »)
#   - panneau à gauche : Pokémon, région, lieu sous le curseur
#   - grande carte à droite (prend toute la largeur gagnée sur un écran large / dans la console)
#   - barre du bas cliquable : Fiche (B) | Carte suivante (Y) | Zoom (X)
#   - « Zone inconnue » dans le style Horizon quand le Pokémon n'a pas d'habitat connu sur la carte
# Le curseur se place sur le premier lieu où vit le Pokémon. Clic sur la carte : déplace le curseur.
#
# Graphismes : graphics/pokedex/pe/habitat_bg, habitat_frame, habitat_unknown (tools/pokedex/build_habitat.py)
module UI
  module DexPE
    # Géométrie de la page Habitat (repère : bord gauche de l'écran, 320 px + DexPE.extra)
    module Habitat
      # Carte : x, y, largeur (sans DexPE.extra), hauteur
      MAP_RECT = [103, 29, 210, 177].freeze
      # Barre du bas : y cliquable
      NAV_Y = 219..236
      TEXTS = {
        title: %w[Habitat Habitat], region: %w[RÉGION REGION], place: %w[LIEU PLACE], back: %w[Fiche Info],
        zoom: %w[Zoom Zoom]
      }.freeze

      module_function

      # @param key [Symbol]
      # @return [String]
      def text(key)
        return TEXTS[key][$options&.language == 'fr' || $options.nil? ? 0 : 1]
      end

      # @return [Array<Integer>] rect de la carte avec la largeur gagnée
      def map_rect
        x, y, w, h = MAP_RECT
        return [x, y, w + DexPE.extra, h]
      end

      # Image 320 px élargie à toute la largeur de l'écran (on étire une colonne au milieu du panneau de la carte)
      # @param name [String] habitat_bg ou habitat_frame
      # @return [Bitmap, String] Bitmap composé, ou le nom du fichier si l'écran n'est pas élargi
      def bitmap(name)
        file = DexPE.file(name)
        e = DexPE.extra
        return file unless DexPE.wide? && e > 0

        pieces = [[0, 0, 200, 240, 0, 0, 200, 240], [200, 0, e, 240, 200, 0, 1, 240], [200 + e, 0, 120, 240, 200, 0, 120, 240]]
        return ::Ecran.composer(file, :pokedex, 320 + e, pieces)
      end

      # @param sprite [Sprite]
      # @param name [String]
      # @return [Sprite]
      def apply(sprite, name)
        image = bitmap(name)
        image.is_a?(String) ? sprite.set_bitmap(image, :pokedex) : sprite.bitmap = image
        DexPE.anti_marche(sprite)
        return sprite
      end
    end

    # Panneau d'infos de la page Habitat (remplace UI::DexWinMap ; mêmes méthodes : data=, set_location, set_region)
    class HabitatPanel < SpriteStack
      # Taille maximale du Pokémon dans le panneau
      FACE_BOX = [84, 74].freeze

      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, DexPE.left, 0, default_cache: :pokedex)
        e = DexPE.extra
        @ball = add_sprite(4, 4, DexPE.file('ball_on'))
        @title = add_text(40, 3, 136, 16, :pokedex_name, type: SymText, color: WHITE)
        @title.bold = true
        with_font(SMALL_FONT) { add_text(200 + e, 5, 114, 13, Habitat.text(:title), 2, color: WHITE) }
        @face = add_sprite(49, 104, NO_INITIAL_IMAGE, type: PokemonFaceSprite)
        with_font(SMALL_FONT) do
          add_text(10, 114, 62, 13, Habitat.text(:region), color: WHITE)
          add_text(10, 148, 62, 13, Habitat.text(:place), color: WHITE)
        end
        @region = add_text(8, 129, 84, 16, '', 1, color: DARK)
        @location = add_text(8, 163, 84, 16, '', 1, color: DARK)
        @nav = [
          add_text(0, 220, 52, 16, Habitat.text(:back), 1, color: WHITE),
          add_text(52, 220, 216 + e, 16, ext_text(9000, 32), 1, color: WHITE),
          add_text(272 + e, 220, 48, 16, Habitat.text(:zoom), 1, color: WHITE)
        ]
      end

      # @param pokemon [PFM::Pokemon, Symbol]
      def data=(pokemon)
        return unless pokemon.is_a?(PFM::Pokemon)

        super(pokemon)
        caught = $pokedex.creature_caught?(pokemon.db_symbol) rescue true
        @ball.set_bitmap(DexPE.file(caught ? 'ball_on' : 'ball_off'), :pokedex)
        fit_face
      end

      # Lieu sous le curseur
      # @param place [String]
      # @param _color [Integer]
      def set_location(place, _color = nil)
        @location.multiline_text = place.to_s
      end

      # Nom de la région (carte du monde)
      # @param place [String]
      # @param _color [Integer]
      def set_region(place, _color = nil)
        @region.text = place.to_s
      end

      # @param more_maps [Boolean] il y a d'autres cartes à voir
      def next_map_available=(more_maps)
        @nav[1].load_color(more_maps ? WHITE : 11)
      end

      def update
        @face.update
      end

      private

      # Le Pokémon tient dans le panneau (sprites plus grands que 96 px réduits)
      def fit_face
        bmp = @face.bitmap
        return unless bmp && !bmp.disposed? && bmp.width > 0 && bmp.height > 0

        @face.zoom = [1.0, FACE_BOX[0] / bmp.width.to_f, FACE_BOX[1] / bmp.height.to_f].min
      end
    end

    # Cadre « Zone inconnue » au centre de la carte
    class HabitatUnknown < SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        x, y, w, h = Habitat.map_rect
        super(viewport, DexPE.left + x + (w - 140) / 2, y + (h - 24) / 2, default_cache: :pokedex)
        add_sprite(0, 0, DexPE.file('habitat_unknown'))
        add_text(0, 4, 140, 16, ext_text(9000, 31), 1, color: WHITE)
      end
    end
  end
end

module GamePlay
  # Carte du Pokédex (habitat) au style Horizon
  class WorldMapPE < WorldMap
    # Couleur des lieux où vit le Pokémon (bleu Horizon, clignotant)
    ZONE_COLOR = [0.2, 0.55, 0.92].freeze

    def initialize(mode = :pokedex, wm_id = $env.get_worldmap, pokemon = nil)
      super
      @cam_x = @cam_y = 0.0
      @echelle = 1
    end

    # Viewports de la carte : coordonnées réelles (le zoom de la carte s'ajoute à celui de l'interface)
    def create_viewport
      @viewport_background = Viewport.create(:main, ViewportsBaseZ)
      _x, _y, @map_w, @map_h = UI::DexPE::Habitat.map_rect
      @viewport_map = map_viewport(1000)
      @viewport_map_zones = map_viewport(2000)
      @viewport_map_markers = map_viewport(3000)
      @viewport_map_cursor = map_viewport(4000)
      @map_viewports = [@viewport_map, @viewport_map_zones, @viewport_map_markers, @viewport_map_cursor]
      @viewport_ui = Viewport.create(:main, ViewportsBaseZ + 5000)
    end

    def create_background
      @bg_background = UI::DexPE::Habitat.apply(Sprite.new(@viewport_background), 'habitat_bg')
    end

    def create_frame
      @ui_frame = UI::DexPE::Habitat.apply(Sprite.new(@viewport_ui), 'habitat_frame')
      @ui_infobox = UI::DexPE::HabitatPanel.new(@viewport_ui)
      @ui_infobox.data = @pokemon
      @ui_unknown_zone = UI::DexPE::HabitatUnknown.new(@viewport_ui)
      @ui_unknown_zone.visible = false
      set_worldmap(@worldmap_id)
    end

    def update_graphics
      super
      @ui_infobox.update
    end

    # Fond fixe (pas de damier animé)
    def update_background_animation; end

    def update_zones_animation
      return if @marker_zones.empty?

      if @zone_animation_backroll
        @zone_animation_counter -= 1
        @zone_animation_backroll = @zone_animation_counter >= 0
      else
        @zone_animation_counter += 1
        @zone_animation_backroll = @zone_animation_counter >= 100
      end
      color = [*ZONE_COLOR, (300 + @zone_animation_counter).to_f / 500]
      @marker_zones.each { |zone| zone.set_color(color) }
    end

    # Caméra : la carte suit le curseur, centrée si elle est plus petite que le panneau
    def update_display_origin
      view_w = @map_w / @zoom.to_f
      view_h = @map_h / @zoom.to_f
      map_w = @map_worldmap.width
      map_h = @map_worldmap.height
      cx = @cursor.x + TileSize / 2.0
      cy = @cursor.y + TileSize / 2.0
      @cam_x = map_w <= view_w ? -(view_w - map_w) / 2.0 : (cx - view_w / 2).clamp(0, map_w - view_w)
      @cam_y = map_h <= view_h ? -(view_h - map_h) / 2.0 : (cy - view_h / 2).clamp(0, map_h - view_h)
    end

    def update_display_position
      zoom = @echelle * @zoom
      @map_viewports.each do |vp|
        vp.zoom = zoom
        rw = vp.rect.width
        rh = vp.rect.height
        vp.ox = (@cam_x - (rw - rw / zoom) / 2.0).round
        vp.oy = (@cam_y - (rh - rh / zoom) / 2.0).round
      end
    end

    def recenter_map
      @cam_x = @cam_y = 0.0
    end

    # X : zoom avant (carte qui tient dans le panneau) ou vue d'ensemble (grande carte)
    def on_toggle_zoom
      if @zoom == 1
        fits = @map_worldmap.width <= @map_w && @map_worldmap.height <= @map_h
        @zoom = fits ? 2 : 0.5
      else
        @zoom = 1
      end
      update_display_origin
      update_display_position
    end

    def set_worldmap(id)
      super
      @ui_infobox.next_map_available = other_worldmap?
    end

    def set_pokemon(pkm, forced_worldmap_id = nil)
      super
      focus_first_zone
    end

    def display_pokemon_zones
      return unless @mode == :pokedex

      @pe_zones = search_pokemon_zone
      display_zones(@pe_zones)
    end

    # Clic dans la carte (coordonnées depuis le bord gauche de l'écran)
    # @return [Boolean] true si le clic était sur la carte
    def pe_click(x, y)
      mx, my, mw, mh = UI::DexPE::Habitat.map_rect
      return false unless x.between?(mx, mx + mw - 1) && y.between?(my, my + mh - 1)

      tx = ((@cam_x + (x - mx) / @zoom.to_f) / TileSize).floor
      ty = ((@cam_y + (y - my) / @zoom.to_f) / TileSize).floor
      return true unless tx.between?(0, @x_max - 1) && ty.between?(0, @y_max - 1)
      return true if tx == @x && ty == @y

      play_cursor_se
      move_cursor_to(tx, ty)
      return true
    end

    private

    # @param z [Integer]
    # @return [Viewport]
    def map_viewport(z)
      x, y, w, h = UI::DexPE::Habitat.map_rect
      x += UI::DexPE.left
      return Viewport.create(x, y, w, h, ViewportsBaseZ + z) unless defined?(::Ecran) && ::Ecran.grand?

      @echelle = ::Ecran.echelle
      e = @echelle
      rx = ::Ecran.decalage_x + (x * e).round
      ry = ::Ecran.decalage_y + (y * e).round
      return ::Ecran.contourner { Viewport.create(rx, ry, (w * e).round, (h * e).round, ViewportsBaseZ + z) }
    end

    # @return [Boolean] une autre carte du monde visitée peut être affichée
    def other_worldmap?
      return each_data_world_map.each_with_index.count { |_wm, id| $env.visited_worldmap?(id) } > 1
    rescue StandardError
      return true
    end

    # Curseur sur le premier lieu où vit le Pokémon
    def focus_first_zone
      return unless @pe_zones && !@marker_zones.empty?

      0.upto(@pe_zones.ysize - 1) do |y|
        0.upto(@pe_zones.xsize - 1) do |x|
          next if @pe_zones[x, y] == 0

          @x = @last_x = x
          @y = @last_y = y
          @cursor_move_count = false
          @cursor.x = BitmapOffset + @map_worldmap.x + TileSize * x
          @cursor.y = BitmapOffset + @map_worldmap.y + TileSize * y
          update_display_origin
          update_display_position
          update_infobox
          return
        end
      end
    end

    # Déplace le curseur (glissement) vers une case
    def move_cursor_to(tx, ty)
      if @cursor_move_count
        @cursor.x = BitmapOffset + @map_worldmap.x + TileSize * @x
        @cursor.y = BitmapOffset + @map_worldmap.y + TileSize * @y
      end
      @last_x = @x
      @last_y = @y
      @x = tx
      @y = ty
      @cursor_move_count = 0
      update_infobox
    end
  end

  class Dex
    # Page Habitat au style Horizon + clics sur la barre du bas et la carte
    module PEHabitat
      private

      def create_worldmap
        @pokemon_worldmap = GamePlay::WorldMapPE.new(:pokedex, $env.get_worldmap)
        @pokemon_worldmap.create_graphics
      end

      public

      def update_mouse(moved)
        return super unless worldmap_state? && Mouse.trigger?(:LEFT)

        mx, my = defined?(::Ecran) ? ::Ecran.souris(@viewport) : [Mouse.x, Mouse.y]
        x = mx - UI::DexPE.left
        if UI::DexPE::Habitat::NAV_Y.include?(my)
          e = UI::DexPE.extra
          if x < 52
            action_b
          elsif x < 272 + e
            action_y
          else
            action_x
          end
          return false
        end
        return false if @pokemon_worldmap.pe_click(x, my)

        return super
      end
    end
    prepend PEHabitat if UI::DexPE::ENABLED
  end
end

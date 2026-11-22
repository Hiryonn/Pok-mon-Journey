# Carte de région : l'écran
#
# Touches : flèches = curseur, A = aperçu du lieu (puis fiche détaillée) / voler / infos du mode, B = retour,
# X = changer de mode, Y = rechercher un lieu (mode Carte) ou vol rapide (mode Vol), L / R = zoom,
# START = changer de région, SELECT = progression de la région.
# Souris : clic = curseur (deuxième clic = A), clic droit maintenu = déplacer la carte, molette = zoom.
module GamePlay
  class CarteRegion < BaseCleanUpdate::FrameBalanced
    M = ::CarteRegion
    Z = 51_000
    ZOOMS = [0.5, 1, 2].freeze

    # La fiche du Pokédex garde la carte de PSDK (carte intégrée à l'écran du Pokédex)
    def self.new(mode = :view, worldmap_id = nil, pokemon = nil)
      if mode == :pokedex || !M.setting?('replace_town_map')
        return GamePlay::WorldMap.new(mode, worldmap_id || $env.get_worldmap, pokemon)
      end

      return super
    end

    # @param mode [Symbol] :view (carte), :fly (Vol depuis l'équipe), :view_wall (carte murale, sans aperçu)
    def initialize(mode = :view, worldmap_id = nil, pokemon = nil)
      super()
      @kind = mode == :fly ? :fly : (mode == :view_wall ? :wall : :view)
      @pokemon = pokemon
      @player = M.player_position
      @worldmap_id = (@player && (worldmap_id.nil? || worldmap_id == $env.get_worldmap) ? @player[0] : worldmap_id) || 0
      @mode = @kind == :fly ? :fly : :normal
      @state = :map
      @zoom = 1.0
      @zoom_target = 1.0
      @cam_x = @cam_y = 0.0
      @pan_x = @pan_y = 0.0
      @move_timer = 0
      @anim = 0
      @cursor_anim = 0
      $wild_battle.on_map_viewed if @kind == :view && $wild_battle.respond_to?(:on_map_viewed)
    end

    def update_inputs
      case @state
      when :choice then update_choice_inputs
      when :preview then update_preview_inputs
      when :extended then update_extended_inputs
      when :map then update_map_inputs
      end
      return true
    end

    def visible=(value)
      super
      @vp_map.visible = value if @vp_map
      @vp_ui.visible = value if @vp_ui
    end

    def update_mouse(_moved)
      return true unless M.setting?('mouse')

      case @state
      when :choice then update_choice_mouse
      when :map, :preview then update_map_mouse
      end
      return true
    end

    def update_graphics
      update_zoom
      update_cursor_position
      update_camera
      place_layers
      update_cursor_animation
      update_preview_animation
      @hints&.update
      return true
    end

    def dispose
      super
      dispose_layers
      [@preview, @extended, @choice, @top, @bottom, @hints].each { |s| s&.dispose }
      @vp_map&.dispose
      @vp_ui&.dispose
      restore_music
    end

    private

    # --- Création -------------------------------------------------------------------------------------
    def create_graphics
      super
      @width = Graphics.width
      @height = Graphics.height
      @map_y = UI::CarteRegion::TopBar::HEIGHT
      @map_h = @height - @map_y - UI::CarteRegion::BottomBar::HEIGHT
      @vp_map = Viewport.create(:main, Z + 100)
      @vp_map.rect.set(0, @map_y, @width, @map_h)
      @vp_ui = Viewport.create(:main, Z + 200)
      @background = Sprite.new(@viewport)
      @layers = []
      @memorized_music = false
      load_worldmap(@worldmap_id, true)
    end

    # (Re)construit tout ce qui dépend de la carte du monde
    def load_worldmap(id, first = false)
      @worldmap_id = id
      @theme = M.theme(id)
      @grid_w, @grid_h = M.grid_size(id)
      rebuild_ui
      dispose_layers
      create_map_layers
      @modes = available_modes
      @mode = @modes.include?(@mode) ? @mode : @modes.first
      place_cursor_start
      create_mode_icons
      play_music unless first && !M.setting?('music')
      refresh_texts
      center_camera(true)
      place_layers
    end

    def rebuild_ui
      [@top, @bottom, @hints, @preview, @extended].each { |s| s&.dispose }
      # Fond derrière la carte : celui du thème (Horizon), sinon celui de la carte de PSDK
      if M.theme_has?(@theme, 'background')
        @background.set_bitmap(M.theme_file(@theme, 'background'), :interface)
      elsif RPG::Cache.interface_exist?('worldmap/background_animated')
        @background.set_bitmap('worldmap/background_animated', :interface)
      end
      @top = UI::CarteRegion::TopBar.new(@vp_ui, @theme, @width)
      @bottom = UI::CarteRegion::BottomBar.new(@vp_ui, @theme, @width, @height)
      bottom = @height - UI::CarteRegion::BottomBar::HEIGHT
      @hints = M.setting?('button_hints') ? UI::CarteRegion::ButtonHints.new(@vp_ui, @theme, @width - 4, bottom) : nil
      @preview = UI::CarteRegion::PreviewBox.new(@vp_ui, @theme, @width, bottom)
      @extended = UI::CarteRegion::ExtendedPanel.new(@vp_ui, @theme, 6, @map_y + 4, @width - 12, @map_h - 8)
    end

    def map_file
      base = M.worldmap(@worldmap_id)&.image.to_s
      if M.setting?('time_based') && !base.empty?
        suffix = time_suffix
        return "#{base}#{suffix}" if suffix && RPG::Cache.interface_exist?("#{base}#{suffix}")
      end
      return base
    end

    def time_suffix
      return '_nuit' if $env.night?
      return '_matin' if $env.morning?
      return '_soir' if $env.sunset?
      return '_jour' if $env.day?

      return nil
    rescue StandardError
      return nil
    end

    # Calque : [sprite, x sur la carte, y sur la carte, suit le zoom ?]
    def add_layer(sprite, bx, by, scaled = true)
      @layers << [sprite, bx, by, scaled]
      return sprite
    end

    def create_map_layers
      file = map_file
      @map_sprite = add_layer(Sprite.new(@vp_map), 0, 0)
      if !file.empty? && RPG::Cache.interface_exist?(file)
        @map_sprite.set_bitmap(file, :interface)
        @map_w = @map_sprite.bitmap.width
        @map_h_px = @map_sprite.bitmap.height
      else
        @map_w = @grid_w * M::TILE
        @map_h_px = @grid_h * M::TILE
      end
      @map_w = [@map_w, @grid_w * M::TILE].max
      @map_h_px = [@map_h_px, @grid_h * M::TILE].max
      create_decorations(false)
      create_unvisited_layer
      create_decorations(true)
      @highlight = add_layer(Sprite.new(@vp_map), 0, 0)
      @highlight_zone = :none
      @player_sprite = nil
      create_player_icon
      @cursor = Sprite.new(@vp_map)
      @cursor.set_bitmap(M.theme_file(@theme, 'cursor'), :interface)
      @cursor.src_rect.set(0, 0, 22, 22)
      @cursor.ox = @cursor.oy = 11
      @cursor.z = 10
      @layers << [@cursor, 0, 0, :cursor]
    end

    def create_decorations(above)
      M.region_list(@worldmap_id, :decorations).each do |deco|
        next if (M.fetch(deco, :above) == true) != above
        next unless M.switch?(M.fetch(deco, :switch))

        file = "#{M::DIR}decorations/#{M.fetch(deco, :image).to_s.sub(/\.png\z/i, '')}"
        next unless RPG::Cache.interface_exist?(file)

        sprite = Sprite.new(@vp_map).set_bitmap(file, :interface)
        add_layer(sprite, M.fetch(deco, :x).to_i * M::TILE, M.fetch(deco, :y).to_i * M::TILE)
      end
    end

    # Lieux pas encore visités (ou cachés) : cases assombries
    def create_unvisited_layer
      return unless M.setting?('mark_unvisited')

      cells = M.cells(@worldmap_id).reject { |id, _| M.visited?(id) && !M.hidden?(id) }.values.flatten(1)
      bmp = M.cells_bitmap(@map_w, @map_h_px, cells, Array(M.setting('unvisited_color')))
      return unless bmp

      @unvisited_bmp = bmp
      sprite = Sprite.new(@vp_map)
      sprite.bitmap = bmp
      add_layer(sprite, 0, 0)
    end

    def create_player_icon
      return unless @player && @player[0] == @worldmap_id && M.setting?('show_player')
      return if M.fetch(M.region(@worldmap_id), :show_player) == false

      female = $game_switches[Yuki::Sw::Gender] ? 'f' : 'm'
      file = "worldmap/player_icons/#{$game_player.charset_base}_#{female}"
      file = 'worldmap/player_icons/default' unless RPG::Cache.interface_exist?(file)
      @player_sprite = icon_at(file, @player[1], @player[2])
      @player_sprite.z = 30
    end

    # Icône centrée sur une case (ne suit pas le zoom, pour rester lisible)
    def icon_at(file, x, y)
      sprite = Sprite.new(@vp_map)
      sprite.z = 20
      if file
        sprite.set_bitmap(file, :interface)
        sprite.ox = sprite.bitmap.width / 2
        sprite.oy = sprite.bitmap.height / 2
      end
      return add_layer(sprite, x * M::TILE + M::TILE / 2, y * M::TILE + M::TILE / 2, :icon)
    end

    def dispose_layers
      Array(@layers).each { |sprite, _, _, _| sprite.dispose unless sprite.disposed? }
      @layers = []
      @unvisited_bmp&.dispose
      @unvisited_bmp = nil
      @highlight_bmp&.dispose
      @highlight_bmp = nil
      @mode_icons = []
      @markers = {}
    end

    def clear_mode_icons
      Array(@mode_icons).each do |sprite|
        @layers.reject! { |s, _, _, _| s == sprite }
        sprite.dispose
      end
      @mode_icons = []
    end

    # Icônes du mode (vol, quêtes, baies, errants, revanches)
    def create_mode_icons
      clear_mode_icons
      @markers = {}
      case @mode
      when :fly
        M.fly_spots(@worldmap_id).each { |zone_id, x, y| add_marker(M.icon_file('fly'), x, y, zone_id) }
      when :quest
        M.quest_markers(@worldmap_id).each do |q|
          color = q[:color].to_s.empty? ? 'quest' : "quest_#{q[:color]}"
          color = 'quest' unless RPG::Cache.interface_exist?(M.icon_file(color))
          add_marker(M.icon_file(color), q[:x], q[:y], q)
        end
      when :berry
        M.berries(@worldmap_id).each do |zone_id, list|
          x, y = M.anchor(@worldmap_id, zone_id)
          next unless x

          icon = list.any? { |b| b[:stage] >= 4 } ? 'berry_ready' : (list.any? { |b| !b[:watered] } ? 'berry_dry' : 'berry')
          add_marker(M.icon_file(icon), x, y, zone_id)
        end
      when :roaming
        M.roamers(@worldmap_id).each do |r|
          x, y = M.anchor(@worldmap_id, r[:zone_id])
          next unless x

          file = "worldmap/pokemons_icons/#{r[:pokemon].character_name}" rescue nil
          file = M.icon_file('unknown') unless file && RPG::Cache.interface_exist?(file)
          add_marker(file, x, y, r)
        end
      when :trainer
        M.trainer_markers(@worldmap_id).each { |tr| add_trainer_marker(tr) }
      end
    end

    def add_marker(file, x, y, data)
      sprite = icon_at(file, x, y)
      @mode_icons << sprite
      (@markers[[x, y]] ||= []) << data
    end

    def add_trainer_marker(tr)
      x = M.fetch(tr, :x).to_i
      y = M.fetch(tr, :y).to_i
      charset = M.fetch(tr, :character).to_s
      if !charset.empty? && RPG::Cache.character_exist?(charset)
        bmp = RPG::Cache.character(charset)
        fw = bmp.width / 4
        fh = bmp.height / 4
        sprite = icon_at(nil, x, y)
        sprite.set_bitmap(charset, :character)
        sprite.src_rect.set(0, 0, fw, fh)
        sprite.ox = fw / 2
        sprite.oy = fh / 2 + 4
        sprite.zoom = fh > 24 ? 0.5 : 1
        @mode_icons << sprite
        (@markers[[x, y]] ||= []) << tr
      else
        add_marker(M.icon_file('trainer'), x, y, tr)
      end
    rescue StandardError
      add_marker(M.icon_file('trainer'), x, y, tr)
    end

    # --- Modes ----------------------------------------------------------------------------------------
    def available_modes
      return [:fly] if @kind == :fly
      return [:normal] if @kind == :wall

      list = [:normal]
      same_region = @player && @player[0] == @worldmap_id
      if M.mode_enabled?(:fly) && M.can_fly_from_map? && (same_region || M.setting?('fly_other_regions')) &&
         !M.fly_spots(@worldmap_id).empty?
        list << :fly
      end
      list << :quest if M.mode_enabled?(:quest) && !M.quest_markers(@worldmap_id).empty?
      list << :berry if M.mode_enabled?(:berry) && !M.berries(@worldmap_id).empty?
      list << :roaming if M.mode_enabled?(:roaming) && !M.roamers(@worldmap_id).empty?
      list << :trainer if M.mode_enabled?(:trainer) && !M.trainer_markers(@worldmap_id).empty?
      return list
    end

    def mode_name(mode = @mode)
      return M.pair(M::MODE_NAMES[mode])
    end

    def switch_mode
      return if @modes.size < 2

      if @modes.size == 2
        play_decision_se
        set_mode(@modes[(@modes.index(@mode).to_i + 1) % 2])
      else
        play_decision_se
        open_choice(:mode, M.t('Mode de la carte', 'Map mode'), @modes.map { |m| mode_name(m) }, @modes.index(@mode)) do |i|
          set_mode(@modes[i]) if i
        end
      end
    end

    def set_mode(mode)
      @mode = mode
      hide_preview(true)
      create_mode_icons
      refresh_texts
    end

    # --- Curseur, caméra, zoom ------------------------------------------------------------------------
    def place_cursor_start
      if @player && @player[0] == @worldmap_id
        @cx = @player[1]
        @cy = @player[2]
      elsif (spot = M.cells(@worldmap_id).keys.find { |id| M.visited?(id) }) && (pos = M.anchor(@worldmap_id, spot))
        @cx, @cy = pos
      else
        @cx = @grid_w / 2
        @cy = @grid_h / 2
      end
      @cx = @cx.clamp(0, [@grid_w - 1, 0].max)
      @cy = @cy.clamp(0, [@grid_h - 1, 0].max)
      @cur_px = @cx * M::TILE.to_f
      @cur_py = @cy * M::TILE.to_f
      @pan_x = @pan_y = 0.0
    end

    def zone_here
      return M.zone_at(@worldmap_id, @cx, @cy)
    end

    def move_cursor(dx, dy)
      nx = @cx + dx
      ny = @cy + dy
      if !nx.between?(0, @grid_w - 1) || !ny.between?(0, @grid_h - 1)
        return if try_connection(nx, ny)

        nx = nx.clamp(0, @grid_w - 1)
        ny = ny.clamp(0, @grid_h - 1)
      end
      return if nx == @cx && ny == @cy

      old_zone = zone_here
      @cx = nx
      @cy = ny
      @pan_x = @pan_y = 0.0
      @move_timer = [M.setting('cursor_frames').to_i, 1].max
      hide_preview(false) if @state == :preview && zone_here != old_zone
      refresh_texts
    end

    def jump_cursor(x, y)
      @cx = x.clamp(0, [@grid_w - 1, 0].max)
      @cy = y.clamp(0, [@grid_h - 1, 0].max)
      @pan_x = @pan_y = 0.0
      refresh_texts
    end

    # Régions reliées : sortir par un bord mène à la carte voisine
    def try_connection(nx, ny)
      side = if nx < 0 then 'left'
             elsif nx >= @grid_w then 'right'
             elsif ny < 0 then 'up'
             else 'down'
             end
      link = M.region_list(@worldmap_id, :connections).find { |c| M.fetch(c, :side).to_s == side }
      return false unless link

      target = M.fetch(link, :worldmap).to_i
      return false unless M.worldmap(target) && target != @worldmap_id

      offset = M.fetch(link, :offset).to_i
      x = @cx
      y = @cy
      load_worldmap(target)
      case side
      when 'left' then x = @grid_w - 1; y += offset
      when 'right' then x = 0; y += offset
      when 'up' then y = @grid_h - 1; x += offset
      else y = 0; x += offset
      end
      jump_cursor(x, y)
      @cur_px = @cx * M::TILE.to_f
      @cur_py = @cy * M::TILE.to_f
      center_camera(true)
      play_cursor_se
      return true
    end

    def update_cursor_position
      tx = @cx * M::TILE.to_f
      ty = @cy * M::TILE.to_f
      frames = [M.setting('cursor_frames').to_i, 1].max
      @move_timer -= 1 if @move_timer > 0
      @cur_px += (tx - @cur_px) / [@move_timer + 1, 1].max.to_f
      @cur_py += (ty - @cur_py) / [@move_timer + 1, 1].max.to_f
      @cur_px = tx if (tx - @cur_px).abs < 0.05 || frames <= 1
      @cur_py = ty if (ty - @cur_py).abs < 0.05 || frames <= 1
    end

    def view_w
      return @width / @zoom
    end

    def view_h
      return @map_h / @zoom
    end

    def camera_target
      vw = view_w
      vh = view_h
      tx = if @map_w <= vw then -(vw - @map_w) / 2.0
           else (@cur_px + M::TILE / 2 - vw / 2 + @pan_x).clamp(0, @map_w - vw)
           end
      ty = if @map_h_px <= vh then -(vh - @map_h_px) / 2.0
           else (@cur_py + M::TILE / 2 - vh / 2 + @pan_y).clamp(0, @map_h_px - vh)
           end
      return [tx, ty]
    end

    def center_camera(instant = false)
      @cam_x, @cam_y = camera_target if instant
    end

    def update_camera
      tx, ty = camera_target
      @cam_x += (tx - @cam_x) * 0.35
      @cam_y += (ty - @cam_y) * 0.35
      @cam_x = tx if (tx - @cam_x).abs < 0.3
      @cam_y = ty if (ty - @cam_y).abs < 0.3
    end

    def zoom_levels
      list = ZOOMS.select { |z| z >= 1 || @map_w > @width || @map_h_px > @map_h }
      return list
    end

    def change_zoom(dir)
      return unless M.setting?('zoom')

      levels = zoom_levels
      index = levels.index(levels.min_by { |z| (z - @zoom_target).abs }).to_i + dir
      return unless index.between?(0, levels.size - 1)

      @zoom_target = levels[index]
      play_cursor_se
    end

    def update_zoom
      return if @zoom == @zoom_target

      @zoom += (@zoom_target - @zoom) * 0.3
      @zoom = @zoom_target if (@zoom_target - @zoom).abs < 0.01
    end

    # Place les calques selon la caméra et le zoom
    def place_layers
      @layers.each do |sprite, bx, by, scaled|
        next if sprite.disposed? || scaled == :cursor

        sprite.x = ((bx - @cam_x) * @zoom).round
        sprite.y = ((by - @cam_y) * @zoom).round
        sprite.zoom = @zoom if scaled == true
      end
      return unless @cursor

      @cursor.x = ((@cur_px + M::TILE / 2 - @cam_x) * @zoom).round
      @cursor.y = ((@cur_py + M::TILE / 2 - @cam_y) * @zoom).round
    end

    def update_cursor_animation
      @cursor_anim = (@cursor_anim + 1) % 40
      @cursor&.src_rect&.x = @cursor_anim < 20 ? 0 : 22
      update_highlight
    end

    # Cases du lieu sous le curseur, éclairées
    def update_highlight
      zone_id = zone_here
      return if zone_id == @highlight_zone

      @highlight_zone = zone_id
      old = @highlight_bmp
      @highlight_bmp = nil
      if zone_id && M.setting?('highlight') && !M.hidden?(zone_id)
        @highlight_bmp = M.cells_bitmap(@map_w, @map_h_px, M.zone_cells(@worldmap_id, zone_id), Array(M.setting('highlight_color')))
      end
      if @highlight_bmp
        @highlight.bitmap = @highlight_bmp
        @highlight.visible = true
      else
        @highlight.visible = false
      end
      old&.dispose
    end

    # --- Textes ---------------------------------------------------------------------------------------
    def refresh_texts
      @top.region = M.worldmap(@worldmap_id)&.name.to_s
      @top.mode = @modes.size > 1 || @kind == :fly ? mode_name : ''
      if M.setting?('progress') && @kind != :fly
        visited = M.progress(@worldmap_id).first
        @top.info = visited ? M.t("Exploré : #{M.percent(visited[1], visited[2])} %", "Explored: #{M.percent(visited[1], visited[2])}%") : ''
      else
        @top.info = ''
      end
      zone_id = zone_here
      name = zone_id ? M.zone_name(zone_id) : ''
      detail = M.district(@worldmap_id, @cx, @cy)
      case @mode
      when :fly
        detail = zone_id && M.flyable?(zone_id) ? M.t('Vol possible', 'Can fly here') : detail
      when :quest
        list = Array(@markers[[@cx, @cy]])
        detail = list.size == 1 ? M.quest_name(list.first[:id]) : (list.empty? ? detail : M.t("#{list.size} quêtes", "#{list.size} quests"))
      when :berry
        n = zone_id ? M.berries(@worldmap_id)[zone_id].size : 0
        detail = n > 0 ? M.t("#{n} baie(s)", "#{n} berr#{n > 1 ? 'ies' : 'y'}") : detail
      end
      @bottom.set(name, detail)
      refresh_hints
    end

    def refresh_hints
      return unless @hints

      list = []
      case @mode
      when :normal
        list << M.t('A : aperçu', 'A: preview') if @kind == :view && M.setting?('preview')
        list << M.t('Y : rechercher', 'Y: search') if can_search?
      when :fly
        list << M.t('A : voler', 'A: fly')
        list << M.t('Y : vol rapide', 'Y: quick fly') if M.setting?('quick_fly')
      else
        list << M.t('A : infos', 'A: info')
      end
      list << M.t('X : mode', 'X: mode') if @modes.size > 1
      list << M.t('L / R : zoom', 'L / R: zoom') if M.setting?('zoom') && zoom_levels.size > 1
      list << M.t('START : région', 'START: region') if region_choices.size > 1
      list << M.t('SELECT : progression', 'SELECT: progress') if M.setting?('progress') && @kind == :view
      list << M.t('B : quitter', 'B: quit')
      @hints.hints = list
    end

    # --- Entrées de la carte --------------------------------------------------------------------------
    def update_map_inputs
      return @running = false if Input.trigger?(:B) && @state == :map

      if @move_timer <= 0 && (dir = Input.dir8) != 0
        dx = [1, 4, 7].include?(dir) ? -1 : ([3, 6, 9].include?(dir) ? 1 : 0)
        dy = [7, 8, 9].include?(dir) ? -1 : ([1, 2, 3].include?(dir) ? 1 : 0)
        move_cursor(dx, dy)
      end
      if Input.trigger?(:A)
        action_a
      elsif Input.trigger?(:X)
        switch_mode
      elsif Input.trigger?(:Y)
        @mode == :fly ? quick_fly : search
      elsif Input.trigger?(:L)
        change_zoom(-1)
      elsif Input.trigger?(:R)
        change_zoom(1)
      elsif Input.trigger?(:START)
        choose_region
      elsif Input.trigger?(:SELECT) && M.setting?('progress') && @kind == :view
        show_progress
      end
    end

    def update_map_mouse
      if Mouse.wheel != 0
        change_zoom(Mouse.wheel <=> 0)
        Mouse.wheel = 0
      end
      if Mouse.press?(:RIGHT)
        if @drag
          @pan_x -= (Mouse.x - @drag[0]) / @zoom
          @pan_y -= (Mouse.y - @drag[1]) / @zoom
        end
        @drag = [Mouse.x, Mouse.y]
        return
      end
      @drag = nil
      return unless Mouse.trigger?(:LEFT)
      return unless Mouse.y.between?(@map_y, @map_y + @map_h - 1)

      x = ((Mouse.x / @zoom + @cam_x) / M::TILE).floor
      y = (((Mouse.y - @map_y) / @zoom + @cam_y) / M::TILE).floor
      return unless x.between?(0, @grid_w - 1) && y.between?(0, @grid_h - 1)

      if x == @cx && y == @cy
        action_a
      else
        play_cursor_se
        hide_preview(false) if @state == :preview
        jump_cursor(x, y)
      end
    end

    # A : selon le mode
    def action_a
      return show_location_preview if @state == :map && @mode == :normal
      return show_extended if @state == :preview && @preview_kind == :location

      case @mode
      when :fly then fly_here
      when :quest then show_quest
      when :berry then show_berries
      when :roaming then show_roamers
      when :trainer then show_trainer
      end
    end

    # --- Aperçus --------------------------------------------------------------------------------------
    def show_location_preview
      return unless @kind == :view && M.setting?('preview')

      zone_id = zone_here
      return play_buzzer_se unless zone_id && !M.hidden?(zone_id)

      play_decision_se
      visited = M.visited?(zone_id)
      body = []
      text = visited ? M.description(zone_id) : ''
      text = M.t('Aucune information.', 'No information available.') if text.empty? && !visited
      image = visited ? M.zone_image(zone_id) : nil
      lines = @preview.wrap(text, @width - 32 - (image ? M.preview_image_width(image) + 8 : 0))
      body.concat(lines.first(M.setting('max_description_lines').to_i.clamp(1, 8))) unless text.empty?
      if visited
        dirs = M.neighbours(@worldmap_id, zone_id)
        dirs.each_slice(2) { |pair| body << pair.map { |d, name, _| "#{d} : #{name}" }.join('    ') }
      end
      footer = nil
      if visited && M.setting?('extended_preview')
        footer = M.t('A : fiche détaillée', 'A: details')
      end
      weather = M.setting?('weather_preview') && visited ? M.weather(zone_id) : nil
      @preview.show(M.zone_name(zone_id), body, image: visited ? M.zone_image(zone_id) : nil, weather: weather, footer: footer, max_lines: 10)
      open_preview(:location)
    end

    def show_extended
      zone_id = zone_here
      return play_buzzer_se unless zone_id && M.visited?(zone_id) && M.setting?('extended_preview')

      play_decision_se
      @extended.open(M.zone_name(zone_id), zone_id, @worldmap_id)
      @preview.hide
      @state = :extended
      @hints&.shown = false
    end

    def show_quest
      list = Array(@markers[[@cx, @cy]])
      return play_buzzer_se if list.empty?

      play_decision_se
      if list.size == 1
        quest_preview(list.first[:id])
      else
        names = list.map { |q| M.quest_name(q[:id]) }
        open_choice(:quest, M.t('Quelle quête ?', 'Which quest?'), names, 0) { |i| quest_preview(list[i][:id]) if i }
      end
    end

    def quest_preview(id)
      body = @preview.wrap(M.quest_description(id), @width - 32).first(4)
      M.quest_goals(id).each { |text, done| body << "#{done ? '✔' : '•'} #{text}" }
      @preview.show(M.quest_name(id), body, max_lines: 10)
      open_preview(:quest)
    end

    def show_berries
      zone_id = zone_here
      list = zone_id ? M.berries(@worldmap_id)[zone_id] : []
      return play_buzzer_se if list.empty?

      play_decision_se
      body = list.map do |b|
        name = (data_item(b[:berry]).name rescue '?')
        water = b[:stage] < 4 ? (b[:watered] ? M.t(' (arrosée)', ' (watered)') : M.t(' (sèche)', ' (dry)')) : ''
        "#{name} : #{M.berry_stage_text(b[:stage])}#{water}"
      end
      @preview.show(M.zone_name(zone_id), body, max_lines: 10)
      open_preview(:berry)
    end

    def show_roamers
      list = Array(@markers[[@cx, @cy]])
      return play_buzzer_se if list.empty?

      play_decision_se
      body = list.map { |r| "#{r[:pokemon].name} N.#{r[:pokemon].level}" }
      @preview.show(M.zone_name(list.first[:zone_id]), body, max_lines: 10)
      open_preview(:roaming)
    end

    def show_trainer
      list = Array(@markers[[@cx, @cy]])
      return play_buzzer_se if list.empty?

      play_decision_se
      tr = list.first
      text = M.localized(M.fetch(tr, :text))
      text = M.t('Ce dresseur veut une revanche !', 'This trainer wants a rematch!') if text.empty?
      @preview.show(M.localized(M.fetch(tr, :name)), @preview.wrap(text, @width - 32), max_lines: 6)
      open_preview(:trainer)
    end

    def show_progress
      play_decision_se
      body = M.progress(@worldmap_id).map { |label, done, total| "#{label} : #{done} / #{total}  (#{M.percent(done, total)} %)" }
      @preview.show(M.t('Progression', 'Progress') + " — #{M.worldmap(@worldmap_id)&.name}", body, max_lines: 8)
      open_preview(:progress)
    end

    def open_preview(kind)
      @preview_kind = kind
      @state = :preview
      @anim = M.setting?('preview_animation') ? 1 : 8
      @preview.slide(@anim / 8.0)
      @hints&.shown = false
    end

    def hide_preview(sound = true)
      return unless @state == :preview || @preview.visible

      play_cancel_se if sound
      @preview.hide
      @state = :map
      @anim = 0
      @hints&.shown = true
    end

    def update_preview_animation
      return unless @state == :preview && @anim < 8

      @anim += 1
      @preview.slide(@anim / 8.0)
    end

    def update_preview_inputs
      if Input.trigger?(:B)
        hide_preview
      elsif Input.trigger?(:A)
        action_a if @preview_kind == :location
      else
        update_map_inputs_moves_only
      end
    end

    # Pendant l'aperçu : le curseur bouge toujours (l'aperçu se ferme si l'on change de lieu)
    def update_map_inputs_moves_only
      return unless @move_timer <= 0 && (dir = Input.dir8) != 0

      dx = [1, 4, 7].include?(dir) ? -1 : ([3, 6, 9].include?(dir) ? 1 : 0)
      dy = [7, 8, 9].include?(dir) ? -1 : ([1, 2, 3].include?(dir) ? 1 : 0)
      move_cursor(dx, dy)
    end

    def update_extended_inputs
      result = @extended.update_inputs
      play_cursor_se if result == :move
      return unless result == :close

      play_cancel_se
      @extended.visible = false
      @extended.dispose_dynamic
      @state = :map
      @hints&.shown = true
    end

    # --- Listes de choix ------------------------------------------------------------------------------
    def open_choice(key, title, items, index = nil, &block)
      @choice&.dispose
      index ||= M.last_choice(key)
      top = @map_y
      bottom = @height - UI::CarteRegion::BottomBar::HEIGHT
      @choice = UI::CarteRegion::ChoiceList.new(@vp_ui, @theme, title, items, M.setting('max_choices').to_i.clamp(2, 12),
                                                 @width, top, bottom, index.to_i)
      @choice_key = key
      @choice_callback = block
      @previous_state = @state == :choice ? :map : @state
      @state = :choice
      @hints&.shown = false
    end

    def close_choice(result)
      callback = @choice_callback
      M.remember_choice(@choice_key, result) if result.is_a?(Integer)
      @choice&.dispose
      @choice = nil
      @state = @previous_state == :preview ? :map : (@previous_state || :map)
      @hints&.shown = @state == :map
      callback&.call(result.is_a?(Integer) ? result : nil)
    end

    def update_choice_inputs
      result = @choice.update_inputs
      handle_choice(result)
    end

    def update_choice_mouse
      handle_choice(@choice.update_mouse) if @choice
    end

    def handle_choice(result)
      case result
      when :move then play_cursor_se
      when :cancel
        play_cancel_se
        close_choice(nil)
      when Integer
        play_decision_se
        close_choice(result)
      end
    end

    # --- Recherche ------------------------------------------------------------------------------------
    def search_places(filter = nil)
      unvisited = M.setting?('search_unvisited')
      list = M.cells(@worldmap_id).keys.reject { |id| M.hidden?(id) }.select { |id| unvisited || M.visited?(id) }
      list = list.map { |id| [id, unvisited ? M.real_name(id) : M.zone_name(id)] }.uniq { |_, name| name }
      list = list.select { |_, name| name.downcase.include?(filter.downcase) } if filter && !filter.empty?
      list = @search_sorted ? list.sort_by { |_, name| name.downcase } : list.sort_by { |id, _| (M.anchor(@worldmap_id, id) || [0, 0]).reverse }
      return list
    end

    def can_search?
      return @kind == :view && M.setting?('search') && search_places.size >= M.setting('search_min').to_i
    end

    def search(filter = nil)
      return play_buzzer_se unless can_search?

      play_decision_se
      places = search_places(filter)
      items = [M.t('Filtrer…', 'Filter…'), @search_sorted ? M.t('Tri : position', 'Order: position') : M.t('Tri : A → Z', 'Order: A → Z')]
      items += places.map(&:last)
      items << M.t('(aucun résultat)', '(no result)') if places.empty?
      current = places.index { |id, _| id == zone_here }
      title = filter.to_s.empty? ? M.t('Rechercher un lieu', 'Find a place') : M.t("Recherche : #{filter}", "Search: #{filter}")
      open_choice(:search, title, items, current ? current + 2 : nil) do |i|
        if i == 0
          ask_filter
        elsif i == 1
          @search_sorted = !@search_sorted
          search(filter)
        elsif i && (place = places[i - 2]) && (pos = M.anchor(@worldmap_id, place[0]))
          jump_cursor(*pos)
        end
      end
    end

    # Filtre de la recherche : saisie du texte avec l'écran de nom de PSDK
    def ask_filter
      @filter_result = ''
      call_scene(GamePlay::NameInput, '', 12, nil, phrase: M.t('Quel lieu chercher ?', 'Which place?')) do |scene|
        @filter_result = scene.return_name.to_s
      end
      search(@filter_result.strip)
    rescue StandardError => e
      log_error("Carte de région : saisie impossible (#{e.message})") if respond_to?(:log_error, true)
      search
    end

    # --- Vol ------------------------------------------------------------------------------------------
    def quick_fly
      return play_buzzer_se unless M.setting?('quick_fly')

      spots = M.fly_spots(@worldmap_id)
      return play_buzzer_se if spots.empty?

      play_decision_se
      current = spots.index { |id, _, _| id == zone_here }
      open_choice(:quick_fly, M.t('Voler vers…', 'Fly to…'), spots.map { |id, _, _| M.real_name(id) }, current) do |i|
        next unless i

        _, x, y = spots[i]
        jump_cursor(x, y)
        fly_here if M.setting?('auto_cursor')
      end
    end

    def fly_here
      zone_id = zone_here
      return play_buzzer_se unless zone_id && M.flyable?(zone_id)
      return play_buzzer_se if @player && @player[0] != @worldmap_id && !M.setting?('fly_other_regions')

      play_decision_se
      name = M.real_name(zone_id)
      open_choice(:fly_confirm, M.t("Voler vers #{name} ?", "Fly to #{name}?"), [M.t('Oui', 'Yes'), M.t('Non', 'No')], 0) do |i|
        do_fly(zone_id) if i == 0
      end
    end

    # Même déroulement que la carte de PSDK (évènement commun 15)
    def do_fly(zone_id)
      zone = M.zone(zone_id)
      $game_player.fly_reset_attributes
      $game_variables[::Yuki::Var::TMP1] = zone.maps.first
      $game_variables[::Yuki::Var::TMP2] = zone.warp.x
      $game_variables[::Yuki::Var::TMP3] = zone.warp.y
      $game_temp.common_event_id = 15
      Yuki::FollowMe.smart_enable unless $game_switches[::Yuki::Sw::EV_Bicycle] || $game_switches[::Yuki::Sw::EV_AccroBike]
      return_to_scene(Scene_Map)
      $game_player.return_to_previous_state
    end

    # --- Régions --------------------------------------------------------------------------------------
    def region_choices
      return [] if @kind == :fly && !M.setting?('fly_other_regions')

      return M.worldmap_ids.select { |id| id == @worldmap_id || $env.visited_worldmap?(id) || $DEBUG || visited_any?(id) }
    end

    def visited_any?(id)
      return M.cells(id).keys.any? { |zone_id| M.visited?(zone_id) }
    end

    def choose_region
      ids = region_choices
      return play_buzzer_se if ids.size < 2

      play_decision_se
      open_choice(:region, M.t('Changer de région', 'Change region'), ids.map { |id| M.worldmap(id)&.name.to_s }, ids.index(@worldmap_id)) do |i|
        if i && ids[i] != @worldmap_id
          load_worldmap(ids[i])
          @zoom = @zoom_target = 1.0
        end
      end
    end

    # --- Musique --------------------------------------------------------------------------------------
    def play_music
      return unless M.setting?('music') && (music = M.music(@worldmap_id))

      unless @memorized_music
        $game_system.bgm_memorize
        @memorized_music = true
      end
      $game_system.bgm_play(RPG::AudioFile.new(music[0], music[1], music[2]))
    rescue StandardError
      nil
    end

    def restore_music
      return unless @memorized_music

      $game_system.bgm_restore
    rescue StandardError
      nil
    end
  end
end

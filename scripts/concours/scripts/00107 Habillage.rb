# Concours : épreuve d'habillage (écran de la Mallette et cadre photo), puis défilé des concurrents
#
# Habillage : le joueur a un temps limité (réglage dressup_time) pour accrocher des accessoires de sa Mallette sur
# la photo de son Pokémon (au plus max_accessories selon le rang) et choisir un fond.
#   Souris : clic gauche pour prendre un accessoire et le glisser (ou cliquer pour le prendre, puis cliquer pour le
#            poser), clic droit pour déplacer le Pokémon ; un accessoire lâché hors de la photo retourne dans la Mallette.
#   Clavier : flèches pour le pointeur, A pour prendre / poser (A sur le Pokémon pour le déplacer), B pour reposer
#            dans la Mallette, X pour passer des accessoires aux fonds, L / R pour changer de page.
# Points : somme des points des accessoires accrochés pour le thème (0 à 3 chacun).
module Concours
  # Photo d'un concurrent : fond, Pokémon et accessoires, coupés au cadre (112 x 128)
  class Photo
    WIDTH = 112
    HEIGHT = 128
    POSE = [56, 124].freeze

    attr_reader :viewport, :pokemon

    # @param x [Integer]
    # @param y [Integer]
    # @param z [Integer] z du viewport
    def initialize(x, y, z)
      @viewport = Viewport.create(:main, z)
      Ecran.placer(@viewport, x, y, WIDTH, HEIGHT)
      @back = Sprite.new(@viewport)
      @pokemon = UI::PokemonFaceSprite.new(@viewport)
      @picture = Sprite.new(@viewport)
      @pieces = []
    end

    # @param entrant [Entrant]
    # @param rank [String]
    def show(entrant, rank)
      clear
      picture = "concurrents/#{rank}/#{entrant.picture}"
      if !entrant.player && !entrant.picture.to_s.empty? && Concours.image?(picture)
        @back.visible = @pokemon.visible = false
        @picture.set_bitmap(Concours.file(picture), :interface)
        @picture.visible = true
        return
      end
      self.backdrop = entrant.backdrop
      @pokemon.data = entrant.pokemon
      pose = entrant.pose || POSE
      @pokemon.set_position(pose[0], pose[1])
      Array(entrant.worn).each { |id, px, py| add(id, px, py) }
    end

    def backdrop=(id)
      image = id.to_s.empty? ? nil : Concours.backdrop_image(id)
      if image && RPG::Cache.interface_exist?(image)
        @back.set_bitmap(image, :interface)
        @back.visible = true
      else
        @back.visible = false
      end
    end

    # @return [Sprite]
    def add(id, x, y)
      sprite = Sprite.new(@viewport)
      sprite.set_bitmap(Concours.accessory_image(id), :interface)
      sprite.set_origin(sprite.width / 2, sprite.height / 2)
      sprite.set_position(x, y)
      @pieces << sprite
      return sprite
    end

    def remove(sprite)
      @pieces.delete(sprite)
      sprite.dispose
    end

    def clear
      @pieces.each(&:dispose)
      @pieces.clear
      @picture.visible = false
    end

    def visible=(value)
      @viewport.visible = value
    end

    def dispose
      clear
      [@back, @pokemon, @picture].each(&:dispose)
      @viewport.dispose
    end
  end

  class DressupScene < GamePlay::BaseCleanUpdate
    WHITE = 10
    DARK = 0
    RED = 2
    GRID_X = 12
    GRID_Y = 46
    CELL = 32
    COLUMNS = 4
    PER_PAGE = 16
    PHOTO_X = 186
    PHOTO_Y = 34
    # Boutons : [x, y, largeur, hauteur]
    BUTTONS = {
      up: [10, 207, 32, 26], down: [46, 207, 32, 26], accessories: [96, 203, 34, 33], backdrops: [134, 203, 34, 33],
      done: [238, 207, 76, 26]
    }.freeze

    # @param entrant [Entrant] le joueur
    # @param theme [Integer]
    # @param rank [String]
    def initialize(entrant, theme, rank)
      super()
      @entrant = entrant
      @theme = theme
      @rank = rank
      @max = Concours.max_accessories(rank)
      @time = Concours.setting('dressup_time').to_i.clamp(10, 600) * 60
      @mode = :accessories
      @page = 0
      @worn = []
      @backdrop = Concours.data['backdrops'].first.to_s
      @px = 160
      @py = 120
      @held = nil
      @started = false
      @hold_frames = 0
      @last_mouse = nil
    end

    def update_inputs
      return start_dressup unless @started
      return finish(true) if @time <= 0

      tick_timer
      update_pointer
      @held ? update_held : update_free
      return true
    end

    def update_graphics
      @pointer&.set_position(@px, @py)
      return true
    end

    def dispose
      super
      @photo&.dispose
      @top_viewport&.dispose
    end

    private

    # --- Création -----------------------------------------------------------------------------------------------------
    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Concours.file('habillage'))
      @stack.add_text(6, 1, 220, 16, Concours.t("Thème : #{Concours.theme_name(@theme)}", "Theme: #{Concours.theme_name(@theme)}"),
                      0, color: WHITE)
      @timer_text = @stack.add_text(244, 1, 70, 16, '', 2, color: WHITE)
      @page_text = @stack.add_text(14, 27, 126, 16, '', 1, color: WHITE)
      @hover_text = @stack.add_text(8, 179, 138, 16, '', 1, color: DARK)
      @backdrop_text = @stack.add_text(176, 172, 132, 16, '', 1, color: DARK)
      @count_text = @stack.add_text(176, 186, 132, 16, '', 1, color: DARK)
      @cells = Array.new(PER_PAGE) do |i|
        x = GRID_X + (i % COLUMNS) * CELL
        y = GRID_Y + (i / COLUMNS) * CELL
        cell = @stack.add_sprite(x, y, Concours.file('case_habillage'))
        item = @stack.add_sprite(x + 15, y + 15, nil)
        count = @stack.with_font(20) { @stack.add_text(x + 1, y + 19, 28, 12, '', 2, color: DARK) }
        { cell: cell, item: item, count: count }
      end
      @cell_cursor = @stack.add_sprite(0, 0, Concours.file('curseur_habillage'))
      @cell_cursor.visible = false
      @stack.add_sprite(*BUTTONS[:up][0, 2], Concours.file('bouton_haut'))
      @stack.add_sprite(*BUTTONS[:down][0, 2], Concours.file('bouton_bas'))
      @tab_accessories = @stack.add_sprite(*BUTTONS[:accessories][0, 2], Concours.file('onglet_accessoires'))
      @tab_backdrops = @stack.add_sprite(*BUTTONS[:backdrops][0, 2], Concours.file('onglet_fonds'))
      @stack.add_sprite(*BUTTONS[:done][0, 2], Concours.file('bouton'))
      @stack.add_text(BUTTONS[:done][0], BUTTONS[:done][1] + 5, 76, 16, Concours.t('Terminé', 'Done'), 1, color: WHITE)
      @photo = Photo.new(PHOTO_X, PHOTO_Y, @viewport.z + 1)
      @photo.backdrop = @backdrop
      @photo.pokemon.data = @entrant.pokemon
      @photo.pokemon.set_position(*Photo::POSE)
      @top_viewport = Viewport.create(:main, @viewport.z + 2)
      @held_sprite = Sprite.new(@top_viewport)
      @pointer = Sprite.new(@top_viewport)
      @pointer.set_bitmap(Concours.file('pointeur'), :interface)
      @last_mouse = [Mouse.x, Mouse.y]
      refresh_page
      refresh_texts
      Concours.play_bgm(Concours.setting('dressup_bgm'))
    end

    # --- Déroulé ------------------------------------------------------------------------------------------------------
    def start_dressup
      @started = true
      name = @entrant.name
      display_message(Concours.t("Habille #{name} sur le thème « #{Concours.theme_name(@theme)} » ! Tu as #{@time / 60} secondes et au plus #{@max} accessoires.",
                                 "Dress up #{name} to match the theme \"#{Concours.theme_name(@theme)}\"! You have #{@time / 60} seconds and up to #{@max} accessories."))
      display_message(Concours.t('Clic gauche : glisser un accessoire sur la photo. Clic droit : déplacer le Pokémon. Au clavier : A pour prendre et poser, B pour reposer, X pour les fonds.',
                                 'Left click: drag an accessory onto the photo. Right click: move the Pokémon. Keyboard: A to pick up and drop, B to put back, X for the backdrops.'))
      Concours.play_se('concours_sifflet')
      return true
    end

    def tick_timer
      @time -= 1
      seconds = (@time + 59) / 60
      return if seconds == @shown_seconds

      @shown_seconds = seconds
      @timer_text.text = format('%d:%02d', seconds / 60, seconds % 60)
      @timer_text.load_color(seconds <= 10 ? RED : WHITE) if @timer_text.respond_to?(:load_color)
      Concours.play_se('concours_choix', 60) if seconds <= 5 && seconds > 0
    end

    def ask_finish
      choice = display_message(Concours.t('As-tu fini d’habiller ton Pokémon ?', 'Are you done dressing up your Pokémon?'), 1,
                               Concours.t('Oui', 'Yes'), Concours.t('Non', 'No'))
      finish(false) if choice == 0
    end

    def finish(timeout)
      drop_back if @held
      if timeout
        Concours.play_se('concours_sifflet')
        display_message(Concours.t('Le temps est écoulé !', "Time's up!"))
      end
      @entrant.worn = @worn.map { |piece| [piece[:id], piece[:sprite].x, piece[:sprite].y] }
      @entrant.backdrop = @backdrop
      @entrant.pose = [@photo.pokemon.x, @photo.pokemon.y]
      @entrant.dressup = @worn.sum { |piece| Concours.accessory_points(piece[:id], @theme) }
      Concours.play_se('concours_appareil')
      @running = false
      return true
    end

    # --- Pages de la Mallette -----------------------------------------------------------------------------------------
    # @return [Array<Array(String, Array<String>)>] titre et éléments de chaque page
    def pages
      return @pages if @pages

      list = []
      if @mode == :accessories
        owned = Concours.data['accessories'].select { |id, count| count.to_i > 0 && Concours.accessory(id) }.keys
        Concours.categories.each do |category|
          id = Concours.fetch(category, 'id').to_s
          items = owned.select { |item| Concours.fetch(Concours.accessory(item), 'category').to_s == id }
          title = Concours.local(Concours.fetch(category, 'name'), id)
          items.each_slice(PER_PAGE) { |slice| list << [title, slice] }
        end
        others = owned - list.flat_map(&:last)
        others.each_slice(PER_PAGE) { |slice| list << [Concours.t('Divers', 'Other'), slice] } unless others.empty?
      else
        owned = Concours.data['backdrops'].select { |id| Concours.backdrop(id) }
        owned.each_slice(PER_PAGE) { |slice| list << [Concours.t('Fonds', 'Backdrops'), slice] }
      end
      list << [Concours.t('Mallette vide', 'Empty case'), []] if list.empty?
      return @pages = list
    end

    def page_items
      return pages[@page % pages.size].last
    end

    def remaining(id)
      return Concours.accessory_count(id) - @worn.count { |piece| piece[:id] == id } - (@held&.dig(:id) == id && @held[:from] == :case ? 1 : 0)
    end

    def refresh_page
      @page %= pages.size
      title, items = pages[@page]
      @page_text.text = pages.size > 1 ? "#{title} (#{@page + 1}/#{pages.size})" : title
      @cells.each_with_index do |cell, i|
        id = items[i]
        cell[:cell].visible = !id.nil?
        cell[:item].visible = !id.nil?
        cell[:count].text = ''
        next unless id

        if @mode == :accessories
          cell[:item].set_bitmap(Concours.accessory_image(id), :interface)
          fit(cell[:item], 26)
          cell[:count].text = "×#{remaining(id)}"
          cell[:item].opacity = remaining(id) > 0 ? 255 : 110
        else
          cell[:item].set_bitmap(Concours.backdrop_image(id, true), :interface)
          fit(cell[:item], 28)
          cell[:item].opacity = 255
        end
      end
      @tab_accessories.src_rect.set(0, @mode == :accessories ? 0 : 33, 34, 33)
      @tab_backdrops.src_rect.set(0, @mode == :backdrops ? 0 : 33, 34, 33)
    end

    # Réduit une image pour qu'elle tienne dans une case
    def fit(sprite, size)
      w = [sprite.width, 1].max
      h = [sprite.height, 1].max
      zoom = [size.to_f / w, size.to_f / h, 1.0].min
      sprite.zoom = zoom
      sprite.set_origin(w / 2, h / 2)
    end

    def refresh_texts
      @backdrop_text.text = Concours.t("Fond : #{Concours.backdrop_name(@backdrop)}", "Backdrop: #{Concours.backdrop_name(@backdrop)}")
      @count_text.text = Concours.t("Accessoires : #{@worn.size} / #{@max}", "Accessories: #{@worn.size} / #{@max}")
    end

    def change_page(delta)
      play_cursor_se
      @page = (@page + delta) % pages.size
      refresh_page
    end

    def change_mode(mode)
      return if @mode == mode

      play_cursor_se
      @mode = mode
      @page = 0
      @pages = nil
      refresh_page
    end

    # --- Pointeur -----------------------------------------------------------------------------------------------------
    def update_pointer
      mouse = [Mouse.x, Mouse.y]
      if mouse != @last_mouse
        @px, @py = mouse
        @last_mouse = mouse
      end
      dx = (Input.press?(:RIGHT) ? 1 : 0) - (Input.press?(:LEFT) ? 1 : 0)
      dy = (Input.press?(:DOWN) ? 1 : 0) - (Input.press?(:UP) ? 1 : 0)
      if dx == 0 && dy == 0
        @hold_frames = 0
      else
        @hold_frames += 1
        speed = @hold_frames > 20 ? 4 : 2
        @px += dx * speed
        @py += dy * speed
      end
      @px = @px.clamp(0, 319)
      @py = @py.clamp(0, 239)
    end

    def inside?(rect, x = @px, y = @py)
      return x >= rect[0] && y >= rect[1] && x < rect[0] + rect[2] && y < rect[1] + rect[3]
    end

    def in_photo?(x = @px, y = @py)
      return inside?([PHOTO_X, PHOTO_Y, Photo::WIDTH, Photo::HEIGHT], x, y)
    end

    def cell_at(x = @px, y = @py)
      return nil unless inside?([GRID_X, GRID_Y, CELL * COLUMNS, CELL * PER_PAGE / COLUMNS], x, y)

      index = (x - GRID_X) / CELL + (y - GRID_Y) / CELL * COLUMNS
      return page_items[index] ? index : nil
    end

    def button_at
      return BUTTONS.keys.find { |key| inside?(BUTTONS[key]) }
    end

    # Accessoire accroché sous le pointeur (le plus haut d'abord)
    def worn_at
      x = @px - PHOTO_X
      y = @py - PHOTO_Y
      return @worn.reverse.find do |piece|
        sprite = piece[:sprite]
        (x - sprite.x).abs <= sprite.width / 2 && (y - sprite.y).abs <= sprite.height / 2
      end
    end

    def pokemon_at?
      return false unless in_photo?

      x = @px - PHOTO_X
      y = @py - PHOTO_Y
      sprite = @photo.pokemon
      return (x - sprite.x).abs <= 30 && y <= sprite.y && y >= sprite.y - 70
    end

    # --- Sans rien en main --------------------------------------------------------------------------------------------
    def update_free
      update_hover
      if Mouse.trigger?(:RIGHT) && pokemon_at?
        hold_pokemon(:RIGHT)
      elsif Mouse.trigger?(:LEFT)
        click(:LEFT)
      elsif Input.trigger?(:A)
        click(nil)
      elsif Input.trigger?(:B)
        piece = worn_at
        piece ? remove_worn(piece) : play_buzzer_se
      elsif Input.trigger?(:X)
        change_mode(@mode == :accessories ? :backdrops : :accessories)
      elsif Input.trigger?(:L)
        change_page(-1)
      elsif Input.trigger?(:R)
        change_page(1)
      elsif Input.trigger?(:START)
        ask_finish
      end
    end

    def update_hover
      index = cell_at
      @cell_cursor.visible = !index.nil?
      if index
        @cell_cursor.set_position(GRID_X + (index % COLUMNS) * CELL - 2, GRID_Y + (index / COLUMNS) * CELL - 2)
        id = page_items[index]
        hover(@mode == :accessories ? Concours.accessory_name(id) : Concours.backdrop_name(id))
      elsif (piece = worn_at)
        hover(Concours.accessory_name(piece[:id]))
      else
        hover('')
      end
    end

    def hover(text)
      @hover_text.text = text if @hover_text.text != text
    end

    # @param button [Symbol, nil] bouton de la souris (nil : clavier)
    def click(button)
      case button_at
      when :up then return change_page(-1)
      when :down then return change_page(1)
      when :accessories then return change_mode(:accessories)
      when :backdrops then return change_mode(:backdrops)
      when :done then return ask_finish
      end
      if (index = cell_at)
        return take_from_case(page_items[index], button)
      elsif (piece = worn_at)
        return take_worn(piece, button)
      elsif pokemon_at?
        return hold_pokemon(button)
      end
    end

    def take_from_case(id, button)
      if @mode == :backdrops
        play_decision_se
        @backdrop = id
        @photo.backdrop = id
        return refresh_texts
      end
      return play_buzzer_se if remaining(id) <= 0

      if @worn.size >= @max
        play_buzzer_se
        return hover(Concours.t("#{@max} accessoires au plus !", "#{@max} accessories at most!"))
      end
      Concours.play_se('concours_choix', 80)
      hold(id, :case, button)
    end

    def take_worn(piece, button)
      Concours.play_se('concours_choix', 80)
      @worn.delete(piece)
      @photo.remove(piece[:sprite])
      hold(piece[:id], :worn, button)
    end

    def remove_worn(piece)
      play_cancel_se
      @worn.delete(piece)
      @photo.remove(piece[:sprite])
      refresh_page
      refresh_texts
    end

    def hold(id, from, button)
      @held = { kind: :accessory, id: id, from: from, button: button, start: [@px, @py], frames: 0 }
      @held_sprite.set_bitmap(Concours.accessory_image(id), :interface)
      @held_sprite.set_origin(@held_sprite.width / 2, @held_sprite.height / 2)
      @held_sprite.zoom = 1
      @held_sprite.visible = true
      @held_sprite.set_position(@px, @py)
      @cell_cursor.visible = false
      refresh_page
      refresh_texts
    end

    def hold_pokemon(button)
      play_cursor_se
      sprite = @photo.pokemon
      @held = { kind: :pokemon, button: button, start: [@px, @py], frames: 0, from_pose: [sprite.x, sprite.y],
                offset: [sprite.x - (@px - PHOTO_X), sprite.y - (@py - PHOTO_Y)] }
    end

    # --- Avec un accessoire ou le Pokémon en main ---------------------------------------------------------------------
    def update_held
      @held[:frames] += 1
      if @held[:kind] == :pokemon
        sprite = @photo.pokemon
        sprite.set_position((@px - PHOTO_X + @held[:offset][0]).clamp(8, Photo::WIDTH - 8),
                            (@py - PHOTO_Y + @held[:offset][1]).clamp(40, Photo::HEIGHT + 30))
      else
        @held_sprite.set_position(@px, @py)
      end
      button = @held[:button]
      if button
        return if Mouse.press?(button)

        moved = (@px - @held[:start][0]).abs + (@py - @held[:start][1]).abs
        # simple clic : on garde l'objet en main jusqu'au clic suivant
        return @held[:button] = nil if moved < 6 && @held[:frames] < 20

        return drop
      end
      if Input.trigger?(:A) || Mouse.trigger?(:LEFT) || Mouse.trigger?(:RIGHT)
        drop
      elsif Input.trigger?(:B)
        drop_back
      end
    end

    def drop
      held = @held
      @held = nil
      @held_sprite.visible = false
      return play_decision_se if held[:kind] == :pokemon

      if in_photo? && (held[:from] == :worn || @worn.size < @max)
        Concours.play_se('concours_choix')
        sprite = @photo.add(held[:id], @px - PHOTO_X, @py - PHOTO_Y)
        @worn << { id: held[:id], sprite: sprite }
      else
        play_cancel_se
      end
      refresh_page
      refresh_texts
    end

    # Repose l'objet tenu : l'accessoire retourne dans la Mallette, le Pokémon à sa place
    def drop_back
      held = @held
      @held = nil
      @held_sprite.visible = false
      @photo.pokemon.set_position(*held[:from_pose]) if held[:kind] == :pokemon
      play_cancel_se
      refresh_page
      refresh_texts
    end
  end

  # Défilé : chaque concurrent est dévoilé derrière le rideau et le public l'acclame (cœurs roses : habillage,
  # cœurs rouges : condition)
  class RevealScene < GamePlay::BaseCleanUpdate
    FRAME_X = 104
    FRAME_Y = 34

    # @param entrants [Array<Entrant>]
    # @param rank [String]
    def initialize(entrants, rank)
      super()
      @entrants = entrants
      @rank = rank
      @steps = []
      @wait = 0
      @hearts = []
      @pending = []
      @curtain_move = 0
      plan
    end

    def update_inputs
      return true if (@wait -= 1) > 0
      return true if busy?

      until @steps.empty?
        kind, *args = @steps.shift
        run_step(kind, *args)
        return true if @wait > 0 || busy?
      end
      @running = false
      return true
    end

    def update_graphics
      update_curtain
      update_hearts
      return true
    end

    def dispose
      super
      @photo&.dispose
      @top_viewport&.dispose
    end

    private

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Concours.file('defile'))
      @photo = Photo.new(FRAME_X, FRAME_Y, @viewport.z + 1)
      @photo.visible = false
      @top_viewport = Viewport.create(:main, @viewport.z + 2)
      @curtain = Sprite.new(@top_viewport)
      @curtain.set_bitmap(Concours.file('rideau'), :interface)
      @curtain.set_position(FRAME_X, FRAME_Y)
      @name = UI::SpriteStack.new(@viewport)
      @name_text = @name.add_text(0, 168, 320, 16, '', 1, color: 10)
    end

    def mc
      return "#{Concours.setting('mc_name')} : "
    end

    def plan
      @steps << [:msg, Concours.t("#{mc}Merci de votre patience ! Que commence le défilé !",
                                  "#{mc}All right, thanks for your patience! Let's begin the Visual Competition!")]
      @entrants.each_with_index do |entrant, i|
        text = if entrant.player
                 Concours.t("#{mc}Entrée n° #{i + 1} ! #{entrant.trainer} compte sur #{entrant.name} !",
                            "#{mc}Entry number #{i + 1}! #{entrant.trainer}'s Contest hopes ride with #{entrant.name}!")
               else
                 Concours.t("#{mc}Entrée n° #{i + 1} ! #{entrant.trainer} et #{entrant.name} !",
                            "#{mc}Entry number #{i + 1}! #{entrant.trainer} with #{entrant.name}!")
               end
        @steps << [:msg, text] << [:show, i] << [:curtain, -1] << [:se, 'concours_foule'] << [:hearts, i] << [:wait, 60]
        @steps << [:curtain, 1] << [:wait, 20] if i < @entrants.size - 1
      end
    end

    def run_step(kind, *args)
      case kind
      when :wait then @wait = args[0].to_i
      when :msg then display_message(args[0].to_s)
      when :se then Concours.play_se(args[0])
      when :show then show(args[0])
      when :curtain then @curtain_move = args[0]
      when :hearts then queue_hearts(@entrants[args[0]])
      end
    end

    def busy?
      return @curtain_move != 0 || !@pending.empty? || !@hearts.empty?
    end

    def show(index)
      entrant = @entrants[index]
      @photo.show(entrant, @rank)
      @photo.visible = true
      @name_text.text = "#{entrant.trainer} & #{entrant.name}"
    end

    # Rideau : -1 il se lève, 1 il descend
    def update_curtain
      return if @curtain_move == 0

      height = (@curtain.src_rect.height + @curtain_move * 4).clamp(0, Photo::HEIGHT)
      @curtain.src_rect.height = height
      @curtain.visible = height > 0
      @curtain_move = 0 if height <= 0 || height >= Photo::HEIGHT
    end

    def queue_hearts(entrant)
      red = Concours.condition_hearts(entrant.condition, @rank)
      pink = Concours.dressup_hearts(entrant.dressup, @rank)
      kinds = []
      [red, pink].max.times do |i|
        kinds << 'coeur_rouge' if i < red
        kinds << 'coeur_rose' if i < pink
      end
      @pending = kinds.each_with_index.map { |kind, i| [kind, i * 10] }
    end

    def update_hearts
      @pending.each { |heart| heart[1] -= 1 }
      while (heart = @pending.first) && heart[1] <= 0
        @pending.shift
        sprite = Sprite.new(@top_viewport)
        sprite.set_bitmap(Concours.file(heart[0]), :interface)
        sprite.set_origin(sprite.width / 2, sprite.height / 2)
        sprite.set_position(rand(20..300), rand(200..228))
        @hearts << { sprite: sprite, time: 0 }
        Concours.play_se('concours_coeur', 80)
      end
      @hearts.each do |heart|
        heart[:time] += 1
        sprite = heart[:sprite]
        sprite.y -= 1
        sprite.x += Math.sin(heart[:time] / 6.0).round
        sprite.opacity = (255 - [heart[:time] - 40, 0].max * 8).clamp(0, 255)
      end
      done, @hearts = @hearts.partition { |heart| heart[:time] >= 72 }
      done.each { |heart| heart[:sprite].dispose }
    end
  end
end

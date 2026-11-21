# Pots à baies : la scène, aux couleurs Horizon
#
# Flèches : choisir un pot (puis l'arrosoir et Quitter à droite) ; A : s'occuper du pot (planter, engrais, arroser,
# cueillir) ; sur l'arrosoir, A puis haut / bas pour en changer ; B : quitter.
# Souris : clic sur un pot (re-clic = A), sur l'arrosoir ou sur Quitter ; clic droit = retour.
module GamePlay
  class PotsBaies < BaseCleanUpdate::FrameBalanced
    P = ::PotsBaies
    DARK = 0
    WHITE = 9
    SMALL = 20
    BG = 'horizon/team/fond'
    HEADER = 'horizon/header'
    FOOTER = 'horizon/tcard/button_background'
    SHELF_X = 6
    SHELF_Y = 32
    SHELF_W = 246
    SIDE_X = 256
    SIDE_Y = 32
    SLOT_W = 48
    PER_ROW = 5
    # Haut des planches de l'étagère (1 ou 2 rangées)
    PLANKS = { 1 => [156], 2 => [109, 181] }.freeze
    CAN_X = 284
    CAN_Y = 66
    QUIT_X = 260
    QUIT_Y = 164
    INFO_X = 6
    INFO_Y = 192
    CAN = -1
    QUIT = -2
    WATERING_FRAMES = 90
    NO_INITIAL_IMAGE = UI::SpriteStack::NO_INITIAL_IMAGE

    def initialize
      super()
      @index = 0
      @frame_count = 0
      @state = :select
      @cans = P.owned_cans
      current = P.state[:can]
      @can_index = @cans.index { |c| c['item'] == current } || 0
      P.state[:can] = @cans[@can_index]['item'] if @cans[@can_index]
      @sparks = Array.new(P::MAX_POTS, 0)
      P.count.times do |i|
        data = P.pots[i]
        next unless P.planted?(data)

        @sparks[i] = 30 if P.seen.key?(i) && P.seen[i] < data[1].to_i
        P.seen[i] = data[1].to_i
      end
    end

    def update_inputs
      case @state
      when :select then update_select_inputs
      when :can then update_can_inputs
      end
      return false
    end

    def update_mouse(_moved)
      return false unless @state == :select || @state == :can

      if Mouse.trigger?(:RIGHT)
        @state == :can ? cancel_can_choice : quit
        return false
      end
      if Mouse.wheel != 0 && @state == :can
        change_can(Mouse.wheel > 0 ? -1 : 1)
        Mouse.wheel = 0
        return false
      end
      return true unless Mouse.trigger?(:LEFT)

      target = target_at(Mouse.x, Mouse.y)
      return true if target.nil?

      if @state == :can
        target == CAN ? confirm_can : cancel_can_choice
      elsif target == @index
        activate
      else
        select(target)
      end
      return false
    end

    def update_graphics
      @frame_count += 1
      anim = (@frame_count / 10) % 4
      @plants.each_with_index do |plant, i|
        plant.src_rect.x = anim * plant.src_rect.width if plant.visible && plant.bitmap
        spark = @spark_sprites[i]
        if @sparks[i] > 0
          @sparks[i] -= 1
          spark.visible = true
          spark.src_rect.x = ((@frame_count / 6) % 4) * 32
        else
          spark.visible = false
        end
      end
      blink = (@frame_count / 20).even?
      @cursor.src_rect.x = blink ? 0 : 48
      @cursor_can.src_rect.x = blink ? 0 : 54
      @arrows.each_with_index { |a, i| a.src_rect.x = (i * 2 + (blink ? 0 : 1)) * 12 }
      update_watering if @state == :watering
      return true
    end

    private

    # --- Entrées ---------------------------------------------------------------------------------
    def update_select_inputs
      if Input.trigger?(:B)
        quit
      elsif Input.trigger?(:A)
        activate
      elsif Input.repeat?(:RIGHT)
        move_right
      elsif Input.repeat?(:LEFT)
        move_left
      elsif Input.repeat?(:UP) || Input.repeat?(:DOWN)
        move_vertical(Input.repeat?(:DOWN) ? 1 : -1)
      end
    end

    def update_can_inputs
      if Input.trigger?(:B)
        cancel_can_choice
      elsif Input.trigger?(:A)
        confirm_can
      elsif Input.repeat?(:UP) || Input.repeat?(:DOWN)
        change_can(Input.repeat?(:UP) ? -1 : 1)
      end
    end

    def rows
      return count > PER_ROW ? 2 : 1
    end

    def count
      return P.count
    end

    def move_right
      if @index >= 0
        last_of_row = (@index % PER_ROW == PER_ROW - 1) || @index == count - 1
        return select(last_of_row ? CAN : @index + 1)
      end
      select(QUIT) if @index == CAN
    end

    def move_left
      return select(@index - 1) if @index > 0 && @index % PER_ROW != 0
      return select(@index == QUIT ? CAN : last_pot_of_first_row) if @index < 0
    end

    def last_pot_of_first_row
      return [count, PER_ROW].min - 1
    end

    def move_vertical(delta)
      if @index >= 0
        return if rows == 1

        target = @index + delta * PER_ROW
        select(target) if target.between?(0, count - 1)
      elsif @index == CAN && delta > 0
        select(QUIT)
      elsif @index == QUIT && delta < 0
        select(CAN)
      end
    end

    def select(index)
      return if index == @index
      return if index >= 0 && index >= count

      play_cursor_se
      @index = index
      refresh
    end

    # A sur la sélection
    def activate
      case @index
      when QUIT then quit
      when CAN then open_can_choice
      else interact(@index) if @index < count
      end
    end

    def quit
      play_cancel_se
      @running = false
    end

    # --- Arrosoir --------------------------------------------------------------------------------
    def open_can_choice
      return play_buzzer_se if @cans.size < 2

      play_decision_se
      @can_before = @can_index
      @state = :can
      refresh
    end

    def change_can(delta)
      index = (@can_index + delta).clamp(0, @cans.size - 1)
      return if index == @can_index

      play_cursor_se
      @can_index = index
      refresh
    end

    def confirm_can
      play_decision_se
      P.state[:can] = @cans[@can_index]['item']
      @state = :select
      refresh
    end

    def cancel_can_choice
      play_cancel_se
      @can_index = @can_before || @can_index
      @state = :select
      refresh
    end

    def can
      return @cans[@can_index]
    end

    # --- Pots ------------------------------------------------------------------------------------
    def interact(index)
      play_decision_se
      data = P.pot(index)
      if P.ripe?(data)
        harvest(index, data)
      elsif P.planted?(data)
        growing(index, data)
      else
        empty_pot(index, data)
      end
      refresh
    end

    def yes_no(text)
      return display_message(text, 1, P.t('Oui', 'Yes'), P.t('Non', 'No')) == 0
    end

    def growing(index, data)
      name = P.item_name(data[0])
      text = P::STAGES[data[1].to_i.clamp(0, 3)]
      display_message(format(P.t(*text), name))
      return unless can || !P.setting?(:need_can)

      tool = can ? P.item_name(can['item'].to_sym) : P.t('de l’eau', 'water')
      return unless yes_no(P.t("Arroser avec #{tool} ?", "Want to sprinkle some water with the #{tool}?"))

      P.water(index)
      start_watering(index)
    end

    def empty_pot(index, data)
      mulch = data[7].to_i
      choices = [P.t('Planter une baie', 'Plant a Berry')]
      choices << P.t('Mettre de l’engrais', 'Fertilize') if P.setting?(:mulch_enabled) && mulch == 0
      choices << P.t('Annuler', 'Cancel')
      intro = mulch == 0 ? P.t('C’est une terre meuble.', 'It’s soft, earthy soil.') :
                           P.t("Il y a de l’engrais dans ce pot (#{P.item_name(mulch)}).", "#{P.item_name(mulch)} has been laid down.")
      choice = display_message(intro, 1, *choices)
      return if choice.nil? || choice == choices.size - 1
      return fertilize(index) if choice == 1

      plant(index)
    end

    def fertilize(index)
      mulches = P.owned_mulches
      return display_message(P.t('Tu n’as pas d’engrais !', 'You don’t have any fertilizer!')) if mulches.empty?

      names = mulches.map { |sym| P.item_name(sym.to_sym) }
      choice = display_message(P.t('Quel engrais mettre ?', 'Which fertilizer?'), 1, *names, P.t('Annuler', 'Cancel'))
      return if choice.nil? || choice >= mulches.size

      sym = mulches[choice].to_sym
      P.lay_mulch(index, sym)
      $bag.remove_item(sym, 1)
      display_message(P.t("Tu as répandu l’engrais sur la terre (#{P.item_name(sym)}).", "The #{P.item_name(sym)} was scattered on the soil."))
    end

    def plant(index)
      berry = nil
      call_scene(GamePlay.bag_class, :berry) { |scene| berry = scene.return_data }
      return if berry.nil? || berry.to_i <= 0

      unless P.plantable?(berry)
        return display_message(P.t('Cette baie ne pousse pas en pot.', 'This Berry can’t grow in a pot.'))
      end

      sym = P.item(berry).db_symbol
      return unless $bag.contain_item?(sym)

      $bag.remove_item(sym, 1)
      P.plant(index, berry)
      play_se(P.setting(:plant_se))
      @sparks[index] = 20
      refresh
      display_message(P.t("Tu as planté une #{P.item_name(berry)} dans le pot.",
                          "You planted a #{P.item_name(berry)} in the pot."))
    end

    def harvest(index, data)
      amount = P.harvest_amount(data)
      name = P.item_name(data[0])
      question = amount > 1 ? P.t("Il y a #{amount} #{name} ! Les cueillir ?", "There are #{amount} #{name}! Want to pick them?") :
                              P.t("Il y a 1 #{name} ! La cueillir ?", "There is 1 #{name}! Want to pick it?")
      return unless yes_no(question)

      sym = P.item(data[0]).db_symbol
      $bag.add_item(sym, amount)
      ::Mementos.safely('baies') { ::Mementos.berries_gained! } if defined?(::Mementos) # insigne Gourmet
      P.clear(index)
      me = P.setting(:harvest_me).to_s
      Audio.me_play(me) unless me.empty?
      refresh
      display_message(P.t("Tu as cueilli #{amount} #{name}.", "You picked #{amount} #{name}."))
      display_message(P.t('La terre est redevenue meuble.', 'The soil returned to its soft and earthy state.'))
    end

    def play_se(file)
      file = file.to_s
      Audio.se_play(file) unless file.empty?
    rescue StandardError
      nil
    end

    # --- Arrosage animé --------------------------------------------------------------------------
    def start_watering(index)
      @watering = index
      @water_count = 0
      @state = :watering
      @cursor.visible = false
      x, soil = soil_position(index)
      file = can ? can_file(can, false) : nil
      @spray.visible = !file.nil?
      @spray.set_bitmap(file, :interface) if file
      @spray.src_rect.set(0, 0, 44, 62)
      @spray.set_position(x - 26, soil - 60)
      play_se(P.setting(:water_se))
    end

    def update_watering
      @water_count += 1
      if @water_count == 10 && can && (anim = can_file(can, true))
        @spray.set_bitmap(anim, :interface)
        @spray.src_rect.set(0, 0, 44, 62)
      end
      @spray.src_rect.x = ((@water_count / 10) % 2) * 44 if @water_count.between?(10, 79) && @spray.bitmap&.width.to_i >= 88
      refresh_pot(@watering) if @water_count == 40
      return if @water_count < WATERING_FRAMES

      @spray.visible = false
      @state = :select
      refresh
      display_message(P.t("#{$trainer.name} arrose la plante.", "#{$trainer.name} watered the plant."))
      display_message(P.t('Et voilà ! Elle a l’air ravie.', 'There! All happy!'))
    end

    def can_file(entry, anim)
      name = P.file("cans/#{entry['image']}#{anim ? '_anim' : ''}")
      return RPG::Cache.interface_exist?(name) ? name : nil
    end

    # --- Placement -------------------------------------------------------------------------------
    # @return [Array(Integer, Integer)] x du créneau, y du haut de la planche
    def slot_position(index)
      row = index / PER_ROW
      in_row = rows == 1 ? count : [count - row * PER_ROW, PER_ROW].min
      in_row = PER_ROW if rows == 2 && row == 0
      x0 = SHELF_X + (SHELF_W - (rows == 1 ? in_row : PER_ROW) * SLOT_W) / 2
      return [x0 + (index % PER_ROW) * SLOT_W, PLANKS[rows][row]]
    end

    # @return [Array(Integer, Integer)] centre du sol (x, y)
    def soil_position(index)
      x, plank = slot_position(index)
      return [x + SLOT_W / 2, plank - 20]
    end

    def target_at(x, y)
      count.times do |i|
        sx, plank = slot_position(i)
        return i if x.between?(sx, sx + SLOT_W - 1) && y.between?(plank - 76, plank + 1)
      end
      return QUIT if x.between?(QUIT_X, QUIT_X + 49) && y.between?(QUIT_Y, QUIT_Y + 17)
      return CAN if x.between?(SIDE_X, SIDE_X + 57) && y.between?(SIDE_Y, SIDE_Y + 125)

      return nil
    end

    # --- Graphismes ------------------------------------------------------------------------------
    def create_graphics
      super
      @base = UI::SpriteStack.new(@viewport, default_cache: :interface)
      picture(BG) || plain_background
      picture(HEADER)
      picture(FOOTER, 0, 214)
      @shelf = @base.add_sprite(SHELF_X, SHELF_Y, P.file("shelf_#{rows}"))
      @base.add_sprite(SIDE_X, SIDE_Y, P.file('side'))
      @title = @base.add_text(96, 5, 128, 16, P.t('POTS À BAIES', 'BERRY POTS'), 1, color: WHITE)
      @base.with_font(SMALL) do
        @total = @base.add_text(6, 7, 84, 13, '', color: WHITE)
        @counter = @base.add_text(232, 7, 82, 13, '', 2, color: WHITE)
        @help = @base.add_text(8, 220, 304, 13, '', 1, color: WHITE)
        @can_name = @base.add_text(SIDE_X + 4, SIDE_Y + 97, 50, 13, '', 1, color: WHITE)
        @no_can = @base.add_text(SIDE_X + 4, CAN_Y - 12, 50, 13, '', 1, color: DARK)
        @no_can2 = @base.add_text(SIDE_X + 4, CAN_Y - 1, 50, 13, '', 1, color: DARK)
      end
      @can_sprite = @base.add_sprite(CAN_X - 22, CAN_Y - 21, NO_INITIAL_IMAGE)
      @arrows = [@base.add_sprite(CAN_X - 6, SIDE_Y + 3, P.file('arrows')), @base.add_sprite(CAN_X - 6, SIDE_Y + 84, P.file('arrows'))]
      @arrows.each { |a| a.src_rect.width = 12 }
      @quit = @base.add_sprite(QUIT_X, QUIT_Y, P.file('quit'))
      @quit.src_rect.height = 18
      @base.with_font(SMALL) { @quit_text = @base.add_text(QUIT_X, QUIT_Y + 3, 50, 13, P.t('Quitter', 'Quit'), 1, color: DARK) }
      @pots = []
      @plants = []
      @spark_sprites = []
      P::MAX_POTS.times do
        @pots << @base.add_sprite(0, 0, NO_INITIAL_IMAGE)
        @plants << @base.add_sprite(0, 0, NO_INITIAL_IMAGE)
      end
      P::MAX_POTS.times do
        spark = @base.add_sprite(0, 0, NO_INITIAL_IMAGE)
        spark.set_bitmap(Yuki::Berries::PLANTED_CHAR, :character) if character?(Yuki::Berries::PLANTED_CHAR)
        spark.src_rect.set(0, 32, 32, 32)
        spark.visible = false
        @spark_sprites << spark
      end
      @cursor = @base.add_sprite(0, 0, P.file('cursor'))
      @cursor.src_rect.width = 48
      @cursor_can = @base.add_sprite(SIDE_X + 2, CAN_Y - 28, P.file('cursor_can'))
      @cursor_can.src_rect.width = 54
      @spray = @base.add_sprite(0, 0, NO_INITIAL_IMAGE)
      @spray.visible = false
      create_info
      refresh
    end

    def picture(name, x = 0, y = 0)
      return nil unless RPG::Cache.interface_exist?(name)

      return @base.add_sprite(x, y, name)
    end

    def plain_background
      bg = @base.add_sprite(0, 0, NO_INITIAL_IMAGE)
      image = Image.new(320, 240)
      image.fill_rect(0, 0, 320, 240, Color.new(229, 243, 250))
      bg.bitmap = image.copy_to_bitmap(Bitmap.new(320, 240))
      image.dispose
    end

    def create_info
      @info = UI::SpriteStack.new(@viewport, INFO_X, INFO_Y, default_cache: :interface)
      @info.add_sprite(0, 0, P.file('info'))
      @info_text = @info.add_text(10, 2, 200, 16, '', color: DARK)
      @drops = @info.add_sprite(214, 6, P.file('drop'))
      @drops.src_rect.width = 18
      @info.with_font(SMALL) { @info_time = @info.add_text(236, 4, 66, 13, '', 2, color: DARK) }
    end

    def character?(name)
      return RPG::Cache.character_exist?(name)
    rescue StandardError
      return false
    end

    # --- Mise à jour de l'affichage -------------------------------------------------------------
    def refresh
      P::MAX_POTS.times { |i| refresh_pot(i) }
      refresh_side
      refresh_cursor
      refresh_info
      @total.text = P.t("Pots : #{count}", "Pots: #{count}")
      ripe = P.ripe_count
      @counter.text = ripe > 0 ? P.t("Prêtes : #{ripe}", "Ready: #{ripe}") : ''
      @help.text = help_text
    end

    def help_text
      return P.t('Haut / Bas : Arrosoir   A : Choisir   B : Annuler', 'Up / Down: Can   A: Choose   B: Cancel') if @state == :can
      return P.t('A : Changer d’arrosoir   B : Quitter', 'A: Change can   B: Quit') if @index == CAN

      return P.t('A : S’occuper du pot   B : Quitter', 'A: Tend the pot   B: Quit')
    end

    def refresh_pot(index)
      pot = @pots[index]
      plant = @plants[index]
      spark = @spark_sprites[index]
      if index >= count
        pot.visible = plant.visible = false
        spark.visible = false
        return
      end
      data = P.pots[index]
      x, plank = slot_position(index)
      pot.set_bitmap(P.file("pot_#{%w[dry damp wet][P.moisture(data)]}"), :interface)
      pot.set_position(x + 4, plank - 27)
      pot.visible = true
      soil_x, soil_y = soil_position(index)
      spark.set_position(soil_x - 16, soil_y - 26)
      refresh_plant(plant, data, soil_x, soil_y)
    end

    def refresh_plant(plant, data, soil_x, soil_y)
      plant.visible = false
      return unless P.planted?(data)

      stage = data[1].to_i.clamp(0, 4)
      name = stage == 0 ? Yuki::Berries::PLANTED_CHAR : "Z_B#{data[0]}"
      return unless character?(name)

      plant.set_bitmap(name, :character)
      w = plant.bitmap.width / 4
      h = plant.bitmap.height / 4
      row = stage == 0 ? 3 : stage - 1
      plant.src_rect.set(plant.src_rect.x % [plant.bitmap.width, 1].max, row * h, w, h)
      plant.set_position(soil_x - w / 2, soil_y + 4 - h)
      plant.visible = true
    end

    def refresh_side
      entry = can
      file = entry ? can_file(entry, false) : nil
      @can_sprite.visible = !file.nil?
      if file
        @can_sprite.set_bitmap(file, :interface)
        @can_sprite.src_rect.set(0, 0, 44, 40)
      end
      @can_name.text = P.t('Arrosoir', 'Can')
      @no_can.text = entry ? '' : P.t('Aucun', 'No')
      @no_can2.text = entry ? '' : P.t('arrosoir', 'can')
      choosing = @state == :can
      @arrows[0].visible = choosing && @can_index > 0
      @arrows[1].visible = choosing && @can_index < @cans.size - 1
      @quit.src_rect.y = @index == QUIT ? 18 : 0
      @quit_text.load_color(@index == QUIT ? WHITE : DARK) if @quit_text.respond_to?(:load_color)
    end

    def refresh_cursor
      @cursor.visible = @index >= 0 && @state != :watering
      @cursor_can.visible = @index == CAN
      return unless @index >= 0

      x, plank = slot_position(@index)
      @cursor.set_position(x, plank - 76)
    end

    def refresh_info
      if @index < 0
        @info_text.text = @index == CAN ? can_info : P.t('Ranger les pots.', 'Put the pots away.')
        @drops.visible = false
        @info_time.text = ''
        return
      end
      data = P.pots[@index]
      @drops.visible = P.planted?(data)
      unless P.planted?(data)
        mulch = data && data[7].to_i != 0 ? P.t(" (#{P.item_name(data[7])})", " (#{P.item_name(data[7])})") : ''
        @info_text.text = P.t("Pot #{@index + 1} : vide", "Pot #{@index + 1}: empty") + mulch
        @info_time.text = ''
        return
      end
      stage = P::STAGE_NAMES[data[1].to_i.clamp(0, 4)]
      @info_text.text = "#{P.item_name(data[0])} - #{P.t(*stage)}"
      @drops.src_rect.x = P.moisture(data) * 18
      @info_time.text = P.setting?(:show_time) ? P.time_text(P.minutes_left(data)) : ''
    end

    def can_info
      return P.t('Tu n’as pas d’arrosoir.', 'You have no watering can.') unless can
      return P.t("#{P.item_name(can['item'].to_sym)} (#{@can_index + 1} / #{@cans.size})", "#{P.item_name(can['item'].to_sym)} (#{@can_index + 1} / #{@cans.size})") if @cans.size > 1

      return P.item_name(can['item'].to_sym)
    end
  end
end

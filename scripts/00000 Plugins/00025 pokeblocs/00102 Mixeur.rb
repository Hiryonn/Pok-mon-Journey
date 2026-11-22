# Pokéblocs : mixeurs à baies
#   BlenderScene : mixeur à jouer (Rubis / Saphir / Émeraude), 0 à 3 autres joueurs ou le Maître Baies
#     A au bon moment quand la flèche passe sur votre repère (en haut à gauche) : Parfait, Bien ou Raté
#   SimpleBlenderScene : mixeur du Kit Pokébloc (Rubis Oméga / Saphir Alpha), 1 à 4 baies, sans mini-jeu
module Pokeblocs
  # Sac ouvert pour choisir une baie (texte « choisir » au lieu de « planter »)
  class BerryBag < GamePlay::Bag
    def initialize
      super(:berry)
    end

    private

    def button_texts
      return CTRL_TEXTS_PER_MODE[:map].collect { |data| get_text(data) }
    end
  end

  # Fenêtre de choix des baies, commune aux deux mixeurs
  module BerryPicker
    private

    # @return [Symbol, nil] baie choisie (retirée du sac), nil si abandon
    def pick_berry(ask_again = true)
      loop do
        id = -1
        call_scene(BerryBag) { |scene| id = scene.return_data }
        if id.is_a?(Integer) && id >= 0
          sym = Pokeblocs.item_sym(id)
          if Pokeblocs.berry?(sym) && $bag.contain_item?(sym)
            $bag.remove_item(sym, 1)
            return sym
          end
          display_message(Pokeblocs.t('Cette baie ne peut pas aller dans le mixeur.', "This Berry can't go in the Blender."))
          next
        end
        return nil unless ask_again

        choice = display_message(Pokeblocs.t('Voulez-vous choisir une baie ?', 'Do you want to choose a Berry?'), 1,
                                 Pokeblocs.t('Oui', 'Yes'), Pokeblocs.t('Non', 'No'))
        return nil if choice != 0
      end
    end

    def berry_sprite(stack, berry)
      sprite = stack.push(0, 0, nil, type: UI::ItemSprite)
      sprite.data = data_item(berry).id
      sprite.set_origin(sprite.width / 2, sprite.height / 2)
      return sprite
    end
  end

  class BlenderScene < GamePlay::BaseCleanUpdate
    include BerryPicker
    DARK = 0
    WHITE = 10
    CENTER_X = 160
    CENTER_Y = 120
    # Repère de chaque joueur (angle de la flèche, sens inverse des aiguilles d'une montre) et position des cadres
    TARGETS = [40, 320, 140, 220].freeze
    NAME_POS = [[42, 81], [221, 81], [42, 138], [221, 138]].freeze
    MARK_POS = [[125, 80], [195, 80], [125, 159], [195, 159]].freeze
    BERRY_START = [[60, 70], [260, 70], [60, 170], [260, 170]].freeze
    MIN_RPM = 7.0
    MAX_RPM = 110.0
    PERFECT = 5
    GOOD = 14
    # @return [Integer] nombre de Pokéblocs obtenus
    attr_reader :made

    # @param players [Integer] 0 à 3 autres joueurs, 4 : Maître Baies
    # @param names [Array<String>, nil] noms des autres joueurs
    # @param fail [Boolean] le Pokébloc sera raté (Noir)
    def initialize(players = 0, names = nil, fail = false)
      super()
      @players = players.to_i.clamp(0, 4)
      @fail = fail
      @made = 0
      @names = [$trainer.name.to_s] + other_names(names)
      @state = :start
      @wait = 2
    end

    def update_inputs
      return true if (@wait -= 1) > 0

      case @state
      when :start then start_round
      when :drop then update_drop
      when :countdown then update_countdown
      when :play then update_play
      when :stop then update_stop
      when :result then update_result
      end
      return true
    end

    def update_graphics
      update_marks
      update_sparks
      return true
    end

    private

    def other_names(names)
      return [] if @players == 0

      if @players == 4
        list = Array(Pokeblocs.setting('master_names'))
        return [(names && names[0]) || list.sample || 'Maître Baies'].map(&:to_s)
      end
      lists = Array(Pokeblocs.setting('npc_names'))
      return Array.new(@players) { |i| ((names && names[i]) || Array(lists[i]).sample || "Joueur #{i + 2}").to_s }
    end

    def seats
      return @players == 4 ? 2 : @players + 1
    end

    # Siège de chaque joueur (le Maître Baies est en haut à droite)
    def seat(index)
      return index
    end

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Pokeblocs.file('mixeur_fond'))
      @disk = @stack.add_sprite(CENTER_X, CENTER_Y, Pokeblocs.file('disque'))
      @disk.set_origin(@disk.width / 2, @disk.height / 2)
      @gauge = @stack.add_sprite(58, 26, Pokeblocs.file('jauge'))
      @stack.add_sprite(32, 24, Pokeblocs.file("mixeur_#{[seats, 4].min}"))
      @name_texts = @names.each_with_index.map do |name, i|
        x, y = NAME_POS[seat(i)]
        @stack.add_text(x, y + 4, 62, 16, name, 1, color: DARK)
      end
      @speed_text = @stack.add_text(110, 187, 100, 16, '', 1, color: DARK)
      @marks = Array.new(4) do |i|
        sprite = @stack.add_sprite(*MARK_POS[i], Pokeblocs.file('notes'))
        sprite.set_origin(8, 8)
        sprite.visible = false
        { sprite: sprite, time: 0 }
      end
      @sparks = Array.new(8) do |i|
        sprite = @stack.add_sprite(0, 0, Pokeblocs.file('etincelles'))
        sprite.src_rect.set(i.even? ? 0 : 14, 0, i.even? ? 14 : 10, 14)
        sprite.visible = false
        { sprite: sprite, time: 0 }
      end
      @big = @stack.add_sprite(CENTER_X, CENTER_Y, nil)
      @big.visible = false
      @berries_sprites = []
      create_result_layer
      Pokeblocs.play_bgm(Pokeblocs.setting('bgm'))
    end

    def create_result_layer
      @result_stack = UI::SpriteStack.new(@viewport)
      @result_stack.add_sprite(0, 0, Pokeblocs.file('resultats'))
      @result_title = @result_stack.add_text(0, 6, 320, 16, Pokeblocs.t('Résultats du mixage', 'Results of blending'), 1, color: DARK)
      @result_speed = @result_stack.add_text(0, 24, 320, 16, '', 1, color: DARK)
      @result_marks = Array.new(3) do |i|
        sprite = @result_stack.add_sprite(176 + i * 40, 44, Pokeblocs.file('notes'))
        sprite.src_rect.set(i * 16, 0, 16, 16)
        sprite
      end
      @result_rows = Array.new(4) do |i|
        y = 64 + i * 20
        { name: @result_stack.add_text(16, y, 140, 16, '', color: DARK),
          counts: Array.new(3) { |k| @result_stack.add_text(168 + k * 40, y, 32, 16, '', 1, color: DARK) },
          berry: @result_stack.add_text(150, y, 160, 16, '', color: DARK) }
      end
      @result_block = @result_stack.add_sprite(28, 158, nil)
      @result_line1 = @result_stack.add_text(84, 166, 230, 16, '', color: DARK)
      @result_line2 = @result_stack.add_text(84, 184, 230, 16, '', color: DARK)
      @result_stack.visible = false
    end

    # --- Tour de mixeur -----------------------------------------------------------------------------------------------
    def start_round
      reset_round
      if @first.nil?
        @first = true
        display_message(Pokeblocs.t('Le mixeur à baies se met en marche...', 'Starting up the Berry Blender...'))
        display_message(Pokeblocs.t('Choisissez une baie dans votre sac.', 'Please select a Berry from your Bag.'))
      end
      berry = pick_berry
      return finish unless berry

      @berries = [berry] + Pokeblocs.npc_berries(berry, @players)
      @berries = @berries.first(1) if @berries.empty?
      @berries_sprites.each(&:dispose)
      @berries_sprites = @berries.each_with_index.map do |b, i|
        sprite = berry_sprite(@stack, b)
        sprite.set_position(*BERRY_START[seat(i)])
        sprite
      end
      @drop_time = 0
      @state = :drop
    end

    def reset_round
      @angle = 0.0
      @rpm = MIN_RPM
      @max_rpm = MIN_RPM
      @progress = 0.0
      @counts = Array.new(@names.size) { [0, 0, 0] }
      @idle = idle_delay
      @disk.angle = 0
      @gauge.x = 58
      @speed_text.text = ''
      @result_stack.visible = false
      @stack.visible = true
      @marks.each { |m| m[:sprite].visible = false }
      @sparks.each { |spark| spark[:sprite].visible = false }
      @big.visible = false
      @name_texts.each { |t| t.visible = true }
    end

    def idle_delay
      return @players == 0 ? 400 : 100 * [@players, 3].min
    end

    def update_drop
      @drop_time += 1
      t = (@drop_time / 36.0).clamp(0, 1)
      @berries_sprites.each_with_index do |sprite, i|
        sx, sy = BERRY_START[seat(i)]
        x = sx + (CENTER_X - sx) * t
        y = sy + (CENTER_Y - sy) * t - Math.sin(t * Math::PI) * 24
        sprite.set_position(x, y)
        sprite.opacity = t > 0.85 ? (255 * (1 - t) / 0.15).round : 255
      end
      return if @drop_time < 40

      @berries_sprites.each { |sprite| sprite.visible = false }
      @count_time = 0
      @state = :countdown
    end

    def update_countdown
      @count_time += 1
      step = @count_time / 40
      if @count_time % 40 == 1
        if step < 3
          @big.set_bitmap(Pokeblocs.file('chiffres'), :interface)
          @big.src_rect.set((2 - step) * 24, 0, 24, 30)
          @big.set_origin(12, 15)
          Pokeblocs.play_se('mixeur_decompte')
        else
          @big.set_bitmap(Pokeblocs.file('partez'), :interface)
          @big.set_origin(@big.width / 2, @big.height / 2)
          Pokeblocs.play_se('mixeur_depart')
        end
        @big.visible = true
      end
      return if @count_time < 160

      @big.visible = false
      @state = :play
    end

    def update_play
      previous = @angle
      @angle = (@angle + degrees_per_frame) % 360
      @disk.angle = @angle.round
      npc_presses(previous, @angle)
      player_press if Input.trigger?(:A)
      decay
      @max_rpm = [@max_rpm, @rpm].max
      @progress += 0.0009 + @rpm * 0.000028
      @gauge.x = 58 + (68 * @progress.clamp(0, 1)).round
      @speed_text.text = format('%.1f %s', @rpm, Pokeblocs.t('tr/min', 'RPM')).tr('.', Pokeblocs.fr? ? ',' : '.')
      return if @progress < 1

      @state = :stop
      @stop_time = 0
    end

    def degrees_per_frame
      return 1.5 + @rpm * 0.09
    end

    def player_press
      distance = ((@angle - TARGETS[0] + 180) % 360 - 180).abs
      judge(0, distance <= PERFECT ? 0 : (distance <= GOOD ? 1 : 2))
    end

    # Les autres joueurs appuient quand la flèche passe sur leur repère
    def npc_presses(from, to)
      (1...@names.size).each do |i|
        target = TARGETS[seat(i)]
        next unless crossed?(from, to, target)

        roll = @players == 4 ? rand(5) : rand(6)
        kind = if @players == 4
                 roll < 2 ? 0 : (roll < 4 ? 1 : nil)
               else
                 { 0 => 0, 1 => 1, 2 => 2, 3 => 2 }[roll]
               end
        judge(i, kind) if kind
      end
    end

    def crossed?(from, to, target)
      return from < target && target <= to if from <= to

      return target > from || target <= to
    end

    # @param player [Integer]
    # @param kind [Integer] 0 : Parfait, 1 : Bien, 2 : Raté
    def judge(player, kind)
      @counts[player][kind] += 1
      mark = @marks[seat(player)]
      mark[:sprite].src_rect.set(kind * 16, 0, 16, 16)
      mark[:sprite].visible = true
      mark[:time] = 24
      case kind
      when 0
        change_speed(6)
        @progress += 0.01
        sparkle
        Pokeblocs.play_se('mixeur_parfait', 80)
      when 1
        change_speed(3)
        @progress += 0.005
        Pokeblocs.play_se('mixeur_bien', 80)
      else
        change_speed(-5)
        Pokeblocs.play_se('mixeur_rate', 80)
      end
      @idle = idle_delay
    end

    def change_speed(amount)
      factor = if amount > 0
                 @rpm >= 100 ? 1.0 : (@rpm >= 80 ? 1.3 : (@rpm >= 40 ? 1.7 : 2.0))
               else
                 @rpm >= 100 ? 1.5 : (@rpm >= 80 ? 1.7 : (@rpm >= 40 ? 1.9 : 2.0))
               end
      @rpm = (@rpm + amount * factor).clamp(MIN_RPM, MAX_RPM)
    end

    def decay
      @idle -= 1
      return if @idle > 0

      @rpm = [@rpm - 0.25, MIN_RPM].max
    end

    def update_marks
      @marks&.each do |mark|
        next unless mark[:time] > 0

        mark[:time] -= 1
        mark[:sprite].visible = mark[:time] > 0
      end
    end

    def sparkle
      @sparks.select { |s| s[:time] <= 0 }.first(2).each do |spark|
        spark[:sprite].set_position(40 + rand(240), 30 + rand(180))
        spark[:sprite].visible = true
        spark[:time] = 12
      end
    end

    def update_sparks
      @sparks&.each do |spark|
        next unless spark[:time] > 0

        spark[:time] -= 1
        spark[:sprite].visible = spark[:time] > 0
      end
    end

    # Le disque ralentit, puis les résultats
    def update_stop
      @stop_time += 1
      @rpm = [@rpm - 3, 0].max
      @angle = (@angle + (@rpm > 0 ? degrees_per_frame : 0)) % 360
      @disk.angle = @angle.round
      return if @stop_time < 40

      make_block
      @page = 0
      show_results
      @state = :result
    end

    def make_block
      @block = Pokeblocs.rse_blend(@berries, @max_rpm, @fail)
      @stored = Pokeblocs.add(@block)
      @made += 1 if @stored
    end

    def ranking
      scores = @counts.map { |p, g, m| p * 10_000 + g * 100 - m }
      order = (0...@names.size).sort_by { |i| [-scores[i], i] }
      ranks = []
      order.each_with_index do |player, k|
        ranks << (k > 0 && scores[player] == scores[order[k - 1]] ? ranks.last : k + 1)
      end
      return order.zip(ranks)
    end

    def show_results
      @stack.visible = false
      @result_stack.visible = true
      speed = format('%.1f', @max_rpm).tr('.', Pokeblocs.fr? ? ',' : '.')
      @result_speed.text = Pokeblocs.t("Vitesse max : #{speed} tr/min", "Max speed: #{speed} RPM")
      @order = ranking
      refresh_result_page
      @result_block.set_bitmap(Pokeblocs.big_icon(@block), :interface)
      level = Pokeblocs.level(@block)
      @result_line1.text = Pokeblocs.t("Vous obtenez un #{Pokeblocs.name(@block)} !", "You got a #{Pokeblocs.name(@block)}!")
      @result_line2.text = Pokeblocs.t("Niv. #{level}   Douceur #{@block['feel']}", "Lv. #{level}   Feel #{@block['feel']}")
    end

    def refresh_result_page
      @result_marks.each { |s| s.visible = @page == 0 }
      @result_rows.each_with_index do |row, k|
        player, rank = @order[k]
        visible = !player.nil?
        row[:name].visible = visible
        row[:counts].each { |t| t.visible = visible && @page == 0 }
        row[:berry].visible = visible && @page == 1
        next unless visible

        row[:name].text = "#{rank}. #{@names[player]}"
        @counts[player].each_with_index { |v, i| row[:counts][i].text = v.to_s }
        row[:berry].text = Pokeblocs.item_name(@berries[player])
      end
    end

    def update_result
      if Input.trigger?(:A) && @page == 0
        @page = 1
        refresh_result_page
        return
      end
      return unless Input.trigger?(:A) || Input.trigger?(:B)

      unless @stored
        display_message(Pokeblocs.t('La Boîte Pokébloc est pleine ! Le Pokébloc est perdu...',
                                    'The Pokéblock Case is full! The Pokéblock was lost...'))
      end
      again = !Pokeblocs.full? && !Pokeblocs.bag_berries.empty? &&
              display_message(Pokeblocs.t('Voulez-vous mixer une autre baie ?', 'Would you like to blend another Berry?'), 1,
                              Pokeblocs.t('Oui', 'Yes'), Pokeblocs.t('Non', 'No')) == 0
      return finish unless again

      @state = :start
      @wait = 1
    end

    def finish
      @running = false
    end
  end

  # Kit Pokébloc : 1 à 4 baies, un Pokébloc par baie
  class SimpleBlenderScene < GamePlay::BaseCleanUpdate
    include BerryPicker
    DARK = 0
    START = [[40, 40], [280, 40], [40, 200], [280, 200]].freeze
    # @return [Integer] nombre de Pokéblocs obtenus
    attr_reader :made

    def initialize
      super()
      @made = 0
      @state = :start
      @wait = 2
    end

    def update_inputs
      return true if (@wait -= 1) > 0

      case @state
      when :start then choose
      when :drop then update_drop
      when :spin then update_spin
      end
      return true
    end

    private

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_sprite(0, 0, Pokeblocs.file('mixeur_simple_fond'))
      frame = @stack.add_sprite(0, 0, Pokeblocs.file('mixeur_simple'))
      frame.set_position((320 - frame.width) / 2, (240 - frame.height) / 2)
      @disk = @stack.add_sprite(160, 120, Pokeblocs.file('disque_simple'))
      @disk.set_origin(@disk.width / 2, @disk.height / 2)
      @sprites = []
      Pokeblocs.play_bgm(Pokeblocs.setting('bgm'))
    end

    def choose
      if @first.nil?
        @first = true
        display_message(Pokeblocs.t('Mettez jusqu’à 4 baies dans le Kit Pokébloc.', 'Put up to 4 Berries in the Pokéblock Kit.'))
      end
      @berries = []
      loop do
        berry = pick_berry(@berries.empty?)
        break unless berry

        @berries << berry
        break if @berries.size >= 4 || Pokeblocs.bag_berries.empty?
        break if display_message(Pokeblocs.t('Ajouter une autre baie ?', 'Add another Berry?'), 1,
                                 Pokeblocs.t('Oui', 'Yes'), Pokeblocs.t('Non', 'No')) != 0
      end
      return @running = false if @berries.empty?

      @sprites.each(&:dispose)
      @sprites = @berries.each_with_index.map do |b, i|
        sprite = berry_sprite(@stack, b)
        sprite.set_position(*START[i])
        sprite
      end
      @time = 0
      @state = :drop
    end

    def update_drop
      @time += 1
      t = (@time / 30.0).clamp(0, 1)
      @sprites.each_with_index do |sprite, i|
        sx, sy = START[i]
        sprite.set_position(sx + (160 - sx) * t, sy + (120 - sy) * t)
        sprite.opacity = (255 * (1 - t * 0.8)).round
      end
      return if @time < 32

      @sprites.each { |s| s.visible = false }
      @time = 0
      @state = :spin
    end

    def update_spin
      @time += 1
      speed = @time < 60 ? @time / 4.0 : [15 - (@time - 60) / 3.0, 0].max
      @disk.angle = (@disk.angle + speed) % 360
      Pokeblocs.play_se('mixeur_bien', 60) if @time % 20 == 1 && @time < 100
      return if @time < 110

      blocks = Pokeblocs.simple_blend(@berries)
      stored = blocks.count { |block| Pokeblocs.add(block) }
      @made += stored
      Pokeblocs.play_se('mixeur_parfait')
      display_message(Pokeblocs.t("Vous obtenez #{Pokeblocs.plural(blocks.first, stored)} !",
                                  "You made #{stored} #{Pokeblocs.name(blocks.first)}!")) if stored > 0
      if stored < blocks.size
        display_message(Pokeblocs.t('La Boîte Pokébloc est pleine !', 'The Pokéblock Case is full!'))
      end
      again = !Pokeblocs.full? && !Pokeblocs.bag_berries.empty? &&
              display_message(Pokeblocs.t('Voulez-vous mixer d’autres baies ?', 'Would you like to blend more Berries?'), 1,
                              Pokeblocs.t('Oui', 'Yes'), Pokeblocs.t('Non', 'No')) == 0
      return @running = false unless again

      @state = :start
    end
  end
end

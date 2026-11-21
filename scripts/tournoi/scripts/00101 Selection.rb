# Tournoi : écran de sélection d'équipe (façon Pokémon Champions)
#   Haut / Bas : choisir un Pokémon   A : menu (Engager / Retirer, Résumé, Retour)
#   Droite : voir l'équipe adverse (si les règles le permettent, A : son résumé)   Gauche : revenir
# Quand le nombre de Pokémon est atteint : « Ces choix vous conviennent ? » (Non : on recommence le choix).
module Tournoi
  # Fond animé (planches de 10 images de 320x240) dans un viewport teinté
  class AnimatedLayer
    FRAME_W = 320
    PER_SHEET = 10

    # @param viewport [Viewport]
    # @param prefix [String] bg ou particles
    # @param speed [Numeric] 0.5, 1 ou 2
    def initialize(viewport, prefix, speed)
      @sprite = Sprite.new(viewport)
      @sheets = []
      @sheets << Tournoi.file("#{prefix}_#{@sheets.size}") while RPG::Cache.interface_exist?(Tournoi.file("#{prefix}_#{@sheets.size}"))
      @count = @sheets.size * PER_SHEET
      @delay = (3 / [speed.to_f, 0.25].max).round.clamp(1, 12)
      @tick = 0
      @frame = 0
      show_frame
    end

    def update
      return if @count <= 1

      @tick += 1
      return if @tick < @delay

      @tick = 0
      @frame = (@frame + 1) % @count
      show_frame
    end

    def visible=(value)
      @sprite.visible = value
    end

    def dispose
      @sprite.dispose
    end

    private

    def show_frame
      return @sprite.visible = false if @sheets.empty?

      @sprite.bitmap = RPG::Cache.interface(@sheets[@frame / PER_SHEET])
      @sprite.src_rect.set((@frame % PER_SHEET) * FRAME_W, 0, FRAME_W, 240)
    end
  end

  # Viewports teintés comme dans le plugin d'origine
  module TintedScene
    private

    def create_tinted_viewports(tone)
      @back_viewport = Viewport.create(:main, 9_990)
      @front_viewport = Viewport.create(:main, 10_010)
      [@back_viewport, @front_viewport].each { |vp| apply_tone(vp, tone) }
    end

    def apply_tone(viewport, tone)
      return if tone.nil? || tone.all?(&:zero?)

      viewport.shader = Shader.create(:map_shader)
      viewport.tone.set(*tone)
    rescue StandardError
      nil
    end
  end

  class SelectionScene < GamePlay::BaseCleanUpdate
    include TintedScene
    WHITE = 10
    ROW_Y = 44
    ROW_H = 32
    BAR_W = 128
    BALL = 11
    # @return [Array<PFM::Pokemon>, nil] Pokémon choisis (dans l'ordre), nil si abandon
    attr_reader :choice

    # @param party [Array<PFM::Pokemon>] équipe du joueur
    # @param opponent [Hash] { name:, party: Array<PFM::Pokemon> }
    # @param rules [Hash] règles (Tournoi.rules)
    def initialize(party, opponent, rules)
      super()
      @party = party.first(6)
      @opponent = opponent
      @opp_party = Array(opponent[:party]).first(6)
      @rules = rules
      able = @party.count { |pokemon| Tournoi.able?(pokemon) }
      @pick = [rules['pick'].to_i, able].min.clamp(1, 6)
      @opp_pick = [rules['pick'].to_i, @opp_party.size].min.clamp(1, 6)
      @chosen = []
      @index = @party.index { |pokemon| Tournoi.able?(pokemon) } || 0
      @opp_index = 0
      @state = :intro
      @choice = nil
      @pulse = 0
      @opp_shown = 0
      @intro_wait = 30
      @flashes = []
    end

    def update_inputs
      case @state
      when :intro then return update_intro
      when :player then return update_player
      when :menu then return update_menu
      when :confirm then return update_confirm
      when :opponent then return update_opponent
      end
      return true
    end

    def update_graphics
      @bg.update
      @particles.update
      @rows.each { |row| row[:icon].update }
      @opp_rows.each { |row| row[:icon].update }
      update_pulse
      update_flashes
      return true
    end

    private

    # --- Création -------------------------------------------------------------------------------------------------------
    def create_viewport
      super
      create_tinted_viewports(Tournoi.tone)
    end

    def create_graphics
      super
      speed = Tournoi.setting('speed').to_f
      @bg = AnimatedLayer.new(@back_viewport, 'bg', speed)
      @particles = AnimatedLayer.new(@front_viewport, 'particles', speed)
      @back = UI::SpriteStack.new(@back_viewport)
      @stack = UI::SpriteStack.new(@viewport)
      @back.add_sprite(0, 2, Tournoi.file('top_bar'))
      @stack.add_text(0, 1, 320, 16, format(Tournoi.t('Choisissez %d Pokémon.', 'Please choose %d Pokémon.'), @pick), 1, color: WHITE)
      create_ball_bars
      @rows = @party.each_with_index.map { |pokemon, i| create_row(pokemon, i, false) }
      @opp_rows = @opp_party.each_with_index.map { |pokemon, i| create_row(pokemon, i, true) }
      @menu = CommandBox.new(@viewport)
      @question = @stack.add_text(0, 0, 0, 16, '', 1, color: WHITE)
      @question.visible = false
      refresh_rows
      Tournoi.play_bgm(Tournoi.setting('bgm'))
    end

    def create_ball_bars
      bar = @back.add_sprite(0, 19, Tournoi.file('ball_bar'))
      bar.src_rect.set(0, 0, 124, 16)
      bar = @back.add_sprite(196, 19, Tournoi.file('ball_bar'))
      bar.src_rect.set(0, 16, 124, 16)
      bar.mirror = true
      @stack.with_font(20) do
        @stack.add_text(5, 20, 60, 13, $trainer.name.to_s, color: WHITE)
        @stack.add_text(255, 20, 60, 13, @opponent[:name].to_s, 2, color: WHITE)
      end
      @slots = Array.new(@pick) { |i| ball_sprite(108 - i * 13, 21, @back, 0) }
      @balls = Array.new(@pick) { |i| ball_sprite(108 - i * 13, 21, @stack, 1) }
      @opp_slots = Array.new(@opp_pick) { |i| ball_sprite(201 + i * 13, 21, @back, 0) }
      @opp_balls = Array.new(@opp_pick) { |i| ball_sprite(201 + i * 13, 21, @stack, 1) }
      (@balls + @opp_balls).each { |ball| ball.visible = false }
    end

    def ball_sprite(x, y, stack, kind)
      sprite = stack.add_sprite(x + BALL / 2, y + BALL / 2, Tournoi.file('balls'))
      sprite.src_rect.set(kind * BALL, 0, BALL, BALL)
      sprite.set_origin(BALL / 2, BALL / 2)
      return sprite
    end

    # Ligne d'un Pokémon (à gauche : le joueur, à droite : l'adversaire, en miroir)
    def create_row(pokemon, index, opponent)
      y = ROW_Y + index * ROW_H
      x = opponent ? 320 - BAR_W : 0
      row = { pokemon: pokemon }
      row[:bar] = @back.add_sprite(x, y, Tournoi.file('poke_bar'))
      row[:bar].src_rect.set(0, 0, BAR_W, 24)
      row[:bar].mirror = opponent
      row[:sel] = @back.add_sprite(x, y, Tournoi.file('poke_bar'))
      row[:sel].src_rect.set(BAR_W, 0, BAR_W, 24)
      row[:sel].mirror = opponent
      row[:sel].opacity = 0
      text_x = opponent ? x + 54 : x + 5
      row[:name] = @stack.add_text(text_x, y + 1, opponent ? 64 : 76, 16, pokemon.given_name.to_s, opponent ? 2 : 0, color: WHITE)
      @stack.with_font(20) do
        row[:level] = @stack.add_text(text_x, y + 12, opponent ? 64 : 76, 13, format(Tournoi.t('N.%d', 'Lv.%d'), pokemon.level), opponent ? 2 : 0, color: WHITE)
      end
      row[:gender] = @stack.push(opponent ? x + 84 : x + 40, y + 13, nil, type: UI::GenderSprite)
      row[:gender].data = pokemon
      row[:icon] = @stack.push(opponent ? x + 22 : x + BAR_W - 22, y + 10, nil, type: UI::PokemonIconSprite)
      row[:icon].data = pokemon
      row[:icon].mirror = !opponent
      create_item(row, pokemon, opponent ? x + 38 : x + BAR_W - 46, y + 5, opponent)
      unless opponent
        row[:num] = @stack.add_sprite(BAR_W + 2, y + 6, Tournoi.file('nums'))
        row[:num].src_rect.set(0, 0, 13, 13)
        row[:num].visible = false
      end
      return row
    end

    def create_item(row, pokemon, x, y, opponent)
      return if pokemon.item_holding.to_i <= 0

      mode = @rules['items']
      mode = 'show' if !opponent && mode == 'hide'
      return if mode == 'none'

      if mode == 'show'
        row[:item] = @stack.push(x - 8, y - 8, nil, type: UI::ItemSprite)
        row[:item].data = pokemon.item_holding
        row[:item].zoom = 0.5
        row[:item].set_position(x, y)
      else
        row[:item] = @stack.add_sprite(x, y, Tournoi.file('item_hide'))
      end
    end

    # --- Affichage ------------------------------------------------------------------------------------------------------
    def refresh_rows
      @rows.each_with_index do |row, i|
        able = Tournoi.able?(row[:pokemon])
        [row[:name], row[:level]].each { |text| text.opacity = able ? 255 : 120 }
        row[:icon].opacity = able ? 255 : 120
        number = @chosen.index(row[:pokemon])
        row[:num].visible = !number.nil?
        row[:num].src_rect.x = number.to_i * 13
        row[:sel].opacity = 0 unless i == @index && @state != :opponent
      end
      @opp_rows.each_with_index { |row, i| row[:sel].opacity = 0 unless i == @opp_index && @state == :opponent }
      @balls.each_with_index { |ball, i| ball.visible = i < @chosen.size }
    end

    # Ligne en surbrillance (clignote doucement)
    def update_pulse
      row = @state == :opponent ? @opp_rows[@opp_index] : @rows[@index]
      return unless row

      @pulse = (@pulse + 1) % 72
      row[:sel].opacity = 255 - (@pulse < 36 ? @pulse : 72 - @pulse) * 4
    end

    # Ball qui apparaît dans un éclair blanc
    def flash_ball(ball)
      ball.visible = true
      ball.zoom = 1.8
      @flashes << ball
    end

    def update_flashes
      @flashes.reject! do |ball|
        ball.zoom = [ball.zoom - 0.1, 1].max
        ball.zoom <= 1
      end
    end

    # --- États ----------------------------------------------------------------------------------------------------------
    # L'adversaire choisit ses Pokémon (ses Balls apparaissent une à une)
    def update_intro
      @intro_wait -= 1
      return true if @intro_wait > 0

      if @opp_shown < @opp_pick
        flash_ball(@opp_balls[@opp_shown])
        @opp_shown += 1
        @intro_wait = 12
        return true
      end
      @state = :player
      refresh_rows
      return true
    end

    def update_player
      if Input.repeat?(:UP) || Input.repeat?(:DOWN)
        move_index(Input.repeat?(:UP) ? -1 : 1)
      elsif Input.trigger?(:A)
        open_menu
      elsif Input.trigger?(:RIGHT) && @rules['show_opponent'] && !@opp_rows.empty?
        play_cursor_se
        @state = :opponent
        @opp_index = @index.clamp(0, @opp_rows.size - 1)
        refresh_rows
      elsif Input.trigger?(:B)
        return cancel_selection
      end
      return true
    end

    def move_index(delta)
      return if @rows.size <= 1

      play_cursor_se
      @rows[@index][:sel].opacity = 0
      @index = (@index + delta) % @rows.size
      @pulse = 0
      refresh_rows
    end

    def open_menu
      pokemon = @rows[@index][:pokemon]
      play_decision_se
      first = @chosen.include?(pokemon) ? Tournoi.t('Retirer', 'Retire') : Tournoi.t('Engager', 'Enter')
      @menu.open(BAR_W + 18, ROW_Y + @index * ROW_H, [first, Tournoi.t('Résumé', 'Summary'), Tournoi.t('Retour', 'Cancel')])
      @state = :menu
    end

    def update_menu
      choice = @menu.update_input(self)
      return true if choice.nil?

      @menu.close
      @state = :player
      case choice
      when 0 then toggle_current
      when 1 then show_summary(@party, @index)
      end
      return true
    end

    def toggle_current
      pokemon = @rows[@index][:pokemon]
      if @chosen.include?(pokemon)
        @chosen.delete(pokemon)
        refresh_rows
        return
      end
      return play_buzzer_se unless Tournoi.able?(pokemon)

      @chosen << pokemon
      refresh_rows
      flash_ball(@balls[@chosen.size - 1])
      ask_confirm if @chosen.size >= @pick
    end

    def ask_confirm
      @state = :confirm
      @question.x = 40
      @question.y = 186
      @question.width = 240
      @question.text = Tournoi.t('Ces choix vous conviennent ?', 'Are you happy with these choices?')
      @question.visible = true
      @menu.open(124, 202, [Tournoi.t('Oui', 'Yes'), Tournoi.t('Non', 'No')], wide: true, banner: true)
    end

    def update_confirm
      choice = @menu.update_input(self)
      return true if choice.nil?

      @menu.close
      @question.visible = false
      if choice == 0
        @choice = @chosen.dup
        @running = false
        return false
      end
      play_cancel_se
      @chosen.clear
      @state = :player
      refresh_rows
      return true
    end

    def update_opponent
      if Input.repeat?(:UP) || Input.repeat?(:DOWN)
        return true if @opp_rows.size <= 1

        play_cursor_se
        @opp_rows[@opp_index][:sel].opacity = 0
        @opp_index = (@opp_index + (Input.repeat?(:UP) ? -1 : 1)) % @opp_rows.size
        @pulse = 0
      elsif Input.trigger?(:A)
        play_decision_se
        show_summary(@opp_party, @opp_index)
      elsif Input.trigger?(:LEFT) || Input.trigger?(:B)
        play_cursor_se
        @state = :player
        refresh_rows
      end
      return true
    end

    def show_summary(party, index)
      call_scene(GamePlay::Summary, party[index], :view, party)
    end

    def cancel_selection
      return true unless @rules['cancel']

      play_cancel_se
      choice = display_message(Tournoi.t('Abandonner ?', 'Give up?'), 2, Tournoi.t('Oui', 'Yes'), Tournoi.t('Non', 'No'))
      if choice == 0
        @choice = nil
        @running = false
        return false
      end
      return true
    end
  end

  # Petit menu (Engager / Résumé / Retour, ou Oui / Non)
  class CommandBox < UI::SpriteStack
    WHITE = 10

    def initialize(viewport)
      super(viewport)
      @shade = add_sprite(0, 0, Tournoi.file('shade'))
      @box = add_sprite(0, 0, Tournoi.file('menu'))
      @cursor = add_sprite(0, 0, Tournoi.file('menu_cursor'))
      @banner = add_sprite(0, 0, Tournoi.file('banner'))
      @texts = Array.new(3) { add_text(0, 0, 60, 16, '', color: WHITE) }
      @index = 0
      @count = 0
      self.visible = false
    end

    # @param x [Integer]
    # @param y [Integer]
    # @param commands [Array<String>]
    def open(x, y, commands, wide: false, banner: false)
      @count = commands.size
      @index = 0
      @wide = wide
      self.visible = true
      @banner.visible = banner
      @shade.visible = banner
      @banner.set_position(36, 182)
      if wide
        @box.src_rect.set(0, 52, 72, 20)
        @box.set_position(x, y)
        @texts.each_with_index do |text, i|
          text.visible = i < @count
          text.x = x + 4 + i * 34
          text.y = y + 1
          text.width = 30
          text.align = 1
          text.text = commands[i].to_s
        end
      else
        y = y.clamp(20, 240 - 56)
        @box.src_rect.set(0, 0, 72, 52)
        @box.set_position(x, y)
        @texts.each_with_index do |text, i|
          text.visible = i < @count
          text.x = x + 10
          text.y = y + 3 + i * 15
          text.width = 60
          text.align = 0
          text.text = commands[i].to_s
        end
      end
      @origin = [x, y]
      refresh_cursor
    end

    def close
      self.visible = false
    end

    # @param scene [GamePlay::Base]
    # @return [Integer, nil] choix (dernier = retour avec B)
    def update_input(scene)
      prev, nxt = @wide ? %i[LEFT RIGHT] : %i[UP DOWN]
      if Input.repeat?(prev) || Input.repeat?(nxt)
        scene.send(:play_cursor_se)
        @index = (@index + (Input.repeat?(prev) ? -1 : 1)) % @count
        refresh_cursor
      elsif Input.trigger?(:A)
        scene.send(:play_decision_se)
        return @index
      elsif Input.trigger?(:B)
        scene.send(:play_cancel_se)
        return @count - 1
      end
      return nil
    end

    private

    def refresh_cursor
      x, y = @origin
      if @wide
        @cursor.src_rect.set(0, 0, 34, 16)
        @cursor.set_position(x + 2 + @index * 34, y + 2)
      else
        @cursor.src_rect.set(0, 16, 68, 14)
        @cursor.set_position(x + 2, y + 4 + @index * 15)
      end
    end
  end
end

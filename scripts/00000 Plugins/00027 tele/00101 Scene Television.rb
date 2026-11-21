# Télé : la scène (commande tele_regarder)
#   Chaînes     : gauche / droite change de chaîne, A l'ouvre, B quitte
#   Programmes  : haut / bas choisit un programme, A le regarde, B revient aux chaînes
#   Programme   : le présentateur parle ; A passe à l'écran suivant (le dernier termine le programme), B revient à la liste
# Un programme regardé jusqu'au bout n'est plus « nouveau ».
module GamePlay
  class TV < BaseCleanUpdate::FrameBalanced
    T = ::Television
    DARK = 0
    WHITE = 9
    FONT = 20
    TEXT_FONT = 18
    SX = T::SCREEN_X
    SY = T::SCREEN_Y
    # Liste de programmes
    ROWS = 4
    ROW_H = 22
    LIST_X = 8
    LIST_Y = 26
    # Programme : bannière, présentateur, fenêtre de texte
    BANNER_POS = [18, 26].freeze
    PRESENTER_POS = [158, 26].freeze
    TEXT_WINDOW = [8, 110].freeze
    LINE_H = 15

    # @return [Boolean] un programme a été regardé jusqu'au bout
    attr_reader :watched

    # @param channel [Integer, nil] chaîne (1 à 8) ouverte directement, nil pour le choix des chaînes
    def initialize(channel = nil)
      super()
      @tick = 0
      @watched = false
      @channel = 0
      @direct = false
      @row = 0
      @offset = 0
      @page = 0
      @state = :channels
      if channel && channel.to_i.between?(1, T::CHANNELS.size)
        @channel = channel.to_i - 1
        @direct = true
        @state = :programs
      end
      @programs = T.channel_programs(@channel)
      # chaîne ouverte directement mais vide : on retombe sur le choix des chaînes
      @state = :channels if @direct && @programs.empty?
      @direct = false if @state == :channels
    end

    def update_inputs
      case @state
      when :channels then update_channels
      when :programs then update_programs
      else update_show
      end
      return false
    end

    def update_graphics
      @tick += 1
      @marker.set_position(SX + 123, SY + 30 + (@tick / 12) % 2 * 2) if @state == :channels
      refresh_arrow if @state == :show
      return nil
    end

    private

    # --- Chaînes -----------------------------------------------------------------------------
    def update_channels
      if Input.repeat?(:LEFT)
        move_channel(-1)
      elsif Input.repeat?(:RIGHT)
        move_channel(1)
      elsif Input.trigger?(:A)
        open_channel
      elsif Input.trigger?(:B)
        play_cancel_se
        @running = false
      end
    end

    def move_channel(delta)
      @channel = (@channel + delta) % T::CHANNELS.size
      play_cursor_se
      refresh_channels
    end

    def open_channel
      @programs = T.channel_programs(@channel)
      return play_buzzer_se if @programs.empty?

      @row = 0
      @offset = 0
      play_decision_se
      show_state(:programs)
    end

    # --- Programmes --------------------------------------------------------------------------
    def update_programs
      if Input.repeat?(:UP)
        move_row(-1)
      elsif Input.repeat?(:DOWN)
        move_row(1)
      elsif Input.trigger?(:A)
        start_program
      elsif Input.trigger?(:B)
        play_cancel_se
        return (@running = false) if @direct

        show_state(:channels)
      end
    end

    def move_row(delta)
      return if @programs.size <= 1

      @row = (@row + delta) % @programs.size
      @offset = @row if @row < @offset
      @offset = @row - ROWS + 1 if @row >= @offset + ROWS
      @offset = 0 if @programs.size <= ROWS
      play_cursor_se
      refresh_programs
    end

    def start_program
      @program = @programs[@row]
      return play_buzzer_se unless @program

      @screens = T.screens(@program)
      @page = 0
      play_decision_se
      show_state(:show)
    end

    # --- Lecture -----------------------------------------------------------------------------
    def update_show
      if Input.trigger?(:A)
        if @page + 1 < @screens.size
          @page += 1
          play_cursor_se
          refresh_show
        else
          finish_program
        end
      elsif Input.trigger?(:B)
        play_cancel_se
        show_state(:programs)
      end
    end

    def finish_program
      T.mark_seen(@program)
      @watched = true
      play_decision_se
      show_state(:programs)
    end

    # --- Création ----------------------------------------------------------------------------
    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.add_sprite(0, 0, 'tele/ecran_fond')
      @stack.add_sprite(SX, SY, 'tele/fond')
      @header = @stack.add_sprite(SX, SY, 'tele/entete')
      @footer = @stack.add_sprite(SX, SY + 172, 'tele/pied')
      @title = @stack.with_font(FONT) { @stack.add_text(SX + 6, SY + 4, 190, 16, '', color: WHITE) }
      @right = @stack.with_font(FONT) { @stack.add_text(SX + 150, SY + 4, 100, 16, '', 2, color: WHITE) }
      @hint = @stack.with_font(FONT) { @stack.add_text(SX, SY + 176, 256, 16, '', 1, color: WHITE) }
      create_channel_sprites
      create_program_sprites
      create_show_sprites
      show_state(@state)
    end

    def create_channel_sprites
      @previous = @stack.add_sprite(SX + 8, SY + 70, 'tele/chaine_petite_1')
      @current = @stack.add_sprite(SX + 72, SY + 50, 'tele/chaine_1')
      @next = @stack.add_sprite(SX + 192, SY + 70, 'tele/chaine_petite_2')
      @previous.opacity = 150
      @next.opacity = 150
      @marker = @stack.add_sprite(SX + 123, SY + 30, 'tele/fleche_bas')
      @channel_name = @stack.with_font(FONT) { @stack.add_text(SX, SY + 136, 256, 16, '', 1, color: DARK) }
      @channel_info = @stack.with_font(TEXT_FONT) { @stack.add_text(SX, SY + 153, 256, 16, '', 1, color: DARK) }
      @badge = @stack.add_sprite(SX + 128, SY + 54, 'tele/badge_nouveau')
      @badge_text = @stack.with_font(TEXT_FONT) { @stack.add_text(SX + 128, SY + 54, 56, 16, '', 1, color: WHITE) }
      @channel_group = [@previous, @current, @next, @marker, @channel_name, @channel_info, @badge, @badge_text]
    end

    def create_program_sprites
      @list_window = @stack.add_sprite(SX + LIST_X, SY + LIST_Y, 'tele/fenetre_liste')
      @arrow = @stack.add_sprite(SX + LIST_X + 12, SY + LIST_Y + 14, 'tele/fleche_droite')
      @row_icons = Array.new(ROWS) { |i| @stack.add_sprite(SX + LIST_X + 30, SY + LIST_Y + 14 + i * ROW_H, 'tele/icone_petite') }
      @row_texts = Array.new(ROWS) do |i|
        @stack.with_font(FONT) { @stack.add_text(SX + LIST_X + 54, SY + LIST_Y + 14 + i * ROW_H, 120, 16, '', color: DARK) }
      end
      @row_badges = Array.new(ROWS) { |i| @stack.add_sprite(SX + LIST_X + 176, SY + LIST_Y + 13 + i * ROW_H, 'tele/badge_nouveau') }
      @row_badge_texts = Array.new(ROWS) do |i|
        @stack.with_font(TEXT_FONT) { @stack.add_text(SX + LIST_X + 176, SY + LIST_Y + 13 + i * ROW_H, 56, 16, '', 1, color: WHITE) }
      end
      @program_group = [@list_window, @arrow] + @row_icons + @row_texts + @row_badges + @row_badge_texts
    end

    def create_show_sprites
      @banner = @stack.add_sprite(SX + BANNER_POS[0], SY + BANNER_POS[1], 'tele/chaine_1')
      @presenter = @stack.add_sprite(SX + PRESENTER_POS[0], SY + PRESENTER_POS[1], 'tele/presentateur_1')
      @text_window = @stack.add_sprite(SX + TEXT_WINDOW[0], SY + TEXT_WINDOW[1], 'tele/fenetre_texte')
      @lines = Array.new(T::LINES) do |i|
        @stack.with_font(TEXT_FONT) { @stack.add_text(SX + TEXT_WINDOW[0] + 16, SY + TEXT_WINDOW[1] + 8 + i * LINE_H, 208, 14, '', color: DARK) }
      end
      @more = @stack.add_sprite(SX + 226, SY + 144, 'tele/fleche_bas')
      @show_group = [@banner, @presenter, @text_window, @more] + @lines
    end

    # @param state [Symbol] :channels, :programs ou :show
    def show_state(state)
      @state = state
      @channel_group.each { |element| element.visible = state == :channels }
      @program_group.each { |element| element.visible = state == :programs }
      @show_group.each { |element| element.visible = state == :show }
      case state
      when :channels then refresh_channels
      when :programs then refresh_programs
      else refresh_show
      end
    end

    # --- Affichage ---------------------------------------------------------------------------
    def refresh_channels
      count = T::CHANNELS.size
      @current.set_bitmap("tele/chaine_#{@channel + 1}", :interface)
      @previous.set_bitmap("tele/chaine_petite_#{(@channel - 1) % count + 1}", :interface)
      @next.set_bitmap("tele/chaine_petite_#{(@channel + 1) % count + 1}", :interface)
      @title.text = text(:title)
      @right.text = "#{@channel + 1}/#{count}"
      @channel_name.text = T.channel_name(@channel)
      total = T.channel_programs(@channel).size
      @channel_info.text = total.zero? ? text(:nothing) : "#{total} #{text(total > 1 ? :programs : :program)}"
      new = T.unseen_count(@channel) > 0
      @badge.visible = new
      @badge_text.visible = new
      @badge_text.text = new ? text(:new) : ''
      @hint.text = text(:hint_channels)
    end

    def refresh_programs
      @title.text = T.channel_name(@channel)
      @right.text = "#{@row + 1}/#{@programs.size}"
      ROWS.times do |i|
        program = @programs[@offset + i]
        @row_icons[i].visible = program ? true : false
        @row_texts[i].text = program ? T.title_of(program) : ''
        new = program && !T.seen?(program)
        @row_badges[i].visible = new ? true : false
        @row_badge_texts[i].text = new ? text(:new) : ''
      end
      @arrow.set_position(SX + LIST_X + 12, SY + LIST_Y + 14 + (@row - @offset) * ROW_H)
      @hint.text = text(:hint_programs)
    end

    def refresh_show
      @title.text = T.title_of(@program)
      @right.text = T.presenter_name(T.presenter_of(@program))
      @banner.set_bitmap("tele/chaine_#{T.channel_of(@program) + 1}", :interface)
      @presenter.set_bitmap("tele/presentateur_#{T.presenter_of(@program) + 1}", :interface)
      lines = @screens[@page]
      @lines.each_with_index { |line, i| line.text = lines[i].to_s }
      @hint.text = text(@page + 1 < @screens.size ? :hint_next : :hint_end)
      refresh_arrow
    end

    # La flèche « suite » clignote tant qu'il reste des écrans
    def refresh_arrow
      @more.visible = @page + 1 < @screens.size && @tick % 40 < 28
    end

    TEXTS = {
      title: ['Télévision', 'Television'],
      program: ['programme', 'program'],
      programs: ['programmes', 'programs'],
      nothing: ['Rien en ce moment', 'Nothing right now'],
      new: ['NOUVEAU', 'NEW'],
      hint_channels: ['G/D : chaîne   A : voir   B : quitter', 'L/R: channel   A: watch   B: quit'],
      hint_programs: ['A : regarder   B : retour', 'A: watch   B: back'],
      hint_next: ['A : suite   B : retour', 'A: next   B: back'],
      hint_end: ['A : terminer   B : retour', 'A: finish   B: back']
    }.freeze

    # @param key [Symbol]
    # @return [String]
    def text(key)
      return TEXTS[key][T.language_index]
    end
  end
end

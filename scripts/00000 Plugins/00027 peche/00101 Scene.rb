# encoding: utf-8
# Pêche : la scène du mini-jeu (attente, touche, combat de tension)
module Peche
  module_function

  # @return [Boolean] la scène a déjà dit pourquoi la pêche a échoué
  def message_done?
    return @message_done == true
  end

  def message_done=(value)
    @message_done = value
  end

  # Fin de partie : statistiques
  # @param won [Boolean]
  # @param reaction [Integer, nil] images mises à réagir
  # @param perfect [Boolean]
  def record(won, reaction = nil, perfect = false)
    store = data
    won ? store['caught'] += 1 : store['lost'] += 1
    store['perfect'] += 1 if perfect
    store['best'] = reaction if reaction && (store['best'].nil? || reaction < store['best'])
  end
end

module GamePlay
  class PecheScene < BaseCleanUpdate
    WHITE = 9
    SEA_Y = 112
    BOBBER = [190, 130].freeze

    # @return [Symbol] :caught, :failed ou :cancel
    attr_reader :result

    # @param type [Symbol] :normal, :super, :mega
    def initialize(type = :normal)
      super()
      @type = type.to_sym
      @rod = Peche.rod(@type)
      @state = :wait
      @frame = 0
      @result = :cancel
      @perfect = false
      @reaction = nil
    end

    def update_inputs
      case @state
      when :wait then input_wait
      when :bite then input_bite
      end
      return true
    end

    def update_graphics
      @frame += 1
      animate_bobber
      case @state
      when :wait then update_wait
      when :bite then update_bite
      when :reel then update_reel
      when :over then update_over
      end
      return true
    end

    private

    # Toutes les images viennent de ressources déjà présentes dans le jeu :
    #  - fond : graphics/battlebacks/back_sea_day   - fenêtre : graphics/windowskins/battle_pj_message
    #  - jauges : graphics/interface/succes/bar_big(_fill)   - flotteur et curseur : graphics/interface/ball_normal
    #  - « ! » : graphics/animations/!   - poisson : sprite de face d'un Magicarpe, passé en silhouette
    BAR_X = 12
    BAR_W = 294
    EXCLAMATION = [466, 82, 28, 28].freeze
    FISH_FILE = '0129'

    def create_graphics
      super
      bgm = Peche.setting('bgm').to_s
      Audio.bgm_play("audio/bgm/#{bgm}") unless bgm.empty?
      @bg = Sprite.new(@viewport).set_bitmap('back_sea_day', :battleback)
      @line_bmp = Bitmap.new(2, 2)
      @line_bmp.fill_rect(0, 0, 2, 2, Color.new(255, 255, 255))
      @line = Sprite.new(@viewport)
      @line.bitmap = @line_bmp
      @line.z = 4
      @fish = build_fish
      @bobber = Sprite.new(@viewport).set_bitmap('ball_normal', :interface)
      @bobber.z = 5
      @mark = Sprite.new(@viewport).set_bitmap('!', :animation)
      @mark.src_rect.set(*EXCLAMATION)
      @mark.z = 6
      @mark.visible = false
      @panel = Sprite.new(@viewport).set_bitmap('battle_pj_message', :windowskin)
      @panel.set_position(0, 190)
      @panel.z = 20
      @stack = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @stack.with_font(20) do
        @msg = @stack.add_text(10, 196, 300, 14, '', 1, color: WHITE)
        @msg.z = 21
        @sub = @stack.add_text(10, 213, 300, 14, '', 1, color: WHITE)
        @sub.z = 21
      end
      build_gauges
      animate_bobber
      say(Peche.t('Attends que ça morde…', 'Wait for a bite…'), Peche.t('B : ranger la canne', 'B: put the rod away'))
    end

    # Silhouette sombre d'un Magicarpe (sprite du jeu), vue sous l'eau
    def build_fish
      sprite = Sprite.new(@viewport)
      sprite.set_bitmap(FISH_FILE, :poke_front)
      sprite.ox = sprite.bitmap.width / 2
      sprite.oy = sprite.bitmap.height / 2
      sprite.zoom = 0.5
      sprite.opacity = 210
      sprite.z = 3
      sprite.visible = false
      return sprite
    rescue StandardError
      return Sprite.new(@viewport).tap { |blank| blank.visible = false }
    end

    ZONES = [[0.0, 0.08, [40, 90, 230, 150]], [0.08, 0.75, [30, 200, 70, 150]], [0.75, 1.0, [230, 50, 40, 170]]].freeze

    def build_gauges
      @gauge = []
      @gauge_bg = Sprite.new(@viewport).set_bitmap('succes/bar_big', :interface)
      @gauge_bg.set_position(BAR_X, 16)
      @gauge_bg.z = 10
      @gauge << @gauge_bg
      ZONES.each do |from, to, rgba|
        zone = Sprite.new(@viewport).set_bitmap('succes/bar_big_fill', :interface)
        zone.set_position(BAR_X + 1 + (BAR_W * from).round, 17)
        zone.src_rect.set((BAR_W * from).round, 0, (BAR_W * (to - from)).round, 6)
        zone.color.set(*rgba)
        zone.z = 11
        @gauge << zone
      end
      @marker = Sprite.new(@viewport).set_bitmap('ball_normal', :interface)
      @marker.z = 12
      @prog_bg = Sprite.new(@viewport).set_bitmap('succes/bar_big', :interface)
      @prog_bg.set_position(BAR_X, 32)
      @prog_bg.z = 10
      @prog = Sprite.new(@viewport).set_bitmap('succes/bar_big_fill', :interface)
      @prog.set_position(BAR_X + 1, 33)
      @prog.z = 11
      @gauge.push(@marker, @prog_bg, @prog)
      @gauge.each { |sprite| sprite.visible = false }
    end

    def say(main, sub = '')
      @msg.text = main
      @sub.text = sub
    end

    # --- Flotteur ---------------------------------------------------------------------------------------------------
    def animate_bobber
      bob = Math.sin(@frame / 14.0) * 2
      shake = @state == :reel ? ((@frame % 4 < 2 ? 1 : -1) * (@reel && @reel.mode != :calm ? 3 : 1)) : 0
      dip = @state == :bite || @state == :reel ? 5 : 0
      @bobber.set_position(BOBBER[0] - 7 + shake, BOBBER[1] + bob + dip)
      top = 40
      @line.set_position(BOBBER[0], top)
      @line.zoom_y = [(@bobber.y - top) / 2.0, 1].max
    end

    # --- Attente ----------------------------------------------------------------------------------------------------
    def input_wait
      if Input.trigger?(:B) || Mouse.trigger?(:RIGHT)
        play_cancel_se
        @result = :cancel
        return @running = false
      end
      return unless Input.trigger?(:A) || Mouse.trigger?(:LEFT)

      fail_with(Peche.t('Tu as tiré trop tôt : le poisson s’est enfui !', 'Too early: the fish got away!'), 'splash')
    end

    def update_wait
      @wait ||= rand(Array(Peche.fetch(@rod, 'wait')).first.to_i..[Array(Peche.fetch(@rod, 'wait')).last.to_i, 60].max)
      return unless @frame >= @wait

      @state = :bite
      @bite_frame = @frame
      @window = [Peche.fetch(@rod, 'window').to_i, 10].max
      @mark.visible = true
      @mark.set_position(BOBBER[0] - 14, BOBBER[1] - 46)
      Peche.play_se('bite')
      say(Peche.t('Ça mord ! Appuie sur A !', 'A bite! Press A!'), '')
    end

    # --- Touche -----------------------------------------------------------------------------------------------------
    def input_bite
      return unless Input.trigger?(:A) || Mouse.trigger?(:LEFT)

      @reaction = @frame - @bite_frame
      @perfect = @reaction <= Peche.setting('perfect_frames').to_i
      @mark.visible = false
      Peche.play_se('hook')
      start_reel
    end

    def update_bite
      @mark.set_position(BOBBER[0] - 14, BOBBER[1] - 46 - (@frame % 8 < 4 ? 2 : 0))
      return unless @frame - @bite_frame > @window

      @mark.visible = false
      fail_with(Peche.t('Trop tard : il a lâché l’appât !', 'Too late: it let go of the bait!'), 'splash')
    end

    # --- Combat -----------------------------------------------------------------------------------------------------
    def start_reel
      @state = :reel
      @reel = Peche::Reel.new(@rod, @perfect ? Peche.setting('perfect_bonus').to_f : 0.0)
      @fish.visible = true
      @gauge.each { |sprite| sprite.visible = true }
      say(@perfect ? Peche.t('Prise parfaite !', 'Perfect hook!') : Peche.t('Ferré !', 'Hooked!'),
          Peche.t('Maintiens A pour enrouler, relâche quand il tire', 'Hold A to reel in, let go when it pulls'))
    end

    def update_reel
      pressed = Input.press?(:A) || Mouse.press?(:LEFT)
      @reel.step(pressed)
      update_reel_visuals
      case @reel.result
      when :win then finish(true, Peche.t('Il est ferré !', 'Caught on the line!'), 'win')
      when :snap then fail_with(Peche.t('Le fil a cassé !', 'The line snapped!'), 'snap')
      when :slack then fail_with(Peche.t('Le fil était trop mou : il s’est échappé…', 'The line went slack: it got away…'), 'splash')
      when :escape then fail_with(Peche.t('Le poisson s’est échappé !', 'The fish got away!'), 'splash')
      end
    end

    def update_reel_visuals
      @marker.set_position(BAR_X + 1 + (@reel.tension.clamp(0, 100) / 100.0 * BAR_W).round - 7, 2)
      @prog.src_rect.set(0, 0, (@reel.progress.clamp(0, 100) / 100.0 * BAR_W).round, 6)
      swing = Math.sin(@frame / 9.0) * (@reel.mode == :pull ? 26 : 14)
      @fish.set_position(BOBBER[0] + swing, BOBBER[1] + 28 + Math.sin(@frame / 17.0) * 5)
      warn = @reel.mode != :calm && (@frame % 8 < 4 || @reel.mode == :pull)
      warn ? @fish.color.set(230, 40, 40, 150) : @fish.color.set(0, 0, 20, 170)
      case @reel.mode
      when :warn then say(Peche.t('Il va tirer : relâche !', 'It’s about to pull: let go!'), '')
      when :pull then say(Peche.t('Il tire !', 'It pulls!'), Peche.t('Laisse le fil filer', 'Let the line run'))
      else
        say(Peche.t('Enroule !', 'Reel in!'), Peche.t('Reste dans le vert', 'Stay in the green')) if @frame % 30 == 0
      end
    end

    # --- Fin --------------------------------------------------------------------------------------------------------
    def finish(won, text, sound)
      @state = :over
      @over = 0
      @result = won ? :caught : :failed
      Peche.message_done = !won
      Peche.record(won, @reaction, @perfect)
      Peche.play_se(sound)
      [@mark].each { |sprite| sprite.visible = false }
      say(text, won && @perfect ? Peche.t('Prise parfaite !', 'Perfect hook!') : '')
    end

    def fail_with(text, sound)
      finish(false, text, sound)
    end

    def update_over
      @over += 1
      return unless @over > 75 || (@over > 20 && (Input.trigger?(:A) || Input.trigger?(:B)))

      @running = false
    end
  end
end

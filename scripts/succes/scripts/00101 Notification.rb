# Succès : bandeau « Succès obtenu ! » sur la carte, et vérification régulière des conditions automatiques
module Succes
  module Notification
    # Durées en images : entrée, affichage, sortie
    IN = 14
    HOLD = 150
    OUT = 14
    X = 56
    Y = 4
    HEIGHT = 32

    module_function

    # @return [Array<Hash>] succès en attente d'affichage
    def queue
      return @queue ||= []
    end

    # @param achievement [Hash]
    def push(achievement)
      queue << achievement
    end

    # Appelé à chaque image sur la carte
    def update
      return show(queue.shift) if !@stack && !queue.empty?
      return unless @stack

      @frame += 1
      offset = if @frame < IN
                 (HEIGHT + Y) * (IN - @frame) / IN
               elsif @frame < IN + HOLD
                 0
               else
                 (HEIGHT + Y) * (@frame - IN - HOLD) / OUT
               end
      @stack.set_position(X, Y - offset)
      dispose if @frame >= IN + HOLD + OUT
    end

    def show(achievement)
      @viewport = Viewport.create(:main, 50_000)
      @stack = UI::SpriteStack.new(@viewport, X, Y - HEIGHT - Y, default_cache: :interface)
      @stack.add_sprite(0, 0, Succes.file('toast'))
      Succes.draw_icon(@stack.add_sprite(0, 0, UI::SpriteStack::NO_INITIAL_IMAGE), achievement, @stack.x, @stack.y)
      @stack.with_font(20) do
        @stack.add_text(36, 2, 168, 13, Succes.t('Succès obtenu !', 'Achievement unlocked!'), color: 0)
      end
      @stack.add_text(36, 14, 168, 16, Succes.name(achievement), color: 0)
      points = Succes.points(achievement)
      @stack.with_font(20) { @stack.add_text(150, 2, 54, 13, "#{points} pts", 2, color: 0) } if points > 0
      @stack.set_position(X, Y - HEIGHT - Y)
      @frame = 0
      play_sound
    rescue StandardError => e
      log_error("Succès : bandeau (#{e.message})") if respond_to?(:log_error, true)
      dispose
    end

    def play_sound
      me = Succes.config.notify_me.to_s
      Audio.me_play(me) unless me.empty?
    rescue StandardError
      nil
    end

    def dispose
      @stack&.dispose
      @viewport&.dispose
      @stack = @viewport = nil
    end

    # @return [Boolean]
    def showing?
      return !@stack.nil?
    end
  end

  module_function

  # Vérification régulière sur la carte (seulement s'il y a des succès automatiques à débloquer)
  def tick
    @tick = (@tick || 0) + 1
    if @tick >= [config.check_every.to_i, 1].max
      @tick = 0
      check_all if all.any? { |a| condition_type(a) != 'manual' && !unlocked?(fetch(a, :id)) }
    end
    Notification.update
  rescue StandardError => e
    log_error("Succès : #{e.message}") if respond_to?(:log_error, true)
  end
end

class Scene_Map
  module SuccesTick
    def update_graphics
      super
      Succes.tick
    end
  end
  prepend SuccesTick
end

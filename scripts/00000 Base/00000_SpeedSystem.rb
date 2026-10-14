module Graphics
  class FPSBalancer
    class << self
      attr_accessor :globally_enabled
    end

    @globally_enabled = true

    def initialize
      @frame_to_execute = 0
      @last_frame_rate = 0
      @frame_delta = 1
      @last_interval_index = 0
    end

    def update
      update_intervals if @last_frame_rate != Graphics.frame_rate && respond_to?(:update_intervals, true)
      current_index = (Graphics.current_time.usec / @frame_delta).floor
      if current_index == @last_interval_index
        @frame_to_execute = 0
      elsif current_index > @last_interval_index
        @frame_to_execute = current_index - @last_interval_index
      else
        @frame_to_execute = Graphics.frame_rate - @last_interval_index + current_index
      end
      @last_interval_index = current_index
    end
  end
end

module NuriYuri
  class SpeedUpButton
    NORMAL_SPEED = 1
    FAST_SPEED = 4

    attr_reader :factor

    def initialize
      @base_repeat_cool_down = (Input::REPEAT_COOLDOWN || 0.25).to_f
      @base_repeat_space = (Input::REPEAT_SPACE || 0.08).to_f
      @active = false
      @factor = NORMAL_SPEED
      apply_repeat_timing
      apply_to_current_scene
      apply_fps_balancer
    end

    def active?
      @active
    end

    def update
      return unless Input.trigger?(:SPEED_UP)

      @active = !@active
      @factor = @active ? FAST_SPEED : NORMAL_SPEED
      apply_repeat_timing
      apply_to_current_scene
      apply_fps_balancer
    end

    private

    def apply_repeat_timing
      # Redefine repeat timing constants without spamming
      # "already initialized constant" warnings.
      old_verbose = $VERBOSE
      $VERBOSE = nil
      Input.send(:remove_const, :REPEAT_COOLDOWN) if Input.const_defined?(:REPEAT_COOLDOWN, false)
      Input.send(:remove_const, :REPEAT_SPACE) if Input.const_defined?(:REPEAT_SPACE, false)
      Input.const_set(:REPEAT_COOLDOWN, @base_repeat_cool_down * @factor)
      Input.const_set(:REPEAT_SPACE, @base_repeat_space * @factor)
      $VERBOSE = old_verbose
    end

    def apply_to_current_scene
      $scene.clock.speed_factor = @factor if $scene.respond_to?(:clock) && $scene.clock
    end

    def apply_fps_balancer
      # Uncap the frame limiter while sped up, restore it when back to normal.
      Graphics::FPSBalancer.globally_enabled = !@active
    end
  end

  class << self
    attr_accessor :global_speed_up_button
  end
end

module BattleSpeedUpOverride
  def update_speed_up
    factor = NuriYuri.global_speed_up_button&.factor || 1
    @clock.speed_factor = factor if @clock.speed_factor != factor
  end
end

module ClockOverwrite
  def initialize
    super
    @speed_factor = NuriYuri.global_speed_up_button&.factor || 1
  end
end

Scheduler.add_proc(:on_scene_switch, :any, 'Forward speed factor to next scene', 1000) do
  if $scene.respond_to?(:clock) && $scene.clock
    $scene.clock.speed_factor = NuriYuri.global_speed_up_button&.factor || 1
  end
end

Graphics.on_start do
  if defined?(Input::Keys) && defined?(Input::Keyboard)
    s = Input::Keyboard::Scancode
    Input::Keys[:SPEED_UP] = [s::Space, s::Space, s::Space, s::Space, 255]
  end

  NuriYuri.global_speed_up_button = NuriYuri::SpeedUpButton.new
  Scheduler.add_proc(:on_update, :any, 'SpeedUpButton', 10_000) do
    NuriYuri.global_speed_up_button&.update
  end


  Clock.prepend(ClockOverwrite) if defined?(Clock)
  Battle::Scene.prepend(BattleSpeedUpOverride) if defined?(Battle::Scene)
end

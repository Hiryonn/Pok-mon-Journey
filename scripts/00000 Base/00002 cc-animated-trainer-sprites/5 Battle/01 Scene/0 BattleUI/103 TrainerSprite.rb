module BattleUI
  # Module adding the horizontal spritesheet animation of the enemy trainer sprite
  module AnimatedTrainerSprite
    # Number of frames shown per second by the intro animation
    FRAMES_PER_SECOND = 12
    # Minimum width to height ratio required to read a bitmap as a spritesheet
    SPRITESHEET_WIDTH_RATIO = 2
    # Key used to store the intro animation inside the animation handler
    ANIMATION_KEY = :trainer_frames

    class << self
      # Get the number of square frames held by a horizontal spritesheet
      # @param width [Integer] width of the bitmap
      # @param height [Integer] height of the bitmap
      # @return [Integer] 0 when the bitmap must not be read as a spritesheet
      def frame_count(width, height)
        return 0 if height <= 0
        return 0 if width <= height * SPRITESHEET_WIDTH_RATIO

        return (width.to_f / height).ceil
      end
    end

    # Create a new TrainerSprite
    # @param viewport [Viewport]
    # @param scene [Battle::Scene]
    # @param battler [String] name of the battler in graphics/battlers
    # @param bank [Integer] Bank where the Trainer is
    # @param position [Integer] position of the battler in the Array
    # @param battle_info [Battle::Logic::BattleInfo]
    def initialize(viewport, scene, battler, bank, position, battle_info)
      super
      setup_animated_frames
    end

    # Play the intro animation once, then leave the sprite on its last frame
    # @note Does nothing when the sprite holds no spritesheet, and never replays
    def start_intro_frame_animation
      return unless animated_frames?
      return if @intro_frame_animation

      unless animation_handler
        log_error('cc-animated-trainer-sprites: animation handler missing, intro animation skipped')
        return
      end

      duration = @animated_frame_count / FRAMES_PER_SECOND.to_f
      animation = Yuki::Animation.cell_x_change(duration, src_rect, 0, @animated_frame_count - 1, src_rect.width)
      animation_handler[ANIMATION_KEY] = animation
      animation.start
      # Kept after start, done? raises on an animation whose time source is not resolved yet
      @intro_frame_animation = animation
    end

    # Tell if the sprite is still playing its intro animation
    # @return [Boolean]
    def intro_frame_animation_running?
      return false unless @intro_frame_animation

      return !@intro_frame_animation.done?
    end

    private

    # Tell if the sprite holds a horizontal spritesheet
    # @return [Boolean]
    def animated_frames?
      return @animated_frame_count.to_i > 1
    end

    # Cut the bitmap into square frames when the enemy trainer holds a spritesheet
    def setup_animated_frames
      @animated_frame_count = 0
      return if @bank == 0 || bitmap.nil?

      @animated_frame_count = AnimatedTrainerSprite.frame_count(bitmap.width, bitmap.height)
      return unless animated_frames?

      src_rect.width = bitmap.height
      # super computed the origin from the full sheet width, it has to be recomputed on the frame
      reset_position
    end
  end

  class TrainerSprite
    prepend AnimatedTrainerSprite
  end
end

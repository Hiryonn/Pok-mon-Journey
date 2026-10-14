module Battle
  class Scene
    # Module holding the appearing message on screen while the trainer intro animation plays
    module AnimatedTrainerMessage
      # Skip the update of wait input
      # @return [Boolean] if the update of wait input should be skipped
      def update_wait_input_skip
        return true if trainer_intro_animation_running?

        return super
      end

      private

      # Tell if an enemy trainer is still playing its intro animation
      # @return [Boolean]
      def trainer_intro_animation_running?
        return false unless $scene.is_a?(Battle::Scene)

        return $scene.visual.enemy_trainer_sprites.any?(&:intro_frame_animation_running?)
      end
    end

    class Message
      prepend AnimatedTrainerMessage
    end
  end
end

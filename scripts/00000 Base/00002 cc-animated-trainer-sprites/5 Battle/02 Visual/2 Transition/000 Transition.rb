module Battle
  class Visual
    module Transition
      # Module starting the enemy trainer intro animation when the appearing message shows up
      module AnimatedTrainerBase
        private

        # Function that shows the message about Wild appearing / Trainer wanting to fight
        def show_appearing_message
          @visual.enemy_trainer_sprites.each(&:start_intro_frame_animation)
          super
        end
      end

      class Base
        prepend AnimatedTrainerBase
      end
    end
  end
end

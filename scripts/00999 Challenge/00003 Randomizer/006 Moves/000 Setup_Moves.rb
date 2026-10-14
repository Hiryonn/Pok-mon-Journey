module PFM
  # The class responsible of managing the randomizer plugin
  class Randomizer
    # The class responsible of telling the state of the random moves mode
    class Moves
      # Get the game state responsive of the whole game state
      # @return [PFM::GameState]
      attr_accessor :game_state

      # Set the state of the system
      # @param [Boolean]
      attr_writer :enabled

      # Create a new Moves object
      # @param game_state [PFM::GameState] game state storing this instance
      def initialize(_game_state = PFM.game_state)
        @enabled = false
      end

      # If the system is activated
      # @return [Boolean]
      def enabled?
        @enabled
      end

      # Enable the Random mode
      def enable
        @enabled = true
      end

      # Disable the Random mode
      def disable
        @enabled = false
      end
    end
  end
end

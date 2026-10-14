module PFM
  # The class responsible of managing the randomizer plugin
  class Randomizer
    # The class responsible of telling the state of the random evolutions mode
    class Evolutions
      # Get the game state responsive of the whole game state
      # @return [PFM::GameState]
      attr_accessor :game_state

      # Set the state of the system
      # @param [Boolean]
      attr_writer :enabled

      # Set the db_symbol of the dex that will be sampled
      # @param [Symbol]
      attr_accessor :pokedex_symbol

      # Set the randomizer mode
      # @param [Symbol]
      attr_accessor :mode

      # Get the current seed
      # @param [Integer]
      attr_reader :seed

      # Create a new Evolutions object
      # @param game_state [PFM::GameState] game state storing this instance
      def initialize(_game_state = PFM.game_state)
        @enabled = false
        @pokedex_symbol = :national
        @mode = :shuffle
      end

      # If the system is activated
      # @return [Boolean]
      def enabled?
        @enabled
      end

      # Enable the Random mode
      def enable
        @mode ||= :shuffle
        @enabled = true
      end

      # Disable the Random mode
      def disable
        @enabled = false
      end

      # Switch between modes
      def switch
        @mode = @mode == :random ? :shuffle : :random
        log_info("The random evolutions mode has been switched to #{@mode}.")
        return
      end
    end
  end
end

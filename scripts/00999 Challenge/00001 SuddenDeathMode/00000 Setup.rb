module PFM
  # The class responsible of telling the state of the system and eventual parameters
  class SuddenDeath
    # Get the game state responsive of the whole game state
    # @return [PFM::GameState]
    attr_accessor :game_state

    # Set the state of the system
    # @param [Boolean]
    attr_writer :enabled

    # Create a new SuddenDeath object
    # @param game_state [PFM::GameState] game state storing this instance
    def initialize(game_state = PFM.game_state)
      @enabled = false
    end

    # If the system is activated
    # @return [Boolean]
    def enabled?
      return @enabled
    end

    # Enable the Sudden Death mode
    def enable
      @enabled = true
    end

    # Disable the Sudden Death mode
    def disable
      @enabled = false
    end
  end

  class << self
    # Get the class handling the Random mode in the game
    # @return [Class<Pokedex>]
    attr_accessor :sudden_death_class
  end

  class GameState
    # The Random Mode
    # @return [PFM::RandomWild]
    attr_accessor :sudden_death

    on_player_initialize(:sudden_death) { @sudden_death = PFM.sudden_death_class.new(self) }
    on_expand_global_variables(:sudden_death) do
      @sudden_death ||= PFM.sudden_death_class.new(self)
      # Variable containing the Random Mode Information
      $sudden_death = @sudden_death
      @sudden_death.game_state = self
    end
  end
end

PFM.sudden_death_class = PFM::SuddenDeath

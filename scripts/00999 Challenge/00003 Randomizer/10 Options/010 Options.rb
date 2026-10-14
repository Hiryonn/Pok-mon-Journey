module PFM
  class << self
    # Get the class handling the option in the game
    # @return [Class<Options>]
    attr_accessor :randomizer_options_class
  end

  # The options data
  #
  # The options are stored in $options and PFM.game_state.options
  # @author Nuri Yuri
  class RandomizerOptions
    # Get the game state responsive of the whole game state
    # @return [PFM::GameState]
    attr_accessor :game_state

    RANDOMIZER_MODULES = %i[wild_pokemon trainers_pokemon given_pokemon evolutions abilities].freeze

    # Create a new Option object with a language
    # @param starting_language [String] the lang id the game will start
    # @param game_state [PFM::GameState] variable responsive of containing the whole game state for easier access
    def initialize(starting_language, game_state = PFM.game_state)
      @game_state = game_state
    end

    RANDOMIZER_MODULES.each do |name|
      # Return current value for the randomizer option.
      # @return [Integer] 1 = disabled, 2 = random, 3 = shuffle
      define_method(name) do
        randomizer_option_value(name)
      end

      # Set the value for the randomizer option.
      # @param value [Integer] 1 = disabled, 2 = random, 3 = shuffle
      define_method("#{name}=") do |value|
        set_randomizer_option(name, value)
      end
    end

    # Return whether move randomization is enabled.
    # @return [Boolean]
    def moves
      $randomizer.moves.enabled?
    end

    # Enable or disable move randomization.
    # @param value [Boolean] true to enable, false to disable
    def moves=(value)
      value ? $randomizer.moves.enable : $randomizer.moves.disable
    end

    # Return the balance value for the randomizer.
    # @return [Integer] -1 = disabled, 0-100 = BST differential
    def balance
      $randomizer.balance
    end

    # Set the balance value for the randomizer.
    # @param [Integer] -1 = disabled, 0-100 = BST differential
    def balance=(value)
      $randomizer.balance = value
    end

    # Return the state of the mega persistence
    # @return [Boolean]
    def mega_persistence
      $randomizer.trainers_pokemon.mega_persistence
    end

    # Set the state of the mega persistence
    # @param [Boolean]
    def mega_persistence=(value)
      $randomizer.trainers_pokemon.mega_persistence = value
    end

    private

    # Apply a randomizer module setting to the underlying $randomizer object.
    # @param name [Symbol] randomizer module name
    # @param value [Integer] 1 = disabled, 2 = random, 3 = shuffle
    def set_randomizer_option(name, value)
      randomizer_module = $randomizer.send(name)
      if value == 1
        randomizer_module.disable
      else
        randomizer_module.enable
        randomizer_module.mode = (value == 2 ? :random : :shuffle)
      end
    end

    # Return the current option value for a randomizer module.
    # @param name [Symbol] randomizer module name
    # @return [Integer] 1 = disabled, 2 = random, 3 = shuffle
    def randomizer_option_value(name)
      randomizer_module = $randomizer.send(name)
      return 1 unless randomizer_module.enabled?
      randomizer_module.mode == :random ? 2 : 3
    end
  end

  class GameState
    # The randomizer options
    # @return [PFM::RandomizerOptions]
    attr_accessor :randomizer_options

    on_player_initialize(:randomizer_options) { @randomizer_options = PFM.randomizer_options_class.new(@starting_language, self) }
    on_expand_global_variables(:randomizer_options) do
      @randomizer_options ||= PFM.randomizer_options_class.new(@starting_language, self)
      # Variable containing all the game options
      $randomizer_options = @randomizer_options
      @randomizer_options.game_state = self
    end
  end
end

PFM.randomizer_options_class = PFM::RandomizerOptions

module PFM
  # The class responsible of managing the randomizer plugin
  class Randomizer
    # The class responsible of telling the state of the random abilities mode
    class Abilities
      require 'set'

      # Set the state of the system
      # @param [Boolean]
      attr_writer :enabled

      # Set the randomizer mode
      # @param [Symbol]
      attr_accessor :mode

      # Get the current seed
      # @param [Integer]
      attr_reader :seed

      # List of available abilities for the randomizer to use
      # @param [Array<PFM::Ability>]
      attr_reader :ability_pool

      ABILITIES_BANLIST = Set[:__undef__, :disguise]

      # Create a new RandomWild object
      # @param game_state [PFM::GameState] game state storing this instance
      def initialize(_game_state = PFM.game_state)
        @enabled = false
        @mode = :shuffle
        @ability_pool = __game_data[:abilities__id].reject { |ability| ABILITIES_BANLIST.include?(ability.db_symbol) }
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
        update_every_ability
      end

      # Disable the Random mode
      def disable
        @enabled = false
        update_every_ability
      end

      # Switch between modes
      def switch
        @mode = @mode == :random ? :shuffle : :random
        log_info("The random abilities mode has been switched to #{@mode}.")
        nil
      end

      # Get the list of available abilities for the randomizer to use
      # @return [Array<PFM::Ability>]
      def ability_pool
        @ability_pool ||= __game_data[:abilities__id].reject { |ability| ABILITIES_BANLIST.include?(ability.db_symbol) }
      end

      # Triggers `update_ability` for every Pokémon
      def update_every_ability
        log_info('Updating every ability')
        block = proc { |pokemon| pokemon&.update_ability }
        $actors.each(&block)
        $storage.each_pokemon(&block)
        $wild_battle.each_roaming_pokemon(&block)
      end
    end
  end
end

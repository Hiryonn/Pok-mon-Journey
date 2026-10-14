module PFM
  # The class responsible of telling the state of the system and eventual parameters
  class Randomizer
    # Get the game state responsive of the whole game state
    # @return [PFM::GameState]
    attr_accessor :game_state
    # Get the state of the wild pokemon module
    # @return [PFM::Randomizer::WildPokemon]
    attr_accessor :wild_pokemon
    # Get the state of the abilities module
    # @return [PFM::Randomizer::Abilities]
    attr_accessor :abilities
    # Get the state of the trainer's pokemon module
    # @return [PFM::Randomizer::TrainersPokemon]
    attr_accessor :trainers_pokemon
    # Get the state of the evolutions module
    # @return [PFM::Randomizer::Evolutions]
    attr_accessor :evolutions
    # Get the state of the moves module
    # @return [PFM::Randomizer::Moves]
    attr_accessor :moves
    # Get the state of the given pokemon module
    # @return [PFM::Randomizer::Moves]
    attr_accessor :given_pokemon
    # Set the db_symbol of the dex that will be sampled
    # @param [Symbol]
    attr_accessor :pokedex_symbol
    # Get the current seed
    # @return [Integer]
    attr_accessor :seed
    # Get the state of the balance mode
    # @return [Boolean]
    attr_accessor :balance

    # Create a new RandomWild object
    # @param game_state [PFM::GameState] game state storing this instance
    def initialize(game_state = PFM.game_state, seed = Random.new_seed)
      @game_state = game_state
      @pokedex_symbol = :national
      @seed = seed
      @balance = -1
    end

    ALL_RANDOMIZER = %i[wild_pokemon given_pokemon trainers_pokemon evolutions abilities moves]

    def each
      return to_enum(__method__) unless block_given?

      ALL_RANDOMIZER.each { |key| yield(send(key)) }
    end

    def each_with_key
      return to_enum(__method__) unless block_given?

      ALL_RANDOMIZER.each { |key| yield(send(key), key) }
    end

    # Enables all random modes
    def enable_all
      each(&:enable)
    end

    # Disables all random modes
    def disable_all
      each(&:disable)
    end

    # Shows if any of the randomizer modes is enabled.
    def enabled?
      return ALL_RANDOMIZER.any? { |mode| send(mode).enabled? }
    end

    # Method showing the states of the modules
    def list
      each_with_key do |randomizer, key|
        randomizer.enabled? ? log_info("#{key}: #{randomizer.enabled?}") : log_error("#{key}: #{randomizer.enabled?}")
      end
    end

    # Get the current seed, if none exists, create a new one
    # @return [Integer]
    def seed
      @seed ||= Random.new_seed
      return @seed
    end

    # Get a random pokemon
    # @param context [Object] the context of the randomization, used to determine which randomizer to check
    # @param creature [PFM::Pokemon] the pokemon to be replaced
    # @param force_shiny [Boolean] if the pokemon should be forced shiny
    # @param no_shiny [Boolean] if the pokemon should not be shiny
    def randomize_pokemon(context, creature, force_shiny = false, no_shiny = false)
      return creature unless enabled?
      return creature if creature.randomizer_properties&.include?(:species)

      candidates = find_adequate_candidates(creature)
      case context.mode
      when :random
        new_species_symbol, new_species_form = candidates.sample
      when :shuffle
        rng = Random.new(PFM.game_state.randomizer.seed ^ creature.id ^ (creature.form << 16))
        new_species_symbol, new_species_form = candidates.sample(random: rng)
      end

      new_pokemon = PFM::Pokemon.new(new_species_symbol, creature.level, force_shiny, no_shiny, new_species_form)
      new_pokemon.randomizer_properties[:species] ||= nil
      return new_pokemon
    end

    # Find all species and forms that have a base stat total within 10% of the original creature's base stat total
    # @param creature [PFM::Pokemon] the creature to be replaced
    # @return [Array<Symbol, Integer>] the db_symbol and form of the new species
    def find_adequate_candidates(creature)
      return data_dex(@pokedex_symbol).creatures.flat_map do |dex_creature|
        data_creature(dex_creature.db_symbol).forms.reject { |form| form.form >= 30 }.map do |form|
          [dex_creature.db_symbol, form.form]
        end
      end if balance == -1

      # Get the base stat total of the original creature
      original_bst = data_creature_form(creature.db_symbol, creature.form).bst
      minimum_bst = original_bst - balance
      maximum_bst = original_bst + balance

      # Find a species and form in the BST range
      candidates = data_dex(@pokedex_symbol).creatures.flat_map do |dex_creature|
        data_creature(dex_creature.db_symbol).forms.reject { |form| form.form >= 30 }.filter_map do |form|
          bst = data_creature_form(dex_creature.db_symbol, form.form).bst
          [dex_creature.db_symbol, form.form] if bst.between?(minimum_bst, maximum_bst)
        end
      end

      return candidates
    end

    # Set the state of the balance mode
    # @param [Integer]
    def balance=(value)
      @balance = value
    end

    # Open the options scene
    def open_options
      $scene.call_scene(GamePlay::RandomizerOptions)
    end

    # Proc a block on all the pokemon in the game (actors, storage, roaming and hall of fame)
    # @param block [Proc] the block to proc on each pokemon
    def affect_all_pokemon(&block)
      $actors.each(&block)
      $storage.each_pokemon(&block)
      $wild_battle.each_roaming_pokemon(&block)

      PFM.game_state.hall_of_fame.player_victory.each do |victory|
        victory[:team].each(&block)
      end
    end
  end

  class << self
    # Get the class handling the Random mode in the game
    # @return [Class<Randomizer>]
    attr_accessor :randomizer_class
  end

  class GameState
    # The Random Mode
    # @return [PFM::RandomWild]
    attr_accessor :randomizer

    on_player_initialize(:randomizer) { @randomizer = PFM.randomizer_class.new(self) }
    on_expand_global_variables(:randomizer) do
      @randomizer ||= PFM.randomizer_class.new(self)
      @randomizer.wild_pokemon ||= PFM::Randomizer::WildPokemon.new
      @randomizer.abilities ||= PFM::Randomizer::Abilities.new
      @randomizer.trainers_pokemon ||= PFM::Randomizer::TrainersPokemon.new
      @randomizer.evolutions ||= PFM::Randomizer::Evolutions.new
      @randomizer.moves ||= PFM::Randomizer::Moves.new
      @randomizer.given_pokemon ||= PFM::Randomizer::GivenPokemon.new
      # Variable containing the Random Mode Information
      $randomizer = @randomizer
      @randomizer.game_state = self
    end
  end
end

PFM.randomizer_class = PFM::Randomizer

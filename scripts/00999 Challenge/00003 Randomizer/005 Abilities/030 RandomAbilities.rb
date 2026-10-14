module PFM
  class Pokemon
    module RandomAbilities
      # Update the Pokemon Ability
      def update_ability
        assign_ability_index
        @ability = get_data.abilities[@ability_index.to_i] if @ability_index
        # Randomize the ability if randomizer is enabled
        @ability = randomize_ability(data_ability(@ability).id) if game_state.randomizer.abilities.enabled?
      end

      # Assign ability index to the corresponding ability if possible
      def assign_ability_index
        return if @ability_index

        if get_data.abilities.include?(ability_db_symbol)
          @ability_index = get_data.abilities.index(ability_db_symbol)
        else
          pokemon_data = { pokemon: db_symbol, form: form, ability: ability }
          if randomizer_properties &&
            randomizer_properties[:ability].is_a?(Array) &&
            (already_randomized = randomizer_properties[:ability].find { |h| h.slice(:pokemon, :form, :ability) == pokemon_data })
            @ability_index = already_randomized[:ability_index]
          end
        end
      end

      # Mega evolve the Pokemon (if possible)
      def mega_evolve
        mega_evolution = can_mega_evolve?
        return unless mega_evolution

        @mega_evolved = @form
        @form = mega_evolution
        # Get the normal ability
        @ability = data_ability(data.abilities.sample).id
        assign_ability_index
        # Replace it with the corresponding
        @ability = randomize_ability(@ability) if game_state.randomizer.abilities.enabled?
        self.ability = nil if self.is_a?(PFM::PokemonBattler)
      end

      # Randomize the ability of the Pokemon
      # @param base_ability_id [Integer] id of the base ability of the Pokemon
      # @return [Integer] id of the new ability
      def randomize_ability(base_ability_id)
        rand = PFM.game_state.randomizer.abilities
        pokemon_data = { pokemon: db_symbol, form: form, ability_index: @ability_index }
        if randomizer_properties &&
           randomizer_properties[:ability].is_a?(Array) &&
           (already_randomized = randomizer_properties[:ability].find { |h| h.slice(:pokemon, :form, :ability_index) == pokemon_data })
          return already_randomized[:ability]
        end

        case rand.mode
        when :random
          # Randomly select an ability from the available abilities
          new_ability = rand.ability_pool.sample.db_symbol
        when :shuffle
          family_id = data_creature(PFM::Randomizer::Family.root(db_symbol)).id
          rng = Random.new(PFM.game_state.randomizer.seed ^ family_id ^ base_ability_id)
          new_ability = rand.ability_pool.sample(random: rng).db_symbol
        end

        ability_hash = pokemon_data.merge(ability: new_ability)
        randomizer_properties[:ability] ||= []
        randomizer_properties[:ability] << ability_hash
        # Get rid of entries with a different db_symbol
        randomizer_properties[:ability].delete_if { |h| h[:pokemon] != db_symbol }
        return new_ability
      end

      # Method that initialize the ability
      # @param opts [Hash] Hash describing optional value you want to assign to the Pokemon
      def ability_initialize(opts)
        ability = data.abilities
        if opts[:ability]
          @ability = opts[:ability]
          assign_ability_index
        else
          ability_chance = rand(100)
          @ability = ability[@ability_index = ABILITY_CHANCES.find_index { |value| value > ability_chance }]
        end
        @ability = randomize_ability(data_ability(@ability).id) if game_state.randomizer.abilities.enabled?
        @ability = data_ability(@ability).id unless @ability.is_a?(Integer)
        @ability_used = false
        self.hp = self.hp # Wonder Guard 1 hp refresh
      end
    end
  end
end

PFM::Pokemon.prepend(PFM::Pokemon::RandomAbilities)

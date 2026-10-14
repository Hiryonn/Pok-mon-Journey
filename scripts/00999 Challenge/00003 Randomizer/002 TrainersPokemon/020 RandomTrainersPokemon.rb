module Battle
  class Logic
    class BattleInfo
      module RandomTrainers
        # Add a trainer to the battle_info object
        # @param battle_info [BattleInfo]
        # @param bank [Integer] bank of the trainer
        # @param id_trainer [Integer] ID of the trainer in the database
        def add_trainer(battle_info, bank, id_trainer)
          trainer = data_trainer(id_trainer)
          klass = trainer.class_name
          battler = trainer.resources
          name = trainer.name
          party = trainer.party.map(&:to_creature)

          ### Ajout Randomizer
          rand = PFM.game_state.randomizer.trainers_pokemon
          party = randomize_trainer_party(party) if rand.enabled?
          ### Fin Ajout Randomizer

          bag = PFM::Bag.new
          victory_text = trainer.victory_text.empty? ? nil : trainer.victory_text
          defeat_text = trainer.victory_text.empty? ? nil : trainer.defeat_text
          trainer.bag_entries.each { |bag_entry| bag.add_item(bag_entry[:dbSymbol], bag_entry[:amount]) }
          battle_info.add_party(bank, party, name, klass, battler, bag, nil, trainer.ai, victory_text, defeat_text)
          # We add the base money only for the enemy side (prevents the ally to have a base money)
          battle_info.base_moneys[bank] << trainer.base_money if bank == 1
          battle_info.trainer_is_couple = battle_info.parties[1].size == 1 if bank == 1 && trainer.vs_type == 2
          battle_info.battle_id = trainer.battle_id if trainer.battle_id != 0
          change_battle_bgms(battle_info, trainer)
        end

        private

        # Randomize the trainer party
        # @param party [Array<PFM::Pokemon>] the party of the trainer
        # @return [Array<PFM::Pokemon>] the randomized party
        def randomize_trainer_party(party)
          rand = PFM.game_state.randomizer.trainers_pokemon

          return party.map do |party_member|
            # On ne randomise pas les acteurs joueurs
            next party_member if party_member.nil?

            is_mega = check_mega_evolution(party_member)

            if is_mega && rand.mega_persistence
              next randomize_pokemon_mega(party_member, party_member.shiny?)
            end

            next PFM.game_state.randomizer.randomize_pokemon(rand, party_member, party_member.shiny?)
          end
        end

        # Check if a pokemon has a mega evolution
        # @param existing_pokemon [PFM::Pokemon] the pokemon to check
        # @return [Boolean] true if the pokemon has a mega evolution, false otherwise
        def check_mega_evolution(existing_pokemon)
          return true if existing_pokemon.db_symbol == :rayquaza && existing_pokemon.skills_set.any? { |skill| skill.db_symbol == :dragon_ascent }

          existing_pokemon&.data.evolutions.find do |evolution|
            evolution.condition_data(:gemme) == existing_pokemon.item_db_symbol
          end
        end

        # Get a random pokemon that has a mega evolution
        # @param creature [PFM::Pokemon] the pokemon to be replaced
        # @param force_shiny [Boolean] if the pokemon should be forced shiny
        # @param no_shiny [Boolean] if the pokemon should not be shiny
        def randomize_pokemon_mega(creature, force_shiny = false)
          rand = PFM.game_state.randomizer.trainers_pokemon
          return creature unless rand.enabled?
          return creature if creature.randomizer_properties&.include?(:species)

          @rng = Random.new(PFM.game_state.randomizer.seed ^ creature.id ^ (creature.form << 16))

          candidates = $randomizer.find_adequate_candidates(creature).select do |species, form|
            next true if species == :rayquaza

            data_creature_form(species, form).evolutions.any? { |evolution| evolution.conditions.any? { |condition| condition[:type] == :gemme } }
          end

          # No mega available
          return $randomizer.randomize_pokemon(rand, creature, force_shiny) if candidates.empty?

          @has_mega = false
          # puts candidates.map { |species, form| "#{species} (#{form})" }.join(', ')
          new_species_symbol, new_species_form = rand.mode == :shuffle ? candidates.sample(random: @rng) : candidates.sample

          # Handle mega evolution keys (items or moves)
          item = mega_item(new_species_symbol, new_species_form)
          moves = new_species_symbol == :rayquaza ? [:dragon_ascent, 0, 0, 0] : nil

          new_pokemon = PFM::Pokemon.new(new_species_symbol, creature.level, force_shiny, false, new_species_form, {item: item, moves: moves})
          new_pokemon.randomizer_properties[:species] ||= nil
          return new_pokemon
        end

        # Get the mega stone for a species and form
        # @param species [Symbol] the species of the pokemon
        # @param form [Integer] the form of the pokemon
        # @return [Symbol, nil] the mega stone of the pokemon or nil if it doesn't need one
        def mega_item(species, form)
          return nil if species == :rayquaza

          data_creature_form(species, form).evolutions.select do |evolution|
            evolution.conditions.any? { |condition| condition[:type] == :gemme }
          end.sample(random: @rng).condition_data(:gemme)
        end
      end

      class << self
        prepend RandomTrainers
      end
    end
  end
end

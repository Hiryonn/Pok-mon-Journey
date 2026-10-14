module PFM
  class Wild_Battle
    module RandomPokemon
      module_function
      # Select the creatures that will be in the battle
      # @param group [Studio::Group] the descriptor of the Wild group
      # @param creature_to_select [Array<Array(PFM::Pokemon, Float)>] list of Pokemon to select with their rates
      # @return [Array<PFM::Pokemon>]
      def select_creature(group, creature_to_select)
        return [] unless group && !group.encounters.empty?
        return [] if creature_to_select.empty?

        main_creature = $actors[0]

        real_rareness = creature_to_select.map.with_index do |(creature, rate), index|
          encounter = group.encounters[index % group.encounters.size]
          next [creature, 0] if repel_active? && !fishing_battle? && creature.level < main_creature.level

          next [creature, rate * encounter.encounter_rate]
        end

        # This reducer prevents to select the exact same Creature twice
        reduced_rareness = real_rareness.reduce([]) { |acc, curr| acc << (curr.last + (acc.last || 0)) }
        max_rand = reduced_rareness.last
        return [] if max_rand.zero?

        is_double_battle = group.is_double_battle || $game_variables[Yuki::Var::Allied_Trainer_ID] > 0
        return (is_double_battle ? 2 : 1).times.reduce([]) do |acc, _|
          nb = Random::WILD_BATTLE.rand(max_rand.to_i)
          index = reduced_rareness.find_index { |i| i > nb } || real_rareness.size - 1
          creature = real_rareness[index].first

          # Randomizer addition
          rand = PFM.game_state.randomizer
          creature = rand.randomize_pokemon(rand.wild_pokemon, creature) if rand.wild_pokemon.enabled?

          redo if acc.include?(creature)
          acc << creature
        end
      end
    end
  end
end

PFM::Wild_Battle.prepend(PFM::Wild_Battle::RandomPokemon)

class Interpreter
  module CallWild
    # Start a wild battle
    # @note: cf super for full ruby doc
    def call_battle_wild(id, level, *args)
      rand_base = PFM.game_state.randomizer
      rand = rand_base.wild_pokemon
      return super unless rand.enabled?

      id = PFM::Pokemon.new(id, level, args[0] == true, args[1] == true) if id.is_a?(Symbol) || id.is_a?(Integer)
      id = rand_base.randomize_pokemon(rand, id)

      if args[0].is_a?(Symbol) || args[0].is_a?(Integer)
        args[0] = rand_base.randomize_pokemon(rand, PFM::Pokemon.new(args[0], args[1]))
        args.pop
      elsif args[0].instance_of?(::PFM::Pokemon)
        args[0] = rand_base.randomize_pokemon(rand, args[0])
      else
        args = []
      end

      return super(id, level, *args)
    end
    alias demarrer_combat call_battle_wild
  end
end

Interpreter.prepend(Interpreter::CallWild)

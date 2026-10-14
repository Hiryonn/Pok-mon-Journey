module GamePlay
  class Evolve
    module RandomEvolutions
      # Launch the Pokemon Evolution scene
      # @param pokemon [PFM::Pokemon] the evolving Pokemon
      # @param id [Integer] the ID of the evolution
      # @param form [Integer] the form of the evolution
      # @param forced [Boolean] if the evolution can be stopped or not
      def initialize(pokemon, id, form = nil, forced = false)
        rand = PFM.game_state.randomizer.evolutions
        if rand.enabled?
          new_pkmn = PFM.game_state.randomizer.randomize_pokemon(rand, PFM::Pokemon.new(id, pokemon.level))
          id = new_pkmn.id
          form = new_pkmn.form
        end

        super(pokemon, id, form, forced)
      end
    end
  end
end

GamePlay::Evolve.prepend(GamePlay::Evolve::RandomEvolutions)

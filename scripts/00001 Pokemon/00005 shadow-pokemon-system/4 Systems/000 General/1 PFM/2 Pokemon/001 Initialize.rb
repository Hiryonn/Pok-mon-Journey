module PFM
  class Pokemon
    module PokemonShadowPatch
      # Create a new Pokemon with specific parameters
      # @param id [Integer, Symbol] ID of the Pokemon in the database
      # @param level [Integer] level of the Pokemon
      # @param force_shiny [Boolean] if the Pokemon have 100% chance to be shiny
      # @param no_shiny [Boolean] if the Pokemon have 0% chance to be shiny (override force_shiny)
      # @param form [Integer] Form index of the Pokemon (-1 = automatic generation)
      # @param opts [Hash] Hash describing optional value you want to assign to the Pokemon
      # @option opts [Boolean] :shadow makes the Pokemon a Shadow Pokemon
      # @option opts [Integer] :heart_gauge forces the max value of the Shadow Heart Gauge
      # @option opts [Integer] :shadow_temper forces the Shadow Temper (Heart Gauge decrease speed)
      # @option opts [Array<Symbol>] :shadow_moves list of Shadow moves given to the Pokemon
      def initialize(id, level, force_shiny = false, no_shiny = false, form = -1, opts = {})
        super
        return unless opts[:shadow]

        max = ShadowGauge.for(db_symbol, self.form, opts[:heart_gauge])
        temper = ShadowTemper.for(db_symbol, max, opts[:shadow_temper])
        @shadow_state = ShadowState.new(ShadowHeart.new(max, nature_db_symbol, temper))
        @shadow_state.store_moves(skills_set.map(&:db_symbol))
        @shadow_state.store_shadow_moves(opts[:shadow_moves] || DEFAULT_SHADOW_MOVES)
        self.skills_set = @shadow_state.shadow_moves.map { |db_symbol| PFM::Skill.new(db_symbol) }
      end
    end

    prepend PokemonShadowPatch
  end
end

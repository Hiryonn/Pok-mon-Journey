module PFM
  # Full gauge a Shadow Pokemon starts its life with, resolved in three layers: the value the
  # encounter hands over, then the one its species is registered with, then a formula read from the
  # creature data. It lives here rather than on ShadowHeart because it reads the database, which the
  # heart itself never does.
  module ShadowGauge
    # Gauge the most open creature of the game gets, the floor of the roster of Pokemon XD.
    # @return [Integer]
    MIN = 1500
    # Gauge the most closed creature of the game gets, the value Shadow Lugia holds in Pokemon XD.
    # @return [Integer]
    MAX = 12_000
    # Weight of each trait in the composite. The two traits that speak of bonding lead, raw power
    # only tells apart creatures the first two put side by side.
    # @return [Hash{ Symbol => Float }]
    WEIGHTS = { catch_rate: 0.40, hatch_steps: 0.35, base_stats: 0.25 }
    # Score given to a creature the database cannot describe, the middle of the range.
    # @return [Float]
    UNKNOWN_SCORE = 0.5
    # Step the gauge is rounded to, a value read by the player being a round one.
    # @return [Integer]
    ROUNDING = 100

    class << self
      # Gauges registered per species, which a game fills to give its own pace.
      # @return [Hash{ Symbol => Integer }]
      def registry
        @registry ||= {}
        return @registry
      end

      # Register the gauge a species gets, which the formula then never has a say on.
      # @param species [Symbol] db_symbol of the species
      # @param value [Integer]
      def register(species, value)
        registry[species] = value
      end

      # Gauge a creature starts with.
      # @param species [Symbol] db_symbol of the species
      # @param form [Integer] form of the creature
      # @param explicit [Integer, nil] value the encounter gives, which wins over everything
      # @return [Integer]
      def for(species, form, explicit = nil)
        return explicit if explicit
        return registry[species] if registry.key?(species)

        return from_data(species, form)
      end

      # Forget the ranges read from the database, so a game that edits its creatures at runtime can
      # have them read again.
      def reset_ranges
        @ranges = nil
      end

      private

      # Gauge the creature data alone gives.
      # @param species [Symbol] db_symbol of the species
      # @param form [Integer] form of the creature
      # @return [Integer]
      def from_data(species, form)
        gauge = MIN + (MAX - MIN) * score_of(data_creature_form(species, form))

        return (gauge / ROUNDING.to_f).round * ROUNDING
      end

      # How closed a creature is, from the most open of the game to the most closed. A creature that
      # lets itself be caught and hatches early is one that opens up, whatever its power.
      # @param creature [Studio::CreatureForm]
      # @return [Float] from 0.0 to 1.0
      def score_of(creature)
        return UNKNOWN_SCORE unless describable?(creature)

        return normalize(composite_of(creature), *ranges[:composite])
      end

      # Weighted stand of a creature among its peers, before the composite is stretched over the
      # whole roster.
      # @param creature [Studio::CreatureForm]
      # @return [Float]
      def composite_of(creature)
        wariness = 1.0 - normalize(Math.log(creature.catch_rate), *ranges[:catch_rate])
        devotion = normalize(Math.log(creature.hatch_steps), *ranges[:hatch_steps])
        power = normalize(base_stats_of(creature), *ranges[:base_stats])

        return WEIGHTS[:catch_rate] * wariness + WEIGHTS[:hatch_steps] * devotion + WEIGHTS[:base_stats] * power
      end

      # Lowest and highest value each trait takes over the roster of the game, and the range the
      # composite itself spans, so the two ends of the gauge are always reached by someone. Read
      # once, a game seldom growing its roster while it runs.
      # @return [Hash{ Symbol => Array<Float> }]
      def ranges
        return @ranges if @ranges

        creatures = describable_creatures
        @ranges = {
          catch_rate: creatures.map { |creature| Math.log(creature.catch_rate) }.minmax,
          hatch_steps: creatures.map { |creature| Math.log(creature.hatch_steps) }.minmax,
          base_stats: creatures.map { |creature| base_stats_of(creature) }.minmax
        }
        @ranges[:composite] = creatures.map { |creature| composite_of(creature) }.minmax

        return @ranges
      end

      # Base form of every creature the formula can read, the one a Shadow Pokemon is met under.
      # @return [Array<Studio::CreatureForm>]
      def describable_creatures
        creatures = []
        each_data_creature do |creature|
          next if creature.db_symbol == :__undef__

          form = creature.forms.first
          creatures << form if describable?(form)
        end

        return creatures
      end

      # Whether the data of a creature carries the three traits the formula reads.
      # @param creature [Studio::CreatureForm, nil]
      # @return [Boolean]
      def describable?(creature)
        return false unless creature

        return creature.catch_rate.to_i > 0 && creature.hatch_steps.to_i > 0
      end

      # @param creature [Studio::CreatureForm]
      # @return [Integer]
      def base_stats_of(creature)
        return creature.base_hp + creature.base_atk + creature.base_dfe +
               creature.base_spd + creature.base_ats + creature.base_dfs
      end

      # Where a value stands between two bounds, the middle when they meet. Base stats come in as
      # integers, hence the conversion, an integer division would answer 0 for every creature but
      # the highest of the roster.
      # @param value [Numeric]
      # @param low [Numeric]
      # @param high [Numeric]
      # @return [Float] from 0.0 to 1.0
      def normalize(value, low, high)
        return UNKNOWN_SCORE if high <= low

        return ((value - low).to_f / (high - low)).clamp(0.0, 1.0)
      end
    end
  end
end

module PFM
  # How easily a Shadow Pokemon loses its temper, resolved in three layers like its gauge: the tier
  # the encounter hands over, then the one its species is registered with, then a formula read from
  # the gauge. A tier is a whole curve rather than a mere ceiling, the published ones differing by
  # their shape as much as by where they stop.
  module ShadowTemper
    # Odds of losing control for every bar the heart has opened, one row per tier, from the calmest
    # species of Pokemon XD to the most volatile. The published table is indexed up to the fourth
    # bar, so the last two columns hold the same value.
    # @return [Array<Array<Float>>]
    CURVES = [
      [0.0, 0.02, 0.05, 0.10, 0.15, 0.15],
      [0.0, 0.05, 0.10, 0.15, 0.20, 0.20],
      [0.0, 0.10, 0.15, 0.20, 0.30, 0.30],
      [0.0, 0.10, 0.15, 0.25, 0.40, 0.40],
      [0.0, 0.10, 0.20, 0.35, 0.50, 0.50]
    ]

    class << self
      # Tiers registered per species, which a game fills to give its own pace.
      # @return [Hash{ Symbol => Numeric }]
      def registry
        @registry ||= {}
        return @registry
      end

      # Register the tier a species gets, which the formula then never has a say on.
      # @param species [Symbol] db_symbol of the species
      # @param tier [Numeric] row of CURVES, a fraction landing between two of them
      def register(species, tier)
        registry[species] = tier
      end

      # Tier a creature starts with.
      # @param species [Symbol] db_symbol of the species
      # @param gauge [Integer] full gauge the creature was given
      # @param explicit [Numeric, nil] tier the encounter gives, which wins over everything
      # @return [Float]
      def for(species, gauge, explicit = nil)
        tier = explicit || registry[species] || from_gauge(gauge)

        return tier.to_f.clamp(0.0, (CURVES.size - 1).to_f)
      end

      # Tier the gauge alone gives. A species that takes a long road to purification is read as one
      # that breaks down more often, which is what shortens that road again.
      # @param gauge [Integer]
      # @return [Float]
      def from_gauge(gauge)
        span = ShadowGauge::MAX - ShadowGauge::MIN
        position = ((gauge - ShadowGauge::MIN).to_f / span).clamp(0.0, 1.0)

        return position * (CURVES.size - 1)
      end

      # Odds of losing control, a tier falling between two curves blending them.
      # @param tier [Float]
      # @param bars [Integer] number of bars the heart has opened
      # @return [Float]
      def chance(tier, bars)
        low = CURVES[tier.floor][bars]
        high = CURVES[tier.ceil][bars]

        return low + (high - low) * (tier - tier.floor)
      end
    end
  end
end

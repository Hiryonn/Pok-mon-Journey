module PFM
  # Heart Gauge of a Shadow Pokemon, the amount of purification it still needs.
  class ShadowHeart
    # Number of equal bars the gauge is split into.
    # @return [Integer]
    BARS = 5

    # Full amount the gauge holds when the heart is locked
    # @return [Integer]
    attr_reader :max
    # Amount left to open, zero meaning the gauge is empty
    # @return [Integer]
    attr_reader :value

    # Create a locked heart.
    # @param max [Integer] full amount of the gauge
    # @param nature [Symbol] db_symbol of the Pokemon nature, it sets the purification rates
    # @param temper [Float, nil] tier of ShadowTemper, the gauge answering for it when left out
    def initialize(max, nature, temper = nil)
      @max = max
      @value = max
      @nature = nature
      @temper = temper
    end

    # Open the gauge by the amount its nature gives for that source.
    # @param source [Symbol] :battle, :call, :walk or :scent
    # @param multiplier [Integer] how many times the base amount the source is worth
    # @return [Integer] amount actually removed, which the last opening truncates
    def open(source, multiplier = 1)
      removed = [rates[source] * multiplier, @value].min
      @value -= removed

      return removed
    end

    # Number of bars the gauge has opened. What is left is floored, so the first bar opens as soon
    # as anything at all is taken, and the last one is shared with the empty gauge.
    # @return [Integer] from 0 to 5
    def opened_bars
      return BARS - (@value * BARS.to_f / @max).floor
    end

    # Number of bars the gauge has opened whole. What is left is ceiled, so a bar only counts once
    # nothing of it is left, which is what the gauge of the summary draws.
    # @return [Integer] from 0 to 5
    def fully_opened_bars
      return BARS - (@value * BARS.to_f / @max).ceil
    end

    # Odds the Pokemon loses control after it attacked, which its temper and the bars it has
    # already opened decide together. A breakdown being the fastest way to open the gauge, a heart
    # close to purification saves itself.
    # @return [Float]
    def instability_chance
      return ShadowTemper.chance(temper, opened_bars)
    end

    # How much of the gauge is still locked, which is what a heart gauge shows.
    # @return [Float] from 1.0 when untouched to 0.0 when empty
    def rate
      return @value.to_f / @max
    end

    # Whether the gauge is empty, so the last lock is waiting for the purification.
    # @return [Boolean]
    def empty?
      return @value <= 0
    end

    private

    # Tier this heart breaks down on, read lazily so a save written before tempers existed keeps
    # the odds its gauge alone gave it.
    # @return [Float]
    def temper
      @temper ||= ShadowTemper.from_gauge(@max)
    end

    # Purification rates of this heart nature.
    # @return [Hash{ Symbol => Integer }]
    def rates
      return RATES[@nature] || NEUTRAL_RATES
    end
  end
end

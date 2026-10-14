module PFM
  # Shadow state of a Pokemon, its locked heart and everything the lock holds back.
  class ShadowState
    # Steps the Pokemon walks in the party between two openings of its heart.
    # @return [Integer]
    WALK_STEPS = 256
    # Stat order the engine uses for its effort value lists, which the state keeps by stat symbol.
    # @return [Array<Symbol>]
    EV_STATS = %i[hp atk dfe spd ats dfs]

    # Everything a purification hands back to the Pokemon at once.
    class Release
      # Friendship a purified Pokemon starts from, whatever it held as a Shadow Pokemon.
      # @return [Integer]
      PURIFIED_LOYALTY = 70

      # Friendship the Pokemon takes back.
      # @return [Integer]
      def loyalty
        return PURIFIED_LOYALTY
      end

      # Experience the Pokemon earned while it was Shadow.
      # @return [Integer]
      attr_reader :experience
      # Effort values it earned while it was Shadow, per stat symbol.
      # @return [Hash{ Symbol => Integer }]
      attr_reader :evs
      # Original moves it gets back.
      # @return [Array<Symbol>]
      attr_reader :moves

      # Create a release.
      # @param experience [Integer]
      # @param evs [Hash{ Symbol => Integer }]
      # @param moves [Array<Symbol>]
      def initialize(experience, evs, moves)
        @experience = experience
        @evs = evs
        @moves = moves
      end
    end

    # Number of original moves each opened bar gives back. The third one asks for a slot the Shadow
    # moves rarely leave, which is why a game giving three or four Shadow moves never sees it.
    # @return [Array<Integer>]
    MOVES_GIVEN_BACK_PER_BAR = [0, 0, 1, 1, 2, 3]
    # Bar from which the nature stops being hidden.
    # @return [Integer]
    NATURE_REVEALED_AT_BAR = 3
    # Moves a Pokemon fights with at once.
    # @return [Integer]
    MOVE_SLOTS = 4

    # Experience the Pokemon earned while it was Shadow, poured back on purification.
    # @return [Integer]
    attr_reader :stored_experience

    # Effort values the Pokemon earned while it was Shadow, per stat symbol. Handed over as a copy,
    # store_evs being the only way they are ever added to.
    # @return [Hash{ Symbol => Integer }]
    def stored_evs
      return @stored_evs.dup
    end

    # Create a Shadow state around a locked heart.
    # @param heart [PFM::ShadowHeart]
    def initialize(heart)
      @heart = heart
      @stored_experience = 0
      @stored_evs = {}
    end

    # Set the experience aside rather than let the Pokemon grow on it.
    # @param amount [Integer]
    def store_experience(amount)
      @stored_experience += amount
    end

    # Set the effort values aside, adding them stat by stat.
    # @param evs [Hash{ Symbol => Integer }]
    def store_evs(evs)
      evs.each { |stat, amount| @stored_evs[stat] = @stored_evs.fetch(stat, 0) + amount }
    end

    # Open the heart from one of the purification sources.
    # @param source [Symbol] :battle, :call, :walk or :scent
    # @param multiplier [Integer] how many times the base amount the source is worth
    # @return [Integer] amount the heart lost
    def open(source, multiplier = 1)
      return @heart.open(source, multiplier)
    end

    # Number of bars the heart has opened.
    # @return [Integer]
    def opened_bars
      return @heart.opened_bars
    end

    # Number of bars the heart has opened whole.
    # @return [Integer]
    def fully_opened_bars
      return @heart.fully_opened_bars
    end

    # Whether the heart is empty, so only the purification itself is left.
    # @return [Boolean]
    def purifiable?
      return @heart.empty?
    end

    # Lock the original moves away, the Shadow moves taking their place.
    # @param moves [Array<Symbol>] db_symbols, in the order they come back
    def store_moves(moves)
      @stored_moves = moves
    end

    # Original moves the opened bars have given back. A Shadow Pokemon keeps its Shadow moves until
    # the purification, so an original move only comes back when a slot is left for it.
    # @return [Array<Symbol>]
    def restorable_moves
      return stored_moves.first([MOVES_GIVEN_BACK_PER_BAR[opened_bars], free_slots].min)
    end

    # Number of slots the heart still holds back, which the interfaces show as locked moves. A move
    # the Shadow ones leave no room for is not one of them, it will never come back before the
    # purification and nothing announces it.
    # @return [Integer]
    def locked_slots
      return [stored_moves.size, free_slots].min - restorable_moves.size
    end

    # Original moves the heart still holds back.
    # @return [Array<Symbol>]
    def remaining_moves
      return stored_moves - restorable_moves
    end

    # Whether the Pokemon has lost control. It keeps hurting itself until it is soothed, and the
    # state outlives the battle it broke down in.
    # @return [Boolean]
    def unstable?
      return @unstable == true
    end

    # How much of the heart is still locked.
    # @return [Float]
    def heart_rate
      return @heart.rate
    end

    # Odds the Pokemon loses control after it attacked.
    # @return [Float]
    def instability_chance
      return @heart.instability_chance
    end

    # Make the Pokemon lose control.
    def destabilize
      @unstable = true
    end

    # Take back control without opening the heart, which is what a knock out does. The crisis ends,
    # but the chance it gave to reach the heart is lost with it.
    def regain_control
      @unstable = false
    end

    # Calm the Pokemon down, which opens its heart by the largest amount its nature allows.
    # @return [Integer] amount the heart lost, zero when it was not unstable
    def soothe
      return 0 unless unstable?

      regain_control

      return open(:call)
    end

    # Use a scent on the Pokemon, which calms it down and opens its heart whether it had lost
    # control or not.
    # @param multiplier [Integer] how many times a Joy Scent the scent is worth
    # @return [Integer] amount the heart lost
    def use_scent(multiplier)
      regain_control

      return open(:scent, multiplier)
    end

    # Send the Pokemon out to a battle, which opens its heart. Being sent out once per battle is the
    # caller's rule, not the heart's, so nothing is guarded here.
    # @return [Integer] amount the heart lost
    def enter_battle
      return open(:battle)
    end

    # Walk one step with the Pokemon in the party, which opens its heart every WALK_STEPS steps.
    # @return [Integer] amount the heart lost, zero on every other step
    def walk_step
      @walked_steps = walked_steps + 1
      return 0 unless @walked_steps >= WALK_STEPS

      @walked_steps = 0

      return open(:walk)
    end

    # Steps walked since the heart last opened from walking.
    # @return [Integer]
    def walked_steps
      @walked_steps ||= 0
      return @walked_steps
    end

    # Keep the Shadow moves the Pokemon fights with while its heart is locked.
    # @param moves [Array<Symbol>] db_symbols
    def store_shadow_moves(moves)
      @shadow_moves = moves
    end

    # Shadow moves the Pokemon fights with while its heart is locked.
    # @return [Array<Symbol>]
    def shadow_moves
      @shadow_moves ||= []
      return @shadow_moves
    end

    # Whether the nature has stopped being hidden.
    # @return [Boolean]
    def nature_revealed?
      return opened_bars >= NATURE_REVEALED_AT_BAR
    end

    # Whether the heart has been opened for good.
    # @return [Boolean]
    def purified?
      return @purified == true
    end

    # Open the last lock and hand back everything the Shadow state held.
    # @return [PFM::ShadowState::Release, nil] nil when the heart is not empty yet, or already purified
    def purify
      return unless purifiable?
      return if purified?

      @purified = true

      return Release.new(@stored_experience, @stored_evs, stored_moves)
    end

    private

    # Slots the Shadow moves leave to the original ones.
    # @return [Integer]
    def free_slots
      return [MOVE_SLOTS - shadow_moves.size, 0].max
    end

    # Original moves, in the order they come back.
    # @return [Array<Symbol>]
    def stored_moves
      @stored_moves ||= []
      return @stored_moves
    end
  end
end

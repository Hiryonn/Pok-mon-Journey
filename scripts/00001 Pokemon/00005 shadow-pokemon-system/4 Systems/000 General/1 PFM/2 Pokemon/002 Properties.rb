module PFM
  class Pokemon
    # Shadow moves a Shadow Pokemon fights with when the encounter gives it none (Shadow Rush, the one every Shadow Pokemon of Pokemon Colosseum knew)
    # @return [Array<Symbol>]
    DEFAULT_SHADOW_MOVES = %i[shadow_rush]

    # Shadow state every question below answers from. The battler built for a fight holds none of its
    # own and hands the one of the creature it stands for, so nothing here reads the variable itself.
    # @return [PFM::ShadowState, nil]
    def shadow_state
      return @shadow_state
    end

    # Whether the Pokemon is a Shadow Pokemon whose heart is still locked.
    # @return [Boolean]
    def shadow?
      return !shadow_state.nil? && !shadow_state.purified?
    end

    # Whether its heart is empty, so the purification is only waiting for the player.
    # @return [Boolean]
    def purifiable?
      return shadow? && shadow_state.purifiable?
    end

    # Whether the Pokemon has lost control and hurts itself every turn.
    # @return [Boolean]
    def unstable?
      return shadow? && shadow_state.unstable?
    end

    # How much of the heart of the Pokemon is still locked, which is what its gauge shows.
    # @return [Float] zero when it is not a Shadow Pokemon
    def shadow_heart_rate
      return 0.0 unless shadow?

      return shadow_state.heart_rate
    end

    # Number of bars its heart has opened.
    # @return [Integer] zero when it is not a Shadow Pokemon
    def opened_heart_bars
      return 0 unless shadow?

      return shadow_state.opened_bars
    end

    # Number of bars its heart has opened whole, the count its gauge shows.
    # @return [Integer] zero when it is not a Shadow Pokemon
    def fully_opened_heart_bars
      return 0 unless shadow?

      return shadow_state.fully_opened_bars
    end

    # Whether the nature of the Pokemon has stopped being hidden, which the second opened bar does.
    # @return [Boolean] true when it is not a Shadow Pokemon, nothing hiding it then
    def nature_revealed?
      return true unless shadow?

      return shadow_state.nature_revealed?
    end

    # Slots the locked heart still holds back, one descriptor per move that is going to come back.
    # @return [Array<PFM::LockedMove>] empty when it is not a Shadow Pokemon
    def locked_moves
      return [] unless shadow?

      return Array.new(shadow_state.locked_slots) { LockedMove.new }
    end

    # Experience the Pokemon earned while its heart is locked, waiting for the purification.
    # @return [Integer] zero when it is not a Shadow Pokemon
    def held_experience
      return 0 unless shadow?

      return shadow_state.stored_experience
    end

    # Odds the Pokemon loses control after it attacked, zero when it is not a Shadow Pokemon.
    # @return [Float]
    def instability_chance
      return 0.0 unless shadow?

      return shadow_state.instability_chance
    end

    # Make the Pokemon lose control.
    def destabilize
      shadow_state.destabilize if shadow?
    end

    # Take back control without opening the heart.
    def regain_control
      shadow_state.regain_control if shadow?
    end

    # Set aside the experience the Pokemon earned while its heart is locked.
    # @param amount [Integer]
    def hold_experience(amount)
      shadow_state.store_experience(amount) if shadow?
    end

    # Set aside the effort values the Pokemon earned while its heart is locked.
    # @param evs [Hash{ Symbol => Integer }]
    def hold_effort_values(evs)
      shadow_state.store_evs(evs) if shadow?
    end

    # Use a scent on the Pokemon, which calms it down and opens its heart.
    # @param multiplier [Integer] how many times a Joy Scent the scent is worth
    # @return [Integer] amount the heart lost, zero when it is not a Shadow Pokemon
    def use_scent(multiplier)
      return 0 unless shadow?

      opened = shadow_state.use_scent(multiplier)
      refresh_shadow_moveset

      return opened
    end

    # Calm the Pokemon down, which opens its heart.
    # @return [Integer] amount the heart lost, zero when there was nothing to calm
    def soothe
      return 0 unless shadow?

      opened = shadow_state.soothe
      refresh_shadow_moveset

      return opened
    end

    # Send the Pokemon out to a battle, which opens its heart.
    # @return [Integer] amount the heart lost, zero when it is not a Shadow Pokemon
    def enter_battle
      return 0 unless shadow?

      opened = shadow_state.enter_battle
      refresh_shadow_moveset

      return opened
    end

    # Walk one step with the Pokemon in the party, which opens its heart once in a while.
    # @return [Integer] amount the heart lost, zero on every other step
    def walk_step
      return 0 unless shadow?

      opened = shadow_state.walk_step
      refresh_shadow_moveset

      return opened
    end

    # Hand back the moves the opened bars give up. Shadow moves stay in front and are never evicted, and the
    # moveset is only rebuilt when it really changes, so the PP of the moves in place survive.
    def refresh_shadow_moveset
      return unless shadow?

      wanted = (shadow_state.shadow_moves + shadow_state.restorable_moves).first(PFM::ShadowState::MOVE_SLOTS)
      return if wanted == skills_set.map(&:db_symbol)

      self.skills_set = wanted.map { |db_symbol| PFM::Skill.new(db_symbol) }
    end

    # Purify the Pokemon, pouring back the friendship, the effort values and the moves its locked heart
    # held. The experience is handed back rather than poured: only the caller can walk the level ups it
    # sets off, and by then the stats it reads are the final ones.
    # @return [Integer, false] experience the heart held, false when it did not open
    def purify
      release = shadow_state&.purify
      return false unless release

      self.loyalty = release.loyalty
      self.skills_set = release.moves.map { |db_symbol| PFM::Skill.new(db_symbol) }
      edit_bonus(ShadowState::EV_STATS.map { |stat| release.evs.fetch(stat, 0) })

      return release.experience
    end
  end
end

module PFM
  # The Shadow state lives on the Pokemon of the party, not on the battler built for the fight, so
  # every question and every verb about it goes back to the creature the battler stands for.
  class PokemonBattler
    # Effects a Shadow Pokemon carries through the battle, empty for any other creature. Memoized
    # outside @effects, the way the engine keeps ability_effect and item_effect, because it throws
    # @effects away every time a creature leaves the field while a Shadow Pokemon stays one.
    # @return [Array<Battle::Effects::Shadow>]
    def shadow_effects
      @shadow_effects ||= shadow? ? Battle::Effects::Shadow::CLASSES.map { |klass| klass.new(@scene.logic, self) } : []

      return @shadow_effects
    end

    # Mark shown next to the level of a Shadow Pokemon a Trainer still owns, the only hint Pokemon XD
    # gives the player that this one can be snagged.
    # @return [String]
    SNAGGABLE_MARK = '+'

    # Return the level text (to_pokemon_number)
    # @return [String]
    def level_pokemon_number
      return super if bank == 0 || !shadow?

      return super + SNAGGABLE_MARK
    end

    # Shadow state every question below answers from, held by the creature the battler stands for.
    # @return [PFM::ShadowState, nil]
    def shadow_state
      return @original.shadow_state
    end

    # Whether the Pokemon is a Shadow Pokemon whose heart is still locked.
    # @return [Boolean]
    def shadow?
      return @original.shadow?
    end

    # Whether the Pokemon has lost control and hurts itself every turn.
    # @return [Boolean]
    def unstable?
      return @original.unstable?
    end

    # Slots the locked heart still holds back.
    # @return [Array<PFM::LockedMove>]
    def locked_moves
      return @original.locked_moves
    end

    # Odds the Pokemon loses control after it attacked.
    # @return [Float]
    def instability_chance
      return @original.instability_chance
    end

    # Make the Pokemon lose control.
    def destabilize
      @original.destabilize
    end

    # Take back control without opening the heart.
    def regain_control
      @original.regain_control
    end

    # Calm the Pokemon down, which opens its heart.
    # @return [Integer] amount the heart lost
    def soothe
      return @original.soothe
    end

    # Send the Pokemon out to a battle, which opens its heart.
    # @return [Integer] amount the heart lost
    def enter_battle
      return @original.enter_battle
    end

    # Use a scent on the Pokemon, which calms it down and opens its heart.
    # @param multiplier [Integer] how many times a Joy Scent the scent is worth
    # @return [Integer] amount the heart lost
    def use_scent(multiplier)
      return @original.use_scent(multiplier)
    end

    # Set aside the experience the Pokemon earned while its heart is locked.
    # @param amount [Integer]
    def hold_experience(amount)
      @original.hold_experience(amount)
    end

    # Set aside the effort values the Pokemon earned while its heart is locked.
    # @param evs [Hash{ Symbol => Integer }]
    def hold_effort_values(evs)
      @original.hold_effort_values(evs)
    end
  end
end

module CCMultiProtagonist
  # Orchestrates multi-player data: which domains are swapped, who is the current player.
  # Single source of truth. Per-player values live in @data and survive save/load via Marshal.
  # Slot strategies are class-level (SLOT_REGISTRY), never part of @data.
  class Manager
    # Game state owning this manager.
    # @return [PFM::GameState]
    attr_accessor :game_state

    # @param game_state [PFM::GameState] the game state owning this manager
    def initialize(game_state)
      @game_state = game_state
      # @type [Hash{Object => Hash{Symbol => Object}}] per-player saved domain values
      @data = {}
      @current_player_id = DEFAULT_PLAYER_ID
      # Protagonist to resume when a #setup ends; nil outside a setup.
      @setup_resume = nil
    end

    # @return [Object] the id of the currently active player
    def current_player_id
      return @current_player_id
    end

    # Set the current player. An Integer id is mirrored to CURRENT_PLAYER_VAR for maker events;
    # game_variables only store numbers, so a non-Integer id stays canonical here and is not mirrored.
    # @param value [Object] the new current player id
    def current_player_id=(value)
      @current_player_id = value
      game_state.game_variables[CURRENT_PLAYER_VAR] = value if value.is_a?(Integer)
    end

    # Save the live value of a slot under a player id, then blank the live domain.
    # @param slot_key [Symbol]
    # @param player_id [Object]
    # @return [Object] the stored value
    def store_slot(slot_key, player_id)
      current_slot = slot(slot_key)
      value = current_slot.extract(game_state)
      (@data[player_id] ||= {})[slot_key] = value
      current_slot.apply(current_slot.blank(game_state), game_state)
      return value
    end

    # Load a slot from a player id into the live state, consuming the stored value.
    # @param slot_key [Symbol]
    # @param player_id [Object]
    def load_slot(slot_key, player_id)
      stored = stored_value(slot_key, player_id)
      current_slot = slot(slot_key)
      current_slot.apply(stored.nil? ? current_slot.blank(game_state) : stored, game_state)
      @data[player_id]&.delete(slot_key)
    end

    # @param slot_key [Symbol]
    # @param player_id [Object]
    # @return [Object, nil]
    def stored_value(slot_key, player_id)
      return @data[player_id] && @data[player_id][slot_key]
    end

    # Switch to another player: store every active slot under the current player, then load the
    # target. No-op when already on the target.
    # @param player_id [Object]
    # @param only [Array<Symbol>, nil]
    # @param except [Array<Symbol>, nil]
    # @param warp [Boolean] when false, the position slot is skipped (switch in place)
    # @return [Object, nil] the new player id, or nil when no switch happened
    def switch_to(player_id, only: nil, except: nil, warp: true)
      return nil if player_id == current_player_id

      keys = active_slot_keys(only: only, except: except)
      keys -= [:position] unless warp
      # Two phases: every active slot is saved under the current player BEFORE any target slot is
      # loaded, so a load never observes another slot mid-save. Position is applied last (below).
      ordered = order_for_apply(keys)
      # rubocop:disable Style/CombinableLoops -- the two phases must stay separate (store all, then load all)
      ordered.each { |slot_key| store_slot(slot_key, current_player_id) }
      ordered.each { |slot_key| load_slot(slot_key, player_id) }
      # rubocop:enable Style/CombinableLoops
      self.current_player_id = player_id
      return player_id
    end

    # Begin configuring a protagonist without a manual switch and restore dance. Saves the active
    # protagonist, makes player_id's data live (empty for a fresh protagonist), and remembers who to
    # resume. Configure it with the usual event commands (team, trainer, charset, position...), then
    # call #end_setup. Naturally silent for a fresh protagonist: a blank position does not warp and a
    # blank charset is skipped.
    # @param player_id [Object] the protagonist to configure
    # @return [Object, nil] the configured player id, or nil when it was already active
    def setup(player_id)
      @setup_resume = current_player_id
      return switch_to(player_id)
    end

    # Store the configured protagonist and return to the one active before #setup.
    # @return [Object, nil] the resumed player id, or nil when not in a setup
    def end_setup
      return nil if @setup_resume.nil?

      target = @setup_resume
      @setup_resume = nil
      return switch_to(target)
    end

    private

    # Position is applied last so its map transfer reads already-swapped domains (party, appearance).
    # @param keys [Array<Symbol>]
    # @return [Array<Symbol>]
    def order_for_apply(keys)
      return keys.reject { |slot_key| slot_key == :position } + keys.select { |slot_key| slot_key == :position }
    end

    # @param only [Array<Symbol>, nil]
    # @param except [Array<Symbol>, nil]
    # @return [Array<Symbol>]
    def active_slot_keys(only: nil, except: nil)
      keys = PER_PLAYER_SLOTS
      keys &= only if only
      keys -= except if except
      return keys
    end

    # @param slot_key [Symbol]
    # @return [CCMultiProtagonist::Slot]
    def slot(slot_key)
      return SLOT_REGISTRY.fetch(slot_key)
    end
  end
end

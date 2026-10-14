module CCMultiProtagonist
  # Portable, Marshal-safe snapshot of the swappable PC state.
  # Excludes other_party (transient steal_pokemon bucket); includes the Let's Go follower.
  class State
    # @return [Array<PFM::Storage::Box>]
    attr_reader :boxes
    # @return [Array<PFM::Storage::BattleBox>]
    attr_reader :battle_boxes
    # @return [Integer]
    attr_reader :current_box
    # @return [Integer]
    attr_reader :current_battle_box
    # @return [PFM::Pokemon, nil]
    attr_reader :lets_go_follower

    # @param boxes [Array<PFM::Storage::Box>]
    # @param battle_boxes [Array<PFM::Storage::BattleBox>]
    # @param current_box [Integer]
    # @param current_battle_box [Integer]
    # @param lets_go_follower [PFM::Pokemon, nil]
    def initialize(boxes, battle_boxes, current_box, current_battle_box, lets_go_follower)
      @boxes = boxes
      @battle_boxes = battle_boxes
      @current_box = current_box
      @current_battle_box = current_battle_box
      @lets_go_follower = lets_go_follower
    end
  end
end

module PFM
  # Plugin-owned snapshot API added by reopening PFM::Storage (the engine multi-protagonist feature is not present, so these names are free).
  # Reads @boxes legitimately from an instance method (no external instance_variable_set).
  class Storage
    # Export the swappable PC state as a portable snapshot.
    # @return [CCMultiProtagonist::State]
    def export_state
      return CCMultiProtagonist::State.new(
        @boxes.dup, battle_boxes.dup, current_box, current_battle_box, lets_go_follower
      )
    end

    # Restore the PC state from a snapshot.
    # @param snapshot [CCMultiProtagonist::State]
    def import_state(snapshot)
      @boxes = snapshot.boxes
      self.battle_boxes = snapshot.battle_boxes
      self.current_box = snapshot.current_box
      self.current_battle_box = snapshot.current_battle_box
      self.lets_go_follower = snapshot.lets_go_follower
    end

    class << self
      # Build an empty PC snapshot.
      # @param game_state [PFM::GameState]
      # @return [CCMultiProtagonist::State]
      def blank_state(game_state)
        # A blank PC must equal a FRESH PC: PFM::Storage#initialize builds the real MAX_BOXES boxes,
        # so snapshotting a throwaway instance yields a correct empty PC (no effect on the live one).
        return PFM::Storage.new(game_state).export_state
      end
    end
  end
end

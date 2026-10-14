module PFM
  class GameState
    # Walk one step with every Shadow Pokemon of the party, registered and guarded like hatching, poison and
    # loyalty, so a step taken while an event runs is not counted twice.
    def shadow_walk_update
      return if cant_process_event_tasks?

      @actors.each(&:walk_step)
    end
  end
end

Scheduler::EventTasks.on(:end_step, 'Shadow heart walk', -1) { PFM.game_state.shadow_walk_update }

# Coexistence hooks: the legacy pathfinding keeps running untouched, these
# additive prepends give the cc-pathfinding scheduler its frame tick and keep
# the two systems' lifecycles in sync. Legacy behavior is always preserved
# through super.
module CCPathfinding
  # Frame tick, right after the regular map update (same cadence as legacy)
  module MapUpdateHook
    def update
      super
      CCPathfinding.scheduler.update
    end

    # The world is being replaced (warp or save load). Save loading runs
    # setup then update BEFORE Pathfinding.load: purge here so no old-map
    # request ever runs one frame against the new map
    def setup(map_id)
      CCPathfinding.scheduler.clear
      super
    end
  end

  # Lifecycle sync on the legacy module functions
  module PathfindingLifecycleHook
    # Map warp: both systems drop their requests
    def clear
      super
      CCPathfinding.scheduler.clear
    end

    # Save loaded: cc requests are never persisted, drop any stale one
    def load
      super
      CCPathfinding.scheduler.clear
    end

    # One pathfinding system per character at a time: a legacy find_path
    # taking over a character evicts its cc request (the cc methods do the
    # reverse eviction themselves)
    def add_request(character, target, tries, tags)
      CCPathfinding.scheduler.remove_request(character)
      return super
    end
  end
end

Game_Map.prepend(CCPathfinding::MapUpdateHook)
Pathfinding.singleton_class.prepend(CCPathfinding::PathfindingLifecycleHook)

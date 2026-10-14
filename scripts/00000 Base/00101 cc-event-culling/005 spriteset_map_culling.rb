# cc-event-culling extension: hosts the event graphical-culling plugin module.
class Spriteset_Map
  # Graphical culling of map events on heavy maps. Purely visual: Game_Map keeps
  # updating every event. Cooperates with CharactersPlugin, which owns @character_sprites.
  module SpritesetCulling
    private

    # Reset the memoized culling flag; containers are (re)built in init_characters.
    def init_or_reload_sprites
      @culling_enabled = nil
      super
    end

    # Add entering events, park leaving ones, before CharactersPlugin updates the pool.
    def update_sprites
      reconcile_event_sprites if culling_enabled?

      super
    end

    # Build sprites for on-screen events only; fall back to the engine when disabled.
    def init_characters
      unless culling_enabled?
        # Culling turned off for this map: drop the parked pool so it is not orphaned.
        @idle_pool&.each(&:dispose)
        @idle_pool = nil
        @event_sprite = nil
        @particled_events = nil

        return super
      end

      reset_culled_state
      $game_map.events.each_value do |event|
        next unless event.can_be_shown?
        next unless event_on_screen?(event)

        spawn_event_sprite(event)
      end
    end

    # Dispose the idle pool on top of CharactersPlugin disposing the live sprites.
    def dispose_sprites
      super
      @idle_pool&.each(&:dispose)
      @idle_pool = []
      @event_sprite = {}
      @particled_events = {}
    end

    # Whether culling is active for the current map (memoized once per map).
    # @return [Boolean]
    def culling_enabled?
      if @culling_enabled.nil?
        @culling_enabled = CCEventCulling.culling_enabled?($game_map.width, $game_map.height,
                                                           Game_Map::NUM_TILE_VIEW_X, Game_Map::NUM_TILE_VIEW_Y)
      end

      return @culling_enabled
    end

    # Whether an event should keep a live sprite (always-shown or on screen).
    # @param event [Game_Event] the map event to test
    # @return [Boolean]
    def event_on_screen?(event)
      return true if event.always_shown?

      return CCEventCulling.on_screen?(event.real_x, event.real_y,
                                       $game_map.display_x, $game_map.display_y,
                                       Game_Map::NUM_TILE_VIEW_X, Game_Map::NUM_TILE_VIEW_Y,
                                       CCEventCulling::SCREEN_MARGIN)
    end

    # Dispose any sprites from a previous (re)load, then reset the containers.
    def reset_culled_state
      @character_sprites&.each(&:dispose)
      @idle_pool&.each(&:dispose)
      @character_sprites = []
      @idle_pool = []
      @event_sprite = {}
      @particled_events = {}
    end

    # Reconcile live event sprites with the current view, once per frame.
    def reconcile_event_sprites
      $game_map.events.each_value do |event|
        next unless event.can_be_shown?

        sprite = @event_sprite[event]

        if event_on_screen?(event)
          spawn_event_sprite(event) unless sprite
        elsif sprite
          park_event_sprite(event, sprite)
        end
      end
    end

    # Create (or reuse from the idle pool) a live sprite for an entering event.
    # @param event [Game_Event] the event entering the view
    def spawn_event_sprite(event)
      sprite = @idle_pool.pop
      if sprite
        sprite.init(event)
      else
        sprite = Sprite_Character.new(@viewport1, event)
      end

      unless @particled_events[event]
        event.particle_push
        @particled_events[event] = true
      end

      @character_sprites.push(sprite)
      @event_sprite[event] = sprite
    end

    # Park a leaving event's sprite: hide it and stash it for reuse (or dispose on overflow).
    # @param event [Game_Event] the event leaving the view
    # @param sprite [Sprite_Character] its currently live sprite
    def park_event_sprite(event, sprite)
      @character_sprites.delete(sprite)
      @event_sprite.delete(event)

      if @idle_pool.size >= CCEventCulling::IDLE_POOL_MAX
        sprite.dispose
      else
        sprite.park_for_culling
        @idle_pool.push(sprite)
      end
    end
  end

  prepend SpritesetCulling
end

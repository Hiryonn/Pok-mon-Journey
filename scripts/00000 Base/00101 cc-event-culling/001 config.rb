# cc-event-culling: graphical culling of off-screen map events on heavy maps.
# Pure predicates live in 002 predicates.rb; engine glue in the class reopenings.
module CCEventCulling
  # Extra tiles kept around the 20x15 view window to avoid pop-in of tall charsets.
  SCREEN_MARGIN = 2
  # An event whose name contains this tag is never culled (always rendered).
  ALWAYS_SHOWN_TAG = '[nocull]'
  # Hard cap of parked sprites kept for reuse; overflow is disposed to bound memory.
  IDLE_POOL_MAX = 32
end

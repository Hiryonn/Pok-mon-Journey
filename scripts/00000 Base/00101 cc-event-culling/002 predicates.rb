module CCEventCulling
  module_function

  # Whether an event's sprite falls inside the view window (plus margin), in tile space.
  # Zoom-agnostic: real_x/y and display_x/y are in 128 units per tile.
  # @param real_x [Integer] event sub-tile x (128 units per tile)
  # @param real_y [Integer] event sub-tile y (128 units per tile)
  # @param display_x [Integer] camera top-left x (128 units per tile)
  # @param display_y [Integer] camera top-left y (128 units per tile)
  # @param view_tiles_x [Integer] visible window width in tiles
  # @param view_tiles_y [Integer] visible window height in tiles
  # @param margin [Integer] extra tiles kept around the window
  # @return [Boolean]
  def on_screen?(real_x, real_y, display_x, display_y, view_tiles_x, view_tiles_y, margin)
    dx = (real_x - display_x) / 128.0
    dy = (real_y - display_y) / 128.0

    return dx >= -margin && dx <= view_tiles_x + margin &&
           dy >= -margin && dy <= view_tiles_y + margin
  end

  # Whether culling can ever do anything on this map: only when the map is
  # larger than the visible window (otherwise no event is ever off-screen).
  # @param map_width [Integer] map width in tiles
  # @param map_height [Integer] map height in tiles
  # @param view_tiles_x [Integer] visible window width in tiles
  # @param view_tiles_y [Integer] visible window height in tiles
  # @return [Boolean]
  def culling_enabled?(map_width, map_height, view_tiles_x, view_tiles_y)
    return map_width > view_tiles_x || map_height > view_tiles_y
  end

  # Whether an event name carries the always-shown tag.
  # @param name [String] the event's name
  # @return [Boolean]
  def name_always_shown?(name)
    return name.include?(ALWAYS_SHOWN_TAG)
  end
end

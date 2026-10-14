# cc-event-culling extension: marks events exempt from graphical culling.
class Game_Event
  # Whether this event must always keep its sprite, ignoring culling.
  # Mirrors the engine's can_be_shown? tag pattern ([sprite=off]).
  # @return [Boolean]
  def always_shown?
    return CCEventCulling.name_always_shown?(@event.name)
  end
end

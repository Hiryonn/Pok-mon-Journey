# cc-event-culling extension: lets a character sprite be hidden while parked in the pool.
class Sprite_Character
  # Hide every drawable so the sprite renders nothing while parked in the idle pool.
  # Freezing its update is the caller's job (removed from @character_sprites).
  def park_for_culling
    self.visible = false
    @bush_depth_sprite.visible = false
    @shadow&.visible = false
    @reflection&.visible = false
  end
end

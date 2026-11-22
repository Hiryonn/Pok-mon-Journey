# Time Twist (time_twist)
# When its HP becomes half or less, the Pokémon twists the dimensions to invert speed order for three turns.
# Quand ses PV tombent à la moitié ou moins (une fois) : lance Distorsion pour 3 tours (l'ordre de vitesse est inversé).
ExtraAbilitiesAdditions.define(:time_twist) do
  def on_post_damage(handler, _hp, target, _launcher, _skill)
    ea_safe('Time Twist') do
      next if target != @target || @twisted || target.hp_rate > 0.5

      @twisted = true
      logic = handler.logic
      next if logic.terrain_effects.has?(:trick_room)

      ea_show(handler.scene, target)
      effect = Battle::Effects::TrickRoom.new(logic)
      effect.counter = 3
      logic.terrain_effects.add(effect)
    end
  end
end

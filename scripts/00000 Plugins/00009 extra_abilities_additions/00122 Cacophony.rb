# Cacophony (cacophony)
# This Pokémon's horrid cacophony powers up its sound-based moves.
ExtraAbilitiesAdditions.define(:cacophony) do
  # Capacités sonores : x1,3.
  def base_power_multiplier(user, _target, move)
    ea_safe('Cacophony', 1) { next(user == @target && move.respond_to?(:sound_attack?) && move.sound_attack? ? 1.3 : 1) }
  end
end

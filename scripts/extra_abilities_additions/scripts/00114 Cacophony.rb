# Cacophony (cacophony)
# This Pokémon's horrid cacophony powers up its sound-based moves.
# Capacités sonores : x1,3.
ExtraAbilitiesAdditions.define(:cacophony) do
  def base_power_multiplier(user, target, move)
    ea_safe('Cacophony', 1) do
      next(user == @target && move.sound_attack? ? 1.3 : 1)
    end
  end
end

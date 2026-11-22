# Overcharged (overcharged)
# Gives priority to an Electric-type move used on the first turn this Pokémon is in battle.
# Capacité Électrik : priorité +1 pendant le premier tour au combat.
ExtraAbilitiesAdditions.define(:overcharged) do
  def on_move_priority_change(user, priority, move)
    ea_safe('Overcharged') do
      next nil if user != @target || user.turn_count != 0 || !ea_type?(move, :electric)

      next priority + 1
    end
  end
end

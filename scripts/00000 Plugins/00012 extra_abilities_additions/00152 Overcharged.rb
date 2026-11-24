# Overcharged (overcharged)
# Gives priority to an Electric-type move used on the first turn this Pokémon is in battle.
ExtraAbilitiesAdditions.define(:overcharged) do
  # Capacité Électrik : priorité +1 pendant le premier tour au combat.
  def on_switch_event(_handler, _who, with)
    @first_turn = true if with == @target
  end

  def on_end_turn_event(_logic, _scene, _battlers)
    @first_turn = false
  end

  def on_move_priority_change(user, priority, move)
    ea_safe('Overcharged', priority) { next(user == @target && @first_turn && ea_type?(move, :electric) ? priority + 1 : priority) }
  end
end

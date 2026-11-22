# Quick Charge (quick_charge)
# Gives priority to the Pokémon's first move each time the Pokémon enters battle.
ExtraAbilitiesAdditions.define(:quick_charge) do
  # Première capacité à chaque entrée au combat : priorité +1.
  def on_switch_event(_handler, _who, with)
    @first_turn = true if with == @target
  end

  def on_end_turn_event(_logic, _scene, _battlers)
    @first_turn = false
  end

  def on_move_priority_change(user, priority, move)
    ea_safe('Quick Charge', priority) { next(user == @target && @first_turn ? priority + 1 : priority) }
  end
end

# Quick Charge (quick_charge)
# Gives priority to the Pokémon's first move each time the Pokémon enters battle.
# Première capacité à chaque entrée au combat : priorité +1.
ExtraAbilitiesAdditions.define(:quick_charge) do
  def on_move_priority_change(user, priority, move)
    ea_safe('Quick Charge') do
      next nil if user != @target || user.turn_count != 0

      next priority + 1
    end
  end
end

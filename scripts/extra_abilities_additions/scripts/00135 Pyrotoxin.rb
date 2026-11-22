# Pyrotoxin (pyrotoxin)
# Powers up Fire-type moves if the target is poisoned, and powers up Poison-type moves if the target is burned.
ExtraAbilitiesAdditions.define(:pyrotoxin) do
  # Feu x1,5 si la cible est empoisonnée ; Poison x1,5 si elle est brûlée.
  def base_power_multiplier(user, target, move)
    ea_safe('Pyrotoxin', 1) do
      next 1 if user != @target

      next 1.5 if ea_type?(move, :fire) && target.poisoned?
      next 1.5 if ea_type?(move, :poison) && target.burn?

      next 1
    end
  end
end

# Permafrost (permafrost)
# Doubles the power of its Ice-type moves and lowers the power of Fire-type moves that hit the Pokémon. It also prevents the Pokémon from being burned.
# Glace x2 ; capacités Feu reçues x0,5 ; pas de brûlure (hérite de Voile Eau).
ExtraAbilitiesAdditions.define(:permafrost, :WaterVeil) do
  def base_power_multiplier(user, target, move)
    ea_safe('Permafrost', 1) do
      next 2 if user == @target && ea_type?(move, :ice)

      next(target == @target && ea_type?(move, :fire) ? 0.5 : 1)
    end
  end
end

# Pecking Order (pecking_order)
# Boosts the power of the Pokémon's Flying-type moves, and lowers the power of everyone else's.
# Ses capacités Vol : x1,3 ; les capacités Vol qui le touchent : x0,7.
ExtraAbilitiesAdditions.define(:pecking_order) do
  def base_power_multiplier(user, target, move)
    ea_safe('Pecking Order', 1) do
      next 1 unless ea_type?(move, :flying)
      next 1.3 if user == @target

      next(target == @target ? 0.7 : 1)
    end
  end
end

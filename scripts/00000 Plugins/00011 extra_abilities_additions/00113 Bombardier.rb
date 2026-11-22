# Bombardier (bombardier)
# Powers up ball and bomb moves.
# Balles et bombes : x1,3.
ExtraAbilitiesAdditions.define(:bombardier) do
  def base_power_multiplier(user, target, move)
    ea_safe('Bombardier', 1) do
      next(user == @target && move.ballistics? ? 1.3 : 1)
    end
  end
end

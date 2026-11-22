# Bombardier (bombardier)
# Powers up ball and bomb moves.
ExtraAbilitiesAdditions.define(:bombardier) do
  # Balles et bombes : x1,3.
  def base_power_multiplier(user, _target, move)
    ea_safe('Bombardier', 1) { next(user == @target && move.respond_to?(:ballistics?) && move.ballistics? ? 1.3 : 1) }
  end
end

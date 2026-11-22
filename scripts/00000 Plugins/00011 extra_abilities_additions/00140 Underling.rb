# Underling (underling)
# Powers up the Pokémon's physical attacks when battling with an ally that has a higher Attack stat than itself.
ExtraAbilitiesAdditions.define(:underling) do
  # Attaques physiques x1,3 si un allié a plus d'Attaque.
  def base_power_multiplier(user, _target, move)
    ea_safe('Underling', 1) do
      next 1 if user != @target || !move.physical?

      next(@logic.allies_of(@target).any? { |ally| ally.atk > @target.atk } ? 1.3 : 1)
    end
  end
end

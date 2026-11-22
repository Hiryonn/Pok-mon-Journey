# Malice (malice)
# The Pokémon is filled with malice, and that boosts the Sp. Atk stat after knocking out any Pokémon.
ExtraAbilitiesAdditions.define(:malice) do
  # Après un K.O. : Atq. Spé. +1.
  def on_post_damage_event(handler, _hp, target, launcher, _skill)
    ea_safe('Malice') do
      next if launcher != @target || target == launcher || !target.dead?

      ea_stat(handler.logic, :ats, 1, launcher, launcher)
    end
  end
end

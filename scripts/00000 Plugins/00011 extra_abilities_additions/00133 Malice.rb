# Malice (malice)
# The Pokémon is filled with malice, and that boosts the Sp. Atk stat after knocking out any Pokémon.
# Après un K.O. : Atq. Spé. +1.
ExtraAbilitiesAdditions.define(:malice) do
  def on_post_damage_death(handler, _hp, target, launcher, _skill)
    ea_safe('Malice') do
      next if launcher != @target || target == launcher

      ea_stat(handler.logic, :ats, 1, launcher, launcher)
    end
  end
end

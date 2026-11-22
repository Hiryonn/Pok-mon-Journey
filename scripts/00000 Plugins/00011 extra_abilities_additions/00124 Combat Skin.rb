# Combat Skin (combat_skin)
# Its combat skin blocks the additional effects of attacks taken. It also reduces damage taken from contact moves.
# Peau de combat : bloque les effets additionnels (hérite de Écran Poudre) et réduit de 25 % les dégâts des attaques de contact.
ExtraAbilitiesAdditions.define(:combat_skin, :ShieldDust) do
  def base_power_multiplier(_user, target, move)
    ea_safe('Combat Skin', 1) { next(target == @target && move.direct? ? 0.75 : 1) }
  end
end

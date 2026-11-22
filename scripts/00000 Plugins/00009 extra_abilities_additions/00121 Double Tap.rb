# Double Tap (double_tap)
# The user's attacks that share its type hit twice, with the second attack being slightly weaker.
# Ses attaques du même type que lui frappent deux fois, la seconde à 75 % (mécanique de Lien Parental).
ExtraAbilitiesAdditions.define(:double_tap, :ParentalBond) do
  def specific_proceed_internal(user, targets, move)
    return nil if user != @target || !(move.type == user.type1 || move.type == user.type2)

    return super
  end

  def mod3_multiplier(user, target, move)
    value = super
    return(value.is_a?(Numeric) && value < 1 ? 0.75 : value)
  end
end

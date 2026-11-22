# Sharp Coral (sharp_coral)
# Its sharpened body doubles its attacking power, but leaves it vulnerable.
ExtraAbilitiesAdditions.define(:sharp_coral) do
  # Attaque x2, mais les dégâts reçus augmentent de 50 %.
  def atk_modifier
    return 2
  end

  def ats_modifier
    return 2
  end

  def base_power_multiplier(_user, target, _move)
    return target == @target ? 1.5 : 1
  end
end

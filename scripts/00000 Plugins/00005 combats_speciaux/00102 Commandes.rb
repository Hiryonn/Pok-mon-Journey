# encoding: utf-8
# Combats spéciaux : commandes d'évènement (voir 00100 Configuration.rb)
class Interpreter
  def combat_triple(trainer, variable: 0)
    return CombatsSpeciaux.triple_battle(trainer, variable: variable)
  end

  def combat_trio_sauvage(specs, variable: 0)
    return CombatsSpeciaux.wild_trio(specs, variable: variable)
  end

  def combat_horde(species, level, taille: nil, forme: 0, variable: 0)
    return CombatsSpeciaux.horde(species, level, size: taille, form: forme, variable: variable)
  end

  def combat_special_gagne?
    return CombatsSpeciaux.last_won == true
  end

  def combat_special_possible?(count = 3)
    return CombatsSpeciaux.possible?(count)
  end
end

# Geiger Sense (geiger_sense)
# If there are Nuclear-type Pokémon upon entering battle, its Attack and Sp. Atk stats are boosted.
ExtraAbilitiesAdditions.define(:geiger_sense) do
  # À l'entrée : si un adversaire est de type Nucléaire, Attaque et Atq. Spé. +1.
  def on_switch_event(handler, _who, with)
    ea_safe('Geiger Sense') do
      next if with != @target

      nuclear = ea_type_id(:nuclear)
      next unless ea_foes(handler.logic, @target).any? { |foe| foe.type1 == nuclear || foe.type2 == nuclear }

      ea_stat(handler.logic, :atk, 1, @target, @target)
      ea_stat(handler.logic, :ats, 1, @target, @target)
    end
  end
end

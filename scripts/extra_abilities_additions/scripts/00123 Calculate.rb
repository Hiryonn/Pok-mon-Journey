# Calculate (calculate)
# Compares an opposing Pokémon's Attack and Sp. Atk stats before raising its own Defense or Sp. Def stat—whichever will be more effective.
ExtraAbilitiesAdditions.define(:calculate) do
  # À l'entrée : compare Attaque et Atq. Spé. des adversaires, puis monte la Défense (ou la Déf. Spé.) la plus utile.
  def on_switch_event(handler, _who, with)
    ea_safe('Calculate') do
      next if with != @target

      foes = ea_foes(handler.logic, @target)
      next if foes.empty?

      physical = foes.sum(&:atk) >= foes.sum(&:ats)
      ea_stat(handler.logic, physical ? :dfe : :dfs, 1, @target, @target)
    end
  end
end

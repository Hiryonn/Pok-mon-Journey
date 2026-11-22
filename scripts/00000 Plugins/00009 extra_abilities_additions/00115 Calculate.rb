# Calculate (calculate)
# Compares an opposing Pokémon's Attack and Sp. Atk stats before raising its own Defense or Sp. Def stat—whichever will be more effective.
# À l'entrée : compare Attaque et Atq. Spé. des adversaires, puis monte la Défense (ou la Déf. Spé.) la plus utile.
ExtraAbilitiesAdditions.define(:calculate) do
  def on_switch_event(handler, _who, with)
    ea_safe('Calculate') do
      next if with != @target

      foes = ea_foes(handler.logic, @target)
      next if foes.empty?

      ea_show(handler.scene, @target)
      physical = foes.sum(&:atk) >= foes.sum(&:ats)
      ea_stat(handler.logic, physical ? :dfe : :dfs, 1, @target, @target)
    end
  end
end

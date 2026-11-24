# Mechanic Shift (mechanic_shift)
# The Pokémon's mechanic body shifts to change form at the end of each turn.
# Fin de tour : change de forme (forme 0 <-> forme 1) si l'espèce a cette forme.
ExtraAbilitiesAdditions.define(:mechanic_shift) do
  def on_end_turn_event(_logic, scene, battlers)
    ea_safe('Mechanic Shift') do
      next if !battlers.include?(@target) || @target.dead?

      wanted = @target.form == 0 ? 1 : 0
      forms = GameData::Pokemon[@target.db_symbol].forms
      next unless forms.any? { |f| f.form == wanted }

      ea_show(scene, @target)
      @target.form = wanted
      @target.form_calibrate(:battle) if @target.respond_to?(:form_calibrate)
    end
  end
end

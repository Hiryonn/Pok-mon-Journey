# Herbalist (herbalist)
# The Pokémon may create another Herb after one is used.
# Après l'utilisation d'une Herbe (Blanche, Mental, Pouvoir), 30 % de chances d'en recevoir une nouvelle.
ExtraAbilitiesAdditions.define(:herbalist) do


  def on_post_action_event(logic, scene, _battlers)
    check_herb(logic, scene)
  end

  def on_end_turn_event(logic, scene, _battlers)
    check_herb(logic, scene)
  end

  private

  def check_herb(logic, scene)
    ea_safe('Herbalist') do
      current = @target.item_db_symbol
      if ExtraAbilitiesAdditions::HERBS.include?(current)
        @herb = current
      elsif @herb && current == :none && !@target.dead?
        herb = @herb
        @herb = nil
        if rand < 0.3
          ea_show(scene, @target)
          logic.item_change_handler.change_item(herb, false, @target)
        end
      end
    end
  end
end

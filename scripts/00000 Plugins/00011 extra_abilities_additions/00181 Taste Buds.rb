# Taste Buds (taste_buds)
# When the Pokémon eats, it shares the effects of the held item with its allies.
# Quand le Pokémon consomme une Baie ou une Herbe, ses alliés en subissent aussi l'effet.
ExtraAbilitiesAdditions.define(:taste_buds) do
  def on_switch_event(_handler, _who, _with)
    track_item
  end

  def on_post_action_event(logic, scene, _battlers)
    check_item(logic, scene)
  end

  def on_end_turn_event(logic, scene, _battlers)
    check_item(logic, scene)
  end

  private

  def shareable?(sym)
    return false if sym.nil? || sym == :none
    return true if ExtraAbilitiesAdditions::HERBS.include?(sym)
    return sym.to_s.end_with?('_berry')
  end

  def track_item
    ea_safe('Taste Buds') do
      current = @target.item_db_symbol
      @last_item = shareable?(current) ? current : nil
    end
  end

  def check_item(logic, scene)
    ea_safe('Taste Buds') do
      current = @target.item_db_symbol
      if shareable?(current)
        @last_item = current
      elsif @last_item && current == :none && !@target.dead?
        sym = @last_item
        @last_item = nil
        share(logic, scene, sym)
      elsif current != :none
        @last_item = nil
      end
    end
  end

  def share(logic, scene, sym)
    allies = logic.allies_of(@target).reject(&:dead?)
    return if allies.empty?

    ea_show(scene, @target)
    allies.each do |ally|
      ea_safe('Taste Buds ally') do
        eff = Battle::Effects::Item.new(logic, ally, sym)
        if defined?(Battle::Effects::Item::Berry) && eff.is_a?(Battle::Effects::Item::Berry)
          eff.execute_berry_effect(force_heal: true, force_execution: true)
        elsif eff.respond_to?(:apply_common_effects_with_fling)
          eff.apply_common_effects_with_fling(scene, ally)
        end
      end
    end
  end
end

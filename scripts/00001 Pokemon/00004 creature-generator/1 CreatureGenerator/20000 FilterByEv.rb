class CreatureGenerator
  # Generates creature forms with a specific EV value for the given stat
  # @param ev_stat [Symbol] The EV stat to filter by (e.g., :hp, :atk). Will be normalized to 'ev_' prefix
  # @param amount [Integer] The EV value to match
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Array<Studio::CreatureForm>]
  def generate_creature_forms_by_ev(ev_stat, amount, all_creature_forms = generate_all_creature_forms)
    # Normalize the stat symbol to ensure it starts with 'ev_'
    ev_stat = :"ev_#{ev_stat}" unless ev_stat.to_s.start_with?('ev_')
    valid_stats = %i[ev_hp ev_atk ev_dfe ev_ats ev_dfs ev_spd]

    raise ArgumentError, "Invalid stat: #{ev_stat}" unless valid_stats.include?(ev_stat)
    raise ArgumentError, "Invalid amount: #{amount}" unless amount.is_a?(Integer) && amount.positive?
    raise ArgumentError, 'Invalid all_creature_forms' unless valid_creature_forms_array?(all_creature_forms)

    all_creature_forms = all_creature_forms.filter { |creature_form| creature_form.send(ev_stat) == amount }
    raise "No creature forms found with #{ev_stat} = #{amount}" if all_creature_forms.empty?

    log_data("Generated #{all_creature_forms.size} creature forms with #{ev_stat} = #{amount}.")
    return all_creature_forms
  end
  alias by_ev generate_creature_forms_by_ev

  # Generates a random creature form with a specific EV value for the given stat
  # @param ev_stat [Symbol] The EV stat to filter by (e.g., :hp, :atk). Will be normalized to 'ev_' prefix
  # @param amount [Integer] The EV value to match
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Studio::CreatureForm]
  def generate_random_creature_form_by_ev(ev_stat, amount, all_creature_forms = generate_all_creature_forms)
    return generate_creature_forms_by_ev(ev_stat, amount, all_creature_forms).sample.tap do |creature|
      log_data("Generated random creature form by EV: #{creature.name} (Form: #{creature.form})")
    end
  end
  alias random_by_ev generate_random_creature_form_by_ev
end

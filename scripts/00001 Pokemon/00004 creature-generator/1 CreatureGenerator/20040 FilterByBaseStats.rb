class CreatureGenerator
  # Generates creature forms with a specific base stat condition
  # @param base_stat [Symbol] The base stat to filter by (e.g., :hp, :atk). Will be normalized to 'base_' prefix
  # @param amount [Integer] The reference value for comparison
  # @param second_amount [Integer, nil] The upper bound for :between comparison
  # @param comparison_type [Symbol] The comparison type (:equal, :lte, :gte, :between)
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Array<Studio::CreatureForm>]
  def generate_creature_forms_by_base_stats(base_stat, amount, second_amount = nil, comparison_type = :equal, all_creature_forms = generate_all_creature_forms)
    # Normalize the stat symbol to ensure it starts with 'base_'
    base_stat = :"base_#{base_stat}" unless base_stat.to_s.start_with?('base_')
    valid_stats = %i[base_hp base_atk base_dfe base_ats base_dfs base_spd]

    raise ArgumentError, "Invalid base stat: #{base_stat}" unless valid_stats.include?(base_stat)

    return filter_creature_forms_by_stat(amount, second_amount, comparison_type, all_creature_forms) { |creature_form|
      creature_form.send(base_stat)
    }
  end
  alias by_base_stats generate_creature_forms_by_base_stats

  # Generates a random creature form with a specific base stat condition
  # @param base_stat [Symbol] The base stat to filter by (e.g., :hp, :atk). Will be normalized to 'base_' prefix
  # @param amount [Integer] The reference value for comparison
  # @param second_amount [Integer, nil] The upper bound for :between comparison
  # @param comparison_type [Symbol] The comparison type (:equal, :lte, :gte, :between)
  # @param all_creature_forms [Array<Studio::CreatureForm>] Optional: List of creature forms to filter
  # @return [Studio::CreatureForm]
  def generate_random_creature_form_by_base_stats(base_stat, amount, second_amount = nil, comparison_type = :equal, all_creature_forms = generate_all_creature_forms)
    return generate_creature_forms_by_base_stats(base_stat, amount, second_amount, comparison_type, all_creature_forms).sample.tap do |creature|
      log_data("Generated random creature form by base stats: #{creature.name} (Form: #{creature.form})")
    end
  end
  alias random_by_base_stats generate_random_creature_form_by_base_stats

  # Generates creature forms with a specific total base stat condition
  # @param amount [Integer] The reference value for comparison
  # @param second_amount [Integer, nil] The upper bound for :between comparison
  # @param comparison_type [Symbol] The comparison type (:equal, :lte, :gte, :between)
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Array<Studio::CreatureForm>]
  def generate_creature_forms_by_total_base_stats(amount, second_amount = nil, comparison_type = :equal, all_creature_forms = generate_all_creature_forms)
    return filter_creature_forms_by_stat(amount, second_amount, comparison_type, all_creature_forms) { |creature_form|
      %i[base_hp base_atk base_dfe base_ats base_dfs base_spd].sum { |stat| creature_form.send(stat) }
    }
  end
  alias by_total_base_stats generate_creature_forms_by_total_base_stats

  # Generates a random creature form with a specific total base stat condition
  # @param amount [Integer] The reference value for comparison
  # @param second_amount [Integer, nil] The upper bound for :between comparison
  # @param comparison_type [Symbol] The comparison type (:equal, :lte, :gte, :between)
  # @param all_creature_forms [Array<Studio::CreatureForm>] Optional: List of creature forms
  # @return [Studio::CreatureForm]
  def generate_random_creature_form_by_total_base_stats(amount, second_amount = nil, comparison_type = :equal, all_creature_forms = generate_all_creature_forms)
    return generate_creature_forms_by_total_base_stats(amount, second_amount, comparison_type, all_creature_forms).sample.tap do |creature|
      log_data("Generated random creature form by total base stats: #{creature.name} (Form: #{creature.form})")
    end
  end
  alias random_by_total_base_stats generate_random_creature_form_by_total_base_stats
end

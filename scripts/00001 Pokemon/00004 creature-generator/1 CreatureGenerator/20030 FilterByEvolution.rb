class CreatureGenerator
  # Generates creature forms with a specific given evolution stage
  # @param evolution_stage [Integer] The stage to match (0 = first, 1 = middle, 2 = final)
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Array<Studio::CreatureForm>]
  def generate_creature_forms_by_evolution_stage(evolution_stage, all_creature_forms = generate_all_creature_forms)
    raise ArgumentError, "Invalid evolution stage: #{evolution_stage}" unless evolution_stage.is_a?(Integer)
    raise ArgumentError, "Invalid evolution stage: #{evolution_stage}" unless (0..2).include?(evolution_stage)
    raise ArgumentError, 'Invalid all_creature_forms' unless valid_creature_forms_array?(all_creature_forms)

    stage_filters = [
      method(:first_stage?),
      method(:middle_stage?),
      method(:third_stage?)
    ]

    all_creature_forms = all_creature_forms.filter(&stage_filters[evolution_stage])
    raise "No creature forms found with evolution stage: #{evolution_stage}" if all_creature_forms.empty?

    log_data("Generated #{all_creature_forms.size} creature forms with evolution stage: #{evolution_stage}.")
    return all_creature_forms
  end
  alias by_evolution_stage generate_creature_forms_by_evolution_stage

  # Generates a random creature form with a specific given evolution stage
  # @param evolution_stage [Integer] The stage to match (0 = first, 1 = middle, 2 = final)
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Studio::CreatureForm]
  def generate_random_creature_form_by_evolution_stage(evolution_stage, all_creature_forms = generate_all_creature_forms)
    return generate_creature_forms_by_evolution_stage(evolution_stage, all_creature_forms).sample.tap do |creature|
      log_data("Generated random creature form by evolution stage: #{creature.name} (Form: #{creature.form})")
    end
  end
  alias random_by_evolution_stage generate_random_creature_form_by_evolution_stage

  # Generates creature forms belonging to an evolution chain of a specific length
  # @param length [Integer] The chain length to match (1 = standalone, 2 = two stages, 3 = three stages)
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Array<Studio::CreatureForm>]
  def generate_creature_forms_by_chain_length(length, all_creature_forms = generate_all_creature_forms)
    raise ArgumentError, "Invalid chain length: #{length}" unless length.is_a?(Integer) && length.positive?
    raise ArgumentError, 'Invalid all_creature_forms' unless valid_creature_forms_array?(all_creature_forms)

    all_creature_forms = all_creature_forms.filter { |creature_form| chain_length(creature_form) == length }
    raise "No creature forms found with chain length: #{length}" if all_creature_forms.empty?

    log_data("Generated #{all_creature_forms.size} creature forms with chain length: #{length}.")
    return all_creature_forms
  end
  alias by_chain_length generate_creature_forms_by_chain_length

  # Generates a random creature form belonging to an evolution chain of a specific length
  # @param length [Integer] The chain length to match (1 = standalone, 2 = two stages, 3 = three stages)
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Studio::CreatureForm]
  def generate_random_creature_form_by_chain_length(length, all_creature_forms = generate_all_creature_forms)
    return generate_creature_forms_by_chain_length(length, all_creature_forms).sample.tap do |creature|
      log_data("Generated random creature form by chain length: #{creature.name} (Form: #{creature.form})")
    end
  end
  alias random_by_chain_length generate_random_creature_form_by_chain_length
end

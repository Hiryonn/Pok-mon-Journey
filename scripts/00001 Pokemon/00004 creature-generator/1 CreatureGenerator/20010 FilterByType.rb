class CreatureGenerator
  # Generates creature forms with a specific given type (primary or secondary)
  # @param type [Symbol] The type to match (e.g., :fire, :water)
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Array<Studio::CreatureForm>]
  def generate_creature_forms_by_type(type, all_creature_forms = generate_all_creature_forms)
    raise ArgumentError, "Invalid type: #{type}" unless type.is_a?(Symbol)
    raise ArgumentError, "Invalid type: #{type}" if data_type(type).id.zero?
    raise ArgumentError, 'Invalid all_creature_forms' unless valid_creature_forms_array?(all_creature_forms)

    all_creature_forms = all_creature_forms.filter { |creature_form| creature_form.type1 == type || creature_form.type2 == type }
    raise "No creature forms found with type: #{type}" if all_creature_forms.empty?

    log_data("Generated #{all_creature_forms.size} creature forms with type: #{data_type(type).name}.")
    return all_creature_forms
  end
  alias by_type generate_creature_forms_by_type

  # Generates a random creature form with a specific given type (primary or secondary)
  # @param type [Symbol] The type to match (e.g., :fire, :water)
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Studio::CreatureForm]
  def generate_random_creature_form_by_type(type, all_creature_forms = generate_all_creature_forms)
    return generate_creature_forms_by_type(type, all_creature_forms).sample.tap do |creature|
      log_data("Generated random creature form by type: #{creature.name} (Form: #{creature.form})")
    end
  end
  alias random_by_type generate_random_creature_form_by_type
end

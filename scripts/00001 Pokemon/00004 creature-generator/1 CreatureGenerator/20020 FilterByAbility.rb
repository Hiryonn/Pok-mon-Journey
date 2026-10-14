class CreatureGenerator
  # Generates creature forms with a specific given ability
  # @param ability [Symbol] The ability to filter by (e.g., :overgrow, :blaze, :torrent)
  # @param include_hidden [Boolean] Whether to include the hidden ability (index 2) in the search (default: false)
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Array<Studio::CreatureForm>]
  def generate_creature_forms_by_ability(ability, include_hidden = false, all_creature_forms = generate_all_creature_forms)
    raise ArgumentError, "Invalid ability: #{ability}" unless ability.is_a?(Symbol)
    raise ArgumentError, "Invalid ability: #{ability}" if data_ability(ability).id.negative?
    raise ArgumentError, 'Invalid all_creature_forms' unless valid_creature_forms_array?(all_creature_forms)

    all_creature_forms = all_creature_forms.filter do |creature_form|
      abilities = include_hidden ? creature_form.abilities : creature_form.abilities.first(2)
      next abilities.include?(ability)
    end
    raise "No creature forms found with ability: #{ability}" if all_creature_forms.empty?

    log_data("Generated #{all_creature_forms.size} creature forms with ability: #{data_ability(ability).name}.")
    return all_creature_forms
  end
  alias by_ability generate_creature_forms_by_ability

  # Generates a random creature form with a specific given ability
  # @param ability [Symbol] The ability to filter by (e.g., :overgrow, :blaze, :torrent)
  # @param include_hidden [Boolean] Whether to include the hidden ability (index 2) in the search (default: false)
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Studio::CreatureForm]
  def generate_random_creature_form_by_ability(ability, include_hidden = false, all_creature_forms = generate_all_creature_forms)
    return generate_creature_forms_by_ability(ability, include_hidden, all_creature_forms).sample.tap do |creature|
      log_data("Generated random creature form by ability: #{creature.name} (Form: #{creature.form})")
    end
  end
  alias random_by_ability generate_random_creature_form_by_ability
end

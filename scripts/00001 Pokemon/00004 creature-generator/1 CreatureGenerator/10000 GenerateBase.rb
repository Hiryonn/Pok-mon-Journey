class CreatureGenerator
  # Generate all creature forms from the database
  # @return [Array<Studio::CreatureForm>]
  def generate_all_creature_forms
    # @type [Array<Studio::CreatureForm>]
    all_creature_forms = []

    each_data_creature_form do |creature_form|
      next if mega_evolution?(creature_form.form)
      next if gigantamax?(creature_form.form)
      next if !@allow_legendary && legendary?(creature_form)
      next if !@allow_mythical && mythical?(creature_form)
      next if !@allow_ultra_beast && ultra_beast?(creature_form)
      next if !@allow_pseudo_legendary && pseudo_legendary?(creature_form)
      next if !@allow_baby && baby?(creature_form)

      all_creature_forms << creature_form
    end

    raise 'No creature forms found' if all_creature_forms.empty?

    log_data("Generated #{all_creature_forms.size} creature forms.")
    return all_creature_forms
  end
  alias all_forms generate_all_creature_forms

  # Generates a random creature form from the database
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Studio::CreatureForm]
  def generate_random_creature_form(all_creature_forms = generate_all_creature_forms)
    raise ArgumentError, 'Invalid all_creature_forms' unless valid_creature_forms_array?(all_creature_forms)

    return all_creature_forms.sample.tap do |creature|
      log_data("Generated random creature form: #{creature.name} (Form: #{creature.form})")
    end
  end
  alias random_form generate_random_creature_form
end

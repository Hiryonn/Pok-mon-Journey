class CreatureGenerator
  # Extract all unique creature forms from a wild encounter group
  # @param group_identifier [Symbol, Integer] The database symbol or ID of the group
  # @return [Array<Studio::CreatureForm>]
  def creature_forms_from_group(group_identifier)
    group = resolve_group(group_identifier)

    all_creature_forms = []
    seen_pairs = []

    group.encounters.each do |encounter|
      resolved_form = resolve_encounter_form(encounter)
      pair = [encounter.specie, resolved_form]
      next if seen_pairs.include?(pair)
      next if mega_evolution?(resolved_form)
      next if gigantamax?(resolved_form)

      seen_pairs << pair
      all_creature_forms << data_creature_form(encounter.specie, resolved_form)
    end

    raise ArgumentError, "No valid creature forms in group #{group_identifier}" if all_creature_forms.empty?

    log_data("Generated #{all_creature_forms.size} creature forms from group #{group_identifier}.")
    return all_creature_forms
  end
  alias from_group creature_forms_from_group

  # Generate a random Pokemon from a wild encounter group using weighted selection
  # @param group_identifier [Symbol, Integer] The database symbol or ID of the group
  # @param creature_forms [Array<Studio::CreatureForm>, nil] Optional filter to restrict eligible encounters
  # @return [PFM::Pokemon]
  def random_pokemon_from_group(group_identifier, creature_forms = nil)
    group = resolve_group(group_identifier)
    raise ArgumentError, 'Invalid creature_forms' if creature_forms && !valid_creature_forms_array?(creature_forms)

    eligible_encounters = filter_eligible_encounters(group.encounters, creature_forms)
    raise ArgumentError, "No encounters match in group #{group_identifier}" if eligible_encounters.empty?

    selected_encounter = weighted_random_encounter(eligible_encounters)
    pokemon = selected_encounter.to_creature

    log_data("Generated Pokemon from group #{group_identifier}: #{pokemon.name} (Level: #{pokemon.level})")
    return pokemon
  end
  alias random_from_group random_pokemon_from_group

  private

  # Resolve a group identifier (Symbol or Integer) to a Studio::Group
  # @param group_identifier [Symbol, Integer] The database symbol or ID of the group
  # @return [Studio::Group]
  def resolve_group(group_identifier)
    raise ArgumentError, "Invalid group: #{group_identifier}" unless group_identifier.is_a?(Symbol) || group_identifier.is_a?(Integer)

    if group_identifier.is_a?(Integer)
      group = nil
      each_data_group do |candidate|
        next unless candidate.id == group_identifier

        group = candidate
        break
      end
      raise ArgumentError, "Unknown group ID: #{group_identifier}" unless group
    else
      group = data_group(group_identifier)
      raise ArgumentError, "Unknown group: #{group_identifier}" if group.db_symbol == :__undef__
    end

    raise ArgumentError, "Group #{group_identifier} has no encounters" if group.encounters.empty?

    return group
  end

  # Resolve encounter form: -1 becomes 0, others stay as-is
  # @param encounter [Studio::Group::Encounter]
  # @return [Integer]
  def resolve_encounter_form(encounter)
    return encounter.form == -1 ? 0 : encounter.form
  end

  # Filter encounters to keep only those whose resolved CreatureForm is in the given array
  # @param encounters [Array<Studio::Group::Encounter>]
  # @param creature_forms [Array<Studio::CreatureForm>, nil]
  # @return [Array<Studio::Group::Encounter>]
  def filter_eligible_encounters(encounters, creature_forms)
    return encounters if creature_forms.nil?

    return encounters.filter do |encounter|
      resolved_form = resolve_encounter_form(encounter)
      next creature_forms.any? { |creature_form| creature_form.db_symbol == encounter.specie && creature_form.form == resolved_form }
    end
  end

  # Select a random encounter using weighted cumulative selection by encounter_rate
  # @param eligible_encounters [Array<Studio::Group::Encounter>]
  # @return [Studio::Group::Encounter]
  def weighted_random_encounter(eligible_encounters)
    total_weight = eligible_encounters.sum(&:encounter_rate)
    random_value = rand(total_weight)
    cumulative_weight = 0

    return eligible_encounters.find do |encounter|
      cumulative_weight += encounter.encounter_rate
      next cumulative_weight > random_value
    end
  end
end

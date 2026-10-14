class CreatureGenerator
  # Generates all legendary creature forms available in the database, excluding mega evolutions
  # @return [Array<Studio::CreatureForm>]
  def generate_all_legendary_creature_forms
    return generate_all_creature_forms_by_category(LEGENDARY_CREATURE_DB_SYMBOL)
  end
  alias all_legendary generate_all_legendary_creature_forms

  # Generates a random legendary creature form available in the database
  # @return [Studio::CreatureForm]
  def generate_random_legendary_creature_form
    return generate_random_creature_form_by_category(LEGENDARY_CREATURE_DB_SYMBOL)
  end
  alias random_legendary generate_random_legendary_creature_form

  # Generates all mythical creature forms available in the database, excluding mega evolutions
  # @return [Array<Studio::CreatureForm>]
  def generate_all_mythical_creature_forms
    return generate_all_creature_forms_by_category(MYTHICAL_CREATURE_DB_SYMBOL)
  end
  alias all_mythical generate_all_mythical_creature_forms

  # Generates a random mythical creature form available in the database
  # @return [Studio::CreatureForm]
  def generate_random_mythical_creature_form
    return generate_random_creature_form_by_category(MYTHICAL_CREATURE_DB_SYMBOL)
  end
  alias random_mythical generate_random_mythical_creature_form

  # Generates all ultra beast creature forms available in the database, excluding mega evolutions
  # @return [Array<Studio::CreatureForm>]
  def generate_all_ultra_beast_creature_forms
    return generate_all_creature_forms_by_category(ULTRA_BEAST_CREATURE_DB_SYMBOL)
  end
  alias all_ultra_beast generate_all_ultra_beast_creature_forms

  # Generates a random ultra beast creature form available in the database
  # @return [Studio::CreatureForm]
  def generate_random_ultra_beast_creature_form
    return generate_random_creature_form_by_category(ULTRA_BEAST_CREATURE_DB_SYMBOL)
  end
  alias random_ultra_beast generate_random_ultra_beast_creature_form

  # Generates all pseudo legendary creature forms available in the database, excluding mega evolutions
  # @return [Array<Studio::CreatureForm>]
  def generate_all_pseudo_legendary_creature_forms
    return generate_all_creature_forms_by_category(PSEUDO_LEGENDARY_CREATURE_DB_SYMBOL)
  end
  alias all_pseudo_legendary generate_all_pseudo_legendary_creature_forms

  # Generates a random pseudo legendary creature form available in the database
  # @return [Studio::CreatureForm]
  def generate_random_pseudo_legendary_creature_form
    return generate_random_creature_form_by_category(PSEUDO_LEGENDARY_CREATURE_DB_SYMBOL)
  end
  alias random_pseudo_legendary generate_random_pseudo_legendary_creature_form

  # Generates all baby creature forms available in the database, excluding mega evolutions
  # @return [Array<Studio::CreatureForm>]
  def generate_all_baby_creature_forms
    return generate_all_creature_forms_by_category(BABY_CREATURE_DB_SYMBOL)
  end
  alias all_baby generate_all_baby_creature_forms

  # Generates a random baby creature form available in the database
  # @return [Studio::CreatureForm]
  def generate_random_baby_creature_form
    return generate_random_creature_form_by_category(BABY_CREATURE_DB_SYMBOL)
  end
  alias random_baby generate_random_baby_creature_form

  private

  # Generates all creature forms for a given category of database symbols
  # @param category_symbols [Array<Symbol>] The list of database symbols for the category
  # @return [Array<Studio::CreatureForm>]
  def generate_all_creature_forms_by_category(category_symbols)
    return available_db_symbols(category_symbols)
  end

  # Generates a random creature form for a given category of database symbols
  # @param category_symbols [Array<Symbol>] The list of database symbols for the category
  # @return [Studio::CreatureForm]
  def generate_random_creature_form_by_category(category_symbols)
    creature_form = available_db_symbols(category_symbols).sample
    log_data("Generated random creature form: #{creature_form.name} (Form: #{creature_form.form})")
    return creature_form
  end
end

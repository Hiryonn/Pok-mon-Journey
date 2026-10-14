class CreatureGenerator
  private

  # This function checks whether this form of the creature is legendary
  # @param creature_form [Studio::CreatureForm]
  # @return [Boolean]
  def legendary?(creature_form)
    return LEGENDARY_CREATURE_DB_SYMBOL.include?(creature_form.db_symbol)
  end

  # This function checks whether this form of the creature is mythical
  # @param creature_form [Studio::CreatureForm]
  # @return [Boolean]
  def mythical?(creature_form)
    return MYTHICAL_CREATURE_DB_SYMBOL.include?(creature_form.db_symbol)
  end

  # This function checks whether this form of the creature is an ultra beast
  # @param creature_form [Studio::CreatureForm]
  # @return [Boolean]
  def ultra_beast?(creature_form)
    return ULTRA_BEAST_CREATURE_DB_SYMBOL.include?(creature_form.db_symbol)
  end

  # This function checks whether this form of the creature is pseudo legendary
  # @param creature_form [Studio::CreatureForm]
  # @return [Boolean]
  def pseudo_legendary?(creature_form)
    return PSEUDO_LEGENDARY_CREATURE_DB_SYMBOL.include?(creature_form.db_symbol)
  end

  # This function checks whether this form of the creature is baby
  # @param creature_form [Studio::CreatureForm]
  # @return [Boolean]
  def baby?(creature_form)
    return BABY_CREATURE_DB_SYMBOL.include?(creature_form.db_symbol)
  end

  # This function checks whether this form of the creature can evolve into valid forms
  # @param creature_form [Studio::CreatureForm]
  # @return [Boolean]
  def valid_evolutions?(creature_form)
    return creature_form.evolutions.any? do |evolution|
      next false if mega_evolution?(evolution.form)
      next false if gigantamax?(evolution.form)

      next true
    end
  end

  # Checks whether the given form corresponds to a Mega Evolution
  # @param form [Integer]
  # @return [Boolean]
  def mega_evolution?(form)
    return (30..39).include?(form)
  end

  # Checks whether the given form corresponds to a Gigantamax form
  # @param form [Integer]
  # @return [Boolean]
  def gigantamax?(form)
    return (40..49).include?(form)
  end

  # Checks whether this creature is on the first stage of its evolution line
  # @param creature_form [Studio::CreatureForm]
  # @return [Boolean]
  def first_stage?(creature_form)
    return false unless creature_form.db_symbol == creature_form.baby_db_symbol
    return false unless valid_evolutions?(creature_form)

    return true
  end

  # Checks whether this creature is on the middle stage of its evolution line
  # @param creature_form [Studio::CreatureForm]
  # @return [Boolean]
  def middle_stage?(creature_form)
    return false if creature_form.db_symbol == creature_form.baby_db_symbol
    return false unless valid_evolutions?(creature_form)

    return true
  end

  # Checks whether this creature is on the third stage of its evolution line
  # @param creature_form [Studio::CreatureForm]
  # @return [Boolean]
  def third_stage?(creature_form)
    return false if creature_form.db_symbol == creature_form.baby_db_symbol
    return false if valid_evolutions?(creature_form)

    baby_creature_form = data_creature_form(creature_form.baby_db_symbol, creature_form.baby_form)
    return false if baby_creature_form.evolutions.any? { |evolution| evolution.db_symbol == creature_form.db_symbol }

    return true
  end

  # Checks whether this creature is on the last stage of its evolution line
  # @param creature_form [Studio::CreatureForm]
  # @return [Boolean]
  def last_stage?(creature_form)
    return false if creature_form.db_symbol == creature_form.baby_db_symbol
    return false if valid_evolutions?(creature_form)

    return true
  end

  # Checks whether this creature has no evolution line (standalone)
  # @param creature_form [Studio::CreatureForm]
  # @return [Boolean]
  def single_stage?(creature_form)
    return false unless creature_form.db_symbol == creature_form.baby_db_symbol
    return false if valid_evolutions?(creature_form)

    return true
  end

  # Returns the length of the evolution chain this creature belongs to
  # @param creature_form [Studio::CreatureForm]
  # @return [Integer]
  def chain_length(creature_form)
    base = data_creature_form(creature_form.baby_db_symbol, creature_form.baby_form)
    return max_depth(base)
  end

  # Recursively computes the maximum depth from a given creature form
  # @param creature_form [Studio::CreatureForm]
  # @return [Integer]
  def max_depth(creature_form)
    valid_evos = creature_form.evolutions.reject { |evolution| mega_evolution?(evolution.form) || gigantamax?(evolution.form) }
    return 1 if valid_evos.empty?

    deepest = valid_evos.map { |evolution| max_depth(data_creature_form(evolution.db_symbol, evolution.form)) }.max
    return 1 + deepest
  end

end

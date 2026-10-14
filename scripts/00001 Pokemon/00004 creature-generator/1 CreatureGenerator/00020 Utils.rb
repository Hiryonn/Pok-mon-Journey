class CreatureGenerator
  private

  # Returns all creature forms whose db_symbol is included in the given list
  # @param symbols [Array<Symbol>] The list of database symbols to match
  # @return [Array<Studio::CreatureForm>]
  def available_db_symbols(symbols)
    # @type [Array<Studio::CreatureForm>]
    all_creature_forms = []

    each_data_creature_form do |creature_form|
      next if symbols.none?(creature_form.db_symbol)
      next if mega_evolution?(creature_form.form)
      next if gigantamax?(creature_form.form)

      all_creature_forms << creature_form
    end

    raise ArgumentError, 'No creature forms found' if all_creature_forms.empty?

    log_data("Generated #{all_creature_forms.size} creature forms.")
    return all_creature_forms
  end

  # Checks if the provided array contains only valid Studio::CreatureForm instances
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @return [Boolean]
  def valid_creature_forms_array?(all_creature_forms)
    return false unless all_creature_forms.is_a?(Array)
    return false if all_creature_forms.empty?
    return false if all_creature_forms.any? { |form| !form.is_a?(Studio::CreatureForm) }

    return true
  end

  # Filters creature forms based on a stat comparison using a given block
  # @param amount [Integer] The reference value for comparison
  # @param second_amount [Integer, nil] The upper bound for :between comparison
  # @param comparison_type [Symbol] The comparison type (:equal, :lte, :gte, :between)
  # @param all_creature_forms [Array<Studio::CreatureForm>]
  # @param block [Proc] A block that returns the stat value to compare
  # @return [Array<Studio::CreatureForm>]
  def filter_creature_forms_by_stat(amount, second_amount, comparison_type, all_creature_forms, &block)
    raise ArgumentError, "Invalid amount: #{amount}" unless amount.is_a?(Integer) && amount.positive?
    raise ArgumentError, 'Second amount must be provided for :between comparison' if comparison_type == :between && (!second_amount.is_a?(Integer) || second_amount.nil? || second_amount <= amount)

    valid_comparisons = %i[equal lte gte between]
    raise ArgumentError, "Invalid comparison type: #{comparison_type}" unless valid_comparisons.include?(comparison_type)
    raise ArgumentError, 'Invalid all_creature_forms' unless valid_creature_forms_array?(all_creature_forms)

    all_creature_forms = all_creature_forms.filter do |creature_form|
      # @type [Integer]
      stat_value = block.call(creature_form)
      compare_value(stat_value, amount, second_amount, comparison_type)
    end

    raise ArgumentError, "No creature forms found with stats #{comparison_type} #{amount}" if all_creature_forms.empty?

    log_data "Generated #{all_creature_forms.size} creature forms with stats #{comparison_type} #{amount}#{", #{second_amount}" if second_amount}"
    return all_creature_forms
  end

  # Performs a value comparison based on the specified comparison type
  # @param value [Integer] The actual value to compare
  # @param amount [Integer] The reference value for comparison
  # @param second_amount [Integer, nil] The upper bound for :between comparison
  # @param comparison_type [Symbol] The comparison type (:equal, :lte, :gte, :between)
  # @return [Boolean]
  def compare_value(value, amount, second_amount, comparison_type)
    case comparison_type
    when :equal
      return value == amount
    when :lte
      return value <= amount
    when :gte
      return value >= amount
    when :between
      return (amount..second_amount).include?(value)
    else
      raise ArgumentError, "Invalid comparison type: #{comparison_type}"
    end
  end
end

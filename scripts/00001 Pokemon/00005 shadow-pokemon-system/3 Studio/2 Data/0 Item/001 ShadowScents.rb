module PFM
  # Scents of the plugin, and how much of a Joy Scent each one is worth.
  module ShadowScents
    # Multiplier each scent applies to the amount a Joy Scent opens.
    # @return [Hash{ Symbol => Integer }]
    MULTIPLIERS = {
      joy_scent: 1,
      excite_scent: 2,
      vivid_scent: 3
    }

    module_function

    # Use a scent on a creature and tell the player what it did.
    # @param creature [PFM::Pokemon]
    # @param scene [GamePlay::Base, Battle::Scene]
    # @param multiplier [Integer] how many times a Joy Scent the scent is worth
    def use_on(creature, scene, multiplier)
      was_unstable = creature.unstable?
      creature.use_scent(multiplier)
      scene.display_message_and_wait(ShadowTexts.message(was_unstable ? :scent_soothed : :scent_opened))
    end
  end
end

# The item descriptor is looked up by db_symbol first and only falls back on the item class, so
# registering the scents by their own db_symbol leaves every ordinary item of the game untouched.
PFM::ShadowScents::MULTIPLIERS.each do |db_symbol, multiplier|
  PFM::ItemDescriptor.define_on_creature_usability(db_symbol) do |_item, creature|
    next creature.shadow?
  end

  PFM::ItemDescriptor.define_on_creature_use(db_symbol) do |_item, creature, scene|
    next PFM::ShadowScents.use_on(creature, scene, multiplier)
  end

  PFM::ItemDescriptor.define_on_creature_battler_use(db_symbol) do |_item, creature, scene|
    next PFM::ShadowScents.use_on(creature, scene, multiplier)
  end
end

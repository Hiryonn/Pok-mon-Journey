class Interpreter
  # Create a new instance of CreatureGenerator with specified rules
  # @param allow_legendary [Boolean] Whether to allow legendary creatures (default: false)
  # @param allow_mythical [Boolean] Whether to allow mythical creatures (default: false)
  # @param allow_ultra_beast [Boolean] Whether to allow ultra beasts (default: false)
  # @param allow_pseudo_legendary [Boolean] Whether to allow pseudo legendary creatures (default: false)
  # @param allow_baby [Boolean] Whether to allow baby creatures (default: false)
  # @return [CreatureGenerator]
  def create_creature_generator_instance(allow_legendary: false, allow_mythical: false, allow_ultra_beast: false, allow_pseudo_legendary: false,
                                         allow_baby: false)
    CreatureGenerator.new(allow_legendary: allow_legendary, allow_mythical: allow_mythical, allow_ultra_beast: allow_ultra_beast,
                          allow_pseudo_legendary: allow_pseudo_legendary, allow_baby: allow_baby)
  end
end

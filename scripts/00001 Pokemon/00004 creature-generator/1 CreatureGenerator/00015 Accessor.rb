module Kernel
  # Iterate through all creature forms of all creatures
  # @yieldparam creature_form [Studio::CreatureForm]
  # @return [Enumerator<Studio::CreatureForm>]
  def each_data_creature_form(&block)
    return each_data_creature.flat_map(&:forms).each(&block)
  end
end

# Tight Grip (tight_grip)
# Extends the duration of the Pokémon's binding moves.
# Ses capacités de piégeage durent 2 tours de plus.
ExtraAbilitiesAdditions.define(:tight_grip) do
  def on_post_action_event(_logic, _scene, battlers)
    ea_safe('Tight Grip') do
      @extended ||= []
      battlers.each do |pokemon|
        next if pokemon.bank == @target.bank

        pokemon.effects.get_all { |e| e.is_a?(Battle::Effects::Bind) && e.origin == @target }.each do |effect|
          next if @extended.include?(effect.object_id)

          @extended << effect.object_id
          effect.counter = effect.instance_variable_get(:@counter).to_i + 2
        end
      end
    end
  end
end

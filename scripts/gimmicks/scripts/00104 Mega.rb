# Gimmicks : Méga-Évolution (celle de PSDK, avec les règles communes et la cinématique)
module Gimmicks
  module Mega
    module_function

    # @param battler [PFM::PokemonBattler]
    # @param logic [Battle::Logic]
    def possible?(battler, logic)
      return logic.mega_evolve.can_pokemon_mega_evolve?(battler)
    end

    # La Méga-Évolution passe par l'action de PSDK (Battle::Actions::Mega)
    def execute(scene, battler, _action)
      Battle::Actions::Mega.new(scene, battler).execute
    end
  end
  register(:mega, Mega)
end

module Battle
  class Visual
    module PJGimmicksMega
      # Cinématique : PSDK a déjà changé la forme, on montre l'ancienne puis la nouvelle au flash
      # @param target [PFM::PokemonBattler]
      def show_mega_animation(target)
        return super unless Gimmicks.cinematic?

        mega_form = target.form
        base_form = target.instance_variable_get(:@mega_evolved)
        target.instance_variable_set(:@form, base_form) if base_form.is_a?(Integer)
        Gimmicks::Cinematic.new(@scene, target).play(:mega) { target.instance_variable_set(:@form, mega_form) }
      ensure
        target.instance_variable_set(:@form, mega_form) if mega_form
      end
    end
    prepend PJGimmicksMega
  end
end

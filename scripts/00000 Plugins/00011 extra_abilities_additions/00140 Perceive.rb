# Perceive (perceive)
# Removes and prevents any field effects except for weather. It prevents the use of Transform and Illusion as well.
# Supprime et empêche tout effet de terrain (hors météo). Bloque aussi Morphing (Transform) et Imposteur ; Illusion n'est bloqué que si sa classe existe.
ExtraAbilitiesAdditions.define(:perceive) do
  def on_switch_event(handler, _who, with)
    ea_safe('Perceive') do
      next if with != @target

      ea_show(handler.scene, @target)
      logic = handler.logic
      ExtraAbilitiesAdditions.clear_effects(logic, ExtraAbilitiesAdditions::HAZARDS + ExtraAbilitiesAdditions::SCREENS + ExtraAbilitiesAdditions::FIELD_EFFECTS)
      logic.fterrain_change_handler.fterrain_change_with_process(:none) unless logic.field_terrain == :none
    end
  end

  def on_fterrain_prevention(handler, fterrain_type, _last_fterrain)
    ea_safe('Perceive') { next(fterrain_type == :none ? nil : ea_prevent(handler)) }
  end
end

# Blocage de Transform / Imposter / Illusion tant qu'un Pokémon avec Perceive est au combat.
module ExtraAbilitiesAdditions
  module PerceiveGuard
    def self.active?(logic)
      return logic.any_field_ability_active?(:perceive)
    rescue StandardError
      return false
    end

    module TransformMove
      def move_usable_by_user(user, targets)
        if PerceiveGuard.active?(@logic)
          show_usage_failure(user)
          return false
        end
        return super
      end
    end

    module ImposterGuard
      def on_switch_event(handler, who, with)
        return if PerceiveGuard.active?(handler.logic)

        return super
      end
    end

    module IllusionGuard
      def on_switch_event(handler, who, with)
        return if PerceiveGuard.active?(handler.logic)

        return super
      end
    end
  end
end

begin
  Battle::Move::Transform.prepend(ExtraAbilitiesAdditions::PerceiveGuard::TransformMove) if defined?(Battle::Move::Transform)
  imposter = Battle::Effects::Ability.const_get(:Imposter) if Battle::Effects::Ability.const_defined?(:Imposter)
  imposter&.prepend(ExtraAbilitiesAdditions::PerceiveGuard::ImposterGuard)
  illusion = Battle::Effects::Ability.const_get(:Illusion) if Battle::Effects::Ability.const_defined?(:Illusion)
  illusion&.prepend(ExtraAbilitiesAdditions::PerceiveGuard::IllusionGuard)
rescue StandardError => e
  ExtraAbilitiesAdditions.log_error('Perceive guard', e)
end

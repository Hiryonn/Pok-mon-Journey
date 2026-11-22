# Clairvoyance (clairvoyance)
# The Pokémon's attacks happen the turn they are selected.
# Capacités à préparation lancées tout de suite ; Prescience/Carnar : l'attaque frappe dès la fin du tour (compte à rebours = 1).
ExtraAbilitiesAdditions.define(:clairvoyance) do
  def on_two_turn_shortcut(user, _targets, _skill)
    return user == @target
  end
end

module ExtraAbilitiesAdditions
  module ClairvoyanceDelayed
    def deal_effect(user, actual_targets)
      result = super
      begin
        if user.has_ability?(:clairvoyance)
          actual_targets.each do |t|
            eff = @logic.position_effects[t.bank][t.position]
            eff = eff.get_all { |e| e.is_a?(Battle::Effects::FutureSight) } if eff.respond_to?(:get_all)
            Array(eff).each { |e| e.counter = 1 if e.respond_to?(:counter=) && e.origin == user }
          end
        end
      rescue StandardError => e
        ExtraAbilitiesAdditions.log_error('Clairvoyance delayed', e)
      end
      return result
    end
  end
end

begin
  Battle::Move::FutureSight.prepend(ExtraAbilitiesAdditions::ClairvoyanceDelayed) if defined?(Battle::Move::FutureSight)
rescue StandardError => e
  ExtraAbilitiesAdditions.log_error('Clairvoyance prepend', e)
end

# Bonus d'overkill : un coup qui dépasse largement les PV restants de la cible rapporte plus à son lanceur.
#  - expérience : le Pokémon qui a porté le coup gagne overkill_exp_percent % de plus à ce K.O.
#  - bonheur : +overkill_loyalty, une fois par Pokémon et par combat
#  - il faut que l'excédent atteigne overkill_threshold % des PV max de la cible (50 par défaut)
# Réglages (Data/configs/plugins/modes_jeu.json) : overkill_enabled, overkill_threshold, overkill_exp_percent,
# overkill_loyalty, overkill_message. Valable dans tous les modes, uniquement quand c'est le joueur qui frappe.
module ModesJeu
  module_function

  def overkill?
    return setting('overkill_enabled') != false
  end
end

module Battle
  class Logic
    class DamageHandler
      module ModesJeuOverkill
        def damage_change(amount, target, launcher = nil, skill = nil, &block)
          before = target.hp
          result = super
          pj_overkill_check(amount.abs, before, target, launcher)
          return result
        rescue StandardError => e
          ModesJeu.log_error("overkill : #{e.message}")
          return result
        end

        private

        def pj_overkill_check(damage, hp_before, target, launcher)
          return unless ModesJeu.overkill? && launcher && launcher.bank == 0 && target.bank != 0
          return unless target.dead? && damage > hp_before

          excess = damage - hp_before
          return if excess * 100 < ModesJeu.setting('overkill_threshold').to_i.clamp(1, 1000) * target.max_hp

          target.instance_variable_set(:@pj_overkill_by, launcher)
          return unless ModesJeu.setting('overkill_message') != false

          @scene.display_message_and_wait(ModesJeu.text(:overkill)) if @scene.respond_to?(:display_message_and_wait)
        end
      end
      prepend ModesJeuOverkill
    end

    class ExpHandler
      module ModesJeuOverkillExp
        def distribute_exp_for(enemy)
          data = super
          killer = enemy.instance_variable_get(:@pj_overkill_by)
          return data unless killer && ModesJeu.overkill?

          percent = ModesJeu.setting('overkill_exp_percent').to_i
          data[killer] = data[killer] * (100 + percent) / 100 if data.key?(killer) && percent > 0
          loyalty = ModesJeu.setting('overkill_loyalty').to_i
          if loyalty > 0 && !killer.instance_variable_get(:@pj_overkill_loyal)
            killer.instance_variable_set(:@pj_overkill_loyal, true)
            killer.original.loyalty = [killer.original.loyalty + loyalty, 255].min if killer.original.respond_to?(:loyalty=)
          end
          return data
        rescue StandardError => e
          ModesJeu.log_error("overkill exp : #{e.message}")
          return data
        end
      end
      prepend ModesJeuOverkillExp
    end
  end
end

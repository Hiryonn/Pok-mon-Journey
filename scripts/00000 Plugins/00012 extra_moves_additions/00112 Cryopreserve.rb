# Cryopreserve (s_extra_cryopreserve) : n'est utilisable que si la cible peut être soignée (PV < PV max) ; elle perd son statut
# (comme Repos), regagne tous ses PV puis est gelée.
module Battle
  class Move
    class ExtraCryopreserve < Move
      private

      def move_usable_by_user(user, targets)
        return false unless super

        return show_usage_failure(user) && false if targets.none? { |t| t.hp < t.max_hp }

        return true
      end

      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.dead? || target.hp >= target.max_hp

          status_handler = @logic.status_change_handler
          status_handler.status_change(:cure, target) if target.status?
          @logic.damage_handler.heal(target, target.max_hp - target.hp)
          status_handler.status_change_with_process(:freeze, target, user, self)
        end
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Cryopreserve', e)
      end
    end
    Move.register(:s_extra_cryopreserve, ExtraCryopreserve)
  end
end

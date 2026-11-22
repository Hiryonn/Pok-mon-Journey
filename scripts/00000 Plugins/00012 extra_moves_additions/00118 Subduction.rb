# Subduction (s_extra_subduction) : le séisme est si violent que le lanceur devient confus.
module Battle
  class Move
    class ExtraSubduction < Basic
      def deal_effect(user, actual_targets)
        super
        confuse_user(user)
      end

      private

      def confuse_user(user)
        return if user.dead? || user.confused?

        @logic.status_change_handler.status_change_with_process(:confusion, user, user, self)
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Subduction', e)
      end
    end
    Move.register(:s_extra_subduction, ExtraSubduction)
  end
end

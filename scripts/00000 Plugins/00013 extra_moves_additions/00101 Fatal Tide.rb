# Fatal Tide (s_extra_fatal_tide) : dégâts, puis Anti-Soin (5 tours) sur les adversaires touchés : plus de soins par capacités,
# talents ni objets.
module Battle
  class Move
    class ExtraFatalTide < Basic
      HEAL_BLOCK_TURNS = 5

      private

      def deal_effect(user, actual_targets)
        super
        actual_targets.each do |target|
          next if target.dead? || !defined?(Battle::Effects::HealBlock) || target.effects.has?(:heal_block)

          target.effects.add(Battle::Effects::HealBlock.new(@logic, target, HEAL_BLOCK_TURNS))
        end
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Fatal Tide', e)
      end
    end
    Move.register(:s_extra_fatal_tide, ExtraFatalTide)
  end
end

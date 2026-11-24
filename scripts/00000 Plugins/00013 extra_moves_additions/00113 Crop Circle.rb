# Crop Circle (s_extra_crop_circle) : Atq. Spé., Déf. Spé. et Vitesse +1 pour tous les Pokémon de type Plante sur le terrain.
module Battle
  class Move
    class ExtraCropCircle < Move
      STATS = %i[ats dfs spd].freeze

      private

      def deal_effect(user, actual_targets)
        @logic.all_alive_battlers.each do |battler|
          next unless battler.type_grass?

          STATS.each { |stat| @logic.stat_change_handler.stat_change_with_process(stat, 1, battler, user, self) }
        end
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Crop Circle', e)
      end
    end
    Move.register(:s_extra_crop_circle, ExtraCropCircle)
  end
end

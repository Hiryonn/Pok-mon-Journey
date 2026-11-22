# Infernal Blade (s_extra_infernal_blade) : toujours super efficace contre le type Fée (la brûlure à 30 % se règle sous Studio).
module Battle
  class Move
    class ExtraInfernalBlade < Basic
      private

      def calc_type_n_multiplier(target, type_to_check, types)
        if target.send(type_to_check) == data_type(:fairy).id
          @effectiveness *= 2 if @effectiveness >= 0
          return 2
        end

        return super
      end
    end
    Move.register(:s_extra_infernal_blade, ExtraInfernalBlade)
  end
end

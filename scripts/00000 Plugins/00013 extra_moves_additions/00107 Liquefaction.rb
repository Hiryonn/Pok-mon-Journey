# Liquefaction (s_extra_liquefaction) : super efficace contre le type Sol.
module Battle
  class Move
    class ExtraLiquefaction < Basic
      private

      def calc_type_n_multiplier(target, type_to_check, types)
        if target.send(type_to_check) == data_type(:ground).id
          @effectiveness *= 2 if @effectiveness >= 0
          return 2
        end

        return super
      end
    end
    Move.register(:s_extra_liquefaction, ExtraLiquefaction)
  end
end

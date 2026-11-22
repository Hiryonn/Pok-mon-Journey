# Vaporize (s_extra_vaporize) : super efficace contre le type Eau (au lieu de « peu efficace »).
module Battle
  class Move
    class ExtraVaporize < Basic
      private

      def calc_type_n_multiplier(target, type_to_check, types)
        if target.send(type_to_check) == data_type(:water).id
          @effectiveness *= 2 if @effectiveness >= 0
          return 2
        end

        return super
      end
    end
    Move.register(:s_extra_vaporize, ExtraVaporize)
  end
end

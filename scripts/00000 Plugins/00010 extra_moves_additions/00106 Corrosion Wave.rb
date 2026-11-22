# Corrosion Wave (s_extra_corrosion_wave) : super efficace contre le type Acier.
module Battle
  class Move
    class ExtraCorrosionWave < Basic
      private

      def calc_type_n_multiplier(target, type_to_check, types)
        if target.send(type_to_check) == data_type(:steel).id
          @effectiveness *= 2 if @effectiveness >= 0
          return 2
        end

        return super
      end
    end
    Move.register(:s_extra_corrosion_wave, ExtraCorrosionWave)
  end
end

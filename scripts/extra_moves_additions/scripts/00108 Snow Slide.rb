# Snow Slide (s_extra_snow_slide) : puissance doublée sous la neige / la grêle.
module Battle
  class Move
    class ExtraSnowSlide < Basic
      SNOW = %i[hail snow].freeze

      def real_base_power(user, target)
        power = super
        weather = ExtraMovesAdditions.weather(@logic)
        return SNOW.include?(weather) ? power * 2 : power
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Snow Slide', e)
        return super
      end
    end
    Move.register(:s_extra_snow_slide, ExtraSnowSlide)
  end
end

# Setting Sun (s_extra_setting_sun) : utilisable seulement sous un soleil extrême, qu'elle fait cesser.
module Battle
  class Move
    class ExtraSettingSun < Basic
      HARSH_SUN = %i[hardsun harsh_sun].freeze

      private

      def move_usable_by_user(user, targets)
        return false unless super

        weather = ExtraMovesAdditions.weather(@logic)
        return show_usage_failure(user) && false unless HARSH_SUN.include?(weather)

        return true
      end

      def deal_effect(user, actual_targets)
        super
        @logic.weather_change_handler.weather_change(:none, 0)
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Setting Sun', e)
      end
    end
    Move.register(:s_extra_setting_sun, ExtraSettingSun)
  end
end

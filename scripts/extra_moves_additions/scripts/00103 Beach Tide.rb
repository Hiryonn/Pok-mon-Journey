# Beach Tide (s_extra_beach_tide) : renforcée de 50 % sous le soleil au lieu d'être affaiblie.
# PSDK applique déjà ×0,5 à cette capacité sous la météo opposée : on triple la puissance dans ce cas pour obtenir ×1,5.
module Battle
  class Move
    class ExtraBeachTide < Basic
      WEATHERS = %i[sunny hardsun].freeze

      def real_base_power(user, target)
        power = super
        weather = @logic.respond_to?(:current_weather) ? @logic.current_weather : nil
        return WEATHERS.include?(weather) ? power * 3 : power
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Beach Tide', e)
        return super
      end
    end
    Move.register(:s_extra_beach_tide, ExtraBeachTide)
  end
end

# Oil Fire (s_extra_oil_fire) : renforcée de 50 % sous la pluie au lieu d'être affaiblie.
# PSDK applique déjà ×0,5 à cette capacité sous la météo opposée : on triple la puissance dans ce cas pour obtenir ×1,5.
module Battle
  class Move
    class ExtraOilFire < Basic
      WEATHERS = %i[rain hardrain].freeze

      def real_base_power(user, target)
        power = super
        weather = ExtraMovesAdditions.weather(@logic)
        return WEATHERS.include?(weather) ? power * 3 : power
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Oil Fire', e)
        return super
      end
    end
    Move.register(:s_extra_oil_fire, ExtraOilFire)
  end
end

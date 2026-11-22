# Love Lariat (s_extra_love_lariat) : dégâts massifs (puissance ×2) contre une cible amoureuse (Attraction).
module Battle
  class Move
    class ExtraLoveLariat < Basic
      def real_base_power(user, target)
        power = super
        return target.effects.has?(:attract) ? power * 2 : power
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Love Lariat', e)
        return super
      end
    end
    Move.register(:s_extra_love_lariat, ExtraLoveLariat)
  end
end

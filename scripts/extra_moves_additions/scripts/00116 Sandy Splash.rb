# Sandy Splash (s_extra_sandy_splash) : capacité de type Eau ET Sol en même temps (efficacité multipliée par celle du Sol).
module Battle
  class Move
    class ExtraSandySplash < Basic
      private

      def definitive_types(user, target)
        types = super
        ground = data_type(:ground)
        return types.include?(ground) ? types : types + [ground]
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Sandy Splash', e)
        return super
      end
    end
    Move.register(:s_extra_sandy_splash, ExtraSandySplash)
  end
end

# Laser Pulse (s_extra_laser_pulse) : le type est tiré au hasard entre Feu, Électrik et Glace, une fois par utilisation.
module Battle
  class Move
    class ExtraLaserPulse < Basic
      TYPES = %i[fire electric ice].freeze

      def proceed_internal(user, targets)
        @extra_laser_type = TYPES.sample
        return super
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Laser Pulse', e)
        return super
      end

      private

      def definitive_types(user, target)
        return [data_type(@extra_laser_type || TYPES.first)]
      rescue StandardError => e
        ExtraMovesAdditions.log_error('Laser Pulse', e)
        return super
      end
    end
    Move.register(:s_extra_laser_pulse, ExtraLaserPulse)
  end
end

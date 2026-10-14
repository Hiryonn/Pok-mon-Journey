module Studio
  # Data class describing a type
  class Type
    # Module to process type effectiveness in Inverse Battle
    module TypeInverseBattleProcessing
      def hit(other_type)
        factor = damage_to.find { |damage| damage.defensive_type == other_type }&.factor || 1
        factor = 1.0 / (factor == 0 ? 0.5 : factor) if $game_switches[Yuki::Sw::BT_Inverse]
        return factor
      end
    end
  end
end

Studio::Type.prepend(Studio::Type::TypeInverseBattleProcessing)

module Battle
    class Move
          class TwoTurnBase
              private
              CAN_HIT_BY_TYPE = [%i[spikes toxic_spikes stealth_rock smouldering_embers], %i[earthquake fissure magnitude spikes toxic_spikes stealth_rock smouldering_embers], %i[gust gravity whirlwind thunder swift sky_uppercut twister smack_down hurricane thousand_arrows spikes toxic_spikes stealth_rock smouldering_embers], %i[surf whirlpool spikes toxic_spikes stealth_rock smouldering_embers], nil]
          end
    end
end
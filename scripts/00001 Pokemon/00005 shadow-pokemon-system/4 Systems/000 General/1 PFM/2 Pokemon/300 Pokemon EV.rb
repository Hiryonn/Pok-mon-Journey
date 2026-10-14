module PFM
  class Pokemon
    module PokemonShadowEVPatch
      # Add ev bonus to a Pokemon
      # @param list [Array<Integer>] an ev list  : [hp, atk, dfe, spd, ats, dfs]
      # @return [Boolean, nil] if the ev had totally been added or not (nil = couldn't be added at all)
      def add_bonus(list)
        return super unless shadow?

        hold_effort_values(ShadowState::EV_STATS.zip(list).to_h)

        return nil
      end
    end

    prepend PokemonShadowEVPatch
  end
end

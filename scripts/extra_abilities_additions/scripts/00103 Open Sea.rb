# Open Sea : les capacités Eau offensives du porteur touchent tous les Pokémon adjacents (adversaires et alliés), comme Surf.
module Battle
  class Move
    module ExtraOpenSeaTargets
      def battler_targets(pokemon, logic)
        list = super
        return list unless pokemon.has_ability?(:open_sea) && !status? && type_water?

        return list | logic.adjacent_foes_of(pokemon) | logic.adjacent_allies_of(pokemon)
      rescue StandardError => e
        ExtraAbilitiesAdditions.log_error('Open Sea', e)
        return super
      end
    end
    prepend ExtraOpenSeaTargets
  end
end

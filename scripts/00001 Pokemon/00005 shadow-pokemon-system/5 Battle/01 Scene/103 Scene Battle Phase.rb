module Battle
  class Scene
    # Hands the snagged creatures over once the battle is over, which is when Pokemon XD gives them.
    module SceneShadowBattleEndPatch
      # Method that perform everything that needs to be performed at battle end (phrases etc...) and gives back the master to Scene_Map
      def battle_end
        hand_snagged_creatures_over
        super
      end
    end

    prepend SceneShadowBattleEndPatch

    private

    # Give the player every creature snagged during the battle, restoring the HP each had before it was emptied to free its place.
    def hand_snagged_creatures_over
      snagged_creatures.each do |battler, ball, hp|
        battler.hp = hp
        give_pokemon_procedure(battler, ball)
      end
      snagged_creatures.clear
    end
  end
end

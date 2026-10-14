module Battle
  class Scene
    # Snagging a Shadow Pokemon from its Trainer keeps the battle going, the creature joining the party only once it is over.
    module SceneShadowSnagPatch
      # Method to caught a Pokémon
      # @param item_wrapper [PFM::ItemDescriptor::Wrapper]
      def caught(item_wrapper)
        target = catch_target
        return super unless logic.battle_info.trainer_battle? && target&.shadow?

        snag(target, item_wrapper.item) if logic.catch_handler.try_to_catch_pokemon(target, logic.alive_battlers(0).first, item_wrapper.item)
        @next_update = :trigger_all_AI
        should_activate_ball_fetch?(item_wrapper)
      end
    end

    prepend SceneShadowSnagPatch

    # Skips the nickname offered after a capture, since a snagged creature is not the player own until it is purified.
    module SceneShadowRenamePatch
      private

      # Rename question and scene
      # @param pkmn [PFM::Pokemon] pokemon that was just caught
      def rename_sequence(pkmn)
        return if pkmn.shadow?

        return super
      end
    end

    prepend SceneShadowRenamePatch

    # Turns the call chosen on the skill choice into the action that takes the whole turn, caught at
    # target_choice since a call has no target to ask for.
    module SceneShadowCallPatch
      private

      # Method that asks the target of the choosen move
      def target_choice
        creature = @visual.called_creature
        return super unless creature

        @player_actions << Actions::Call.new(self, creature)
        @next_update = can_player_make_another_action_choice? ? :player_action_choice : :trigger_all_AI
        @skip_frame = true
      end
    end

    prepend SceneShadowCallPatch

    # Creatures snagged during this battle, waiting for it to end, each with the Ball that took it and the HP it had when it left the field.
    # @return [Array<Array>]
    def snagged_creatures
      @snagged_creatures ||= []
      return @snagged_creatures
    end

    private

    # Take a creature out of the battle the way a knock out does, silently, and keep it aside until the
    # battle is over. Its place is freed by emptying its HP, which is what lets its Trainer send the next one.
    # @param battler [PFM::PokemonBattler] creature that was just snagged
    # @param ball [Studio::BallItem]
    def snag(battler, ball)
      snagged_creatures << [battler, ball, battler.hp]
      logic.battle_info.caught_pokemon = battler
      battler.hp = 0
      visual.show_snag(battler)
      # The engine fills its switch requests from the creatures that died during the turn, which it
      # reads from last_battle_turn, a stamp only refreshed on the ones still alive. A creature
      # emptied before the turn counter runs is never seen dying, so the request is filed here.
      logic.switch_request << { who: battler }
    end
  end
end

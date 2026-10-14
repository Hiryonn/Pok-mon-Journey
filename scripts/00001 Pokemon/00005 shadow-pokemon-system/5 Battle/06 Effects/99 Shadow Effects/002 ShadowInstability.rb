module Battle
  module Effects
    # Effect watching a Shadow Pokemon lose control after it attacks, and hurting it every turn
    # while it has. It holds no rule of its own, the odds and the state both live on the creature.
    class ShadowInstability < Shadow
      # Fraction of its max HP an unstable Pokemon loses every turn.
      # @return [Integer]
      DAMAGE_FACTOR = 16

      # Function giving the name of the effect
      # @return [Symbol]
      def name
        return :shadow_instability
      end

      # Function called at the end of an action
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_post_action_event(logic, scene, battlers)
        return unless battlers.include?(@target)
        return unless watched?
        return if @target.unstable?
        return unless logic.generic_rng.rand < @target.instability_chance

        @target.destabilize
        scene.display_message_and_wait(PFM::ShadowTexts.creature_message(:reverse_mode_entered, @target))
      end

      # Function called after damages were applied and when target died (post_damage_death)
      # @param handler [Battle::Logic::DamageHandler]
      # @param hp [Integer] number of hp (damage) dealt
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      def on_post_damage_death(handler, hp, target, launcher, skill)
        return unless target == @target

        @target.regain_control
      end

      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        return unless battlers.include?(@target)
        return unless @target.unstable?
        return if @target.dead?

        scene.display_message_and_wait(PFM::ShadowTexts.creature_message(:reverse_mode_damage, @target))
        # The fraction is taken rounded down, then shifted by one point either way at random.
        damage = @target.max_hp / DAMAGE_FACTOR + logic.generic_rng.rand(-1..1)
        logic.damage_handler.damage_change(damage.clamp(1, Float::INFINITY), @target)
      end
    end

    Shadow::CLASSES << ShadowInstability
  end
end

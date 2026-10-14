module Battle
  class Logic
    module SuddenDeath
      # Function that actually deal the damage
      # @param hp [Integer] number of hp (damage) dealt
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @param messages [Proc] messages shown right before the post processing
      def damage_change(hp, target, launcher = nil, skill = nil, &messages)
        if PFM.game_state.sudden_death.enabled? && target.from_player_party?
          hp = target.max_hp
          log_data('OHKO from Sudden Death Mode.')
        end
        super(hp, target, launcher, skill, &messages)
      end

      # Function that drains a certain quantity of HP from the target and give it to the user
      # @param hp_factor [Integer] the division factor of HP to drain
      # @param target [PFM::PokemonBattler] target that get HP drained
      # @param launcher [PFM::PokemonBattler] launcher of a draining move/effect
      # @param skill [Battle::Move, nil] Potential move used
      # @param hp_overwrite [Integer, nil] for the number of hp drained by the move
      # @param drain_factor [Integer] the division factor of HP drained
      # @param messages [Proc] messages shown right before the post processing
      def drain(hp_factor, target, launcher, skill = nil, hp_overwrite: nil, drain_factor: 1, &messages)
        if PFM.game_state.sudden_death.enabled? && target.from_player_party?
          hp_overwrite = target.max_hp
          log_data('OHKO from Sudden Death Mode.')
        end
        super(hp_factor, target, launcher, skill, hp_overwrite: hp_overwrite, drain_factor: drain_factor, &messages)
      end
    end
  end
end

Battle::Logic::DamageHandler.prepend(Battle::Logic::SuddenDeath)

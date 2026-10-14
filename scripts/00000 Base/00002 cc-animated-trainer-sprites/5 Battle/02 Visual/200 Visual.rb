module Battle
  class Visual
    # Get the sprite of every enemy trainer
    # @note Trainer sprites are stored on negative positions, Pokemon sprites on positive ones
    # @return [Array<BattleUI::TrainerSprite>] empty on a wild battle
    def enemy_trainer_sprites
      battlers = @battlers[1]
      return [] unless battlers

      trainers = battlers.select { |position, _sprite| position.is_a?(Integer) && position.negative? }
      return trainers.values
    end
  end
end

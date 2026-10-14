module Battle
  class Logic
    class CatchHandler
      # Lets a Ball reach a Shadow Pokemon a Trainer owns, which is the only way to get one.
      module CatchHandlerShadowPatch
        # Check if the ball is blocked because the battle is a trainer battle
        # @param target [PFM::PokemonBattler]
        # @param ball [Studio::BallItem]
        # @return [Boolean] if the ball was blocked
        def ball_blocked_for_trainer_battle?(target, ball)
          # The Snag Machine is what turns a Ball into one that reaches a creature someone else owns,
          # so a player who does not carry it steals nothing, whatever the Ball.
          return false if target.shadow? && $bag.contain_item?(:snag_machine)

          return super
        end
      end

      prepend CatchHandlerShadowPatch
    end
  end
end

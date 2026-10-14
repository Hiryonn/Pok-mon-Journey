module Battle
    class Move
        class BoltShooter < MultiHit
           def hit_amount(user, actual_targets)
            number_targets = actual_targets.size
            no_of_hits = 6 / number_targets
            return no_of_hits
           end
           
           def multi_hit?
            return true
          end
        end
        Move.register(:s_bolt_shooter, BoltShooter)
    end
end


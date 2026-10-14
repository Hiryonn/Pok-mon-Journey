module Battle
    class Move
        class AntlerAssult < MultiHit

            def multi_hit?
                return true
            end

            def hit_amount(user, actual_targets)
                return 2
            end

        end
        Move.register(:s_antler_assault, AntlerAssult)
    end
end

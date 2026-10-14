module Battle
    class Move
        class BehemothRush < Basic
            
            def recoil?
                true
            end
            def recoil_factor
                4 || super
            end
        end
        Move.register(:s_behemoth_rush, BehemothRush)
    end
end
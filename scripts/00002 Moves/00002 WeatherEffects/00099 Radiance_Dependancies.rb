module PFM
    class Pokemon
        def type_radiance?
            return type?(data_type(:radiant).id)
        end
    end
end

module Battle
    class Move
        def type_radiance?
            return type?(data_type(:radiant).id)
        end
    end
end

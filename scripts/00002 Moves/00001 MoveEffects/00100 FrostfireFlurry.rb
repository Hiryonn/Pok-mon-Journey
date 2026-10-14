module Battle
    class Move
        class FrostfireFlurry < Basic
            def damages(user, target)
                hp_dealt = super
                hp_dealt *= 4 if target.type_steel?
                @effectiveness = @effectiveness * 4 if target.type_steel?  
                return hp_dealt
            end

        end

        Move.register(:s_frostfire_flurry , FrostfireFlurry)
        
        
    end
end
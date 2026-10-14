module Battle
    class Move
        class CleverCleave < Basic
             private
            def damages(user, target)
                hp_dealt = super
                hp_dealt *= 2 
                hp_dealt *= 2 if target.type_rock? || target.type_steel?
                @effectiveness *= 2 
                @effectiveness *= 2 if target.type_rock? || target.type_steel?
                return hp_dealt
            end

        end
        Move.register(:s_clever_cleave, CleverCleave)
        public
    end
end

        
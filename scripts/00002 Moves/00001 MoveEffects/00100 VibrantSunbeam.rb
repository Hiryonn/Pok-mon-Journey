module Battle
    class Move
        class VibrantSunbeam < Basic
            def damages(user, target)
                hp_dealt = super
                if $env.sunny? || $env.hardsun?
                  hp_dealt *= 1.5
                else
                  nil
                end
                
                #hp_dealt *= 1.5 if $env.lumini?
                return hp_dealt
              end
        end
        Move.register(:s_vibrant_sunbeam , VibrantSunbeam)
        
    end
end
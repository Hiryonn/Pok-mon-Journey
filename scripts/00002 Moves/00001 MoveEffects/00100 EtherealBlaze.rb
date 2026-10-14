module Battle
    class Move
        class EtherealBlaze < Basic
            def damages(user, target)
                hp_dealt = super
                hp_dealt *= 2 if states.include?(Configs.states.symbol(target.status))
        
                return hp_dealt
              end
             
              STATES = %i[burn]

              def states
                STATES
              end
        end
        Move.register(:s_ethereal_blaze , EtherealBlaze)
        
    end
end
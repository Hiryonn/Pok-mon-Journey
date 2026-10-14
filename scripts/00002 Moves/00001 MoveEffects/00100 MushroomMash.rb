module Battle
    class Move
        class MushroomMash < MultiHit
            def damages(user, target)
                hp_dealt = super
                hp_dealt *= 2 if states.include?(Configs.states.symbol(target.status))
                return hp_dealt
            end
              # Return the States that triggers the x2 damages
              STATES = %i[burn paralysis sleep freeze poison toxic]
              # Return the STATES constant
              # @return [Array<Symbol>]
            def states
                STATES
            end
            
        end
        Move.register(:s_mushroom_mash , MushroomMash)
        
    end
end
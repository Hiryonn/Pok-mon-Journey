module Battle
    class Move
        #Set Power in PS to 0
        class StrikingVelocity < Basic
          
                def calc_sp_atk(user, target)
                  return user.spd
                end

        end
        Move.register(:s_striking_velocity, StrikingVelocity)
    end

end



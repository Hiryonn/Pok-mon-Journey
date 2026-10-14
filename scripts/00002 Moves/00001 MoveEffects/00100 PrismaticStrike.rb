module Battle
    class Move
        class PrismaticStrike < Absorb
            private
            def drain_factor
                return 4 / 3.0 if $env.twilight? || $env.radiance?
                return 2
            end

         

            def calc_sp_def(user, target)
                ph_move = true
                result = calc_sp_def_basis(user, target, ph_move)
                result = (result * calc_def_stat_modifier(user, target, ph_move)).floor
                logic.each_effects(user, target) do |e|
                  result = (result * e.sp_def_multiplier(user, target, self)).floor
                end
                return result
            end

        end
        Move.register(:s_prismatic_strike, PrismaticStrike)
        public
    end
end


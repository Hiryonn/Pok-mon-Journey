module Battle
    class Logic
         
        def calc_critical_hit(user, target, initial_critical_count)
            return false if bank_effects[target.bank].has?(:lucky_chant)
            return true if user.has_ability?(:merciless) && (target.poisoned? || target.toxic?)
            return true if user.effects.has?(:laser_focus)
            return true if target.last_hit_move?(:mana_blade)
            current_value = @move_critical_rng.rand(100_000)
            return current_value < CRITICAL_RATES[calc_critical_count(user, target, initial_critical_count)]
        end

        


    end

end


module PFM
    class PokemonBattler

        def last_hit_move?(db_symbol)
        return last_hit_by_move&.db_symbol == db_symbol
        end
    end
end

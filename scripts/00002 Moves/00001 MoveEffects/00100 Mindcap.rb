module Battle
    class Move
        class Mindcap < Basic
      
     
      private
      def deal_damage(user, actual_targets)
        return true if status?
        raise 'Badly configured move, it should have positive power' if power < 0
        successful_damages = actual_targets.map do |target|
          hp = damages(user, target)
          damage_handler = @logic.damage_handler
          damage_handler.damage_change_with_process(hp, target, user, self) do
            scene.display_message_and_wait(actual_targets.size == 1 ? parse_text(18, 84) : parse_text_with_pokemon(19, 384, target)) if critical_hit?
            efficent_message(effectiveness, target) if hp > 0
          end
          if states.include?(Configs.states.symbol(target.status))
            recoil(hp, user) if recoil? && damage_handler.instance_variable_get(:@reason).nil?
          else
            hp = hp/2
            recoil(hp, user) if recoil? && damage_handler.instance_variable_get(:@reason).nil?
          end
          next(false) if damage_handler.instance_variable_get(:@reason)
          next(true)
        end
        new_targets = actual_targets.map.with_index { |target, index| successful_damages[index] && target }.select { |target| target }
        actual_targets.clear.concat(new_targets)
        return successful_damages.include?(true)
      end
      # Return the States that triggers the x2 damages
      STATES = %i[burn paralysis sleep freeze poison toxic]
      # Return the STATES constant
      # @return [Array<Symbol>]

      def recoil?
        true
      end

      def recoil_factor
          2 || super
      end
        
      # hp =  damage dealt
      # @param user [PFM::PokemonBattler]
      def recoil(hp, user)
          super(hp, user)
        end


      def deal_effect(user, targets)
        
        targets.each do |target|
          stat_mul = -1
          stat_mul *= 2 if states.include?(Configs.states.symbol(target.status))
          stats.each_key {|stat| statsarr1[stat] = stat_mul}
          stats.each {|stat, power|logic.stat_change_handler.stat_change_with_process(stat, power, target, user, self)}
        end
      end
                


        def stats
            return STATS
        end

        STATS = {atk: -1,dfe:-1,spd:-1,ats:-1,dfs:-1}
        
        
      def states
        STATES
      end
        end
        Move.register(:s_mindcap , Mindcap)
        public
        
    end
end
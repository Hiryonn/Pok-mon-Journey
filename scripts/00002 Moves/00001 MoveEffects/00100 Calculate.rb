module Battle
    class Move
        class Calculate < Basic
            #Move will fail if target highest stat is not above 0 
            def move_usable_by_user(user, targets)
                return false unless super
                if targets.all? { |target| find_highest_stat(target).nil?}
                  show_usage_failure(user)
                  return false
                end
                return true
            end
            private
              # Function will Check and set stat accordingly
              # @param user [PFM::PokemonBattler] user of the move
              # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
              
              
            
            def deal_effect(user,targets)
                targets.each do |target|
                    best_stat = find_highest_stat(target)
                    return if best_stat.nil?
                    boost_stat = check_stat(best_stat)
                    logic.stat_change_handler.stat_change_with_process(boost_stat, 1, user, user, self)
                end
            end

            def check_stat(stat)
                    change_stat = nil
                
                    case(stat)
                    when :atk
                        change_stat = :dfe 
                    when :dfs
                        change_stat = :ats
                    when :spd
                        change_stat = :spd
                    when :ats
                        change_stat = :dfs
                    when :dfe
                        change_stat = :atk
                    else
                        nil
                    end
                    return change_stat
            end
                
              
              # @return [Integer]
              # Function will give first highest stat in the order 0 = atk, 1 = dfe, 2 = spd, 3 = ats, 4 = dfs, 5 = eva, 6 = acc
            def find_highest_stat(launcher)
                stat = boosted_stat(launcher.spd, launcher.dfs, launcher.ats, launcher.dfe, launcher.atk)
                return stat
            end

            def boosted_stat(spd, dfs, ats, dfe, atk)
                stats = [[:dfe, dfe], [:dfs, dfs], [:atk, atk], [:ats, ats], [:spd, spd]]
                return stats.max_by(&:last)&.first
            end 
            
        
            
        end
        Move.register(:s_calculate ,Calculate)
        public
        
    end
end
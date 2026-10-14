module Battle
    class Move
        class ShardBlast < Basic
            def fainted_this_turn?(target)
                return true if target.dead?
            end

            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                    if fainted_this_turn?(target)
                        bank = actual_targets.map(&:bank).first
                        return if @logic.bank_effects[bank]&.get(:stealth_rock)
                        @logic.add_bank_effect(Effects::StealthRock.new(@logic, bank, self))
                        @scene.display_message_and_wait(parse_text_with_pokemon(400002, 13, target))  
                    end
                end
            end

            def calc_factor(target)
                type = [self.type]
                @effectiveness = -1
                n = calc_type_n_multiplier(target, :type1, type) * calc_type_n_multiplier(target, :type2, type) * calc_type_n_multiplier(target, :type3, type)
                return n
            end
 
        end
        Move.register(:s_shard_blast , ShardBlast)
        
    end
end
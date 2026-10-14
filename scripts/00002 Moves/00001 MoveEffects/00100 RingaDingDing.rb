module Battle
    class Move
        class RingADingDing < Basic
            
            def recoil?
                true
            end
            def recoil_factor
                8 || super
            end
            def recoil(hp, user)
                hp = user.max_hp 
                return false if user.has_ability?(:rock_head) && !%i[struggle shadow_rush shadow_end].include?(db_symbol)
                return special_recoil(hp, user) if user.has_ability?(:parental_bond)
                @logic.damage_handler.damage_change((hp / recoil_factor).to_i.clamp(1, Float::INFINITY), user)
                @scene.display_message_and_wait(parse_text_with_pokemon(400002, 16, user))
            end
        end
        Move.register(:s_ring_a_ding_ding,RingADingDing)
    end
end
module Battle
    class Move
        class DragonChomp < Basic

        private
        # Function that deals the effect to the pokemon
        # @param user [PFM::PokemonBattler] user of the move
        # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
            def deal_effect(user, actual_targets)
                return if user.dead?
                actual_targets.each do |target|
                    if @logic.item_change_handler.can_lose_item?(target, user) && target.hold_berry?(target.battle_item_db_symbol)
                        additionnal_variables = {PFM::Text::ITEM2[2] => target.item_name, PFM::Text::PKNICK[1] => target.given_name}
                        @scene.display_message_and_wait(parse_text_with_pokemon(400002, 40, user, additionnal_variables))
                        if target.item_effect.is_a?(Effects::Item::Berry)
                            user_effect = Effects::Item.new(logic, user, target.item_effect.db_symbol)
                            user_effect.execute_berry_effect(force_heal: true, force_execution: true)
                            if user.has_ability?(:cheek_pouch) && !user.effects.has?(:heal_block)
                                @scene.visual.show_ability(user)
                                @logic.damage_handler.heal(user, user.max_hp / 3)
                            end
                            user.effects.add(Effects::CudChewEffect.new(logic, user, user.ability_effect.turn_count, target.item_effect.db_symbol)) if user.has_ability?(:cud_chew)
                        end
                    @logic.item_change_handler.change_item(:none, true, target, user, self)
                    elsif @logic.item_change_handler.can_lose_item?(target, user)
                        next if user.dead? && target.hold_item?(:rocky_helmet) || %i[rough_skin iron_barbs].include?(target.battle_ability_db_symbol)
                        additionnal_variables = {PFM::Text::ITEM2[2] => target.item_name, PFM::Text::PKNICK[1] => target.given_name}
                        @scene.display_message_and_wait(parse_text_with_pokemon(400002, 40, user, additionnal_variables))
                        target_item = target.item_db_symbol
                            if $game_temp.trainer_battle
                                if target.from_party? && !target.effects.has?(:item_stolen)
                                    @logic.item_change_handler.change_item(:none, false, target, user, self)
                                    target.effects.add(Effects::ItemStolen.new(@logic, target))
                                else
                                    @logic.item_change_handler.change_item(:none, true, target, user, self)
                                end
                            else
                            overwrite = user.from_party? && !target.from_party?
                            @logic.item_change_handler.change_item(:none, overwrite, target, user, self)
                            end
                        end
                    end
            
                end
            end
        Move.register(:s_draconic_chomp, DragonChomp)
        public
    end
end
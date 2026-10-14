module Battle
    class Move
        class TyphoonBlast < Basic

            def effect_working(user, actual_target)
                if actual_targets.any? { |target| @logic.item_change_handler.can_lose_item?(target, user) }
                    n = 1
                        scene.logic.each_effects(user).each do |e|
                            n *= e.effect_chance_modifier(self)
                        end
                return bchance?((effect_chance * n) / 100.0) && super
                else
                return false
                end
            end


            def deal_effect(user, actual_targets)
                actual_targets.each do |target|
                  next unless @logic.item_change_handler.can_lose_item?(target, user)
                  next if user.dead? && target.hold_item?(:rocky_helmet) || %i[rough_skin iron_barbs].include?(target.battle_ability_db_symbol)
                  additionnal_variables = {PFM::Text::ITEM2[2] => target.item_name, PFM::Text::PKNICK[1] => target.given_name}
                  @scene.display_message_and_wait(parse_text_with_pokemon(400002, 33, user, additionnal_variables))
                  if target.from_party? && !target.effects.has?(:item_stolen)
                    @logic.item_change_handler.change_item(:none, false, target, user, self)
                    target.effects.add(Effects::ItemStolen.new(@logic, target))
                  else
                    @logic.item_change_handler.change_item(:none, true, target, user, self)
                  end
                end
            end
        end
        Move.register(:s_typhoon_blast , TyphoonBlast)
        
    end
end
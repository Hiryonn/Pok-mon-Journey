module Battle
  class Move
      class MapleDust < Move


          def deal_effect(user,  actual_target)
            pokemon = nil
           if enemy_poke?(user)
            pokemon = user
           else
            pokemon = logic.scene.visual.heal_pokemon_choice 
           end 
            logic.scene.display_message_and_wait(parse_text_with_2pokemon(400002, 67 , user, pokemon)) if pokemon != user
            logic.scene.display_message_and_wait(parse_text_with_pokemon(400002, 100 , user)) if pokemon == user
            hp = pokemon.max_hp / 4
            logic.damage_handler.heal(pokemon,hp)
            logic.status_change_handler.status_change_with_process(:cure, pokemon) if pokemon.status != 0
          end

          def enemy_poke?(pokemon)
            return false unless $scene.is_a?(Battle::Scene)
            return false unless pokemon
            return pokemon.bank != 0 if pokemon.is_a?(PFM::PokemonBattler)
            return pokemon.position.nil? || pokemon.position < 0
          end
      end
      Move.register(:s_maple_dust, MapleDust)
  end
end

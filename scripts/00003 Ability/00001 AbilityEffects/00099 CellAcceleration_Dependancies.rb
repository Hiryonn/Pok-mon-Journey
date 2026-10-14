module Battle
    module Effects
      class CellAcceleration < PositionTiedEffectBase
        MAPPING = {
          normal:   :ghost,
          fire:     :dragon,
          water:    :grass,
          electric: :ground,
          grass:    :bug,
          ice:      :ice,
          fighting: :psychic,
          poison:   :steel,
          ground:   :flying,
          flying:   :electric,
          psychic:  :dark,
          bug:      :rock,
          rock:     :water,
          ghost:    :normal,
          dragon:   :fairy,
          dark:     :fighting,
          steel:    :fire,
          fairy:    :poison
        }
        def initialize(logic, bank, target, setpokemon, position)
          super(logic, bank, 0)
          @target = target
          @set_pokemon = setpokemon
          @position = position
          @type = nil
          type_change(data_type(@set_pokemon.type1).db_symbol)
        end
        # Get the effect name
        # @return [Symbol]
        def name
          return :cell_accleration
        end
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if who != @set_pokemon
          if who == @set_pokemon && handler.logic.all_alive_battlers.include?(@target)
            return if with == nil
            @set_pokemon = with
            type_change(data_type(@set_pokemon.type1).db_symbol)            
          end
        end

        def type_change(foe_type)
          @type = MAPPING[foe_type]
          if @target.type1 == 19 
            if @target.type2 != data_type(@type).id
              @target.type2 = data_type(@type).id
              @logic.scene.visual.show_ability(@target)
              @logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 899, @target, '[VAR TYPE(0001)]' => data_type(@target.type2).name)) 
            end          
          elsif @target.type1 != data_type(@type).id
            @logic.scene.visual.show_ability(@target)
            @target.kosmosa_calibrate(@type)
            @logic.scene.visual.show_switch_form_animation(@target)
            @logic.scene.visual.wait_for_animation
            @logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 899, @target, '[VAR TYPE(0001)]' => data_type(@target.type1).name)) 
          end
        end
      end
    end
end
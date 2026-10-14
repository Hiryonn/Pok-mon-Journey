module Battle
  class Move
    # Shared behaviour of every Shadow move: it ignores the type chart, and it never runs out of PP.
    module ShadowMove
      # Engine text ids mapped to the plugin's own key, used when the game's dialog file lacks the line.
      # @return [Hash{ Integer => Symbol }]
      ENGINE_MESSAGES = {
        378 => :recoil_hit,
        851 => :recharging
      }
      # Id of the battle dialog file of the engine.
      # @return [Integer]
      ENGINE_FILE_ID = 19

      # Parse a text from the text database with specific informations and a pokemon
      # @param file_id [Integer] ID of the text file
      # @param text_id [Integer] ID of the text in the file
      # @param pokemon [PFM::Pokemon] pokemon that will introduce an offset on text_id (its name is also used)
      # @param additionnal_var [nil, Hash{String => String}] additional remplacements in the text
      # @return [String] the text parsed and ready to be displayed
      def parse_text_with_pokemon(file_id, text_id, pokemon, additionnal_var = nil)
        key = ENGINE_MESSAGES[text_id]
        return super unless file_id == ENGINE_FILE_ID && key

        return PFM::ShadowTexts.creature_message(key, pokemon)
      end

      private

      # Calc TypeN multiplier of the move
      # @note The damage formula multiplies the three type slots instead of asking type_modifier, so the first slot carries it all.
      # @param target [PFM::PokemonBattler] target of the move
      # @param type_to_check [Symbol] type to check on the target
      # @param types [Array<Integer>] list of types the move has
      # @return [Numeric]
      def calc_type_n_multiplier(target, type_to_check, types)
        result = type_to_check == :type1 ? PFM::ShadowEffectiveness.against(target.shadow?) : 1.0
        @effectiveness *= result if @effectiveness >= 0

        return result
      end

      # Decrease the PP of the move
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      def decrease_pp(user, targets)
        return
      end
    end

    # Shadow move dealing plain damage, its secondary status coming from the data.
    class ShadowBasic < Basic
      include ShadowMove
    end

    # Shadow move hurting its user on top of its damage.
    class ShadowRecoil < RecoilMove
      include ShadowMove
    end

    # Shadow move changing a stat or inflicting a status.
    class ShadowStat < StatusStat
      include ShadowMove
    end

    # Shadow move keeping the target from fleeing.
    class ShadowCantSwitch < CantSwitch
      include ShadowMove
    end

    # Shadow move sweeping the screens away.
    class ShadowDefog < Defog
      include ShadowMove
    end

    # Shadow move halving the HP of everything on the field, its user spending the next turn
    # recovering from it.
    class ShadowHalf < Reload
      include ShadowMove

      private

      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @note The halving lives here and not in damages because the move is a status one, which the damage step of the engine leaves untouched.
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          # Halving never knocks out, so a creature on its last point comes out of it untouched.
          damage = target.hp / 2
          @logic.damage_handler.damage_change(damage, target) if damage.positive?
        end

        super
      end
    end

    Move.register(:s_shadow_basic, ShadowBasic)
    Move.register(:s_shadow_recoil, ShadowRecoil)
    Move.register(:s_shadow_stat, ShadowStat)
    Move.register(:s_shadow_cantflee, ShadowCantSwitch)
    Move.register(:s_shadow_defog, ShadowDefog)
    Move.register(:s_shadow_half, ShadowHalf)
  end
end

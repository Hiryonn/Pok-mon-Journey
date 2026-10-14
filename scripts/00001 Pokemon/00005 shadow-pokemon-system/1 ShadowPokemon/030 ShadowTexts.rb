module PFM
  # Messages of the plugin, which live in the dialog file it ships rather than in the ones of the
  # game, so installing the plugin never overwrites a text of its host.
  module ShadowTexts
    # Id of the dialog file shipped by the plugin.
    # @return [Integer]
    FILE_ID = 110_020

    # Index of each message in that file.
    # @return [Hash{ Symbol => Integer }]
    MESSAGES = {
      instability_refusal: 0,
      heart_opened: 1,
      call_unheard: 2,
      scent_soothed: 3,
      scent_opened: 4,
      summary_title: 5,
      locked_heart: 6,
      opened_bars: 7,
      held_experience: 8,
      out_of_control: 9,
      calm: 10,
      ready_to_purify: 11,
      call_button: 12,
      shadow_sky_appeared: 13,
      shadow_sky_continues: 14,
      shadow_sky_faded: 15,
      reverse_mode_entered: 16,
      reverse_mode_damage: 19,
      heart_door: 22,
      locked_move: 29,
      trade_refusal: 30,
      shadow_sky_damage: 31,
      purification_nickname: 34,
      purify_choice: 35,
      purify_which: 36,
      call_attentive: 37,
      shadow_spotted: 38,
      reverse_mode_ended: 39,
      call_out: 40,
      recoil_hit: 41,
      recharging: 44
    }

    module_function

    # Message of the plugin, in the language of the game.
    # @param key [Symbol]
    # @return [String]
    def message(key)
      return ext_text(FILE_ID, MESSAGES[key])
    end

    # Sentence telling how far the heart has come, one line per bar it can open plus the last lock.
    # A gauge that has run out shares its bar count with the one just before it, so it takes a line
    # of its own rather than a count.
    # @param bars [Integer] number of bars the heart has opened
    # @param empty [Boolean] whether the gauge has run out
    # @return [String]
    def heart_door(bars, empty)
      line = empty ? ShadowHeart::BARS + 1 : bars

      return ext_text(FILE_ID, MESSAGES[:heart_door] + line)
    end

    # Message of the plugin naming a creature, in the language of the game. A message a battle can
    # show takes three lines in the dialog file, the ally one then the wild one then the one of a
    # Trainer, the engine picking between them from the creature itself. Outside of a battle only
    # the first line is ever read.
    # @param key [Symbol]
    # @param creature [PFM::PokemonBattler]
    # @param additional_variables [Hash{ String => String }, nil] the ones the engine does not fill on its own
    # @return [String]
    def creature_message(key, creature, additional_variables = nil)
      return parse_text_with_pokemon(FILE_ID, MESSAGES[key], creature, additional_variables)
    end
  end
end

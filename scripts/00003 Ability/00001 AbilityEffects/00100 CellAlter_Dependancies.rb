module PFM
    class Pokemon
    attr_accessor :kosmosa_type

    KOSMOSA_CALIBRATE = {}
    FORM = {
      normal:   0,
      fire:     1,
      water:    2,
      electric: 3,
      grass:    4,
      ice:      5,
      fighting: 6,
      poison:   7,
      ground:   8,
      flying:   9,
      psychic:  10,
      bug:      11,
      rock:     12,
      ghost:    13,
      dragon:   14,
      dark:     15,
      steel:    16,
      fairy:    17
    }
    TYPE = {
      normal:   1,
      fire:     2,
      water:    3,
      electric: 4,
      grass:    5,
      ice:      6,
      fighting: 7,
      poison:   8,
      ground:   9,
      flying:   10,
      psychic:  11,
      bug:      12,
      rock:     13,
      ghost:    14,
      dragon:   15,
      dark:     17,
      steel:    16,
      fairy:    18
    }

    def kosmosa_calibrate(reason = :menu)
      @character = nil
      last_form = @form
      block = KOSMOSA_CALIBRATE[db_symbol]
      instance_exec(reason, &block) if block
      @form = 0 if data_creature(db_symbol).forms.none? { |creature_form| creature_form.form == @form }
      update_ability
      return last_form != @form
    end
            
    def kosmosa_form(reason)
        @kosmosa_type = TYPE[reason]
        return FORM[reason]
    end
    KosmosaItem = %i[__undef__ blaze_gel hydro_gel lightning_gel nature_gel frosty_gel aura_gel toxic_gel earth_gel soaring_gel mind_gel insect_gel mineral_gel spooky_gel draco_gel night_gel iron_gel pixie_gel]
    FORM_CALIBRATE[:kosmosa] = proc {@form = KosmosaItem.index(item_db_symbol).to_i}
    KOSMOSA_CALIBRATE[:kosmosa] = proc { |reason| @form = kosmosa_form(reason) }

    end
end
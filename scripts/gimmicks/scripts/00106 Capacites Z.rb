# Gimmicks : capacités Z (et Ultra-Explosion de Necrozma)
#
# - Le Pokémon tient un cristal Z (Normazium Z… ou cristal exclusif) et le dresseur a un Bracelet Z.
# - Cristal de type : une attaque offensive de ce type devient la capacité Z du type (puissance selon la puissance
#   de base, même catégorie) ; une attaque de statut de ce type reçoit un bonus Z (stat +1…) puis s'utilise.
# - Cristal exclusif : une attaque précise d'un Pokémon précis devient sa capacité Z exclusive.
# - Le Pokémon garde son cristal ; la capacité Z utilise un PP de l'attaque de départ.
# - Necrozma Crinière du Couchant / Ailes de l'Aurore avec l'Ultranecrozium Z : Ultra-Explosion au début du tour
#   (puis Photon Geyser devient « Apocalypse Lumineuse »).
module Gimmicks
  module ZMove
    # Cristal de type => capacité Z (physique ; la version spéciale est « <nom>2 » dans Studio)
    TYPES = {
      normalium_z: [:normal, :breakneck_blitz], fightinium_z: [:fighting, :all_out_pummeling],
      flyinium_z: [:flying, :supersonic_skystrike], poisonium_z: [:poison, :acid_downpour],
      groundium_z: [:ground, :tectonic_rage], rockium_z: [:rock, :continental_crush], buginium_z: [:bug, :savage_spin_out],
      ghostium_z: [:ghost, :never_ending_nightmare], steelium_z: [:steel, :corkscrew_crash],
      firium_z: [:fire, :inferno_overdrive], waterium_z: [:water, :hydro_vortex], grassium_z: [:grass, :bloom_doom],
      electrium_z: [:electric, :gigavolt_havoc], psychium_z: [:psychic, :shattered_psyche],
      icium_z: [:ice, :subzero_slammer], dragonium_z: [:dragon, :devastating_drake],
      darkinium_z: [:dark, :black_hole_eclipse], fairium_z: [:fairy, :twinkle_tackle]
    }.freeze
    # Cristaux exclusifs : cristal => [Pokémon, formes (nil : toutes), attaque, capacité Z, puissance]
    EXCLUSIVE = {
      aloraichium_z: [%i[raichu], [1], :thunderbolt, :stoked_sparksurfer, 175],
      decidium_z: [%i[decidueye], nil, :spirit_shackle, :sinister_arrow_raid, 180],
      eevium_z: [%i[eevee], nil, :last_resort, :extreme_evoboost, 0],
      incinium_z: [%i[incineroar], nil, :darkest_lariat, :malicious_moonsault, 180],
      kommonium_z: [%i[kommo_o], nil, :clanging_scales, :clangorous_soulblaze, 185],
      lunalium_z: [%i[lunala necrozma], [0, 2], :moongeist_beam, :menacing_moonraze_maelstrom, 200],
      lycanium_z: [%i[lycanroc], nil, :stone_edge, :splintered_stormshards, 190],
      marshadium_z: [%i[marshadow], nil, :spectral_thief, :soul_stealing_7_star_strike, 195],
      mewnium_z: [%i[mew], nil, :psychic, :genesis_supernova, 185],
      mimikium_z: [%i[mimikyu], nil, :play_rough, :let_s_snuggle_forever, 190],
      pikanium_z: [%i[pikachu], [0], :volt_tackle, :catastropika, 210],
      pikashunium_z: [%i[pikachu], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], :thunderbolt, :s10_000_000_volt_thunderbolt, 195],
      primarium_z: [%i[primarina], nil, :sparkling_aria, :oceanic_operetta, 195],
      snorlium_z: [%i[snorlax], nil, :giga_impact, :pulverizing_pancake, 210],
      solganium_z: [%i[solgaleo necrozma], [0, 1], :sunsteel_strike, :searing_sunraze_smash, 200],
      tapunium_z: [%i[tapu_koko tapu_lele tapu_bulu tapu_fini], nil, :nature_s_madness, :guardian_of_alola, 0],
      ultranecrozium_z: [%i[necrozma], [30], :photon_geyser, :light_that_burns_the_sky, 200]
    }.freeze
    # Ultra-Explosion : Necrozma (forme 1 ou 2) → forme 30
    ULTRA_FORMS = [1, 2].freeze
    ULTRA_FORM = 30
    # Puissance de la capacité Z selon la puissance de l'attaque de départ (exceptions plus bas)
    POWERS = [[55, 100], [65, 120], [75, 140], [85, 160], [95, 175], [100, 180], [110, 185], [125, 190], [130, 195]].freeze
    POWER_EXCEPTIONS = {
      mega_drain: 120, weather_ball: 160, hex: 160, gear_grind: 180, v_create: 220, flying_press: 170, core_enforcer: 140,
      crush_grip: 190, wring_out: 190, electro_ball: 160, gyro_ball: 160, low_kick: 160, grass_knot: 160,
      heavy_slam: 160, heat_crash: 160, return: 160, frustration: 160, fling: 100, natural_gift: 160, magnitude: 140,
      present: 100, punishment: 160, beat_up: 100, flail: 160, reversal: 160, trump_card: 160, stored_power: 160,
      power_trip: 160, spit_up: 100, crush_claw: 140, triple_kick: 120, bone_rush: 140, double_hit: 140
    }.freeze
    # Bonus Z des attaques de statut : stat => niveaux, :reset (stats baissées remises), :heal (PV au max),
    # :crit (taux de critique), :all (+1 à tout). Attaque absente : :reset.
    STATUS = {
      atk1: %i[bulk_up hone_claws howl laser_focus leer meditate odor_sleuth power_trick rototiller screech sharpen
               tail_whip taunt topsy_turvy will_o_wisp work_up],
      atk2: %i[mirror_move], atk3: %i[splash],
      dfe1: %i[aqua_ring baby_doll_eyes baneful_bunker block charm defend_order fairy_lock feather_dance flower_shield
               grassy_terrain growl harden mat_block noble_roar pain_split play_nice poison_gas poison_powder quick_guard
               reflect roar spider_web spikes spiky_shield stealth_rock strength_sap tearful_look tickle torment toxic
               toxic_spikes venom_drench wide_guard withdraw],
      ats1: %i[confuse_ray electrify embargo fake_tears gear_up gravity growth instruct ion_deluge metal_sound
               mind_reader miracle_eye nightmare psychic_terrain reflect_type simple_beam soak sweet_kiss teeter_dance
               telekinesis],
      ats2: %i[heal_block psycho_shift],
      dfs1: %i[charge confide cosmic_power electric_terrain entrainment flatter glare gastro_acid ingrain light_screen
               magic_room magnetic_flux mean_look misty_terrain mud_sport spotlight stun_spore thunder_wave water_sport
               whirlwind wish wonder_room],
      dfs2: %i[aromatic_mist captivate imprison magic_coat powder],
      spd1: %i[after_you aurora_veil lock_on quash role_play safeguard skill_swap snatch tailwind trick worry_seed],
      spd2: %i[ally_switch],
      acc1: %i[copycat defense_curl focus_energy kinesis mimic sand_attack smokescreen trick_room],
      eva1: %i[camouflage detect flash lucky_chant magnet_rise scary_face sweet_scent],
      all: %i[celebrate conversion forest_s_curse geomancy happy_hour hold_hands purify sketch trick_or_treat],
      crit: %i[acupressure foresight heart_swap sleep_talk],
      heal: %i[belly_drum memento parting_shot haze]
    }.freeze
    # Images des titres (graphics/interface/gimmicks/z_titles) qui ne suivent pas le nom de l'attaque
    TITLES = {
      s10_000_000_volt_thunderbolt: 'tenmillionvoltthunderbolt', let_s_snuggle_forever: 'letssnuggleforever'
    }.freeze
    TEXTS = {
      power: ['%s s\'entoure de Force Z !', '%s surrounded itself with its Z-Power!'],
      reset: ['Les stats baissées de %s reviennent à la normale !', '%s returned its decreased stats to normal!'],
      heal: ['%s récupère tous ses PV grâce à la Force Z !', '%s restored its HP using its Z-Power!'],
      crit: ['%s se concentre grâce à la Force Z !', '%s boosted its critical-hit ratio using its Z-Power!'],
      ultra_pre: ['Une lumière éblouissante va jaillir de %s !', 'Bright light is about to burst out of %s!'],
      ultra: ['%s retrouve sa vraie puissance grâce à l\'Ultra-Explosion !',
              '%s regained its true power through Ultra Burst!']
    }.freeze

    module_function

    # @param key [Symbol]
    def text(key)
      return TEXTS[key][$options&.language == 'fr' ? 0 : 1]
    rescue StandardError
      return TEXTS[key].first
    end

    # Cristal Z tenu (variantes « _z2 » et « ilima_normalium_z » ramenées au cristal de base)
    # @param battler [PFM::PokemonBattler]
    # @return [Symbol, nil]
    def crystal(battler)
      item = battler.battle_item_db_symbol.to_s
      item = 'normalium_z' if item == 'ilima_normalium_z'
      item = item.sub(/z2\z/, 'z').to_sym
      return TYPES.key?(item) || EXCLUSIVE.key?(item) ? item : nil
    rescue StandardError
      return nil
    end

    # @param battler [PFM::PokemonBattler]
    def ultra?(battler)
      return battler.db_symbol == :necrozma && ULTRA_FORMS.include?(battler.form) && crystal(battler) == :ultranecrozium_z
    end

    # Capacité Z obtenue avec une attaque
    # @param battler [PFM::PokemonBattler]
    # @param move [Battle::Move]
    # @param form [Integer] forme à considérer (Ultra-Explosion)
    # @return [Hash, nil] { z: db_symbol, power:, status: true (bonus Z d'une attaque de statut) }
    def z_for(battler, move, form = battler.form)
      return nil unless move && (crystal = crystal(battler))

      if (exclusive = EXCLUSIVE[crystal])
        species, forms, base, z, power = exclusive
        form = ULTRA_FORM if crystal == :ultranecrozium_z && ultra?(battler)
        return nil unless species.include?(battler.db_symbol) && (forms.nil? || forms.include?(form)) && move.db_symbol == base

        return { z: z, power: power, exclusive: true }
      end
      type, generic = TYPES[crystal]
      return nil unless data_type(move.type).db_symbol == type
      return { status: true } if move.status?

      name = move.special? && data_move_exist?(:"#{generic}2") ? :"#{generic}2" : generic
      return { z: name, power: power_for(move) }
    rescue StandardError
      return nil
    end

    # @param symbol [Symbol]
    def data_move_exist?(symbol)
      return data_move(symbol).db_symbol == symbol
    rescue StandardError
      return false
    end

    # @param move [Battle::Move]
    # @return [Integer]
    def power_for(move)
      return POWER_EXCEPTIONS[move.db_symbol] if POWER_EXCEPTIONS[move.db_symbol]

      base = move.power.to_i
      return 100 if base <= 0

      return (POWERS.find { |limit, _| base <= limit }&.last) || 200
    end

    # @param battler [PFM::PokemonBattler]
    # @param _logic [Battle::Logic]
    def possible?(battler, _logic)
      return true if ultra?(battler)

      return battler.moveset.any? { |move| move.pp > 0 && z_for(battler, move) }
    end

    # @param battler [PFM::PokemonBattler]
    # @param move [Battle::Move]
    # @return [Boolean] l'attaque peut devenir une capacité Z (ou Ultra-Explosion sans capacité Z)
    def selectable?(battler, move)
      return true if ultra?(battler)

      return !z_for(battler, move).nil?
    end

    # Nom affiché sur le bouton de l'attaque quand la capacité Z est choisie
    # @return [String, nil]
    def display_name(battler, move)
      info = z_for(battler, move, ultra?(battler) ? ULTRA_FORM : battler.form)
      return nil unless info
      return "Z-#{move.name}" if info[:status]

      return data_move(info[:z]).name
    rescue StandardError
      return nil
    end

    # @param scene [Battle::Scene]
    # @param battler [PFM::PokemonBattler]
    # @param action [Battle::Actions::PJGimmick]
    def execute(scene, battler, action)
      ultra_burst(scene, battler) if ultra?(battler)
      attack = action.attack
      move = attack&.move
      info = z_for(battler, move)
      return unless info

      scene.display_message_and_wait(format(text(:power), battler.given_name))
      title = info[:status] ? nil : title_name(info[:z])
      Cinematic.new(scene, battler).play(:zmove, title) {} if Gimmicks.cinematic?
      if info[:status]
        status_bonus(scene, battler, move)
      else
        attack.instance_variable_set(:@move, build_move(scene, battler, move, info))
      end
    end

    # @param scene [Battle::Scene]
    # @param battler [PFM::PokemonBattler]
    def ultra_burst(scene, battler)
      scene.display_message_and_wait(format(text(:ultra_pre), battler.given_name))
      battler.instance_variable_set(:@pj_ultra_base_form, battler.form)
      change = proc { battler.instance_variable_set(:@form, ULTRA_FORM) }
      Gimmicks.cinematic? ? Cinematic.new(scene, battler).play(:ultra, &change) : change.call
      scene.visual.battler_sprite(battler.bank, battler.position)&.pokemon = battler
      scene.visual.refresh_info_bar(battler)
      scene.display_message_and_wait(format(text(:ultra), battler.given_name))
      battler.ability_effect.on_switch_event(scene.logic.switch_handler, battler, battler) rescue nil
    end

    # Capacité Z offensive (remplace l'attaque, un PP de l'attaque de départ est utilisé)
    def build_move(scene, battler, move, info)
      z = Battle::Move::PJZMove.new(info[:z], 1, 1, scene)
      z.pj_setup(move, info[:power], battler)
      return z
    end

    # Bonus Z d'une attaque de statut
    def status_bonus(scene, battler, move)
      effect = STATUS.find { |_, moves| moves.include?(move.db_symbol) }&.first || :reset
      effect = battler.type?(data_type(:ghost).id) ? :heal : :atk1 if move.db_symbol == :curse
      logic = scene.logic
      case effect
      when :reset
        changed = false
        stages = battler.instance_variable_get(:@battle_stage) || []
        %i[atk dfe spd dfs ats eva acc].each do |stat|
          index = stat_index(stat)
          next unless stages[index].to_i < 0

          stages[index] = 0
          changed = true
        end
        scene.display_message_and_wait(format(text(:reset), battler.given_name)) if changed
      when :heal
        logic.damage_handler.heal(battler, battler.max_hp - battler.hp, test_heal_block: false) if battler.hp < battler.max_hp
        scene.display_message_and_wait(format(text(:heal), battler.given_name))
      when :crit
        battler.effects.add(Battle::Effects::FocusEnergy.new(logic, battler)) rescue nil
        scene.display_message_and_wait(format(text(:crit), battler.given_name))
      when :all
        %i[atk dfe ats dfs spd].each { |stat| logic.stat_change_handler.stat_change_with_process(stat, 1, battler, battler) }
      else
        stat = effect.to_s[0..2].to_sym
        logic.stat_change_handler.stat_change_with_process(stat, effect.to_s[-1].to_i, battler, battler)
      end
    end

    # @param stat [Symbol]
    # @return [Integer] indice dans battle_stage
    def stat_index(stat)
      return Configs.stats.send(:"#{stat}_stage_index")
    rescue StandardError
      return %i[atk dfe spd dfs ats eva acc].index(stat)
    end

    # @param z [Symbol]
    # @return [String] image du titre
    def title_name(z)
      return TITLES[z] || z.to_s.sub(/2\z/, '').delete('_')
    end
  end
  register(:zmove, ZMove)
end

module PFM
  class PokemonBattler
    # Fin du combat : Necrozma reprend sa forme
    def pj_end_ultra
      @form = @pj_ultra_base_form if @pj_ultra_base_form
      @pj_ultra_base_form = nil
    end
  end
end

module Battle
  class Move
    # Capacité Z offensive : puissance, catégorie et type de l'attaque de départ (effets des capacités exclusives)
    class PJZMove < Basic
      # @return [Battle::Move] attaque de départ
      attr_reader :pj_base_move

      # @param base [Battle::Move]
      # @param power [Integer]
      # @param battler [PFM::PokemonBattler]
      def pj_setup(base, power, battler)
        @pj_base_move = base
        @pj_power = power
        @pj_physical = base.physical?
        @pj_physical = battler.atk_basis > battler.ats_basis if db_symbol == :light_that_burns_the_sky
        @pj_status = db_symbol == :extreme_evoboost
      end

      def power
        return @pj_power || super
      end

      def real_base_power(user, target)
        return @pj_power || super
      end

      def physical?
        return @pj_status ? false : @pj_physical
      end

      def special?
        return @pj_status ? false : !@pj_physical
      end

      def status?
        return @pj_status ? true : false
      end

      def critical_rate
        return db_symbol == :s10_000_000_volt_thunderbolt ? 3 : super
      end

      # Garde du Pokémon : une capacité Z la traverse
      def blocable?(*)
        return false
      end

      def damages(user, target)
        return [(target.hp * 3 / 4), 1].max if db_symbol == :guardian_of_alola

        return super
      end

      def effect_working?(user, actual_targets)
        return true
      end

      def deal_effect(user, actual_targets)
        case db_symbol
        when :extreme_evoboost
          %i[atk dfe ats dfs spd].each { |stat| logic.stat_change_handler.stat_change_with_process(stat, 2, user, user, self) }
        when :clangorous_soulblaze
          %i[atk dfe ats dfs spd].each { |stat| logic.stat_change_handler.stat_change_with_process(stat, 1, user, user, self) }
        when :stoked_sparksurfer
          actual_targets.each { |target| logic.status_change_handler.status_change_with_process(:paralysis, target, user, self) }
        when :genesis_supernova
          logic.fterrain_change_handler.fterrain_change_with_process(:psychic_terrain, 5)
        when :splintered_stormshards
          logic.fterrain_change_handler.fterrain_change_with_process(:none, 0)
        end
        return true
      rescue StandardError => e
        log_error("Capacité Z : #{e.message}") if respond_to?(:log_error, true)
        return true
      end
    end
  end
end

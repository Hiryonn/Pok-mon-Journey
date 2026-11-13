# Gimmicks : Dynamax / Gigamax
#
# - Le dresseur a un Poignet Dynamax ; le Pokémon grandit pendant 3 tours (ou jusqu'à ce qu'il soit rappelé).
# - PV multipliés par 1,5 + 0,05 x niveau Dynamax (0 à 10).
# - Toutes ses attaques deviennent des attaques Max (attaques de statut : Gardomax) ; avec le facteur Gigamax et une
#   forme Gigamax (forme 40, Shifours 40 / 41), l'attaque du type de sa forme Gigamax devient son attaque G-Max.
module Gimmicks
  module Dynamax
    # Durée en tours
    TURNS = 3
    # Taille du Pokémon Dynamaxé en combat
    SPRITE_ZOOM = 1.5
    # Niveau Dynamax des Pokémon qui n'en ont pas reçu (0 à 10)
    DEFAULT_LEVEL = 10
    # Ne peuvent pas se Dynamaxer
    BLOCKED = %i[zacian zamazenta eternatus].freeze
    # Forme Gigamax : forme 40 (+ forme de départ si elle existe, ex. Shifours 41)
    GMAX_FORM = 40
    # Attaque Max de chaque type
    MAX_MOVES = {
      normal: :max_strike, fighting: :max_knuckle, flying: :max_airstream, poison: :max_ooze, ground: :max_quake,
      rock: :max_rockfall, bug: :max_flutterby, ghost: :max_phantasm, steel: :max_steelspike, fire: :max_flare,
      water: :max_geyser, grass: :max_overgrowth, electric: :max_lightning, psychic: :max_mindstorm,
      ice: :max_hailstorm, dragon: :max_wyrmwind, dark: :max_darkness, fairy: :max_starfall
    }.freeze
    # Attaques G-Max : Pokémon => [type, attaque, puissance fixe (nil : selon l'attaque de départ)]
    GMAX_MOVES = {
      venusaur: [:grass, :gmax_vine_lash], charizard: [:fire, :gmax_wildfire], blastoise: [:water, :gmax_cannonade],
      butterfree: [:bug, :gmax_befuddle], pikachu: [:electric, :gmax_volt_crash], meowth: [:normal, :gmax_gold_rush],
      machamp: [:fighting, :gmax_chi_strike], gengar: [:ghost, :gmax_terror], kingler: [:water, :gmax_foam_burst],
      lapras: [:ice, :gmax_resonance], eevee: [:normal, :gmax_cuddle], snorlax: [:normal, :gmax_replenish],
      garbodor: [:poison, :gmax_malodor], melmetal: [:steel, :gmax_meltdown], rillaboom: [:grass, :gmax_drum_solo, 160],
      cinderace: [:fire, :gmax_fireball, 160], inteleon: [:water, :gmax_hydrosnipe, 160],
      corviknight: [:flying, :gmax_wind_rage], orbeetle: [:psychic, :gmax_gravitas], drednaw: [:water, :gmax_stonesurge],
      coalossal: [:rock, :gmax_volcalith], flapple: [:grass, :gmax_tartness], appletun: [:grass, :gmax_sweetness],
      sandaconda: [:ground, :gmax_sandblast], toxtricity: [:electric, :gmax_stun_shock],
      centiskorch: [:fire, :gmax_centiferno], hatterene: [:fairy, :gmax_smite], grimmsnarl: [:dark, :gmax_snooze],
      alcremie: [:fairy, :gmax_finale], copperajah: [:steel, :gmax_steelsurge], duraludon: [:dragon, :gmax_depletion],
      urshifu: [:dark, :gmax_one_blow]
    }.freeze
    # Shifours Mille Poings (forme 1) : G-Max Multicoup (Eau)
    GMAX_FORM_MOVES = { [:urshifu, 1] => [:water, :gmax_rapid_flow] }.freeze
    # Puissance des attaques Max selon la puissance de départ ([limite, puissance], Combat / Poison à part)
    POWERS = [[40, 90], [50, 100], [60, 110], [70, 120], [100, 130], [140, 140]].freeze
    POWERS_LOW = [[40, 70], [50, 75], [60, 80], [70, 85], [100, 90], [140, 95]].freeze
    # Effets des attaques Max : stat des lanceurs (+1) / des cibles (-1), météo, champ
    EFFECTS = {
      max_strike: [:foes, :spd, -1], max_knuckle: [:allies, :atk, 1], max_airstream: [:allies, :spd, 1],
      max_ooze: [:allies, :ats, 1], max_quake: [:allies, :dfs, 1], max_rockfall: [:weather, :sandstorm],
      max_flutterby: [:foes, :ats, -1], max_phantasm: [:foes, :dfe, -1], max_steelspike: [:allies, :dfe, 1],
      max_flare: [:weather, :sunny], max_geyser: [:weather, :rain], max_overgrowth: [:terrain, :grassy_terrain],
      max_lightning: [:terrain, :electric_terrain], max_mindstorm: [:terrain, :psychic_terrain],
      max_hailstorm: [:weather, :hail], max_wyrmwind: [:foes, :atk, -1], max_darkness: [:foes, :dfs, -1],
      max_starfall: [:terrain, :misty_terrain],
      gmax_befuddle: [:status, %i[poison paralysis sleep]], gmax_stun_shock: [:status, %i[poison paralysis]],
      gmax_malodor: [:status, %i[poison]], gmax_volt_crash: [:status, %i[paralysis]],
      gmax_foam_burst: [:foes, :spd, -2], gmax_tartness: [:foes, :eva, -1], gmax_chi_strike: [:allies, :atk, 0],
      gmax_finale: [:heal], gmax_sweetness: [:cure], gmax_snooze: [:status, %i[sleep]]
    }.freeze
    TEXTS = {
      start: ['%s se Dynamaxe !', '%s Dynamaxed!'],
      gmax: ['%s se Gigamaxe !', '%s Gigantamaxed!'],
      end: ['%s retrouve sa taille normale !', '%s returned to its normal size!']
    }.freeze

    module_function

    # @param key [Symbol]
    def text(key)
      return TEXTS[key][$options&.language == 'fr' ? 0 : 1]
    rescue StandardError
      return TEXTS[key].first
    end

    # @param battler [PFM::PokemonBattler]
    # @param _logic [Battle::Logic]
    def possible?(battler, _logic)
      return false if BLOCKED.include?(battler.db_symbol) || battler.pj_dynamax?
      return false if Gimmicks.species_config(battler.db_symbol)['no_dynamax']

      return true
    end

    # @param pokemon [PFM::Pokemon]
    # @return [Integer, nil] forme Gigamax si le Pokémon a le facteur Gigamax
    def gmax_form(pokemon)
      original = pokemon.respond_to?(:original) && pokemon.original ? pokemon.original : pokemon
      return nil unless original.pj_gmax_factor

      [GMAX_FORM + pokemon.form.to_i, GMAX_FORM].uniq.each do |form|
        return form if data_creature(pokemon.db_symbol).forms.any? { |f| f.form == form }
      end
      return nil
    rescue StandardError
      return nil
    end

    # @param scene [Battle::Scene]
    # @param battler [PFM::PokemonBattler]
    # @param action [Battle::Actions::PJGimmick]
    def execute(scene, battler, action)
      form = gmax_form(battler)
      change = proc { battler.pj_dynamax!(form) }
      Gimmicks.cinematic? ? Cinematic.new(scene, battler).play(:dynamax, &change) : change.call
      sprite = scene.visual.battler_sprite(battler.bank, battler.position)
      sprite.pokemon = battler if sprite
      scene.visual.refresh_info_bar(battler)
      scene.display_message_and_wait(format(text(form ? :gmax : :start), battler.given_name))
      attack = action.attack
      attack.pj_use_max_move if attack.respond_to?(:pj_use_max_move)
    end

    # Fin du Dynamax (fin des 3 tours)
    # @param scene [Battle::Scene]
    # @param battler [PFM::PokemonBattler]
    def finish(scene, battler)
      battler.pj_end_dynamax
      sprite = scene.visual.battler_sprite(battler.bank, battler.position)
      sprite.pokemon = battler if sprite
      scene.visual.refresh_info_bar(battler)
      scene.display_message_and_wait(format(text(:end), battler.given_name))
    end

    # Attaque Max pour une attaque
    # @param battler [PFM::PokemonBattler]
    # @param move [Battle::Move]
    # @return [Array(Symbol, Integer)] attaque et puissance (0 : Gardomax)
    def max_for(battler, move)
      return [:max_guard, 0] if move.status?

      type = data_type(move.type).db_symbol
      gmax = (GMAX_FORM_MOVES[[battler.db_symbol, battler.pj_dmax_base_form.to_i]] || GMAX_MOVES[battler.db_symbol]) if battler.pj_gigantamax?
      return [gmax[1], gmax[2] || power_for(move, type)] if gmax && gmax[0] == type

      symbol = MAX_MOVES[type]
      return [symbol || :max_strike, power_for(move, type)]
    end

    # @param move [Battle::Move]
    # @param type [Symbol]
    # @return [Integer]
    def power_for(move, type)
      table = %i[fighting poison].include?(type) ? POWERS_LOW : POWERS
      base = move.power.to_i
      return table.first.last if base <= 0

      return (table.find { |limit, _| base <= limit }&.last) || (table == POWERS_LOW ? 100 : 150)
    end

    # Nom affiché quand le Dynamax est choisi (ou en cours)
    # @return [String, nil]
    def display_name(battler, move)
      gigantamax = battler.pj_gigantamax? || (!battler.pj_dynamax? && gmax_form(battler))
      symbol = if move.status?
                 :max_guard
               elsif gigantamax && (gmax = GMAX_FORM_MOVES[[battler.db_symbol, battler.form.to_i]] || GMAX_MOVES[battler.db_symbol]) &&
                     gmax[0] == data_type(move.type).db_symbol
                 gmax[1]
               else
                 MAX_MOVES[data_type(move.type).db_symbol] || :max_strike
               end
      return data_move(symbol).name
    rescue StandardError
      return nil
    end

    # @param scene [Battle::Scene]
    # @param battler [PFM::PokemonBattler]
    # @param move [Battle::Move]
    # @return [Battle::Move]
    def build_move(scene, battler, move)
      symbol, power = max_for(battler, move)
      max = symbol == :max_guard ? Battle::Move::PJMaxGuard.new(:max_guard, 1, 1, scene) : Battle::Move::PJMaxMove.new(symbol, 1, 1, scene)
      max.pj_setup(move, power) if max.respond_to?(:pj_setup)
      return max
    end
  end
  register(:dynamax, Dynamax)
end

module PFM
  class Pokemon
    # @return [Integer] niveau Dynamax (0 à 10)
    def pj_dynamax_level
      return @pj_dynamax_level || Gimmicks.setting('dynamax_level', Gimmicks::Dynamax::DEFAULT_LEVEL).to_i
    end

    # @param value [Integer]
    def pj_dynamax_level=(value)
      @pj_dynamax_level = value.to_i.clamp(0, 10)
    end

    # @return [Boolean] facteur Gigamax
    attr_accessor :pj_gmax_factor
  end

  class PokemonBattler
    # @return [Integer, nil] tours de Dynamax restants
    attr_accessor :pj_dmax_turns
    # @return [Integer, nil] forme avant le Gigamax
    attr_reader :pj_dmax_base_form

    # @return [Boolean]
    def pj_dynamax?
      return !@pj_dmax_mult.nil?
    end

    # @return [Boolean]
    def pj_gigantamax?
      return pj_dynamax? && !@pj_dmax_base_form.nil?
    end

    # @param gmax_form [Integer, nil] forme Gigamax
    def pj_dynamax!(gmax_form = nil)
      old_hp = hp
      level = (original || self).pj_dynamax_level
      @pj_dmax_turns = Gimmicks.setting('dynamax_turns', Gimmicks::Dynamax::TURNS).to_i
      if gmax_form
        @pj_dmax_base_form = @form
        @form = gmax_form
      end
      @pj_dmax_mult = 1.5 + 0.05 * level
      self.hp = (old_hp * @pj_dmax_mult).floor
    end

    def pj_end_dynamax
      return unless @pj_dmax_mult

      current = hp
      mult = @pj_dmax_mult
      @pj_dmax_mult = nil
      @pj_dmax_turns = nil
      @form = @pj_dmax_base_form if @pj_dmax_base_form
      @pj_dmax_base_form = nil
      self.hp = current > 0 ? [(current / mult).ceil, 1].max : 0
    end

    module PJGimmicksDynamax
      def max_hp
        value = super
        return @pj_dmax_mult ? (value * @pj_dmax_mult).floor : value
      end

      # Rappelé : fin du Dynamax
      def reset_states
        pj_end_dynamax if @pj_dmax_mult
        super
      end
    end
    prepend PJGimmicksDynamax
  end
end

module Battle
  module Actions
    class Attack
      module PJGimmicksDynamax
        # @param scene [Battle::Scene]
        # @param move [Battle::Move]
        # @param launcher [PFM::PokemonBattler]
        def initialize(scene, move, launcher, target_bank, target_position)
          super
          pj_use_max_move if launcher.respond_to?(:pj_dynamax?) && launcher.pj_dynamax?
        end

        # L'attaque Max (ou la capacité Z) utilise un PP de l'attaque de départ
        def execute
          base = @move.respond_to?(:pj_base_move) ? @move.pj_base_move : nil
          base.pp -= 1 if base && base.pp > 0 && !@pj_pp_used
          @pj_pp_used = true
          super
        end

        # Remplace l'attaque par l'attaque Max correspondante
        def pj_use_max_move
          return if @move.is_a?(Battle::Move::PJMaxMove) || @move.is_a?(Battle::Move::PJMaxGuard)
          return if @move.db_symbol == :struggle

          @move = Gimmicks::Dynamax.build_move(@scene, @launcher, @move)
        end
      end
      prepend PJGimmicksDynamax
    end
  end

  class Scene
    module PJGimmicksDynamax
      # Fin de tour : les Dynamax s'achèvent après 3 tours
      def on_battle_turn_end
        @logic.all_alive_battlers.each do |battler|
          next unless battler.respond_to?(:pj_dynamax?) && battler.pj_dynamax?

          battler.pj_dmax_turns -= 1
          Gimmicks::Dynamax.finish(self, battler) if battler.pj_dmax_turns <= 0
        end
        super
      end
    end
    prepend PJGimmicksDynamax
  end

  class Move
    # Gardomax : Abri qui marche à chaque tour
    class PJMaxGuard < Protect
      # @return [Battle::Move] attaque de départ
      attr_reader :pj_base_move

      def pj_setup(base, _power)
        @pj_base_move = base
      end

      private

      def pass_failure_check?(_user)
        return true
      end
    end
    Move.register(:s_max_guard, PJMaxGuard)

    # Attaque Max / G-Max : puissance et catégorie de l'attaque de départ, effet du type
    class PJMaxMove < Basic
      # @return [Battle::Move] attaque de départ
      attr_reader :pj_base_move

      def pj_setup(base, power)
        @pj_base_move = base
        @pj_power = power
        @pj_physical = base.physical?
      end

      def power
        return @pj_power || super
      end

      def real_base_power(user, target)
        return @pj_power || super
      end

      def physical?
        return @pj_physical.nil? ? super : @pj_physical
      end

      def special?
        return @pj_physical.nil? ? super : !@pj_physical
      end

      def effect_working?(user, actual_targets)
        return true
      end

      def deal_effect(user, actual_targets)
        effect = Gimmicks::Dynamax::EFFECTS[db_symbol]
        return true unless effect

        handler = logic.stat_change_handler
        case effect.first
        when :foes
          actual_targets.select(&:alive?).each { |target| handler.stat_change_with_process(effect[1], effect[2], target, user, self) }
        when :allies
          allies = logic.allies_of(user) + [user] rescue [user]
          allies.select(&:alive?).each { |ally| handler.stat_change_with_process(effect[1], effect[2], ally, user, self) } if effect[2] != 0
        when :weather
          logic.weather_change_handler.weather_change_with_process(effect[1], 5)
        when :terrain
          logic.fterrain_change_handler.fterrain_change_with_process(effect[1], 5)
        when :status
          actual_targets.select(&:alive?).each do |target|
            status = effect[1].sample(random: logic.generic_rng)
            logic.status_change_handler.status_change_with_process(status, target, user, self)
          end
        when :heal
          (logic.allies_of(user) + [user]).select(&:alive?).each { |ally| logic.damage_handler.heal(ally, ally.max_hp / 6) } rescue nil
        when :cure
          (logic.allies_of(user) + [user]).select(&:alive?).each(&:cure) rescue nil
        end
        return true
      rescue StandardError => e
        log_error("Attaque Max : #{e.message}") if respond_to?(:log_error, true)
        return true
      end
    end
  end
end

module BattleUI
  # Pokémon Dynamaxé : plus grand (le motif dynamax_pattern est posé par 00109 Motif Tera.rb)
  class PokemonSprite
    module PJGimmicksDynamax
      def pokemon=(pokemon)
        super
        pj_apply_dynamax_look
      end

      def reset_tone_status
        super
        pj_apply_dynamax_look
      end

      private

      def pj_apply_dynamax_look
        return unless @pokemon.respond_to?(:pj_dynamax?)

        if @pokemon.pj_dynamax?
          self.zoom = Gimmicks::Dynamax::SPRITE_ZOOM
          @pj_dmax_look = true
        elsif @pj_dmax_look
          self.zoom = 1
          @pj_dmax_look = false
        end
      end
    end
    prepend PJGimmicksDynamax
  end
end

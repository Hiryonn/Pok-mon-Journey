# Styles de combat : règles en combat
module StylesPLA
  # Puissance des capacités maîtrisées : [Puissant, Rapide] (écarts ajoutés à la puissance de base)
  SPECIAL_POWER = {
    octazooka: [35, -25], hidden_power: [20, -20], volt_tackle: [20, -20], steel_beam: [20, -20],
    chloroblast: [20, -20], spacial_rend: [20, -15], outrage: [30, -30], thrash: [30, -30], petal_dance: [30, -30],
    raging_fury: [30, -30]
  }.freeze

  class << self
    # @return [Array(PFM::PokemonBattler, Battle::Move), nil] capacité en cours (soins)
    attr_accessor :current
    # @return [Boolean] l'IA du plugin gimmicks choisit (les styles sont décidés à part)
    attr_accessor :ai_lock
  end

  module_function

  # @param battler [PFM::PokemonBattler]
  # @return [Symbol, nil] style du Pokémon (pris ou choisi pour ce tour)
  def style_of(battler)
    return nil unless battler.respond_to?(:pla_style)

    return battler.pla_style || battler.pla_pending
  end

  # @param battler [PFM::PokemonBattler]
  # @return [PFM::Pokemon, nil]
  def original_of(battler)
    return battler.respond_to?(:original) ? battler.original : battler
  end

  # @param battler [PFM::PokemonBattler]
  # @return [Boolean] Pokémon d'un autre dresseur que le joueur
  def trainer_pokemon?(battler)
    return false if battler.respond_to?(:from_party?) && battler.from_party?

    return !Gimmicks.wild?(battler)
  rescue StandardError
    return false
  end

  # @param battler [PFM::PokemonBattler]
  # @param move [Battle::Move, PFM::Skill]
  # @return [Boolean] le Pokémon maîtrise la capacité
  def battler_mastered?(battler, move)
    return false unless battler && move && enabled?
    return false unless masterable?(move.db_symbol)

    pokemon = original_of(battler)
    return false unless pokemon.respond_to?(:pj_mastered?)
    return true if pokemon.pj_mastered?(move.db_symbol)

    return setting('trainer_mastery') && trainer_pokemon?(battler) && pokemon.pj_level_mastery?(move.db_symbol)
  rescue StandardError
    return false
  end

  # @param user [PFM::PokemonBattler, nil]
  # @param move [Battle::Move]
  # @return [Symbol, nil] style qui change la capacité (le Pokémon est dans un style et la maîtrise)
  def move_style(user, move)
    return nil unless user.respond_to?(:pla_style) && (style = user.pla_style)

    return battler_mastered?(user, move) ? style : nil
  end

  # @param move [Battle::Move]
  # @param power [Integer] puissance de base
  # @param style [Symbol]
  # @return [Integer]
  def styled_power(move, power, style)
    strong, agile = SPECIAL_POWER[move.db_symbol] || power_deltas(power)
    return style == :strong ? power + strong : [power + agile, 5].max
  end

  def power_deltas(power)
    return [50, -30] if power >= 150
    return [30, -20] if power >= 120
    return [20, -20] if power >= 80
    return [15, -15] if power >= 60
    return [10, -10] if power >= 20

    return [5, -5]
  end

  # @param move [Battle::Move]
  # @param accuracy [Integer]
  # @return [Integer] précision en Style Puissant
  def strong_accuracy(move, accuracy)
    return accuracy if accuracy <= 0

    value = if move.status?
              accuracy >= 80 ? 100 : accuracy + 20
            elsif move.db_symbol == :seed_flare || accuracy >= 90
              100
            else
              accuracy + (accuracy >= 80 ? 10 : 15)
            end
    return [value, 100].min
  end

  # @param battler [PFM::PokemonBattler]
  # @return [Object] dresseur du Pokémon (son sac, comme le plugin gimmicks)
  def owner_of(battler)
    return battler.bag || "bank#{battler.bank}"
  end

  # @param battler [PFM::PokemonBattler]
  # @return [Boolean] au moins une capacité maîtrisée
  def any_mastered?(battler)
    return battler.moveset.any? { |move| battler_mastered?(battler, move) }
  end

  # Styles possibles pour un Pokémon
  # @param battler [PFM::PokemonBattler]
  # @param logic [Battle::Logic]
  # @param chosen [Array<Symbol>] mécaniques déjà choisies ce tour par le même dresseur
  # @return [Array<Symbol>]
  def available_kinds(battler, logic, chosen = [])
    return [] if ai_lock || !battler || !enabled? || battler.dead?
    return [] if battler.pla_style || battler.pj_gimmick || battler.mega_evolved?
    return [] if chosen.any? { |kind| KINDS.include?(kind) }
    return [] if logic.pla_cooldown(battler) > 0
    return [] if battler.respond_to?(:pj_dynamax?) && battler.pj_dynamax?
    return [] unless any_mastered?(battler)

    return KINDS.dup
  rescue StandardError => e
    log_error("Styles de combat : #{e.message}") if respond_to?(:log_error, true)
    return []
  end

  # Le Pokémon prend le style (action exécutée avant les attaques)
  # @param scene [Battle::Scene]
  # @param battler [PFM::PokemonBattler]
  # @param kind [Symbol]
  def activate(scene, battler, kind)
    battler.pla_style = kind
    battler.pla_pending = nil
    battler.pla_turns = [setting('turns').to_i, 1].max
    battler.pla_flinched = false
    scene.logic.pla_set_cooldown(battler, [setting('cooldown').to_i, 0].max)
    scene.display_message_and_wait(text(:enter, battler.given_name, text(kind)))
    Banner.new(scene, kind).play
    scene.visual.refresh_info_bar(battler)
    scene.display_message_and_wait(text(kind == :strong ? :slower : :sooner, battler.given_name))
  end

  # Fin de tour : durée des styles et attente des dresseurs
  # @param logic [Battle::Logic]
  def end_turn(logic)
    scene = logic.scene
    logic.all_battlers.to_a.compact.each do |battler|
      battler.pla_pending = nil
      next unless battler.pla_style

      battler.pla_turns -= 1
      next if battler.pla_turns > 0

      style = battler.pla_style
      battler.pla_style = nil
      battler.pla_flinched = false
      next if battler.dead? || battler.position.to_i < 0

      scene.visual.refresh_info_bar(battler)
      scene.display_message_and_wait(text(:faded, battler.given_name, text(style)))
    end
    logic.pla_cooldowns.each_key do |owner|
      next if logic.pla_cooldowns[owner] <= 0

      logic.pla_cooldowns[owner] -= 1
      next if logic.pla_cooldowns[owner] > 0

      player = owner.equal?($bag) || owner.to_s == 'bank0'
      scene.display_message_and_wait(text(player ? :again_player : :again_foe))
    end
  end
end

module PFM
  class PokemonBattler
    # @return [Symbol, nil] style en cours (:strong, :agile)
    attr_accessor :pla_style
    # @return [Symbol, nil] style choisi pour ce tour (pas encore pris)
    attr_accessor :pla_pending
    # @return [Boolean] déjà apeuré pendant ce Style Puissant
    attr_accessor :pla_flinched

    # @return [Integer] tours restants du style
    def pla_turns
      return @pla_turns ||= 0
    end

    attr_writer :pla_turns

    # @return [Boolean] tour où le Pokémon prend le style
    def pla_first_turn?
      return true if @pla_pending

      return @pla_style && pla_turns >= [StylesPLA.setting('turns').to_i, 1].max
    end

    module StylesPLAReset
      # Changement de Pokémon : le style s'arrête (l'attente du dresseur continue)
      def reset_states
        super
        @pla_style = nil
        @pla_pending = nil
        @pla_turns = 0
        @pla_flinched = false
      end
    end
    prepend StylesPLAReset
  end
end

module Battle
  class Logic
    # @return [Hash{Object => Integer}] tours d'attente de chaque dresseur
    def pla_cooldowns
      return @pla_cooldowns ||= Hash.new(0)
    end

    # @param battler [PFM::PokemonBattler]
    def pla_cooldown(battler)
      key = pla_cooldowns.keys.find { |owner| owner.equal?(StylesPLA.owner_of(battler)) || owner == StylesPLA.owner_of(battler) }
      return key ? pla_cooldowns[key] : 0
    end

    def pla_set_cooldown(battler, turns)
      owner = StylesPLA.owner_of(battler)
      key = pla_cooldowns.keys.find { |known| known.equal?(owner) || known == owner } || owner
      pla_cooldowns[key] = turns
    end

    module StylesPLALogic
      # Les styles choisis ce tour changent déjà l'ordre des actions
      def sort_actions
        @actions.each do |action|
          next unless action.is_a?(Actions::PJGimmick) && StylesPLA::KINDS.include?(action.kind)

          action.user.pla_pending = action.kind
        end
        super
      end

    end
    prepend StylesPLALogic

    # Fin de tour : après les effets de fin de tour (météo, Restes…), avant les remplacements
    class EndTurnHandler
      module StylesPLAEndTurn
        def process_events
          super
          StylesPLA.end_turn(@logic) if @logic.can_battle_continue?
        rescue StandardError => e
          log_error("Styles de combat : #{e.message}") if respond_to?(:log_error, true)
        end
      end
      prepend StylesPLAEndTurn
    end

    # Changements de stats des capacités maîtrisées : un cran de plus (Puissant) ou de moins (Rapide)
    class StatChangeHandler
      module StylesPLAStats
        def handle_stat_change_events(stat, power, target, launcher, skill)
          power = super
          return power if power == 0 || !launcher || !skill
          return power unless StylesPLA.current && StylesPLA.current.last.equal?(skill)

          case StylesPLA.move_style(launcher, skill)
          when :strong then return power > 0 ? [power + 1, 6].min : [power - 1, -6].max
          when :agile then return power > 0 ? [power - 1, 1].max : [power + 1, -1].min
          end
          return power
        end
      end
      prepend StylesPLAStats
    end

    # Style Rapide : jamais apeuré
    class StatusChangeHandler
      module StylesPLAFlinch
        def status_appliable?(status, target, launcher = nil, skill = nil)
          return false if status == :flinch && target.respond_to?(:pla_style) && target.pla_style == :agile

          return super
        end
      end
      prepend StylesPLAFlinch
    end

    # Soins des capacités maîtrisées
    class DamageHandler
      module StylesPLAHeal
        def heal(target, hp, test_heal_block: true, animation_id: nil, &block)
          user, move = StylesPLA.current
          if user && move&.status? && (style = StylesPLA.move_style(user, move))
            factor = if style == :agile
                       target == user ? 0.6 : 1.0
                     elsif target == user
                       1.4
                     else
                       hp >= target.max_hp / 2 ? 1.5 : 4 / 3.0
                     end
            hp = [(hp * factor).round, 1].max
          end
          return super(target, hp, test_heal_block: test_heal_block, animation_id: animation_id, &block)
        end
      end
      prepend StylesPLAHeal
    end
  end

  class Move
    module StylesPLAMove
      def proceed(user, target_bank, target_position)
        previous = StylesPLA.current
        StylesPLA.current = [user, self]
        result = super
        pla_agile_flinch(user)
        return result
      ensure
        StylesPLA.current = previous
      end

      # Puissant : -5, Rapide : +5 au premier tour (pour tout le tour du Pokémon, comme dans le plugin d'origine)
      def priority(user = nil)
        value = super
        return value unless user && (style = StylesPLA.style_of(user))
        return StylesPLA::NEUTRAL_PRIORITY - 5 if style == :strong
        return StylesPLA::NEUTRAL_PRIORITY + 5 if style == :agile && user.pla_first_turn?

        return value
      end

      # Puissant : effets secondaires plus fréquents
      def effect_chance
        value = super
        return value unless StylesPLA.move_style(@user, self) == :strong

        raw = data.effect_chance.to_i
        return value if raw <= 0 || raw >= 100
        return 100 if raw >= 50

        return [raw + (db_symbol == :dire_claw ? 30 : 20), 100].min
      end

      # Puissant : plus précis
      def chance_of_hit(user, target)
        value = super
        return value unless StylesPLA.move_style(user, self) == :strong && (base = accuracy) > 0

        return value * StylesPLA.strong_accuracy(self, base) / base.to_f
      end

      # Puissant : contrecoup plus fort (1/4 et 1/3 -> 1/2, 1/2 -> 3/4)
      def recoil_factor
        value = super
        return value unless StylesPLA.move_style(@user, self) == :strong

        return value >= 3 ? 2 : value * 2 / 3.0
      end

      # Puissant : absorbe plus (1/2 -> 3/4)
      def drain_factor
        value = super
        return value unless StylesPLA.move_style(@user, self) == :strong

        return [value / 1.5, 1].max
      end

      # PP en plus pendant un style
      def decrease_pp(user, targets)
        before = pp
        super
        return unless pp < before && StylesPLA.move_style(user, self)

        self.pp = [pp - StylesPLA.setting('extra_pp').to_i, 0].max
      end

      private

      # Puissance des capacités maîtrisées
      def calc_base_power(user, target)
        value = super
        base = power
        return value if base <= 1 || status? || !(style = StylesPLA.move_style(user, self))

        return [(value * StylesPLA.styled_power(self, base, style) / base.to_f).round, 1].max
      end

      # Un Pokémon en Style Rapide qui frappe un Pokémon en Style Puissant avant qu'il agisse l'apeure (une fois)
      def pla_agile_flinch(user)
        return unless user.respond_to?(:pla_style) && user.pla_style == :agile && !status?

        logic.foes_of(user).each do |target|
          next if target.dead? || target.pla_style != :strong || target.pla_flinched
          next if target.move_history.any?(&:current_turn?)

          hit = target.damage_history.last
          next unless hit&.current_turn? && hit.launcher == user && hit.move.equal?(self)

          target.pla_flinched = true
          logic.status_change_handler.status_change_with_process(:flinch, target, user, self)
        end
      rescue StandardError => e
        log_error("Styles de combat : #{e.message}") if respond_to?(:log_error, true)
      end
    end
    prepend StylesPLAMove
  end

  module Actions
    class PJGimmick
      module StylesPLAAction
        def execute
          return super unless StylesPLA::KINDS.include?(@kind)
          return if @user.dead? || @user.position.to_i < 0 || !@scene.logic.battler(@user.bank, @user.position).equal?(@user)

          StylesPLA.activate(@scene, @user, @kind)
        end
      end
      prepend StylesPLAAction
    end
  end
end

# Les styles rejoignent les mécaniques de l'onglet « ACTION » (sans les règles « une fois par combat »)
module Gimmicks
  class State
    module StylesPLAState
      def available(battler, chosen = [])
        list = super
        return list unless battler

        list = [] if battler.pla_style
        return list + StylesPLA.available_kinds(battler, @logic, chosen)
      end
    end
    prepend StylesPLAState
  end

  # Seules les capacités maîtrisées peuvent être lancées avec un style
  class StyleHandler
    def possible?(battler, logic)
      return StylesPLA.available_kinds(battler, logic).any?
    end

    def selectable?(battler, move)
      return StylesPLA.battler_mastered?(battler, move)
    end

    def execute(scene, battler, action)
      StylesPLA.activate(scene, battler, action.kind)
    end
  end
  StylesPLA::KINDS.each { |kind| register(kind, StyleHandler.new) }

  class << self
    module StylesPLAText
      def text(key)
        return StylesPLA.text(key) if StylesPLA::TEXTS.key?(key) && (StylesPLA::KINDS.include?(key) || key.to_s.end_with?('_short'))

        return super
      end

      # Icône des styles dans la roue des mécaniques
      def wheel_icon(kind, battler)
        return StylesPLA.file("icon_#{kind}") if StylesPLA::KINDS.include?(kind)

        return super
      end
    end
    prepend StylesPLAText
  end
end

module Battle
  module AI
    class Base
      module StylesPLAAI
        def trigger
          @pla_chosen = []
          return super
        end

        private

        def battle_action_for(pokemon)
          StylesPLA.ai_lock = true
          result = super
          StylesPLA.ai_lock = false
          return result unless result.is_a?(Actions::Attack) && StylesPLA.setting('ai')

          kind = StylesPLA::AI.choice(@scene.logic, pokemon, result.move, @pla_chosen || [])
          return result unless kind

          (@pla_chosen ||= []) << StylesPLA.owner_of(pokemon)
          return [Actions::PJGimmick.new(@scene, pokemon, kind, result), result]
        rescue StandardError => e
          log_error("Styles de combat : #{e.message}") if respond_to?(:log_error, true)
          return result
        ensure
          StylesPLA.ai_lock = false
        end
      end
      prepend StylesPLAAI
    end
  end
end

# Choix du style par l'IA (d'après le plugin d'origine)
module StylesPLA
  module AI
    module_function

    # @param logic [Battle::Logic]
    # @param battler [PFM::PokemonBattler]
    # @param move [Battle::Move] attaque choisie
    # @param chosen [Array<Object>] dresseurs qui ont déjà choisi un style ce tour
    # @return [Symbol, nil]
    def choice(logic, battler, move, chosen)
      return nil if chosen.any? { |owner| owner.equal?(StylesPLA.owner_of(battler)) }
      return nil unless StylesPLA.available_kinds(battler, logic).any? && StylesPLA.battler_mastered?(battler, move)

      rng = logic.generic_rng
      strong, agile = move_scores(battler)
      strong += 20 if move.relative_priority > 0
      foe_scores(logic, battler).each do |s, a|
        strong += s
        agile += a
      end
      strong -= rng.rand(0..20)
      agile -= rng.rand(0..20)
      return nil if strong <= 0 && agile <= 0
      return strong > agile ? :strong : :agile if strong != agile

      return rng.rand(2) == 0 ? :strong : :agile
    end

    def move_scores(battler)
      strong = agile = 0
      battler.moveset.each do |m|
        next unless StylesPLA.battler_mastered?(battler, m)

        strong += 10 if m.relative_priority != 0
        strong += 10 if m.power > 1
        accuracy = m.accuracy
        strong += accuracy <= 50 ? 40 : (accuracy <= 75 ? 30 : (accuracy <= 85 ? 20 : 10)) if accuracy > 0 && accuracy < 100
        chance = m.data.effect_chance.to_i
        strong += chance <= 10 ? 10 : (chance <= 20 ? 20 : (chance <= 30 ? 30 : 40)) if chance > 0 && chance < 100
        strong += 10 if m.battle_stage_mod.any?
        if m.recoil?
          strong -= 20
          agile += 10
        end
        if m.heal?
          strong += 10
          agile += 10
        end
      end
      return strong, agile
    end

    # @return [Array<Array(Integer, Integer)>] [Puissant, Rapide] pour chaque adversaire
    def foe_scores(logic, battler)
      trick_room = logic.terrain_effects.has?(:trick_room)
      return logic.foes_of(battler).select(&:alive?).map do |foe|
        strong = agile = 0
        foe_style = StylesPLA.style_of(foe)
        if foe_style == :strong
          agile += 20
        elsif foe_style == :agile
          agile += battler.spd > foe.spd ? 20 : -10
        elsif (battler.spd < foe.spd) != trick_room
          agile += 30
        else
          agile -= 10
        end
        agile += 20 if foe.hp <= foe.max_hp / 4
        gap = battler.level - foe.level
        if gap >= 30
          strong = agile = -999
        elsif gap >= 20
          agile = -999
        end
        [strong, agile]
      end
    end
  end
end

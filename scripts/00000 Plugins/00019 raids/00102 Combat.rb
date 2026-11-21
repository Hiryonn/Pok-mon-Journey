# Raids : combat de raid (lancement, compteurs de tours et de K.O., bouclier, actions en plus du boss, capture)
module Raids
  module_function

  # Raid du combat en cours
  # @param logic [Battle::Logic, nil]
  # @return [Raids::Rules, nil]
  def rules_of(logic)
    return logic&.battle_info.respond_to?(:pj_raid) ? logic.battle_info.pj_raid : nil
  end

  # @param logic [Battle::Logic]
  # @return [PFM::PokemonBattler, nil]
  def boss_of(logic)
    return logic.battler(1, 0)
  end

  # @param battler [PFM::PokemonBattler]
  def boss?(battler, logic)
    return battler && battler.bank == 1 && rules_of(logic) && battler.equal?(boss_of(logic))
  end

  # Pokémon qui combattent (les premiers de l'équipe en état de se battre)
  # @param size [Integer]
  # @return [Array<PFM::Pokemon>]
  def participants(size)
    return $actors.reject(&:dead?).first(size)
  end

  # Lance un combat de raid
  # @param rules [Rules] raid complet (rules.pokemon = boss)
  # @param after [Proc, nil] appelé à la fin du combat avec le résultat (:win, :caught, :lost)
  def start_battle(rules, &after)
    rules.complete
    team = rules.adventure ? $actors.dup : participants(rules.size)
    rules.size = [team.size, 1].max.clamp(1, 3)
    rules.after = after
    style = style_data(rules.style)
    background = rules.background || fetch(style, 'background')
    bgm = Array(fetch(style, 'bgm'))
    track = rules.rank >= 6 || rules.final_boss ? (bgm[1] || bgm[0]) : bgm[0]
    info = ::Battle::Logic::BattleInfo.new(background_name: background.to_s, battle_bgm: track && !track.empty? ? track : nil)
    _party, name, klass, sprite, bag = info.player_basic_info
    info.add_party(0, team, name, klass, sprite, bag)
    info.add_party(1, [rules.pokemon])
    info.vs_type = rules.size
    info.battle_id = 1
    info.pj_raid = rules
    $game_temp.battle_can_lose = true
    if $scene.is_a?(::Scene_Map)
      Graphics.freeze
      $scene = ::Battle::Scene.new(info)
      Yuki::FollowMe.set_battle_entry
    else
      $scene.call_scene(::Battle::Scene, info)
    end
  end

  # --- Compteurs ---------------------------------------------------------------------------------------------------
  # @param scene [Battle::Scene]
  # @param amount [Integer]
  def change_turns(scene, amount)
    rules = rules_of(scene.logic)
    return unless rules && rules.turn_count

    rules.turn_count = [rules.turn_count + amount, 0].max
    scene.visual.pj_raid_hud&.refresh
    return if rules.turn_count > 0 || scene.logic.battle_result >= 0

    boss = boss_of(scene.logic)
    scene.display_message_and_wait(format(t('L’énergie autour de %s devient incontrôlable !', 'The energy around %s grew out of control!'), boss.given_name))
    blown_out(scene)
  end

  # @param scene [Battle::Scene]
  # @param amount [Integer]
  def change_kos(scene, amount, message: true)
    rules = rules_of(scene.logic)
    return unless rules && rules.ko_count

    rules.ko_count = [rules.ko_count + amount, 0].max
    rules.adventure[:hearts] = rules.ko_count if rules.adventure
    scene.visual.pj_raid_hud&.refresh
    return if amount > 0 || !message || scene.logic.battle_result >= 0

    name = boss_of(scene.logic).given_name
    case rules.ko_count
    when 0 then text = t('L’énergie autour de %s devient incontrôlable !', 'The energy around %s grew out of control!')
    when 1 then text = t('L’énergie autour de %s devient trop forte pour tenir !', 'The energy around %s is growing too strong to withstand!')
    else text = t('L’énergie autour de %s se renforce !', 'The energy around %s is growing stronger!')
    end
    scene.display_message_and_wait(format(text, name))
    blown_out(scene) if rules.ko_count <= 0
  end

  # Le joueur est expulsé de l'antre (combat perdu, sans être mis K.O.)
  def blown_out(scene)
    scene.display_message_and_wait(t('Vous êtes expulsé de l’antre !', 'You were blown out of the den!'))
    rules_of(scene.logic).outcome = :lost
    scene.logic.battle_result = 3
  end

  # --- Bouclier ------------------------------------------------------------------------------------------------------
  # @param scene [Battle::Scene]
  # @param boss [PFM::PokemonBattler]
  def start_shield(scene, boss)
    rules = rules_of(scene.logic)
    return if rules.shield_started || rules.shield_hp.to_i <= 0 || boss.dead?

    rules.shield_started = true
    rules.shield = rules.shield_hp
    scene.display_message_and_wait(format(t('L’énergie se concentre autour de %s !', 'Energy has begun to gather around %s!'), boss.given_name))
    boss.cure if boss.status != 0
    scene.visual.pj_raid_hud&.flash
    scene.visual.pj_raid_hud&.refresh
    scene.display_message_and_wait(format(t('Une mystérieuse barrière protège %s !', 'A mysterious barrier appeared in front of %s!'), boss.given_name))
  end

  # @return [Boolean] le bouclier est levé
  def shield_up?(logic)
    rules = rules_of(logic)
    return rules && rules.shield.to_i > 0
  end

  # Barres cassées par une attaque
  # @param user [PFM::PokemonBattler]
  # @param skill [Battle::Move]
  # @param rules [Rules]
  def shield_damage(user, skill, rules)
    amount = 1
    amount += 1 if rules.cheer_offense3
    case rules.style
    when :basic
      amount += 1 if skill.respond_to?(:effectiveness) && skill.effectiveness.to_f > 1
    when :ultra
      amount += 2 if skill.respond_to?(:pj_base_move)
    when :max
      if user.respond_to?(:pj_dynamax?) && user.pj_dynamax?
        amount += 1
        amount += 1 if user.pj_gigantamax? && skill.db_symbol.to_s.start_with?('gmax_')
      end
    when :tera
      if user.respond_to?(:pj_tera?) && user.pj_tera?
        amount += 1 if user.pj_tera == skill.type
        amount += 1 if [user.type1, user.type2].include?(skill.type)
      end
    end
    return amount
  end

  # @param scene [Battle::Scene]
  # @param boss [PFM::PokemonBattler]
  # @param amount [Integer]
  def hit_shield(scene, boss, amount)
    rules = rules_of(scene.logic)
    return unless rules.shield.to_i > 0

    rules.shield = [rules.shield - amount, 0].max
    scene.visual.pj_raid_hud&.refresh
    return if rules.shield > 0

    scene.display_message_and_wait(t('La barrière mystérieuse disparaît !', 'The mysterious barrier disappeared!'))
    loss = [boss.max_hp / 8, boss.hp - 1].min
    scene.logic.damage_handler.damage_change(loss, boss) if loss > 0
    %i[dfe dfs].each { |stat| scene.logic.stat_change_handler.stat_change_with_process(stat, -2, boss) }
  end

  # --- Actions en plus du boss ---------------------------------------------------------------------------------------
  # Seuils des actions : part des PV ou des tours restants
  ACTION_PHASES = { reset_boosts: 0.4, reset_drops: 0.6, drain_cheer: 0.5 }.freeze

  # @param scene [Battle::Scene]
  def extra_actions(scene)
    rules = rules_of(scene.logic)
    boss = boss_of(scene.logic)
    return if !rules || !boss || boss.dead? || scene.logic.battle_result >= 0

    Array(rules.extra_actions).dup.each do |action|
      mod = ACTION_PHASES[action.to_sym] || 0.5
      next unless boss.hp <= (boss.max_hp * mod).round || (rules.max_turns.to_i > 0 && rules.turn_count <= (rules.max_turns * mod).round)

      rules.extra_actions.delete(action)
      scene.visual.pj_raid_hud&.flash
      send(:"action_#{action}", scene, boss)
    end
  end

  def action_reset_drops(scene, boss)
    scene.display_message_and_wait(format(t('%s se débarrasse des effets négatifs !', '%s removed negative effects from itself!'), boss.given_name))
    boss.cure if boss.status != 0
    boss.battle_stage.map! { |stage| [stage, 0].max }
  end

  def action_reset_boosts(scene, boss)
    scene.display_message_and_wait(format(t('%s annule les hausses de stats de votre équipe !', '%s nullified the stat changes affecting your side!'), boss.given_name))
    scene.logic.alive_battlers(0).each { |battler| battler.battle_stage.map! { |stage| [stage, 0].min } }
  end

  def action_drain_cheer(scene, boss)
    rules = rules_of(scene.logic)
    scene.display_message_and_wait(format(t('%s affaiblit les encouragements !', '%s reduced the effectiveness of cheering!'), boss.given_name))
    rules.cheer_level = [rules.cheer_level.to_i - 1, 0].max
    scene.visual.pj_raid_hud&.refresh
  end

  # Le boss est affaibli : il attaque deux fois
  def double_attack_phase?(rules, boss)
    return false unless setting('double_attack')
    return true if boss.hp <= (boss.max_hp * 0.4).round

    return rules.max_turns.to_i > 0 && rules.turn_count <= (rules.max_turns * 0.4).round
  end

  # Attaque supplémentaire (zone) quand le bouclier est levé
  def spread_attack_phase?(rules, logic)
    return false if rules.shield.to_i <= 0 || Array(rules.spread_moves).empty?

    return logic.generic_rng.rand(rules.shield_hp.to_i) < rules.shield
  end

  # @param scene [Battle::Scene]
  # @param boss [PFM::PokemonBattler]
  # @param symbol [Symbol]
  # @param target [PFM::PokemonBattler, nil]
  def use_extra_move(scene, boss, symbol, target = nil)
    data = data_move(symbol)
    return if data.db_symbol == :__undef__

    move = ::Battle::Move[data.battle_engine_method].new(data.db_symbol, data.pp, data.pp, scene)
    target ||= scene.logic.alive_battlers(0).sample(random: scene.logic.generic_rng)
    return unless target

    action = ::Battle::Actions::Attack.new(scene, move, boss, target.bank, target.position)
    action.pj_raid_extra = true
    action.execute
  end

  # --- Début du combat -------------------------------------------------------------------------------------------------
  # Boss Dynamax / Téracristallisé / cristal Z, interface, mécaniques du joueur
  # @param scene [Battle::Scene]
  def setup_battle(scene)
    rules = rules_of(scene.logic)
    boss = boss_of(scene.logic)
    return unless rules && boss

    rules.cheer_level ||= 0
    case rules.style
    when :max
      if boss.respond_to?(:pj_dynamax!)
        form = defined?(::Gimmicks::Dynamax) && boss.original.pj_gmax_factor ? ::Gimmicks::Dynamax.gmax_form(boss) : nil
        hp_rate = boss.hp_rate
        boss.pj_dynamax!(form)
        boss.hp = (boss.max_hp * hp_rate).round.clamp(1, boss.max_hp)
        boss.pj_dmax_turns = 999
        boss.pj_gimmick = :dynamax if boss.respond_to?(:pj_gimmick=)
      end
    when :tera
      if boss.respond_to?(:pj_terastallize!)
        type = ::Gimmicks::Tera.tera_type(boss)
        boss.pj_terastallize!(::Gimmicks::Tera.type_id(type))
        boss.pj_gimmick = :tera if boss.respond_to?(:pj_gimmick=)
      end
    when :ultra
      ::Gimmicks.save_data[:wild] = [:zmove] if defined?(::Gimmicks) && ::Gimmicks.respond_to?(:save_data)
    end
    sprite = scene.visual.battler_sprite(boss.bank, boss.position)
    sprite.pokemon = boss if sprite
    scene.visual.pj_raid_start
  end

  # Fin d'un tour : Pokémon K.O. remis sur pied, compteur de tours, encouragement, actions du boss
  # @param scene [Battle::Scene]
  def turn_end(scene)
    rules = rules_of(scene.logic)
    logic = scene.logic
    return if logic.battle_result >= 0

    revive_fainted(scene)
    change_turns(scene, -1)
    return if logic.battle_result >= 0

    if rules.cheers && rules.cheer_level < 3
      rules.cheer_level += 1
      text = rules.cheer_level < 3 ? t('Le niveau d’encouragement monte !', 'Your cheer level is building!') : t('Le niveau d’encouragement est au maximum !', 'Your cheer level is at its maximum!')
      scene.display_message_and_wait(text)
      scene.visual.pj_raid_hud&.refresh
    end
    rules.cheer_used = false
    extra_actions(scene)
    boss = boss_of(logic)
    boss.pj_dmax_turns = 999 if rules.style == :max && boss.respond_to?(:pj_dynamax?) && boss.pj_dynamax?
    recharge_z(scene, boss) if rules.style == :ultra
    tick_cheer_effects(scene)
  end

  # Le boss recharge son énergie Z (tous les z_power_every tours)
  def recharge_z(scene, boss)
    every = [setting('z_power_every').to_i, 1].max
    return unless $game_temp.battle_turn.to_i % every == 0 && boss.pj_gimmick == :zmove

    used = scene.logic.pj_gimmicks.instance_variable_get(:@used)
    used[:zmove]&.delete_if { |owner| owner.equal?(scene.logic.pj_gimmicks.send(:owner_of, boss)) }
    boss.pj_gimmick = nil
    scene.visual.pj_raid_hud&.flash
    scene.display_message_and_wait(format(t('%s recharge son énergie Z !', '%s replenished its Z-Power with a surge of energy!'), boss.given_name))
  end

  # Les Pokémon du joueur K.O. reviennent (fin du tour)
  def revive_fainted(scene)
    scene.logic.all_battlers.each do |battler|
      next unless battler.bank == 0 && battler.dead? && battler.position.to_i.between?(0, scene.battle_info.vs_type - 1)

      battler.hp = battler.max_hp
      battler.status = 0
      sprite = scene.visual.battler_sprite(battler.bank, battler.position)
      if sprite
        sprite.pokemon = battler
        sprite.visible = true
        sprite.opacity = 255
        sprite.go_in
      end
      scene.visual.show_info_bar(battler)
      scene.visual.refresh_info_bar(battler)
      scene.display_message_and_wait(format(t('%s se remet de sa défaite et retourne au combat !', '%s recovered from fainting and is back in the fight!'), battler.given_name))
    end
  end

  # --- Fin du combat -------------------------------------------------------------------------------------------------------
  # Capture du boss vaincu (balle choisie dans le sac, réussite assurée)
  # @param scene [Battle::Scene]
  # @return [Boolean] capturé
  def offer_capture(scene)
    rules = rules_of(scene.logic)
    boss = boss_of(scene.logic)
    return false unless rules && boss && rules.capture != false

    ball = rules.adventure ? :poke_ball : choose_ball(scene, boss)
    return false unless ball

    $bag.remove_item(ball, 1) unless rules.adventure
    capture_bgm = fetch(style_data(rules.style), 'capture_bgm').to_s
    $game_system.bgm_play(RPG::AudioFile.new(capture_bgm)) unless capture_bgm.empty?
    boss.pj_end_dynamax if boss.respond_to?(:pj_end_dynamax)
    boss.pj_end_tera if boss.respond_to?(:pj_end_tera)
    reset_boss(boss.original, rules)
    boss.instance_variable_set(:@pj_raid_hp_mult, nil)
    boss.hp = boss.max_hp
    boss.status = 0
    scene.battle_info.caught_pokemon = boss
    if rules.adventure
      boss.copy_properties_back_to_original
      rules.adventure[:captures] << boss.original
      scene.display_message_and_wait(format(t('Vous avez capturé %s !', 'You caught %s!'), boss.original.name))
    else
      scene.send(:give_pokemon_procedure, boss, data_item(ball))
    end
    rules.outcome = :caught
    return true
  end

  # @return [Symbol, nil] Poké Ball choisie
  def choose_ball(scene, boss)
    balls = []
    each_data_item { |item| balls << item.db_symbol if item.is_a?(Studio::BallItem) && $bag.contain_item?(item.db_symbol) }
    if balls.empty?
      scene.display_message_and_wait(format(t('%s est affaibli… mais vous n’avez pas de Poké Ball !', '%s is weak... but you have no Poké Balls!'), boss.given_name))
      return nil
    end
    first = balls.include?(:poke_ball) ? [:poke_ball] : []
    balls = (first + (balls - first)).first(6)
    names = balls.map { |ball| format('%s (x%d)', item_name(ball), $bag.item_quantity(ball)) }
    choice = scene.display_message_and_wait(format(t('%s est affaibli ! Lancer une Poké Ball ?', '%s is weak! Throw a Poké Ball?'), boss.given_name),
                                            names.size + 1, *names, t('Ne pas capturer', 'Don’t catch'))
    return balls[choice.to_i] if choice.to_i < balls.size

    return nil
  end
end

module Battle
  class Logic
    class BattleInfo
      # @return [Raids::Rules, nil] raid du combat
      attr_accessor :pj_raid
    end

    module RaidsLogic
      # Équipe du joueur K.O. mais compteur de K.O. pas à 0 : le combat continue (ils reviennent en fin de tour)
      def can_battle_continue?
        rules = Raids.rules_of(self)
        return super unless rules && @battle_result < 0

        boss = Raids.boss_of(self)
        return super if boss.nil? || boss.dead?
        return true if alive_battlers(0).empty? && rules.ko_count.to_i > 0

        return super
      end

      def battle_phase_end
        Raids.turn_end(@scene) if Raids.rules_of(self)
        super
      end
    end
    prepend RaidsLogic

    class ExpHandler
      module RaidsNoExp
        def distribute_exp_grouped(enemies)
          rules = Raids.rules_of(@logic)
          return [] if rules && (Raids.setting('no_exp') || rules.adventure)

          return super
        end
      end
      prepend RaidsNoExp
    end

    class DamageHandler
      module RaidsDamage
        def damage_change(hp, target, launcher = nil, skill = nil, &messages)
          rules = Raids.rules_of(@logic)
          return super unless rules

          boss = Raids.boss?(target, @logic)
          if boss && skill && rules.shield.to_i > 0
            hp = [(hp * 0.05).ceil, 1].max
            hp = [hp, target.hp - 1].min if target.hp > 1
          elsif boss && !rules.shield_started && rules.shield_hp.to_i > 0
            cap = (target.max_hp * Raids.setting('shield_threshold').to_i / 100.0).floor
            hp = [hp, target.hp - cap].min if target.hp > cap
            hp = 0 if hp < 0
          end
          if target.bank == 0 && rules.cheer_defense3 && target.hp > 1 && hp >= target.hp
            hp = target.hp - 1
          end
          super(hp, target, launcher, skill, &messages)
          raids_after_damage(hp, target, launcher, skill, rules, boss)
        end

        private

        def raids_after_damage(_hp, target, launcher, skill, rules, boss)
          scene = @scene
          if boss
            return if target.dead?

            cap = (target.max_hp * Raids.setting('shield_threshold').to_i / 100.0).floor
            if !rules.shield_started && rules.shield_hp.to_i > 0 && target.hp <= cap
              Raids.start_shield(scene, target)
            elsif rules.shield.to_i > 0 && skill && launcher && launcher.bank == 0 && !skill.status?
              Raids.hit_shield(scene, target, Raids.shield_damage(launcher, skill, rules))
            end
          elsif target.bank == 0 && target.dead?
            Raids.change_kos(scene, -1)
          end
        end
      end
      prepend RaidsDamage
    end
  end

  module Actions
    class Attack
      # @return [Boolean] attaque en plus du boss (pas de double attaque derrière)
      attr_accessor :pj_raid_extra

      module RaidsAttack
        def execute
          rules = Raids.rules_of(@scene.logic)
          boss = rules && !@pj_raid_extra && Raids.boss?(@launcher, @scene.logic) && @launcher.alive? ? @launcher : nil
          return super unless boss

          if Raids.spread_attack_phase?(rules, @scene.logic)
            @scene.visual.pj_raid_hud&.flash
            Raids.use_extra_move(@scene, boss, Array(rules.spread_moves).sample(random: @scene.logic.generic_rng).to_sym)
            return unless @scene.logic.can_battle_continue? && boss.alive?
          end
          result = super
          boss.moveset.each { |move| move.pp = move.ppmax if move.respond_to?(:pp=) }
          if @scene.logic.can_battle_continue? && boss.alive? && Raids.double_attack_phase?(rules, boss)
            others = boss.moveset.reject { |move| move.db_symbol == @move.db_symbol || move.db_symbol == :__undef__ }
            others = boss.moveset if others.empty?
            move = others.sample(random: @scene.logic.generic_rng)
            Raids.use_extra_move(@scene, boss, move.db_symbol) if move
          end
          return result
        end
      end
      prepend RaidsAttack
    end
  end

  class Scene
    module RaidsScene
      def battle_end
        rules = Raids.rules_of(@logic)
        return super unless rules && !@pj_raid_ended

        @pj_raid_ended = true
        boss = Raids.boss_of(@logic)
        if @logic.battle_result == 0 && boss&.dead?
          rules.outcome = :win
          Raids.stats[:won] += 1
          Raids.offer_capture(self)
        else
          rules.outcome ||= :lost
          if boss && !boss.dead?
            flee = Raids.local(Raids.fetch(Raids.style_data(rules.style), 'flee'))
            display_message_and_wait(format(flee, boss.given_name)) unless flee.empty?
          end
        end
        heal_after(rules)
        rules.after&.call(rules.outcome, self)
        super
      end

      private

      def heal_after(rules)
        return if rules.adventure || !Raids.setting('heal_after')

        Raids.participants(6).each(&:cure)
      end

      # Premier choix du joueur : préparation du raid
      def player_action_choice
        if Raids.rules_of(@logic) && !@pj_raid_ready
          @pj_raid_ready = true
          Raids.setup_battle(self)
        end
        super
      end

      # La fuite devient l'encouragement
      def player_action_choice_internal(choice, forced_action = nil)
        return super unless choice == :flee && Raids.rules_of(@logic)

        pj_raid_cheer_choice
      end

      # Pas de Poké Ball pendant le raid
      def catch_prevented(item_wrapper)
        return super unless Raids.rules_of(@logic)

        message_window.blocking = true
        message_window.wait_input = true
        display_message_and_wait(Raids.t('Impossible ! L’énergie du raid protège le Pokémon.', 'It’s no good! The raid energy protects the Pokémon.'))
        $bag.add_item(item_wrapper.item.db_symbol, 1)
        @next_update = :player_action_choice
        return true
      end

      # Aventure : le combat rend la main à la carte
      def return_to_last_scene
        rules = Raids.rules_of(@logic)
        return super unless rules&.adventure

        @running = false
      end
    end
    prepend RaidsScene
  end
end

# Mécanique du style du raid : bloquée pour le joueur tant que l'encouragement du style n'a pas servi
if defined?(Gimmicks::State)
  module Gimmicks
    class State
      module RaidsLock
        def available?(kind, battler)
          rules = Raids.rules_of(@logic)
          if rules && battler.bank == 0 && Raids::GIMMICK_OF[rules.style] == kind && !rules.gimmick_unlocked
            return false
          end
          return false if rules && battler.bank == 1 && kind != :zmove

          return super
        end
      end
      prepend RaidsLock
    end
  end
end

module PFM
  class PokemonBattler
    module RaidsCopy
      def copy_properties
        super
        @pj_raid_hp_mult = @original.pj_raid_hp_mult if @original.respond_to?(:pj_raid_hp_mult)
      end
    end
    prepend RaidsCopy
  end
end

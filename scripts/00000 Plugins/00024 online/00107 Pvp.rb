# encoding: utf-8
# Jeu en ligne — étape 2 : combat en temps réel entre deux joueurs (interface PSDK de la synchronisation).
# ATTENTION : cette partie dépend de détails internes du moteur de combat de PSDK (noms d'étapes, d'attributs, de classes d'actions)
# qui n'ont pas pu être vérifiés hors du jeu. Tout est protégé : en cas d'incompatibilité, le combat est interrompu proprement
# (Online::Pvp::Unsupported) et le message d'erreur est écrit dans le log pour pouvoir corriger.
module Online
  module Pvp
    class Unsupported < StandardError; end

    module_function

    # @return [Online::Lockstep, nil] combat en ligne de cette scène
    def of(object)
      info = object.respond_to?(:battle_info) ? object.battle_info : object
      return info.respond_to?(:pj_pvp) ? info.pj_pvp : nil
    end

    # Décisions de mon joueur → données JSON (le côté de l'adversaire est toujours « banque 0 » chez lui)
    # @param actions [Array<Battle::Actions::Base>]
    # @return [Array<Hash>]
    def serialize(actions)
      return actions.map do |action|
        kind = action.class.name.to_s.split('::').last
        case kind
        when 'Attack'
          launcher = action.instance_variable_get(:@launcher) || action.launcher
          move = action.instance_variable_get(:@move) || action.move
          slot = launcher.moveset.index { |skill| skill.equal?(move) } || launcher.moveset.index { |skill| skill.db_symbol == move.db_symbol }
          raise Unsupported, 'attaque introuvable' unless slot

          { 'type' => 'move', 'mon' => launcher.position, 'slot' => slot,
            'target_bank' => (action.instance_variable_get(:@target_bank) || action.target_bank).to_i,
            'target_pos' => (action.instance_variable_get(:@target_position) || action.target_position).to_i }
        when 'Switch'
          { 'type' => 'switch', 'mon' => (action.instance_variable_get(:@who) || action.who).position,
            'with' => (action.instance_variable_get(:@with) || action.with).party_index.to_i }
        when 'Flee' then { 'type' => 'flee' }
        else
          raise Unsupported, "action « #{kind} » non gérée"
        end
      end
    end

    # Décisions de l'adversaire → vraies actions (banques inversées : sa banque 0 est ma banque 1)
    # @param scene [Battle::Scene]
    # @param list [Array<Hash>]
    # @return [Array<Battle::Actions::Base>]
    def build(scene, list)
      logic = scene.logic
      return list.map do |act|
        case act['type']
        when 'move'
          battler = logic.battler(1, act['mon'].to_i)
          raise Unsupported, 'Pokémon adverse introuvable' unless battler

          move = battler.moveset[act['slot'].to_i]
          raise Unsupported, 'attaque adverse introuvable' unless move

          ::Battle::Actions::Attack.new(scene, move, battler, 1 - act['target_bank'].to_i, act['target_pos'].to_i)
        when 'switch'
          battler = logic.battler(1, act['mon'].to_i)
          with = battler && logic.party_of(battler)[act['with'].to_i]
          raise Unsupported, 'remplaçant introuvable' unless battler && with

          ::Battle::Actions::Switch.new(scene, battler, with)
        when 'flee' then nil
        else raise Unsupported, "action adverse « #{act['type']} »"
        end
      end.compact
    end

    # Empreinte de l'état du combat, indépendante du point de vue (les deux côtés doivent obtenir la même)
    # @param logic [Battle::Logic]
    # @param role [String] 'host' ou 'guest'
    def digest(logic, role)
      sides = [0, 1].map { |bank| logic.all_battlers.select { |b| b.bank == bank }.sort_by(&:position).map { |b| [b.db_symbol, b.hp, b.level, b.status_id.to_i] } }
      sides.reverse! if role == 'guest'
      return Online::Lockstep.digest(sides)
    end
  end

  module Game
    module_function

    # Combat en temps réel contre un autre joueur
    # @return [Boolean] le combat a démarré
    def pvp(**opts)
      cap = Online.duel_setting('level_cap').to_i
      team = duel_team
      if team.empty?
        say(Online.t('Il te faut au moins un Pokémon en forme.', 'You need at least one healthy Pokémon.'))
        return false
      end
      names = team.map { |p| "#{p.given_name} #{Online.t('N.', 'Lv.')}#{p.level}" }.join(', ')
      return false unless ask(Online.t("Combat en ligne en temps réel\nÉquipe : #{names}", "Live online battle\nTeam: #{names}"), Online.t('Combattre', 'Fight'), Online.t('Annuler', 'Cancel')) == 0

      link = open_link(:pvp, **opts)
      return false unless link

      session = Online::Lockstep.new(link, team_size: Online.duel_setting('team_size').to_i, level_cap: cap, banned: Online.duel_setting('banned'),
                                           turn_timeout: Online.setting('idle_timeout').to_i.clamp(30, 300))
      session.offer(team.map { |p| Online::Codec.encode(p) })
      outcome = wait_for(60) { session.update; %i[running cancelled].include?(session.status) }
      unless session.status == :running
        session.cancel('annulé') unless outcome == :ok
        say(Online.t("Combat annulé (#{session.reason}).", "Battle cancelled (#{session.reason})."))
        link.close
        return false
      end
      return start_pvp_battle(session, link, team, cap)
    end

    def start_pvp_battle(session, link, team, cap)
      opponent = session.theirs.map do |mon|
        mon = mon.merge('level' => [mon['level'], cap].min) if cap > 0
        Online::Codec.decode(mon, origin: link.peer['name'])
      end
      mine = team.map { |pokemon| Marshal.load(Marshal.dump(pokemon)) }
      mine.each { |pokemon| pokemon.level = [pokemon.level, cap].min } if cap > 0
      info = ::Battle::Logic::BattleInfo.new
      _party, name, klass, battler, = info.player_basic_info
      info.add_party(1, opponent, link.peer['name'], link.peer['name'], Online.opponent_battler(session.peer_battler, battler), PFM::Bag.new)
      info.add_party(0, mine, name, klass, battler, PFM::Bag.new)
      info.vs_type = 1
      info.pj_pvp = session
      srand(session.seed)
      @no_exp_before = $game_switches[Yuki::Sw::BT_NoExp]
      $game_switches[Yuki::Sw::BT_NoExp] = true
      $game_temp.battle_can_lose = true
      @pvp_pending = { session: session, link: link, since: nil }
      Graphics.freeze
      $scene = ::Battle::Scene.new(info)
      Yuki::FollowMe.set_battle_entry
      return true
    end

    # Fin du combat (appelé par la scène)
    def pvp_finished(session, won)
      $game_switches[Yuki::Sw::BT_NoExp] = @no_exp_before
      session.finish!(won) unless session.status == :over
      @pvp_pending[:since] = Time.now if @pvp_pending
    end

    def pvp_tick
      return unless @pvp_pending && @pvp_pending[:since]

      link = @pvp_pending[:link]
      session = @pvp_pending[:session]
      @pvp_pending = nil
      link.close
      won = session.won
      stats = (Online.state['pvp'] ||= { 'won' => 0, 'lost' => 0 })
      stats[won ? 'won' : 'lost'] += 1
      Online.add_log("combat en ligne : #{won ? 'victoire' : 'défaite'}#{session.reason ? " (#{session.reason})" : ''}")
      say(won ? Online.t("Victoire#{session.reason ? " — #{session.reason}" : ''} !", "Victory#{session.reason ? " — #{session.reason}" : ''}!") : Online.t('Défaite…', 'Defeat…'))
    end
  end
end

module Battle
  class Logic
    class BattleInfo
      # @return [Online::Lockstep, nil] combat en ligne en temps réel
      attr_accessor :pj_pvp
    end

    module OnlinePvpLogic
      # Fin de tour : on compare l'état avec l'adversaire (détection de désynchronisation)
      def battle_phase_end
        super
        pvp = Online::Pvp.of(self)
        return unless pvp && pvp.status == :running

        @pj_pvp_turn = @pj_pvp_turn.to_i + 1
        pvp.report(@pj_pvp_turn - 1, Online::Pvp.digest(self, pvp.role))
      rescue StandardError => e
        log_error("En ligne (fin de tour) : #{e.message}") if respond_to?(:log_error, true)
      end
    end
    prepend OnlinePvpLogic
  end

  class Scene
    module OnlinePvpScene
      # Au lieu de l'IA, on attend la décision de l'autre joueur
      def trigger_all_AI
        pvp = Online::Pvp.of(@logic)
        return super unless pvp

        @pj_pvp_turn ||= 0
        unless @pj_pvp_sent
          @pj_pvp_sent = true
          pvp.submit(@pj_pvp_turn, Online::Pvp.serialize(@player_actions))
        end
        pvp.update
        return pj_pvp_stop(pvp) if pvp.status != :running

        remote = pvp.remote_actions(@pj_pvp_turn)
        return @next_update = :trigger_all_AI unless remote # on attend, image par image

        @player_actions.concat(Online::Pvp.build(self, remote))
        @pj_pvp_sent = false
        @pj_pvp_turn += 1
        @next_update = :sort_actions
      rescue Online::Pvp::Unsupported, NoMethodError, NameError => e
        log_error("En ligne (combat) : #{e.class} #{e.message}") if respond_to?(:log_error, true)
        pj_pvp_abort(pvp, e.message)
      end

      # Fuir = abandonner
      def player_action_choice_internal(choice, forced_action = nil)
        pvp = Online::Pvp.of(@logic)
        return super unless pvp && choice == :flee

        if display_message(Online.t("Abandonner le combat ?\nTu perdras.", "Forfeit the battle?\nYou will lose."), 1, Online.t('Oui', 'Yes'), Online.t('Non', 'No')).to_i == 0
          pvp.forfeit
          return pj_pvp_stop(pvp)
        end
        @next_update = :player_action_choice
      end

      def battle_end
        pvp = Online::Pvp.of(@logic)
        won = pvp ? (@logic.battle_result == 0) : nil
        super
        Online::Game.pvp_finished(pvp, pvp.won.nil? ? won : pvp.won) if pvp
      end

      private

      # Le combat se termine parce que l'autre est parti / a abandonné / désynchronisation
      def pj_pvp_stop(pvp)
        if pvp.status == :cancelled
          display_message_and_wait(Online.t("Combat interrompu (#{pvp.reason}).", "Battle interrupted (#{pvp.reason})."))
          pvp.instance_variable_set(:@won, nil)
        end
        pj_pvp_force_end(pvp.won == true ? 0 : 1)
      end

      def pj_pvp_abort(pvp, text)
        pvp&.cancel('erreur')
        display_message_and_wait(Online.t("Combat interrompu (#{text}).", "Battle interrupted (#{text})."))
        pj_pvp_force_end(2)
      end

      def pj_pvp_force_end(result)
        @logic.instance_variable_set(:@battle_result, result)
        @next_update = :battle_end
      end
    end
    prepend OnlinePvpScene
  end
end

class Scene_Map
  module OnlinePvpMapTick
    def update
      super
      Online::Game.pvp_tick
    rescue StandardError => e
      log_error("En ligne : #{e.message}") if respond_to?(:log_error, true)
    end
  end
  prepend OnlinePvpMapTick
end

class Interpreter
  # Combat en ligne en temps réel (le résultat est annoncé au retour sur la carte)
  def online_combat
    result = Online::Game.pvp
    @wait_count = 2
    return result
  end

  def online_combats_gagnes
    return (Online.state['pvp'] || {})['won'].to_i
  end
end

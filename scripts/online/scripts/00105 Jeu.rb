# encoding: utf-8
# Jeu en ligne : interface dans le jeu (choix de la connexion, échange, défi d'équipe) et commandes d'évènement.
# Les parties « réseau » (Link, Trade, Duel, Codec) ne dépendent pas de PSDK ; ce fichier est le seul à utiliser les scènes du jeu.
module Online
  module Game
    module_function

    # --- petits outils d'interface ---------------------------------------------------------------------------------
    def say(text)
      $scene.display_message_and_wait(text)
    end

    # @return [Integer] index du choix (0, 1, 2…)
    def ask(text, *choices)
      return $scene.display_message(text, 1, *choices).to_i
    end

    # Boucle d'attente (le joueur peut annuler avec B)
    # @param timeout [Numeric] secondes
    # @yieldreturn [Boolean] true : on a fini d'attendre
    # @return [Symbol] :ok, :cancel, :timeout
    def wait_for(timeout)
      started = Time.now
      loop do
        Graphics.update
        return :ok if yield
        return :cancel if Input.trigger?(:B)
        return :timeout if Time.now - started > timeout
      end
    end

    # Saisie de texte (code de salon, adresse IP)
    # @return [String, nil]
    def ask_text(prompt, max)
      text = nil
      $scene.call_scene(GamePlay::NameInput, '', max, nil, prompt) { |scene| text = scene.return_name }
      text = text.to_s.strip
      return text.empty? ? nil : text
    rescue StandardError, NotImplementedError => e
      log_error("En ligne : saisie de texte (#{e.message})") if respond_to?(:log_error, true)
      return nil
    end

    # @return [Hash] compte du serveur (id / jeton), sauvegardé avec la partie
    def account
      data = Online.state
      return (data['account'] ||= {})
    end

    # --- connexion -----------------------------------------------------------------------------------------------------
    # Demande au joueur comment se connecter, puis attend l'autre joueur
    # @param kind [Symbol] :trade ou :duel
    # @return [Online::Link, nil] liaison prête, nil si abandon
    # @param kind [Symbol] :trade, :duel ou :pvp
    # @param join_code [String, nil] code de salon reçu dans une invitation (rejoint directement)
    # @param invite_to [String, nil] code ami d'un joueur à inviter (crée le salon et lui envoie l'invitation)
    def open_link(kind, join_code: nil, invite_to: nil)
      unless Online.enabled?
        say(Online.t('Le jeu en ligne est désactivé.', 'Online play is disabled.'))
        return nil
      end
      return open_invited_link(kind, join_code, invite_to) if join_code || invite_to

      mode = Online.server? ? ask(Online.t('Comment te connecter ?', 'How do you want to connect?'), Online.t('Serveur', 'Server'), Online.t('Direct', 'Direct'), Online.t('Annuler', 'Cancel')) : 1
      return nil if mode == 2

      host = ask(Online.t('Créer ou rejoindre ?', 'Create or join?'), Online.t('Créer', 'Create'), Online.t('Rejoindre', 'Join'), Online.t('Annuler', 'Cancel'))
      return nil if host == 2

      link = mode == 0 ? server_link(kind, host == 0) : direct_link(host == 0)
      return nil unless link

      outcome = wait_for(Online.setting('idle_timeout').to_i.clamp(15, 600)) { link.refresh; link.ready? || link.closed? }
      if outcome != :ok || !link.ready?
        say(outcome == :cancel ? Online.t('Connexion annulée.', 'Connection cancelled.') : Online.t("Connexion impossible (#{link.error || 'délai dépassé'}).", "Couldn't connect (#{link.error || 'timeout'})."))
        link.close
        return nil
      end
      return link
    end

    # Liaison préparée par une invitation (joueurs de la même carte, amis)
    def open_invited_link(kind, join_code, invite_to)
      link = Online::ServerLink.new(Online.setting('server_host').to_s, Online.setting('server_port').to_i, Online.nickname, account)
      if join_code
        link.join_room(join_code)
      else
        link.create_room(kind == :trade ? :trade : :duel)
        wait_for(10) { link.refresh; link.code || link.closed? }
        unless link.code
          say(Online.t("Le serveur ne répond pas (#{link.error || 'délai dépassé'}).", "The server isn't responding (#{link.error || 'timeout'})."))
          link.close
          return nil
        end
        link.request('t' => 'invite', 'to' => invite_to, 'kind' => kind.to_s, 'code' => link.code)
        say(Online.t("Invitation envoyée. En attente de l'autre joueur…\n(B : annuler)", 'Invitation sent. Waiting for the other player…\n(B: cancel)'))
      end
      outcome = wait_for(Online.setting('idle_timeout').to_i.clamp(15, 600)) { link.refresh; link.ready? || link.closed? }
      return link if outcome == :ok && link.ready?

      say(outcome == :cancel ? Online.t('Connexion annulée.', 'Cancelled.') : Online.t("Connexion impossible (#{link.error || 'délai dépassé'}).", "Couldn't connect (#{link.error || 'timeout'})."))
      link.close
      return nil
    end

    def server_link(kind, create)
      kind = kind == :trade ? :trade : :duel
      link = Online::ServerLink.new(Online.setting('server_host').to_s, Online.setting('server_port').to_i, Online.nickname, account)
      if create
        link.create_room(kind)
        outcome = wait_for(10) { link.refresh; link.code || link.closed? }
        code = link.code
        if outcome != :ok || link.closed? || code.nil?
          say(Online.t("Le serveur ne répond pas (#{link.error || 'délai dépassé'}).", "The server isn't responding (#{link.error || 'timeout'})."))
          link.close
          return nil
        end
        say(Online.t("Code du salon : #{code}\nDonne-le à l'autre joueur, puis attends sa connexion (B : annuler).", "Room code: #{code}\nGive it to the other player, then wait (B: cancel)."))
      else
        code = ask_text(Online.t('Code du salon ?', 'Room code?'), 8)
        return nil unless code

        link.join_room(code)
      end
      return link
    end

    def direct_link(create)
      link = Online::DirectLink.new(Online.nickname)
      port = Online.setting('direct_port').to_i
      if create
        link.host(port)
        say(Online.t("Tu héberges sur le port #{port} (ouvre-le sur ta box si besoin).\nDonne ton adresse IP à l'autre joueur, puis attends (B : annuler).", "You host on port #{port} (open it on your router if needed).\nGive your IP address to the other player, then wait (B: cancel)."))
      else
        address = ask_text(Online.t("Adresse IP de l'hôte ?", "Host IP address?"), 40)
        return nil unless address

        link.join(address, port)
      end
      return link
    end

    # --- échange -------------------------------------------------------------------------------------------------------
    # @param pokemon [PFM::Pokemon]
    # @return [String, nil] raison du refus
    def trade_refusal(pokemon)
      return Online.t('Un Œuf ne peut pas être échangé.', "An Egg can't be traded.") if pokemon.egg? && !Online.trade_setting('allow_eggs')
      return Online.t('Ce Pokémon ne peut pas être échangé.', "This Pokémon can't be traded.") if Array(Online.trade_setting('banned')).map(&:to_s).include?(pokemon.db_symbol.to_s)
      return Online.t('Niveau trop élevé pour les échanges.', 'Level too high for trading.') if pokemon.level > Online.trade_setting('max_level').to_i
      return nil unless Online.trade_setting('keep_last')

      others = $actors.reject { |p| p.equal?(pokemon) || p.egg? || p.dead? }
      return Online.t('Il te faut un autre Pokémon en état de se battre.', 'You need another Pokémon that can fight.') if others.empty? && !pokemon.dead?

      return nil
    end

    # @return [Boolean] un échange a eu lieu
    def trade(**opts)
      index = -1
      $scene.call_scene(GamePlay::Party_Menu, $actors, :map) { |scene| index = scene.return_data }
      pokemon = index.to_i >= 0 ? $actors[index] : nil
      return false unless pokemon

      reason = trade_refusal(pokemon)
      return say(reason) && false if reason
      return false unless ask(Online.t("Proposer #{pokemon.given_name} ?", "Offer #{pokemon.given_name}?"), Online.t('Oui', 'Yes'), Online.t('Non', 'No')) == 0

      link = open_link(:trade, **opts)
      return false unless link

      session = Online::Trade.new(link, max_level: Online.trade_setting('max_level').to_i)
      mine = Online::Codec.encode(pokemon)
      session.offer(mine)
      return run_trade(session, link, pokemon, index)
    ensure
      link&.close
    end

    def run_trade(session, link, pokemon, index)
      asked = false
      outcome = wait_for(180) do
        status = session.update
        if status == :review && !asked
          asked = true
          peer = link.peer['name']
          text = Online.t("#{peer} propose #{Online::Codec.summary(session.theirs)}.\nÉchanger contre #{Online::Codec.summary(session.mine)} ?",
                          "#{peer} offers #{Online::Codec.summary(session.theirs)}.\nTrade for #{Online::Codec.summary(session.mine)}?")
          ask(text, Online.t('Accepter', 'Accept'), Online.t('Refuser', 'Decline')) == 0 ? session.confirm : session.cancel('refusé')
        end
        %i[commit cancelled].include?(status)
      end
      session.cancel('annulé') unless outcome == :ok
      unless session.status == :commit
        say(Online.t("Échange annulé (#{session.reason}).", "Trade cancelled (#{session.reason})."))
        return false
      end
      return commit_trade(session, link, pokemon, index)
    end

    def commit_trade(session, link, pokemon, index)
      unless $actors[index].equal?(pokemon)
        session.cancel('équipe modifiée')
        say(Online.t('Échange annulé (équipe modifiée).', 'Trade cancelled (party changed).'))
        return false
      end
      received = Online::Codec.decode(session.theirs, origin: link.peer['name'])
      $actors[index] = received
      register(received)
      session.done!
      Online.state['trades'] += 1
      Online.add_log("échange : #{pokemon.db_symbol} → #{received.db_symbol} (#{link.peer['name']})")
      say(Online.t("#{received.name} #{Online.t('N.', 'Lv.')}#{received.level} rejoint ton équipe !", "#{received.name} Lv.#{received.level} joins your team!"))
      return true
    end

    def register(pokemon)
      dex = PFM.game_state.pokedex
      dex.mark_seen(pokemon.db_symbol, forced: true)
      dex.mark_captured(pokemon.db_symbol)
    rescue StandardError => e
      log_error("En ligne : Pokédex (#{e.message})") if respond_to?(:log_error, true)
    end

    # --- défi d'équipe -------------------------------------------------------------------------------------------------
    # @return [Array<PFM::Pokemon>] équipe engagée dans le défi
    def duel_team
      cap = Online.duel_setting('level_cap').to_i
      banned = Array(Online.duel_setting('banned')).map(&:to_s)
      list = $actors.reject { |p| p.egg? || p.dead? || banned.include?(p.db_symbol.to_s) }
      list = list.select { |p| p.level <= cap } if cap > 0
      return list.first(Online.duel_setting('team_size').to_i.clamp(1, 6))
    end

    # @return [Boolean] le combat a été lancé (le résultat est traité en revenant sur la carte)
    def duel(**opts)
      team = duel_team
      if team.empty?
        cap = Online.duel_setting('level_cap').to_i
        say(Online.t("Il te faut au moins un Pokémon en forme#{cap > 0 ? " de niveau #{cap} ou moins" : ''}.", "You need at least one healthy Pokémon#{cap > 0 ? " of level #{cap} or lower" : ''}."))
        return false
      end
      names = team.map { |p| "#{p.given_name} #{Online.t('N.', 'Lv.')}#{p.level}" }.join(', ')
      return false unless ask(Online.t("Équipe engagée : #{names}.", "Team: #{names}."), Online.t('Défier', 'Challenge'), Online.t('Annuler', 'Cancel')) == 0

      link = open_link(:duel, **opts)
      return false unless link

      session = Online::Duel.new(link, team_size: Online.duel_setting('team_size').to_i, level_cap: Online.duel_setting('level_cap').to_i, banned: Online.duel_setting('banned'))
      session.offer(team.map { |p| Online::Codec.encode(p) })
      return run_duel(session, link, team)
    end

    def run_duel(session, link, team)
      started = false
      outcome = wait_for(120) do
        status = session.update
        if status == :ready && !started
          started = true
          peer = link.peer['name']
          theirs = session.theirs.map { |mon| Online::Codec.summary(mon) }.join(', ')
          say(Online.t("#{peer} engage : #{theirs}.", "#{peer} brings: #{theirs}."))
          session.start
        end
        %i[fighting cancelled].include?(status)
      end
      unless session.status == :fighting
        session.cancel('annulé') unless outcome == :ok
        say(Online.t("Défi annulé (#{session.reason}).", "Challenge cancelled (#{session.reason})."))
        link.close
        return false
      end
      return start_duel_battle(session, link, team)
    end

    # Lance le combat contre l'équipe de l'autre joueur (dirigée par l'IA)
    def start_duel_battle(session, link, team)
      cap = Online.duel_setting('level_cap').to_i
      opponent = session.theirs.map do |mon|
        mon = mon.merge('level' => [mon['level'], cap].min) if cap > 0
        Online::Codec.decode(mon, origin: link.peer['name'])
      end
      mine = team.map { |pokemon| Marshal.load(Marshal.dump(pokemon)) } # copies : ton équipe réelle n'est pas touchée
      info = ::Battle::Logic::BattleInfo.new
      _party, name, klass, battler, = info.player_basic_info
      info.add_party(1, opponent, link.peer['name'], link.peer['name'], Online.opponent_battler(session.peer_battler, battler), PFM::Bag.new)
      info.add_party(0, mine, name, klass, battler, PFM::Bag.new)
      info.vs_type = 1
      info.pj_online = session
      @no_exp_before = $game_switches[Yuki::Sw::BT_NoExp]
      $game_switches[Yuki::Sw::BT_NoExp] = true
      $game_temp.battle_can_lose = true
      @pending = { session: session, link: link, since: nil }
      Graphics.freeze
      $scene = ::Battle::Scene.new(info)
      Yuki::FollowMe.set_battle_entry
      return true
    end

    # Fin du combat (appelé par la scène de combat)
    def battle_finished(session, result)
      $game_switches[Yuki::Sw::BT_NoExp] = @no_exp_before
      session.result!(result == 0)
      @pending[:since] = Time.now if @pending
    end

    # Appelé à chaque image sur la carte : attend le résultat de l'autre joueur puis annonce le vainqueur
    def map_tick
      return unless @pending && @pending[:since]

      session = @pending[:session]
      session.update
      waited = Time.now - @pending[:since]
      return unless session.status == :done || session.status == :cancelled || waited > 60

      link = @pending[:link]
      @pending = nil
      link.close
      finish_duel(session)
    end

    def finish_duel(session)
      peer = (session.status == :done) ? nil : true
      if session.status == :done
        won = session.my_win
        Online.state['duels'][won ? 'won' : 'lost'] += 1
        Online.add_log("défi : #{won ? 'victoire' : 'défaite'}")
        text = won ? Online.t("Tu as battu l'équipe adverse !\nL'autre joueur #{session.their_win ? 'a aussi gagné' : 'a perdu'} contre la tienne.", "You beat the other team!\nThe other player #{session.their_win ? 'won too' : 'lost'} against yours.") :
                     Online.t("L'équipe adverse t'a battu !\nL'autre joueur #{session.their_win ? 'a aussi gagné' : 'a perdu'} contre la tienne.", "The other team beat you!\nThe other player #{session.their_win ? 'won too' : 'lost'} against yours.")
        say(text)
      elsif peer
        say(Online.t("Le résultat de l'autre joueur n'est pas arrivé (#{session.reason || 'délai dépassé'}).", "The other player's result didn't arrive (#{session.reason || 'timeout'})."))
      end
    end
  end
end

module Battle
  class Logic
    class BattleInfo
      # @return [Online::Duel, nil] défi en ligne en cours
      attr_accessor :pj_online
    end
  end

  class Scene
    module OnlineScene
      def battle_end
        session = @battle_info.respond_to?(:pj_online) ? @battle_info.pj_online : nil
        result = @logic.battle_result if session
        super
        Online::Game.battle_finished(session, result) if session
      end
    end
    prepend OnlineScene
  end
end

class Scene_Map
  module OnlineMapTick
    def update
      super
      Online::Game.map_tick
    rescue StandardError => e
      log_error("En ligne : #{e.message}") if respond_to?(:log_error, true)
    end
  end
  prepend OnlineMapTick
end

class Interpreter
  # Échange entre deux joueurs (renvoie true si un échange a eu lieu)
  def online_echange
    result = Online::Game.trade
    @wait_count = 2
    return result
  end

  # Défi d'équipe entre deux joueurs ; le résultat est annoncé au retour sur la carte
  def online_defi
    result = Online::Game.duel
    @wait_count = 2
    return result
  end

  def online_disponible?
    return Online.enabled?
  end

  def online_echanges_nombre
    return Online.state['trades'].to_i
  end

  def online_defis_gagnes
    return Online.state['duels']['won'].to_i
  end
end

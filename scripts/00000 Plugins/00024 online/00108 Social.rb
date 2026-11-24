# encoding: utf-8
# Jeu en ligne — étape 3 : profil, amis et classements (via le serveur ; indisponible en mode direct).
# Les chiffres du profil sont envoyés par le jeu : le serveur les borne mais ne peut pas les vérifier (classements « d'honneur »).
module Online
  module Social
    module_function

    # Connexion au serveur
    # @param account [Hash]
    # @param pause [Proc] appelé à chaque attente (Graphics.update dans le jeu)
    # @return [Online::ServerLink, nil]
    def connect(account, timeout: 8, &pause)
      link = Online::ServerLink.new(Online.setting('server_host').to_s, Online.setting('server_port').to_i, Online.nickname, account)
      link.open_social
      started = Time.now
      until link.welcomed? || link.closed? || Time.now - started > timeout
        link.refresh
        pause&.call
      end
      return link if link.welcomed?

      link.close
      return nil
    end

    # Envoie une requête et attend la réponse du type attendu
    # @return [Hash] réponse du serveur ({'t' => 'error', …} en cas d'erreur ou de délai)
    def call(link, message, expect, timeout: 8, &pause)
      return { 't' => 'error', 'code' => 'closed', 'text' => 'connexion perdue' } unless link.request(message)

      started = Time.now
      loop do
        link.poll.each do |event|
          next unless event['t'] == 'resp'

          reply = event['m']
          return reply if reply['t'] == 'error' || Array(expect).include?(reply['t'])
        end
        return { 't' => 'error', 'code' => 'closed', 'text' => 'connexion perdue' } if link.closed?
        return { 't' => 'error', 'code' => 'timeout', 'text' => 'pas de réponse' } if Time.now - started > timeout

        pause&.call
      end
    end

    # @return [Hash] profil envoyé au serveur (valeurs lues dans la partie, 0 si introuvables)
    def profile_data
      state = Online.state
      duels = state['duels'] || {}
      pvp = state['pvp'] || {}
      return {
        'title' => state['title'].to_s,
        'team' => safe([]) { $actors.reject(&:egg?).first(6).map { |pokemon| pokemon.db_symbol.to_s } },
        'dex_seen' => safe(0) { PFM.game_state.pokedex.creature_seen }, 'dex_caught' => safe(0) { PFM.game_state.pokedex.creature_caught },
        'badges' => safe(0) { PFM.game_state.trainer.badge_count }, 'play_time' => safe(0) { PFM.game_state.trainer.play_time.to_i },
        'trades' => state['trades'].to_i, 'duels_won' => duels['won'].to_i, 'duels_lost' => duels['lost'].to_i,
        'pvp_won' => pvp['won'].to_i, 'pvp_lost' => pvp['lost'].to_i
      }
    end

    def safe(default)
      value = yield
      return value.nil? ? default : value
    rescue StandardError, NoMethodError
      return default
    end

    # @param user [Hash] { 'id', 'name', 'online', 'profile' }
    # @return [String]
    def card_text(user)
      profile = user['profile'] || {}
      lines = ["#{user['name']}  (#{user['id']})#{user['online'] ? Online.t('  — en ligne', '  — online') : ''}"]
      lines << profile['title'] unless profile['title'].to_s.empty?
      if profile.empty?
        lines << Online.t('Profil pas encore partagé.', 'Profile not shared yet.')
      else
        lines << Online.t("Pokédex : #{profile['dex_caught']} capturés / #{profile['dex_seen']} vus   Badges : #{profile['badges']}",
                          "Pokédex: #{profile['dex_caught']} caught / #{profile['dex_seen']} seen   Badges: #{profile['badges']}")
        lines << Online.t("Combats en ligne : #{profile['pvp_won']} V / #{profile['pvp_lost']} D   Défis : #{profile['duels_won']} V / #{profile['duels_lost']} D   Échanges : #{profile['trades']}",
                          "Online battles: #{profile['pvp_won']} W / #{profile['pvp_lost']} L   Challenges: #{profile['duels_won']} W / #{profile['duels_lost']} L   Trades: #{profile['trades']}")
        team = Array(profile['team']).map { |symbol| Online::Codec.species_name(symbol) }
        lines << Online.t("Équipe : #{team.join(', ')}", "Team: #{team.join(', ')}") unless team.empty?
      end
      return lines.join("\n")
    end
  end
end

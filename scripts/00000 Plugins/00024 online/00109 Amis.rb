# encoding: utf-8
# Jeu en ligne — étape 3 : menus Profil / Amis / Classements (commande d'évènement : online_social).
module Online
  module Game
    module_function

    # @return [Boolean] le menu a été ouvert
    def social
      unless Online.enabled? && Online.server?
        say(Online.t("Il faut un serveur en ligne (réglage « server_host ») pour les amis et les classements.", 'An online server is required for friends and leaderboards.'))
        return false
      end
      link = Online::Social.connect(account) { Graphics.update }
      unless link
        say(Online.t('Connexion au serveur impossible.', "Couldn't reach the server."))
        return false
      end
      begin
        call_social(link, 'profile_set', 'profile' => Online::Social.profile_data)
        share_base(link) if Online::BaseShare.available?
        social_menu(link)
      ensure
        link.close
      end
      return true
    end

    def call_social(link, type, payload = {}, expect = nil)
      expect ||= { 'profile_set' => 'profile_ok', 'profile_get' => 'profile', 'friends_list' => 'friends', 'board' => 'board' }[type] || 'friend_ok'
      reply = Online::Social.call(link, { 't' => type }.merge(payload), expect) { Graphics.update }
      return reply
    end

    def error_text(reply)
      return Online.t("Erreur : #{reply['text'] || reply['code']}", "Error: #{reply['text'] || reply['code']}")
    end

    def social_menu(link)
      loop do
        choice = ask(Online.t('Amis et classements', 'Friends and leaderboards'), Online.t('Mon profil', 'My profile'), Online.t('Amis', 'Friends'), Online.t('Ajouter un ami', 'Add a friend'), Online.t('Classements', 'Leaderboards'), Online.t('Quitter', 'Quit'))
        case choice
        when 0 then my_profile(link)
        when 1 then friends_menu(link)
        when 2 then add_friend(link)
        when 3 then boards_menu(link)
        else break
        end
        return unless link && !link.closed?
      end
    end

    def my_profile(link)
      me = { 'id' => account['id'].to_s, 'name' => Online.nickname, 'online' => true, 'profile' => Online::Social.profile_data }
      say(Online.t("Ton code ami : #{me['id']}\n", "Your friend code: #{me['id']}\n") + Online::Social.card_text(me))
      loop do
        entries = []
        entries << [Online.t('Mot de ma base', 'Base message'), :greeting] if Online::BaseShare.available?
        entries << [Online.t("Visible sur la carte : #{Online::Presence.enabled? ? 'oui' : 'non'}", "Visible on map: #{Online::Presence.enabled? ? 'yes' : 'no'}"), :ghosts] if Online.setting('ghosts')
        break if entries.empty?

        entries << [Online.t('Retour', 'Back'), :back]
        case entries[ask(Online.t('Mon profil', 'My profile'), *entries.map(&:first))]&.last
        when :greeting
          text = ask_text(Online.t('Mot affiché dans ta base (40 lettres)', 'Message shown in your base (40 chars)'), 40)
          Online.state['base_greeting'] = text.to_s
          share_base(link)
        when :ghosts
          Online::Presence.set_enabled(!Online::Presence.enabled?)
          say(Online::Presence.enabled? ? Online.t('Tes amis te voient sur la carte (après le prochain changement de carte).', 'Friends can see you on the map (after the next map change).') : Online.t('Tu es invisible.', 'You are hidden.'))
        else break
        end
      end
    end

    def add_friend(link)
      code = ask_text(Online.t("Code ami de l'autre joueur ?", "Other player's friend code?"), 8)
      return unless code

      reply = call_social(link, 'friend_add', 'code' => code.upcase)
      return say(error_text(reply)) if reply['t'] == 'error'

      name = reply.dig('user', 'name')
      say(reply['a'] == 'accepted' ? Online.t("Vous êtes maintenant amis avec #{name} !", "You are now friends with #{name}!") : Online.t("Demande envoyée à #{name}.", "Request sent to #{name}."))
    end

    PAGE = 3

    def friends_menu(link)
      page = 0
      loop do
        reply = call_social(link, 'friends_list')
        return say(error_text(reply)) if reply['t'] == 'error'

        friends = reply['friends']
        requests = reply['requests']
        slice = friends[page * PAGE, PAGE] || []
        labels = slice.map { |f| "#{f['online'] ? '● ' : ''}#{f['name']}" }
        labels << Online.t("Demandes (#{requests.size})", "Requests (#{requests.size})") unless requests.empty?
        labels << Online.t('Suite', 'More') if friends.size > (page + 1) * PAGE
        labels << Online.t('Retour', 'Back')
        title = friends.empty? && requests.empty? ? Online.t("Aucun ami pour l'instant.", 'No friends yet.') : Online.t("Amis (#{friends.size})", "Friends (#{friends.size})")
        choice = ask(title, *labels)
        label = labels[choice]
        if choice < slice.size then friend_card(link, slice[choice])
        elsif label == Online.t('Suite', 'More') then page += 1
        elsif label.to_s.start_with?(Online.t('Demandes', 'Requests')) then requests_menu(link, requests)
        else break
        end
      end
    end

    def friend_card(link, friend)
      say(Online::Social.card_text(friend))
      loop do
        entries = []
        entries << [Online.t('Visiter la base', 'Visit base'), :visit] if friend['has_base'] && Online::BaseShare.available?
        entries << [Online.t('Défier / échanger', 'Challenge / trade'), :invite] if friend['online']
        entries << [Online.t('Gérer', 'Manage'), :manage] << [Online.t('Retour', 'Back'), :back]
        choice = entries[ask(friend['name'], *entries.map(&:first))]&.last
        case choice
        when :visit then visit_base(link, friend)
        when :invite then return invite_friend(friend)
        when :manage then return manage_friend(link, friend)
        else return
        end
      end
    end

    # Défi, combat ou échange avec un ami connecté (il reçoit une invitation sur sa carte)
    def invite_friend(friend)
      choice = ask(Online.t("Inviter #{friend['name']}", "Invite #{friend['name']}"), Online.t("Défi d'équipe", 'Team challenge'), Online.t('Combat en temps réel', 'Live battle'), Online.t('Échanger', 'Trade'), Online.t('Retour', 'Back'))
      case choice
      when 0 then duel(invite_to: friend['id'])
      when 1 then pvp(invite_to: friend['id'])
      when 2 then trade(invite_to: friend['id'])
      end
    end

    def manage_friend(link, friend)
      action = ask(friend['name'], Online.t('Retirer des amis', 'Remove friend'), Online.t('Bloquer', 'Block'), Online.t('Signaler', 'Report'), Online.t('Retour', 'Back'))
      return if action > 2
      return unless ask(Online.t("#{%w[Retirer Bloquer Signaler][action]} #{friend['name']} ?", "#{%w[Remove Block Report][action]} #{friend['name']}?"), Online.t('Oui', 'Yes'), Online.t('Non', 'No')) == 0

      type = %w[friend_remove block report][action]
      reply = call_social(link, type, 'code' => friend['id'], 'reason' => 'signalé depuis le jeu')
      say(reply['t'] == 'error' ? error_text(reply) : Online.t(["#{friend['name']} a été retiré.", "#{friend['name']} est bloqué.", 'Signalement envoyé, merci.'][action], ["#{friend['name']} was removed.", "#{friend['name']} is blocked.", 'Report sent, thanks.'][action]))
    end

    def requests_menu(link, requests)
      requests.each do |request|
        choice = ask(Online.t("#{request['name']} (#{request['id']}) veut être ton ami.", "#{request['name']} (#{request['id']}) wants to be your friend."), Online.t('Accepter', 'Accept'), Online.t('Refuser', 'Decline'), Online.t('Plus tard', 'Later'))
        next if choice == 2

        reply = call_social(link, 'friend_answer', 'code' => request['id'], 'accept' => choice == 0)
        say(error_text(reply)) if reply['t'] == 'error'
      end
    end

    BOARDS = [['dex_caught', 'Pokédex'], ['pvp_won', 'Combats en ligne'], ['duels_won', 'Défis'], ['trades', 'Échanges']].freeze

    def boards_menu(link)
      loop do
        choice = ask(Online.t('Quel classement ?', 'Which leaderboard?'), *BOARDS.map { |_, name| name }, Online.t('Retour', 'Back'))
        break if choice >= BOARDS.size

        reply = call_social(link, 'board', 'board' => BOARDS[choice][0])
        next say(error_text(reply)) if reply['t'] == 'error'

        rows = reply['rows'].first(8).map { |row| "#{row['rank']}. #{row['name']} — #{row['value']}" }
        mine = reply['me'] ? Online.t("\nTa place : #{reply['me']['rank']} / #{reply['total']}", "\nYour rank: #{reply['me']['rank']} / #{reply['total']}") : ''
        say(rows.empty? ? Online.t('Personne dans ce classement.', 'Nobody on this board yet.') : "#{reply['title']}\n#{rows.join("\n")}#{mine}")
      end
    end
  end
end

class Interpreter
  # Menu Profil / Amis / Classements
  def online_social
    result = Online::Game.social
    @wait_count = 2
    return result
  end
end

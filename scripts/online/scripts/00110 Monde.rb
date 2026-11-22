# encoding: utf-8
# Jeu en ligne — étape 4 : évènements / distributions du serveur et boîte d'échange mondiale (dépôt asynchrone).
# Le serveur garde le Pokémon déposé jusqu'à ce qu'un autre joueur propose celui demandé ; le dépôt est ensuite récupéré (boîte de réception).
module Online
  module Game
    module_function

    # @return [Boolean]
    def world
      unless Online.enabled? && Online.server?
        say(Online.t('Il faut un serveur en ligne (réglage « server_host »).', 'An online server is required.'))
        return false
      end
      link = Online::Social.connect(account) { Graphics.update }
      unless link
        say(Online.t('Connexion au serveur impossible.', "Couldn't reach the server."))
        return false
      end
      begin
        collect_inbox(link)
        world_menu(link)
      ensure
        link.close
      end
      return true
    end

    def world_call(link, type, payload, expect)
      return Online::Social.call(link, { 't' => type }.merge(payload), expect) { Graphics.update }
    end

    def world_menu(link)
      loop do
        choice = ask(Online.t('Monde en ligne', 'Online world'), Online.t('Évènements', 'Events'), Online.t("Boîte d'échange", 'Trade box'), Online.t('Quitter', 'Quit'))
        case choice
        when 0 then events_menu(link)
        when 1 then box_menu(link)
        else break
        end
        return if link.closed?
      end
    end

    # --- récompenses -------------------------------------------------------------------------------------------------
    # Ajoute un Pokémon reçu à l'équipe (ou au PC)
    # @return [Boolean]
    def give_pokemon(data, origin)
      problem = Online::Codec.problem(data, max_level: 100)
      if problem
        log_error("En ligne : Pokémon reçu refusé (#{problem})") if respond_to?(:log_error, true)
        return false
      end
      pokemon = Online::Codec.decode(data, origin: origin)
      $actors.size < 6 ? $actors << pokemon : $storage.store(pokemon)
      register(pokemon)
      return pokemon
    rescue StandardError, NoMethodError => e
      log_error("En ligne : réception impossible (#{e.message})") if respond_to?(:log_error, true)
      return false
    end

    # Vide la boîte de réception : on n'accuse réception qu'après avoir donné le Pokémon
    def collect_inbox(link)
      reply = world_call(link, 'box_collect', {}, 'box_inbox')
      return if reply['t'] == 'error'

      done = []
      reply['items'].each do |item|
        pokemon = give_pokemon(item['mon'], item['from'].to_s)
        next unless pokemon

        done << item['uid']
        say(Online.t("#{pokemon.name} (#{item['from']}) a été ajouté à ton équipe ou à ton PC !", "#{pokemon.name} (#{item['from']}) was added to your team or PC!"))
      end
      world_call(link, 'box_ack', { 'uids' => done }, 'box_ok') unless done.empty?
    end

    # --- évènements --------------------------------------------------------------------------------------------------
    def events_menu(link)
      reply = world_call(link, 'events_list', {}, 'events')
      return say(error_text(reply)) if reply['t'] == 'error'

      events = reply['events']
      return say(Online.t("Aucun évènement en cours.", 'No event right now.')) if events.empty?

      page = 0
      loop do
        slice = events[page * PAGE, PAGE] || []
        labels = slice.map { |e| "#{e['claimed'] ? '✓ ' : ''}#{e['title']}" }
        labels << Online.t('Suite', 'More') if events.size > (page + 1) * PAGE
        labels << Online.t('Retour', 'Back')
        choice = ask(Online.t('Évènements en cours', 'Current events'), *labels)
        if choice < slice.size then claim_event(link, slice[choice])
        elsif labels[choice] == Online.t('Suite', 'More') then page += 1
        else break
        end
      end
    end

    def claim_event(link, event)
      say("#{event['title']}\n#{event['desc']}")
      return say(Online.t('Déjà récupéré.', 'Already claimed.')) if event['claimed']
      return unless ask(event['title'], Online.t('Récupérer', 'Claim'), Online.t('Retour', 'Back')) == 0

      code = event['needs_code'] ? ask_text(Online.t("Code de l'évènement ?", 'Event code?'), 20) : ''
      return if code.nil?

      reply = world_call(link, 'event_claim', { 'id' => event['id'], 'code' => code }, 'event_reward')
      return say(error_text(reply)) if reply['t'] == 'error'

      event['claimed'] = true
      reward = reply['reward']
      if reward['type'] == 'pokemon'
        pokemon = give_pokemon(reward['mon'], Online.t('Évènement', 'Event'))
        say(pokemon ? Online.t("#{pokemon.name} rejoint ton équipe ou ton PC !", "#{pokemon.name} joins your team or PC!") : Online.t("Impossible de recevoir ce Pokémon (voir le log).", "Couldn't receive this Pokémon (see log)."))
      else
        $bag.add_item(reward['item'].to_sym, reward['count'].to_i)
        say(Online.t("Tu as reçu #{reward['count']} × #{reward['item']} !", "You received #{reward['count']} × #{reward['item']}!"))
      end
    end

    # --- boîte d'échange ---------------------------------------------------------------------------------------------
    def box_menu(link)
      loop do
        mine = world_call(link, 'box_mine', {}, 'box_mine')
        return say(error_text(mine)) if mine['t'] == 'error'

        dep = mine['deposit']
        choice = ask(Online.t("Boîte d'échange", 'Trade box'), Online.t('Parcourir', 'Browse'),
                     dep ? Online.t('Mon dépôt', 'My deposit') : Online.t('Déposer', 'Deposit'), Online.t('Récupérer mes échanges', 'Collect my trades'), Online.t('Retour', 'Back'))
        case choice
        when 0 then box_browse(link)
        when 1 then dep ? box_my_deposit(link, dep) : box_deposit(link)
        when 2 then collect_inbox(link)
        else break
        end
      end
    end

    def want_text(want)
      species = want['species'] ? Online::Codec.species_name(want['species']) : Online.t("n'importe quel Pokémon", 'any Pokémon')
      return Online.t("#{species} N.#{want['min_level']}+", "#{species} Lv.#{want['min_level']}+")
    end

    def box_deposit(link)
      index = -1
      $scene.call_scene(GamePlay::Party_Menu, $actors, :map) { |scene| index = scene.return_data }
      pokemon = index.to_i >= 0 ? $actors[index] : nil
      return unless pokemon

      reason = trade_refusal(pokemon)
      return say(reason) if reason

      species = ask_text(Online.t("Espèce demandée en échange ? (nom interne en minuscules, ex. pikachu ; vide : n'importe laquelle)", 'Species wanted? (internal lowercase name, empty: any)'), 30)
      species = species.to_s.downcase.strip.gsub(/[^a-z0-9_]/, '')
      species = nil if species.empty?
      if species && !Online::Codec.species?(species)
        return say(Online.t("Espèce inconnue : #{species}.", "Unknown species: #{species}."))
      end
      level = ask_text(Online.t('Niveau minimum demandé ? (1-100)', 'Minimum level? (1-100)'), 3).to_i.clamp(1, 100)
      want = { 'species' => species, 'min_level' => level }
      return unless ask(Online.t("Déposer #{pokemon.given_name} contre #{want_text(want)} ?", "Deposit #{pokemon.given_name} for #{want_text(want)}?"), Online.t('Oui', 'Yes'), Online.t('Non', 'No')) == 0
      return unless $actors[index].equal?(pokemon)

      reply = world_call(link, 'box_deposit', { 'mon' => Online::Codec.encode(pokemon), 'want' => want }, 'box_ok')
      return say(error_text(reply)) if reply['t'] == 'error'

      $actors.delete_at(index) # le serveur le garde ; il revient avec « Mon dépôt → Retirer »
      Online.add_log("dépôt : #{pokemon.db_symbol}")
      say(Online.t("#{pokemon.given_name} est déposé. Tu le retrouveras (ou son remplaçant) dans « Récupérer mes échanges ».", "#{pokemon.given_name} deposited. You'll get your trade (or it back) via “Collect my trades”."))
    end

    def box_my_deposit(link, deposit)
      choice = ask(Online.t("Ton dépôt : #{Online::Codec.summary(deposit['mon'])}\nCherche : #{want_text(deposit['want'])}", "Your deposit: #{Online::Codec.summary(deposit['mon'])}\nWants: #{want_text(deposit['want'])}"),
                   Online.t('Retirer le dépôt', 'Withdraw'), Online.t('Retour', 'Back'))
      return unless choice == 0

      reply = world_call(link, 'box_withdraw', {}, 'box_ok')
      return say(error_text(reply)) if reply['t'] == 'error'

      collect_inbox(link)
    end

    def box_browse(link)
      species = ask_text(Online.t("Chercher une espèce ? (nom interne ; vide : tout voir)", 'Search a species? (internal name; empty: all)'), 30).to_s.downcase.gsub(/[^a-z0-9_]/, '')
      reply = world_call(link, 'box_list', species.empty? ? {} : { 'species' => species }, 'box')
      return say(error_text(reply)) if reply['t'] == 'error'

      deposits = reply['deposits']
      return say(Online.t('Aucun dépôt pour le moment.', 'No deposits right now.')) if deposits.empty?

      page = 0
      loop do
        slice = deposits[page * PAGE, PAGE] || []
        labels = slice.map { |d| "#{Online::Codec.summary(d['mon'])}" }
        labels << Online.t('Suite', 'More') if deposits.size > (page + 1) * PAGE
        labels << Online.t('Retour', 'Back')
        choice = ask(Online.t("Dépôts (#{reply['total']})", "Deposits (#{reply['total']})"), *labels)
        if choice < slice.size then return if box_take(link, slice[choice])
        elsif labels[choice] == Online.t('Suite', 'More') then page += 1
        else break
        end
      end
    end

    # @return [Boolean] échange réalisé
    def box_take(link, deposit)
      want = deposit['want']
      say("#{Online::Codec.summary(deposit['mon'])}\n" + Online.t("Déposé par #{deposit['owner']}\nCherche : #{want_text(want)}", "By #{deposit['owner']}\nWants: #{want_text(want)}"))
      return false unless ask(deposit['owner'], Online.t('Proposer un Pokémon', 'Offer a Pokémon'), Online.t('Retour', 'Back')) == 0

      index = -1
      $scene.call_scene(GamePlay::Party_Menu, $actors, :map) { |scene| index = scene.return_data }
      pokemon = index.to_i >= 0 ? $actors[index] : nil
      return false unless pokemon

      reason = trade_refusal(pokemon)
      reason ||= Online.t('Ce n\'est pas l\'espèce demandée.', 'Not the species wanted.') if want['species'] && pokemon.db_symbol.to_s != want['species']
      reason ||= Online.t('Niveau trop bas.', 'Level too low.') if pokemon.level < want['min_level'].to_i
      return say(reason) && false if reason
      return false unless ask(Online.t("Échanger #{pokemon.given_name} contre #{Online::Codec.summary(deposit['mon'])} ?", "Trade #{pokemon.given_name} for #{Online::Codec.summary(deposit['mon'])}?"), Online.t('Oui', 'Yes'), Online.t('Non', 'No')) == 0
      return false unless $actors[index].equal?(pokemon)

      reply = world_call(link, 'box_take', { 'id' => deposit['id'], 'mon' => Online::Codec.encode(pokemon) }, 'box_ok')
      return say(error_text(reply)) && false if reply['t'] == 'error'

      $actors.delete(pokemon)
      received = give_pokemon(reply['mon'], reply['from'].to_s)
      Online.state['trades'] += 1
      Online.add_log("boîte : #{pokemon.db_symbol} → #{reply['mon']['id']} (#{reply['from']})")
      say(received ? Online.t("Échange réussi ! #{received.name} est à toi.", "Trade done! #{received.name} is yours.") : Online.t("Échange fait, mais le Pokémon reçu n'a pas pu être ajouté (voir le log).", 'Trade done but the received Pokémon could not be added (see log).'))
      return true
    end
  end
end

class Interpreter
  # Évènements du serveur et boîte d'échange mondiale
  def online_monde
    result = Online::Game.world
    @wait_count = 2
    return result
  end
end

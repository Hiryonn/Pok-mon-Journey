# Concours : accueil (type, rang, Pokémon, ruban déjà gagné), lancement de la scène et récompenses
module Concours
  module_function

  # @param type [String, Symbol, nil] imposé (sinon choisi à l'accueil)
  # @param rank [String, Symbol, nil] imposé (sinon choisi à l'accueil)
  # @param greet [Boolean] messages d'accueil
  # @return [Integer] place du joueur (1 à 4), 0 si abandon
  def reception(type = nil, rank = nil, greet: true)
    scene = $scene
    if greet
      scene.display_message(t('Bonjour ! Ici l’accueil des Concours Pokémon.', 'Hello! This is the reception counter for Pokémon Contests.'))
      choice = scene.display_message(t('Voulez-vous inscrire un Pokémon au concours ?', 'Would you like to enter your Pokémon in our Contest?'), 1,
                                     t('Participer', 'Enter'), t('Annuler', 'Cancel'))
      return nevermind(scene) unless choice == 0
    end
    return nevermind(scene, t('Il vous faut au moins un Pokémon pour participer.', 'You must have at least one Pokémon to participate.')) if $actors.none? { |p| !p.egg? }

    pass = setting('pass_item').to_s
    if !pass.empty? && !$bag.contain_item?(pass.to_sym)
      return nevermind(scene, t('Il vous faut un Passe Concours pour participer.', 'You need a Contest Pass to participate.'))
    end
    type = choose_type(scene) if type.nil? || !TYPE_IDS.include?(type.to_s)
    return nevermind(scene) unless type

    rank = choose_rank(scene) if rank.nil? || !RANK_IDS.include?(rank.to_s)
    return nevermind(scene) unless rank

    pokemon = choose_pokemon(scene)
    return nevermind(scene) unless pokemon

    ribbon = ribbon(type, rank)
    if pokemon.respond_to?(:ribbon?) && pokemon.ribbon?(ribbon)
      scene.display_message(t('Oh, mais ce ruban...', 'Oh, but that Ribbon...'))
      scene.display_message(t('Votre Pokémon a déjà gagné ce concours, n’est-ce pas ?', "Your Pokémon has won this Contest before, hasn't it?"))
      again = scene.display_message(t('Voulez-vous quand même participer ?', 'Would you like to enter it in this Contest anyway?'), 1,
                                    t('Oui', 'Yes'), t('Non', 'No'))
      return nevermind(scene) unless again == 0
    end
    scene.display_message(t('Très bien, votre Pokémon est inscrit à ce concours.', 'Okay, your Pokémon will be entered in this Contest.'))
    scene.display_message(t('Vous êtes l’entrée n° 4. Le concours va bientôt commencer !', 'Your Pokémon is Entry No. 4. The Contest will begin shortly.'))
    return start(type, rank, pokemon)
  end

  def nevermind(scene, text = nil)
    scene.display_message(text || t('Nous espérons vous revoir bientôt !', 'We hope you will participate another time.'))
    return 0
  end

  # @return [String, nil]
  def choose_type(scene)
    names = TYPE_IDS.map { |type| t("Concours #{type_name(type)}", "#{type_name(type)} Contest") }
    choice = scene.display_message(t('À quel type de concours voulez-vous participer ?', 'Which type of Contest would you like to enter?'), 1,
                                   *names, t('Retour', 'Exit'))
    return TYPE_IDS[choice] if choice && choice < TYPE_IDS.size

    return nil
  end

  # @return [String, nil]
  def choose_rank(scene)
    open = RANK_IDS.select { |rank| rank_open?(rank) }
    names = open.map { |rank| t("Rang #{rank_name(rank)}", "#{rank_name(rank)} Rank") }
    choice = scene.display_message(t('Quel rang voulez-vous tenter ?', 'Which Rank would you like to enter?'), 1, *names, t('Retour', 'Exit'))
    return open[choice] if choice && choice < open.size

    return nil
  end

  # @return [PFM::Pokemon, nil]
  def choose_pokemon(scene)
    scene.display_message(t('Quel Pokémon voulez-vous inscrire ?', 'Which Pokémon would you like to enter?'))
    loop do
      index = -1
      GamePlay.open_party_menu_to_select_pokemon($actors) { |menu| index = menu.return_data }
      return nil if index.nil? || index < 0

      pokemon = $actors[index]
      return pokemon if pokemon && !pokemon.egg?

      scene.display_message(t('Un Œuf ne peut pas participer à un concours.', "An Egg can't enter a Contest."))
    end
  end

  # Lance le concours (scène, résultats, ruban)
  # @return [Integer] place du joueur
  def start(type, rank, pokemon)
    entrants = build_entrants(type.to_s, rank.to_s, pokemon)
    bgm = $game_system.playing_bgm
    stage = nil
    $scene.call_scene(StageScene, type.to_s, rank.to_s, entrants) { |s| stage = s }
    $game_system.bgm_play(bgm) if bgm
    ranking = stage&.ranking || ranking(entrants)
    player = entrants.find(&:player)
    place = ranking.index(player).to_i + 1
    finish(type.to_s, rank.to_s, ranking, place)
    return place
  end

  def finish(type, rank, ranking, place)
    save_winner(type, rank, ranking.first)
    stats = record(type, rank)
    stats['played'] += 1
    stats['won'] += 1 if place == 1
    stats['last'] = place
    @last_contest = [type, rank]
    switch = setting('win_switch').to_i
    $game_switches[switch] = place == 1 if switch > 0
    variable = setting('result_variable').to_i
    $game_variables[variable] = place if variable > 0
    give_rewards(rank) if place == 1
  end

  def last_contest
    return @last_contest
  end

  # Récompenses de victoire réglées dans Studio : [{ rank, item, count, money, accessory, backdrop }]
  def give_rewards(rank)
    Array(config.rewards).each do |reward|
      next unless fetch(reward, 'rank').to_s.empty? || fetch(reward, 'rank').to_s == rank.to_s

      item = fetch(reward, 'item').to_s
      if !item.empty? && data_item(item.to_sym).db_symbol != :__undef__
        count = [fetch(reward, 'count').to_i, 1].max
        $bag.add_item(item.to_sym, count)
        $scene.display_message(t("Vous recevez #{count > 1 ? "#{count} × " : ''}#{data_item(item.to_sym).name} !",
                                 "You received #{count > 1 ? "#{count} × " : ''}#{data_item(item.to_sym).name}!"))
      end
      money = fetch(reward, 'money').to_i
      if money > 0
        PFM.game_state.add_money(money)
        $scene.display_message(t("Vous recevez #{money} $ !", "You received $#{money}!"))
      end
      accessory = fetch(reward, 'accessory').to_s
      give_accessory(accessory, 1, true) unless accessory.empty?
      backdrop = fetch(reward, 'backdrop').to_s
      give_backdrop(backdrop, true) unless backdrop.empty?
    end
  end

  # Donne un accessoire avec la musique et le message (silent : sans message)
  def give_accessory(id, count = 1, announce = true)
    return false unless unlock_accessory(id, count)
    return true unless announce

    play_me('concours_accessoire')
    $scene.display_message(t("Vous obtenez : #{accessory_name(id)}#{count > 1 ? " × #{count}" : ''} !",
                             "Obtained the #{accessory_name(id)}#{count > 1 ? " × #{count}" : ''}!"))
    $scene.display_message(t("#{$trainer.name} range l’accessoire dans la Mallette.", "#{$trainer.name} put away the accessory in the Fashion Case."))
    return true
  end

  def give_backdrop(id, announce = true)
    return false if backdrop?(id)
    return false unless unlock_backdrop(id)
    return true unless announce

    play_me('concours_accessoire')
    $scene.display_message(t("Vous obtenez le fond « #{backdrop_name(id)} » !", "Obtained the #{backdrop_name(id)} backdrop!"))
    $scene.display_message(t("#{$trainer.name} range le fond dans la Mallette.", "#{$trainer.name} put away the backdrop in the Fashion Case."))
    return true
  end
end

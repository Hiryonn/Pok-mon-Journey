# Raids : cases et menus des aventures (location, échanges, PNJ, butin)
module Raids
  # Choix d'un Pokémon parmi des cartes (3 à l'écran, gauche / droite pour les suivantes)
  class CardScene < GamePlay::BaseCleanUpdate
    WHITE = 10
    VISIBLE = 3

    # @return [Integer, nil] index choisi
    attr_reader :choice

    # @param style [Symbol]
    # @param title [String]
    # @param pokemons [Array<PFM::Pokemon>]
    # @param help [String]
    # @param can_cancel [Boolean]
    def initialize(style, title, pokemons, help, can_cancel = true)
      super()
      @style = style
      @title = title
      @pokemons = pokemons
      @help = help
      @can_cancel = can_cancel
      @index = 0
      @top = 0
      @choice = nil
    end

    def update_inputs
      if Input.trigger?(:LEFT) && @index > 0
        @index -= 1
        play_cursor_se
        refresh
      elsif Input.trigger?(:RIGHT) && @index < @pokemons.size - 1
        @index += 1
        play_cursor_se
        refresh
      elsif Input.trigger?(:A)
        play_decision_se
        @choice = @index
        @running = false
      elsif Input.trigger?(:B) && @can_cancel
        play_cancel_se
        @running = false
      end
      return true
    end

    def update_graphics
      @cards&.each { |card| card[:face].update }
      return true
    end

    private

    def create_graphics
      super
      @stack = UI::SpriteStack.new(@viewport)
      @stack.add_background(Raids.file("menus/bg_#{@style}"))
      @stack.add_text(8, 3, 160, 16, @title, color: WHITE)
      @cards = Array.new(VISIBLE) { |i| create_card(6 + i * 104, 30) }
      @stack.add_sprite(6, 190, Raids.file('menus/desc'))
      @desc = @stack.add_text(14, 194, 292, 16, '', color: WHITE)
      @stack.add_text(14, 212, 292, 16, @help, color: WHITE)
      refresh
    end

    def create_card(x, y)
      card = { bg: @stack.add_sprite(x, y, Raids.file('menus/card')) }
      card[:bg].src_rect.set(0, 0, 100, 150)
      card[:face] = @stack.push(x + 50, y + 51, nil, type: UI::PokemonFaceSprite)
      card[:face].zoom = 0.5
      card[:name] = @stack.add_text(x + 4, y + 54, 92, 16, '', 1, color: WHITE)
      card[:level] = @stack.add_text(x + 4, y + 68, 92, 16, '', 1, color: WHITE)
      card[:types] = [@stack.push(x + 2, y + 84, nil, type: UI::TypeSprite), @stack.push(x + 50, y + 84, nil, type: UI::TypeSprite)]
      card[:moves] = @stack.with_font(20) { Array.new(4) { |i| @stack.add_text(x + 6, y + 100 + i * 12, 90, 13, '', color: WHITE) } }
      return card
    end

    def refresh
      @top = @index - VISIBLE + 1 if @index >= @top + VISIBLE
      @top = @index if @index < @top
      @cards.each_with_index do |card, i|
        pokemon = @pokemons[@top + i]
        visible = !pokemon.nil?
        card.each_value { |v| Array(v).each { |s| s.visible = visible } }
        next unless pokemon

        card[:bg].src_rect.y = @top + i == @index ? 150 : 0
        card[:face].data = pokemon
        card[:name].text = pokemon.given_name
        card[:level].text = format(Raids.t('Niv. %d', 'Lv. %d'), pokemon.level)
        types = [pokemon.type1, pokemon.type2]
        card[:types].each_with_index do |sprite, t|
          sprite.data = types[t].to_i > 0 ? Struct.new(:type).new(types[t]) : nil
        end
        card[:moves].each_with_index { |text, m| text.text = pokemon.skills_set[m]&.name.to_s }
      end
      pokemon = @pokemons[@index]
      return unless pokemon

      ability = data_ability(pokemon.ability).name rescue ''
      item = pokemon.item_holding.to_i > 0 ? Raids.item_name(pokemon.item_holding) : Raids.t('aucun objet', 'no item')
      @desc.text = format(Raids.t('%s · Talent : %s · %s', '%s · Ability: %s · %s'), pokemon.given_name, ability, item)
    end
  end

  # --- Effets des cases ------------------------------------------------------------------------------------------------------
  module AdventureTiles
    module_function

    # @param adventure [Adventure]
    # @param scene [AdventureScene]
    # @param data [Hash] case
    # @param dir [Integer] direction actuelle
    # @param dirs [Array<Integer>] directions possibles
    # @return [Integer] direction suivante
    def trigger(adventure, scene, data, dir, dirs)
      return dir if data[:used]

      method = :"tile_#{data[:id].gsub(/([a-z])([A-Z])/, '\1_\2').downcase}"
      return dir unless respond_to?(method, true)

      result = send(method, adventure, scene, data, dir, dirs)
      return result.is_a?(Integer) ? result : dir
    end

    def t(fr, en = fr)
      return Raids.t(fr, en)
    end

    def use(scene, data)
      data[:used] = true
      scene.refresh_tiles
    end

    def turn(dirs, wanted, dir)
      return dirs.include?(wanted) ? wanted : dir
    end

    def tile_start_point(_adv, _scene, _data, dir, _dirs)
      return dir
    end
    def tile_turn_north(_adv, _scene, _data, dir, dirs)
      return turn(dirs, 0, dir)
    end
    def tile_turn_south(_adv, _scene, _data, dir, dirs)
      return turn(dirs, 1, dir)
    end
    def tile_turn_west(_adv, _scene, _data, dir, dirs)
      return turn(dirs, 2, dir)
    end
    def tile_turn_east(_adv, _scene, _data, dir, dirs)
      return turn(dirs, 3, dir)
    end

    def tile_random_turn(_adv, _scene, _data, dir, dirs)
      return rand(2).zero? ? dir : dirs.sample
    end

    def tile_reverse_turn(_adv, scene, _data, dir, dirs)
      scene.display_message(t('Le sol vous fait faire demi-tour !', 'You were forced to turn around!'))
      return turn(dirs, Adventure::OPPOSITE[dir], dir)
    end

    def tile_crossroad(adv, scene, _data, dir, dirs)
      adv.crossroads << [adv.x, adv.y] unless adv.crossroads.include?([adv.x, adv.y])
      return scene.choose_direction(dirs, dir)
    end

    def tile_battle(adv, scene, data, dir, _dirs)
      battle = adv.battles[data[:battle].to_i]
      adv.fight(scene, battle) if battle
      return dir
    end

    def tile_key(adv, scene, data, dir, _dirs)
      adv.keys += 1
      scene.display_message(t('Vous trouvez une clé !', 'You found a key!'))
      use(scene, data)
      scene.refresh_hud
      return dir
    end

    def tile_door(adv, scene, data, dir, dirs)
      if adv.keys > 0
        adv.keys -= 1
        scene.display_message(t('Vous ouvrez la porte avec une clé.', 'You unlocked the door with a key.'))
        use(scene, data)
        scene.refresh_hud
        return dir
      end
      scene.display_message(t('Une porte fermée à clé bloque le passage.', 'A locked door blocks the way.'))
      return turn(dirs, Adventure::OPPOSITE[dir], dir)
    end

    def tile_chest(adv, scene, data, dir, _dirs)
      unless adv.keys > 0
        scene.display_message(t('Un coffre fermé à clé… Il faudrait une clé.', 'A locked chest... You need a key.'))
        return dir
      end
      return dir unless scene.display_message(t('Ouvrir le coffre avec une clé ?', 'Open the chest with a key?'), 1, t('Oui', 'Yes'), t('Non', 'No')).to_i.zero?

      adv.keys -= 1
      rules = Rules.new(style: adv.style, rank: 4)
      rules.pokemon = adv.party.first
      items = Raids.generate_rewards(rules).to_a.sample(2)
      items.each { |item, count| adv.loot[item] += count }
      names = items.map { |item, count| "#{Raids.item_name(item)} x#{count}" }.join(', ')
      scene.display_message(format(t('Le coffre contenait : %s !', 'The chest contained: %s!'), names))
      use(scene, data)
      scene.refresh_hud
      return dir
    end

    def tile_switch(adv, scene, _data, dir, _dirs)
      adv.tiles.each_value { |tile| tile[:hidden] = !tile[:hidden] if tile[:toggle] }
      scene.display_message(t('Clac ! Quelque chose a changé sur la carte.', 'Click! Something changed on the map.'))
      scene.refresh_tiles
      return dir
    end

    def tile_warp(adv, scene, data, dir, _dirs)
      target = data[:warp]
      target ||= adv.tiles.find { |pos, tile| tile[:id] == 'Warp' && pos != [adv.x, adv.y] }&.first
      return dir unless target

      scene.display_message(t('Vous êtes transporté ailleurs !', 'You were warped elsewhere!'))
      adv.x, adv.y = target
      scene.place_player
      return adv.directions.include?(dir) ? dir : (adv.directions.first || dir)
    end

    def tile_portal(adv, scene, _data, dir, _dirs)
      start = Raids.fetch(adv.map, 'start')
      return dir unless start

      scene.display_message(t('Le portail vous ramène au début de la carte !', 'The portal sent you back to the start!'))
      adv.x, adv.y = start
      scene.place_player
      return adv.directions.first || dir
    end

    def tile_teleporter(adv, scene, _data, dir, _dirs)
      return dir if adv.crossroads.empty?
      return dir unless scene.display_message(t('Retourner à un croisement déjà vu ?', 'Return to a crossroad you visited?'), 1, t('Oui', 'Yes'), t('Non', 'No')).to_i.zero?

      target = scene.choose_position(adv.crossroads)
      return dir unless target

      adv.x, adv.y = target
      scene.place_player
      return scene.choose_direction(adv.directions, dir)
    end

    def tile_roadblock(adv, scene, data, dir, dirs)
      types, block, success = Adventure::ROADBLOCKS[data[:variant].to_i]
      scene.display_message(Raids.pick(block))
      helper = adv.party.find { |pokemon| types.any? { |type| pokemon.type?(data_type(type).id) } }
      if helper
        scene.display_message(format(Raids.pick(success), helper.given_name))
        use(scene, data)
        return dir
      end
      names = types.map { |type| data_type(type).name }.join(' / ')
      scene.display_message(format(t('Un Pokémon de type %s pourrait vous aider…', 'A %s-type Pokémon may be able to help...'), names))
      return turn(dirs, Adventure::OPPOSITE[dir], dir)
    end

    def tile_hidden_trap(adv, scene, _data, dir, _dirs)
      return dir if rand(2).zero?

      scene.display_message(t('C’est un piège ! Votre équipe est blessée.', 'It’s a trap! Your party was hurt.'))
      adv.party.each { |pokemon| pokemon.hp = [pokemon.hp - pokemon.max_hp / 4, 1].max }
      return dir
    end

    def tile_berries(adv, scene, data, dir, _dirs)
      adv.party.each { |pokemon| pokemon.hp = [pokemon.hp + pokemon.max_hp / 2, pokemon.max_hp].min }
      scene.display_message(t('Vous trouvez des baies : votre équipe récupère des PV.', 'You found some Berries: your party recovered HP.'))
      use(scene, data)
      return dir
    end

    def tile_flare(adv, scene, data, dir, _dirs)
      adv.light += 1
      scene.display_message(t('Vous ramassez une torche : vous voyez plus loin.', 'You picked up a flare: you can see further.'))
      use(scene, data)
      scene.refresh_hud
      return dir
    end

    def tile_nurse(adv, scene, data, dir, _dirs)
      return dir unless scene.display_message(t('Une infirmière propose de soigner votre équipe. Accepter ?', 'A nurse offers to heal your party. Accept?'), 1, t('Oui', 'Yes'), t('Non', 'No')).to_i.zero?

      adv.party.each { |pokemon| pokemon.hp = pokemon.max_hp; pokemon.cure; pokemon.skills_set.each { |s| s&.pp = s.ppmax } }
      scene.display_message(t('Votre équipe est en pleine forme !', 'Your party was fully restored!'))
      use(scene, data)
      return dir
    end

    def tile_mystic(adv, scene, data, dir, _dirs)
      adv.hearts = adv.max_hearts
      scene.display_message(t('Une mystique apaise votre esprit : vos cœurs sont remplis !', 'A mystic cleansed your weary spirit: your hearts are full!'))
      use(scene, data)
      scene.refresh_hud
      return dir
    end

    def tile_partner_a(adv, scene, data, dir, _dirs)
      adv.max_hearts += 1 if adv.max_hearts < 6
      adv.hearts = [adv.hearts + 1, adv.max_hearts].min
      scene.display_message(t('Un dresseur vous encourage : vous gagnez un cœur !', 'A trainer cheered you on: you gained a heart!'))
      use(scene, data)
      scene.refresh_hud
      return dir
    end
    singleton_class.alias_method :tile_partner_b, :tile_partner_a

    def tile_mystery_npc(adv, scene, data, dir, dirs)
      kind = %i[tile_nurse tile_mystic tile_item_vendor tile_stat_trainer tile_move_tutor tile_assistant].sample
      return send(kind, adv, scene, data, dir, dirs)
    end

    def tile_assistant(adv, scene, data, dir, _dirs)
      offers = AdventureMenus.rental_offers(adv.style, adv.level, 2)
      return dir if offers.empty?
      return dir unless scene.display_message(t('Un assistant propose d’échanger un de vos Pokémon. Regarder ?', 'An assistant offers to trade one of your Pokémon. Take a look?'), 1, t('Oui', 'Yes'), t('Non', 'No')).to_i.zero?

      choice = nil
      scene.call_scene(CardScene, adv.style, t('Échange', 'Exchange'), offers, t('A : choisir   B : refuser', 'A: choose   B: decline')) { |s| choice = s.choice }
      if choice
        AdventureMenus.replace_member(adv, scene, offers[choice])
        use(scene, data)
      end
      return dir
    end

    HELD_ITEMS = %i[life_orb leftovers choice_band choice_specs sitrus_berry focus_sash expert_belt shell_bell scope_lens
                    muscle_band wise_glasses assault_vest rocky_helmet weakness_policy quick_claw].freeze

    def tile_item_vendor(adv, scene, data, dir, _dirs)
      items = HELD_ITEMS.select { |item| Raids.item_exists?(item) }.sample(3)
      return dir if items.empty?

      names = items.map { |item| Raids.item_name(item) }
      choice = scene.display_message(t('Un marchand offre un objet à tenir. Lequel ?', 'A vendor offers an item to hold. Which one?'), names.size + 1, *names, t('Aucun', 'None')).to_i
      return dir if choice >= items.size

      member = AdventureMenus.choose_member(adv, scene, t('Qui doit le tenir ?', 'Who should hold it?'))
      return dir unless member

      member.item_holding = data_item(items[choice]).id
      scene.display_message(format(t('%s tient maintenant : %s.', '%s is now holding %s.'), member.given_name, names[choice]))
      use(scene, data)
      return dir
    end

    STATS = [%i[ev_hp hp], %i[ev_atk atk], %i[ev_dfe dfe], %i[ev_spd spd], %i[ev_ats ats], %i[ev_dfs dfs]].freeze

    def tile_stat_trainer(adv, scene, data, dir, _dirs)
      member = AdventureMenus.choose_member(adv, scene, t('Une coach propose d’entraîner un Pokémon. Lequel ?', 'A trainer offers special training. Which Pokémon?'))
      return dir unless member

      names = [t('PV', 'HP'), t('Attaque', 'Attack'), t('Défense', 'Defense'), t('Vitesse', 'Speed'), t('Atq. Spé.', 'Sp. Atk'), t('Déf. Spé.', 'Sp. Def')]
      choice = scene.display_message(t('Quelle stat renforcer ?', 'Which stat?'), names.size + 1, *names, t('Annuler', 'Cancel')).to_i
      return dir if choice >= STATS.size

      STATS.each { |ev, _| member.send(:"#{ev}=", 0) unless ev == :ev_hp }
      member.send(:"#{STATS[choice][0]}=", 252)
      member.hp = [member.hp, member.max_hp].min
      scene.display_message(format(t('%s se sent plus fort !', '%s feels stronger!'), member.given_name))
      use(scene, data)
      return dir
    end

    def tile_move_tutor(adv, scene, data, dir, _dirs)
      member = AdventureMenus.choose_member(adv, scene, t('Un maître des capacités propose ses leçons. Pour qui ?', 'A move tutor offers lessons. For which Pokémon?'))
      return dir unless member

      known = member.skills_set.compact.map(&:db_symbol)
      pool = Raids.compile_moves(member.db_symbol, member.form, adv.style, rental: true).values.flatten.uniq - known
      moves = pool.sample(3)
      if moves.empty?
        scene.display_message(t('Il n’a rien à lui apprendre…', 'There is nothing to teach...'))
        return dir
      end
      names = moves.map { |m| data_move(m).name }
      choice = scene.display_message(t('Quelle capacité apprendre ?', 'Which move?'), names.size + 1, *names, t('Annuler', 'Cancel')).to_i
      return dir if choice >= moves.size

      olds = member.skills_set.map { |s| s&.name.to_s }
      slot = olds.size < 4 ? olds.size : scene.display_message(t('Oublier quelle capacité ?', 'Forget which move?'), olds.size + 1, *olds, t('Annuler', 'Cancel')).to_i
      return dir if slot > 3 || (olds.size >= 4 && slot >= olds.size)

      member.skills_set[slot] = PFM::Skill.new(moves[choice])
      scene.display_message(format(t('%s apprend %s !', '%s learned %s!'), member.given_name, names[choice]))
      use(scene, data)
      return dir
    end

    def tile_researcher(adv, scene, data, dir, _dirs)
      member = AdventureMenus.choose_member(adv, scene, t('Une chercheuse propose d’étudier un Pokémon. Lequel ?', 'A researcher offers to study a Pokémon. Which one?'))
      return dir unless member

      case adv.style
      when :tera
        type = Raids.random_tera_type(member)
        member.pj_tera_type = type if member.respond_to?(:pj_tera_type=)
        scene.display_message(format(t('Le type Téra de %s devient %s !', '%s’s Tera Type is now %s!'), member.given_name, data_type(type).name))
      when :max
        member.pj_dynamax_level = 10 if member.respond_to?(:pj_dynamax_level=)
        member.pj_gmax_factor = true if member.respond_to?(:pj_gmax_factor=)
        scene.display_message(format(t('%s est prêt pour le Dynamax (niveau 10) !', '%s is ready to Dynamax (level 10)!'), member.given_name))
      when :ultra
        crystal = Raids.z_crystal_for(member)
        member.item_holding = data_item(crystal).id if crystal
        scene.display_message(crystal ? format(t('%s reçoit : %s.', '%s received %s.'), member.given_name, Raids.item_name(crystal)) : t('Rien à faire pour ce Pokémon…', 'Nothing to do for this Pokémon...'))
      else
        Raids.set_hidden_ability(member)
        scene.display_message(format(t('%s révèle son talent caché !', '%s revealed its hidden ability!'), member.given_name))
      end
      use(scene, data)
      return dir
    end
  end

  # --- Menus ---------------------------------------------------------------------------------------------------------------
  module AdventureMenus
    module_function

    def t(fr, en = fr)
      return Raids.t(fr, en)
    end

    # @return [Array<PFM::Pokemon>] Pokémon de location proposés
    def rental_offers(style, level, count)
      entries = (3..5).flat_map { |rank| Raids.pool(style, rank) }.uniq { |e| [e[:species], e[:form]] }
      return entries.sample(count).map { |entry| Raids.create_rental(entry[:species], style, level, entry[:form]) }
    end

    # Choix des 3 Pokémon de location (3 tours de 3 cartes)
    # @return [Array<PFM::Pokemon>, nil]
    def choose_rentals(style, level)
      party = []
      3.times do |round|
        offers = rental_offers(style, level, 3)
        return nil if offers.empty?

        title = format(t('Location (%d/3)', 'Rental (%d/3)'), round + 1)
        choice = nil
        $scene.call_scene(CardScene, style, title, offers, t('A : choisir   B : abandonner', 'A: choose   B: quit')) { |s| choice = s.choice }
        return nil unless choice

        party << offers[choice]
      end
      return party
    end

    # @return [PFM::Pokemon, nil] membre de l'équipe choisi
    def choose_member(adv, scene, question)
      names = adv.party.map { |pokemon| pokemon.given_name }
      choice = scene.display_message(question, names.size + 1, *names, t('Annuler', 'Cancel')).to_i
      return choice < adv.party.size ? adv.party[choice] : nil
    end

    # Le nouveau Pokémon remplace un membre de l'équipe
    def replace_member(adv, scene, pokemon)
      member = choose_member(adv, scene, format(t('%s remplace qui ?', 'Who should %s replace?'), pokemon.given_name))
      return false unless member

      adv.party[adv.party.index(member)] = pokemon
      $actors.replace(adv.party)
      scene.display_message(format(t('%s rejoint l’équipe !', '%s joined the party!'), pokemon.given_name))
      return true
    end

    # Après une capture : échanger avec un membre ?
    def exchange(adv, scene, captured)
      choice = scene.display_message(format(t('Prendre %s dans l’équipe ?', 'Add %s to the party?'), captured.given_name), 1, t('Oui', 'Yes'), t('Non', 'No')).to_i
      return unless choice.zero?

      copy = captured.clone
      copy.hp = copy.max_hp
      replace_member(adv, scene, copy)
    end

    # Pause (aux croisements) : équipe, abandon
    def pause(adv, scene)
      choices = [t('Voir l’équipe', 'Check Party'), t('Abandonner', 'End Adventure'), t('Retour', 'Back')]
      case scene.display_message(t('Que faire ?', 'What would you like to do?'), choices.size, *choices).to_i
      when 0
        GamePlay.open_party_menu(adv.party)
      when 1
        sure = scene.display_message(t('Abandonner l’aventure ?', 'End the adventure?'), 1, t('Oui', 'Yes'), t('Non', 'No')).to_i
        adv.outcome = :quit if sure.zero?
      end
    end

    # Fin : choix du Pokémon à garder
    def spoils(adv, scene)
      list = adv.captures.uniq
      return if list.empty?

      choice = nil
      scene.call_scene(CardScene, adv.style, t('Butin', 'Spoils'), list, t('A : garder ce Pokémon   B : aucun', 'A: keep this Pokémon   B: none')) { |s| choice = s.choice }
      adv.instance_variable_set(:@kept, choice ? list[choice] : nil)
    end

    # Pokémon gardé (après le retour de l'équipe)
    def keep_spoils(adv)
      pokemon = adv.instance_variable_get(:@kept)
      return unless pokemon

      pokemon.hp = pokemon.max_hp
      pokemon.cure
      $game_system.map_interpreter.add_pokemon(pokemon)
      $scene.display_message(format(t('%s vous suit désormais !', '%s is now yours!'), pokemon.given_name)) if $scene.respond_to?(:display_message)
    end
  end
end

# PokeSmart : appli Debug (seulement quand le jeu est lancé en mode debug, jamais dans la version finale)
#
# Raccourcis de test sans passer par des commandes d'évent : soigner / monter l'équipe, donner un Pokémon ou un objet,
# argent, badges, Pokédex complet, téléportation par zone, traverser les murs, rencontres sauvages,
# interrupteurs et variables, applis du téléphone et amis.
# Haut / bas : choisir ; gauche / droite : une page ; A : valider ; B : revenir.
module UI
  module PokeSmart
    # Affiche l'appli Debug (en mode debug seulement)
    DEBUG_APP = true
    # Niveau des Pokémon donnés par l'appli Debug
    DEBUG_POKEMON_LEVEL = 50
    # Quantité des objets donnés par l'appli Debug
    DEBUG_ITEM_COUNT = 10
    # Argent donné par l'appli Debug
    DEBUG_MONEY = 10_000
    # Nombre de badges donnés par « Tous les badges » (région 1)
    DEBUG_BADGES = 8
    # Au-delà de ce nombre de lignes, une liste est d'abord découpée en tranches
    DEBUG_GROUP_SIZE = 50

    module_function

    # @return [Boolean] si l'appli Debug est disponible (jeu lancé en mode debug, pas la version finale)
    def debug_app?
      return DEBUG_APP && PSDK_CONFIG.debug? && !PSDK_CONFIG.release?
    rescue StandardError
      return false
    end
  end
end

module GamePlay
  class Menu
    module SmartStyle
      # Entrées du menu principal de l'appli Debug
      DEBUG_MENU = %i[heal level1 level10 pokemon item money badges dex warp through encounters switches variables
                      apps friends].freeze

      public

      # Appli Debug : menu des raccourcis de test
      def open_debug
        @debug = true
        @debug_stack = []
        debug_main(0)
      end

      # Ferme l'appli Debug
      def close_debug
        @debug = nil
        @debug_stack = nil
        @debug_list = nil
        close_customization
      end

      private

      # --- Listes ------------------------------------------------------------------------------

      # Affiche une liste de l'appli Debug
      # @param title [String]
      # @param entries [Array<Array(String, Proc)>] [texte, action] ; l'action reçoit l'index de la ligne
      # @param index [Integer]
      # @param back [Proc, nil] B (nil = fermer l'appli)
      def debug_show(title, entries, index = 0, back = nil)
        @debug_list = { title: title, entries: entries, back: back }
        @custom_level = :debug
        open_picker(entries.map(&:first), index, title)
      end

      # Longue liste découpée en tranches (« 1-50 », « 51-100 »…), puis les éléments de la tranche choisie
      # @param title [String]
      # @param items [Array<Array(String, Object)>] [texte, valeur]
      # @param back [Proc]
      # @yieldparam value [Object] valeur choisie
      def debug_choose(title, items, back, &on_pick)
        show_groups = nil
        show_slice = lambda do |from, group_index|
          slice = items[from, UI::PokeSmart::DEBUG_GROUP_SIZE] || []
          back_to_groups = items.size > UI::PokeSmart::DEBUG_GROUP_SIZE ? -> { show_groups.call(group_index) } : back
          debug_show(title, slice.map { |label, value| [label, proc { on_pick.call(value) }] }, 0, back_to_groups)
        end
        show_groups = lambda do |index|
          size = UI::PokeSmart::DEBUG_GROUP_SIZE
          groups = (0...items.size).step(size).map do |from|
            last = [from + size, items.size].min
            label = "#{items[from][0].to_s[0, 5].strip}-#{items[last - 1][0].to_s[0, 5].strip}"
            [label, proc { show_slice.call(from, from / size) }]
          end
          debug_show(title, groups, index, back)
        end
        items.size > UI::PokeSmart::DEBUG_GROUP_SIZE ? show_groups.call(0) : show_slice.call(0, 0)
      end

      # Résultat d'une action, affiché à la place du titre
      # @param text [String]
      def debug_done(text)
        @phone.title = text
      end

      # --- Menu principal ----------------------------------------------------------------------

      # @param index [Integer]
      def debug_main(index)
        entries = DEBUG_MENU.map { |key| [debug_label(key), proc { debug_run(key) }] }
        debug_show('Debug', entries, index)
      end

      # @param key [Symbol]
      # @return [String]
      def debug_label(key)
        case key
        when :heal then 'Soigner'
        when :level1 then 'Niveau +1'
        when :level10 then 'Niveau +10'
        when :pokemon then 'Pokémon'
        when :item then 'Objets'
        when :money then "Argent +#{UI::PokeSmart::DEBUG_MONEY}"
        when :badges then 'Badges'
        when :dex then 'Pokédex complet'
        when :warp then 'Téléportation'
        when :through then "Traverser : #{$game_player&.through ? 'oui' : 'non'}"
        when :encounters then "Rencontres : #{debug_encounters? ? 'oui' : 'non'}"
        when :switches then 'Interrupteurs'
        when :variables then 'Variables'
        when :apps then 'Applis'
        when :friends then 'Amis'
        else key.to_s
        end
      end

      # @param key [Symbol]
      def debug_run(key)
        index = DEBUG_MENU.index(key) || 0
        back = -> { debug_main(index) }
        case key
        when :heal then debug_heal
        when :level1 then debug_level(1)
        when :level10 then debug_level(10)
        when :pokemon then return debug_pokemon(back)
        when :item then return debug_items(back)
        when :money then debug_money
        when :badges then debug_badges
        when :dex then debug_dex
        when :warp then return debug_warp(back)
        when :through then $game_player.through = !$game_player.through
        when :encounters then debug_toggle_encounters
        when :switches then return debug_switches(back)
        when :variables then return debug_variables(back)
        when :apps then return debug_apps(back)
        when :friends then return debug_friends(back)
        end
        title = @phone_title_after_debug
        debug_main(index)
        debug_done(title) if title
      rescue StandardError => e
        log_error("PokeSmart debug : #{e.class} #{e.message}") if respond_to?(:log_error, true)
        debug_main(DEBUG_MENU.index(key) || 0)
        debug_done('Erreur (voir la console)')
      ensure
        @phone_title_after_debug = nil
      end

      # Titre à afficher quand le menu est réaffiché
      # @param text [String]
      def debug_result(text)
        @phone_title_after_debug = text
      end

      # --- Équipe ------------------------------------------------------------------------------

      def debug_heal
        $actors.compact.each do |pokemon|
          pokemon.cure
          pokemon.hp = pokemon.max_hp
          pokemon.skills_set.compact.each { |skill| skill.pp = skill.ppmax }
        end
        debug_result('Équipe soignée')
      end

      # @param amount [Integer]
      def debug_level(amount)
        $actors.compact.each do |pokemon|
          next if pokemon.egg?

          # comme give_level de PSDK, sans les messages, l'apprentissage des capacités ni l'évolution
          amount.times do
            break if pokemon.level >= PFM.game_state.level_max_limit

            pokemon.level_up_stat_refresh
          end
          pokemon.hp = pokemon.max_hp
        end
        debug_result("Niveau +#{amount}")
      end

      # Donner un Pokémon (au niveau DEBUG_POKEMON_LEVEL, dans l'équipe ou le PC)
      # @param back [Proc]
      def debug_pokemon(back)
        items = each_data_creature.reject { |creature| creature.db_symbol == :__undef__ }
                                  .map { |creature| [format('%03d %s', creature.id, debug_short(creature.name, 10)), creature.db_symbol] }
        debug_choose('Pokémon', items, back) do |db_symbol|
          pokemon = PFM::Pokemon.new(db_symbol, UI::PokeSmart::DEBUG_POKEMON_LEVEL)
          added = PFM.game_state.add_pokemon(pokemon)
          PFM.game_state.pokedex.mark_seen(db_symbol, forced: true)
          PFM.game_state.pokedex.mark_captured(db_symbol)
          debug_done(added ? "#{pokemon.name} reçu" : 'Plus de place')
        end
      end

      # --- Objets, argent, badges, Pokédex -----------------------------------------------------

      # Donner un objet (DEBUG_ITEM_COUNT exemplaires)
      # @param back [Proc]
      def debug_items(back)
        items = each_data_item.reject { |item| item.db_symbol == :__undef__ }
                              .map { |item| [debug_short(item.name, 14), item.db_symbol] }
                              .sort_by { |name, _| name.to_s.downcase }
        debug_choose('Objets', items, back) do |db_symbol|
          PFM.game_state.bag.add_item(db_symbol, UI::PokeSmart::DEBUG_ITEM_COUNT)
          debug_done("#{data_item(db_symbol).name} x#{UI::PokeSmart::DEBUG_ITEM_COUNT}")
        end
      end

      def debug_money
        state = PFM.game_state
        if state.respond_to?(:add_money)
          state.add_money(UI::PokeSmart::DEBUG_MONEY)
        else
          state.money += UI::PokeSmart::DEBUG_MONEY
        end
        debug_result("Argent : #{state.money}")
      end

      def debug_badges
        UI::PokeSmart::DEBUG_BADGES.times { |i| $trainer.set_badge(i + 1, 1, true) }
        debug_result("#{UI::PokeSmart::DEBUG_BADGES} badges obtenus")
      end

      def debug_dex
        dex = PFM.game_state.pokedex
        dex.enable
        each_data_creature do |creature|
          next if creature.db_symbol == :__undef__

          dex.mark_seen(creature.db_symbol, forced: true)
          dex.mark_captured(creature.db_symbol)
        end
        debug_result('Pokédex complet')
      end

      # --- Carte -------------------------------------------------------------------------------

      # Téléportation dans une zone (point de vol de la zone, sinon centre de sa première carte)
      # @param back [Proc]
      def debug_warp(back)
        zones = each_data_zone.select { |zone| zone.maps&.any? }
                              .map { |zone| [debug_short(zone.name.to_s.empty? ? zone.db_symbol.to_s : zone.name, 14), zone] }
        debug_choose('Téléportation', zones, back) do |zone|
          map_id = zone.maps.first
          x = zone.warp&.x
          y = zone.warp&.y
          unless x && y
            map = load_data(format('Data/Map%03d.rxdata', map_id))
            x = map.width / 2
            y = map.height / 2
          end
          $game_temp.player_new_map_id = map_id
          $game_temp.player_new_x = x
          $game_temp.player_new_y = y
          $game_temp.player_new_direction = 2
          $game_temp.player_transferring = true
          close_debug
          @quiting = true
        end
      end

      # @return [Boolean] si les Pokémon sauvages peuvent apparaître
      def debug_encounters?
        return PFM.game_state.get_repel_count < 99_999
      rescue StandardError
        return true
      end

      # Rencontres sauvages : coupées par un Repousse « infini », remises en enlevant le Repousse
      def debug_toggle_encounters
        PFM.game_state.set_repel_count(debug_encounters? ? 999_999 : 0)
      end

      # --- Interrupteurs et variables ----------------------------------------------------------

      # Tranches d'une longue liste d'identifiants (« 1-50 », « 51-100 »…)
      # @param title [String]
      # @param count [Integer] nombre d'identifiants (1 à count)
      # @param index [Integer] tranche sélectionnée
      # @param back [Proc]
      # @yieldparam from [Integer] premier identifiant de la tranche choisie
      # @yieldparam group_back [Proc] retour aux tranches
      def debug_groups(title, count, index, back, &show)
        size = UI::PokeSmart::DEBUG_GROUP_SIZE
        return show.call(1, back) if count <= size

        groups = (1..count).step(size).map do |from|
          group_index = (from - 1) / size
          ["#{from}-#{[from + size - 1, count].min}", proc { show.call(from, -> { debug_groups(title, count, group_index, back, &show) }) }]
        end
        debug_show(title, groups, index, back)
      end

      # @param text [String]
      # @param max [Integer]
      # @return [String] texte raccourci pour tenir dans une ligne
      def debug_short(text, max = 11)
        text = text.to_s
        return text.size > max ? "#{text[0, max - 1]}…" : text
      end

      # A : allume / éteint l'interrupteur (la liste reste ouverte)
      # @param back [Proc]
      def debug_switches(back)
        names = $data_system.switches
        debug_groups('Interrupteurs', names.size - 1, 0, back) do |from, group_back|
          debug_switch_list(from, 0, group_back)
        end
      end

      # @param from [Integer] premier interrupteur de la tranche
      # @param index [Integer]
      # @param back [Proc]
      def debug_switch_list(from, index, back)
        names = $data_system.switches
        last = [from + UI::PokeSmart::DEBUG_GROUP_SIZE, names.size].min
        entries = (from...last).map do |id|
          ["#{id} #{debug_short(names[id], 9)} #{$game_switches[id] ? 'ON' : 'off'}", proc do |row|
            $game_switches[id] = !$game_switches[id]
            $game_map.need_refresh = true
            debug_switch_list(from, row, back)
          end]
        end
        debug_show('Interrupteurs', entries, index, back)
      end

      # A : choisir la variable, puis la modifier (+1, -1, +10, -10, 0)
      # @param back [Proc]
      def debug_variables(back)
        names = $data_system.variables
        debug_groups('Variables', names.size - 1, 0, back) do |from, group_back|
          debug_variable_list(from, 0, group_back)
        end
      end

      # @param from [Integer] première variable de la tranche
      # @param index [Integer]
      # @param back [Proc]
      def debug_variable_list(from, index, back)
        names = $data_system.variables
        last = [from + UI::PokeSmart::DEBUG_GROUP_SIZE, names.size].min
        entries = (from...last).map do |id|
          ["#{id} #{debug_short(names[id], 8)}=#{$game_variables[id]}", proc { |row| debug_variable(id, -> { debug_variable_list(from, row, back) }) }]
        end
        debug_show('Variables', entries, index, back)
      end

      # @param id [Integer] variable
      # @param back [Proc] retour à la liste des variables
      # @param index [Integer]
      def debug_variable(id, back, index = 0)
        changes = [['+1', 1], ['-1', -1], ['+10', 10], ['-10', -10], ['= 0', nil]]
        entries = changes.map do |label, delta|
          [label, proc do |row|
            $game_variables[id] = delta ? $game_variables[id].to_i + delta : 0
            $game_map.need_refresh = true
            debug_variable(id, back, row)
          end]
        end
        debug_show("V#{id} = #{$game_variables[id]}", entries, index, back)
      end

      # --- Téléphone ---------------------------------------------------------------------------

      # Débloquer / rebloquer les applis réglées « par une commande » dans Studio
      # @param back [Proc]
      # @param index [Integer]
      def debug_apps(back, index = 0)
        ps = UI::PokeSmart
        locked = ps.studio_locked_apps
        entries = [['Tout débloquer', proc do
          locked.each { |action| ps.unlock_app(action) }
          debug_refresh_home
          debug_apps(back)
          debug_done(locked.empty? ? 'Aucune appli à débloquer' : 'Applis débloquées')
        end]]
        locked.each do |action|
          names = ps::APP_NAMES[action]
          name = ps.studio_app_name(action) || (names ? names[ps.french? ? 0 : 1] : action.to_s.sub(/\Aopen_/, ''))
          entries << ["#{name} : #{ps.app_unlocked?(action) ? 'oui' : 'non'}", proc do |row|
            ps.app_unlocked?(action) ? ps.lock_app(action) : ps.unlock_app(action)
            debug_refresh_home
            debug_apps(back, row)
          end]
        end
        debug_show('Applis', entries, index, back)
      end

      # Recrée les applis du téléphone (applis débloquées ou rebloquées)
      def debug_refresh_home
        action = @buttons[@index]&.action
        init_indexes
        rebuild_phone
        @index = @buttons.index { |button| button.action == action } || 0
        hide_home_buttons
      end

      # Amis : rencontrer tous les contacts, affinité au maximum, recevoir tous les messages
      # @param back [Proc]
      def debug_friends(back)
        friends = UI::PokeSmart::Friends
        all = -> { friends.contacts.map { |contact| contact[:id] } }
        entries = [
          ['Rencontrer tous', proc do
            all.call.each { |id| friends.meet(id) }
            debug_done('Contacts rencontrés')
          end],
          ['Affinité max', proc do
            all.call.each { |id| friends.add_affinity(id, UI::PokeSmart::FRIEND_MAX_AFFINITY) }
            debug_done('Affinité au maximum')
          end],
          ['Tous les messages', proc do
            all.call.each { |id| friends.messages_of(id).each { |message| friends.send_message(id, message[:id]) } }
            debug_done('Messages reçus')
          end]
        ]
        debug_show('Amis', entries, 0, back)
      end

      # --- Touches (appelées par la liste de choix de Personnaliser) ---------------------------

      # A : action de la ligne
      def debug_validate
        entry = @debug_list[:entries][@picker.index]
        return unless entry

        entry.last.arity == 0 ? entry.last.call : entry.last.call(@picker.index)
      rescue StandardError => e
        log_error("PokeSmart debug : #{e.class} #{e.message}") if respond_to?(:log_error, true)
        debug_done('Erreur (voir la console)')
      end

      # B : liste d'avant, ou fermer l'appli
      def debug_back
        back = @debug_list[:back]
        back ? back.call : close_debug
      end

      # Haut / bas / gauche / droite : la même liste, autre ligne
      # @param index [Integer]
      def debug_select(index)
        open_picker(@debug_list[:entries].map(&:first), index, @debug_list[:title])
      end
    end

    if UI::PokeSmart::ENABLED
      register_button(:open_debug) { UI::PokeSmart.debug_app? } unless ACTION_LIST.include?(:open_debug)
    end
  end
end

# PokeSmart : appli Debug (seulement quand le jeu est lancé en mode debug, jamais dans la version finale)
#
# L'appli ouvre un écran Debug en plein écran (images dans graphics/interface/debug) avec des raccourcis de test,
# sans passer par des commandes d'évent :
#   Équipe        : soigner, niveaux
#   Pokémon       : recevoir n'importe quel Pokémon (niveau réglable, X = chromatique)
#   Objets        : recevoir n'importe quel objet (quantité réglable)
#   Joueur        : argent, badges, Pokédex complet, traverser les murs, rencontres sauvages, vitesse
#   Carte         : téléportation dans une zone de Studio
#   Interrupteurs : allumer / éteindre
#   Variables     : modifier
#   Téléphone     : applis à débloquer, amis
# Touches : L / R = catégorie, haut / bas = ligne, gauche / droite = régler (sinon page), A = valider,
#           X = action secondaire (indiquée en bas), B = quitter. Souris : clic, molette, clic droit = quitter.
module UI
  module PokeSmart
    # Affiche l'appli Debug (en mode debug seulement)
    DEBUG_APP = true
    # Niveau proposé pour les Pokémon donnés
    DEBUG_POKEMON_LEVEL = 50
    # Quantité proposée pour les objets donnés
    DEBUG_ITEM_COUNT = 10
    # Argent donné par A sur « Argent » (gauche / droite : 1 000)
    DEBUG_MONEY = 10_000
    # Nombre de badges de la région 1
    DEBUG_BADGES = 8

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
  # Écran Debug du téléphone (plein écran)
  class PokeSmartDebug < BaseCleanUpdate
    # Catégories : [clé, titre, aide affichée en bas]
    CATEGORIES = [
      [:team, 'Équipe', 'A : valider   Droite : niveau +1'],
      [:pokemon, 'Pokémon', 'A : recevoir   X : chromatique'],
      [:items, 'Objets', 'A : recevoir'],
      [:player, 'Joueur', 'A : valider   Gauche / droite : régler'],
      [:map, 'Carte', 'A : se téléporter'],
      [:switches, 'Interrupteurs', 'A : allumer / éteindre'],
      [:variables, 'Variables', 'Gauche / droite : -1 / +1   A : +10   X : 0'],
      [:phone, 'Téléphone', 'A : valider   Gauche / droite : régler']
    ]
    # Dossier des images
    DIR = 'debug/'
    # Lignes visibles et position de la première
    ROWS = 7
    ROW_X = 13
    ROW_Y = 69
    ROW_SPACING = 19
    # Largeur de la partie « nom » d'une ligne (le reste affiche la valeur)
    LABEL_WIDTH = 141
    ROW_WIDTH = 295
    # Icônes des catégories
    ICON_X = 15
    ICON_Y = 29
    ICON_STEP = 38
    # Durée d'affichage d'un résultat dans la bande du bas (images)
    MESSAGE_TIME = 150

    # @return [Boolean] si le joueur a été téléporté (le menu se ferme)
    attr_reader :warped
    # @return [Boolean] si les applis du téléphone ont changé (le menu se recrée)
    attr_reader :phone_changed

    def initialize
      super()
      @category = 0
      @indexes = Array.new(CATEGORIES.size, 0)
      @firsts = Array.new(CATEGORIES.size, 0)
      @give_level = UI::PokeSmart::DEBUG_POKEMON_LEVEL
      @give_count = UI::PokeSmart::DEBUG_ITEM_COUNT
      @message_timer = 0
      @warped = false
      @phone_changed = false
      @running = true
    end

    def update_inputs
      return false unless @entries

      if Input.trigger?(:B)
        play_cancel_se
        @running = false
      elsif Input.trigger?(:L) || Input.trigger?(:R)
        change_category(@category + (Input.trigger?(:L) ? -1 : 1))
      elsif Input.repeat?(:UP) || Input.repeat?(:DOWN)
        move_to(index + (Input.repeat?(:UP) ? -1 : 1), true)
      elsif Input.repeat?(:LEFT) || Input.repeat?(:RIGHT)
        side = Input.repeat?(:LEFT) ? :left : :right
        entry[side] ? run(entry[side]) : move_to(index + (side == :left ? -ROWS : ROWS), false)
      elsif Input.trigger?(:A)
        entry[:a] ? run(entry[:a], true) : play_buzzer_se
      elsif Input.trigger?(:X)
        entry[:x] ? run(entry[:x], true) : play_buzzer_se
      else
        return true
      end
      return false
    end

    def update_mouse(moved)
      if Mouse.wheel != 0
        move_to(index + (Mouse.wheel > 0 ? -3 : 3), false)
        Mouse.wheel = 0
        return false
      end
      if Mouse.trigger?(:RIGHT)
        play_cancel_se
        @running = false
        return false
      end
      return true unless Mouse.trigger?(:LEFT)

      mouse_click(Mouse.x, Mouse.y)
      return false
    end

    def update_graphics
      return true if @message_timer <= 0

      @message_timer -= 1
      show_help if @message_timer == 0
      return true
    end

    private

    def create_graphics
      super
      @background = Sprite.new(@viewport).set_bitmap("#{DIR}background", :interface)
      @header = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @header.add_text(8, 4, 100, 16, 'DEBUG', 0, color: UI::PokeSmart::DARK)
      @title = @header.add_text(158, 3, 104, 16, '', 0, color: UI::PokeSmart::WHITE)
      @counter = @header.add_text(262, 3, 52, 16, '', 2, color: UI::PokeSmart::WHITE)
      @icons = CATEGORIES.each_index.map do |i|
        icon = @header.add_sprite(ICON_X + i * ICON_STEP, ICON_Y, "#{DIR}categories", 2, CATEGORIES.size, type: SpriteSheet)
        icon.select(0, i)
        next icon
      end
      @scroll_up = @header.add_sprite(153, 57, "#{DIR}scroll_up")
      @scroll_down = @header.add_sprite(153, 201, "#{DIR}scroll_down")
      @help = @header.add_text(8, 220, 304, 16, '', 0, color: UI::PokeSmart::WHITE)
      @selector = Sprite.new(@viewport).set_bitmap("#{DIR}selector", :interface)
      change_category(0, false)
    end

    # --- Navigation ----------------------------------------------------------------------------

    # @return [Integer] ligne sélectionnée
    def index
      return @indexes[@category]
    end

    # @return [Integer] première ligne affichée
    def first
      return @firsts[@category]
    end

    # @return [Hash] ligne sélectionnée
    def entry
      return @entries[index] || {}
    end

    # @param category [Integer]
    # @param sound [Boolean]
    def change_category(category, sound = true)
      play_cursor_se if sound
      @category = category % CATEGORIES.size
      @icons.each_with_index { |icon, i| icon.select(i == @category ? 1 : 0, i) }
      @title.text = CATEGORIES[@category][1]
      refresh
      show_help
    end

    # @param target [Integer]
    # @param wrap [Boolean] haut / bas font le tour de la liste
    def move_to(target, wrap)
      count = @entries.size
      return if count == 0

      target = wrap ? target % count : target.clamp(0, count - 1)
      return if target == index

      play_cursor_se
      @indexes[@category] = target
      draw_rows
    end

    # Clic : icône de catégorie, ligne (2e clic = valider, ou régler sur la valeur), flèches de défilement
    # @param mx [Integer]
    # @param my [Integer]
    def mouse_click(mx, my)
      if my.between?(ICON_Y, ICON_Y + 21)
        icon = (mx - ICON_X + (ICON_STEP - 23) / 2) / ICON_STEP
        change_category(icon) if icon.between?(0, CATEGORIES.size - 1) && icon != @category
      elsif mx.between?(ROW_X, ROW_X + ROW_WIDTH - 1) && my >= ROW_Y && (my - ROW_Y) % ROW_SPACING < 15
        row = first + (my - ROW_Y) / ROW_SPACING
        return unless row < @entries.size && row < first + ROWS
        return move_to(row, false) if row != index

        if (entry[:left] || entry[:right]) && mx >= ROW_X + LABEL_WIDTH
          side = mx < ROW_X + LABEL_WIDTH + (ROW_WIDTH - LABEL_WIDTH) / 2 ? :left : :right
          run(entry[side]) if entry[side]
        elsif entry[:a]
          run(entry[:a], true)
        end
      elsif mx.between?(148, 172) && my.between?(55, 66)
        move_to(index - ROWS, false)
      elsif mx.between?(148, 172) && my.between?(199, 210)
        move_to(index + ROWS, false)
      end
    end

    # Lance l'action d'une ligne puis met l'écran à jour
    # @param action [Proc]
    # @param decision [Boolean] son de validation (sinon son du curseur)
    def run(action, decision = false)
      decision ? play_decision_se : play_cursor_se
      result = action.call
      say(result) if result.is_a?(String)
      refresh unless @warped
    rescue StandardError => e
      log_error("PokeSmart debug : #{e.class} #{e.message}") if respond_to?(:log_error, true)
      play_buzzer_se
      say("Erreur : #{e.message}"[0, 60])
    end

    # Message dans la bande du bas (puis l'aide revient)
    # @param text [String]
    def say(text)
      @help.text = text
      @message_timer = MESSAGE_TIME
    end

    def show_help
      @help.text = CATEGORIES[@category][2]
    end

    # Recalcule les lignes de la catégorie
    def refresh
      @entries = send(:"entries_#{CATEGORIES[@category][0]}")
      @indexes[@category] = index.clamp(0, [@entries.size - 1, 0].max)
      draw_rows
    end

    def draw_rows
      @firsts[@category] = first.clamp([index - ROWS + 1, 0].max, index)
      @rows&.dispose
      @rows = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @entries[first, ROWS]&.each_with_index do |row_entry, i|
        y = ROW_Y + i * ROW_SPACING
        @rows.add_sprite(ROW_X, y, "#{DIR}#{(first + i).even? ? 'row' : 'row_alt'}")
        @rows.add_text(ROW_X + 4, y - 1, LABEL_WIDTH - 6, 16, row_entry[:label].to_s, 0, color: UI::PokeSmart::WHITE)
        value_x = ROW_X + LABEL_WIDTH + 2
        value_width = ROW_WIDTH - LABEL_WIDTH - 2
        @rows.add_sprite(value_x + 4, y, "#{DIR}arrow_left") if row_entry[:left]
        @rows.add_sprite(value_x + value_width - 12, y, "#{DIR}arrow_right") if row_entry[:right]
        @rows.add_text(value_x + 14, y - 1, value_width - 28, 16, row_entry[:value].to_s, 1, color: UI::PokeSmart::DARK)
      end
      if @entries.empty?
        @rows.add_text(ROW_X, ROW_Y + 40, ROW_WIDTH, 16, 'Rien ici', 1, color: UI::PokeSmart::DARK)
        @selector.visible = false
      else
        @selector.visible = true
        @selector.set_position(ROW_X - 2, ROW_Y - 2 + (index - first) * ROW_SPACING)
      end
      @counter.text = @entries.empty? ? '' : "#{index + 1}/#{@entries.size}"
      @scroll_up.visible = first > 0
      @scroll_down.visible = first + ROWS < @entries.size
    end

    # --- Lignes des catégories -----------------------------------------------------------------
    # Une ligne : { label:, value:, a:, x:, left:, right: } (une action peut renvoyer le texte du résultat)

    def entries_team
      list = [
        { label: "Soigner l'équipe", value: 'A', a: proc { debug_heal($actors) && 'Équipe soignée' } },
        { label: 'Niveau +1 (équipe)', value: 'A', a: proc { debug_level($actors, 1) } },
        { label: 'Niveau +10 (équipe)', value: 'A', a: proc { debug_level($actors, 10) } }
      ]
      $actors.compact.each do |pokemon|
        list << { label: pokemon.given_name, value: pokemon.egg? ? 'Œuf' : "N.#{pokemon.level}  #{pokemon.hp}/#{pokemon.max_hp}",
                  a: proc { debug_heal([pokemon]) }, right: proc { debug_level([pokemon], 1) } }
      end
      return list
    end

    def entries_pokemon
      @creatures ||= each_data_creature.reject { |creature| creature.db_symbol == :__undef__ }
                                       .map { |creature| [format('%03d %s', creature.id, creature.name), creature.db_symbol] }
      list = [{ label: 'Niveau donné', value: @give_level.to_s,
                left: proc { @give_level = [@give_level - 1, 1].max; nil },
                right: proc { @give_level = [@give_level + 1, 100].min; nil } }]
      @creatures.each do |label, db_symbol|
        list << { label: label, value: '', a: proc { debug_give_pokemon(db_symbol, false) }, x: proc { debug_give_pokemon(db_symbol, true) } }
      end
      return list
    end

    def entries_items
      @items ||= each_data_item.reject { |item| item.db_symbol == :__undef__ }
                               .map { |item| [item.name.to_s, item.db_symbol] }
                               .sort_by { |name, _| name.downcase }
      bag = PFM.game_state.bag
      list = [{ label: 'Quantité', value: "x#{@give_count}",
                left: proc { @give_count = [@give_count - 1, 1].max; nil },
                right: proc { @give_count = [@give_count + 1, 999].min; nil } }]
      @items.each do |name, db_symbol|
        owned = bag.respond_to?(:item_quantity) ? bag.item_quantity(db_symbol) : nil
        list << { label: name, value: owned ? "Sac : #{owned}" : '', a: proc do
          bag.add_item(db_symbol, @give_count)
          next "#{name} x#{@give_count}"
        end }
      end
      return list
    end

    def entries_player
      state = PFM.game_state
      badges = debug_badge_count
      return [
        { label: 'Argent', value: state.money.to_s, a: proc { debug_money(UI::PokeSmart::DEBUG_MONEY) },
          left: proc { debug_money(-1000) }, right: proc { debug_money(1000) } },
        { label: 'Badges', value: badges ? "#{badges}/#{UI::PokeSmart::DEBUG_BADGES}" : '?',
          a: proc { debug_badges(UI::PokeSmart::DEBUG_BADGES) },
          left: proc { debug_badges((badges || 0) - 1) }, right: proc { debug_badges((badges || 0) + 1) } },
        { label: 'Pokédex complet', value: 'A', a: proc { debug_dex } },
        { label: 'Traverser les murs', value: $game_player.through ? 'ON' : 'off', a: proc { debug_through },
          left: proc { debug_through }, right: proc { debug_through } },
        { label: 'Rencontres', value: debug_encounters? ? 'ON' : 'off', a: proc { debug_toggle_encounters },
          left: proc { debug_toggle_encounters }, right: proc { debug_toggle_encounters } },
        { label: 'Vitesse', value: $game_player.move_speed.to_s,
          left: proc { debug_speed(-1) }, right: proc { debug_speed(1) } }
      ]
    end

    def entries_map
      list = [{ label: 'Position', value: "#{$game_map.map_id} : #{$game_player.x}, #{$game_player.y}" }]
      each_data_zone.each do |zone|
        next unless zone.maps&.any?

        name = zone.name.to_s.empty? ? zone.db_symbol.to_s : zone.name.to_s
        list << { label: name, value: "Carte #{zone.maps.first}", a: proc { debug_warp(zone) } }
      end
      return list
    end

    def entries_switches
      names = $data_system.switches
      return (1...names.size).map do |id|
        toggle = proc do
          $game_switches[id] = !$game_switches[id]
          $game_map.need_refresh = true
          nil
        end
        { label: format('%03d %s', id, names[id]), value: $game_switches[id] ? 'ON' : 'off', a: toggle, left: toggle, right: toggle }
      end
    end

    def entries_variables
      names = $data_system.variables
      return (1...names.size).map do |id|
        change = lambda do |value|
          $game_variables[id] = value
          $game_map.need_refresh = true
          nil
        end
        { label: format('%03d %s', id, names[id]), value: $game_variables[id].to_s,
          left: proc { change.call($game_variables[id].to_i - 1) }, right: proc { change.call($game_variables[id].to_i + 1) },
          a: proc { change.call($game_variables[id].to_i + 10) }, x: proc { change.call(0) } }
      end
    end

    def entries_phone
      ps = UI::PokeSmart
      locked = ps.studio_locked_apps
      list = []
      unless locked.empty?
        list << { label: 'Débloquer les applis', value: 'A', a: proc do
          locked.each { |action| ps.unlock_app(action) }
          @phone_changed = true
          next 'Applis débloquées'
        end }
        locked.each do |action|
          toggle = proc do
            ps.app_unlocked?(action) ? ps.lock_app(action) : ps.unlock_app(action)
            @phone_changed = true
            nil
          end
          list << { label: "Appli #{debug_app_name(action)}", value: ps.app_unlocked?(action) ? 'ON' : 'off', a: toggle, left: toggle, right: toggle }
        end
      end
      return list unless defined?(ps::Friends)

      friends = ps::Friends
      ids = friends.contacts.map { |contact| contact[:id] }
      return list if ids.empty?

      list << { label: 'Rencontrer les amis', value: 'A', a: proc do
        ids.each { |id| friends.meet(id) }
        @phone_changed = true
        next 'Amis rencontrés'
      end }
      list << { label: 'Tous les messages', value: 'A', a: proc do
        ids.each { |id| friends.messages_of(id).each { |message| friends.send_message(id, message[:id]) } }
        @phone_changed = true
        next 'Messages reçus'
      end }
      ids.each do |id|
        affinity = lambda do |amount|
          friends.meet(id) unless friends.met?(id)
          friends.add_affinity(id, amount)
          @phone_changed = true
          nil
        end
        list << { label: friends.name(id).to_s, value: friends.met?(id) ? "#{friends.affinity(id)}/#{ps::FRIEND_MAX_AFFINITY}" : 'pas rencontré',
                  a: proc { affinity.call(ps::FRIEND_MAX_AFFINITY) }, left: proc { affinity.call(-10) }, right: proc { affinity.call(10) } }
      end
      return list
    end

    # --- Actions -------------------------------------------------------------------------------

    # @param pokemons [Array<PFM::Pokemon>]
    def debug_heal(pokemons)
      pokemons = pokemons.compact
      pokemons.each do |pokemon|
        pokemon.cure
        pokemon.hp = pokemon.max_hp
        pokemon.skills_set.compact.each { |skill| skill.pp = skill.ppmax }
      end
      return pokemons.size == 1 ? "#{pokemons.first.given_name} soigné" : 'Équipe soignée'
    end

    # Comme give_level de PSDK, sans les messages, l'apprentissage des capacités ni l'évolution
    # @param pokemons [Array<PFM::Pokemon>]
    # @param amount [Integer]
    def debug_level(pokemons, amount)
      pokemons.compact.each do |pokemon|
        next if pokemon.egg?

        amount.times do
          break if pokemon.level >= PFM.game_state.level_max_limit

          pokemon.level_up_stat_refresh
        end
        pokemon.hp = pokemon.max_hp
      end
      return "Niveau +#{amount}"
    end

    # @param db_symbol [Symbol]
    # @param shiny [Boolean]
    def debug_give_pokemon(db_symbol, shiny)
      pokemon = PFM::Pokemon.new(db_symbol, @give_level, shiny)
      return 'Plus de place' unless PFM.game_state.add_pokemon(pokemon)

      PFM.game_state.pokedex.mark_seen(db_symbol, forced: true)
      PFM.game_state.pokedex.mark_captured(db_symbol)
      return "#{pokemon.name} N.#{@give_level}#{shiny ? ' chromatique' : ''} reçu"
    end

    # @param amount [Integer] (négatif = retirer)
    def debug_money(amount)
      state = PFM.game_state
      if amount >= 0 && state.respond_to?(:add_money)
        state.add_money(amount)
      elsif amount < 0 && state.respond_to?(:lose_money)
        state.lose_money([-amount, state.money].min)
      else
        state.money = [state.money + amount, 0].max
      end
      return amount == UI::PokeSmart::DEBUG_MONEY ? "+#{amount}" : nil
    end

    # @return [Integer, nil] badges obtenus (région 1)
    def debug_badge_count
      return (1..UI::PokeSmart::DEBUG_BADGES).count { |i| $trainer.badge_obtained?(i, 1) }
    rescue StandardError
      return nil
    end

    # Garde les badges 1 à count, enlève les autres
    # @param count [Integer]
    def debug_badges(count)
      count = count.clamp(0, UI::PokeSmart::DEBUG_BADGES)
      (1..UI::PokeSmart::DEBUG_BADGES).each { |i| $trainer.set_badge(i, 1, i <= count) }
      return nil
    end

    def debug_dex
      dex = PFM.game_state.pokedex
      dex.enable
      each_data_creature do |creature|
        next if creature.db_symbol == :__undef__

        dex.mark_seen(creature.db_symbol, forced: true)
        dex.mark_captured(creature.db_symbol)
      end
      return 'Pokédex complet'
    end

    def debug_through
      $game_player.through = !$game_player.through
      return nil
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
      return nil
    end

    # @param delta [Integer]
    def debug_speed(delta)
      $game_player.instance_variable_set(:@move_speed, ($game_player.move_speed + delta).clamp(1, 6))
      return nil
    end

    # Téléportation : point de vol de la zone, sinon centre de sa première carte
    # @param zone [Studio::Zone]
    def debug_warp(zone)
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
      @warped = true
      @running = false
      return nil
    end

    # @param action [Symbol]
    # @return [String]
    def debug_app_name(action)
      ps = UI::PokeSmart
      names = ps::APP_NAMES[action]
      return ps.studio_app_name(action) || (names ? names[ps.french? ? 0 : 1] : action.to_s.sub(/\Aopen_/, ''))
    end
  end

  class Menu
    module SmartStyle
      public

      # Appli Debug : écran Debug en plein écran
      def open_debug
        call_scene(GamePlay::PokeSmartDebug) do |scene|
          if scene.warped
            @quiting = true
          elsif scene.phone_changed
            action = @buttons[@index]&.action
            init_indexes
            rebuild_phone
            @index = @buttons.index { |button| button.action == action } || 0
            update_buttons
          end
        end
      end
    end

    if UI::PokeSmart::ENABLED
      register_button(:open_debug) { UI::PokeSmart.debug_app? } unless ACTION_LIST.include?(:open_debug)
    end
  end
end

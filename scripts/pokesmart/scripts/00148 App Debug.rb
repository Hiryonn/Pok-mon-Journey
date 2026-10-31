# PokeSmart : appli Debug (seulement quand le jeu est lancé en mode debug, jamais dans la version finale)
#
# L'appli ouvre un écran Debug en plein écran (images dans graphics/interface/debug) avec des raccourcis de test,
# sans passer par des commandes d'évent :
#   Équipe        : soigner, niveaux
#   Pokémon       : recevoir n'importe quel Pokémon (recherche par n°, symbole ou nom, niveau réglable, X = chromatique)
#   Objets        : recevoir n'importe quel objet (recherche par n°, symbole ou nom, quantité réglable)
#   Joueur        : argent, badges, Pokédex complet, traverser les murs, rencontres sauvages, vitesse
#   Carte         : téléportation (n° de carte, X et Y à saisir, ou une zone de Studio)
#   Interrupteurs : allumer / éteindre
#   Variables     : modifier
#   Téléphone     : applis à débloquer, amis
# Touches : L / R = catégorie, haut / bas = ligne, gauche / droite = régler (sinon page), A = valider,
#           X = action secondaire (indiquée en bas), B = quitter. Souris : clic, molette, clic droit = quitter.
#         Saisie au clavier (recherche, nombres) : taper le texte, Entrée = valider, Échap = annuler.
module UI
  module PokeSmart
    # Affiche l'appli Debug (en mode debug seulement)
    DEBUG_APP = true
    # Niveau proposé pour les Pokémon donnés
    DEBUG_POKEMON_LEVEL = 50
    # Quantité proposée pour les objets donnés
    DEBUG_ITEM_COUNT = 10
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
      [:pokemon, 'Pokémon', 'A : recevoir / écrire   X : chromatique'],
      [:items, 'Objets', 'A : recevoir / écrire'],
      [:player, 'Joueur', 'A : valider / écrire   Gauche / droite : régler'],
      [:map, 'Carte', 'A : écrire / se téléporter   Gauche / droite : régler'],
      [:switches, 'Interrupteurs', 'A : allumer / éteindre'],
      [:variables, 'Variables', 'Gauche / droite : -1 / +1   A : écrire   X : 0'],
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
      @warp_target = nil
    end

    def update_inputs
      return false unless @entries
      return update_typing if @typing
      return false if wait_key_release

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
      return update_typing_mouse if @typing

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
      update_cursor_blink if @typing
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
      @input = @header.add_text(8, 220, 200, 16, '', 0, color: UI::PokeSmart::WHITE)
      @input.visible = false
      @selector = Sprite.new(@viewport).set_bitmap("#{DIR}selector", :interface)
      change_category(0, false)
    end

    # --- Saisie au clavier --------------------------------------------------------------------

    # Commence une saisie dans la bande du bas. Le texte est lu directement au clavier (les touches du jeu sont
    # ignorées pendant la saisie) : Entrée valide, Échap annule, Retour arrière efface, Ctrl+V colle.
    # @param prompt [String]
    # @param initial [Object] texte de départ
    # @param max [Integer] nombre de caractères
    # @param numeric [Boolean] seulement des chiffres (et le signe -)
    # @param on_change [Proc, nil] appelé à chaque lettre (recherche en direct)
    # @yieldparam text [String] texte validé (le résultat peut être un message)
    def start_typing(prompt, initial = '', max = 7, numeric: false, on_change: nil, &on_done)
      play_decision_se
      @typing = on_done
      @typing_change = on_change
      @typing_max = max
      @typing_numeric = numeric
      @typed = initial.to_s.dup
      @blink = 0
      @message_timer = 0
      @help.text = "#{prompt} :"
      width = @help.respond_to?(:real_width) ? @help.real_width : @help.text.size * 6
      @input.x = @help.x + width + 4
      @input.visible = true
      refresh_input_text
      Input.clear
      @keyboard_state = { Enter: keyboard_press?(:Enter), Escape: keyboard_press?(:Escape) }
      return nil
    end

    # @param key [Symbol] nom de la touche (Enter, Escape)
    # @return [Boolean] si la touche du clavier est enfoncée
    def keyboard_press?(key)
      keyboard = Input::Keyboard
      return keyboard.press?(keyboard.const_get(key))
    rescue StandardError, NameError
      return false
    end

    # @param key [Symbol]
    # @return [Boolean] si la touche vient d'être enfoncée
    def keyboard_trigger?(key)
      down = keyboard_press?(key)
      triggered = down && !@keyboard_state[key]
      @keyboard_state[key] = down
      return triggered
    end

    # Pendant la saisie : lettres tapées, Entrée, Échap, Retour arrière
    def update_typing
      enter = keyboard_trigger?(:Enter)
      escape = keyboard_trigger?(:Escape)
      text = Input.get_text
      return finish_typing if enter && !text
      return cancel_typing if escape && !text
      return false unless text

      Input.clear
      before = @typed.dup
      text.each_char do |char|
        case char
        when "\r", "\n" then return finish_typing
        when "\e" then return cancel_typing
        when "\b" then @typed.chop!
        when "\u0016" then (Yuki.get_clipboard.to_s rescue '').each_char { |c| add_typed_char(c) }
        else add_typed_char(char)
        end
      end
      return false if before == @typed

      refresh_input_text
      @typing_change&.call(@typed)
      return false
    end

    # Clic gauche : valider, clic droit : annuler
    def update_typing_mouse
      if Mouse.trigger?(:LEFT)
        finish_typing
      elsif Mouse.trigger?(:RIGHT)
        cancel_typing
      end
      return false
    end

    # @param char [String]
    def add_typed_char(char)
      return if char.ord < 32 || @typed.size >= @typing_max
      return if @typing_numeric && !(char.match?(/\d/) || (char == '-' && @typed.empty?))

      @typed << char
    end

    def refresh_input_text
      @input.text = "#{@typed}#{@blink < 20 ? '_' : ' '}"
    end

    def update_cursor_blink
      @blink = (@blink + 1) % 40
      refresh_input_text if @blink == 0 || @blink == 20
    end

    def finish_typing
      text = @typed.strip
      on_done = @typing
      stop_typing
      run(proc { on_done.call(text) }, true)
      return false
    end

    def cancel_typing
      play_cancel_se
      stop_typing
      draw_rows
      return false
    end

    def stop_typing
      @typing = nil
      @typing_change = nil
      @input.visible = false
      @wait_release = true
      show_help
    end

    # Après une saisie, attend que Entrée / Échap soient relâchées (sinon elles valideraient la ligne suivante)
    # @return [Boolean] si les touches sont ignorées
    def wait_key_release
      return false unless @wait_release
      return true if Input.press?(:A) || Input.press?(:B)

      @wait_release = false
      return false
    end

    # Ligne de saisie d'un nombre
    # @param label [String]
    # @param value [Integer] valeur actuelle
    # @param range [Range] valeurs permises
    # @param step [Integer] gauche / droite
    # @param set [Proc] reçoit la nouvelle valeur
    # @return [Hash]
    def number_entry(label, value, range, step = 1, display: value.to_s, &set)
      change = ->(new_value) { set.call(new_value.clamp(range.min, range.max)) && nil }
      return { label: label, value: display,
               left: proc { change.call(value - step) }, right: proc { change.call(value + step) },
               a: proc do
                 start_typing(label, value, [range.max.to_s.size, range.min.to_s.size].max, numeric: true) do |text|
                   next 'Nombre invalide' unless text.match?(/\A-?\d+\z/)

                   change.call(text.to_i)
                   next nil
                 end
               end }
    end

    # Cherche dans une liste [texte, valeur, n°, symbole] : n°, symbole exact, puis début / morceau du nom
    # @param list [Array<Array>]
    # @param text [String]
    # @return [Integer, nil] index dans la liste
    def find_in(list, text)
      return nil if text.empty?

      if text.match?(/\A\d+\z/)
        number = text.to_i
        return list.index { |entry_data| entry_data[2] == number }
      end
      key = debug_normalize(text)
      return list.index { |entry_data| entry_data[3].to_s == text.downcase } ||
             list.index { |entry_data| debug_normalize(entry_data[4]).start_with?(key) } ||
             list.index { |entry_data| debug_normalize(entry_data[4]).include?(key) } ||
             list.index { |entry_data| entry_data[3].to_s.include?(text.downcase) }
    end

    # @param text [String]
    # @return [String] minuscules sans accents
    def debug_normalize(text)
      return text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '').downcase
    rescue StandardError
      return text.to_s.downcase
    end

    # Sélectionne une ligne (après une recherche)
    # @param row [Integer]
    def select_row(row)
      @indexes[@category] = row
      @firsts[@category] = [row - 1, 0].max
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
        icon = (mx - ICON_X + (ICON_STEP - 22) / 2) / ICON_STEP
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
      @counter.text = @typing ? 'Entrée / Échap' : (@entries.empty? ? '' : "#{index + 1}/#{@entries.size}")
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
      @creatures ||= each_data_creature.reject { |creature| creature.db_symbol == :__undef__ }.map do |creature|
        [format('%03d %s', creature.id, creature.name), creature.db_symbol, creature.id, creature.db_symbol, creature.name.to_s]
      end
      list = [
        { label: 'Chercher', value: 'n°, symbole ou nom', a: proc do
          live = lambda do |text|
            found = find_in(@creatures, text)
            next unless found

            select_row(found + 2)
            draw_rows
          end
          start_typing('Pokémon', '', 16, on_change: live) do |text|
            found = find_in(@creatures, text)
            next "Introuvable : #{text}" unless found

            select_row(found + 2)
            next "#{@creatures[found][0]} : A pour recevoir"
          end
        end },
        number_entry('Niveau donné', @give_level, 1..PFM.game_state.level_max_limit) { |value| @give_level = value }
      ]
      @creatures.each do |label, db_symbol|
        list << { label: label, value: db_symbol.to_s, a: proc { debug_give_pokemon(db_symbol, false) }, x: proc { debug_give_pokemon(db_symbol, true) } }
      end
      return list
    end

    def entries_items
      @items ||= each_data_item.reject { |item| item.db_symbol == :__undef__ }
                               .map { |item| [item.name.to_s, item.db_symbol, item.id, item.db_symbol, item.name.to_s] }
                               .sort_by { |data| data[0].downcase }
      bag = PFM.game_state.bag
      list = [
        { label: 'Chercher', value: 'n°, symbole ou nom', a: proc do
          live = lambda do |text|
            found = find_in(@items, text)
            next unless found

            select_row(found + 2)
            draw_rows
          end
          start_typing('Objet', '', 16, on_change: live) do |text|
            found = find_in(@items, text)
            next "Introuvable : #{text}" unless found

            select_row(found + 2)
            next "#{@items[found][0]} : A pour recevoir"
          end
        end },
        number_entry('Quantité', @give_count, 1..999, display: "x#{@give_count}") { |value| @give_count = value }
      ]
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
        number_entry('Argent', state.money, 0..9_999_999, 1000) { |value| debug_set_money(value) },
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
      @warp_target ||= [$game_map.map_id, $game_player.x, $game_player.y]
      map_id, x, y = @warp_target
      width, height = debug_map_size(map_id)
      zone_name = debug_zone_of(map_id)
      list = [
        number_entry('Carte (n°)', map_id, 1..999, display: zone_name ? "#{map_id} #{zone_name}" : map_id.to_s) do |value|
          @warp_target = [value, x, y]
        end,
        number_entry('X', x, 0..[(width || 999) - 1, 0].max) { |value| @warp_target = [map_id, value, y] },
        number_entry('Y', y, 0..[(height || 999) - 1, 0].max) { |value| @warp_target = [map_id, x, value] },
        { label: 'Se téléporter', value: width ? "#{map_id} : #{x}, #{y}" : 'carte introuvable', a: proc { debug_warp_to(map_id, x, y) } },
        { label: 'Position actuelle', value: "#{$game_map.map_id} : #{$game_player.x}, #{$game_player.y}", a: proc do
          @warp_target = [$game_map.map_id, $game_player.x, $game_player.y]
          next nil
        end }
      ]
      each_data_zone.each do |zone|
        next unless zone.maps&.any?

        name = zone.name.to_s.empty? ? zone.db_symbol.to_s : zone.name.to_s
        list << { label: name, value: "Carte #{zone.maps.first}", a: proc do
          @warp_target = debug_zone_target(zone)
          select_row(3)
          next "#{name} : A pour s'y téléporter"
        end }
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
        number_entry(format('%03d %s', id, names[id]), $game_variables[id].to_i, -9_999_999..9_999_999) { |value| change.call(value) }
          .merge(x: proc { change.call(0) })
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

    # @param value [Integer] nouvelle somme
    def debug_set_money(value)
      state = PFM.game_state
      delta = value - state.money
      if delta >= 0 && state.respond_to?(:add_money)
        state.add_money(delta)
      elsif delta < 0 && state.respond_to?(:lose_money)
        state.lose_money(-delta)
      else
        state.money = value
      end
      return true
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

    # @param map_id [Integer]
    # @return [Array(Integer, Integer), nil] largeur et hauteur de la carte (nil si elle n'existe pas)
    def debug_map_size(map_id)
      @map_sizes ||= {}
      return @map_sizes[map_id] if @map_sizes.key?(map_id)

      map = load_data(format('Data/Map%03d.rxdata', map_id))
      return @map_sizes[map_id] = [map.width, map.height]
    rescue StandardError, ScriptError
      return @map_sizes[map_id] = nil
    end

    # @param map_id [Integer]
    # @return [String, nil] nom de la zone de Studio qui contient la carte
    def debug_zone_of(map_id)
      @zone_names ||= each_data_zone.each_with_object({}) do |zone, names|
        (zone.maps || []).each { |id| names[id] ||= zone.name.to_s }
      end
      return @zone_names[map_id]
    end

    # Point de vol de la zone, sinon centre de sa première carte
    # @param zone [Studio::Zone]
    # @return [Array(Integer, Integer, Integer)]
    def debug_zone_target(zone)
      map_id = zone.maps.first
      return [map_id, zone.warp.x, zone.warp.y] if zone.warp&.x && zone.warp&.y

      width, height = debug_map_size(map_id) || [2, 2]
      return [map_id, width / 2, height / 2]
    end

    # @param map_id [Integer]
    # @param x [Integer]
    # @param y [Integer]
    def debug_warp_to(map_id, x, y)
      width, height = debug_map_size(map_id)
      return 'Carte introuvable' unless width

      x = x.clamp(0, width - 1)
      y = y.clamp(0, height - 1)

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

      # Appli Debug : écran Debug en plein écran. Lancé directement (sans les animations de sortie / retour du menu,
      # qui laissaient le téléphone caché), puis le téléphone revient tel quel.
      def open_debug
        Graphics.freeze
        @viewport.visible = false
        scene = GamePlay::PokeSmartDebug.new
        scene.main
        @viewport.visible = true
        if scene.warped
          @quiting = true
        elsif scene.phone_changed
          action = @buttons[@index]&.action
          init_indexes
          rebuild_phone
          @index = @buttons.index { |button| button.action == action } || 0
          update_buttons
        end
        Graphics.transition(8)
      end
    end

    if UI::PokeSmart::ENABLED
      register_button(:open_debug) { UI::PokeSmart.debug_app? } unless ACTION_LIST.include?(:open_debug)
    end
  end
end

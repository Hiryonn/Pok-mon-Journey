# Poké Récré : l'écran de jeu (aux couleurs de l'interface Horizon)
#
# Le Pokémon est au milieu, sur un décor choisi selon l'endroit. La main suit la souris (ou les flèches) :
#   - caresser : garder A (ou le clic) appuyé sur le Pokémon en bougeant la main → cœurs, affection et bonne humeur
#   - nourrir  : X (ou le bol en bas à gauche) ouvre le plateau des friandises du sac ; A en prend une, puis garder
#                A sur le Pokémon : il la mange en trois bouchées → affection et satiété
#   - changer  : Y (ou le bouton en bas à droite) pour jouer avec un autre Pokémon de l'équipe
#   - décor    : L (ou le bouton coussin) : fond et décorations à gauche et à droite
#   - jeux     : R (ou le bouton pelote) : Cueille-Baies et Jongle-Tête (00104 Mini-jeux.rb)
#   - B        : lâche la friandise, ferme le plateau, ou quitte
# Un Pokémon brûlé, gelé, empoisonné ou paralysé : la main le montre ; assez de caresses le guérissent (cure_pets).
module GamePlay
  class PokeRecre < BaseCleanUpdate::FrameBalanced
    P = ::PokeRecre
    WHITE = 9
    DARK = 0
    SMALL = 20
    # Cadre des jauges (nom puis affection, satiété, bonne humeur)
    STATS_X = 4
    STATS_Y = 30
    ICON_STEP = 17
    # Pokémon : bas du sprite et agrandissement
    POKEMON_X = 168
    POKEMON_Y = 204
    POKEMON_ZOOM = 2
    # Boutons
    FEED_X = 6
    FEED_Y = 174
    SWITCH_X = 284
    SWITCH_Y = 178
    BACK_X = 284
    BACK_Y = 32
    DECO_BUTTON_Y = 66
    GAMES_BUTTON_Y = 100
    # Décorations : bas des images à gauche et à droite du Pokémon, hauteur maximale
    DECO_LEFT_X = 74
    DECO_RIGHT_X = 262
    DECO_Y = 210
    DECO_MAX = 90
    # Statuts : image de la main quand on caresse [bande, taille, images]
    STATUS_HANDS = { burn: ['brulure', 64, 4], frozen: ['gel', 32, 4], poison: ['poison', 32, 3], paralysis: ['choc', 64, 4] }.freeze
    # Plateau des friandises
    TRAY_X = 4
    TRAY_Y = 172
    TRAY_ITEM_X = 48
    TRAY_STEP = 38
    TRAY_VISIBLE = 7
    # Choix du Pokémon
    PARTY_X = 10
    PARTY_Y = 44
    SLOT_X = 22
    SLOT_Y = 72
    SLOT_STEP = 46
    # Main : vitesse aux flèches ; bouchées : images entre deux bouchées
    HAND_SPEED = 4
    BITE_FRAMES = 24
    HEART_FRAMES = 36

    # @return [PFM::Pokemon] Pokémon avec qui on a joué en dernier
    attr_reader :pokemon

    # @param pokemon [PFM::Pokemon, nil] Pokémon de départ (nil : le premier de l'équipe)
    def initialize(pokemon = nil)
      super()
      @pokemon = pokemon && !pokemon.egg? ? pokemon : P.party.first
      @mode = :play
      @hand_x = 160.0 + ox
      @hand_y = 120.0
      @pet_distance = 0.0
      @pet_sound = 0
      @bites = 0
      @bite_timer = 0
      @food = nil
      @tray_index = 0
      @tray_offset = 0
      @party_index = 0
      @hearts = []
      @effects = []
      @notice = 0
      @anim = 0
      @status_pets = 0
      @menu_index = 0
      @pokemon&.amie_change(:visit)
    end

    def update_inputs
      unless @pokemon
        quit if Input.trigger?(:B) || Input.trigger?(:A)
        return false
      end

      update_hand
      case @mode
      when :play then update_play
      when :tray then update_tray
      when :feeding then update_feeding
      when :switch then update_switch
      when :decor then update_decor
      when :games then update_games
      end
      return false
    end

    def update_graphics
      @pokemon_sprite&.update
      update_hearts
      update_effects
      @anim += 1
      if @notice > 0 && (@notice -= 1) == 0
        refresh_help
      end
      return true
    end

    private

    # @return [Integer] x du bord gauche de l'écran
    def left
      return defined?(::Ecran) && ::Ecran.grand? ? ::Ecran.logique_gauche : 0
    end

    # @return [Integer] largeur de l'écran
    def full_width
      return defined?(::Ecran) && ::Ecran.grand? ? ::Ecran.logique_largeur : 320
    end

    # @return [Integer] décalage des éléments ancrés à gauche
    def lx
      return left
    end

    # @return [Integer] décalage des éléments ancrés à droite
    def rx
      return left + full_width - 320
    end

    # @return [Integer] décalage des éléments centrés
    def ox
      return left + (full_width - 320) / 2
    end

    # @return [Array<Integer>] position de la souris dans les coordonnées de la scène
    def mouse_xy
      return defined?(::Ecran) ? ::Ecran.souris(@viewport) : [Mouse.x, Mouse.y]
    end

    # --- Main --------------------------------------------------------------------------------------
    def update_hand
      old_x = @hand_x
      old_y = @hand_y
      if Mouse.moved
        @hand_x, @hand_y = mouse_xy.map(&:to_f)
      elsif @mode != :tray && @mode != :switch
        @hand_x -= HAND_SPEED if Input.press?(:LEFT)
        @hand_x += HAND_SPEED if Input.press?(:RIGHT)
        @hand_y -= HAND_SPEED if Input.press?(:UP)
        @hand_y += HAND_SPEED if Input.press?(:DOWN)
      end
      @hand_x = @hand_x.clamp(left, left + full_width - 1)
      @hand_y = @hand_y.clamp(0, 239)
      @hand_moved = Math.hypot(@hand_x - old_x, @hand_y - old_y)
      @hand.set_position(@hand_x.round, @hand_y.round)
      @glow&.set_position(@hand_x.round, @hand_y.round)
      @held.set_position(@hand_x.round, @hand_y.round) if @held
    end

    def holding?
      return Input.press?(:A) || Mouse.press?(:left)
    end

    def clicked?(sprite)
      return Mouse.trigger?(:left) && sprite.visible && sprite.mouse_in?
    end

    def on_pokemon?
      return false unless @pokemon_sprite&.bitmap

      return @pokemon_sprite.mouse_in?(@hand_x, @hand_y)
    end

    # --- Jeu ---------------------------------------------------------------------------------------
    def update_play
      return quit if Input.trigger?(:B) || clicked?(@back_button)
      return open_tray if Input.trigger?(:X) || clicked?(@feed_button)
      return open_switch if Input.trigger?(:Y) || clicked?(@switch_button)
      return open_decor if Input.trigger?(:L) || clicked?(@decor_button)
      return open_games if Input.trigger?(:R) || clicked?(@games_button)

      petting = holding? && on_pokemon?
      show_hand(petting)
      return unless petting && @hand_moved > 0

      @pet_distance += @hand_moved
      if (@pet_sound -= 1) <= 0
        Audio.se_play('audio/se/poke_recre_pet', 90)
        @pet_sound = 24
      end
      return if @pet_distance < [P.setting('pet_distance').to_f, 50].max

      @pet_distance = 0
      @pokemon.amie_change(:pet)
      return if pet_status

      happy
    end

    # --- Main ------------------------------------------------------------------------------------------
    def xy_hand?
      return P.setting('hand_style').to_s != 'classic'
    end

    # Statut qui se voit sur la main (nil : aucun)
    def hand_status
      return nil unless @pokemon
      return :burn if @pokemon.burn?
      return :frozen if @pokemon.frozen?
      return :poison if @pokemon.poisoned? || (@pokemon.respond_to?(:toxic?) && @pokemon.toxic?)
      return :paralysis if @pokemon.paralyzed?

      return nil
    rescue StandardError
      return nil
    end

    def show_hand(petting)
      return @hand.set_bitmap(P.file(petting ? 'hand_press' : 'hand'), :interface) unless xy_hand?

      status = petting && hand_status
      if status
        name, size, count = STATUS_HANDS[status]
        return set_hand(name, size, (@anim / 8) % count)
      end
      return set_hand('caresse', 32, (@anim / 6) % 4) if petting
      return set_hand('pointe', 32, 0) if on_pokemon?

      set_hand('repos', 32, holding? ? 1 : 0)
    end

    def set_hand(name, size, frame)
      key = [name, frame]
      return if @hand_key == key

      @hand_key = key
      @hand.set_bitmap(P.file("main/#{name}"), :interface)
      @hand.src_rect.set(frame * size, 0, size, size)
      @hand.set_origin(size / 2, size / 2)
    end

    # Une caresse à un Pokémon qui a un statut : guérison après assez de caresses
    # @return [Boolean] true si la caresse a été prise par le statut
    def pet_status
      return false unless hand_status

      needed = P.setting('cure_pets').to_i
      return false if needed <= 0

      @status_pets += 1
      spawn_hearts
      refresh_stats
      if @status_pets < needed
        notify(P.t("#{@pokemon.given_name} se sent un peu mieux…", "#{@pokemon.given_name} feels a little better…"))
        return true
      end

      @status_pets = 0
      @pokemon.cure
      spawn_anim((ox + POKEMON_X), POKEMON_Y - 60, 'eclat', 32, 5, 6, 2)
      spawn_anim(@hand_x, @hand_y, 'soin', 64, 1, 40)
      Audio.se_play('audio/se/poke_recre_pet', 100, 130)
      notify(P.t("#{@pokemon.given_name} est guéri !", "#{@pokemon.given_name} is cured!"))
      @hand_key = nil
      return true
    end

    # Le Pokémon est content : cri et cœurs
    def happy
      cry = @pokemon.cry
      Audio.se_play(cry, 90, 110) unless cry.to_s.empty?
      spawn_hearts
      refresh_stats
    rescue StandardError
      spawn_hearts
      refresh_stats
    end

    def quit
      play_cancel_se
      @running = false
    end

    # --- Plateau des friandises --------------------------------------------------------------------
    def open_tray
      @foods = P.owned_puffs.map { |id| "puff:#{id}" } + P.bag_foods
      if @foods.empty?
        play_buzzer_se
        return notify(P.t("Tu n'as rien à lui donner à manger.", 'You have nothing to feed it.'))
      end

      play_decision_se
      @mode = :tray
      @tray_index = @tray_index.clamp(0, @foods.size - 1)
      refresh_tray
      refresh_help
    end

    def close_tray(mode = :play)
      @mode = mode
      @tray.each { |sprite| sprite.visible = false }
      @tray_items.each { |icon, count| icon.visible = count.visible = false }
      @tray_cursor.visible = false
      refresh_help
    end

    def update_tray
      if Input.trigger?(:B) || clicked?(@feed_button)
        play_cancel_se
        return close_tray
      end

      if Input.repeat?(:RIGHT) && @tray_index < @foods.size - 1
        @tray_index += 1
        play_cursor_se
        refresh_tray
      elsif Input.repeat?(:LEFT) && @tray_index > 0
        @tray_index -= 1
        play_cursor_se
        refresh_tray
      end
      clicked = @tray_items.index { |icon, _| icon.visible && Mouse.trigger?(:left) && icon.mouse_in? }
      if clicked
        @tray_index = @tray_offset + clicked
        return take_food
      end
      take_food if Input.trigger?(:A)
    end

    def take_food
      if @pokemon.fullness_level >= 5
        play_buzzer_se
        return notify(P.t("#{@pokemon.given_name} n'a plus faim !", "#{@pokemon.given_name} is full!"))
      end

      @food = @foods[@tray_index]
      @bites = 0
      @bite_timer = 0
      play_decision_se
      show_food_icon(@held, @food, 1)
      @held.set_origin(@held_rect[2] / 2, @held_rect[3] / 2)
      @held.visible = true
      @hand.visible = false
      close_tray(:feeding)
    end

    def item_icon(item)
      return data_item(item).icon
    rescue StandardError
      return '000'
    end

    # @return [String, nil] id de la Pofiterole (entrée « puff:id » du plateau)
    def puff_id(food)
      return food.is_a?(String) && food.start_with?('puff:') ? food.sub('puff:', '') : nil
    end

    # Image d'une friandise (objet du sac ou Pofiterole) ; zoom 0,5 pour les Pofiteroles sur le plateau
    def show_food_icon(sprite, food, puff_zoom = 0.5)
      id = puff_id(food)
      if id
        entry = P.puff(id)
        sprite.set_bitmap(P.file('pofiteroles'), :interface)
        size = P::PUFF_SIZE
        sprite.src_rect.set(entry[:col] * size, entry[:row] * size, size, size)
        sprite.zoom = puff_zoom
        @held_rect = [entry[:col] * size, entry[:row] * size, size, size] if sprite == @held
      else
        sprite.set_bitmap(item_icon(food), :icon)
        sprite.src_rect.set(0, 0, sprite.bitmap.width, sprite.bitmap.height)
        sprite.zoom = 1
        @held_rect = [0, 0, sprite.bitmap.width, sprite.bitmap.height] if sprite == @held
      end
    end

    def food_count(food)
      id = puff_id(food)
      return id ? P.puff_count(id) : $bag.item_quantity(food)
    end

    def refresh_tray
      @tray.each { |sprite| sprite.visible = true }
      @tray_offset = @tray_index - TRAY_VISIBLE + 1 if @tray_index >= @tray_offset + TRAY_VISIBLE
      @tray_offset = @tray_index if @tray_index < @tray_offset
      @tray_items.each_with_index do |(icon, count), i|
        item = @foods[@tray_offset + i]
        icon.visible = count.visible = !item.nil?
        next unless item

        show_food_icon(icon, item)
        count.text = "×#{food_count(item)}"
      end
      @tray_cursor.visible = true
      @tray_cursor.x = (ox + TRAY_ITEM_X) + (@tray_index - @tray_offset) * TRAY_STEP - 2
      @info.text = item_name(@foods[@tray_index])
    end

    def item_name(item)
      return P.puff_name(puff_id(item)) if puff_id(item)

      return data_item(item).name.to_s
    rescue StandardError
      return item.to_s
    end

    # --- Repas -------------------------------------------------------------------------------------
    def update_feeding
      return drop_food if Input.trigger?(:B)

      unless holding? && on_pokemon?
        @bite_timer = 0
        return
      end

      @bite_timer += 1
      return if @bite_timer < BITE_FRAMES

      @bite_timer = 0
      bite
    end

    def bite
      @bites += 1
      Audio.se_play('audio/se/poke_recre_eat', 90)
      spawn_crumbs
      x, y, width, height = @held_rect
      if @bites < 3
        @held.src_rect.set(x, y, (width * (3 - @bites) / 3.0).round, height)
        return
      end

      id = puff_id(@food)
      if id
        P.add_puff(id, -1)
        @pokemon.amie_feed_puff(id)
      else
        $bag.remove_item(@food, 1)
        @pokemon.amie_feed(@food)
      end
      drop_food(false)
      happy
    end

    def drop_food(sound = true)
      play_cancel_se if sound
      @food = nil
      @held.visible = false
      @hand.visible = true
      @mode = :play
      refresh_help
    end

    # --- Changer de Pokémon ------------------------------------------------------------------------
    def open_switch
      if P.party.size < 2
        play_buzzer_se
        return notify(P.t("Personne d'autre ne peut jouer.", 'No one else can play.'))
      end

      play_decision_se
      @mode = :switch
      @party_index = ($actors.index(@pokemon) || 0)
      @hand.visible = false
      refresh_switch
      refresh_help
    end

    def close_switch
      @mode = :play
      @switch_sprites.each { |sprite| sprite.visible = false }
      @slots.each { |slot, active, icon| slot.visible = active.visible = icon.visible = false }
      @switch_stats.each { |row| row.each { |sprite| sprite.visible = false } }
      @hand&.visible = true
      refresh_help
    end

    def update_switch
      if Input.trigger?(:B)
        play_cancel_se
        return close_switch
      end

      party = $actors.compact
      if Input.repeat?(:RIGHT) && @party_index < party.size - 1
        @party_index += 1
        play_cursor_se
        refresh_switch
      elsif Input.repeat?(:LEFT) && @party_index > 0
        @party_index -= 1
        play_cursor_se
        refresh_switch
      end
      clicked = @slots.index { |slot, _, _| slot.visible && Mouse.trigger?(:left) && slot.mouse_in? }
      if clicked && clicked < party.size
        @party_index = clicked
        refresh_switch
        return choose_pokemon
      end
      choose_pokemon if Input.trigger?(:A)
    end

    def choose_pokemon
      chosen = $actors.compact[@party_index]
      return play_buzzer_se if chosen.nil? || chosen.egg?

      play_decision_se
      if chosen != @pokemon
        @pokemon = chosen
        @pokemon.amie_change(:visit)
        @pokemon_sprite.data = @pokemon
        @pokemon_sprite.zoom = POKEMON_ZOOM
        @status_pets = 0
      end
      close_switch
      refresh_stats
    end

    def refresh_switch
      party = $actors.compact
      @switch_sprites.each { |sprite| sprite.visible = true }
      @slots.each_with_index do |(slot, active, icon), i|
        member = party[i]
        slot.visible = !member.nil?
        active.visible = i == @party_index
        icon.visible = !member.nil?
        icon.data = member if member
      end
      selected = party[@party_index]
      @switch_name.text = selected ? selected.given_name.to_s : ''
      levels = selected && !selected.egg? ? [selected.affection_level, selected.fullness_level, selected.enjoyment_level] : [0, 0, 0]
      @switch_stats.each_with_index do |row, r|
        row.each_with_index do |sprite, i|
          sprite.visible = true
          sprite.set_bitmap(P.file(gauge_file(r, i < levels[r])), :interface)
        end
      end
    end

    # --- Cœurs et miettes --------------------------------------------------------------------------
    def spawn_hearts
      base_x = (ox + POKEMON_X)
      base_y = POKEMON_Y - 70
      4.times do
        sprite = @base.add_sprite(base_x + rand(-40..40), base_y + rand(-30..20), P.file('heart'))
        sprite.set_origin(sprite.width / 2, sprite.height / 2)
        sprite.z = 30
        @hearts << [sprite, 0, rand(-10..10) / 10.0, -(rand(10..20) / 10.0)]
      end
    end

    def spawn_crumbs
      sprite = @base.add_sprite(@hand_x.round, @hand_y.round + 6, P.file('crumbs'))
      sprite.set_origin(sprite.width / 2, 0)
      sprite.z = 97
      @hearts << [sprite, 0, 0, 1.5]
    end

    def update_hearts
      @hearts.reject! do |entry|
        sprite, age, dx, dy = entry
        entry[1] = age + 1
        sprite.x += dx
        sprite.y += dy
        sprite.opacity = 255 - 255 * age / HEART_FRAMES
        next false if age < HEART_FRAMES

        sprite.dispose
        true
      end
    end

    # Animation d'une bande d'images (main/<nom>) : se joue puis disparaît
    def spawn_anim(x, y, name, size, count, frame_time, loops = 1)
      sprite = @base.add_sprite(x.round, y.round, P.file("main/#{name}"))
      sprite.src_rect.set(0, 0, size, size)
      sprite.set_origin(size / 2, size / 2)
      sprite.z = 96
      @effects << { sprite: sprite, size: size, count: count, time: frame_time, life: count * frame_time * loops, age: 0 }
    end

    def update_effects
      @effects.reject! do |fx|
        fx[:age] += 1
        frame = (fx[:age] / fx[:time]) % fx[:count]
        fx[:sprite].src_rect.x = frame * fx[:size]
        fx[:sprite].opacity = 255 - [fx[:age] - fx[:life] + 12, 0].max * 20
        next false if fx[:age] < fx[:life]

        fx[:sprite].dispose
        true
      end
    end

    def notify(text)
      @info.text = text
      @notice = 90
    end

    # --- Graphismes --------------------------------------------------------------------------------
    def create_graphics
      super
      @base = UI::SpriteStack.new(@viewport, default_cache: :interface)
      @backdrop = @base.add_sprite(left, 0, nil)
      @backdrop.zoom_x = full_width / 320.0
      refresh_backdrop
      @deco_sprites = [(ox + DECO_LEFT_X), (ox + DECO_RIGHT_X)].map { |x| @base.add_sprite(x, DECO_Y, nil) }
      refresh_decorations
      create_pokemon
      header = picture('horizon/header', 0, 0)
      add_disposable(*::Ecran.elargir_plaque(header, 80, 240)) if header && defined?(::Ecran) && ::Ecran.cadre?(@viewport)
      footer = picture('horizon/tcard/button_background', left, 214)
      footer.zoom_x = full_width / 320.0 if footer
      @base.add_text(ox + 80, 5, 160, 16, P.t('POKÉ RÉCRÉ', 'POKÉMON-AMIE'), 1, color: WHITE)
      create_stats
      @feed_button = @base.add_sprite((lx + FEED_X), FEED_Y, P.file('feed'))
      @switch_button = @base.add_sprite((rx + SWITCH_X), SWITCH_Y, P.file('switch'))
      @back_button = @base.add_sprite((rx + BACK_X), BACK_Y, P.file('back'))
      @decor_button = @base.add_sprite((rx + BACK_X), DECO_BUTTON_Y, P.file('bouton_deco'))
      @games_button = @base.add_sprite((rx + BACK_X), GAMES_BUTTON_Y, P.file('bouton_jeux'))
      create_tray
      create_switch
      create_menu
      @base.with_font(SMALL) { @info = @base.add_text(left + 8, 220, full_width - 16, 13, '', 1, color: WHITE) }
      @held = @base.add_sprite(0, 0, nil)
      @held.visible = false
      @held.z = 98
      @hand = @base.add_sprite(0, 0, P.file('hand'))
      @hand.set_origin(@hand.width / 2, @hand.height / 2)
      @hand.z = 99
      show_hand(false)
      @feed_button.z = 45
      refresh_stats
      refresh_help
      return unless @pokemon.nil?

      @info.text = P.t("Aucun Pokémon ne peut jouer.", 'No Pokémon can play.')
    end

    def picture(name, x, y)
      return @base.add_sprite(x, y, name) if RPG::Cache.interface_exist?(name)

      return nil
    end

    def create_pokemon
      @pokemon_sprite = UI::PokemonFaceSprite.new(@viewport)
      @pokemon_sprite.data = @pokemon if @pokemon
      @pokemon_sprite.zoom = POKEMON_ZOOM
      @pokemon_sprite.set_position((ox + POKEMON_X), POKEMON_Y)
    rescue StandardError => e
      log_error("Poké Récré : sprite du Pokémon (#{e.message})") if respond_to?(:log_error, true)
    end

    # Image d'une jauge : 0 affection, 1 satiété, 2 bonne humeur
    def gauge_file(row, on)
      name = %w[affection satiete bonne_humeur][row]
      return on ? name : "#{name}_off"
    end

    def create_stats
      @base.add_sprite((lx + STATS_X), STATS_Y, P.file('stats'))
      @base.with_font(SMALL) { @name_text = @base.add_text((lx + STATS_X) + 7, STATS_Y + 5, 92, 13, '', color: DARK) }
      @gauges = Array.new(3) do |r|
        Array.new(5) { |i| @base.add_sprite((lx + STATS_X) + 9 + i * ICON_STEP, STATS_Y + 20 + r * 15, P.file(gauge_file(r, false))) }
      end
    end

    def refresh_stats
      return unless @pokemon

      @name_text.text = @pokemon.given_name.to_s
      levels = [@pokemon.affection_level, @pokemon.fullness_level, @pokemon.enjoyment_level]
      @gauges.each_with_index do |row, r|
        row.each_with_index { |sprite, i| sprite.set_bitmap(P.file(gauge_file(r, i < levels[r])), :interface) }
      end
    end

    def create_tray
      @tray = [@base.add_sprite((ox + TRAY_X), TRAY_Y, P.file('tray'))]
      @tray[0].z = 40
      @tray_cursor = @base.add_sprite((ox + TRAY_ITEM_X) - 2, TRAY_Y + 3, P.file('slot_active'))
      @tray_cursor.zoom_y = 34 / 36.0
      @tray_cursor.z = 41
      @tray_items = Array.new(TRAY_VISIBLE) do |i|
        icon = @base.add_sprite((ox + TRAY_ITEM_X) + i * TRAY_STEP + 2, TRAY_Y + 3, nil)
        count = nil
        @base.with_font(SMALL) { count = @base.add_text((ox + TRAY_ITEM_X) + i * TRAY_STEP, TRAY_Y + 25, 36, 13, '', 2, color: DARK) }
        icon.z = 42
        count.z = 42
        [icon, count]
      end
      close_tray
    end

    def create_switch
      @switch_sprites = [@base.add_sprite((ox + PARTY_X), PARTY_Y, P.file('party'))]
      @base.with_font(SMALL) do
        @switch_sprites << @base.add_text((ox + PARTY_X) + 10, PARTY_Y + 9, 280, 13, P.t('Avec qui veux-tu jouer ?', 'Who do you want to play with?'), 1, color: DARK)
      end
      @slots = Array.new(6) do |i|
        x = (ox + SLOT_X) + i * SLOT_STEP
        slot = @base.add_sprite(x, SLOT_Y, P.file('slot'))
        active = @base.add_sprite(x, SLOT_Y, P.file('slot_active'))
        icon = UI::PokemonIconSprite.new(@viewport, false)
        icon.set_position(x + 4, SLOT_Y + 2)
        [slot, active, icon]
      end
      @switch_name = @base.add_text((ox + PARTY_X) + 20, PARTY_Y + 74, 120, 16, '', color: DARK)
      @switch_sprites << @switch_name
      @switch_stats = Array.new(3) do |r|
        Array.new(5) { |i| @base.add_sprite((ox + PARTY_X) + 150 + i * ICON_STEP, PARTY_Y + 76 + r * 18, P.file(gauge_file(r, false))) }
      end
      # Le cadre passe devant tout (sauf la main)
      @switch_sprites.each { |sprite| sprite.z = 50 }
      @slots.each { |slot, active, icon| slot.z = 51; active.z = 52; icon.z = 53 }
      @switch_stats.flatten.each { |sprite| sprite.z = 53 }
      @switch_sprites[1..].each { |text| text.z = 53 }
      @mode = :switch
      close_switch
    end

    def refresh_help
      return unless @info

      @info.text = case @mode
                   when :tray then @foods && @foods[@tray_index] ? item_name(@foods[@tray_index]) : ''
                   when :feeding then P.t('Garde A sur le Pokémon pour le nourrir   B : Reposer', 'Hold A on the Pokémon to feed it   B: Put back')
                   when :switch, :games then P.t('A : Choisir   B : Retour', 'A: Choose   B: Back')
                   when :decor then P.t('Haut / Bas : Choisir   Gauche / Droite : Changer   B : Retour',
                                        'Up / Down: Select   Left / Right: Change   B: Back')
                   else P.t('A Caresser  X Nourrir  Y Changer  L Décor  R Jeux  B Quitter',
                            'A Pet  X Feed  Y Switch  L Decor  R Games  B Quit')
                   end
    end
  end
end

# Poké Récré : menus Décor (fond, décorations) et Jeux (mini-jeux et récompenses)
module GamePlay
  class PokeRecre
    MENU_ROW_Y = 80
    MENU_ROW_STEP = 34
    GAMES = [
      ['cueille', 'Cueille-Baies', 'Berry Picker', 'PokeRecreBerryPicker'],
      ['jongle', 'Jongle-Tête', 'Head It', 'PokeRecreHeadIt']
    ].freeze

    private

    def create_menu
      panel = @base.add_sprite((ox + PARTY_X), PARTY_Y, P.file('party'))
      title = @base.add_text((ox + PARTY_X) + 10, PARTY_Y + 7, 280, 16, '', 1, color: DARK)
      @menu_title = title
      @menu_sprites = [panel, title]
      @menu_cursor = @base.add_sprite((ox + PARTY_X) + 14, 0, P.file('heart'))
      @menu_rows = Array.new(3) do |i|
        y = MENU_ROW_Y + i * MENU_ROW_STEP
        label = value = nil
        @base.with_font(SMALL) do
          label = @base.add_text((ox + PARTY_X) + 36, y, 70, 16, '', color: DARK)
          value = @base.add_text((ox + PARTY_X) + 96, y, 170, 16, '', 1, color: DARK)
        end
        icon = @base.add_sprite((ox + PARTY_X) + 282, y + 22, nil)
        [label, value, icon]
      end
      panel.z = 50
      ([title, @menu_cursor] + @menu_rows.flatten).each { |sprite| sprite.z = 53 }
      hide_menu
    end

    def hide_menu
      (@menu_sprites + [@menu_cursor] + @menu_rows.flatten).each { |sprite| sprite.visible = false }
    end

    def open_menu(mode)
      play_decision_se
      @mode = mode
      @menu_index = 0
      @hand.visible = false
      refresh_menu
      refresh_help
    end

    def close_menu
      hide_menu
      @mode = :play
      @hand.visible = true
      refresh_help
    end

    def menu_rows_count
      return @mode == :games ? GAMES.size : 3
    end

    # Ligne cliquée à la souris (nil : aucune)
    def clicked_row
      return nil unless Mouse.trigger?(:left)

      mx, my = mouse_xy
      return (0...menu_rows_count).find do |i|
        y = MENU_ROW_Y + i * MENU_ROW_STEP
        mx.between?((ox + PARTY_X) + 10, (ox + PARTY_X) + 290) && my.between?(y - 4, y + 22)
      end
    end

    def menu_move
      if Input.repeat?(:DOWN) && @menu_index < menu_rows_count - 1
        @menu_index += 1
        play_cursor_se
        refresh_menu
      elsif Input.repeat?(:UP) && @menu_index > 0
        @menu_index -= 1
        play_cursor_se
        refresh_menu
      end
    end

    def refresh_menu
      (@menu_sprites + [@menu_cursor]).each { |sprite| sprite.visible = true }
      @menu_cursor.set_position((ox + PARTY_X) + 18, MENU_ROW_Y + @menu_index * MENU_ROW_STEP)
      @mode == :games ? refresh_games_menu : refresh_decor_menu
    end

    # --- Décor -----------------------------------------------------------------------------------------
    def open_decor
      open_menu(:decor)
    end

    def update_decor
      if Input.trigger?(:B) || Input.trigger?(:A) || clicked?(@decor_button)
        play_cancel_se
        return close_menu
      end

      menu_move
      row = clicked_row
      if row
        @menu_index = row
        return change_decor(1)
      end
      change_decor(1) if Input.repeat?(:RIGHT)
      change_decor(-1) if Input.repeat?(:LEFT)
    end

    def change_decor(step)
      play_cursor_se
      data = P.data
      if @menu_index == 0
        choices = P.backdrop_choices
        data['backdrop'] = choices[((choices.index(data['backdrop'].to_s) || 0) + step) % choices.size]
        refresh_backdrop
      else
        side = @menu_index == 1 ? 'left' : 'right'
        choices = [nil] + P.owned_decorations
        data[side] = choices[((choices.index(data[side]) || 0) + step) % choices.size]
        refresh_decorations
      end
      refresh_menu
    end

    def refresh_decor_menu
      data = P.data
      @menu_title.text = P.t('Décor', 'Decor')
      labels = [P.t('Fond', 'Backdrop'), P.t('À gauche', 'Left'), P.t('À droite', 'Right')]
      values = [P.backdrop_name(data['backdrop']), P.decoration_name(data['left']), P.decoration_name(data['right'])]
      @menu_rows.each_with_index do |(label, value, icon), i|
        label.visible = value.visible = true
        label.text = labels[i]
        value.text = "< #{values[i]} >"
        id = i == 0 ? nil : data[i == 1 ? 'left' : 'right']
        show_deco(icon, id, 28)
      end
    end

    def refresh_backdrop
      name = P.backdrop_file
      name = P.file('bg_field') unless RPG::Cache.interface_exist?(name)
      @backdrop.set_bitmap(name, :interface)
    end

    def refresh_decorations
      data = P.data
      @deco_sprites.zip(%w[left right]).each { |sprite, side| show_deco(sprite, data[side], DECO_MAX) }
    end

    # Image d'une décoration (bas au milieu), réduite si elle dépasse max
    def show_deco(sprite, id, max)
      file = id && P.decoration_file(id)
      sprite.visible = file && P.decoration(id) && RPG::Cache.interface_exist?(file) ? true : false
      return unless sprite.visible

      sprite.set_bitmap(file, :interface)
      sprite.zoom = [1.0, max.to_f / [sprite.bitmap.width, sprite.bitmap.height].max].min
      sprite.set_origin(sprite.bitmap.width / 2, sprite.bitmap.height)
    end

    # --- Jeux ------------------------------------------------------------------------------------------
    def open_games
      open_menu(:games)
    end

    def update_games
      if Input.trigger?(:B) || clicked?(@games_button)
        play_cancel_se
        return close_menu
      end

      menu_move
      row = clicked_row
      if row
        @menu_index = row
        refresh_menu
        return play_game
      end
      play_game if Input.trigger?(:A)
    end

    def refresh_games_menu
      @menu_title.text = P.t('Mini-jeux', 'Mini-games')
      @menu_rows.each_with_index do |(label, value, icon), i|
        game = GAMES[i]
        label.visible = value.visible = !game.nil?
        icon.visible = false
        next unless game

        label.text = P.t(game[1], game[2])
        value.text = P.t("Record : #{P.data['records'][game[0]].to_i}", "Record: #{P.data['records'][game[0]].to_i}")
      end
    end

    def play_game
      game = GAMES[@menu_index]
      play_decision_se
      result = nil
      call_scene(GamePlay.const_get(game[3]), @pokemon) { |scene| result = scene.result }
      close_menu
      give_rewards(result)
    end

    # Récompenses d'un mini-jeu : Pofiteroles selon les étoiles, parfois une décoration
    # @param result [Hash, nil] { points:, stars: }
    def give_rewards(result)
      return unless result

      stars = result[:stars].to_i
      @pokemon.amie_change(:pet) if stars > 0
      gifts = P.give_rewards(stars)
      refresh_stats
      return notify(P.t('Pas de récompense cette fois…', 'No reward this time…')) if gifts.empty?

      happy
      notify(P.t("Obtenu : #{gifts.join(', ')}", "Got: #{gifts.join(', ')}"))
      @notice = 180
    end
  end
end

# Raids : Aventures Raid (d'après les « Raid Adventures » du plugin d'origine)
#
# Le joueur laisse son équipe à l'entrée, choisit 3 Pokémon de location et avance tout seul sur une carte de cases
# (Data/configs/plugins/raids_cartes.json, carte dessinée dans graphics/interface/raids/adventure/maps). Il choisit
# sa route aux croisements ; chaque case Combat lance un raid (le dernier est le boss). Les cœurs servent de compteur de
# K.O. pour tous les combats : à 0, l'aventure s'arrête. Un Pokémon battu est capturé et peut remplacer un membre de
# l'équipe. À la fin, le joueur garde un des Pokémon capturés et les objets trouvés.
# Cases : Pathway, StartPoint, Battle, Crossroad, TurnNorth/South/West/East, RandomTurn, ReverseTurn, Door, Key, Chest,
# Switch (montre / cache les cases « toggle »), Warp (case warp), Portal, Teleporter, Roadblock, HiddenTrap, Berries,
# Flare, Assistant, ItemVendor, StatTrainer, MoveTutor, Nurse, Mystic, MysteryNPC, Researcher, PartnerA, PartnerB.
module Raids
  class Adventure
    TILE = 16
    DIRS = { 0 => [0, -1], 1 => [0, 1], 2 => [-1, 0], 3 => [1, 0] }.freeze
    OPPOSITE = { 0 => 1, 1 => 0, 2 => 3, 3 => 2 }.freeze
    # Cases qui disparaissent une fois utilisées
    CONSUMED = %w[Berries Flare Key Chest Door Roadblock Assistant ItemVendor StatTrainer MoveTutor Nurse Mystic MysteryNPC
                  Researcher PartnerA PartnerB].freeze
    # Obstacles : type(s) nécessaire(s) et textes
    ROADBLOCKS = [
      [%i[flying], ['Un gouffre profond barre la route !', 'A deep chasm blocks your path!'],
       ['%s vous fait passer de l’autre côté !', '%s happily carried you across the chasm!']],
      [%i[water], ['Une grande mare d’eau trouble barre la route !', 'A large pool of murky water blocks your path!'],
       ['%s vous fait traverser l’eau !', '%s happily carried you across the water!']],
      [%i[fighting], ['Un mur bloque le passage, mais il a l’air fragile.', 'The wall here seems thin.'],
       ['%s défonce le mur d’un coup puissant !', '%s bashed through the wall with a mighty blow!']],
      [%i[psychic], ['Le sol semble instable par endroits…', 'The floor here seems unstable in certain spots...'],
       ['%s devine le chemin sûr !', '%s foresaw the dangers ahead!']],
      [%i[rock ground steel], ['Une tempête de poussière souffle ici !', 'A dust storm blocks your path!'],
       ['%s vous protège de la tempête !', '%s shielded you from the dust storm!']],
      [%i[fire], ['Des ronces épaisses bloquent le passage !', 'Thick brambles block your path!'],
       ['%s brûle les ronces !', '%s burned away the brambles!']]
    ].freeze

    # @return [Hash] carte (raids_cartes.json)
    attr_reader :map
    # @return [Symbol]
    attr_reader :style
    attr_accessor :hearts, :max_hearts, :keys, :outcome, :boss_battled, :battle_count, :light
    # @return [Hash{Symbol => Integer}]
    attr_reader :loot
    # @return [Array<PFM::Pokemon>]
    attr_reader :captures, :party
    # @return [Hash{Array(Integer, Integer) => Hash}] cases
    attr_reader :tiles
    # @return [Array<Hash>] combats ({ pos:, rules:, battled: })
    attr_reader :battles
    attr_accessor :x, :y, :dir
    # @return [Array<Array(Integer, Integer)>] croisements visités (Téléporteur)
    attr_reader :crossroads
    # @return [Boolean] carte dans le noir
    attr_reader :darkness

    # @param map [Hash]
    # @param style [Symbol]
    # @param party [Array<PFM::Pokemon>] Pokémon de location
    def initialize(map, style, party)
      @map = map
      @style = style
      @party = party
      @hearts = @max_hearts = party.size + 1
      @keys = 0
      @loot = Hash.new(0)
      @captures = []
      @outcome = nil
      @boss_battled = false
      @battle_count = 0
      @crossroads = []
      @light = 0
      @darkness = rand(100) < Raids.fetch(map, 'darkness').to_i
      @dir = 0
      build_tiles
      build_battles
    end

    def level
      return [(Raids.badges + 1) * 10, 70].min
    end

    # --- Cases --------------------------------------------------------------------------------------------------------
    def build_tiles
      @tiles = {}
      Array(Raids.fetch(@map, 'pathways')).each { |x, y| @tiles[[x, y]] = { id: 'Pathway' } }
      Array(Raids.fetch(@map, 'battles')).each_with_index { |(x, y), i| @tiles[[x, y]] = { id: 'Battle', battle: i } }
      Array(Raids.fetch(@map, 'tiles')).each do |tile|
        pos = [Raids.fetch(tile, 'x').to_i, Raids.fetch(tile, 'y').to_i]
        data = { id: Raids.fetch(tile, 'id').to_s }
        data[:toggle] = true if Raids.fetch(tile, 'toggle')
        data[:hidden] = true if data[:toggle]
        data[:warp] = Raids.fetch(tile, 'warp') if Raids.fetch(tile, 'warp')
        data[:variant] = rand(ROADBLOCKS.size) if data[:id] == 'Roadblock'
        data[:battle] = @tiles[pos][:battle] if @tiles[pos]&.key?(:battle)
        @tiles[pos] = data
      end
      start = Raids.fetch(@map, 'start') || @tiles.find { |_p, t| t[:id] == 'StartPoint' }&.first || [0, 0]
      @x, @y = start
      @start = [@x, @y]
      @tiles[[@x, @y]] ||= { id: 'Pathway' }
    end

    # @return [Hash, nil] case (nil : rien, ou case cachée)
    def tile(x, y)
      data = @tiles[[x, y]]
      return nil if data.nil? || data[:hidden] || data[:id] == 'Empty'

      return data
    end

    # @return [Array<Integer>] directions possibles depuis une case
    def directions(x = @x, y = @y)
      return DIRS.select { |_d, (dx, dy)| tile(x + dx, y + dy) }.keys
    end

    # Combats : rangs 3, 4 puis 5 ; le dernier est le boss (rang 6)
    def build_battles
      positions = Array(Raids.fetch(@map, 'battles'))
      count = positions.size
      @battles = positions.each_with_index.map do |pos, i|
        boss = i == count - 1
        rank = boss ? 6 : [3 + (i * 3 / [count - 1, 1].max), 5].min
        rules = Rules.new(style: @style, rank: rank, adventure: { hearts: @hearts, captures: @captures }, size: 3,
                          turns: 15, shield: 5, final_boss: boss)
        rules.pokemon = Raids.create_boss(rules)
        level = [(Raids.badges + 1) * 7, 56].min + (boss ? 4 : 0)
        rules.pokemon.level = level
        rules.pokemon.hp = rules.pokemon.max_hp
        rules.pokemon.instance_variable_set(:@shiny, false)
        { pos: pos, rules: rules, battled: false, boss: boss }
      end
    end

    # @return [Hash, nil]
    def boss_battle
      return @battles.find { |b| b[:boss] }
    end

    # --- Déroulement --------------------------------------------------------------------------------------------------
    # Case du joueur : effets puis direction suivante
    # @param scene [AdventureScene]
    # @return [Integer, nil] direction (nil : arrêt)
    def process_tile(scene)
      data = @tiles[[@x, @y]]
      data[:visited] = true if data
      dirs = directions
      dir = @dir
      dir = Raids::AdventureTiles.trigger(self, scene, data, dir, dirs) if data && data[:id] != 'Pathway'
      return nil if @outcome

      dirs = directions
      return nil if dirs.empty?
      # Pas de demi-tour tout seul : on continue tout droit, sinon on tourne
      return dir if dirs.include?(dir)

      others = dirs - [OPPOSITE[dir]]
      return others.first if others.size == 1
      return scene.choose_direction(dirs, dir) if others.size > 1

      return dirs.first
    end

    # Combat d'une case
    # @param scene [AdventureScene]
    # @param battle [Hash]
    def fight(scene, battle)
      return if battle[:battled]

      rules = battle[:rules]
      rules.ko_count = @hearts
      rules.adventure[:hearts] = @hearts
      rules.adventure[:captures] = @captures
      @boss_battled = battle[:boss]
      scene.display_message(format(Raids.t('Un %s sauvage vous attend !', 'A wild %s is waiting for you!'), rules.pokemon.name))
      outcome = nil
      Raids.start_battle(rules) { |result, _battle_scene| outcome = result }
      battle[:battled] = true
      @hearts = rules.ko_count.to_i
      @party.each { |pokemon| pokemon.hp = pokemon.max_hp if pokemon.dead? }
      @party.each(&:cure)
      if %i[win caught].include?(outcome)
        @battle_count += 1
        Raids.stats[:won] += 1
        captured = @captures.last if outcome == :caught
        if captured && !@boss_battled
          captured.level = level if captured.level > level
          scene.refresh_hud
          Raids::AdventureMenus.exchange(self, scene, captured)
        end
        @outcome = :win if @boss_battled
      else
        @outcome = @boss_battled ? :lost_boss : :lost
      end
      scene.refresh_battles
      scene.refresh_hud
    end

    # Fin : objets, Pokémon gardé, équipe rendue
    def finish(scene)
      case @outcome
      when :win
        scene.display_message(Raids.t('Vous avez terminé l’aventure !', 'You completed the adventure!'))
        Raids.stats[:adventures] += 1
      when :lost_boss
        scene.display_message(Raids.t('Le boss a eu raison de vous…', 'The boss got the better of you...'))
      else
        scene.display_message(Raids.t('L’aventure s’arrête ici.', 'The adventure is over.'))
      end
      loot = @loot.to_a
      loot.map! { |item, count| [item, (count / 2.0).ceil] } if @outcome == :lost_boss
      loot = [] unless %i[win lost_boss].include?(@outcome)
      loot.each { |item, count| $bag.add_item(item, count) }
      unless loot.empty?
        names = loot.map { |item, count| "#{Raids.item_name(item)} x#{count}" }.join(', ')
        scene.display_message(format(Raids.t('Objets trouvés : %s.', 'Items found: %s.'), names))
      end
      Raids::AdventureMenus.spoils(self, scene) unless @captures.empty?
    end
  end

  # --- Écran de la carte -------------------------------------------------------------------------------------------------
  class AdventureScene < GamePlay::BaseCleanUpdate
    WHITE = 10
    T = Adventure::TILE

    # @param adventure [Adventure]
    def initialize(adventure)
      super()
      @adventure = adventure
      @started = false
    end

    def update_inputs
      return true if @started

      @started = true
      run
      @running = false
      return false
    end

    def update_graphics
      @player_sprite&.update
      return true
    end

    # Boucle de l'aventure (bloquante)
    def run
      bgm = Raids.fetch(Raids.style_data(@adventure.style), 'adventure_bgm').to_s
      $game_system.bgm_play(RPG::AudioFile.new(bgm)) unless bgm.empty?
      intro
      dir = @adventure.directions.first || 0
      @adventure.dir = dir
      until @adventure.outcome
        dir = @adventure.process_tile(self)
        break if @adventure.outcome

        if dir.nil?
          display_message(Raids.t('Plus aucun chemin ! Il faut abandonner l’aventure.', 'No valid paths found! You were forced to abandon the adventure!'))
          @adventure.outcome = :lost
          break
        end
        @adventure.dir = dir
        step(dir)
      end
      @adventure.finish(self)
    end

    def intro
      name = Raids.local(Raids.fetch(@adventure.map, 'name'))
      display_message(format(Raids.t('%s : %s', '%s: %s'), Raids.style_text(@adventure.style, 'adventure'), name))
      boss = @adventure.boss_battle
      if boss
        type = data_type(Raids.creature_types(boss[:rules].pokemon.db_symbol, boss[:rules].pokemon.form).first || :normal).name
        display_message(format(Raids.t('Un puissant Pokémon de type %s attend au fond !', 'A powerful %s-type Pokémon awaits at the end!'), type))
      end
      display_message(Raids.t('Les cœurs servent pour tous les combats : à chaque K.O., vous en perdez un.', 'Your hearts are shared by every battle: you lose one each time a Pokémon faints.'))
    end

    # Avance d'une case (animation), la caméra suit
    def step(dir)
      dx, dy = Adventure::DIRS[dir]
      8.times do
        @player_sprite.x += dx * 2
        @player_sprite.y += dy * 2
        follow_camera
        Graphics.update
        update_graphics
      end
      @adventure.x += dx
      @adventure.y += dy
      place_player
    end

    # Choix d'une direction (croisement) ; Y : menu
    # @return [Integer]
    def choose_direction(dirs, current)
      dir = dirs.include?(current) ? current : dirs.first
      show_arrows(dirs, dir)
      loop do
        Graphics.update
        update_graphics
        { UP: 0, DOWN: 1, LEFT: 2, RIGHT: 3 }.each do |key, d|
          next unless Input.trigger?(key) && dirs.include?(d)

          dir = d
          play_cursor_se
          show_arrows(dirs, dir)
        end
        if Input.trigger?(:A)
          play_decision_se
          break
        elsif Input.trigger?(:Y) || Input.trigger?(:X)
          play_decision_se
          Raids::AdventureMenus.pause(@adventure, self)
          return current if @adventure.outcome

          show_arrows(dirs, dir)
        end
      end
      hide_arrows
      return dir
    end

    # Téléporteur : choisir une case
    # @param positions [Array<Array(Integer, Integer)>]
    # @return [Array(Integer, Integer), nil]
    def choose_position(positions)
      index = 0
      cursor = Sprite.new(@map_viewport)
      cursor.bitmap = RPG::Cache.interface(Raids.file('adventure/cursor'))
      cursor.zoom = 0.5
      cursor.z = 70
      loop do
        x, y = positions[index]
        cursor.set_position(x * T - 2, y * T - 2)
        center_on(x, y)
        Graphics.update
        if Input.trigger?(:LEFT) || Input.trigger?(:UP)
          index = (index - 1) % positions.size
          play_cursor_se
        elsif Input.trigger?(:RIGHT) || Input.trigger?(:DOWN)
          index = (index + 1) % positions.size
          play_cursor_se
        elsif Input.trigger?(:A)
          play_decision_se
          cursor.dispose
          return positions[index]
        elsif Input.trigger?(:B)
          play_cancel_se
          cursor.dispose
          follow_camera
          return nil
        end
      end
    end

    # Joueur placé sur sa case (après un saut)
    def place_player
      @player_sprite.set_position(@adventure.x * T + T / 2, @adventure.y * T + T)
      follow_camera
    end

    def refresh_hud
      @hearts.each_with_index do |heart, i|
        heart.visible = i < @adventure.max_hearts
        heart.src_rect.y = i < @adventure.hearts ? 0 : 11
      end
      @keys_text.text = "x#{@adventure.keys}"
      @dark&.zoom = 1.0 + @adventure.light * 0.5
    end

    # Cases (après une case utilisée, un interrupteur…)
    def refresh_tiles
      @tile_sprites.each_value(&:dispose)
      @tile_sprites.clear
      @adventure.tiles.each do |(x, y), data|
        next if data[:hidden] || data[:id] == 'Empty'

        name = data[:id] == 'Battle' ? 'Battle' : data[:id]
        name = 'Pathway' if data[:used]
        sprite = Sprite.new(@map_viewport)
        sprite.bitmap = RPG::Cache.interface(Raids.file("adventure/tiles/#{name}"))
        sprite.set_position(x * T, y * T)
        sprite.zoom = 0.5
        sprite.z = 10
        @tile_sprites[[x, y]] = sprite
      end
      @player_sprite.z = 50 if @player_sprite
    end

    # Pokémon des combats (silhouettes tant qu'ils ne sont pas battus)
    def refresh_battles
      @battle_sprites.each(&:dispose)
      @battle_sprites.clear
      @adventure.battles.each do |battle|
        next if battle[:battled]

        x, y = battle[:pos]
        sprite = UI::PokemonIconSprite.new(@map_viewport)
        sprite.data = battle[:rules].pokemon
        sprite.set_position(x * T + T / 2, y * T + T / 2)
        sprite.zoom = battle[:boss] ? 0.8 : 0.6
        sprite.tone.set(-255, -255, -255, 0)
        sprite.z = 40
        @battle_sprites << sprite
      end
    end

    private

    def create_graphics
      super
      @map_viewport = Viewport.create(:main, 10_001)
      @map_stack = UI::SpriteStack.new(@map_viewport)
      image = Raids.fetch(@adventure.map, 'image').to_s
      @map_sprite = @map_stack.add_sprite(0, 0, Raids.file("adventure/maps/#{image}"))
      @map_sprite.zoom = 0.5
      @tile_sprites = {}
      @battle_sprites = []
      refresh_tiles
      refresh_battles
      create_player
      @hud_viewport = Viewport.create(:main, 10_002)
      @hud = UI::SpriteStack.new(@hud_viewport)
      if @adventure.darkness
        @dark = @hud.add_sprite(0, 0, Raids.file('adventure/darkness'))
        @dark.set_origin(320, 240)
      end
      @hud.add_sprite(4, 4, Raids.file('adventure/hud'))
      @hearts = Array.new(6) do |i|
        heart = @hud.add_sprite(8 + i * 13, 8, Raids.file('adventure/hearts'))
        heart.src_rect.set(0, 0, 12, 11)
        heart
      end
      @hud.add_sprite(228, 7, Raids.file('adventure/key'))
      @keys_text = @hud.add_text(242, 4, 30, 16, '', color: WHITE)
      @arrows = Array.new(4) do |i|
        arrow = Sprite.new(@map_viewport)
        arrow.bitmap = RPG::Cache.interface(Raids.file('adventure/arrows'))
        arrow.src_rect.set(i * 16, 0, 16, 16)
        arrow.visible = false
        arrow.z = 60
        arrow
      end
      refresh_hud
      place_player
    end

    def create_player
      @player_sprite = Sprite.new(@map_viewport)
      bitmap = RPG::Cache.character($game_player.character_name.to_s)
      @player_sprite.bitmap = bitmap
      w = bitmap.width / 4
      h = bitmap.height / 4
      @player_sprite.src_rect.set(0, 0, w, h)
      @player_sprite.set_origin(w / 2, h)
      @player_sprite.zoom = T * 1.25 / [w, 1].max
      @player_sprite.z = 50
    rescue StandardError
      @player_sprite = Sprite.new(@map_viewport)
    end

    def dispose
      @tile_sprites&.each_value(&:dispose)
      @battle_sprites&.each(&:dispose)
      @arrows&.each(&:dispose)
      @player_sprite&.dispose
      super
    end
    public :dispose

    def follow_camera
      center_on_pixels(@player_sprite.x, @player_sprite.y - T / 2)
    end

    def center_on(x, y)
      center_on_pixels(x * T + T / 2, y * T + T / 2)
    end

    def center_on_pixels(px, py)
      width = Raids.fetch(@adventure.map, 'width').to_i * T
      height = Raids.fetch(@adventure.map, 'height').to_i * T
      ox = width < 320 ? -(320 - width) / 2 : (px - 160).clamp(0, width - 320)
      oy = height < 240 ? -(240 - height) / 2 : (py - 120).clamp(0, height - 240)
      @map_viewport.ox = ox
      @map_viewport.oy = oy
      @dark&.set_position(px - ox, py - oy)
    end

    def show_arrows(dirs, dir)
      @arrows.each_with_index do |arrow, d|
        arrow.visible = dirs.include?(d)
        dx, dy = Adventure::DIRS[d]
        arrow.set_position((@adventure.x + dx) * T, (@adventure.y + dy) * T)
        arrow.opacity = d == dir ? 255 : 120
      end
    end

    def hide_arrows
      @arrows.each { |arrow| arrow.visible = false }
    end
  end

  module_function

  # Lance une aventure
  # @param style [Symbol]
  # @param map_id [Integer, nil]
  def start_adventure(style = :max, map_id = nil)
    style = normalize_style(style)
    style = :basic unless style_available?(style)
    maps = Array(maps_config.maps)
    if maps.empty?
      $scene.display_message(t('Aucune carte d’aventure n’est réglée.', 'No adventure map is set up.'))
      return
    end
    map = maps.find { |m| fetch(m, 'id').to_i == map_id.to_i } if map_id
    map ||= choose_map(maps)
    return unless map

    level = [(badges + 1) * 10, 70].min
    rentals = AdventureMenus.choose_rentals(style, level)
    return if rentals.nil? || rentals.empty?

    stored = $actors.dup
    bgm = $game_system.playing_bgm
    adventure = Adventure.new(map, style, rentals)
    begin
      $actors.replace(rentals)
      $scene.call_scene(AdventureScene, adventure)
    ensure
      $actors.replace(stored)
      $game_system.bgm_play(bgm) if bgm
    end
    AdventureMenus.keep_spoils(adventure)
    return adventure.outcome
  end

  def choose_map(maps)
    return maps.first if maps.size == 1

    names = maps.map { |m| local(fetch(m, 'name')) }
    choice = $scene.display_message(t('Quelle carte explorer ?', 'Which map do you want to explore?'), names.size + 1, *names, t('Annuler', 'Cancel'))
    return choice.to_i < maps.size ? maps[choice.to_i] : nil
  end
end

# Gimmicks : cinématiques façon Pokémon Essentials (Deluxe Battle Kit)
#
# L'écran passe au noir, on retrouve le Pokémon (de face) sur son socle et son dresseur qui arrive sur le côté,
# le terrain s'assombrit, l'effet de la mécanique se joue, le Pokémon se transforme sur un fond de lignes de vitesse,
# puis retour au combat. A ou B passe la cinématique.
#
# Méga-Évolution : énergie rose du dresseur vers le Pokémon, silhouette, sphère de lumière qui devient une sphère
#   rouge craquelée, éclatement, nouvelle forme sur fond bleu avec le symbole Méga.
# Téracristal : terrain teinté de la couleur du type, étoile, cristal qui recouvre le Pokémon, explosion arc-en-ciel,
#   le Pokémon apparaît couvert du motif de son type.
# Dynamax : énergie rouge, le Pokémon grandit en silhouette, éclat rouge, forme géante.
module Gimmicks
  class Cinematic
    # Viewport au-dessus du combat et de la boîte de message
    Z = 20_000
    # Pokémon du joueur : Pokémon à droite, dresseur à gauche (inversé pour l'adversaire)
    POKEMON_X = 186
    TRAINER_X = 52
    GROUND_Y = 172
    TRAINER_Y = 192
    POKEMON_ZOOM = 1.25
    # Textures dessinées une fois pour toute la partie
    TEXTURES = {}

    # @param scene [Battle::Scene]
    # @param battler [PFM::PokemonBattler]
    def initialize(scene, battler)
      @scene = scene
      @visual = scene.visual
      @battler = battler
      @owned = []
      @transformed = false
      @skip = false
      @enemy = battler.bank != 0
      @poke_x = @enemy ? 320 - POKEMON_X : POKEMON_X
      @trainer_x = @enemy ? 320 - TRAINER_X : TRAINER_X
    end

    # Joue la cinématique
    # @param kind [Symbol] :mega, :dynamax, :tera, :zmove, :ultra
    # @param arg [Object] détail de l'effet (titre de la capacité Z…)
    # @param transform [Proc] change le Pokémon (forme, type…) au moment de l'éclat
    def play(kind, arg = nil, &transform)
      @transform = transform
      @visual.wait_for_animation
      fade_to_black
      build_stage
      fade_from_black
      intro
      arg.nil? ? send(:"effect_#{kind}") : send(:"effect_#{kind}", arg)
      fade_to_black
      dispose_stage
      apply_transform
      fade_from_black(true)
    ensure
      dispose
    end

    private

    # --- Boucle -------------------------------------------------------------------
    # @param count [Integer] nombre d'images
    # @yieldparam index [Integer]
    # @yieldparam rate [Float] avancement de 0 à 1
    def frames(count)
      count.times do |index|
        @skip ||= Input.trigger?(:A) || Input.trigger?(:B) if @stage
        break if @skip && @stage

        yield(index, (index + 1).to_f / count) if block_given?
        tick
      end
    end

    def tick
      # LiteRGSS ne range les sprites selon leur z qu'à la demande : sans ça, un sprite créé
      # pendant l'effet (voile, lignes de vitesse…) passe devant le Pokémon malgré un z plus petit
      if @sort_needed && @viewport && !@viewport.disposed?
        @viewport.sort_z
        @sort_needed = false
      end
      if @overlay && @pokemon && !@pokemon.disposed?
        @overlay.sync(@pokemon)
        @overlay.opacity = (@overlay.opacity * @overlay_rate).to_i if @overlay_rate
      end
      was_locked = @visual.locking?
      @visual.lock unless was_locked
      @visual.scene_update_proc {}
      @visual.unlock unless was_locked
    end

    # Courbe douce (départ rapide, arrivée lente)
    def ease_out(rate)
      return 1 - (1 - rate)**3
    end

    def apply_transform
      return if @transformed

      @transformed = true
      @transform&.call
      sprite = @visual.battler_sprite(@battler.bank, @battler.position)
      sprite.pokemon = @battler if sprite
      @visual.refresh_info_bar(@battler) if @visual.respond_to?(:refresh_info_bar)
    end

    # Transformation pendant la cinématique (le sprite du combat change aussi)
    def apply_transform_in_stage
      return if @transformed

      @transformed = true
      @transform&.call
      @transform = nil
      @transformed = false
      refresh_pokemon_bitmap if @pokemon && !@pokemon.disposed?
      build_tera_overlay
    end

    def cry
      @visual.battler_sprite(@battler.bank, @battler.position)&.cry
    rescue StandardError
      nil
    end

    # --- Fondus -------------------------------------------------------------------
    def fade_to_black
      @viewport ||= Viewport.create(:main, Z)
      @black ||= plain_sprite(Color.new(0, 0, 0), 320, 240, 100)
      @black.opacity = 0
      frames(12) { |_, rate| @black.opacity = (255 * rate).to_i }
      @black.opacity = 255
    end

    # @param last [Boolean] retour au combat
    def fade_from_black(last = false)
      skip = @skip
      @skip = false if last
      frames(12) { |_, rate| @black.opacity = (255 * (1 - rate)).to_i }
      @skip = skip
      @black.opacity = 0
    end

    # --- Scène --------------------------------------------------------------------
    # Plans (z) : 0 terrain, 1 socles, 2 voile sombre, 3 teinte, 4-7 fonds d'effet, 8 halo, 9 dresseur,
    # 10 Pokémon, 11+ effets devant, 60 éclat blanc
    def build_stage
      hidden = hide_battle
      background = @visual.viewport.snap_to_bitmap
      @owned << background
      restore_battle(hidden)
      @stage = []
      @bg = stage_sprite(background, 160, 120, 0)
      @bg.set_origin(160, 120)
      @bg.zoom = 1.3
      @dark = plain_sprite(Color.new(0, 0, 0), 320, 240, 2)
      @dark.opacity = 70
      @base = stage_sprite(platform_texture, @poke_x, GROUND_Y, 1)
      @base.set_origin(64, 16)
      @trainer_base = stage_sprite(platform_texture, @trainer_x, TRAINER_Y - 2, 1)
      @trainer_base.set_origin(64, 16)
      @trainer_base.zoom = 0.7
      build_trainer
      build_pokemon
      @flash = plain_sprite(Color.new(255, 255, 255), 320, 240, 60)
      @flash.opacity = 0
    end

    # Cache les boîtes et les Pokémon du combat le temps de photographier le terrain
    def hide_battle
      @visual.hide_info_bars(true)
      sprites = []
      (@visual.instance_variable_get(:@battlers) || {}).each_value do |bank|
        bank.each_value do |sprite|
          next unless sprite.respond_to?(:visible) && sprite.visible

          sprite.visible = false
          sprites << sprite
        end
      end
      return sprites
    end

    # @param sprites [Array]
    def restore_battle(sprites)
      sprites.each { |sprite| sprite.visible = true }
    end

    def build_pokemon
      @pokemon = Sprite::WithColor.new(@viewport)
      @pokemon.z = 10
      @sort_needed = true
      @stage << @pokemon
      refresh_pokemon_bitmap
      @pokemon.set_position(@poke_x, GROUND_Y)
      @pokemon.zoom = POKEMON_ZOOM
      @pokemon.set_color([1, 1, 1, 0])
      build_tera_overlay
    end

    def refresh_pokemon_bitmap
      @pokemon.bitmap = @battler.battler_face
      @margin = bottom_margin(@pokemon.bitmap)
      @pokemon.set_origin(@pokemon.bitmap.width / 2, @pokemon.bitmap.height - @margin)
    end

    # Motif Téra / Dynamax sur le Pokémon de la cinématique
    def build_tera_overlay
      kind = if @battler.respond_to?(:pj_tera?) && @battler.pj_tera?
               Gimmicks.tera_type_of(@battler)
             elsif @battler.respond_to?(:pj_dynamax?) && @battler.pj_dynamax?
               :dynamax
             end
      return unless kind
      return @overlay.type = kind if @overlay && !@overlay.disposed?

      @overlay = TeraOverlay.new(@viewport, kind)
      @sort_needed = true
      @stage << @overlay
    rescue StandardError
      @overlay = nil
    end

    # Milieu du Pokémon à l'écran
    # @return [Integer]
    def pokemon_center_y
      height = @pokemon.bitmap ? (@pokemon.bitmap.height - @margin.to_i) * 0.42 : 40
      return (GROUND_Y - height * @pokemon.zoom_y).to_i
    end

    # Lignes vides en bas de l'image (pour poser le Pokémon sur son socle)
    # @param texture [Texture]
    # @return [Integer]
    def bottom_margin(texture)
      @margins ||= {}
      return @margins[texture] ||= begin
        image = Image.new(texture.to_png, true)
        empty = 0
        (texture.height - 1).downto(0) do |y|
          break if (0...texture.width).step(2).any? { |x| image.get_pixel_alpha(x, y) > 0 }

          empty += 1
        end
        image.dispose
        [empty - 4, 0].max
      end
    rescue StandardError
      return 0
    end

    def build_trainer
      texture, rect = trainer_texture
      return unless texture

      @trainer = Sprite::WithColor.new(@viewport)
      @trainer.z = 9
      @sort_needed = true
      @trainer.bitmap = texture
      @trainer.src_rect.set(*rect) if rect
      width = rect ? rect[2] : texture.width
      height = rect ? rect[3] : texture.height
      @trainer.set_origin(width / 2, height - bottom_margin_rect(texture, rect))
      @trainer.set_position(@trainer_x, TRAINER_Y)
      @trainer.zoom = height > 140 ? 0.75 : 1
      @trainer.set_color([1, 1, 1, 0])
      @stage << @trainer
    end

    # @return [Integer]
    def bottom_margin_rect(texture, rect)
      return rect ? 0 : bottom_margin(texture)
    end

    # Image de face du dresseur (joueur : image du générateur « <nom>_front », sinon son image de dos)
    # @return [Array(Texture, Array), nil]
    def trainer_texture
      names = @scene.battle_info.battlers[@battler.bank] || []
      name = names[@battler.party_id.to_i] || names.first
      if name
        base = name.to_s.sub(/_back\z/, '')
        plain = base.sub(/_r\d+\z/, '')
        ["#{base}_front", "#{plain}_front", "#{base}_big", base].uniq.each do |candidate|
          next if candidate == name.to_s && @battler.bank == 0
          next unless RPG::Cache.battler_exist?(candidate)

          return RPG::Cache.battler(candidate), nil
        end
      end
      sprite = @visual.battler_sprite(@battler.bank, -@battler.party_id.to_i - 1)
      return nil unless sprite.respond_to?(:bitmap) && sprite.bitmap && !sprite.bitmap.disposed?

      return sprite.bitmap, [sprite.src_rect.x, sprite.src_rect.y, sprite.src_rect.width, sprite.src_rect.height]
    rescue StandardError
      return nil
    end

    def dispose_stage
      @stage&.each { |sprite| sprite.dispose unless sprite.disposed? }
      @stage = nil
      @overlay = nil
    end

    def dispose
      dispose_stage
      @black&.dispose
      @viewport&.dispose
      @owned.each { |texture| texture.dispose unless texture.disposed? }
      @visual.show_info_bars rescue nil
    end

    # --- Début commun : la caméra glisse, le dresseur arrive ------------------------
    def intro
      side = @enemy ? 1 : -1
      start = @trainer_x + side * 90
      @trainer&.x = start
      @trainer_base.x = start
      frames(22) do |_, rate|
        x = start + (@trainer_x - start) * ease_out(rate)
        @trainer&.x = x
        @trainer_base.x = x
        @bg.x = 160 - side * 14 * ease_out(rate)
      end
      frames(10)
    end

    # Assombrit le terrain (voile noir)
    # @param target [Integer] opacité visée
    # @param count [Integer]
    def darken(target, count, &block)
      from = @dark.opacity
      frames(count) do |index, rate|
        @dark.opacity = (from + (target - from) * rate).to_i
        block&.call(index, rate)
      end
    end

    # Particules d'énergie du dresseur (anneau, orbe…) vers le Pokémon
    # @param color [Array<Integer>]
    # @param count [Integer] nombre de particules
    # @param duration [Integer]
    def energy_to_pokemon(color, count, duration, &block)
      source_x = @trainer_x + (@enemy ? -10 : 10)
      source_y = TRAINER_Y - 56
      target_y = pokemon_center_y
      texture = glow_texture(7, color)
      particles = count.times.map do |i|
        sprite = stage_sprite(texture, source_x, source_y, 12)
        sprite.set_origin(7, 7)
        sprite.opacity = 0
        [sprite, i * duration / (count * 2), (i.even? ? 1 : -1) * (20 + (i * 13) % 30)]
      end
      key = stage_sprite(glow_texture(12, color), source_x, source_y, 12)
      key.set_origin(12, 12)
      key.opacity = 0
      life = duration / 2
      frames(duration) do |index, rate|
        key.opacity = (255 * [rate * 4, 1].min * (index % 8 < 4 ? 1 : 0.75)).to_i
        particles.each do |sprite, delay, arc|
          t = (index - delay).to_f / life
          next sprite.opacity = 0 if t < 0 || t > 1

          sprite.opacity = (255 * Math.sin(t * Math::PI)).to_i
          sprite.x = source_x + (@poke_x - source_x) * t
          sprite.y = source_y + (target_y - source_y) * t - Math.sin(t * Math::PI) * arc
          sprite.zoom = 1.3 - t * 0.6
        end
        block&.call(index, rate)
      end
      particles.each { |sprite, _, _| sprite.opacity = 0 }
      frames(10) { |_, rate| key.opacity = (255 * (1 - rate)).to_i }
    end

    # Fond bleu à lignes de vitesse (moment où la nouvelle forme apparaît)
    # @param palette [Symbol] :blue, :red
    # @return [Sprite]
    def speed_lines(palette = :blue)
      textures = [speed_texture(palette, 1), speed_texture(palette, 2)]
      sprite = stage_sprite(textures.first, @poke_x, pokemon_center_y, 5)
      sprite.set_origin(90, 70)
      sprite.zoom = 2.4
      sprite.opacity = 0
      @speed_textures = textures
      return sprite
    end

    # Fait vibrer les lignes de vitesse
    def animate_speed(sprite, index)
      sprite.bitmap = @speed_textures[(index / 3) % 2] if @speed_textures
      sprite.angle = Math.sin(index / 9.0) * 2
    end

    # Retour au terrain sombre puis pause
    def outro(*sprites)
      frames(18) do |_, rate|
        sprites.each { |sprite| sprite.opacity = (sprite.opacity * (1 - rate)).to_i if sprite }
      end
      sprites.each { |sprite| sprite.visible = false if sprite }
      frames(30)
    end

    # --- Méga-Évolution -------------------------------------------------------------
    def effect_mega
      darken(215, 24) { |_, rate| @pokemon.set_color([0, 0, 0, rate * 0.9]) }
      $game_system.se_play(Configs.sounds.mega_evolve_se) rescue nil
      energy_to_pokemon([255, 90, 170], 8, 50)
      frames(14) { |_, rate| @pokemon.set_color([rate, rate, rate, 0.9 + 0.1 * rate]) }
      center_y = pokemon_center_y
      radius = sphere_radius
      disk = stage_sprite(disk_texture(64), @poke_x, center_y, 12)
      disk.set_origin(64, 64)
      disk.zoom = 0
      halo = stage_sprite(glow_texture(64, [255, 220, 150]), @poke_x, center_y, 11)
      halo.set_origin(64, 64)
      halo.opacity = 0
      sphere = stage_sprite(sphere_texture, @poke_x, center_y, 13)
      sphere.set_origin(64, 64)
      sphere.opacity = 0
      size = radius / 64.0
      frames(20) { |_, rate| disk.zoom = ease_out(rate) * size }
      frames(10)
      sphere.zoom = size
      frames(34) do |_, rate|
        sphere.opacity = (255 * rate).to_i
        halo.opacity = (255 * [rate * 1.5 - 0.5, 0].max).to_i
        halo.zoom = size * 1.5
      end
      disk.visible = false
      frames(30) do |index, _|
        shake = index.even? ? 1 : -1
        sphere.x = @poke_x + shake
        halo.zoom = size * (1.45 + 0.08 * Math.sin(index / 3.0))
      end
      frames(6) { |_, rate| @flash.opacity = (255 * rate).to_i }
      apply_transform_in_stage
      sphere.visible = false
      halo.visible = false
      lines = speed_lines(:blue)
      lines.opacity = 255
      glow = stage_sprite(glow_texture(64, [255, 250, 220]), @poke_x, pokemon_center_y, 8)
      glow.set_origin(64, 64)
      glow.zoom = 1.6
      symbol = mega_symbol
      cry
      frames(34) do |index, rate|
        @flash.opacity = (255 * (1 - rate)).to_i
        @pokemon.set_color([0.75, 0.75, 0.75, 1 - ease_out(rate)])
        animate_speed(lines, index)
        symbol&.opacity = (255 * rate).to_i
      end
      @pokemon.set_color([1, 1, 1, 0])
      frames(60) do |index, _|
        animate_speed(lines, index + 34)
        glow.zoom = 1.6 + 0.08 * Math.sin(index / 5.0)
        symbol&.y = symbol_y + Math.sin(index / 8.0) * 2
      end
      outro(lines, glow)
      frames(10) { |_, rate| symbol&.opacity = (255 * (1 - rate)).to_i }
    end

    # Taille de la sphère : elle couvre le Pokémon
    # @return [Integer]
    def sphere_radius
      height = @pokemon.bitmap ? (@pokemon.bitmap.height - @margin.to_i) : 80
      return [[(height * @pokemon.zoom_y * 0.55).to_i, 44].max, 70].min
    end

    # @return [Integer]
    def symbol_y
      height = @pokemon.bitmap ? (@pokemon.bitmap.height - @margin.to_i) : 80
      return [(GROUND_Y - height * @pokemon.zoom_y * 0.85 - 14).to_i, 18].max
    end

    # Symbole de la Méga-Évolution au-dessus du Pokémon
    # @return [Sprite, nil]
    def mega_symbol
      sprite = animation_sprite('mega-evolution/icon_mega', @poke_x, symbol_y, 30)
      unless sprite
        sprite = interface_sprite('icon_mega', @poke_x, symbol_y, 30)
        sprite&.zoom = 2.5
      end
      sprite&.opacity = 0
      return sprite
    end

    # --- Téracristal ----------------------------------------------------------------
    def effect_tera
      type = Gimmicks.tera_type_of(@battler)
      rgb = Gimmicks::Tera::COLORS[type] || [255, 255, 255]
      rgb = [190, 190, 200] if type == :stellar
      tint = plain_sprite(Color.new(*rgb.map { |c| (c * 0.75).to_i }), 320, 240, 3)
      tint.opacity = 0
      center_y = pokemon_center_y
      darken(40, 24) do |_, rate|
        tint.opacity = (190 * rate).to_i
        @pokemon.set_color([1, 1, 1, rate * 0.5])
      end
      energy_to_pokemon(rgb.map { |c| [c + 60, 255].min }, 6, 40)
      star = stage_sprite(star_texture, @poke_x, center_y, 8)
      star.set_origin(80, 80)
      star.zoom = 0
      frames(22) do |_, rate|
        @pokemon.set_color([1, 1, 1, 0.5 + 0.5 * rate])
        star.zoom = ease_out(rate) * 1.2
        star.opacity = 200
        star.angle = (1 - rate) * 25
      end
      crystal_y = GROUND_Y - 44
      crystals = (1..3).map { |i| interface_sprite("tera_crystal_#{i}", @poke_x, crystal_y, 12 + i) }.compact
      crystals.each { |crystal| crystal.opacity = 0 }
      $game_system.se_play(Configs.sounds.mega_evolve_se) rescue nil
      crystals.each do |crystal|
        frames(10) do |_, rate|
          crystal.opacity = (255 * rate).to_i
          crystal.zoom_y = 0.4 + 0.6 * ease_out(rate)
          crystal.zoom_x = 0.8 + 0.2 * ease_out(rate)
        end
      end
      white = plain_sprite(Color.new(255, 255, 255), 320, 240, 20)
      white.opacity = 0
      frames(30) do |index, rate|
        star.opacity = (200 * (1 - rate)).to_i
        white.opacity = (170 * rate).to_i
        crystals.each { |crystal| crystal.x = @poke_x + (index.even? ? 1 : -1) }
      end
      frames(6) { |_, rate| @flash.opacity = (255 * rate).to_i }
      apply_transform_in_stage
      crystals.each { |crystal| crystal.visible = false }
      star.visible = false
      white.opacity = 0
      center_y = pokemon_center_y
      burst = stage_sprite(burst_texture(type, rgb), @poke_x, center_y, 7)
      burst.set_origin(64, 64)
      burst.zoom = 2.6
      crown = interface_sprite('tera_icon', @poke_x, symbol_y - 6, 30)
      if crown
        crown.zoom = 0.3
        crown.opacity = 0
      end
      @overlay_rate = 0
      shards = 6.times.map { |i| [interface_sprite('tera_crystal_4', @poke_x, center_y, 25), i * Math::PI / 3] }
      shards.reject! { |shard, _| shard.nil? }
      cry
      frames(34) do |index, rate|
        @flash.opacity = (255 * (1 - rate)).to_i
        @pokemon.set_color([1, 1, 1, 1 - ease_out(rate)])
        @overlay_rate = ease_out(rate)
        burst.angle = index * 0.6
        burst.zoom = 2.6 + 0.3 * rate
        shards.each do |shard, angle|
          shard.zoom = 0.5
          shard.opacity = (255 * (1 - rate)).to_i
          shard.set_position(@poke_x + Math.cos(angle) * 150 * ease_out(rate), center_y + Math.sin(angle) * 110 * ease_out(rate))
          shard.angle = index * 8
        end
        crown&.opacity = (255 * rate).to_i
      end
      @pokemon.set_color([1, 1, 1, 0])
      @overlay_rate = nil
      lines = speed_lines(:blue)
      frames(16) do |index, rate|
        lines.opacity = (255 * rate).to_i
        burst.zoom = 2.9 - 1.5 * rate
        burst.angle = (34 + index) * 0.6
        animate_speed(lines, index)
      end
      frames(50) do |index, _|
        animate_speed(lines, index + 16)
        burst.angle = (50 + index) * 0.6
        burst.zoom = 1.4 + 0.06 * Math.sin(index / 5.0)
        crown&.y = symbol_y - 6 + Math.sin(index / 8.0) * 2
      end
      outro(lines, burst)
      frames(10) { |_, rate| crown&.opacity = (255 * (1 - rate)).to_i }
    end

    # --- Capacité Z ----------------------------------------------------------------
    # Rayons dorés, le Pokémon et son dresseur s'illuminent, la Force Z monte, titre de l'attaque
    # @param title [String] image de graphics/interface/gimmicks/z_titles
    def effect_zmove(title = nil)
      darken(200, 20)
      $game_system.se_play(Configs.sounds.mega_evolve_se) rescue nil
      energy_to_pokemon([255, 220, 90], 8, 44) do |_, rate|
        @trainer&.set_color([1, 0.95, 0.6, rate * 0.7])
      end
      lines = speed_lines(:gold)
      glow = stage_sprite(glow_texture(64, [255, 230, 120]), @poke_x, pokemon_center_y, 8)
      glow.set_origin(64, 64)
      glow.zoom = 1.7
      glow.opacity = 0
      particles = 12.times.map { interface_sprite('z_particle', @poke_x, GROUND_Y, 15) }.compact
      particles.each { |particle| particle.opacity = 0 }
      title_sprite = title && interface_sprite("z_titles/#{title}", -140, 204, 30)
      frames(16) do |index, rate|
        lines.opacity = (255 * rate).to_i
        glow.opacity = (255 * rate).to_i
        @pokemon.set_color([1, 0.95, 0.6, rate * 0.7])
        animate_speed(lines, index)
      end
      cry
      frames(70) do |index, rate|
        animate_speed(lines, index + 16)
        particles.each_with_index do |particle, i|
          phase = ((index * 3 + i * 17) % 60) / 60.0
          particle.opacity = (255 * (1 - phase)).to_i
          particle.set_position(@poke_x - 50 + (i * 37) % 100, GROUND_Y - phase * 120)
        end
        title_sprite&.x = -140 + (300 * ease_out([rate * 3, 1].min)).to_i
      end
      frames(20) do |index, rate|
        animate_speed(lines, index + 86)
        @pokemon.set_color([1, 0.95, 0.6, 0.7 * (1 - rate)])
        @trainer&.set_color([1, 0.95, 0.6, 0.7 * (1 - rate)])
        particles.each { |particle| particle.opacity = (particle.opacity * (1 - rate)).to_i }
        title_sprite&.opacity = (255 * (1 - rate)).to_i
      end
      outro(lines, glow)
    end

    # --- Ultra-Explosion -------------------------------------------------------------
    # Necrozma devient noir, une étoile de lumière le traverse, éclat, forme Ultra
    def effect_ultra
      darken(230, 20) { |_, rate| @pokemon.set_color([0, 0, 0, rate]) }
      star = interface_sprite('z_ultra_icon', @poke_x, pokemon_center_y, 20)
      if star
        star.opacity = 0
        star.zoom = 0.2
      end
      frames(50) do |index, rate|
        next unless star

        star.opacity = (255 * rate).to_i
        star.zoom = 0.2 + rate * 0.7
        star.angle = index
      end
      frames(6) { |_, rate| @flash.opacity = (255 * rate).to_i }
      apply_transform_in_stage
      star&.visible = false
      lines = speed_lines(:gold)
      lines.opacity = 255
      cry
      frames(40) do |index, rate|
        @flash.opacity = (255 * (1 - rate)).to_i
        @pokemon.set_color([1, 0.9, 0.5, 0.8 * (1 - rate)])
        animate_speed(lines, index)
      end
      frames(40) { |index, _| animate_speed(lines, index + 40) }
      @pokemon.set_color([1, 1, 1, 0])
      outro(lines)
    end

    # --- Dynamax ----------------------------------------------------------------------
    # Énergie rouge du Bracelet, le Pokémon grandit en silhouette rouge, éclat, forme géante sur fond rouge
    def effect_dynamax
      red = plain_sprite(Color.new(150, 10, 60), 320, 240, 3)
      red.opacity = 0
      darken(190, 22) { |_, rate| red.opacity = (110 * rate).to_i }
      $game_system.se_play(Configs.sounds.mega_evolve_se) rescue nil
      energy_to_pokemon([255, 40, 110], 10, 50) do |_, rate|
        @pokemon.set_color([1, 0.15, 0.4, rate])
      end
      glow = stage_sprite(glow_texture(64, [255, 60, 120]), @poke_x, pokemon_center_y, 8)
      glow.set_origin(64, 64)
      glow.opacity = 0
      frames(50) do |index, rate|
        @pokemon.zoom = POKEMON_ZOOM + ease_out(rate) * 0.95
        @base.zoom_x = 1 + rate * 0.6
        glow.opacity = (220 * rate).to_i
        glow.y = pokemon_center_y
        glow.zoom = 1 + rate * 1.4
        @pokemon.x = @poke_x + (index.even? ? 1 : -1) * (rate * 2).to_i
      end
      frames(6) { |_, rate| @flash.opacity = (255 * rate).to_i }
      apply_transform_in_stage
      @pokemon.x = @poke_x
      lines = speed_lines(:red)
      lines.y = pokemon_center_y
      lines.opacity = 255
      glow.y = pokemon_center_y
      cry
      frames(34) do |index, rate|
        @flash.opacity = (255 * (1 - rate)).to_i
        @pokemon.set_color([1, 0.15, 0.4, 1 - 0.75 * ease_out(rate)])
        animate_speed(lines, index)
      end
      frames(50) do |index, _|
        animate_speed(lines, index + 34)
        glow.zoom = 2.4 + 0.1 * Math.sin(index / 5.0)
      end
      outro(lines, glow)
      @pokemon.set_color([1, 1, 1, 0])
    end

    # --- Sprites ----------------------------------------------------------------------
    # @return [Sprite]
    def stage_sprite(texture, x, y, z)
      sprite = Sprite.new(@viewport)
      sprite.bitmap = texture
      sprite.set_position(x, y)
      sprite.z = z
      @sort_needed = true
      @stage << sprite
      return sprite
    end

    # @return [Sprite, nil] image de graphics/animations
    def animation_sprite(name, x, y, z)
      return nil unless RPG::Cache.animation_exist?(name)

      sprite = Sprite.new(@viewport)
      sprite.bitmap = RPG::Cache.animation(name)
      sprite.set_origin(sprite.bitmap.width / 2, sprite.bitmap.height / 2)
      sprite.set_position(x, y)
      sprite.z = z
      @sort_needed = true
      @stage << sprite
      return sprite
    rescue StandardError
      return nil
    end

    # @return [Sprite, nil] image de graphics/interface/gimmicks
    def interface_sprite(name, x, y, z)
      return nil unless RPG::Cache.interface_exist?(Gimmicks.file(name))

      sprite = Sprite.new(@viewport)
      sprite.bitmap = RPG::Cache.interface(Gimmicks.file(name))
      sprite.set_origin(sprite.bitmap.width / 2, sprite.bitmap.height / 2)
      sprite.set_position(x, y)
      sprite.z = z
      @sort_needed = true
      @stage << sprite
      return sprite
    end

    # Rectangle d'une couleur
    def plain_sprite(color, width, height, z)
      image = Image.new(width, height)
      image.fill_rect(0, 0, width, height, color)
      sprite = Sprite.new(@viewport)
      sprite.bitmap = texture_from(image)
      sprite.z = z
      @sort_needed = true
      @stage << sprite if @stage && z < 100
      return sprite
    end

    # @param image [Image]
    # @return [Texture]
    def texture_from(image, keep = false)
      texture = Texture.new(image.width, image.height)
      image.copy_to_bitmap(texture)
      image.dispose
      @owned << texture unless keep
      return texture
    end

    # Texture gardée pour les cinématiques suivantes
    # @param key [Object]
    # @param size [Array(Integer, Integer)]
    # @yieldparam x [Integer]
    # @yieldparam y [Integer]
    # @yieldreturn [Array(Integer, Integer, Integer, Integer), nil] couleur du pixel (nil : transparent)
    def cached_texture(key, width, height)
      texture = TEXTURES[key]
      return texture if texture && !texture.disposed?

      image = Image.new(width, height)
      height.times do |y|
        width.times do |x|
          color = yield(x, y)
          image.set_pixel(x, y, Color.new(*color)) if color
        end
      end
      return TEXTURES[key] = texture_from(image, true)
    end

    # Disque blanc au bord adouci
    def disk_texture(radius)
      return cached_texture([:disk, radius], radius * 2, radius * 2) do |x, y|
        dist = Math.hypot(x - radius + 0.5, y - radius + 0.5)
        next nil if dist > radius

        [255, 255, 255, dist > radius - 2 ? (255 * (radius - dist) / 2).to_i : 255]
      end
    end

    # Halo lumineux
    def glow_texture(radius, rgb)
      return cached_texture([:glow, radius, rgb], radius * 2, radius * 2) do |x, y|
        t = Math.hypot(x - radius + 0.5, y - radius + 0.5) / radius
        next nil if t >= 1

        white = (1 - t)**3
        [rgb[0] + ((255 - rgb[0]) * white).to_i, rgb[1] + ((255 - rgb[1]) * white).to_i, rgb[2] + ((255 - rgb[2]) * white).to_i,
         (255 * (1 - t)**2).to_i]
      end
    end

    # Socle clair (comme ceux du combat)
    def platform_texture
      return cached_texture(:platform, 128, 32) do |x, y|
        t = Math.sqrt(((x - 63.5) / 64.0)**2 + ((y - 15.5) / 16.0)**2)
        next nil if t >= 1

        if t > 0.86 then [205, 190, 225, 255]
        elsif t > 0.62 then [238, 232, 246, 235]
        elsif t > 0.5 then [190, 160, 205, 235]
        else [228, 220, 238, 220]
        end
      end
    end

    # Sphère rouge craquelée (Méga-Évolution)
    def sphere_texture
      points = Array.new(12) do |i|
        angle = i * 2.399963
        dist = 60 * Math.sqrt((i + 0.5) / 12.0)
        [64 + Math.cos(angle) * dist + ((i * 37) % 9) - 4, 64 + Math.sin(angle) * dist + ((i * 53) % 9) - 4]
      end
      return cached_texture(:mega_sphere, 128, 128) do |x, y|
        dist = Math.hypot(x - 63.5, y - 63.5)
        next nil if dist > 63
        next [255, 245, 235, dist > 62 ? 140 : 255] if dist > 60.5

        d1 = 999
        d2 = 999
        points.each do |px, py|
          d = Math.hypot(x - px, y - py)
          if d < d1
            d2 = d1
            d1 = d
          elsif d < d2
            d2 = d
          end
        end
        next [250, 235, 235, 255] if d2 - d1 < 1.8

        light = 1 + 0.35 * (1 - Math.hypot(x - 44, y - 40) / 90.0)
        [[(112 * light).to_i, 255].min, (26 * light).to_i, (42 * light).to_i, 255]
      end
    end

    # Étoile à quatre branches (Téracristal)
    def star_texture
      return cached_texture(:tera_star, 160, 160) do |x, y|
        dx = (x - 79.5).abs / 80.0
        dy = (y - 79.5).abs / 80.0
        value = dx**0.62 + dy**0.62
        next nil if value >= 1

        [255, 255, 255, (190 * [(1 - value) * 4, 1].min).to_i]
      end
    end

    # Explosion arc-en-ciel au centre de la couleur du type (Téracristal)
    def burst_texture(type, rgb)
      return cached_texture([:tera_burst, type], 128, 128) do |x, y|
        dx = x - 63.5
        dy = y - 63.5
        t = Math.hypot(dx, dy) / 64.0
        next nil if t >= 1

        sector = (((Math.atan2(dy, dx) + Math::PI) / (2 * Math::PI)) * 64).floor
        ray = ((sector * 7919) % 100) / 100.0
        if t < 0.38
          white = 1 - t / 0.38
          color = rgb.map { |c| (c + (255 - c) * white * 0.6).to_i }
        else
          hue = (0.95 + (t - 0.38) * 1.1 + ray * 0.05) % 1
          color = hsv(hue, 0.28 + 0.18 * ray, 1)
          mix = [(0.48 - t) / 0.1, 0].max
          color = color.each_with_index.map { |c, i| (c + (rgb[i] - c) * [mix, 1].min).to_i }
        end
        alpha = t > 0.7 ? (1 - t) / 0.3 : 1
        [color[0], color[1], color[2], (255 * alpha * (0.85 + 0.15 * ray)).to_i]
      end
    end

    # Fond à lignes de vitesse
    # @param palette [Symbol] :blue, :red, :gold
    # @param seed [Integer] variante (les deux variantes alternent)
    def speed_texture(palette, seed)
      dark, light = { blue: [[16, 92, 200], [110, 190, 255]], red: [[120, 0, 40], [255, 80, 120]],
                      gold: [[150, 90, 10], [255, 220, 110]] }[palette] || [[16, 92, 200], [110, 190, 255]]
      return cached_texture([:speed, palette, seed], 180, 140) do |x, y|
        dx = x - 89.5
        dy = (y - 69.5) * 1.15
        r = Math.hypot(dx, dy)
        t = [r / 95.0, 1].min
        base = dark.each_with_index.map { |c, i| (light[i] + (c - light[i]) * t).to_i }
        sector = (((Math.atan2(dy, dx) + Math::PI) / (2 * Math::PI)) * 260).floor
        hash = ((sector * 2_654_435 + seed * 97_531) % 1000) / 1000.0
        start = 22 + hash * 55
        if hash < 0.38 && r > start
          strength = [(r - start) / 25.0, 1].min * (0.55 + hash * 0.8)
          base = base.map { |c| (c + (255 - c) * [strength, 1].min).to_i }
        end
        [base[0], base[1], base[2], 255]
      end
    end

    # @return [Array<Integer>] couleur RVB
    def hsv(hue, sat, val)
      i = (hue * 6).floor
      f = hue * 6 - i
      p = val * (1 - sat)
      q = val * (1 - f * sat)
      t = val * (1 - (1 - f) * sat)
      rgb = [[val, t, p], [q, val, p], [p, val, t], [p, q, val], [t, p, val], [val, p, q]][i % 6]
      return rgb.map { |c| (c * 255).to_i }
    end
  end
end

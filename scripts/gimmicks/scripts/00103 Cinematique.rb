# Gimmicks : cinématique façon Pokémon Essentials (Deluxe Battle Kit)
#
# L'écran passe au noir, puis on voit le Pokémon (de face, en grand) et son dresseur sur le terrain du combat
# assombri ; l'effet de la mécanique se joue, le Pokémon se transforme, puis retour au combat.
# A ou B passe la cinématique.
module Gimmicks
  class Cinematic
    # Viewport au-dessus du combat et de la boîte de message
    Z = 20_000
    # Positions (bas des sprites)
    POKEMON_X = 204
    TRAINER_X = 96
    GROUND_Y = 178

    # @param scene [Battle::Scene]
    # @param battler [PFM::PokemonBattler]
    def initialize(scene, battler)
      @scene = scene
      @visual = scene.visual
      @battler = battler
      @owned = []
      @transformed = false
      @skip = false
    end

    # Joue la cinématique
    # @param kind [Symbol] :mega, :dynamax, :tera, :zmove, :ultra
    # @param arg [Object] détail de l'effet (titre de la capacité Z…)
    # @param transform [Proc] change le Pokémon (forme, type…) au moment du flash
    def play(kind, arg = nil, &transform)
      @transform = transform
      @visual.wait_for_animation
      fade_to_black
      build_stage
      fade_from_black
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
      was_locked = @visual.locking?
      @visual.lock unless was_locked
      @visual.scene_update_proc {}
      @visual.unlock unless was_locked
    end

    def apply_transform
      return if @transformed

      @transformed = true
      @transform&.call
      sprite = @visual.battler_sprite(@battler.bank, @battler.position)
      sprite.pokemon = @battler if sprite
      @visual.refresh_info_bar(@battler) if @visual.respond_to?(:refresh_info_bar)
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
    def build_stage
      hidden = hide_battle
      background = @visual.viewport.snap_to_bitmap
      @owned << background
      restore_battle(hidden)
      @stage = []
      @bg = stage_sprite(background, 160, 120, 0)
      @bg.set_origin(160, 120)
      @bg.zoom = 1.25
      @dark = plain_sprite(Color.new(0, 0, 0), 320, 240, 1)
      @dark.opacity = 110
      @tint = plain_sprite(Color.new(255, 255, 255), 320, 240, 2)
      @tint.opacity = 0
      @ground = stage_sprite(ellipse_texture(72, 14), POKEMON_X, GROUND_Y - 2, 3)
      @ground.set_origin(72, 14)
      @ground.opacity = 160
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
      @stage << @pokemon
      refresh_pokemon_bitmap
      @pokemon.set_position(POKEMON_X, GROUND_Y)
      @pokemon.zoom = 1.5
      @pokemon.set_color([1, 1, 1, 0])
    end

    def refresh_pokemon_bitmap
      @pokemon.bitmap = @battler.battler_face
      @pokemon.set_origin(@pokemon.bitmap.width / 2, @pokemon.bitmap.height - bottom_margin(@pokemon.bitmap))
    end

    # Lignes vides en bas de l'image (pour poser le Pokémon sur le sol)
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
        empty
      end
    rescue StandardError
      return 0
    end

    def build_trainer
      texture, rect = trainer_texture
      return unless texture

      @trainer = Sprite::WithColor.new(@viewport)
      @trainer.z = 9
      @trainer.bitmap = texture
      @trainer.src_rect.set(*rect) if rect
      width = rect ? rect[2] : texture.width
      height = rect ? rect[3] : texture.height
      @trainer.set_origin(width / 2, height)
      @trainer.set_position(TRAINER_X, GROUND_Y + 2)
      @trainer.set_color([1, 1, 1, 0])
      @stage << @trainer
    end

    # Image de face du dresseur (joueur : image du générateur ou « <nom>_front »)
    # @return [Array(Texture, Array), nil]
    def trainer_texture
      names = @scene.battle_info.battlers[@battler.bank] || []
      name = names[@battler.party_id.to_i] || names.first
      return nil unless name

      base = name.to_s.sub(/_back\z/, '')
      ["#{base}_front", "#{base}_big", base].each do |candidate|
        next if candidate == name.to_s && @battler.bank == 0
        next unless RPG::Cache.battler_exist?(candidate)

        return RPG::Cache.battler(candidate), nil
      end
      sprite = @visual.battler_sprite(@battler.bank, -@battler.party_id.to_i - 1)
      return nil unless @battler.bank != 0 && sprite.respond_to?(:bitmap) && sprite.bitmap

      return sprite.bitmap, [sprite.src_rect.x, sprite.src_rect.y, sprite.src_rect.width, sprite.src_rect.height]
    rescue StandardError
      return nil
    end

    def dispose_stage
      @stage&.each { |sprite| sprite.dispose unless sprite.disposed? }
      @stage = nil
    end

    def dispose
      dispose_stage
      @black&.dispose
      @viewport&.dispose
      @owned.each { |texture| texture.dispose unless texture.disposed? }
      @visual.show_info_bars rescue nil
    end

    # --- Effets -------------------------------------------------------------------
    # Méga-Évolution : le Pokémon devient blanc, une sphère de lumière l'enveloppe, flash, nouvelle forme
    def effect_mega
      rays = stage_sprite(rays_texture(Color.new(80, 150, 255), Color.new(200, 230, 255)), 160, 120, 4)
      rays.set_origin(100, 100)
      rays.zoom = 2.2
      rays.opacity = 0
      orb = stage_sprite(disk_texture(48), POKEMON_X, GROUND_Y - 50, 20)
      orb.set_origin(48, 48)
      orb.zoom = 0
      ring = animation_sprite('mega-evolution/mega-evolution-ring', POKEMON_X, GROUND_Y - 50, 21)
      icon = animation_sprite('mega-evolution/icon_mega', POKEMON_X, GROUND_Y - 120, 22)
      ring&.opacity = 0
      icon&.opacity = 0
      $game_system.se_play(Configs.sounds.mega_evolve_se) rescue nil
      frames(30) { |_, rate| @pokemon.set_color([1, 1, 1, rate]) }
      frames(30) do |_, rate|
        orb.zoom = rate * 1.6
        orb.opacity = 255
      end
      frames(10) { |_, rate| @flash.opacity = (255 * rate).to_i }
      apply_transform_in_stage
      @tint.opacity = 0
      rays.opacity = 255
      orb.opacity = 0
      @dark.opacity = 0
      @visual.battler_sprite(@battler.bank, @battler.position)&.cry rescue nil
      frames(40) do |index, rate|
        @flash.opacity = (255 * (1 - rate)).to_i
        @pokemon.set_color([1, 1, 1, 1 - rate])
        rays.angle = index * 2
        if ring
          ring.opacity = (255 * (1 - rate)).to_i
          ring.zoom = 0.7 + rate * 2
        end
        icon&.opacity = (255 * [rate * 2, 1].min).to_i
      end
      frames(40) do |index, rate|
        rays.angle = (40 + index) * 2
        icon&.opacity = (255 * (1 - rate)).to_i
      end
      @pokemon.set_color([1, 1, 1, 0])
    end

    # Téracristal : fond violet, des cristaux recouvrent le Pokémon, éclatent, il apparaît aux couleurs de son type
    def effect_tera
      type = Gimmicks.tera_type_of(@battler)
      rgb = (Gimmicks::Tera::COLORS[type] || [255, 255, 255]).map { |c| c / 255.0 }
      purple = plain_sprite(Color.new(70, 30, 130), 320, 240, 2)
      purple.opacity = 0
      center_y = GROUND_Y - 60
      crystals = (1..3).map { |i| interface_sprite("tera_crystal_#{i}", POKEMON_X, center_y, 20 + i) }.compact
      crystals.each { |c| c.opacity = 0 }
      shine = interface_sprite('tera_shine', POKEMON_X, center_y, 5)
      shine&.opacity = 0
      pulse = interface_sprite('tera_pulse', POKEMON_X, center_y, 6)
      pulse&.opacity = 0
      shards = 4.times.map { interface_sprite('tera_crystal_4', POKEMON_X, center_y, 24) }.compact
      shards.each { |c| c.opacity = 0 }
      icon = interface_sprite('tera_icon', POKEMON_X, center_y - 70, 25)
      if icon
        icon.opacity = 0
        icon.zoom = 0.3
      end
      frames(25) do |_, rate|
        @pokemon.set_color([1, 1, 1, rate])
        purple.opacity = (200 * rate).to_i
      end
      crystals.each do |crystal|
        frames(14) do |_, rate|
          crystal.opacity = (255 * rate).to_i
          crystal.zoom = 1.0 + 0.25 * rate
        end
      end
      frames(20)
      frames(8) { |_, rate| @flash.opacity = (255 * rate).to_i }
      apply_transform_in_stage
      crystals.each { |c| c.opacity = 0 }
      @pokemon.set_color(rgb + [0.6])
      @visual.battler_sprite(@battler.bank, @battler.position)&.cry rescue nil
      directions = [[-1, -1], [1, -1], [-1, 1], [1, 1]]
      frames(40) do |index, rate|
        @flash.opacity = (255 * (1 - rate)).to_i
        if shine
          shine.opacity = (255 * (1 - rate)).to_i
          shine.zoom = 0.6 + rate * 1.6
          shine.angle = index * 3
        end
        if pulse
          pulse.opacity = (255 * (1 - rate)).to_i
          pulse.zoom = 1 + rate * 4
        end
        shards.each_with_index do |shard, i|
          dx, dy = directions[i]
          shard.opacity = (255 * (1 - rate)).to_i
          shard.set_position(POKEMON_X + dx * rate * 120, center_y + dy * rate * 90)
          shard.angle = index * 6 * dx
        end
        @pokemon.set_color(rgb + [0.6 - 0.4 * rate])
        if icon
          icon.opacity = (255 * [rate * 2, 1].min).to_i
          icon.zoom = 0.3 + 0.15 * rate
        end
      end
      frames(35) do |_, rate|
        icon&.opacity = (255 * (1 - rate)).to_i
        @pokemon.set_color(rgb + [0.2 * (1 - rate)])
      end
      @pokemon.set_color([1, 1, 1, 0])
    end

    # Capacité Z : rayons dorés, le Pokémon et son dresseur s'illuminent, la Force Z monte, titre de l'attaque
    # @param title [String] image de graphics/interface/gimmicks/z_titles
    def effect_zmove(title = nil)
      rays = stage_sprite(rays_texture(Color.new(250, 200, 60), Color.new(255, 240, 170)), 160, 120, 4)
      rays.set_origin(100, 100)
      rays.zoom = 2.2
      rays.opacity = 0
      particles = 10.times.map { interface_sprite('z_particle', POKEMON_X, GROUND_Y, 15) }.compact
      particles.each { |p| p.opacity = 0 }
      title_sprite = title && interface_sprite("z_titles/#{title}", -140, 196, 30)
      frames(25) do |_, rate|
        rays.opacity = (255 * rate).to_i
        @pokemon.set_color([1, 1, 0.75, rate * 0.8])
        @trainer&.set_color([1, 1, 0.75, rate * 0.8]) if @trainer.respond_to?(:set_color)
      end
      @visual.battler_sprite(@battler.bank, @battler.position)&.cry rescue nil
      frames(60) do |index, rate|
        rays.angle = index * 2
        particles.each_with_index do |particle, i|
          phase = ((index * 3 + i * 17) % 60) / 60.0
          particle.opacity = (255 * (1 - phase)).to_i
          particle.set_position(POKEMON_X - 40 + (i * 37) % 80, GROUND_Y - phase * 110)
        end
        title_sprite&.x = -140 + (300 * [rate * 3, 1].min).to_i
      end
      frames(30) do |index, rate|
        rays.angle = (60 + index) * 2
        @pokemon.set_color([1, 1, 0.75, 0.8 * (1 - rate)])
        @trainer&.set_color([1, 1, 0.75, 0.8 * (1 - rate)]) if @trainer.respond_to?(:set_color)
        particles.each { |p| p.opacity = (p.opacity * (1 - rate)).to_i }
        title_sprite&.opacity = (255 * (1 - rate)).to_i
      end
      @pokemon.set_color([1, 1, 1, 0])
    end

    # Ultra-Explosion : Necrozma devient noir, une étoile de lumière le traverse, flash, forme Ultra
    def effect_ultra
      @dark.opacity = 230
      star = interface_sprite('z_ultra_icon', POKEMON_X, GROUND_Y - 60, 20)
      if star
        star.opacity = 0
        star.zoom = 0.2
      end
      frames(30) { |_, rate| @pokemon.set_color([0, 0, 0, rate]) }
      frames(40) do |index, rate|
        next unless star

        star.opacity = (255 * rate).to_i
        star.zoom = 0.2 + rate * 0.6
        star.angle = index
      end
      frames(10) { |_, rate| @flash.opacity = (255 * rate).to_i }
      apply_transform_in_stage
      star&.opacity = 0
      @dark.opacity = 60
      @tint.opacity = 0
      @visual.battler_sprite(@battler.bank, @battler.position)&.cry rescue nil
      frames(50) do |_, rate|
        @flash.opacity = (255 * (1 - rate)).to_i
        @pokemon.set_color([1, 0.9, 0.5, 0.7 * (1 - rate)])
      end
      frames(30)
      @pokemon.set_color([1, 1, 1, 0])
    end

    # Dynamax : énergie rouge, le Pokémon devient une silhouette blanche géante, puis apparaît en rouge
    def effect_dynamax
      rays = stage_sprite(rays_texture(Color.new(200, 20, 90), Color.new(255, 90, 150)), 160, 120, 4)
      rays.set_origin(100, 100)
      rays.zoom = 2.2
      rays.opacity = 0
      clouds = interface_sprite('dynamax_pattern', 160, 228, 6)
      clouds&.opacity = 0
      frames(25) do |_, rate|
        @pokemon.set_color([1, 1, 1, rate])
        rays.opacity = (220 * rate).to_i
        clouds&.opacity = (255 * rate).to_i
      end
      frames(45) do |index, rate|
        @pokemon.zoom = 1.5 + rate * 1.1
        rays.angle = index * 2
        clouds&.x = 160 - (index % 40)
        @ground.zoom_x = 1 + rate * 0.8
      end
      frames(8) { |_, rate| @flash.opacity = (255 * rate).to_i }
      apply_transform_in_stage
      @pokemon.zoom = 2.6
      @visual.battler_sprite(@battler.bank, @battler.position)&.cry rescue nil
      frames(40) do |index, rate|
        @flash.opacity = (255 * (1 - rate)).to_i
        rays.angle = (45 + index) * 2
        @pokemon.set_color([1, 0.1, 0.35, 0.8 - 0.5 * rate])
      end
      frames(35) do |index, _|
        rays.angle = (85 + index) * 2
      end
      @pokemon.set_color([1, 1, 1, 0])
    end

    # Transformation pendant la cinématique (le sprite de la scène change aussi)
    def apply_transform_in_stage
      return if @transformed

      @transformed = true
      @transform&.call
      @transform = nil
      @transformed = false
      refresh_pokemon_bitmap if @pokemon && !@pokemon.disposed?
    end

    # --- Sprites ------------------------------------------------------------------
    # @return [Sprite]
    def stage_sprite(texture, x, y, z)
      sprite = Sprite.new(@viewport)
      sprite.bitmap = texture
      sprite.set_position(x, y)
      sprite.z = z
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
      @stage << sprite if @stage && z < 100
      return sprite
    end

    # @param image [Image]
    # @return [Texture]
    def texture_from(image)
      texture = Texture.new(image.width, image.height)
      image.copy_to_bitmap(texture)
      image.dispose
      @owned << texture
      return texture
    end

    # Disque blanc au bord adouci
    def disk_texture(radius)
      size = radius * 2
      image = Image.new(size, size)
      size.times do |y|
        size.times do |x|
          dist = Math.hypot(x - radius + 0.5, y - radius + 0.5)
          next if dist > radius

          alpha = dist > radius - 4 ? (255 * (radius - dist) / 4).to_i : 255
          image.set_pixel(x, y, Color.new(255, 255, 255, alpha))
        end
      end
      return texture_from(image)
    end

    # Ombre au sol
    def ellipse_texture(rx, ry)
      image = Image.new(rx * 2, ry * 2)
      (ry * 2).times do |y|
        (rx * 2).times do |x|
          d = ((x - rx + 0.5) / rx)**2 + ((y - ry + 0.5) / ry)**2
          image.set_pixel(x, y, Color.new(20, 20, 30, (200 * (1 - d)).to_i)) if d < 1
        end
      end
      return texture_from(image)
    end

    # Rayons qui partent du centre (fond des transformations)
    def rays_texture(color_a, color_b, count = 24)
      size = 200
      image = Image.new(size, size)
      size.times do |y|
        size.times do |x|
          angle = Math.atan2(y - 100, x - 100)
          sector = ((angle + Math::PI) / (2 * Math::PI) * count).floor
          image.set_pixel(x, y, sector.even? ? color_a : color_b)
        end
      end
      return texture_from(image)
    end
  end
end

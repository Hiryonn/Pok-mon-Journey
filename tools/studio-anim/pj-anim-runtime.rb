# encoding: utf-8
# =============================================================================
# Studio Animations — animations des attaques faites dans Pokémon Studio (Données > Attaques > Animations)
# -----------------------------------------------------------------------------
# Sources : Data/studio_animations/moves/<attaque>.json
# Cache (créé en mode debug, à livrer avec le jeu compilé) : Data/studio_animations.rxdata
#
# Une attaque qui a une animation Studio la joue à la place de celle de PSDK (Animations.rxdata).
# Format d'une animation :
#   duration  durée en secondes
#   layers    calques : image (graphics/animations), cell (taille d'une case), anchor (user, target, path, screen),
#             blend (0 normal, 1 addition, 2 soustraction), front (devant / derrière la cible),
#             keys : { t, cell, x, y, p (path : 0 lanceur -> 1 cible), zoom (%), angle, opacity, mirror, visible, tween }
#   events    évènements : se (son), flash (on: user / target / screen), shake, move (aller-retour), hide, show
# Les positions sont vues depuis le joueur (lanceur en bas à gauche, cible en haut à droite) ; elles sont
# retournées quand c'est l'adversaire qui attaque.
# =============================================================================
require 'json'

module StudioAnimations
  FOLDER = 'Data/studio_animations/moves'
  CACHE_FILE = 'Data/studio_animations.rxdata'

  class << self
    # Animations du projet : { db_symbol => Hash }
    # @return [Hash{Symbol => Hash}]
    def data
      refresh_if_changed unless release?
      @data ||= load_all
    end

    # Inscrit les animations auprès de PSDK (Battle::MoveAnimation)
    def register_all
      list = data
      return if @registered.equal?(list)

      specific = Battle::MoveAnimation.instance_variable_get(:@specific_move_animations)
      (@registered_keys || []).each { |db| specific[db]&.delete(:first_use) }
      list.each do |db_symbol, anim|
        user = Player.new(anim, :user)
        target = Player.new(anim, :target)
        Battle::MoveAnimation.register_specific_animation(db_symbol, :first_use, user, target)
      end
      @registered_keys = list.keys
      @registered = list
    rescue StandardError => e
      log_studio_animations_error('Impossible d’inscrire les animations', e)
    end

    def refresh_if_changed
      now = Time.now
      return if @last_check && now - @last_check < 1

      @last_check = now
      signature = sources.map { |f| [f, File.mtime(f).to_f] }
      @data = nil if @signature && signature != @signature
      @signature = signature
    rescue StandardError
      nil
    end

    def release?
      defined?(PSDK_CONFIG) && PSDK_CONFIG.respond_to?(:release?) && PSDK_CONFIG.release?
    end

    def sources
      Dir.exist?(FOLDER) ? Dir[File.join(FOLDER, '*.json')].sort : []
    end

    def load_all
      if release?
        return load_data(CACHE_FILE) rescue {}
      end

      result = {}
      sources.each do |file|
        json = JSON.parse(File.read(file, encoding: 'utf-8'))
        result[File.basename(file, '.json').to_sym] = normalize(json)
      rescue StandardError => e
        log_studio_animations_error("Animation invalide : #{file}", e)
      end
      begin
        File.binwrite(CACHE_FILE, Marshal.dump(result))
      rescue StandardError
        nil
      end
      return result
    end

    # JSON -> Hash à clés symboles, valeurs prêtes à jouer
    def normalize(json)
      layers = (json['layers'] || []).map do |layer|
        keys = (layer['keys'] || []).map do |k|
          {
            t: k['t'].to_f, cell: k['cell']&.to_i, x: k['x']&.to_f, y: k['y']&.to_f, p: k['p']&.to_f, zoom: k['zoom']&.to_f,
            angle: k['angle']&.to_f, opacity: k['opacity']&.to_f, mirror: k['mirror'], visible: k['visible'] != false,
            tween: k['tween'] != false
          }
        end.sort_by { |k| k[:t] }
        {
          image: layer['image'].to_s, cell: (layer['cell'] || 192).to_i, cell_h: (layer['cellH'] || layer['cell'] || 192).to_i,
          anchor: (layer['anchor'] || 'target').to_sym, blend: layer['blend'].to_i, front: layer['front'] != false, keys: keys
        }
      end
      events = (json['events'] || []).map do |e|
        e.transform_keys(&:to_sym).merge(t: e['t'].to_f, type: e['type'].to_s.to_sym, on: (e['on'] || 'target').to_sym)
      end.sort_by { |e| e[:t] }
      { duration: [json['duration'].to_f, 0.05].max, layers: layers, events: events }
    end

    def log_studio_animations_error(message, error)
      text = "[StudioAnimations] #{message} : #{error.class} #{error.message}"
      respond_to?(:log_error, true) ? log_error(text) : puts(text)
    end
  end

  # Animation jouée par PSDK : role :user (calques user / screen, évènements du lanceur et sons)
  # ou :target (calques target / path, évènements de la cible). Pas d'objet graphique avant start (Marshal).
  class Player < Yuki::Animation::TimedAnimation
    # @param anim [Hash]
    # @param role [Symbol]
    def initialize(anim, role)
      super(anim[:duration])
      @role = role
      user_side = role == :user
      @layers = anim[:layers].select { |l| %i[user screen].include?(l[:anchor]) == user_side }
      @events = anim[:events].select do |e|
        if e[:type] == :se then user_side
        else %i[user screen].include?(e[:on]) == user_side
        end
      end
      @total = anim[:duration]
    end

    def start(begin_offset = 0)
      super
      @user = resolve(:user)
      @target = resolve(:target)
      @viewport = resolve(:viewport)
      @reverse = @user.respond_to?(:bank) && @user.bank == 1
      @fired = []
      @moves = {}
      @sprites = @layers.map { |layer| create_sprite(layer) }
      @screen_flash = nil
      @origin = { user: sprite_position(@user), target: sprite_position(@target) }
      return self
    end

    private

    def update_internal(time_factor)
      return finish if time_factor >= 1 && @sprites

      t = time_factor * @total
      @layers.each_with_index { |layer, i| update_layer(@sprites[i], layer, t) if @sprites[i] }
      @events.each_with_index do |event, i|
        next if @fired[i] || t < event[:t]

        @fired[i] = true
        fire(event)
      end
      update_effects(t)
    end

    # --- Calques ---------------------------------------------------------------------------
    def create_sprite(layer)
      return nil if layer[:image].empty? || !RPG::Cache.animation_exist?(layer[:image])

      sprite = Sprite::WithColor.new(@viewport)
      sprite.bitmap = RPG::Cache.animation(layer[:image])
      sprite.set_origin(layer[:cell] / 2, layer[:cell_h] / 2)
      sprite.visible = false
      if layer[:blend] > 0
        begin
          sprite.shader.blend_type = layer[:blend]
        rescue StandardError
          nil
        end
      end
      base = layer[:anchor] == :user ? @user : @target
      base_z = base.respond_to?(:z) ? base.z : 0
      sprite.z = layer[:front] ? base_z + 1 : base_z - 1
      @viewport.sort_z if @viewport.respond_to?(:sort_z)
      return sprite
    rescue StandardError => e
      StudioAnimations.log_studio_animations_error("Image #{layer[:image]}", e)
      return nil
    end

    def update_layer(sprite, layer, t)
      keys = layer[:keys]
      index = keys.rindex { |k| k[:t] <= t }
      if index.nil? || !keys[index][:visible]
        sprite.visible = false
        return
      end
      a = keys[index]
      b = keys[index + 1]
      r = b && a[:tween] && b[:visible] && b[:t] > a[:t] ? (t - a[:t]) / (b[:t] - a[:t]) : 0
      v = ->(key, default) { lerp(a[key] || default, b ? (b[key] || a[key] || default) : (a[key] || default), r) }
      cols = [sprite.bitmap.width / layer[:cell], 1].max
      cell = a[:cell] || 0
      sprite.src_rect.set((cell % cols) * layer[:cell], (cell / cols) * layer[:cell_h], layer[:cell], layer[:cell_h])
      x, y = anchor_position(layer[:anchor], v.call(:p, 0))
      dx = v.call(:x, 0)
      dy = v.call(:y, 0)
      dx, dy = -dx, -dy if @reverse
      sprite.set_position(x + dx, y + dy)
      sprite.zoom = v.call(:zoom, 100) / 100.0
      sprite.angle = v.call(:angle, 0) * (@reverse ? -1 : 1)
      sprite.opacity = v.call(:opacity, 255).to_i
      sprite.mirror = @reverse ? !a[:mirror] : !!a[:mirror]
      sprite.visible = true
    end

    def lerp(a, b, r)
      a + (b - a) * r
    end

    # Centre d'un Pokémon (ses pieds sont à y)
    def sprite_position(sprite)
      return [160, 120] unless sprite

      height = sprite.respond_to?(:src_rect) && sprite.src_rect ? sprite.src_rect.height * sprite.zoom_y : 0
      return [sprite.x, sprite.y - height / 2]
    end

    def anchor_position(anchor, p)
      case anchor
      when :user then @origin[:user]
      when :screen then [160, 120]
      when :path
        u = @origin[:user]
        g = @origin[:target]
        [u[0] + (g[0] - u[0]) * p, u[1] + (g[1] - u[1]) * p]
      else @origin[:target]
      end
    end

    # --- Évènements ------------------------------------------------------------------------
    def fire(event)
      case event[:type]
      when :se
        Audio.se_play("audio/se/#{event[:name]}", (event[:volume] || 100).to_i, (event[:pitch] || 100).to_i) rescue nil
      when :flash
        flash(event)
      when :shake, :move
        on = event[:on] == :user ? @user : @target
        @moves[event.object_id] = event.merge(sprite: on, start: event[:t])
      when :hide, :show
        on = event[:on] == :user ? @user : @target
        return unless on

        on.visible = event[:type] == :show
        (@hidden ||= []) << on if event[:type] == :hide
      end
    end

    def flash(event)
      color = color_of(event[:color])
      alpha = (event[:alpha] || 255).to_f / 255
      if event[:on] == :screen
        @screen_flash ||= begin
          image = Image.new(320, 240)
          image.fill_rect(0, 0, 320, 240, Color.new(255, 255, 255))
          sprite = Sprite::WithColor.new(@viewport)
          sprite.bitmap = Texture.new(320, 240)
          image.copy_to_bitmap(sprite.bitmap)
          image.dispose
          sprite.z = 10_000
          @viewport.sort_z if @viewport.respond_to?(:sort_z)
          sprite
        end
        @screen_flash.set_color([color[0], color[1], color[2], 1])
        @flash_screen = { start: event[:t], duration: (event[:duration] || 0.2).to_f, alpha: alpha }
      else
        on = event[:on] == :user ? @user : @target
        return unless on.respond_to?(:set_tone_to)

        @flash_on = { sprite: on, start: event[:t], duration: (event[:duration] || 0.2).to_f, alpha: alpha, color: color }
      end
    end

    def color_of(hex)
      value = hex.to_s.delete('#')
      value = 'ffffff' unless value.match?(/\A\h{6}\z/)
      [0, 2, 4].map { |i| value[i, 2].to_i(16) / 255.0 }
    end

    def update_effects(t)
      if (f = @flash_screen)
        r = (t - f[:start]) / [f[:duration], 0.01].max
        @screen_flash.opacity = r >= 1 ? 0 : (255 * f[:alpha] * (1 - r)).to_i
        @flash_screen = nil if r >= 1
      end
      if (f = @flash_on)
        r = (t - f[:start]) / [f[:duration], 0.01].max
        if r >= 1
          f[:sprite].reset_tone_status if f[:sprite].respond_to?(:reset_tone_status)
          @flash_on = nil
        else
          f[:sprite].set_tone_to(*f[:color], f[:alpha] * (1 - r))
        end
      end
      @moves.each_value do |m|
        sprite = m[:sprite]
        next unless sprite

        base = sprite.equal?(@user) ? (@origin_feet_user ||= [@user.x, @user.y]) : (@origin_feet_target ||= [@target.x, @target.y])
        r = (t - m[:start]) / [m[:duration].to_f, 0.01].max
        if r >= 1
          sprite.set_position(*base) unless m[:done]
          m[:done] = true
          next
        end
        if m[:type] == :shake
          power = (m[:power] || 4).to_f
          sprite.set_position(base[0] + Math.sin(r * Math::PI * 8) * power * (1 - r), base[1])
        else
          dx = (m[:x] || 0).to_f
          dy = (m[:y] || 0).to_f
          dx, dy = -dx, -dy if @reverse
          k = m[:back] == false ? r : Math.sin(r * Math::PI)
          sprite.set_position(base[0] + dx * k, base[1] + dy * k)
        end
      end
    end

    # Fin : tout est remis en place
    def finish
      @sprites.each { |s| s&.dispose }
      @sprites = nil
      @screen_flash&.bitmap&.dispose
      @screen_flash&.dispose
      @screen_flash = nil
      if @flash_on
        @flash_on[:sprite].reset_tone_status if @flash_on[:sprite].respond_to?(:reset_tone_status)
        @flash_on = nil
      end
      @user&.set_position(*@origin_feet_user) if @origin_feet_user
      @target&.set_position(*@origin_feet_target) if @origin_feet_target
      @hidden&.each { |sprite| sprite.visible = true unless sprite.disposed? }
      @hidden = nil
    end
  end
end

module Battle
  module MoveAnimation
    class << self
      alias studio_animations_get get
      # Les animations Studio sont relues (en test) avant chaque attaque
      def get(move, *animation_reason)
        StudioAnimations.register_all
        studio_animations_get(move, *animation_reason)
      end
    end
  end
end

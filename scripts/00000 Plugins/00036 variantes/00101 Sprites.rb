# Variantes : sprites des Pokémon Cuivrés, Argentés, Dorés, Prismatiques (recolorés en jeu) et Radiants (images de Studio)
module Variantes
  @textures = {}

  module_function

  # Texture d'une variante
  # @param kind [Symbol] :front, :back ou :icon
  # @param filename [String] nom du sprite normal (sans extension)
  # @param variant [Symbol]
  # @yieldreturn [Texture] sprite normal (pour Cuivré / Argenté / Doré / Prismatique)
  # @return [Texture, nil] nil si la variante n'a pas d'image (le sprite chromatique est alors utilisé)
  def texture(kind, filename, variant, &source)
    return radiant_texture(kind, filename) if variant == :radiant

    return tinted("#{kind}/#{filename}", variant, kind, &source)
  end

  # @param kind [Symbol]
  # @param filename [String]
  # @return [String] chemin du sprite Radiant
  def radiant_path(kind, filename)
    return "#{RADIANT_DIRS[kind]}/#{filename}.png"
  end

  # @param kind [Symbol]
  # @param filename [String]
  # @return [Texture, nil]
  def radiant_texture(kind, filename)
    path = radiant_path(kind, filename)
    cached = @textures[path]
    return cached if cached && !cached.disposed?
    return nil unless File.exist?(path)

    return @textures[path] = Texture.new(path)
  rescue StandardError => e
    log_error("Variantes : #{path} illisible (#{e.message})") if respond_to?(:log_error, true)
    return nil
  end

  # @param creature_id [Integer]
  # @param form [Integer]
  # @return [Boolean] si ce Pokémon a un sprite Radiant (de face)
  def radiant_available?(creature_id, form)
    filename = PFM::Pokemon.front_filename(creature_id, form, false, false, false)
    return File.exist?(radiant_path(:front, filename))
  rescue StandardError
    return false
  end

  # Sprite recoloré tout cuivre / tout argent / tout or (gardé en cache)
  # @param key [String]
  # @param variant [Symbol]
  # @param kind [Symbol] :front, :back ou :icon
  # @yieldreturn [Texture]
  # @return [Texture, nil]
  def tinted(key, variant, kind = :front)
    cache_key = "#{variant}/#{key}"
    cached = @textures[cache_key]
    return cached if cached && !cached.disposed?

    source = yield
    return nil unless source && !source.disposed?

    return @textures[cache_key] = variant == :prismatic ? prism(source, kind, key) : tint(source, gradient(variant))
  rescue StandardError => e
    log_error("Variantes : recoloration impossible de #{key} (#{e.message})") if respond_to?(:log_error, true)
    return nil
  end

  # Recolore une texture : chaque pixel prend la couleur du dégradé selon sa luminosité
  # (contraste étiré sur le sprite pour garder le relief, transparence conservée)
  # @param source [Texture]
  # @param stops [Array<Array<Integer>>]
  # @return [Texture]
  def tint(source, stops)
    image = Image.new(source.to_png, true)
    width = image.width
    height = image.height
    lums = []
    height.times do |y|
      width.times do |x|
        color = image.get_pixel(x, y)
        next if color.alpha == 0

        lums << luminance(color)
      end
    end
    unless lums.empty?
      sorted = lums.sort
      low = sorted[(sorted.size * 0.02).floor]
      high = sorted[[(sorted.size * 0.98).ceil, sorted.size - 1].min]
      high = low + 1 if high <= low
      height.times do |y|
        width.times do |x|
          color = image.get_pixel(x, y)
          next if color.alpha == 0

          t = ((luminance(color) - low) / (high - low)).clamp(0.0, 1.0)
          r, g, b = gradient_color(stops, t)
          image.set_pixel(x, y, Color.new(r, g, b, color.alpha))
        end
      end
    end
    texture = Texture.new(width, height)
    image.copy_to_bitmap(texture)
    image.dispose
    return texture
  end

  # Prismatique : arc-en-ciel en diagonale sur le Pokémon (relief gardé, contours noirs gardés),
  # halo lumineux autour et éclats de cristal (sprites de face et de dos)
  # @param source [Texture]
  # @param kind [Symbol] :front, :back ou :icon
  # @param key [String] (place des éclats, toujours la même pour un sprite)
  # @return [Texture]
  def prism(source, kind, key)
    image = Image.new(source.to_png, true)
    width = image.width
    height = image.height
    colors = Array.new(height) { |y| Array.new(width) { |x| image.get_pixel(x, y) } }
    opaque = colors.map { |row| row.map { |color| color.alpha > 0 } }
    points = []
    height.times { |y| width.times { |x| points << [x, y] if opaque[y][x] } }
    unless points.empty?
      xs = points.map(&:first)
      ys = points.map(&:last)
      x0 = xs.min
      y0 = ys.min
      bw = [xs.max - x0, 1].max.to_f
      bh = [ys.max - y0, 1].max.to_f
      sorted = points.map { |x, y| luminance(colors[y][x]) }.sort
      low = sorted[(sorted.size * 0.02).floor]
      high = sorted[[(sorted.size * 0.98).ceil, sorted.size - 1].min]
      high = low + 1 if high <= low
      hues = Array.new(height) { Array.new(width) }
      points.each do |x, y|
        color = colors[y][x]
        lum = luminance(color)
        t = ((lum - low) / (high - low)).clamp(0.0, 1.0)
        u = (x - x0) / bw * 0.55 + (y - y0) / bh * 0.45
        hue = (u * PRISM_CYCLES + t * 0.1 + 0.92) % 1.0
        hues[y][x] = hue
        next if lum < 40 # contours

        r, g, b = hsl_to_rgb(hue, 1.0 - 0.2 * t, 0.36 + 0.5 * t)
        image.set_pixel(x, y, Color.new(r, g, b, color.alpha))
      end
      prism_glow(image, opaque, hues, kind == :icon ? 1 : 2)
      prism_shards(image, opaque, key) unless kind == :icon
    end
    texture = Texture.new(width, height)
    image.copy_to_bitmap(texture)
    image.dispose
    return texture
  end

  # Nombre d'arcs-en-ciel sur la diagonale du Pokémon
  PRISM_CYCLES = 1.6
  # Opacité du halo (1 pixel, 2 pixels du Pokémon)
  PRISM_GLOW = [150, 60].freeze

  # Halo autour du Pokémon (couleur du pixel le plus proche, éclaircie)
  def prism_glow(image, opaque, hues, radius)
    height = opaque.size
    width = opaque.first.size
    height.times do |y|
      width.times do |x|
        next if opaque[y][x]

        best = nil
        (-radius..radius).each do |dy|
          (-radius..radius).each do |dx|
            xx = x + dx
            yy = y + dy
            next if xx < 0 || yy < 0 || xx >= width || yy >= height || !opaque[yy][xx]

            dist = [dx.abs, dy.abs].max
            best = [dist, hues[yy][xx]] if best.nil? || dist < best[0]
          end
        end
        next unless best

        r, g, b = hsl_to_rgb(best[1], 1.0, 0.82)
        image.set_pixel(x, y, Color.new(r, g, b, PRISM_GLOW[best[0] - 1] || 40))
      end
    end
  end

  # Éclat de cristal (losange de 3 x 5 pixels)
  PRISM_SHARD = [[1, 0], [0, 1], [1, 1], [2, 1], [0, 2], [1, 2], [2, 2], [0, 3], [1, 3], [2, 3], [1, 4]].freeze

  # Quelques éclats près du Pokémon (sans le toucher)
  def prism_shards(image, opaque, key)
    height = opaque.size
    width = opaque.first.size
    return if width < 16 || height < 16

    random = Random.new(key.to_s.bytes.inject(7) { |sum, byte| (sum * 31 + byte) % 2_147_483_647 })
    near = lambda do |x, y, x_from, x_to, y_from, y_to|
      ((x + x_from).clamp(0, width - 1)..(x + x_to).clamp(0, width - 1)).any? do |xx|
        ((y + y_from).clamp(0, height - 1)..(y + y_to).clamp(0, height - 1)).any? { |yy| opaque[yy][xx] }
      end
    end
    count = 0
    400.times do
      break if count >= 4

      x = random.rand(2..(width - 5))
      y = random.rand(2..(height - 7))
      next unless near.call(x, y, -6, 8, -6, 10)
      next if near.call(x, y, -3, 5, -3, 7)
      next if PRISM_SHARD.any? { |dx, dy| image.get_pixel(x + dx, y + dy).alpha > 0 }

      start = random.rand
      PRISM_SHARD.each do |dx, dy|
        r, g, b = hsl_to_rgb((start + dy * 0.08) % 1.0, 1.0, dx == 0 ? 0.9 : 0.7)
        image.set_pixel(x + dx, y + dy, Color.new(r, g, b, 220))
      end
      count += 1
    end
  end

  # @param h [Float] 0..1
  # @param s [Float] 0..1
  # @param l [Float] 0..1
  # @return [Array<Integer>]
  def hsl_to_rgb(h, s, l)
    return Array.new(3, (l * 255).round) if s <= 0

    q = l < 0.5 ? l * (1 + s) : l + s - l * s
    p = 2 * l - q
    [h + 1.0 / 3, h, h - 1.0 / 3].map do |t|
      t += 1 if t < 0
      t -= 1 if t > 1
      value = if t < 1.0 / 6 then p + (q - p) * 6 * t
              elsif t < 0.5 then q
              elsif t < 2.0 / 3 then p + (q - p) * (2.0 / 3 - t) * 6
              else p
              end
      (value * 255).round.clamp(0, 255)
    end
  end

  # @param color [Color]
  # @return [Float]
  def luminance(color)
    return color.red * 0.299 + color.green * 0.587 + color.blue * 0.114
  end

  # @param stops [Array<Array<Integer>>]
  # @param t [Float] 0..1
  # @return [Array<Integer>]
  def gradient_color(stops, t)
    return stops.first if stops.size == 1

    pos = t * (stops.size - 1)
    index = [pos.floor, stops.size - 2].min
    local = pos - index
    a = stops[index]
    b = stops[index + 1]
    return Array.new(3) { |i| (a[i] + (b[i] - a[i]) * local).round.clamp(0, 255) }
  end

  # Vide le cache (après une modification des réglages par exemple)
  def clear_cache
    @textures.each_value { |texture| texture.dispose unless texture.disposed? }
    @textures.clear
    @config = nil
  end
end

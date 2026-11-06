# Variantes : sprites des Pokémon Argentés, Dorés (recolorés en jeu) et Radiants (images de Studio)
module Variantes
  @textures = {}

  module_function

  # Texture d'une variante
  # @param kind [Symbol] :front, :back ou :icon
  # @param filename [String] nom du sprite normal (sans extension)
  # @param variant [Symbol]
  # @yieldreturn [Texture] sprite normal (pour Argenté / Doré)
  # @return [Texture, nil] nil si la variante n'a pas d'image (le sprite chromatique est alors utilisé)
  def texture(kind, filename, variant, &source)
    return radiant_texture(kind, filename) if variant == :radiant

    return tinted("#{kind}/#{filename}", variant, &source)
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

  # Sprite recoloré tout argent / tout or (gardé en cache)
  # @param key [String]
  # @param variant [Symbol]
  # @yieldreturn [Texture]
  # @return [Texture, nil]
  def tinted(key, variant)
    cache_key = "#{variant}/#{key}"
    cached = @textures[cache_key]
    return cached if cached && !cached.disposed?

    source = yield
    return nil unless source && !source.disposed?

    return @textures[cache_key] = tint(source, gradient(variant))
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

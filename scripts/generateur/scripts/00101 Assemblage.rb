# Générateur de personnages : assemblage des pièces (calques + couleurs libres)
module Generateur
  @textures = {}

  module_function

  # Pièce d'un sprite pour un choix ({ 'key', 'color' }) -> entrée ou nil
  # @param kind [String]
  # @param cat [String]
  # @param gender [String]
  # @param choice [Hash]
  # @return [Hash, nil]
  def resolve(kind, cat, gender, choice)
    return nil unless choice

    list = entries(kind).select { |e| e['cat'] == cat && ok_gender?(e, gender) }
    same = list.select { |e| e['key'] == choice['key'] }
    if same.empty?
      return nil unless %w[hair base].include?(cat) && list.first

      same = list.select { |e| e['key'] == list.first['key'] }
    end
    same = same.sort_by { |e| e['gender'] == gender ? 0 : 1 }
    return same.find { |e| e['color'] == choice['color'] } || same.find { |e| e['color'].to_s.empty? } || same.first
  end

  # Calques d'un sprite : [[fichier, couleur libre ou nil], …]
  # @param kind [String]
  # @param spec [Hash]
  # @return [Array<Array>]
  def layers(kind, spec)
    gender = spec['gender']
    out = []
    LAYERS.each do |cat|
      next if kind == 'back' && cat == 'bottom' # le dos n'a qu'un vêtement

      choice = cat == 'base' ? { 'key' => spec['skin'], 'color' => '' } : spec[cat]
      next unless choice

      entry = resolve(kind, cat, gender, choice)
      next unless entry

      out << [entry['file'], cat == 'base' ? spec['skinTint'] : choice['tint']]
    end
    return out
  end

  # Image assemblée d'un sprite
  # @param kind [String]
  # @param spec [Hash]
  # @return [Image, nil]
  def compose_image(kind, spec)
    result = nil
    layers(kind, spec).each do |file, tint|
      path = "#{PARTS_DIR}/#{file}.png"
      next unless File.exist?(path)

      img = Image.new(path)
      tint_image(img, tint) if tint && !tint.to_s.empty?
      result ||= Image.new(img.width, img.height)
      result.blt(0, 0, img, img.rect)
      img.dispose
    end
    return result if result.nil? || kind != 'back'

    # dos : images côte à côte -> les unes sous les autres (format PSDK)
    fw = result.width / BACK_FRAMES
    strip = Image.new(fw, result.height * BACK_FRAMES)
    BACK_FRAMES.times { |i| strip.blt(0, i * result.height, result, Rect.new(i * fw, 0, fw, result.height)) }
    result.dispose
    return strip
  rescue StandardError => e
    log_error("Générateur : assemblage impossible (#{e.message})") if respond_to?(:log_error, true)
    return nil
  end

  # Texture assemblée (sans cache)
  # @return [Texture, nil]
  def compose_texture(kind, spec)
    img = compose_image(kind, spec)
    return nil unless img

    texture = Texture.new(img.width, img.height)
    img.copy_to_bitmap(texture)
    img.dispose
    return texture
  end

  # Texture du personnage du joueur (gardée en cache)
  # @param kind [String]
  # @return [Texture, nil]
  def texture(kind)
    current = spec
    return nil unless current

    cached = @textures[kind]
    return cached if cached && !cached.disposed?

    return @textures[kind] = compose_texture(kind, current)
  end

  # Oublie les textures (le personnage a changé) ; elles ne sont pas libérées tout de suite (encore affichées)
  def clear_textures
    @textures = {}
  end

  # --- Couleur libre : la pièce prend la teinte choisie, en gardant ses ombres, ses reflets et ses contours ---
  # @param img [Image]
  # @param hex [String] "#rrggbb"
  def tint_image(img, hex)
    value = hex.to_s.delete('#')
    return unless value.match?(/\A\h{6}\z/)

    th, ts, tl = rgb_to_hsl(value[0, 2].hex, value[2, 2].hex, value[4, 2].hex)
    width = img.width
    height = img.height
    count = 0
    sum_s = 0.0
    sum_l = 0.0
    colors = {}
    height.times do |y|
      width.times do |x|
        c = img.get_pixel(x, y)
        next if c.alpha == 0

        key = (c.red << 16) | (c.green << 8) | c.blue
        hsl = colors[key] ||= rgb_to_hsl(c.red, c.green, c.blue)
        next if hsl[2] < OUTLINE_L

        count += 1
        sum_s += hsl[1]
        sum_l += hsl[2]
      end
    end
    return if count == 0

    ms = sum_s / count
    ml = sum_l / count
    mapped = {}
    height.times do |y|
      width.times do |x|
        c = img.get_pixel(x, y)
        next if c.alpha == 0

        key = (c.red << 16) | (c.green << 8) | c.blue
        _h, s, l = colors[key]
        next if l < OUTLINE_L

        r, g, b = mapped[key] ||= hsl_to_rgb(th, ms > 0.04 ? [s * ts / ms, 1.0].min : ts, (l + tl - ml).clamp(0.0, 1.0))
        img.set_pixel(x, y, Color.new(r, g, b, c.alpha))
      end
    end
  end

  # @return [Array<Float>] teinte (degrés), saturation, luminosité
  def rgb_to_hsl(r, g, b)
    r /= 255.0
    g /= 255.0
    b /= 255.0
    max = [r, g, b].max
    min = [r, g, b].min
    l = (max + min) / 2
    return [0.0, 0.0, l] if max == min

    d = max - min
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    h = if max == r then (g - b) / d + (g < b ? 6 : 0)
        elsif max == g then (b - r) / d + 2
        else (r - g) / d + 4
        end
    return [h * 60, s, l]
  end

  # @return [Array<Integer>]
  def hsl_to_rgb(hue, sat, l)
    hue = (hue % 360) / 360.0
    return Array.new(3, (l * 255).round.clamp(0, 255)) if sat <= 0

    q = l < 0.5 ? l * (1 + sat) : l + sat - l * sat
    p = 2 * l - q
    [hue + 1.0 / 3, hue, hue - 1.0 / 3].map do |t|
      t += 1 if t < 0
      t -= 1 if t > 1
      v = if t < 1.0 / 6 then p + (q - p) * 6 * t
          elsif t < 0.5 then q
          elsif t < 2.0 / 3 then p + (q - p) * (2.0 / 3 - t) * 6
          else p
          end
      (v * 255).round.clamp(0, 255)
    end
  end

  # --- Noms utilisés par le jeu -------------------------------------------------
  # @param filename [String]
  # @return [Boolean] charset du joueur assemblé (pj_joueur_m_walk…)
  def charset_name?(filename)
    return filename.to_s.start_with?("#{CHARSET}_") && !spec.nil?
  end

  # @param filename [String]
  # @return [Texture, nil]
  def charset_texture(filename)
    return nil unless charset_name?(filename)

    suffix = filename.to_s.sub(/\A#{CHARSET}_[mf]_?/, '')
    return texture(SUFFIX_KIND[suffix] || 'walk')
  end

  # Dresseur du joueur : « pj_joueur » (dos, en combat) et « pj_joueur_front » (face)
  # @return [Texture, nil]
  def battler_texture(filename)
    return nil if spec.nil?

    case filename.to_s
    when CHARSET then texture('back')
    when "#{CHARSET}_front" then texture('front')
    end
  end
end

# Les images du joueur viennent du générateur
module RPG
  module Cache
    class << self
      alias pj_gen_character character
      alias pj_gen_character_exist? character_exist?
      alias pj_gen_battler battler
      alias pj_gen_battler_exist? battler_exist?

      def character(filename, hue = 0)
        return Generateur.charset_texture(filename) || pj_gen_character(filename, hue) if Generateur.charset_name?(filename)

        return pj_gen_character(filename, hue)
      end

      def character_exist?(filename)
        return true if Generateur.charset_name?(filename)

        return pj_gen_character_exist?(filename)
      end

      def battler(filename, hue = 0)
        return Generateur.battler_texture(filename) || pj_gen_battler(filename, hue) if Generateur.battler_texture_name?(filename)

        return pj_gen_battler(filename, hue)
      end

      def battler_exist?(filename)
        return true if Generateur.battler_texture_name?(filename)

        return pj_gen_battler_exist?(filename)
      end
    end
  end
end

module Generateur
  module_function

  # @return [Boolean]
  def battler_texture_name?(filename)
    return !spec.nil? && [CHARSET, "#{CHARSET}_front"].include?(filename.to_s)
  end
end

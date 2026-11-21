# Icône PSS : assemblage de l'image (les pièces de 40x40 sont empilées, aucun fichier n'est écrit)
module IconePss
  module_function

  # Image assemblée d'une icône
  # @param spec [Hash] réglage (celui du joueur si omis)
  # @return [Image, nil]
  def compose_image(spec = self.spec)
    return nil unless spec && available?

    result = Image.new(SIZE, SIZE)
    layers(fix_spec(Marshal.load(Marshal.dump(spec)))).each do |file|
      path = "#{PIECES_DIR}/#{file}.png"
      next unless File.exist?(path)

      img = Image.new(path)
      result.blt(0, 0, img, img.rect)
      img.dispose
    end
    return result
  rescue StandardError => e
    log_error("Icône PSS : assemblage impossible (#{e.message})") if respond_to?(:log_error, true)
    return nil
  end

  # Texture assemblée (sans cache : à libérer par l'appelant)
  # @param spec [Hash] réglage (celui du joueur si omis)
  # @return [Texture, nil]
  def compose_texture(spec = self.spec)
    img = compose_image(spec)
    return nil unless img

    texture = Texture.new(img.width, img.height)
    img.copy_to_bitmap(texture)
    img.dispose
    return texture
  end

  # Texture de l'icône du joueur (gardée en cache)
  # @return [Texture, nil]
  def texture
    current = spec
    return nil unless current

    @texture = nil if @texture&.disposed?
    return @texture ||= compose_texture(current)
  end

  # Oublie la texture (l'icône a changé) ; elle n'est pas libérée tout de suite (encore affichée)
  def clear_textures
    @texture = nil
  end
end

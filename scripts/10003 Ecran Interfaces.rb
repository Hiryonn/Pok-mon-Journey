# encoding: utf-8
# Interfaces pleine largeur : le fond, la barre de boutons et les boutons de UI::GenericBase (chargement, équipe,
# carte dresseur, options…) occupent toute la largeur de l'écran au lieu d'un cadre 320x240.
# Le contenu propre à chaque interface reste centré. Voir 10002 Ecran.rb pour le cadre.
module Ecran
  module_function

  # Étire horizontalement un fond qui défile (origine animée de 16 px) pour couvrir tout l'écran
  # @param sprite [Sprite]
  def elargir_fond(sprite, vp = nil)
    bmp = sprite.bitmap
    return unless bmp

    sprite.x = bord_gauche(vp || (sprite.respond_to?(:viewport) ? sprite.viewport : nil))
    sprite.zoom_x = logique_largeur / [bmp.width - 16.0, 1].max
    sprite.zoom_y = [BASE_HAUTEUR / [bmp.height - 16.0, 1].max, 1].max
  end

  # Étire horizontalement une barre (image pensée pour 320 px de large)
  # @param sprite [Sprite]
  def elargir_barre(sprite, vp = nil)
    bmp = sprite.bitmap
    return unless bmp

    sprite.x = bord_gauche(vp || (sprite.respond_to?(:viewport) ? sprite.viewport : nil))
    sprite.zoom_x = logique_largeur / bmp.width.to_f
  end

  # Garde la plaque centrale d'un bandeau (colonnes a à b) et étire de chaque côté les colonnes unies pour couvrir l'écran
  # @param sprite [Sprite] bandeau d'une image pensée pour 320 px de large
  # @param a [Integer] début de la plaque centrale
  # @param b [Integer] fin de la plaque centrale
  # @return [Array<Sprite>] sprites ajoutés (à supprimer avec la scène)
  def elargir_plaque(sprite, a, b)
    bmp = sprite.bitmap
    return [] unless bmp

    largeur_image = bmp.width
    hauteur = bmp.height
    bord = bord_gauche(sprite.viewport)
    fin = bord + logique_largeur
    plaque = b - a
    px = bord == 0 ? (logique_largeur - plaque) / 2 : a
    sprite.src_rect.set(a, 0, plaque, hauteur)
    sprite.x = px
    gauche = Sprite.new(sprite.viewport)
    gauche.bitmap = bmp
    gauche.src_rect.set(0, 0, a, hauteur)
    gauche.set_position(bord, sprite.y)
    gauche.zoom_x = (px - bord) / a.to_f
    droite = Sprite.new(sprite.viewport)
    droite.bitmap = bmp
    droite.src_rect.set(b, 0, largeur_image - b, hauteur)
    droite.set_position(px + plaque, sprite.y)
    droite.zoom_x = (fin - px - plaque) / (largeur_image - b).to_f
    [gauche, droite].each { |autre| autre.z = sprite.z }
    return [gauche, droite]
  end

  # Image élargie : deux bords conservés tels quels (colonnes 0..a et b..fin) et un milieu uniforme étiré
  # @param nom [String] image dans graphics/interface/
  # @param a [Integer] largeur du bord gauche conservé
  # @param b [Integer] début du bord droit conservé
  # @param largeur [Integer] largeur voulue
  # @param cache [Symbol] dossier du cache (:interface, :pokedex…)
  # @return [Bitmap] (mis en cache ; ne pas le détruire)
  def tranches(nom, a, b, largeur, cache = :interface)
    @tranches ||= {}
    cle = [nom, a, b, largeur, cache]
    return @tranches[cle] if @tranches[cle] && !@tranches[cle].disposed?

    source = RPG::Cache.public_send(cache, nom)
    return source if largeur <= source.width

    src = Image.new(source.to_png, true)
    sw = src.width
    sh = src.height
    img = Image.new(largeur, sh)
    milieu = largeur - a - (sw - b)
    img.blt(0, 0, src, Rect.new(0, 0, a, sh))
    img.stretch_blt(Rect.new(a, 0, milieu, sh), src, Rect.new(a, 0, b - a, sh))
    img.blt(a + milieu, 0, src, Rect.new(b, 0, sw - b, sh))
    bitmap = Bitmap.new(largeur, sh)
    img.copy_to_bitmap(bitmap)
    img.dispose
    src.dispose
    return @tranches[cle] = bitmap
  end

  # Image composée en pleine largeur à partir de morceaux d'une image 320 px
  # @param nom [String] image source
  # @param cache [Symbol] dossier du cache
  # @param largeur [Integer] largeur finale
  # @param morceaux [Array<Array>] [dx, dy, dl, dh, sx, sy, sl, sh] : copie tel quel si dl == sl, étire sinon
  # @return [Bitmap] (mis en cache ; ne pas le détruire)
  def composer(nom, cache, largeur, morceaux)
    @composes ||= {}
    cle = [nom, cache, largeur]
    return @composes[cle] if @composes[cle] && !@composes[cle].disposed?

    source = RPG::Cache.public_send(cache, nom)
    src = Image.new(source.to_png, true)
    img = Image.new(largeur, source.height)
    morceaux.each do |dx, dy, dl, dh, sx, sy, sl, sh|
      next if dl <= 0 || dh <= 0

      if dl == sl && dh == sh
        img.blt(dx, dy, src, Rect.new(sx, sy, sl, sh))
      else
        img.stretch_blt(Rect.new(dx, dy, dl, dh), src, Rect.new(sx, sy, sl, sh))
      end
    end
    bitmap = Bitmap.new(largeur, source.height)
    img.copy_to_bitmap(bitmap)
    img.dispose
    src.dispose
    return @composes[cle] = bitmap
  end

  # Position de la souris dans le repère 320x240 de l'interface
  # @param vp [Viewport, nil] viewport de la scène
  # @return [Array(Integer, Integer)]
  def souris(vp)
    return vp.translate_mouse_coords(Mouse.x, Mouse.y) if vp.respond_to?(:translate_mouse_coords) && cadre?(vp)

    return Mouse.x, Mouse.y
  end

  # Répartit n éléments de largeur donnée sur toute la largeur de l'écran
  # @param index [Integer]
  # @param total [Integer]
  # @param largeur_element [Integer]
  # @return [Integer] x logique
  def repartir(index, total, largeur_element, vp = nil)
    case_largeur = logique_largeur / total.to_f
    return (bord_gauche(vp) + case_largeur * index + (case_largeur - largeur_element) / 2.0).round
  end

  # Ajoute la pleine largeur à UI::GenericBase
  module GenericBaseLarge
    private

    def create_background
      super
      Ecran.elargir_fond(@background, @viewport) if Ecran.cadre?(@viewport)
    end

    def create_button_background
      super
      Ecran.elargir_barre(@button_background, @viewport) if Ecran.cadre?(@viewport)
    end

    def create_control_button
      super
      return unless Ecran.cadre?(@viewport)
      return if respond_to?(:boutons_deja_places?, true) && boutons_deja_places?

      @ctrl.each_with_index do |button, index|
        button.set_position(Ecran.repartir(index, @ctrl.size, 76, @viewport), button.y)
      end
    end
  end

  # Écran de chargement : le bandeau du haut couvre toute la largeur (la plaque « LOAD » reste intacte)
  module LoadLarge
    private

    def create_frame
      super
      return unless Ecran.cadre?(@viewport)

      add_disposable(*Ecran.elargir_plaque(@frame, 80, 240))
    end
  end
end

UI::GenericBase.prepend(Ecran::GenericBaseLarge) if defined?(UI::GenericBase) && !UI::GenericBase.include?(Ecran::GenericBaseLarge)
GamePlay::Load.prepend(Ecran::LoadLarge) if defined?(GamePlay::Load) && !GamePlay::Load.include?(Ecran::LoadLarge)

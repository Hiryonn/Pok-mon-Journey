# encoding: utf-8
# Écran 640×360 : les interfaces écrites pour 320×240 sont posées dans un cadre centré (même code, même coordonnées),
# en attendant d'être refaites en pleine largeur. Avec un écran de 320×240, le cadre est l'écran entier : rien ne change.
#
#   Ecran.viewport(z)                  viewport de la taille d'une ancienne interface, centré à l'écran
#   Ecran.viewport(z, fond: true)      idem, avec un fond noir sur tout l'écran (supprimé avec le viewport)
#   Ecran.largeur / Ecran.hauteur      taille réelle de l'écran
#   Ecran.decalage_x / Ecran.decalage_y   position du coin du cadre
module Ecran
  BASE_LARGEUR = 320
  BASE_HAUTEUR = 240

  module_function

  # @return [Integer]
  def largeur
    return Graphics.width
  end

  # @return [Integer]
  def hauteur
    return Graphics.height
  end

  # @return [Boolean] vrai si l'écran est plus grand qu'une ancienne interface
  def grand?
    return largeur > BASE_LARGEUR || hauteur > BASE_HAUTEUR
  end

  # @return [Integer]
  def decalage_x
    return [(largeur - BASE_LARGEUR) / 2, 0].max
  end

  # @return [Integer]
  def decalage_y
    return [(hauteur - BASE_HAUTEUR) / 2, 0].max
  end

  # @param z [Integer]
  # @param fond [Boolean] fond noir derrière le cadre
  # @return [Viewport]
  def viewport(z, fond: false)
    vp = Viewport.create(:main, z)
    vp.rect.set(decalage_x, decalage_y, BASE_LARGEUR, BASE_HAUTEUR) if grand?
    attacher_fond(vp, z) if fond && grand?
    return vp
  end

  # Viewport plein écran rempli de noir (se supprime avec le viewport donné)
  def attacher_fond(vp, z)
    fond_vp = Viewport.create(:main, z - 1)
    sprite = Sprite.new(fond_vp)
    sprite.bitmap = Bitmap.new(largeur, hauteur)
    sprite.bitmap.fill_rect(0, 0, largeur, hauteur, Color.new(0, 0, 0))
    original = vp.method(:dispose)
    vp.define_singleton_method(:dispose) do
      sprite.dispose unless sprite.disposed?
      fond_vp.dispose unless fond_vp.disposed?
      original.call
    end
  rescue StandardError
    nil
  end
end

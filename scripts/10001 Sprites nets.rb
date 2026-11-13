# encoding: utf-8
# Sprites des évents nets pendant les déplacements.
#
# Avec la carte en tuiles de 16 px (Yuki::Tilemap16px, zoom 0,5), PSDK cale la carte sur des pixels entiers
# mais place les évents (PNJ, joueur, ombres) à la demi-case de pixel près (screen_x * 0,5). Pendant que la
# caméra défile, un évent se retrouve donc souvent sur un demi-pixel : l'image est rééchantillonnée et ses
# contours paraissent plus épais, puis redeviennent fins à l'arrêt. On cale ici les évents sur les mêmes
# pixels entiers que la carte (même arrondi que Yuki::Tilemap#update_position).
class Sprite_Character
  alias pj_sharp_update_position update_position
  # @return [Boolean]
  def update_position
    result = pj_sharp_update_position
    if @tile_zoom && @tile_zoom < 1
      set_position(x.floor, y.floor)
      @reflection&.set_position(x, y + ((@character.z - 1) * 32 * @tile_zoom).floor)
    end
    return result
  end

  alias pj_sharp_update_shadow update_shadow
  def update_shadow
    pj_sharp_update_shadow
    return unless @tile_zoom && @tile_zoom < 1 && @shadow

    @shadow.x = @shadow.x.floor
    @shadow.y = @shadow.y.floor
  end
end

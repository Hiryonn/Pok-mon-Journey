# -*- coding: utf-8 -*-
"""Pokédex Horizon : graphismes de la page Habitat (carte des lieux où vit le Pokémon).

Fabrique, à partir de graphics/pokedex/pe/adv_data.png (même style que les pages Données / Tâches) :
  graphics/pokedex/pe/habitat_bg.png      fond 320x240 : bandeau, panneau d'infos à gauche, fond du panneau carte, barre du bas
  graphics/pokedex/pe/habitat_frame.png   bord du panneau carte (posé au-dessus de la carte, intérieur transparent)
  graphics/pokedex/pe/habitat_unknown.png cadre « Zone inconnue »

Usage : python tools/pokedex/build_habitat.py   (depuis la racine du projet)
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PE = os.path.join(ROOT, 'graphics', 'pokedex', 'pe')

# Géométrie (à garder identique à scripts/interface_horizon/.../009 Habitat.rb)
LEFT_PANEL = (2, 24, 95, 211)      # x0, y0, x1, y1 (exclus)
MAP_PANEL = (98, 24, 318, 211)
MAP_RECT = (103, 29, 210, 177)     # x, y, largeur, hauteur de la carte
PLATES = [(6, 112), (6, 146)]      # bandeaux « Région » et « Lieu » (15 px : place pour les accents)
PLATE_W = 78

FILL = (229, 242, 249, 255)
LINE = (202, 231, 244, 255)


def nine_slice(src, size, c=8):
    """Cadre arrondi du panneau gauche de adv_data.png étiré à la taille size.

    Les coins, bords et le fond sont pris à des endroits sans contenu (le coin haut gauche, où commence le bandeau
    de titre, est le miroir du coin haut droit).
    """
    w, h = size
    out = Image.new('RGBA', (w, h))
    tr = src.crop((148, 24, 156, 32))
    corners = {
        (0, 0): tr.transpose(Image.FLIP_LEFT_RIGHT), (w - c, 0): tr,
        (0, h - c): src.crop((2, 147, 10, 155)), (w - c, h - c): src.crop((148, 147, 156, 155)),
    }
    fill = src.getpixel((130, 140))
    out.paste(Image.new('RGBA', (w - 2 * c, h - 2 * c), fill), (c, c))
    out.paste(src.crop((130, 24, 131, 32)).resize((w - 2 * c, c), Image.NEAREST), (c, 0))
    out.paste(src.crop((130, 147, 131, 155)).resize((w - 2 * c, c), Image.NEAREST), (c, h - c))
    out.paste(src.crop((2, 140, 10, 141)).resize((c, h - 2 * c), Image.NEAREST), (0, c))
    out.paste(src.crop((148, 140, 156, 141)).resize((c, h - 2 * c), Image.NEAREST), (w - c, c))
    for pos, img in corners.items():
        out.paste(img, pos)
    return out


def plate(src, width):
    """Bandeau de titre bleu (bord droit en biais) de la largeur demandée."""
    base = src.crop((6, 28, 122, 41))  # 116x13, biais à droite (fond du panneau autour)
    left = base.crop((0, 0, 40, 13))
    mid = base.crop((40, 0, 41, 13)).resize((max(width - 60, 1), 13), Image.NEAREST)
    right = base.crop((96, 0, 116, 13))
    out = Image.new('RGBA', (width, 13))
    out.paste(left, (0, 0))
    out.paste(mid, (40, 0))
    out.paste(right, (width - 20, 0))
    # 2 lignes de plus en haut (le biais continue) : les majuscules accentuées (RÉGION) tiennent dans le bandeau
    tall = Image.new('RGBA', (width, 15))
    top = out.crop((0, 0, width - 1, 1))
    tall.paste(top, (1, 0))
    tall.paste(Image.new('RGBA', (1, 1), out.getpixel((0, 0))), (0, 0))
    tall.paste(top, (1, 1))
    tall.paste(Image.new('RGBA', (1, 1), out.getpixel((0, 0))), (0, 1))
    tall.paste(out, (0, 2))
    return tall


def main():
    src = Image.open(os.path.join(PE, 'adv_data.png')).convert('RGBA')

    bg = Image.new('RGBA', (320, 240))
    # fond quadrillé (colonne de bord étirée), bandeau du haut et barre du bas
    bg.paste(src.crop((0, 22, 1, 214)).resize((320, 192), Image.NEAREST), (0, 22))
    bg.paste(src.crop((0, 0, 320, 22)), (0, 0))
    bg.paste(src.crop((0, 214, 320, 240)), (0, 214))

    x0, y0, x1, y1 = LEFT_PANEL
    left = nine_slice(src, (x1 - x0, y1 - y0))
    bg.alpha_composite(left, (x0, y0))
    # socle clair sous le Pokémon
    ImageDraw.Draw(bg).ellipse((19, 97, 79, 109), fill=(224, 240, 248, 255), outline=LINE)
    for px, py in PLATES:
        bg.alpha_composite(plate(src, PLATE_W), (px, py))

    x0, y0, x1, y1 = MAP_PANEL
    frame = Image.new('RGBA', (320, 240))
    frame.alpha_composite(nine_slice(src, (x1 - x0, y1 - y0)), (x0, y0))
    mx, my, mw, mh = MAP_RECT
    d = ImageDraw.Draw(frame)
    d.rectangle((mx - 1, my - 1, mx + mw, my + mh), outline=LINE)
    # le fond reçoit le panneau entier (couleur sous les cartes plus petites que la zone)
    bg.alpha_composite(frame)
    ImageDraw.Draw(bg).rectangle((mx, my, mx + mw - 1, my + mh - 1), fill=FILL)
    # le cadre posé sur la carte : intérieur transparent, petits coins arrondis
    d.rectangle((mx, my, mx + mw - 1, my + mh - 1), fill=(0, 0, 0, 0))
    for cx, cy in ((mx, my), (mx + mw - 1, my), (mx, my + mh - 1), (mx + mw - 1, my + mh - 1)):
        frame.putpixel((cx, cy), LINE)

    bg.save(os.path.join(PE, 'habitat_bg.png'))
    frame.save(os.path.join(PE, 'habitat_frame.png'))

    # Cadre « Zone inconnue » : bandeau bleu arrondi, liseré clair
    w, h = 140, 24
    box = Image.new('RGBA', (w, h))
    d = ImageDraw.Draw(box)
    d.rounded_rectangle((0, 0, w - 1, h - 1), 5, fill=(255, 255, 255, 255))
    d.rounded_rectangle((1, 1, w - 2, h - 2), 4, fill=(84, 127, 165, 255))
    d.rectangle((3, h - 5, w - 4, h - 4), fill=(97, 189, 227, 255))
    d.rectangle((3, 2, w - 4, 2), fill=(110, 150, 186, 255))
    box.save(os.path.join(PE, 'habitat_unknown.png'))
    print('habitat_bg.png, habitat_frame.png, habitat_unknown.png écrits dans', PE)


if __name__ == '__main__':
    main()

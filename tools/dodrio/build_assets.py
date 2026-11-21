# Cueillette Dodrio : images du mini-jeu d'après la planche de Rouge Feu / Vert Feuille (source_frlg.png)
#
# Usage : python build_assets.py [dossier du projet]
#   graphics/interface/dodrio/
#     dodrio.png      6 images de 64x56 : repos, tête droite, tête du milieu, tête gauche, fatigué, raté
#     baies.png       3 baies de 8x9 (petite, moyenne, grosse)
#     ecrase.png      3 baies écrasées de 14x8
#     etoile.png      étincelle d'une baie attrapée (12x12)
#     cases.png       cases des ratés de 10x10 (jaune : reste, gris : vide, rouge : raté)
#     fond.png        terrain de jeu 320x240 (arbres, ciel, clôture)
#     fond_menu.png   fond clair des écrans d'accueil et de résultats (320x240)
#     panneau.png     panneau des textes (288x120)
#     colonne.png     repère de la colonne (24x4)
#     bandeau.png     bandeau du haut (score, ratés) 320x20
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..')
OUT = os.path.join(ROOT, 'graphics', 'interface', 'dodrio')
SHEET = Image.open(os.path.join(HERE, 'source_frlg.png')).convert('RGBA')
BGS = {(239, 255, 239), (230, 255, 255), (200, 200, 168)}
W, H = 320, 240


def save(im, name):
    im.save(os.path.join(OUT, name))
    print(name)


def cut(box):
    im = SHEET.crop(box)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][:3] in BGS:
                px[x, y] = (0, 0, 0, 0)
    return im


def strip(boxes, cw, ch, bottom=False):
    out = Image.new('RGBA', (cw * len(boxes), ch), (0, 0, 0, 0))
    for i, box in enumerate(boxes):
        piece = cut(box)
        x = i * cw + (cw - piece.width) // 2
        y = ch - piece.height if bottom else (ch - piece.height) // 2
        out.alpha_composite(piece, (x, y))
    return out


def sprites():
    # les images de la planche sont alignées sur le même corps : on garde la colonne x 0..64, pieds en bas
    bottoms = [(6, 56), (66, 120), (130, 184), (194, 248), (279, 312), (322, 376)]
    out = Image.new('RGBA', (64 * 6, 56), (0, 0, 0, 0))
    for i, (top, bottom) in enumerate(bottoms):
        piece = cut((0, top, 64, bottom))
        out.alpha_composite(piece, (i * 64, 56 - piece.height))
    save(out, 'dodrio.png')
    save(strip([(72, 5, 80, 14), (72, 21, 80, 30), (72, 37, 80, 46)], 8, 9), 'baies.png')
    save(strip([(69, 58, 83, 66), (69, 74, 83, 82), (69, 90, 83, 98)], 14, 8), 'ecrase.png')
    save(strip([(70, 100, 82, 112)], 12, 12), 'etoile.png')
    save(strip([(71, 151, 81, 161), (71, 167, 81, 177), (71, 183, 81, 193)], 10, 10), 'cases.png')


def playfield():
    left = SHEET.crop((68, 198, 308, 358))
    right = SHEET.crop((311, 198, 551, 358))
    sky = left.getpixel((200, 60))
    # 160 lignes -> 240 : on répète les troncs (lignes 44 à 84)
    def tall(panel):
        out = Image.new('RGBA', (panel.width, H), sky)
        out.alpha_composite(panel.crop((0, 0, panel.width, 84)), (0, 0))
        out.alpha_composite(panel.crop((0, 44, panel.width, 84)), (0, 84))
        out.alpha_composite(panel.crop((0, 44, panel.width, 84)), (0, 124))
        out.alpha_composite(panel.crop((0, 84, panel.width, 160)), (0, 164))
        return out
    lt, rt = tall(left), tall(right)
    bg = Image.new('RGBA', (W, H), sky)
    # bas du terrain : herbe et clôture du panneau de gauche (4 piquets de 24 px), sans le tronc derrière
    trunk = {(189, 189, 140), (173, 173, 132), (197, 197, 148), (156, 156, 132), (140, 140, 107), (230, 247, 255), (107, 156, 148), (74, 156, 123)}
    ground = left.crop((0, 100, 96, 160)).convert('RGBA')
    px = ground.load()
    for y in range(ground.height):
        for x in range(ground.width):
            if px[x, y][:3] in trunk:
                px[x, y] = (0, 0, 0, 0)
    for x in range(-24, W, 96):
        bg.alpha_composite(ground, (x, H - 60))
    def clear_sky(im):
        im = im.copy()
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                if px[x, y][:3] == sky[:3]:
                    px[x, y] = (0, 0, 0, 0)
        return im
    bg.alpha_composite(clear_sky(lt.crop((47, 0, 119, H))), (0, 0))
    bg.alpha_composite(clear_sky(rt.crop((120, 0, 192, H))), (W - 72, 0))
    save(bg, 'fond.png')


def menu_bg():
    full = SHEET.crop((330, 35, 570, 195))
    sky = full.getpixel((120, 60))
    # 240x160 -> 320x240 : colonnes du milieu (ciel, haie, clôture) et lignes du ciel répétées
    wide = Image.new('RGBA', (W, 160), sky)
    wide.alpha_composite(full.crop((0, 0, 120, 160)), (0, 0))
    wide.alpha_composite(full.crop((120, 0, 240, 160)), (W - 120, 0))
    middle = full.crop((88, 0, 120, 160))
    for x in range(120, W - 120, 32):
        wide.alpha_composite(middle, (x, 0))
    wide.alpha_composite(full.crop((120, 0, 240, 160)), (W - 120, 0))
    out = Image.new('RGBA', (W, H), sky)
    out.alpha_composite(wide.crop((0, 0, W, 70)), (0, 0))
    band = wide.crop((0, 50, W, 90))
    out.alpha_composite(band, (0, 70))
    out.alpha_composite(band, (0, 110))
    out.alpha_composite(wide.crop((0, 70, W, 160)), (0, 150))
    save(out, 'fond_menu.png')


def panel():
    im = Image.new('RGBA', (288, 120), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 287, 119), radius=8, fill=(255, 251, 238, 235), outline=(132, 98, 58, 255), width=2)
    d.rounded_rectangle((4, 4, 283, 115), radius=6, outline=(222, 197, 148, 255))
    save(im, 'panneau.png')
    c = Image.new('RGBA', (24, 4), (0, 0, 0, 0))
    ImageDraw.Draw(c).rounded_rectangle((0, 0, 23, 3), radius=2, fill=(255, 255, 255, 140))
    save(c, 'colonne.png')
    band = Image.new('RGBA', (W, 20), (40, 72, 64, 190))
    ImageDraw.Draw(band).line((0, 19, W - 1, 19), fill=(20, 40, 36, 220))
    save(band, 'bandeau.png')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    sprites()
    playfield()
    menu_bg()
    panel()

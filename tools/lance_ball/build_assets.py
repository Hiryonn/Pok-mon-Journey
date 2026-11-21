# Lance-Ball : images du mini-jeu d'après la planche du Poké Transfert de Noir / Blanc (source_bw.png)
#
# Usage : python build_assets.py [dossier du projet]
#   graphics/interface/lance_ball/
#     fond.png        terrain 320x240 (mer en haut, herbe)
#     lanceur.png     bras du lance-balle (vu de dessus)
#     balles.png      balles en vol : 6 images de 32x32 ; ligne 0 bleue, ligne 1 dorée
#     objets.png      6 images de 32x32 : Poké Ball, balle bleue, balle dorée, ombre, viseur, impact
#     cachettes.png   3 lignes de 4 images de 32x32 : buisson, feuillage d'arbre, tronc (la cachette tremble)
#     apparition.png  3 images de 32x32 : nuage rose (le Pokémon sort)
#     nuages.png      4 lignes de 5 images de 32x32 : fumée (raté), fumée étoilée, étoiles (capturé), nuage rose
#     cercles.png     6 images de 32x32 : ligne 0 cible rouge, ligne 1 onde bleue (impact au sol)
#     etoiles.png     4 images de 32x32 (étourdi)    zzz.png  4 images de 32x32 (endormi)
#     chiffres.png    10 chiffres de 16x32
#     texte_<nom>.png bandeaux anglais 128x32 (ready1..3, start, timeup, finish, record)
#     barre.png       bandeau du haut 320x20 (TIME, jauge vide) et jauge.png (jauge pleine 120x4)
#     cases.png       bandeau du bas (6 cases et SCORE) d'après l'écran du bas, panneau.png
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..')
OUT = os.path.join(ROOT, 'graphics', 'interface', 'lance_ball')
SHEET = Image.open(os.path.join(HERE, 'source_bw.png')).convert('RGBA')
CELL_BG = (56, 144, 184)
W, H = 320, 240


def save(im, name):
    im.save(os.path.join(OUT, name))
    print(name)


def key(im, colors):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][:3] in colors:
                px[x, y] = (0, 0, 0, 0)
    return im


def cell(x0, col, row):
    return key(SHEET.crop((x0 + col * 34, 2 + row * 34, x0 + col * 34 + 32, 2 + row * 34 + 32)), {CELL_BG})


def grid(x0, rows, cols):
    out = Image.new('RGBA', (32 * cols, 32 * len(rows)), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        for c in range(cols):
            out.alpha_composite(cell(x0, c, row), (c * 32, r * 32))
    return out


def sprites():
    save(grid(732, [0, 1], 6), 'balles.png')
    save(grid(518, [1], 6), 'objets.png')
    save(grid(518, [2, 3, 4], 4), 'cachettes.png')
    save(grid(518, [5], 3), 'apparition.png')
    save(grid(518, [6, 7, 8, 9], 5), 'nuages.png')
    save(grid(732, [2, 3], 6), 'cercles.png')
    save(grid(732, [4], 4), 'etoiles.png')
    save(grid(732, [5], 4), 'zzz.png')
    digits = Image.new('RGBA', (160, 32), (0, 0, 0, 0))
    for i in range(10):
        digits.alpha_composite(key(SHEET.crop((518 + i * 18, 2, 534 + i * 18, 34)), {CELL_BG}), (i * 16, 0))
    save(digits, 'chiffres.png')
    texts = {'ready1': (732, 206), 'ready2': (862, 206), 'ready3': (992, 206), 'start': (732, 240), 'timeup': (862, 240),
             'finish': (732, 274), 'record': (862, 274)}
    for name, (x, y) in texts.items():
        save(key(SHEET.crop((x, y, x + 128, y + 32)), {CELL_BG}), f'texte_{name}.png')


def field():
    src = SHEET.crop((260, 2, 516, 194))
    wide = Image.new('RGBA', (W, 192))
    wide.alpha_composite(src, (0, 0))
    wide.alpha_composite(src.crop((40, 0, 104, 192)), (256, 0))
    out = Image.new('RGBA', (W, H))
    out.alpha_composite(wide, (0, 0))
    out.alpha_composite(wide.crop((0, 96, W, 144)), (0, 192))
    save(out, 'fond.png')
    arms = key(SHEET.crop((280, 210, 496, 262)), {(64, 128, 112)})
    box = arms.getbbox()
    save(arms.crop(box), 'lanceur.png')


def hud():
    bar = Image.new('RGBA', (W, 20), (40, 40, 44, 235))
    d = ImageDraw.Draw(bar)
    d.line((0, 19, W - 1, 19), fill=(200, 208, 232, 255))
    label = SHEET.crop((26, 20, 56, 28))
    bar.alpha_composite(label, (4, 6))
    d.rectangle((38, 8, 159, 11), fill=(84, 84, 96, 255))
    save(bar, 'barre.png')
    gauge = Image.new('RGBA', (120, 4), (120, 232, 40, 255))
    ImageDraw.Draw(gauge).line((0, 0, 119, 0), fill=(176, 248, 104, 255))
    save(gauge, 'jauge.png')
    slots = SHEET.crop((2, 336, 258, 388))
    save(slots, 'cases.png')
    panel = Image.new('RGBA', (256, 150), (0, 0, 0, 0))
    d = ImageDraw.Draw(panel)
    d.rounded_rectangle((0, 0, 255, 149), radius=12, fill=(200, 208, 232, 245), outline=(40, 40, 44, 255), width=3)
    d.rounded_rectangle((8, 8, 247, 141), radius=8, fill=(104, 168, 200, 255), outline=(40, 40, 44, 255), width=2)
    save(panel, 'panneau.png')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    sprites()
    field()
    hud()

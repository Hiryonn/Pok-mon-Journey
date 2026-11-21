# Montures : dessine les images du plugin (couleurs de l'interface Horizon)
#
# Usage : python build_assets.py [dossier du projet]
#   graphics/interface/montures/ : roue des montures (fond, cases, curseur, panneau, descendre), appli Monture
#   (lignes, ligne choisie, étiquette « montée »), icônes des pouvoirs (pouvoirs.png : 12 icônes de 14 x 14)
import math
import os
import sys

from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', '..')
OUT = os.path.join(ROOT, 'graphics', 'interface', 'montures')
SLATE = (51, 71, 81, 255)
STEEL = (69, 103, 129, 255)
BLUE = (80, 126, 166, 255)
PALE = (229, 243, 250, 255)
WHITE = (250, 253, 254, 255)
GOLD = (255, 210, 90, 255)
POWERS = ['surf', 'waterfall', 'whirlpool', 'dive', 'strength', 'rock_smash', 'cut', 'rock_climb', 'headbutt',
          'flash', 'fly', 'search']
COLORS = {
    'surf': (70, 140, 220), 'waterfall': (60, 120, 200), 'whirlpool': (40, 100, 180), 'dive': (30, 70, 150),
    'strength': (190, 110, 60), 'rock_smash': (150, 110, 80), 'cut': (80, 160, 70), 'rock_climb': (130, 100, 70),
    'headbutt': (110, 140, 60), 'flash': (230, 180, 40), 'fly': (120, 170, 220), 'search': (170, 110, 180),
}


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name), optimize=True)


def big(size):
    """Dessin en 4x puis réduction (bords nets mais lissés)"""
    return Image.new('RGBA', (size[0] * 4, size[1] * 4), (0, 0, 0, 0))


def small(im, size):
    return im.resize(size, Image.LANCZOS)


def wheel():
    bg = Image.new('RGBA', (320, 240), (10, 20, 28, 120))
    ring = big((200, 200))
    d = ImageDraw.Draw(ring)
    d.ellipse((8, 8, 792, 792), fill=(51, 71, 81, 150), outline=(140, 180, 210, 255), width=8)
    d.ellipse((150, 150, 650, 650), outline=(110, 150, 180, 160), width=4)
    bg.alpha_composite(small(ring, (200, 200)), (60, 20))
    save(bg, 'roue_fond.png')
    cell = big((34, 34))
    d = ImageDraw.Draw(cell)
    d.ellipse((2, 2, 133, 133), fill=STEEL, outline=PALE, width=6)
    save(small(cell, (34, 34)), 'case.png')
    cur = big((40, 40))
    d = ImageDraw.Draw(cur)
    d.ellipse((4, 4, 155, 155), outline=GOLD, width=10)
    save(small(cur, (40, 40)), 'curseur.png')
    ride = big((40, 40))
    d = ImageDraw.Draw(ride)
    d.ellipse((4, 4, 155, 155), outline=(120, 220, 140, 255), width=8)
    save(small(ride, (40, 40)), 'montee.png')
    panel = big((120, 44))
    d = ImageDraw.Draw(panel)
    d.rounded_rectangle((0, 0, 479, 175), radius=40, fill=(51, 71, 81, 235), outline=(140, 180, 210, 255), width=6)
    save(small(panel, (120, 44)), 'panneau.png')
    # descendre : flèche vers le bas sur le sol
    foot = big((32, 32))
    d = ImageDraw.Draw(foot)
    d.polygon([(64, 24), (64, 64), (40, 64), (64, 92), (88, 64), (64, 64)], fill=WHITE)
    d.rectangle((52, 24, 76, 66), fill=WHITE)
    d.polygon([(64, 104), (30, 64), (52, 64), (52, 20), (76, 20), (76, 64), (98, 64)], fill=WHITE)
    d.rectangle((20, 108, 108, 116), fill=PALE)
    save(small(foot, (32, 32)), 'descendre.png')


def rows():
    for name, fill, edge in (('ligne', WHITE, STEEL), ('ligne_sel', (214, 236, 250, 255), BLUE)):
        im = Image.new('RGBA', (308, 44), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle((0, 0, 307, 43), radius=4, fill=edge)
        d.rounded_rectangle((1, 1, 306, 42), radius=3, fill=fill)
        if name == 'ligne_sel':
            d.rounded_rectangle((0, 0, 307, 43), radius=4, outline=BLUE, width=2)
        d.rounded_rectangle((3, 4, 38, 39), radius=3, fill=PALE, outline=STEEL)
        save(im, name + '.png')
    tag = Image.new('RGBA', (44, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(tag)
    d.rounded_rectangle((0, 0, 43, 13), radius=6, fill=(70, 160, 100, 255))
    save(tag, 'etiquette.png')


def icon(power):
    im = big((14, 14))
    d = ImageDraw.Draw(im)
    c = COLORS[power] + (255,)
    d.ellipse((0, 0, 55, 55), fill=c, outline=(255, 255, 255, 255), width=3)
    w = (255, 255, 255, 255)
    if power == 'surf':
        for y in (20, 34):
            d.arc((8, y - 8, 30, y + 8), 200, 340, fill=w, width=4)
            d.arc((26, y - 8, 48, y + 8), 200, 340, fill=w, width=4)
    elif power == 'waterfall':
        d.polygon([(28, 10), (14, 28), (22, 28), (22, 44), (34, 44), (34, 28), (42, 28)], fill=w)
    elif power == 'whirlpool':
        pts = [(28 + r * math.cos(a), 28 + r * math.sin(a)) for a, r in ((t / 6, 2 + t * 0.9) for t in range(0, 22))]
        d.line(pts, fill=w, width=4)
    elif power == 'dive':
        d.polygon([(28, 46), (14, 28), (22, 28), (22, 10), (34, 10), (34, 28), (42, 28)], fill=w)
    elif power == 'strength':
        d.rounded_rectangle((14, 18, 42, 42), radius=6, fill=w)
        for x in (18, 25, 32):
            d.line((x + 3, 18, x + 3, 28), fill=c, width=2)
    elif power == 'rock_smash':
        d.polygon([(12, 40), (18, 18), (32, 12), (44, 24), (42, 42)], fill=w)
        d.line((26, 14, 30, 28, 24, 40), fill=c, width=3)
    elif power == 'cut':
        d.ellipse((12, 14, 40, 34), fill=w)
        d.line((26, 34, 26, 46), fill=w, width=4)
        d.line((18, 24, 34, 24), fill=c, width=2)
    elif power == 'rock_climb':
        d.polygon([(8, 44), (22, 14), (30, 28), (36, 20), (48, 44)], fill=w)
    elif power == 'headbutt':
        d.ellipse((12, 8, 44, 34), fill=w)
        d.rectangle((24, 32, 32, 46), fill=w)
    elif power == 'flash':
        pts = []
        for k in range(10):
            a = -math.pi / 2 + k * math.pi / 5
            r = 20 if k % 2 == 0 else 9
            pts.append((28 + r * math.cos(a), 28 + r * math.sin(a)))
        d.polygon(pts, fill=w)
    elif power == 'fly':
        d.polygon([(8, 30), (28, 20), (48, 12), (40, 26), (48, 30), (30, 36), (14, 40)], fill=w)
    elif power == 'search':
        d.ellipse((12, 12, 34, 34), outline=w, width=5)
        d.line((32, 32, 44, 44), fill=w, width=6)
    return small(im, (14, 14))


def powers():
    strip = Image.new('RGBA', (14 * len(POWERS), 14), (0, 0, 0, 0))
    for i, p in enumerate(POWERS):
        strip.alpha_composite(icon(p), (i * 14, 0))
    save(strip, 'pouvoirs.png')


if __name__ == '__main__':
    wheel()
    rows()
    powers()
    print('Images des montures faites dans', OUT)

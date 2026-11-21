# Triple Triad : écran d'ouverture d'un booster, aux couleurs de l'interface Horizon (graphics/interface/triple_triad/)
#   python tools/triple_triad/build_booster_assets.py
# - booster_panel.png (300 x 178) : grand cadre clair avec des rayons de lumière partant du centre
# - booster_shadow.png (44 x 8) : ombre sous une carte
# - booster_new.png (52 x 12) : étiquette « Nouveau ! » (le texte est écrit par le jeu)
# - booster_flash.png (8 x 8) : éclair blanc agrandi quand le paquet s'ouvre
import math
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'graphics', 'interface', 'triple_triad')

LIGHT, SHEEN, PALE, SKY = (229, 243, 250), (250, 253, 254), (213, 238, 248), (145, 201, 247)
BLUE, STEEL, DEEP = (80, 126, 166), (69, 103, 129), (36, 52, 62)
GOLD, GOLD_D = (240, 192, 64), (168, 112, 24)


def panel():
    w, h = 300, 178
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), 8, fill=STEEL)
    d.rounded_rectangle((2, 2, w - 3, h - 3), 7, fill=SHEEN)
    d.rounded_rectangle((4, 4, w - 5, h - 5), 6, fill=LIGHT)
    # rayons : secteurs alternés plus clairs autour du centre
    rays = Image.new('L', (w, h), 0)
    rd = ImageDraw.Draw(rays)
    cx, cy, r = w / 2, h / 2, 260
    for i in range(16):
        a0 = math.radians(i * 22.5)
        a1 = math.radians(i * 22.5 + 11.25)
        rd.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=255)
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((4, 4, w - 5, h - 5), 6, fill=255)
    rays = Image.composite(rays, Image.new('L', (w, h), 0), mask)
    im.paste(PALE + (255,), (0, 0), rays)
    # halo au centre
    for k, col in ((70, PALE), (52, SHEEN)):
        d.ellipse((cx - k * 1.6, cy - k, cx + k * 1.6, cy + k), fill=col)
    # reflet en haut
    d.line((10, 5, w - 11, 5), fill=(255, 255, 255))
    return im


def shadow():
    im = Image.new('RGBA', (44, 8), (0, 0, 0, 0))
    ImageDraw.Draw(im).ellipse((0, 0, 43, 7), fill=STEEL + (90,))
    return im


def new_tag():
    im = Image.new('RGBA', (52, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 51, 11), 5, fill=GOLD_D)
    d.rounded_rectangle((1, 1, 50, 10), 4, fill=GOLD)
    d.line((4, 2, 47, 2), fill=(252, 228, 150))
    return im


def flash():
    return Image.new('RGBA', (8, 8), (255, 255, 255, 255))


def main():
    panel().save(os.path.join(OUT, 'booster_panel.png'))
    shadow().save(os.path.join(OUT, 'booster_shadow.png'))
    new_tag().save(os.path.join(OUT, 'booster_new.png'))
    flash().save(os.path.join(OUT, 'booster_flash.png'))
    print('Images écrites dans', OUT)


if __name__ == '__main__':
    main()

# Écran console de la carte : cadre de console portable avec une manette de chaque côté (dessin original)
#
# Usage : python build_console.py
#   graphics/interface/console/console_<thème>_<L>x<H>.png   un cadre par taille d'écran du jeu (640x360, 640x480, 480x360) :
#   manettes jusqu'aux bords ; écran transparent aux 3 / 4 de la largeur, rebord de 15 px en haut et en bas
#   (640x360 -> 480x330 en (80, 15))
# Thèmes : neon (bleu / rouge), gris, rouge, bleu, pastel (vert / rose), violet. Ne touche à aucune autre image.
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'graphics', 'interface', 'console')
SIZES = [(640, 360), (640, 480), (480, 360)]
# rebord de la console au-dessus et au-dessous de l'écran (même valeur que BORD dans scripts/10006 Ecran Console.rb)
BORD = 15
THEMES = {
    'neon': ((0, 166, 220), (255, 76, 72)),
    'gris': ((128, 128, 136), (128, 128, 136)),
    'rouge': ((214, 40, 52), (214, 40, 52)),
    'bleu': ((40, 92, 214), (40, 92, 214)),
    'pastel': ((116, 214, 156), (246, 140, 190)),
    'violet': ((136, 92, 214), (136, 92, 214)),
}


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c) + (255,)


def grip(d, box, color, left):
    x0, y0, x1, y1 = box
    r = 30
    d.rounded_rectangle(box, radius=r, fill=shade(color, 1))
    # coins côté console carrés
    if left:
        d.rectangle((x1 - r, y0, x1, y1), fill=shade(color, 1))
        d.line((x0 + r, y0 + 1, x1, y0 + 1), fill=shade(color, 1.25), width=2)
        d.line((x0 + 1, y0 + r, x0 + 1, y1 - r), fill=shade(color, 1.18), width=2)
        d.line((x0 + r, y1 - 1, x1, y1 - 1), fill=shade(color, 0.7), width=2)
    else:
        d.rectangle((x0, y0, x0 + r, y1), fill=shade(color, 1))
        d.line((x0, y0 + 1, x1 - r, y0 + 1), fill=shade(color, 1.25), width=2)
        d.line((x1 - 1, y0 + r, x1 - 1, y1 - r), fill=shade(color, 0.75), width=2)
        d.line((x0, y1 - 1, x1 - r, y1 - 1), fill=shade(color, 0.7), width=2)
    # rail entre la manette et la console
    rx = x1 - 3 if left else x0
    d.rectangle((rx, y0 + 4, rx + 3, y1 - 4), fill=(24, 24, 28, 255))


def stick(d, cx, cy, k=1.0):
    a, b, c = round(17 * k), round(13 * k), round(9 * k)
    d.ellipse((cx - a, cy - a, cx + a, cy + a), fill=(22, 22, 26, 255))
    d.ellipse((cx - b, cy - b, cx + b, cy + b), fill=(48, 48, 54, 255))
    d.ellipse((cx - c, cy - c - 1, cx + c, cy + c - 1), fill=(62, 62, 70, 255))
    d.arc((cx - b, cy - b, cx + b, cy + b), 200, 320, fill=(86, 86, 96, 255), width=2)


def buttons(d, cx, cy, gap=17, r=8):
    for dx, dy in ((0, -gap), (gap, 0), (0, gap), (-gap, 0)):
        x, y = cx + dx, cy + dy
        d.ellipse((x - r, y - r, x + r, y + r), fill=(22, 22, 26, 255))
        d.ellipse((x - r + 2, y - r + 1, x + r - 2, y + r - 3), fill=(52, 52, 58, 255))


def small_bar(d, cx, cy, plus):
    d.rectangle((cx - 6, cy - 1, cx + 6, cy + 1), fill=(22, 22, 26, 255))
    if plus:
        d.rectangle((cx - 1, cy - 6, cx + 1, cy + 6), fill=(22, 22, 26, 255))


def build(name, left_color, right_color, W, H):
    # écran aux 3 / 4 de la largeur, avec un rebord de BORD pixels en haut et en bas (640x360 -> 480x330 en (80, 15))
    sw, sh = W * 3 // 4, H - 2 * BORD
    sx, sy = (W - sw) // 2, BORD
    SCREEN = (sx, sy, sx + sw, sy + sh)
    gw = sx - 12  # largeur d'une manette (jusqu'au bord de la fenêtre)
    top, bottom = 2, H - 2
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # fond autour de la console
    for y in range(H):
        t = abs(y - H / 2) / (H / 2)
        c = int(30 - 14 * t)
        d.line((0, y, W, y), fill=(c, c, c + 6, 255))
    # manettes
    lx0, lx1 = sx - 6 - gw, sx - 6
    rx0, rx1 = W - sx + 6, W - sx + 6 + gw
    grip(d, (lx0, top, lx1, bottom), left_color, True)
    grip(d, (rx0, top, rx1, bottom), right_color, False)
    lc, rc = (lx0 + lx1) // 2 - 2, (rx0 + rx1) // 2 + 2
    span = bottom - top
    k = min(1.0, gw / 68)
    gap, br = round(17 * k), max(5, round(8 * k))
    stick(d, lc, top + span * 20 // 100, k)
    buttons(d, lc, top + span * 51 // 100, gap, br)
    small_bar(d, lx1 - 14, top + 18, False)
    yb = top + span * 82 // 100
    d.rectangle((lc - 6, yb - 6, lc + 6, yb + 6), fill=(22, 22, 26, 255))
    d.rectangle((lc - 4, yb - 4, lc + 4, yb + 4), fill=(52, 52, 58, 255))
    buttons(d, rc, top + span * 24 // 100, gap, br)
    stick(d, rc, top + span * 58 // 100, k)
    small_bar(d, rx0 + 14, top + 18, True)
    d.ellipse((rc - 6, yb - 6, rc + 6, yb + 6), fill=(22, 22, 26, 255))
    d.ellipse((rc - 4, yb - 4, rc + 4, yb + 4), fill=(52, 52, 58, 255))
    # console
    d.rectangle((lx1 - 2, top, rx0 + 2, bottom), fill=(44, 44, 50, 255))
    d.line((lx1 - 2, top + 1, rx0 + 2, top + 1), fill=(70, 70, 78, 255), width=2)
    d.line((lx1 - 2, bottom - 1, rx0 + 2, bottom - 1), fill=(28, 28, 32, 255), width=2)
    d.rectangle((lx1 - 2, 0, rx0 + 2, H), fill=(44, 44, 50, 255))
    d.line((lx1 - 2, 1, rx0 + 2, 1), fill=(70, 70, 78, 255), width=2)
    d.line((lx1 - 2, H - 2, rx0 + 2, H - 2), fill=(28, 28, 32, 255), width=2)
    d.rounded_rectangle((sx - 6, sy - 8, W - sx + 6, sy + sh + 8), radius=6, fill=(20, 20, 24, 255))
    # écran (transparent)
    d.rectangle((SCREEN[0] - 1, SCREEN[1] - 1, SCREEN[2], SCREEN[3]), fill=(8, 8, 10, 255))
    d.rectangle((SCREEN[0], SCREEN[1], SCREEN[2] - 1, SCREEN[3] - 1), fill=(0, 0, 0, 0))
    im.save(os.path.join(OUT, f'console_{name}_{W}x{H}.png'))


def main():
    os.makedirs(OUT, exist_ok=True)
    for W, H in SIZES:
        for name, (left, right) in THEMES.items():
            build(name, left, right, W, H)
    print('consoles', len(THEMES) * len(SIZES))


if __name__ == '__main__':
    main()

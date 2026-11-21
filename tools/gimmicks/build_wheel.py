# Gimmicks : images de la roue des mécaniques (touche Y pendant le choix de l'attaque), style de l'interface Horizon
# (ardoise, bleu acier, cadres blancs).
#   python3 tools/gimmicks/build_wheel.py [racine du projet]
import math
import os
import sys
from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'
GIMMICKS = os.path.join(ROOT, 'graphics/interface/gimmicks')
OUT = os.path.join(GIMMICKS, 'wheel')
os.makedirs(OUT, exist_ok=True)
S = 4  # dessin agrandi puis réduit (bords lisses)
STEEL = (80, 126, 166)
SLATE = (51, 71, 81)
DEEP = (34, 46, 56)
WHITE = (240, 246, 250)
LINE = (196, 216, 234)


def smooth(img, size):
    return img.resize(size, Image.LANCZOS)


def save(img, name):
    img.save(os.path.join(OUT, name + '.png'))


# Voile sur tout l'écran
save(Image.new('RGBA', (320, 240), (12, 18, 26, 150)), 'dim')

# Anneau en pointillés qui relie les mécaniques (ellipse 2 * 120 x 2 * 64)
RX, RY, M = 120, 64, 6
W, H = (RX + M) * 2, (RY + M) * 2
ring = Image.new('RGBA', (W * S, H * S))
d = ImageDraw.Draw(ring)
d.ellipse((M * S, M * S, (W - M) * S, (H - M) * S), outline=STEEL + (230,), width=2 * S)
for i in range(36):
    a = math.radians(i * 10)
    x, y = W * S / 2 + RX * S * math.cos(a), H * S / 2 + RY * S * math.sin(a)
    r = 1.6 * S if i % 3 == 0 else 1.0 * S
    d.ellipse((x - r, y - r, x + r, y + r), fill=WHITE + (255,))
save(smooth(ring, (W, H)), 'ring')

# Moyeu : cadre Horizon (ardoise, bord blanc, bandeau bleu acier « ACTION », zone blanche pour le nom et l'aide)
HW, HH = 120, 78
hub = Image.new('RGBA', (HW * S, HH * S))
d = ImageDraw.Draw(hub)
d.rounded_rectangle((0, 0, HW * S - 1, HH * S - 1), 5 * S, fill=WHITE + (255,))
d.rounded_rectangle((S, S, (HW - 1) * S - 1, (HH - 1) * S - 1), 4 * S, fill=SLATE + (255,))
d.rounded_rectangle((3 * S, 3 * S, (HW - 3) * S - 1, 17 * S), 3 * S, fill=STEEL + (255,))
d.line((3 * S, 14 * S, (HW - 3) * S, 14 * S), fill=(64, 104, 140, 255), width=S)
d.rounded_rectangle((4 * S, 21 * S, (HW - 4) * S - 1, (HH - 4) * S - 1), 3 * S, fill=WHITE + (255,))
for x in range(10, HW - 10, 4):  # pointillés entre le nom et l'aide
    d.rectangle((x * S, 44 * S, (x + 2) * S - 1, 45 * S - 1), fill=LINE + (255,))
save(smooth(hub, (HW, HH)), 'hub')

# Case d'une mécanique : 2 lignes (normale, sous le curseur)
BW, BH = 86, 22
sheet = Image.new('RGBA', (BW, BH * 2))
for row, (fill, border, top) in enumerate(((SLATE, LINE, (72, 96, 108)), (STEEL, (255, 255, 255), (118, 160, 196)))):
    box = Image.new('RGBA', (BW * S, BH * S))
    d = ImageDraw.Draw(box)
    d.rounded_rectangle((0, 0, BW * S - 1, BH * S - 1), 5 * S, fill=DEEP + (255,))
    d.rounded_rectangle((S, S, (BW - 1) * S - 1, (BH - 1) * S - 1), 4 * S, fill=border + (255,))
    d.rounded_rectangle((2 * S, 2 * S, (BW - 2) * S - 1, (BH - 2) * S - 1), 3 * S, fill=fill + (255,))
    d.line((5 * S, 3 * S, (BW - 5) * S, 3 * S), fill=top + (255,), width=S)
    # Pastille de l'icône
    d.ellipse((3 * S, 3 * S, 19 * S - 1, 19 * S - 1), fill=DEEP + (200,))
    sheet.alpha_composite(smooth(box, (BW, BH)), (0, row * BH))
save(sheet, 'slot')

# Coche de la mécanique choisie pour ce tour
C = 12
check = Image.new('RGBA', (C * S, C * S))
d = ImageDraw.Draw(check)
d.ellipse((0, 0, C * S - 1, C * S - 1), fill=(40, 160, 80, 255), outline=(255, 255, 255, 255), width=S)
d.line([(3 * S, 6 * S), (5 * S, 8.5 * S), (9 * S, 3.5 * S)], fill=(255, 255, 255, 255), width=int(1.6 * S))
save(smooth(check, (C, C)), 'check')


# Icônes 16 x 16 des mécaniques (à partir des icônes du plugin)
def icon(source, name, fit=16):
    path = os.path.join(GIMMICKS, source + '.png')
    if not os.path.exists(path):
        return
    img = Image.open(path).convert('RGBA')
    img = img.crop(img.getbbox())
    if img.width > fit or img.height > fit:
        factor = fit / max(img.width, img.height)
        img = img.resize((max(1, round(img.width * factor)), max(1, round(img.height * factor))), Image.LANCZOS)
    out = Image.new('RGBA', (16, 16))
    out.alpha_composite(img, ((16 - img.width) // 2, (16 - img.height) // 2))
    save(out, 'icon_' + name)


icon('icon_mega', 'mega')
icon('icon_zcrystal', 'zmove')
icon('icon_ultra', 'ultra')
icon('icon_dynamax', 'dynamax')
icon('tera_icon', 'tera', 15)
for old in ('frame',):
    path = os.path.join(OUT, old + '.png')
    if os.path.exists(path):
        os.remove(path)
print('ok')

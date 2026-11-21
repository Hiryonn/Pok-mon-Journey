# Advanced Pokédex : graphismes de la page Tâches (style du Pokédex Horizon, paliers orange comme le Pokédex de
# Légendes Arceus / le plugin « Pokedex Tasks » de dewm3734)
#   python3 tools/advanced_pokedex/build_tasks_page.py [racine du projet]
import os
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'
PE = os.path.join(ROOT, 'graphics/pokedex/pe')
OUT = os.path.join(ROOT, 'graphics/pokedex/advanced/tasks')
os.makedirs(OUT, exist_ok=True)
S = 4
PAPER = (250, 253, 254)
LIGHT = (226, 240, 248)
EDGE = (202, 231, 244)
STEEL = (84, 127, 165)
CYAN = (97, 189, 227)
ORANGE = (236, 146, 62)
ORANGE_DARK = (196, 92, 30)
ORANGE_LIGHT = (250, 222, 196)
ROW_Y = 72
ROW_H = 27


def smooth(img, size):
    return img.resize(size, Image.LANCZOS)


def frame(d, box, r):
    x0, y0, x1, y1 = box
    d.rounded_rectangle((x0, y0, x1, y1), r, fill=EDGE + (255,))
    d.rounded_rectangle((x0 + 2 * S, y0 + 2 * S, x1 - 2 * S, y1 - 2 * S), r - S, fill=PAPER + (255,))


# --- Fond (320 x 240) -------------------------------------------------------------------------------
base = Image.open(os.path.join(PE, 'adv_height.png')).convert('RGBA')
bg = Image.new('RGBA', (320, 240), PAPER + (255,))
bg.alpha_composite(base.crop((0, 0, 320, 22)), (0, 0))
bg.alpha_composite(base.crop((0, 213, 320, 240)), (0, 213))
big = Image.new('RGBA', (320 * S, 240 * S))
d = ImageDraw.Draw(big)
for y in range(26, 212, 8):
    d.rectangle((0, y * S, 320 * S, y * S + S - 1), fill=(240, 247, 251, 255))
frame(d, (4 * S, 25 * S, 316 * S, 67 * S), 5 * S)
frame(d, (4 * S, 69 * S, 316 * S, 211 * S), 5 * S)
# bandeau bleu acier biseauté du cadre du haut
d.polygon([(6 * S, 27 * S), (150 * S, 27 * S), (142 * S, 40 * S), (6 * S, 40 * S)], fill=STEEL + (255,))
d.line((6 * S, 40 * S, 142 * S, 40 * S), fill=CYAN + (255,), width=S)
# piste de la barre de recherche
d.rounded_rectangle((12 * S, 50 * S, 236 * S, 58 * S), 3 * S, fill=LIGHT + (255,), outline=EDGE + (255,), width=S)
bg.alpha_composite(smooth(big, (320, 240)))
d = ImageDraw.Draw(bg)
for i in range(1, 5):
    y = ROW_Y + i * ROW_H + 1
    for x in range(12, 308, 3):
        d.point((x, y), fill=EDGE + (255,))
bg.save(os.path.join(PE, 'adv_tasks.png'))

# --- Paliers : 2 lignes de 46 x 11 (pas atteint, atteint) ----------------------------------------------
W, H = 46, 11
pills = Image.new('RGBA', (W * S, H * 2 * S))
d = ImageDraw.Draw(pills)
for row, (fill, border) in enumerate(((ORANGE_LIGHT, (232, 190, 150)), (ORANGE, ORANGE_DARK))):
    y = row * H * S
    d.rounded_rectangle((0, y, W * S - 1, y + H * S - 1), 5 * S, fill=border + (255,))
    d.rounded_rectangle((S, y + S, W * S - S - 1, y + H * S - S - 1), 4 * S, fill=fill + (255,))
smooth(pills, (W, H * 2)).save(os.path.join(OUT, 'threshold.png'))

# --- Compteur de la tâche (36 x 22, 2 lignes : en cours, finie) -------------------------------------------
CW, CH = 36, 22
box = Image.new('RGBA', (CW * S, CH * 2 * S))
d = ImageDraw.Draw(box)
for row, fill in enumerate((ORANGE_DARK, STEEL)):
    y = row * CH * S
    d.rounded_rectangle((0, y, CW * S - 1, y + CH * S - 1), 6 * S, fill=fill + (255,))
    d.rounded_rectangle((2 * S, y + 2 * S, CW * S - 2 * S - 1, y + 5 * S), 3 * S, fill=tuple(min(255, c + 40) for c in fill) + (255,))
smooth(box, (CW, CH * 2)).save(os.path.join(OUT, 'counter.png'))

# --- Barre de recherche (224 x 6) ------------------------------------------------------------------------
bar = Image.new('RGBA', (224, 12))
d = ImageDraw.Draw(bar)
d.rectangle((0, 0, 223, 5), fill=ORANGE + (255,))
d.rectangle((0, 4, 223, 5), fill=ORANGE_DARK + (255,))
d.rectangle((0, 6, 223, 11), fill=(96, 176, 72, 255))
d.rectangle((0, 10, 223, 11), fill=(60, 130, 50, 255))
bar.save(os.path.join(OUT, 'bar.png'))

# --- Tampon « recherche terminée » (cercle vert avec coche, 18 x 18) -------------------------------------
st = Image.new('RGBA', (18 * S, 18 * S))
d = ImageDraw.Draw(st)
d.ellipse((0, 0, 18 * S - 1, 18 * S - 1), fill=(60, 150, 70, 255))
d.ellipse((2 * S, 2 * S, 16 * S - 1, 16 * S - 1), outline=(255, 255, 255, 255), width=S)
d.line([(5 * S, 9 * S), (8 * S, 12.5 * S), (13.5 * S, 5.5 * S)], fill=(255, 255, 255, 255), width=int(2.2 * S))
smooth(st, (18, 18)).save(os.path.join(OUT, 'complete.png'))
print('ok')

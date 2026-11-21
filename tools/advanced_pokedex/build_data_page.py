# Advanced Pokédex : graphismes de la page Données (style du Pokédex Horizon)
# Fond fait à partir de la page Taille Horizon (bandeau du haut et barre du bas) ; icônes des habitats et couleurs des
# groupes d'œufs reprises du plugin « Pokedex Data Page » d'Essentials (Lucidious89).
#   python3 tools/advanced_pokedex/build_data_page.py <dossier Graphics/Plugins/Pokedex Data Page> [racine du projet]
import os
import sys
from PIL import Image, ImageDraw

SRC = sys.argv[1] if len(sys.argv) > 1 else 'Graphics/Plugins/Pokedex Data Page'
ROOT = sys.argv[2] if len(sys.argv) > 2 else '.'
PE = os.path.join(ROOT, 'graphics/pokedex/pe')
OUT = os.path.join(ROOT, 'graphics/pokedex/advanced/data')
os.makedirs(OUT, exist_ok=True)
S = 4
PAPER = (250, 253, 254)
LIGHT = (226, 240, 248)
EDGE = (202, 231, 244)
STEEL = (84, 127, 165)
SLATE = (52, 71, 81)
CYAN = (97, 189, 227)


def smooth(img, size):
    return img.resize(size, Image.LANCZOS)


def frame(draw, box, radius=5):
    x0, y0, x1, y1 = box
    draw.rounded_rectangle((x0, y0, x1, y1), radius, fill=EDGE + (255,))
    draw.rounded_rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), radius - 1, fill=PAPER + (255,))


def title_band(draw, x0, y0, width):
    # bandeau bleu acier au bout biseauté (comme les bandes de la fiche)
    draw.polygon([(x0, y0), (x0 + width, y0), (x0 + width - 8, y0 + 12), (x0, y0 + 12)], fill=STEEL + (255,))
    draw.line((x0, y0 + 12, x0 + width - 8, y0 + 12), fill=CYAN + (255,))


# --- Fond de la page (320 x 240) ------------------------------------------------------------------
base = Image.open(os.path.join(PE, 'adv_height.png')).convert('RGBA')
bg = Image.new('RGBA', (320, 240), PAPER + (255,))
bg.alpha_composite(base.crop((0, 0, 320, 22)), (0, 0))
bg.alpha_composite(base.crop((0, 213, 320, 240)), (0, 213))
big = Image.new('RGBA', (320 * S, 240 * S))
d = ImageDraw.Draw(big)
# lignes de papier très claires en fond
for y in range(26, 212, 8):
    d.rectangle((0, y * S, 320 * S, y * S + S - 1), fill=(240, 247, 251, 255))
frame(d, (4 * S, 26 * S, 153 * S, 153 * S), 5 * S)
frame(d, (157 * S, 26 * S, 316 * S, 153 * S), 5 * S)
# bande du bas (habitat + évolutions), comme les bandes d'infos Horizon
d.polygon([(4 * S, 157 * S), (316 * S, 157 * S), (316 * S, 210 * S), (4 * S, 210 * S)], fill=STEEL + (255,))
d.line((4 * S, 157 * S, 316 * S, 157 * S), fill=CYAN + (255,), width=S)
d.rounded_rectangle((8 * S, 161 * S, 52 * S, 205 * S), 4 * S, fill=EDGE + (255,))
d.rounded_rectangle((10 * S, 163 * S, 50 * S, 203 * S), 3 * S, fill=PAPER + (255,))
d.polygon([(58 * S, 161 * S), (312 * S, 161 * S), (312 * S, 195 * S), (58 * S, 195 * S)], fill=(70, 110, 146, 255))
bg.alpha_composite(smooth(big, (320, 240)))
d = ImageDraw.Draw(bg)
title_band(d, 6, 28, 110)
title_band(d, 159, 28, 110)
# pistes des barres de stats (76 x 5)
for i in range(6):
    d.rectangle((72, 47 + i * 14, 147, 51 + i * 14), fill=LIGHT + (255,))
    d.rectangle((72, 52 + i * 14, 147, 52 + i * 14), fill=EDGE + (255,))
# séparateurs pointillés des lignes de droite
for i in range(1, 8):
    for x in range(162, 312, 3):
        d.point((x, 42 + i * 13), fill=EDGE + (255,))
bg.save(os.path.join(PE, 'adv_data.png'))

# --- Barres des stats (couleurs de la page d'Essentials) : 6 lignes de 76 x 5 ------------------------
stats = Image.open(os.path.join(SRC, 'overlay_stats.png')).convert('RGBA')
rows = Image.new('RGBA', (76, 30))
for i in range(6):
    color = stats.getpixel((50, i * 18 + 9))[:3]
    dark = tuple(max(0, c - 40) for c in color)
    rd = ImageDraw.Draw(rows)
    rd.rectangle((0, i * 5, 75, i * 5 + 3), fill=color + (255,))
    rd.rectangle((0, i * 5 + 4, 75, i * 5 + 4), fill=dark + (255,))
rows.save(os.path.join(OUT, 'stat_bars.png'))

# --- Pastilles des groupes d'œufs : 16 lignes de 51 x 11 (couleurs du plugin) ----------------------
# Lignes d'egg_groups.png : ????, Undiscovered, Monster, Water1, Bug, Flying, Field, Fairy, Grass, Humanlike,
# Water3, Mineral, Amorphous, Water2, Ditto, Dragon (28 pixels chacune)
eggs = Image.open(os.path.join(SRC, 'egg_groups.png')).convert('RGBA')
pills = Image.new('RGBA', (51 * S, 11 * 16 * S))
pd = ImageDraw.Draw(pills)
for i in range(16):
    cell = eggs.crop((2, i * 28 + 2, 60, i * 28 + 26))
    counts = {}
    for c in getattr(cell, 'get_flattened_data', cell.getdata)():
        if c[3] > 200:
            counts[c[:3]] = counts.get(c[:3], 0) + 1
    color = max(counts, key=counts.get)
    dark = tuple(max(0, c - 50) for c in color)
    y = i * 11 * S
    pd.rounded_rectangle((0, y, 51 * S - 1, y + 11 * S - 1), 4 * S, fill=dark + (255,))
    pd.rounded_rectangle((S, y + S, 50 * S - 1, y + 10 * S - 1), 3 * S, fill=color + (255,))
smooth(pills, (51, 11 * 16)).save(os.path.join(OUT, 'egg_groups.png'))

# --- Habitats : 10 icônes ramenées à 36 x 36 (?, plaine, forêt, bord de l'eau, mer, grotte, montagne,
# terrain accidenté, ville, rare) -------------------------------------------------------------------
hab = Image.open(os.path.join(SRC, 'habitats.png')).convert('RGBA')
icons = Image.new('RGBA', (36, 36 * 10))
for i in range(10):
    cell = hab.crop((0, i * 48, 64, i * 48 + 48))
    cell = cell.crop(cell.getbbox() or (0, 0, 64, 48))
    factor = 36 / max(cell.width, cell.height)
    cell = cell.resize((round(cell.width * factor), round(cell.height * factor)), Image.LANCZOS)
    icons.alpha_composite(cell, ((36 - cell.width) // 2, i * 36 + (36 - cell.height) // 2))
icons.save(os.path.join(OUT, 'habitats.png'))

# --- Sexe : barre 48 x 6 (bleu / rose) -------------------------------------------------------------
gender = Image.new('RGBA', (48, 12))
gd = ImageDraw.Draw(gender)
gd.rectangle((0, 0, 47, 5), fill=(80, 140, 230, 255))
gd.rectangle((0, 6, 47, 11), fill=(240, 110, 150, 255))
gender.save(os.path.join(OUT, 'gender_bar.png'))

# --- Flèche entre deux stades d'évolution (8 x 11) ---------------------------------------------------
arrow = Image.new('RGBA', (8 * S, 11 * S))
ad = ImageDraw.Draw(arrow)
ad.polygon([(0, 0), (8 * S - 1, 5.5 * S), (0, 11 * S - 1)], fill=(255, 255, 255, 255))
smooth(arrow, (8, 11)).save(os.path.join(OUT, 'arrow.png'))

# --- Fenêtre des listes (capacités, talents, évolutions) : 304 x 188 -------------------------------
W, H = 304, 188
win = Image.new('RGBA', (W * S, H * S))
wd = ImageDraw.Draw(win)
wd.rounded_rectangle((0, 0, W * S - 1, H * S - 1), 6 * S, fill=SLATE + (255,))
wd.rounded_rectangle((2 * S, 2 * S, (W - 2) * S - 1, (H - 2) * S - 1), 5 * S, fill=EDGE + (255,))
wd.rounded_rectangle((4 * S, 4 * S, (W - 4) * S - 1, (H - 4) * S - 1), 4 * S, fill=PAPER + (255,))
wd.rectangle((4 * S, 4 * S, (W - 4) * S - 1, 20 * S), fill=STEEL + (255,))
wd.line((4 * S, 20 * S, (W - 4) * S, 20 * S), fill=CYAN + (255,), width=S)
# zone de description en bas
wd.rounded_rectangle((8 * S, 126 * S, (W - 8) * S - 1, (H - 6) * S - 1), 4 * S, fill=LIGHT + (255,))
smooth(win, (W, H)).save(os.path.join(OUT, 'window.png'))
# Ligne choisie (288 x 14) et onglet (2 lignes : inactif, actif ; 34 x 14)
sel = Image.new('RGBA', (288 * S, 14 * S))
sd = ImageDraw.Draw(sel)
sd.rounded_rectangle((0, 0, 288 * S - 1, 14 * S - 1), 4 * S, fill=CYAN + (255,))
sd.rounded_rectangle((S, S, 287 * S - 1, 13 * S - 1), 3 * S, fill=(214, 238, 250, 255))
smooth(sel, (288, 14)).save(os.path.join(OUT, 'row_selected.png'))
tab = Image.new('RGBA', (34 * S, 28 * S))
td = ImageDraw.Draw(tab)
td.rounded_rectangle((0, 0, 34 * S - 1, 14 * S - 1), 4 * S, fill=(64, 100, 132, 255))
td.rounded_rectangle((0, 14 * S, 34 * S - 1, 28 * S - 1), 4 * S, fill=(255, 255, 255, 255))
td.rounded_rectangle((S, 15 * S, 33 * S - 1, 27 * S - 1), 3 * S, fill=CYAN + (255,))
smooth(tab, (34, 28)).save(os.path.join(OUT, 'tab.png'))
print('ok')

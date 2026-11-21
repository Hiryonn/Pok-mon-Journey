# Styles de combat (Pokémon Légendes Arceus) : graphismes à partir du plugin « PLA Battle Styles » (Lucidious89)
# pour Pokémon Essentials (écran 512 x 384) ramenés à l'écran de PSDK (320 x 240).
#
#   python3 tools/styles_pla/build_assets.py <dossier Graphics/Plugins/PLA Battle Styles> <racine du projet>
import os
import sys
from PIL import Image, ImageDraw

SRC = sys.argv[1] if len(sys.argv) > 1 else 'Graphics/Plugins/PLA Battle Styles'
ROOT = sys.argv[2] if len(sys.argv) > 2 else '.'
OUT = os.path.join(ROOT, 'graphics/interface/styles_pla')
GIMMICKS = OUT
os.makedirs(OUT, exist_ok=True)
SCALE = 320 / 512


def load(name):
    return Image.open(os.path.join(SRC, name + '.png')).convert('RGBA')


def scaled(img, factor=SCALE):
    return img.resize((round(img.width * factor), round(img.height * factor)), Image.LANCZOS)


def half(img):
    return img.resize((img.width // 2, img.height // 2), Image.NEAREST)


# Titres « STRONG STYLE » / « AGILE STYLE »
for name in ('title_strong', 'title_agile'):
    scaled(load(name)).save(os.path.join(OUT, name + '.png'))

# Bandeau derrière le titre : couleur du style (barres d'info_bar), transparent sur les bords
bars = load('info_bar')
for i, kind in enumerate(('strong', 'agile')):
    bar = bars.crop((8, i * 24 + 4, 504, i * 24 + 20)).resize((320, 60), Image.LANCZOS)
    band = Image.new('RGBA', (320, 60))
    px, out = bar.load(), band.load()
    for y in range(60):
        for x in range(320):
            r, g, b, _ = px[x, y]
            edge = min(1.0, min(x, 319 - x) / 90.0) * min(1.0, min(y, 59 - y) / 3.0 + 0.35)
            out[x, y] = (r, g, b, int(235 * edge))
    band.save(os.path.join(OUT, 'fade_%s.png' % kind))

# Onglets « ACTION » (comme ceux du plugin gimmicks) (75 x 23 par ligne : éteint puis allumé)
cursor = load('cursor_styles')  # 6 lignes de 46 : action, style, strong, agile, strong éteint, agile éteint
row = lambda i: cursor.crop((0, i * 46, 150, i * 46 + 46))
for kind, on, off in (('strong', 2, 4), ('agile', 3, 5)):
    tab = Image.new('RGBA', (75, 46))
    tab.alpha_composite(half(row(off)), (0, 0))
    tab.alpha_composite(half(row(on)), (0, 23))
    tab.save(os.path.join(GIMMICKS, 'tab_%s.png' % kind))

# Icônes de la boîte d'infos : le poing (Puissant) et l'aile (Rapide), sur une pastille de la couleur du style
fist = row(2).crop((8, 8, 38, 38))
wing = row(3).crop((114, 8, 144, 38))
for kind, img, color in (('strong', fist, (222, 82, 33)), ('agile', wing, (33, 140, 206))):
    icon = Image.new('RGBA', (16, 16))
    d = ImageDraw.Draw(icon)
    d.ellipse((0, 0, 15, 15), fill=(40, 40, 48, 255))
    d.ellipse((1, 1, 14, 14), fill=color + (255,))
    small = img.resize((12, 12), Image.LANCZOS)
    # Garde seulement le blanc du symbole
    px = small.load()
    for y in range(12):
        for x in range(12):
            r, g, b, a = px[x, y]
            px[x, y] = (255, 255, 255, a) if a > 90 and min(r, g, b) > 150 else (0, 0, 0, 0)
    icon.alpha_composite(small, (2, 2))
    icon.save(os.path.join(GIMMICKS, 'icon_%s.png' % kind))

# Capacité maîtrisée (petite graine)
mastered = load('mastered_icon')
mastered = mastered.crop(mastered.getbbox()).resize((7, 11), Image.LANCZOS)
px = mastered.load()
for y in range(mastered.height):
    for x in range(mastered.width):
        r, g, b, a = px[x, y]
        px[x, y] = (r, g, b, 255 if a > 110 else 0)
mastered.save(os.path.join(OUT, 'mastered.png'))

# Cadre des effets du style : onglet « STYLE INFO » et barre de la couleur du style au-dessus d'un fond sombre
info_tab = load('info_tab')   # 2 lignes de 34 : strong, agile
info_bar = load('info_bar')   # 2 lignes de 24 : strong, agile
W, H = 228, 70
for i, kind in enumerate(('strong', 'agile')):
    panel = Image.new('RGBA', (W, H))
    d = ImageDraw.Draw(panel)
    bar = info_bar.crop((0, i * 24, 512, i * 24 + 24)).resize((W, 6), Image.LANCZOS)
    d.rounded_rectangle((0, 12, W - 1, H - 1), 4, fill=(24, 26, 38, 225), outline=(12, 12, 20, 255))
    panel.alpha_composite(bar, (0, 12))
    tab = info_tab.crop((0, i * 34, 144, i * 34 + 34))
    panel.alpha_composite(tab.resize((72, 17), Image.NEAREST), (4, 0))
    panel.save(os.path.join(OUT, 'info_%s.png' % kind))
print('ok')

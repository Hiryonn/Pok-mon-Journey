# Berrydex : graphismes du jeu (graphics/interface/berrydex/) à partir de « TDW Berry Core and Dex » (Essentials)
#   python build_berrydex_assets.py <dossier Graphics/UI/Berrydex du pack> <racine du projet>
# - tags/<baie>.png : étiquette de chaque baie du projet (nom Essentials ORANBERRY -> oran_berry), 64 x 64
# - weather/<nom>.png : icônes de météo et de lieux, réduites à 24 x 24
# - found.png, unknown.png, pastilles des saveurs, panneaux aux couleurs du Pokédex Horizon
import glob
import json
import os
import sys
from PIL import Image, ImageDraw

SRC, ROOT = sys.argv[1], sys.argv[2]
OUT = os.path.join(ROOT, 'graphics/interface/berrydex')
os.makedirs(os.path.join(OUT, 'tags'), exist_ok=True)
os.makedirs(os.path.join(OUT, 'weather'), exist_ok=True)

LIGHT, SHEEN, PALE, SKY = (229, 243, 250), (250, 253, 254), (213, 238, 248), (145, 201, 247)
BLUE, STEEL, SLATE, DEEP = (80, 126, 166), (69, 103, 129), (51, 71, 81), (36, 52, 62)


def save(im, rel):
    path = os.path.join(OUT, rel + '.png')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)


# étiquettes des baies du projet
count = 0
for f in glob.glob(os.path.join(ROOT, 'Data/Studio/items/*.json')):
    d = json.load(open(f, encoding='utf-8-sig'))
    if not d.get('isBerry'):
        continue
    tag = os.path.join(SRC, 'Tag Icons', d['dbSymbol'].replace('_', '').upper() + '.png')
    if os.path.exists(tag):
        save(Image.open(tag).convert('RGBA'), 'tags/' + d['dbSymbol'])
        count += 1
print('étiquettes :', count)

# météo et lieux (48 -> 24)
for f in glob.glob(os.path.join(SRC, 'Plant Icons', '*.png')):
    im = Image.open(f).convert('RGBA').resize((24, 24), Image.BOX)
    save(im, 'weather/' + os.path.basename(f)[:-4].lower())
save(Image.open(os.path.join(SRC, 'unknown.png')).convert('RGBA').resize((24, 24), Image.BOX), 'unknown')
save(Image.open(os.path.join(SRC, 'icon_found.png')).convert('RGBA').resize((14, 14), Image.NEAREST), 'found')

# pastilles des saveurs (couleurs du pack ; le texte est écrit par le jeu)
FLAVORS = {'spicy': (240, 128, 48), 'dry': (104, 144, 240), 'sweet': (248, 88, 136), 'bitter': (120, 200, 80), 'sour': (248, 208, 48)}
for key, color in FLAVORS.items():
    im = Image.new('RGBA', (52, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    dark = tuple(max(0, c - 70) for c in color)
    d.rounded_rectangle((0, 0, 51, 13), 4, fill=dark)
    d.rounded_rectangle((1, 1, 50, 12), 3, fill=color)
    save(im, 'flavor_' + key)


def panel(w, h, fill, border, name, lines=0, line_color=None, top=4, step=16):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), 3, fill=border)
    d.rounded_rectangle((1, 1, w - 2, h - 2), 2, fill=fill)
    if lines:
        for ly in range(top + step - 1, h - 3, step):
            for lx in range(3, w - 3, 2):
                im.putpixel((lx, ly), line_color)
    save(im, name)


# carte de gauche (étiquette, nom), liste de droite (comme la liste du sac), panneau d'infos, curseur
panel(122, 176, LIGHT, STEEL, 'card')
panel(178, 176, STEEL, SLATE, 'list', lines=1, line_color=(88, 128, 160))
panel(178, 176, SHEEN, STEEL, 'info')
panel(178, 18, SKY, SLATE, 'cursor')
panel(166, 16, PALE, (190, 222, 244), 'row')
print('ok', OUT)

# Magasins : graphismes du jeu (graphics/interface/magasins/), aux couleurs du Pokédex Horizon
#   python build_magasins_assets.py <racine du projet>
# Inspirés de « Arcky's Poke Market » (Essentials) : comptoir (liste par catégorie) et étalages (rayons + panier).
# La barre du bas et les icônes des poches viennent du sac Horizon (graphics/interface/bag_horizon/).
import os
import sys
from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'
OUT = os.path.join(ROOT, 'graphics/interface/magasins')
os.makedirs(OUT, exist_ok=True)
LIGHT, SHEEN, PALE, SKY = (229, 243, 250), (250, 253, 254), (213, 238, 248), (145, 201, 247)
BLUE, STEEL, SLATE, DEEP = (80, 126, 166), (69, 103, 129), (51, 71, 81), (36, 52, 62)


def save(im, name):
    im.save(os.path.join(OUT, name + '.png'))


def panel(w, h, fill, border, radius=3):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=border)
    d.rounded_rectangle((1, 1, w - 2, h - 2), max(radius - 1, 0), fill=fill)
    return im


# fenêtres de gauche (argent / dans le sac / panier)
save(panel(112, 36, SHEEN, STEEL), 'window')
# liste du comptoir : bandeau de la catégorie + 10 lignes
im = panel(196, 182, STEEL, SLATE)
d = ImageDraw.Draw(im)
d.rounded_rectangle((1, 1, 194, 18), 2, fill=SLATE)
for y in range(20 + 15, 180, 16):
    for x in range(4, 192, 2):
        im.putpixel((x, y), (88, 128, 160, 255))
save(im, 'list')
save(panel(192, 16, SKY, SLATE, 2), 'cursor')
save(panel(108, 22, SHEEN, STEEL), 'quantity')
save(panel(64, 40, SHEEN, STEEL), 'choice')
# flèche de choix (5 x 7)
arrow = Image.new('RGBA', (5, 7), (0, 0, 0, 0))
ad = ImageDraw.Draw(arrow)
ad.polygon([(0, 0), (4, 3), (0, 6)], fill=DEEP)
save(arrow, 'arrow')

# rayons de l'étalage : 3 étagères de 6 objets
W, H = 196, 182
im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.rounded_rectangle((0, 0, W - 1, H - 1), 4, fill=SLATE)
d.rounded_rectangle((1, 1, W - 2, H - 2), 3, fill=STEEL)
d.rectangle((4, 4, W - 5, H - 5), fill=DEEP)
for r in range(3):
    top = 4 + r * 58
    d.rectangle((5, top + 1, W - 6, top + 49), fill=PALE)
    # reflet en haut du fond
    d.rectangle((5, top + 1, W - 6, top + 6), fill=SHEEN)
    # planche
    d.rectangle((4, top + 50, W - 5, top + 56), fill=BLUE)
    d.line((4, top + 50, W - 5, top + 50), fill=SKY)
    d.line((4, top + 56, W - 5, top + 56), fill=SLATE)
save(im, 'shelf')
# curseur de l'étalage : cadre autour de l'objet + étiquette du prix
cw, ch = 34, 50
im = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.rounded_rectangle((0, 0, cw - 1, 37), 3, outline=(200, 40, 48), width=2)
d.rounded_rectangle((0, 37, cw - 1, ch - 1), 2, fill=(200, 40, 48))
save(im, 'shelf_cursor')
# étiquette de remise (-20 %) / majoration
save(panel(26, 11, (88, 184, 104), (48, 128, 72), 2), 'tag_discount')
save(panel(26, 11, (232, 120, 64), (168, 72, 32), 2), 'tag_overcharge')
print('ok', OUT)

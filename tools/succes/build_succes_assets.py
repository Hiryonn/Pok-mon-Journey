# Succès : graphismes du jeu (graphics/interface/succes/ et icône de l'appli du téléphone), aux couleurs du Pokédex Horizon
#   python build_succes_assets.py <racine du projet>
# - row.png / row_selected.png / row_done.png : lignes de la liste (308 x 34)
# - frame.png : cadre de l'icône (32 x 32) ; lock.png : succès secret ; check.png : succès obtenu
# - bar(_big).png / bar(_big)_fill.png : barres de progression ; points.png : pastille des points ; card.png : fiche du succès
# - trophy_bronze / silver / gold / platinum.png : icônes de trophée (32 x 32)
# - toast.png : bandeau de la notification « Succès obtenu ! »
# - pokesmart/icon_trophy.png : icône de l'appli Succès du téléphone (64 x 32 : normale, sélectionnée)
import os
import sys
from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'
OUT = os.path.join(ROOT, 'graphics/interface/succes')
os.makedirs(OUT, exist_ok=True)

LIGHT, SHEEN, PALE, SKY = (229, 243, 250), (250, 253, 254), (213, 238, 248), (145, 201, 247)
BLUE, STEEL, SLATE, DEEP = (80, 126, 166), (69, 103, 129), (51, 71, 81), (36, 52, 62)
GOLD, GOLD_D = (240, 192, 64), (168, 112, 24)


def save(im, name, folder=OUT):
    im.save(os.path.join(folder, name + '.png'))


def panel(w, h, fill, border, radius=3):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=border)
    d.rounded_rectangle((1, 1, w - 2, h - 2), max(radius - 1, 0), fill=fill)
    return im


# lignes de la liste
save(panel(308, 34, SHEEN, STEEL), 'row')
save(panel(308, 34, PALE, BLUE), 'row_done')
sel = panel(308, 34, SKY, SLATE)
ImageDraw.Draw(sel).rounded_rectangle((2, 2, 305, 31), 2, outline=SHEEN)
save(sel, 'row_selected')
save(panel(32, 32, LIGHT, STEEL), 'frame')
save(panel(308, 180, SHEEN, STEEL), 'card')
save(panel(296, 8, PALE, STEEL, 3), 'bar_big')
save(Image.new('RGBA', (294, 6), SKY + (255,)), 'bar_big_fill')
save(panel(64, 6, PALE, STEEL, 2), 'bar')
save(Image.new('RGBA', (62, 4), SKY + (255,)), 'bar_fill')
save(panel(30, 14, STEEL, SLATE, 4), 'points')
save(panel(208, 32, SHEEN, SLATE), 'toast')

# cadenas (succès secret, 24 x 24)
im = Image.new('RGBA', (24, 24), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.arc((7, 3, 16, 14), 180, 360, fill=SLATE, width=2)
d.line((7, 9, 7, 11), fill=SLATE, width=2)
d.line((16, 9, 16, 11), fill=SLATE, width=2)
d.rounded_rectangle((5, 11, 18, 21), 2, fill=SLATE)
d.rounded_rectangle((6, 12, 17, 20), 1, fill=BLUE)
d.rectangle((11, 14, 12, 18), fill=SLATE)
save(im, 'lock')

# coche (succès obtenu, 14 x 14)
im = Image.new('RGBA', (14, 14), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.ellipse((0, 0, 13, 13), fill=(48, 128, 72))
d.ellipse((1, 1, 12, 12), fill=(88, 184, 104))
d.line((3, 7, 6, 10, 10, 4), fill=(255, 255, 255), width=2)
save(im, 'check')


# trophées en pixel art (32 x 32), contour sombre comme les icônes du téléphone
TROPHY = [
    '................................',
    '................................',
    '................................',
    '.........OOOOOOOOOOOOOO.........',
    '.....OOOOOHHHHHHLLLLLLMOOOO.....',
    '....OLLLLOHLLLLLLLLLLMMOLLLO....',
    '....OLOOOOHLLLLLLLLLLMMOOOLO....',
    '....OLO..OHLLLLLLLLLLMMO.OLO....',
    '....OLO..OHLLLLLLLLLLMMO.OLO....',
    '....OLO..OHLLLLLLLLLMMMO.OLO....',
    '.....OLO.OHLLLLLLLLLMMMOOLO.....',
    '.....OOLOOHLLLLLLLLLMMDOLOO.....',
    '......OOLOOLLLLLLLLMMMDOLO......',
    '.......OOOOLLLLLLLLMMDDOO.......',
    '..........OOLLLLLLMMDOO.........',
    '...........OOLLLLMMDOO..........',
    '............OOLLMMDOO...........',
    '.............OOLMDOO............',
    '..............OLMDO.............',
    '..............OLMDO.............',
    '.............OOLMDOO............',
    '............OLLLMMDDO...........',
    '...........OOOOOOOOOOO..........',
    '..........OSSSSSSSSSSSO.........',
    '..........OSWWWWWWWWWSO.........',
    '..........OSSSSSSSSSSSO.........',
    '.........OKKKKKKKKKKKKKO........',
    '.........OOOOOOOOOOOOOOO........',
    '................................',
    '................................',
    '................................',
    '................................',
]
METALS = {
    'bronze': ((246, 196, 150), (214, 140, 82), (176, 104, 56), (124, 68, 32)),
    'silver': ((250, 252, 255), (210, 220, 230), (164, 178, 192), (112, 124, 138)),
    'gold': ((255, 244, 168), (248, 208, 72), (216, 160, 32), (160, 104, 16)),
    'platinum': ((238, 250, 255), (176, 224, 240), (120, 184, 216), (72, 128, 168)),
}


def trophy(metal):
    hi, light, mid, dark = METALS[metal]
    colors = {'O': (48, 48, 48), 'H': hi, 'L': light, 'M': mid, 'D': dark,
              'S': (112, 80, 32), 'W': (200, 136, 64), 'K': (72, 48, 24)}
    im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    for y, row in enumerate(TROPHY):
        for x, c in enumerate(row):
            if c in colors:
                im.putpixel((x, y), colors[c] + (255,))
    return im


for metal in METALS:
    save(trophy(metal), 'trophy_' + metal)

# icône de l'appli du téléphone : normale à gauche, sélectionnée (un peu plus claire) à droite
icon = Image.new('RGBA', (64, 32), (0, 0, 0, 0))
gold = trophy('gold')
icon.alpha_composite(gold, (0, 0))
bright = gold.copy()
px = bright.load()
for y in range(32):
    for x in range(32):
        r, g, b, a = px[x, y]
        if a and (r, g, b) != (48, 48, 48):
            px[x, y] = (min(255, r + 18), min(255, g + 18), min(255, b + 18), a)
icon.alpha_composite(bright, (32, 0))
save(icon, 'icon_trophy', os.path.join(ROOT, 'graphics/interface/pokesmart'))
print('ok', OUT)

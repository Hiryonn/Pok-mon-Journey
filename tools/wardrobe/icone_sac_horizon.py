"""Ajoute l'icône « Tenues » (9e colonne, 14x14) à graphics/interface/bag_horizon/pockets.png.
Idempotent : si la feuille fait déjà 126 px de large, la 9e colonne est simplement redessinée."""
from PIL import Image
import sys

PATH = sys.argv[1] if len(sys.argv) > 1 else 'graphics/interface/bag_horizon/pockets.png'
S = 14
SHIRT = [
    ".###..###.",
    "##########",
    "##########",
    "..######..",
    "..######..",
    "..######..",
    "..######..",
]
# (fond, encre, reflet) pour : poche inactive, poche active
STYLES = {0: ((69, 103, 129, 255), (36, 52, 62, 255)), 1: ((248, 248, 248, 255), (69, 103, 129, 255))}

im = Image.open(PATH).convert('RGBA')
out = Image.new('RGBA', (S * 9, im.height), (0, 0, 0, 0))
out.paste(im.crop((0, 0, S * 8, im.height)), (0, 0))
for row in range(im.height // S):
    cell = im.crop((0, row * S, S, row * S + S)).copy()  # cadre de la 1re poche
    if row in STYLES:
        bg, ink = STYLES[row]
        for y in range(3, 11):
            for x in range(2, 12):
                cell.putpixel((x, y), bg)
        for y, line in enumerate(SHIRT):
            for x, c in enumerate(line):
                if c == '#':
                    cell.putpixel((x + 2, y + 4), ink)
    out.paste(cell, (S * 8, row * S))
out.save(PATH)
print('ok', out.size)

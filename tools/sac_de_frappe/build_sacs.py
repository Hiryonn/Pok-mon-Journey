# Sac de frappe : variantes du sac (Super Training de X / Y, planche sacs_xy.png, cases de 32 x 64)
#
# Usage : python build_sacs.py
#   graphics/interface/sac_de_frappe/sacs/<id>.png   sac agrandi 3 fois (pixels exacts), accroché par le haut
# Les ids sont repris dans scripts/sac_de_frappe/scripts/00100 Configuration.rb (BAGS). Ne touche à aucune autre image.
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'graphics', 'interface', 'sac_de_frappe', 'sacs')
SHEET = os.path.join(HERE, 'sacs_xy.png')
IDS = [
    ['gris', 'rose', 'team_flare', 'jaune', 'bleu', 'violet', 'vert', 'double', 'noir'],
    ['aquatique_1', 'aquatique_2', 'aquatique_3', 'scarabee_1', 'scarabee_2', 'scarabee_3', 'acier_1', 'acier_2', 'acier_3'],
    ['spectre_1', 'spectre_2', 'spectre_3', 'givre_1', 'givre_2', 'givre_3', 'plante_1', 'plante_2', 'plante_3'],
]
SCALE = 3


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.open(SHEET).convert('RGBA')
    px = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            if px[x, y][:3] == (0, 128, 128):
                px[x, y] = (0, 0, 0, 0)
    for r, row in enumerate(IDS):
        for c, name in enumerate(row):
            cell = sheet.crop((2 + c * 34, 2 + r * 66, 34 + c * 34, 66 + r * 66))
            cell = cell.crop(cell.getbbox())
            cell.resize((cell.width * SCALE, cell.height * SCALE), Image.NEAREST).save(os.path.join(OUT, f'{name}.png'))
    print('sacs', sum(len(r) for r in IDS))


if __name__ == '__main__':
    main()

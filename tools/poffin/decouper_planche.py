"""Découpe la planche de cuisson des Pofin (tools/poffin/planche/Poffin_Baking.png) en images pour le plugin poffin.
Écrit graphics/interface/poffin/*.png. Les pièces sont à l'échelle de la planche (écrans de 256x192 comme sur DS) :
le plugin les pose sur un écran de 320x240 (voir 00100 Configuration.rb : SCREEN_X / SCREEN_Y).
Modes : opaque = tel quel ; dehors = le blanc relié au bord de la pièce devient transparent ;
tout = tout le blanc devient transparent (anneaux, dont l'intérieur est vide).
Utilisation : python tools/poffin/decouper_planche.py
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ICI = os.path.dirname(os.path.abspath(__file__))
PLANCHE = os.path.join(ICI, 'planche', 'Poffin_Baking.png')
SORTIE = os.path.join(ICI, '..', '..', 'graphics', 'interface', 'poffin')

# nom : (x, y, largeur, hauteur, mode)
PIECES = {
    'fond_cuisine': (20, 145, 256, 192, 'opaque'),
    'fond_liste': (303, 146, 256, 192, 'opaque'),
    'feu_rouge': (29, 351, 236, 192, 'tout'),
    'feu_jaune': (307, 351, 236, 192, 'tout'),
    'feu_bleu': (29, 567, 236, 192, 'tout'),
    'cadre_perles': (318, 567, 214, 192, 'tout'),
    'nappe': (148, 776, 256, 192, 'opaque'),
    'pofin_1': (105, 1034, 128, 128, 'dehors'),
    'pofin_2': (246, 1034, 128, 128, 'dehors'),
    'pofin_3': (386, 1034, 128, 128, 'dehors'),
    'bouton_fini': (93, 1217, 128, 32, 'dehors'),
    'bouton_start': (106, 1255, 96, 32, 'dehors'),
    'fleche_bleue': (309, 1206, 96, 87, 'dehors'),
    'fleche_verte': (455, 1204, 96, 87, 'dehors'),
    'nuage': (228, 1225, 54, 54, 'dehors'),
    'case_rouge': (312, 1314, 79, 32, 'dehors'),
    'case_bleue': (393, 1314, 80, 32, 'dehors'),
    'case_jaune': (312, 1346, 79, 32, 'dehors'),
    'case_verte': (393, 1346, 80, 32, 'dehors'),
    'case_orange': (312, 1387, 161, 32, 'dehors'),
    'cuillere': (518, 1407, 32, 56, 'dehors'),
    'onde_1': (526, 1320, 16, 16, 'dehors'),
    'onde_2': (522, 1344, 24, 24, 'dehors'),
    'onde_3': (518, 1372, 32, 32, 'dehors'),
    # pâtes de 3 tailles : beige (cuisson), orange (trop chaud), grise (brûlée)
    'pate_beige_1': (47, 1497, 54, 54, 'dehors'),
    'pate_beige_2': (44, 1557, 58, 58, 'dehors'),
    'pate_beige_3': (41, 1618, 64, 64, 'dehors'),
    'pate_orange_1': (218, 1498, 54, 54, 'dehors'),
    'pate_orange_2': (216, 1557, 58, 58, 'dehors'),
    'pate_orange_3': (213, 1618, 64, 64, 'dehors'),
    'pate_grise_1': (302, 1499, 54, 54, 'dehors'),
    'pate_grise_2': (300, 1559, 58, 58, 'dehors'),
    'pate_grise_3': (297, 1620, 64, 64, 'dehors'),
}
# pastilles de saveur de la planche (rouge, jaune, bleu, vert)
for i, y in enumerate((1222, 1239, 1256, 1273)):
    PIECES[f'pastille_{i + 1}'] = (22, y, 14, 14, 'dehors')


def rendre_transparent(img, mode):
    a = np.array(img.convert('RGBA'))
    blanc = (a[:, :, :3] >= 252).all(axis=2)
    if mode == 'tout':
        a[blanc, 3] = 0
    elif mode == 'dehors':
        lab, _ = ndimage.label(blanc)
        bord = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
        for n in bord:
            a[lab == n, 3] = 0
    return Image.fromarray(a, 'RGBA')


def main():
    planche = Image.open(PLANCHE).convert('RGBA')
    os.makedirs(SORTIE, exist_ok=True)
    for nom, (x, y, w, h, mode) in PIECES.items():
        rendre_transparent(planche.crop((x, y, x + w, y + h)), mode).save(os.path.join(SORTIE, nom + '.png'))
    # fond de l'écran de 320x240 : la couleur du haut du décor, pour entourer l'écran de 256x192
    haut = planche.getpixel((24, 150))
    Image.new('RGBA', (320, 240), haut).save(os.path.join(SORTIE, 'fond.png'))
    print(len(PIECES) + 1, 'images écrites dans', os.path.normpath(SORTIE))


if __name__ == '__main__':
    main()

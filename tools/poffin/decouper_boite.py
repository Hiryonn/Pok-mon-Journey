"""Découpe la planche de la boîte à poffins (tools/poffin/planche/Poffin_Box.png) en images pour le plugin poffin.
Écrit graphics/interface/poffin/ : boite_fond, conditions_fond, donner_fond, donner_damier, bouton_<couleur>_<1-4>, texte_long,
texte_court, haut_<n>, bas_<n> (flèches), anneau_<1-5>, et mini_1 à mini_3 / mini_brule (icônes de 16x16 faites avec les poffins
de la cuisson : lancer d'abord decouper_planche.py).
Utilisation : python tools/poffin/decouper_boite.py
"""
import os

from PIL import Image

import decouper_planche as cuisine

ICI = os.path.dirname(os.path.abspath(__file__))
PLANCHE = os.path.join(ICI, 'planche', 'Poffin_Box.png')
SORTIE = cuisine.SORTIE

COULEURS = ['orange', 'rouge', 'rose', 'bleu', 'jaune', 'vert']
BOUTONS_X = [87, 151, 215, 280, 345, 410]
BOUTONS_Y = [390, 423, 456, 489]
FLECHES_X = [37, 61, 83, 105, 127, 148, 169, 191]

PIECES = {
    'boite_fond': (17, 116, 256, 192, 'opaque'),
    'conditions_fond': (288, 116, 256, 192, 'opaque'),
    'donner_fond': (32, 713, 256, 192, 'opaque'),
    'donner_damier': (305, 713, 256, 192, 'opaque'),
    'texte_long': (38, 571, 124, 18, 'dehors'),
    'texte_court': (167, 571, 46, 18, 'dehors'),
}
for c, nom in enumerate(COULEURS):
    for e, y in enumerate(BOUTONS_Y):
        PIECES[f'bouton_{nom}_{e + 1}'] = (BOUTONS_X[c], y, 64, 31, 'dehors')
for i, x in enumerate(FLECHES_X):
    PIECES[f'haut_{i + 1}'] = (x, 594, 18, 14, 'dehors')
    PIECES[f'bas_{i + 1}'] = (x, 611, 18, 15, 'dehors')
for i in range(5):  # rouge, bleu clair, vert, rose, jaune
    PIECES[f'anneau_{i + 1}'] = (231, 572 + 16 * i, 14, 14, 'dehors')


def main():
    planche = Image.open(PLANCHE).convert('RGBA')
    os.makedirs(SORTIE, exist_ok=True)
    for nom, (x, y, w, h, mode) in PIECES.items():
        cuisine.rendre_transparent(planche.crop((x, y, x + w, y + h)), mode).save(os.path.join(SORTIE, nom + '.png'))
    # icônes de la liste : les poffins de la cuisson réduits à 16x16
    for nom, source in {'mini_1': 'pofin_1', 'mini_2': 'pofin_2', 'mini_3': 'pofin_3', 'mini_brule': 'pate_grise_1'}.items():
        img = Image.open(os.path.join(SORTIE, source + '.png')).convert('RGBA')
        img.resize((16, 16), Image.BOX).save(os.path.join(SORTIE, nom + '.png'))
    print(len(PIECES) + 4, 'images écrites dans', os.path.normpath(SORTIE))


if __name__ == '__main__':
    main()

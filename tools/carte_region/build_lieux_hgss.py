# Carte de région : images des lieux de HeartGold / SoulSilver (planche lieux_hgss_source.png, 256x160 par image)
#
# Usage : python build_lieux_hgss.py [dossier du projet]
#   graphics/interface/carte_region/lieux/<lieu>.png         image de base (celle du matin, choisie dans Studio)
#   graphics/interface/carte_region/lieux/<lieu>_matin.png   matin et journée
#   graphics/interface/carte_region/lieux/<lieu>_soir.png    soirée (coucher du soleil)
#   graphics/interface/carte_region/lieux/<lieu>_nuit.png    nuit
# En jeu, la carte de région prend la variante de l'heure si elle existe (00100 Configuration.rb : zone_image).
# Ne touche à aucune autre image.
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..')
OUT = os.path.join(ROOT, 'graphics', 'interface', 'carte_region', 'lieux')
SHEET = Image.open(os.path.join(HERE, 'lieux_hgss_source.png')).convert('RGBA')

LEFT = ['antre_noire_sud', 'tour_chetiflor', 'ruines_alpha', 'caves_jumelles', 'puits_ramoloss', 'bois_aux_chenes',
        'parc_naturel', 'tour_cendree']
RIGHT = ['tour_carillon', 'tourbiles', 'mont_creuset', 'route_de_glace', 'antre_du_dragon', 'antre_noire_est',
         'chutes_tohjo', 'route_victoire']
TIMES = ['matin', 'soir', 'nuit']


def main():
    os.makedirs(OUT, exist_ok=True)
    for group, x0 in ((LEFT, 69), (RIGHT, 907)):
        for row, name in enumerate(group):
            y = 30 + row * 195 + 16
            for col, time in enumerate(TIMES):
                x = x0 + col * 259
                art = SHEET.crop((x, y, x + 256, y + 160))
                art.save(os.path.join(OUT, f'{name}_{time}.png'))
                if time == 'matin':
                    art.save(os.path.join(OUT, f'{name}.png'))
            print(name)


if __name__ == '__main__':
    main()

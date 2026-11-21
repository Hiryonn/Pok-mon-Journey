# Résumé : passe les graphismes du résumé (graphics/interface/summary_pe/) aux couleurs de l'interface Horizon
#   python tools/interface-horizon/recolor_summary.py
# Chaque gris est remplacé par la teinte Horizon de même clarté (ardoise, acier, bleu, ciel, bleu pâle) ;
# les couleurs (types, barres, sexe, chromatique…) ne changent pas. Sans effet sur une image déjà passée.
import glob
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
DIR = os.path.join(ROOT, 'graphics', 'interface', 'summary_pe')

# Gris -> couleur Horizon (points de passage, interpolés entre eux)
RAMP = [
    (0, (36, 52, 62)), (35, (51, 71, 81)), (61, (69, 103, 129)), (81, (80, 126, 166)),
    (138, (104, 152, 194)), (183, (210, 234, 246)), (239, (229, 243, 250)), (255, (255, 255, 255)),
]


def horizon(level):
    for (a, ca), (b, cb) in zip(RAMP, RAMP[1:]):
        if a <= level <= b:
            t = (level - a) / (b - a) if b > a else 0
            return tuple(round(ca[i] + (cb[i] - ca[i]) * t) for i in range(3))
    return RAMP[-1][1]


def is_grey(r, g, b):
    return max(r, g, b) - min(r, g, b) <= 8


def recolor(path):
    im = Image.open(path).convert('RGBA')
    px = im.load()
    cache = {}
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0 or not is_grey(r, g, b) or (r, g, b) == (255, 255, 255):
                continue
            key = (r, g, b)
            if key not in cache:
                cache[key] = horizon(round((r + g + b) / 3))
            px[x, y] = cache[key] + (a,)
    im.save(path)


def main():
    files = [f for f in glob.glob(os.path.join(DIR, '*.png')) if not os.path.basename(f).startswith('move_slot_')]
    for f in files:
        recolor(f)
    print(len(files), 'images passées aux couleurs Horizon dans', DIR)


if __name__ == '__main__':
    main()

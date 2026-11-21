"""Découpe les planches d'attaques (fond uni, titres retirés) en une feuille transparente par attaque.
Usage : python3 decouper_attaques.py [dossier_des_planches] [dossier_de_sortie]
Défauts : tools/animations_attaques/sources -> graphics/animations (fichiers atk_<nom>.png) + index.json à côté du script.
Zones écrites à la main d'après les planches (x0, y0, x1, y1[, {exclude: [...], strip: 'black'|'olive'}]) ;
vérifie le résultat à l'œil si tu changes une planche."""
import json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else HERE + '/sources'
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.abspath(HERE + '/../../graphics/animations')
os.makedirs(OUT, exist_ok=True)

# (nom, x0, y0, x1, y1) ; les zones qui se chevauchent : la première qui contient le centre d'un amas gagne
POISON = [
 ('acid_armor', 125, 28, 700, 80), ('acid', 0, 28, 125, 62),
 ('cross_poison', 0, 105, 540, 170), ('poison_fang', 590, 125, 730, 160),
 ('gastro_acid', 0, 190, 520, 245), ('poison_sting', 590, 203, 720, 300),
 ('gunk_shot', 0, 262, 430, 348), ('poison_tail', 480, 328, 780, 365),
 ('sludge', 480, 418, 545, 445), ('sludge_bomb', 580, 395, 730, 555),
 ('poison_extra_1', 0, 352, 160, 478, {'exclude': [(105, 440, 160, 478)]}), ('poison_vagues', 60, 438, 460, 780, {'strip': 'olive'}),
 ('toxic_spikes', 470, 603, 790, 660),
 ('poisoned', 610, 692, 750, 722), ('badly_poisoned', 610, 766, 750, 798),
 ('poison_gas_smog', 0, 790, 560, 872, {'strip': 'black'}), ('poison_jab', 0, 905, 650, 1055),
 ('poisonpowder', 0, 1085, 735, 1150), ('toxic', 70, 1180, 600, 1225),
]
JOSHR = [
 ('joshr_divers', 0, 0, 306, 436), ('joshr_vignes', 0, 436, 278, 483), ('joshr_explosions_fumee', 0, 483, 175, 506),
 ('joshr_vitres_grises', 0, 506, 278, 645), ('joshr_notes_soleil', 0, 647, 160, 733, {'exclude': [(135, 645, 300, 708)]}),
 ('joshr_vitres_vertes', 0, 732, 278, 870), ('joshr_vitres_jaunes', 0, 870, 278, 1008), ('joshr_vitres_bleues', 0, 1008, 278, 1146),
]
DRAGON = [
 ('draco_meteor', 0, 28, 770, 590), ('dragon_claw', 0, 625, 770, 935),
 ('dragon_dance', 0, 970, 770, 1160), ('dragon_pulse', 0, 1195, 770, 1445),
 ('dragon_rage', 0, 1480, 770, 1535), ('dragon_rush', 0, 1570, 770, 1700),
 ('dragonbreath', 0, 1722, 245, 1778), ('outrage', 150, 1740, 770, 1860, {'exclude': [(0, 1740, 250, 1782)], 'strip': 'black'}),
 ('roar_of_time', 0, 1885, 770, 2060), ('spacial_rend', 0, 2095, 770, 2175),
 ('twister', 0, 2205, 770, 2480),
]
def cut(path, regions, prefix, bgcolor):
    im = Image.open(path).convert('RGB'); a = np.array(im).astype(int)
    bg = np.abs(a - np.array(bgcolor)).sum(axis=2) < 12
    fg = ~bg
    black_text = (a.sum(axis=2) < 40)
    alpha = fg.copy()
    rgba = np.dstack([a.astype(np.uint8), (alpha * 255).astype(np.uint8)])
    index = {}
    for name, x0, y0, x1, y1, *opt in regions:
        opt = opt[0] if opt else {}
        sub = rgba[y0:y1, x0:x1].copy()
        for ex0, ey0, ex1, ey1 in opt.get('exclude', []):
            sub[max(0, ey0 - y0):max(0, ey1 - y0), max(0, ex0 - x0):max(0, ex1 - x0), 3] = 0
        if opt.get('strip') == 'black':
            sub[(sub[:, :, :3].astype(int).sum(axis=2) < 60), 3] = 0
        if opt.get('strip') == 'olive':
            r, g, b = (sub[:, :, i].astype(int) for i in range(3))
            sub[(r > 110) & (g > 90) & (b < 70) & (r - b > 70), 3] = 0
        ys, xs = np.where(sub[:, :, 3] > 0)
        if len(xs) == 0: print('VIDE', name); continue
        crop = sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        Image.fromarray(crop).save(f'{OUT}/{prefix}{name}.png')
        index[name] = [int(x0 + xs.min()), int(y0 + ys.min()), int(crop.shape[1]), int(crop.shape[0])]
    return index
idx = {}
idx.update(cut(SRC + '/poison.png', POISON, 'atk_', (0, 128, 128)))
idx.update(cut(SRC + '/dragon.png', DRAGON, 'atk_', (0, 128, 128)))
idx.update(cut(SRC + '/joshr.png', JOSHR, 'atk_', (199, 225, 209)))
json.dump(idx, open(HERE + '/index.json', 'w'), indent=1)
print(len(idx))

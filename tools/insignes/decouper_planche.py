"""Découpe la planche des médailles (tools/insignes/planche/Medal.png) en insignes.
Écrit graphics/interface/insignes/<id>.png (32x32, fond transparent) et Data/configs/plugins/insignes.json (le catalogue :
noms, descriptions, fichier de chaque insigne). Le catalogue peut être modifié à la main : relancer ce script le réécrit,
sauf si on lui passe --sans-catalogue (pour ne toucher qu'aux images).
Planche : 6 couleurs de 4 lignes (8 médailles, 4 ailées, 8, 8) de cases de 32x32 (pas 32 en x, 34 en y).
Utilisation : python tools/insignes/decouper_planche.py [--sans-catalogue]
"""
import json
import os
import sys

from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.join(ICI, '..', '..')
PLANCHE = os.path.join(ICI, 'planche', 'Medal.png')
SORTIE = os.path.join(RACINE, 'graphics', 'interface', 'insignes')
CATALOGUE = os.path.join(RACINE, 'Data', 'configs', 'plugins', 'insignes.json')
FOND = (80, 136, 176)
CASE = 32
PAS_Y = 34

COULEURS = [  # id, français, anglais
    ('bronze', 'bronze', 'bronze'), ('bleu', 'bleu', 'blue'), ('rouge', 'rouge', 'red'),
    ('rose', 'rose', 'pink'), ('or', 'or', 'gold'), ('argent', 'argent', 'silver'),
]
# motifs : id -> (français, anglais, description française, anglaise) ; {n} = palier
MOTIFS = {
    'ball': ('Poké Ball', 'Poké Ball', 'orné d’une Poké Ball', 'decorated with a Poké Ball'),
    'heart': ('Cœur', 'Heart', 'orné d’un cœur', 'decorated with a heart'),
    'sun': ('Soleil', 'Sun', 'orné d’un soleil', 'decorated with a sun'),
    'crown': ('Couronne', 'Crown', 'orné d’une couronne', 'decorated with a crown'),
    'stars': ('Étoiles', 'Stars', 'orné d’étoiles', 'decorated with stars'),
    'wing_ball': ('Poké Ball ailée', 'Winged Poké Ball', 'orné d’une Poké Ball aux ailes déployées', 'decorated with a Poké Ball with spread wings'),
    'wing_sun': ('Soleil ailé', 'Winged Sun', 'orné d’un soleil aux ailes déployées', 'decorated with a sun with spread wings'),
    'wing_heart': ('Cœur ailé', 'Winged Heart', 'orné d’un cœur aux ailes déployées', 'decorated with a heart with spread wings'),
    'wing_crown': ('Couronne ailée', 'Winged Crown', 'orné d’une couronne aux ailes déployées', 'decorated with a crown with spread wings'),
    'honor': ('Honneur', 'Honor', 'd’honneur, en forme de cœur ailé semé d’étoiles', 'of honor, shaped like a winged heart scattered with stars'),
    'mystery': ('Mystère', 'Mystery', 'marqué d’un point d’interrogation', 'marked with a question mark'),
}
ROMAIN = ['', 'I', 'II', 'III', 'IV', 'V', 'VI']

# (ligne dans la couleur, colonne) -> (motif, palier) ; palier 0 = pas de palier
def disposition():
    out = {}
    for c in range(4):
        out[(0, c)] = ('ball', c + 1)
        out[(0, c + 4)] = ('heart', c + 1)
        out[(2, c)] = ('sun', c + 1)
        out[(2, c + 4)] = ('crown', c + 1)
    for c, m in enumerate(['wing_ball', 'wing_sun', 'wing_heart', 'wing_crown']):
        out[(1, c)] = (m, 0)
    for c in range(6):
        out[(3, c)] = ('stars', c + 1)
    out[(3, 6)] = ('honor', 0)
    out[(3, 7)] = ('mystery', 0)
    return out


def fiche(couleur, motif, palier):
    cid, c_fr, c_en = couleur
    m_fr, m_en, d_fr, d_en = MOTIFS[motif]
    suffixe_fr = f' {ROMAIN[palier]}' if palier and motif != 'stars' else (f' ({palier} étoile{"s" if palier > 1 else ""})' if palier else '')
    suffixe_en = f' {ROMAIN[palier]}' if palier and motif != 'stars' else (f' ({palier} star{"s" if palier > 1 else ""})' if palier else '')
    ident = f'{cid}_{motif}' + (f'_{palier}' if palier else '')
    return {
        'id': ident, 'couleur': cid, 'motif': motif, 'palier': palier,
        'nom': [f'Insigne {m_fr} {c_fr}{suffixe_fr}', f'{c_en.capitalize()} {m_en} Emblem{suffixe_en}'],
        'description': [f'Un insigne {c_fr} {d_fr}.', f'A {c_en} emblem {d_en}.'],
    }


def main():
    planche = Image.open(PLANCHE).convert('RGBA')
    os.makedirs(SORTIE, exist_ok=True)
    grille = disposition()
    liste = []
    for g, couleur in enumerate(COULEURS):
        for (ligne, colonne), (motif, palier) in sorted(grille.items()):
            x = 2 + CASE * colonne
            y = 2 + PAS_Y * (4 * g + ligne)
            case = planche.crop((x, y, x + CASE, y + CASE))
            px = case.load()
            for j in range(CASE):
                for i in range(CASE):
                    if px[i, j][:3] == FOND:
                        px[i, j] = (0, 0, 0, 0)
            fic = fiche(couleur, motif, palier)
            case.save(os.path.join(SORTIE, fic['id'] + '.png'))
            liste.append(fic)
    if '--sans-catalogue' not in sys.argv:
        os.makedirs(os.path.dirname(CATALOGUE), exist_ok=True)
        with open(CATALOGUE, 'w', encoding='utf-8') as f:
            json.dump({'couleurs': [{'id': c[0], 'nom': [c[1], c[2]]} for c in COULEURS], 'insignes': liste}, f, ensure_ascii=False, indent=1)
            f.write('\n')
    print(len(liste), 'insignes écrits dans', os.path.normpath(SORTIE))


if __name__ == '__main__':
    main()

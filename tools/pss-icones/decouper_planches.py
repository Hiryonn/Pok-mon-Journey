#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Découpe la planche des icônes PSS (planches/PSS_Icon_2.png) en pièces de 40x40 sur fond transparent.

Sortie (dans le projet) :
  graphics/icones_pss/pieces/<categorie>/<serie>_<nom>.png
  Data/configs/plugins/icone_pss_pieces.json   (catalogue lu par l'outil Studio et par le plugin « icone_pss »)

Usage (depuis la racine du projet) :  python tools/pss-icones/decouper_planches.py
Nécessite Pillow (pip install pillow).

La planche est une grille de cases de 40x40 sur fond vert (0,255,80) ; le bleu-vert (0,128,128) marque une case vide.
Toutes les pièces sont déjà à leur place dans la case : on les empile simplement les unes sur les autres.
Les 4 premières lignes (icônes toutes faites) ne sont pas découpées : le générateur crée de nouvelles icônes.
"""
import json
import os
import shutil
import sys

from PIL import Image

RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
PLANCHE = os.path.join(os.path.dirname(__file__), 'planches', 'PSS_Icon_2.png')
SORTIE_PIECES = os.path.join(RACINE, 'graphics', 'icones_pss', 'pieces')
SORTIE_JSON = os.path.join(RACINE, 'Data', 'configs', 'plugins', 'icone_pss_pieces.json')

TAILLE = 40
FOND = (0, 255, 80)
VIDE = (0, 128, 128)

# Ordre des couches, de l'arrière vers l'avant
COUCHES = ['hair_back', 'top', 'skin', 'eyes', 'fringe', 'hair_front', 'accessory', 'hat']

# Couleurs (même ordre que dans la planche)
COULEURS_CHEVEUX = [('noir', 'black'), ('marron', 'brown'), ('châtain clair', 'tan'), ('roux', 'orange'), ('blond', 'blonde')]
COULEURS_HAUTS = ['noir', 'blanc', 'gris', 'marron', 'rouge', 'bleu', 'vert', 'orange', 'violet', 'rose', 'bleu clair', 'rouge orangé', 'vert clair']


def detecter_grille(img):
    """Positions (x, y) de chaque case, d'après les cases qui ne sont pas entièrement bleu-vert."""
    px = img.load()
    largeur, hauteur = img.size

    def bandes(longueur, est_plein):
        res, debut = [], None
        for i in range(longueur):
            plein = est_plein(i)
            if plein and debut is None:
                debut = i
            if not plein and debut is not None:
                res.append((debut, i - debut))
                debut = None
        if debut is not None:
            res.append((debut, longueur - debut))
        return res

    lignes = bandes(hauteur, lambda y: any(px[x, y][:3] != VIDE for x in range(largeur)))
    colonnes = bandes(largeur, lambda x: any(px[x, y][:3] != VIDE for y in range(hauteur)))
    lignes = [y for y, n in lignes if n == TAILLE]
    colonnes = [x for x, n in colonnes if n == TAILLE]
    return lignes, colonnes


def main():
    img = Image.open(PLANCHE).convert('RGB')
    lignes, colonnes = detecter_grille(img)
    nb_col = len(colonnes)
    print(f'grille : {len(lignes)} lignes x {nb_col} colonnes')
    if (len(lignes), nb_col) != (22, 19):
        sys.exit('La planche n\'a pas la forme attendue (22 lignes x 19 colonnes).')

    def case(l, c):
        x, y = colonnes[c], lignes[l]
        rgba = Image.new('RGBA', (TAILLE, TAILLE))
        src, dst = img.crop((x, y, x + TAILLE, y + TAILLE)).load(), rgba.load()
        vide = True
        for j in range(TAILLE):
            for i in range(TAILLE):
                p = src[i, j]
                if p == FOND or p == VIDE:
                    dst[i, j] = (0, 0, 0, 0)
                else:
                    dst[i, j] = p + (255,)
                    vide = False
        return None if vide else rgba

    def suite(l, c, n):
        """n cases à la suite, en passant à la ligne suivante au bout de la ligne."""
        res = []
        for _ in range(n):
            res.append((l, c))
            c += 1
            if c == nb_col:
                l, c = l + 1, 0
        return res

    def couleur_dominante(im):
        # couleur la plus fréquente parmi les pixels ni très sombres (contours) ni transparents
        compte = {}
        px = im.load()
        for j in range(im.size[1]):
            for i in range(im.size[0]):
                p = px[i, j]
                if p[3] and sum(p[:3]) > 150:
                    compte[p[:3]] = compte.get(p[:3], 0) + 1
        if not compte:
            return '#808080'
        r, g, b = max(compte, key=compte.get)
        return '#%02x%02x%02x' % (r, g, b)

    if os.path.isdir(SORTIE_PIECES):
        shutil.rmtree(SORTIE_PIECES)
    nb = [0]

    def ecrire(categorie, nom, pos):
        im = case(*pos)
        if im is None:
            sys.exit(f'Case vide en ligne {pos[0]}, colonne {pos[1]} ({categorie}/{nom}).')
        dossier = os.path.join(SORTIE_PIECES, categorie)
        os.makedirs(dossier, exist_ok=True)
        im.save(os.path.join(dossier, nom + '.png'))
        nb[0] += 1
        return f'{categorie}/{nom}', couleur_dominante(im)

    cat = {'taille': TAILLE, 'couches': COUCHES, 'series': [], 'couleurs_cheveux': [], 'couleurs_hauts': COULEURS_HAUTS}
    # Un seul chapeau, accessoire, frange ou coiffure à la fois ; les hauts, la peau et les yeux sont obligatoires.
    cat['couleurs_cheveux'] = [{'label': fr, 'id': en} for fr, en in COULEURS_CHEVEUX]

    # --- Les deux séries : A = lignes 4 à 14, B = lignes 15 à 21
    # Les hauts sont sur la planche en deux rangées de 13 couleurs, identiques sauf le rose : une rangée par série.
    def serie(sid, label, hauts, peau, yeux, frange, cheveux, cheveux_seuls, accessoires, chapeaux):
        d = {'id': sid, 'label': label, 'hauts': [], 'hauts_hex': [], 'peau': [], 'yeux': [], 'frange': [], 'cheveux': [], 'accessoires': [], 'chapeaux': []}
        for c, pos in enumerate(hauts, 1):
            f, h = ecrire('top', f'{sid}_c{c:02d}', pos)
            d['hauts'].append(f)
            d['hauts_hex'].append(h)
        for i, pos in enumerate(peau, 1):
            d['peau'].append(ecrire('skin', f'{sid}_{i}', pos)[0])
        for i, pos in enumerate(yeux, 1):
            d['yeux'].append(ecrire('eyes', f'{sid}_{i}', pos)[0])
        for c, pos in enumerate(frange, 1):
            d['frange'].append(ecrire('fringe', f'{sid}_c{c}', pos)[0])
        # cheveux : par style, 5 couleurs x (arrière, avant)
        for s, debut in enumerate(cheveux, 1):
            coul = []
            for c in range(5):
                dos = ecrire('hair_back', f'{sid}_s{s}_c{c + 1}', debut[2 * c])[0]
                face, hex_face = ecrire('hair_front', f'{sid}_s{s}_c{c + 1}', debut[2 * c + 1])
                if sid == 'a' and s == 1:
                    cat['couleurs_cheveux'][c]['hex'] = hex_face
                coul.append({'arriere': dos, 'avant': face})
            d['cheveux'].append({'label': f'Coiffure {s}', 'couleurs': coul})
        if cheveux_seuls:
            s = len(cheveux) + 1
            coul = [{'arriere': ecrire('hair_back', f'{sid}_s{s}_c{c + 1}', pos)[0], 'avant': None} for c, pos in enumerate(cheveux_seuls)]
            d['cheveux'].append({'label': f'Coiffure {s}', 'couleurs': coul})
        for genre, nom, positions in accessoires:
            fichiers = [ecrire('accessory', f'{sid}_{genre}{i}', pos)[0] for i, pos in enumerate(positions, 1)]
            d['accessoires'].append({'genre': genre, 'label': nom, 'fichiers': fichiers})
        for i, pos in enumerate(chapeaux, 1):
            d['chapeaux'].append(ecrire('hat', f'{sid}_{i:02d}', pos)[0])
        return d

    a_cheveux = suite(10, 0, 50)
    cat['series'].append(serie(
        'a', 'Série A', suite(4, 0, 13),
        suite(8, 0, 3), suite(7, 0, 6), suite(9, 0, 5),
        [a_cheveux[i:i + 10] for i in range(0, 50, 10)], suite(12, 12, 5),
        [('barrette', 'Barrettes', suite(4, 13, 6)), ('cristal', 'Cristaux', suite(5, 0, 3)), ('ruban', 'Rubans', suite(5, 3, 4)),
         ('etoile', 'Étoiles', suite(5, 7, 3)), ('noeud', 'Nœuds', suite(5, 10, 5)), ('feuille', 'Feuilles', suite(5, 15, 3))],
        suite(13, 0, 28)))
    b_cheveux = suite(17, 0, 40)
    cat['series'].append(serie(
        'b', 'Série B', [(5, 18)] + suite(6, 0, 12),
        suite(16, 0, 3), suite(15, 0, 6), [],
        [b_cheveux[i:i + 10] for i in range(0, 40, 10)], [],
        [('barrette', 'Barrettes', suite(21, 0, 5)), ('ruban', 'Rubans', suite(21, 5, 4)), ('feuille', 'Feuilles', suite(21, 9, 3))],
        suite(20, 0, 19)))

    os.makedirs(os.path.dirname(SORTIE_JSON), exist_ok=True)
    with open(SORTIE_JSON, 'w', encoding='utf-8') as f:
        json.dump(cat, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'{nb[0]} pièces écrites dans graphics/icones_pss/pieces ; catalogue : Data/configs/plugins/icone_pss_pieces.json')


if __name__ == '__main__':
    main()

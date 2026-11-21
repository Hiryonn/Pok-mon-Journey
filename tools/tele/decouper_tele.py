"""Découpe la planche de la télé (tools/tele/planche/TV_Screen.png) en images pour le plugin tele.
Écrit graphics/interface/tele/ : chaine_1 à 8 (112x80), presentateur_1 à 5 (80x80), icone_dossier, icone_boite, barre_bleu_1/2,
barre_vert, barre_noir, curseur, entete, pied, chaine_petite_1 à 8, fleche_bas/droite/gauche, icone_petite, badge_nouveau, fond (écran de 256x192), ecran_fond (320x240) et fenetre_texte / fenetre_liste (fenêtres blanches
construites avec le coin de la planche).
Utilisation : python tools/tele/decouper_tele.py
"""
import os

from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
PLANCHE = os.path.join(ICI, 'planche', 'TV_Screen.png')
SORTIE = os.path.normpath(os.path.join(ICI, '..', '..', 'graphics', 'interface', 'tele'))

PIECES = {}
for i in range(8):
    PIECES[f'chaine_{i + 1}'] = (2 + 114 * i, 2, 112, 80)
for i in range(5):
    PIECES[f'presentateur_{i + 1}'] = (2 + 82 * i, 86, 80, 80)
PIECES.update({
    'icone_dossier': (2, 170, 32, 32),
    'icone_boite': (68, 238, 32, 32),
    'barre_bleu_1': (102, 238, 32, 32),
    'barre_bleu_2': (136, 238, 32, 32),
    'barre_vert': (170, 238, 32, 32),
    'barre_noir': (204, 238, 32, 32),
    'curseur': (238, 206, 32, 64),
})
CADRE = (2, 206, 64, 64)  # coin de fenêtre (haut gauche)
COIN = 18


def fond(planche):
    """Fond de l'écran : 187 lignes dans la planche, la dernière est répétée jusqu'à 192."""
    src = planche.crop((2, 274, 258, 461))
    img = Image.new('RGBA', (256, 192))
    img.paste(src, (0, 0))
    ligne = src.crop((0, 186, 256, 187))
    for y in range(187, 192):
        img.paste(ligne, (0, y))
    return img


def fenetre(planche, largeur, hauteur):
    """Fenêtre blanche : le coin de la planche est retourné aux quatre angles, les bords sont étirés."""
    cadre = planche.crop((CADRE[0], CADRE[1], CADRE[0] + CADRE[2], CADRE[1] + CADRE[3]))
    coin = cadre.crop((0, 0, COIN, COIN))
    bord_h = cadre.crop((COIN, 0, COIN + 1, COIN))      # bord haut (1 px de large)
    bord_v = cadre.crop((0, COIN, COIN, COIN + 1))      # bord gauche (1 px de haut)
    img = Image.new('RGBA', (largeur, hauteur), (0, 0, 0, 0))
    img.alpha_composite(coin, (0, 0))
    img.alpha_composite(coin.transpose(Image.FLIP_LEFT_RIGHT), (largeur - COIN, 0))
    img.alpha_composite(coin.transpose(Image.FLIP_TOP_BOTTOM), (0, hauteur - COIN))
    img.alpha_composite(coin.transpose(Image.ROTATE_180), (largeur - COIN, hauteur - COIN))
    haut = bord_h.resize((largeur - 2 * COIN, COIN))
    gauche = bord_v.resize((COIN, hauteur - 2 * COIN))
    img.alpha_composite(haut, (COIN, 0))
    img.alpha_composite(haut.transpose(Image.FLIP_TOP_BOTTOM), (COIN, hauteur - COIN))
    img.alpha_composite(gauche, (0, COIN))
    img.alpha_composite(gauche.transpose(Image.FLIP_LEFT_RIGHT), (largeur - COIN, COIN))
    # intérieur blanc : tout ce qui n'est pas atteint depuis l'extérieur sans traverser le trait sombre
    pix = img.load()
    dehors = set()
    pile = [(x, y) for x in range(largeur) for y in (0, hauteur - 1)] + [(x, y) for y in range(hauteur) for x in (0, largeur - 1)]
    while pile:
        x, y = pile.pop()
        if (x, y) in dehors or not (0 <= x < largeur and 0 <= y < hauteur) or pix[x, y][3] >= 100:
            continue
        dehors.add((x, y))
        pile += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    blanc = Image.new('RGBA', (largeur, hauteur), (0, 0, 0, 0))
    bp = blanc.load()
    for y in range(hauteur):
        for x in range(largeur):
            if (x, y) not in dehors:
                bp[x, y] = (255, 255, 255, 255)
    blanc.alpha_composite(img)
    return blanc


def ecran_fond():
    """Fond du 320x240 autour de l'écran de 256x192 : dégradé sombre."""
    img = Image.new('RGBA', (320, 240))
    pix = img.load()
    for y in range(240):
        v = 18 + y // 12
        for x in range(320):
            pix[x, y] = (v, v + 4, v + 16, 255)
    return img


def derives(planche):
    """Images déduites de la planche : bandeaux, petites chaînes, flèches, pastille « nouveau »."""
    images = {}
    for nom, (x, y, w, h) in (('entete', PIECES['barre_bleu_1']), ('pied', PIECES['barre_noir'])):
        tuile = planche.crop((x, y, x + 32, y + 20))
        img = Image.new('RGBA', (256, 20))
        for i in range(8):
            img.paste(tuile, (32 * i, 0))
        images[nom] = img
    for i in range(8):
        x, y, w, h = PIECES[f'chaine_{i + 1}']
        images[f'chaine_petite_{i + 1}'] = planche.crop((x, y, x + w, y + h)).resize((56, 40), Image.BOX)
    x, y, w, h = PIECES['curseur']
    curseur = planche.crop((x, y, x + w, y + h))
    images['fleche_bas'] = curseur.resize((10, 20), Image.BOX)
    images['fleche_droite'] = curseur.rotate(90, expand=True).resize((20, 10), Image.BOX)
    images['fleche_gauche'] = curseur.rotate(-90, expand=True).resize((20, 10), Image.BOX)
    x, y, w, h = PIECES['icone_dossier']
    images['icone_petite'] = planche.crop((x, y, x + w, y + h)).resize((16, 16), Image.BOX)
    x, y, w, h = PIECES['barre_vert']
    images['badge_nouveau'] = planche.crop((x, y + 12, x + 32, y + 28)).resize((56, 16), Image.BOX)
    return images


def main():
    planche = Image.open(PLANCHE).convert('RGBA')
    os.makedirs(SORTIE, exist_ok=True)
    for nom, (x, y, w, h) in PIECES.items():
        planche.crop((x, y, x + w, y + h)).save(os.path.join(SORTIE, nom + '.png'))
    for nom, img in derives(planche).items():
        img.save(os.path.join(SORTIE, nom + '.png'))
    fond(planche).save(os.path.join(SORTIE, 'fond.png'))
    ecran_fond().save(os.path.join(SORTIE, 'ecran_fond.png'))
    fenetre(planche, 240, 58).save(os.path.join(SORTIE, 'fenetre_texte.png'))
    fenetre(planche, 240, 106).save(os.path.join(SORTIE, 'fenetre_liste.png'))
    print(len(os.listdir(SORTIE)), 'images écrites dans', SORTIE)


if __name__ == '__main__':
    main()

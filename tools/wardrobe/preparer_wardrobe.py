"""Prépare les images du plugin wardrobe à partir des planches de tools/wardrobe/planche/.
Écrit graphics/interface/wardrobe/ : fond (320x240 : la salle d'essayage + le panneau + la barre d'aide), rideau_1 à 9 (le rideau
qui se ferme / s'ouvre, 105 de large au plus), marqueur (tenue portée), curseur (ligne choisie), fleche_haut / fleche_bas,
et graphics/interface/bag_pe/tab_9.png (onglet « Tenues » du sac).
Utilisation : python tools/wardrobe/preparer_wardrobe.py
"""
import os

from PIL import Image, ImageChops, ImageDraw

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.normpath(os.path.join(ICI, '..', '..'))
PLANCHE = os.path.join(ICI, 'planche')
SORTIE = os.path.join(RACINE, 'graphics', 'interface', 'wardrobe')
SAC = os.path.join(RACINE, 'graphics', 'interface', 'bag_pe')

# rideau : x, largeur de chaque image dans la planche (ancrées à droite de l'alcôve)
RIDEAU = [(0, 105), (116, 94), (235, 80), (350, 70), (470, 55), (591, 39), (707, 28), (820, 20), (933, 12)]
PANNEAU_X = 142       # le panneau (178 de large dans la planche) recouvre la droite de la salle
BARRE = (50, 50, 54, 255)
BARRE_H = 20


def fond():
    salle = Image.open(os.path.join(PLANCHE, 'salle.png')).convert('RGBA')
    img = Image.new('RGBA', (320, 240), (0, 0, 0, 255))
    img.alpha_composite(salle.crop((0, 2, 178, 242)), (0, 0))
    # le sac à dos de la planche dépasse un peu à gauche du panneau : on recopie le sol
    for x in range(139, PANNEAU_X):
        for y in range(160, 205):
            img.putpixel((x, y), img.getpixel((138, y)))
    img.alpha_composite(salle.crop((178, 2, 356, 242)), (PANNEAU_X, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 240 - BARRE_H, PANNEAU_X - 1, 239), fill=BARRE)
    d.line((0, 240 - BARRE_H, PANNEAU_X - 1, 240 - BARRE_H), fill=(110, 110, 120, 255))
    return img


def rideau():
    planche = Image.open(os.path.join(PLANCHE, 'rideau.png')).convert('RGBA')
    return [planche.crop((x, 0, x + w, 96)) for x, w in RIDEAU]


def curseur():
    img = Image.new('RGBA', (160, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, 159, 19), radius=4, fill=(222, 238, 246, 255), outline=(112, 120, 144, 255))
    d.rounded_rectangle((1, 1, 158, 18), radius=3, outline=(255, 255, 255, 255))
    return img


def fleche(haut):
    img = Image.new('RGBA', (11, 6), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(0, 5), (10, 5), (5, 0)] if haut else [(0, 0), (10, 0), (5, 5)]
    d.polygon(pts, fill=(112, 120, 144, 255))
    return img


def onglet():
    """Onglet « Tenues » : le fanion de l'onglet des favoris, recoloré, avec un tee-shirt."""
    img = Image.open(os.path.join(SAC, 'tab_8.png')).convert('RGBA')
    base = img.getpixel((3, 3))
    rose = (226, 132, 198, 255)
    pix = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if pix[x, y][3] == 0:
                continue
            if 4 <= x <= 23 and 3 <= y <= 21:
                pix[x, y] = rose                      # efface le cœur
            elif pix[x, y][:3] == base[:3]:
                pix[x, y] = rose
            else:                                      # bords (ombre du fanion)
                r, g, b, a = pix[x, y]
                pix[x, y] = (min(255, r), g, b, a) if False else pix[x, y]
    # tee-shirt 14x12 : forme, contour blanc, remplissage bleu nuit
    masque = Image.new('L', (28, 28), 0)
    d = ImageDraw.Draw(masque)
    d.rectangle((9, 8, 18, 18), fill=255)             # corps
    d.polygon([(9, 8), (4, 11), (6, 14), (9, 12)], fill=255)    # manche gauche
    d.polygon([(18, 8), (23, 11), (21, 14), (18, 12)], fill=255)  # manche droite
    d.rectangle((12, 7, 15, 8), fill=0)               # col
    contour = ImageChops.subtract(masque.filter(__import__('PIL.ImageFilter', fromlist=['MaxFilter']).MaxFilter(3)), masque)
    nuit = (37, 52, 100, 255)
    for y in range(28):
        for x in range(28):
            if contour.getpixel((x, y)) and pix[x, y][3]:
                pix[x, y] = (255, 255, 255, 255)
    for y in range(28):
        for x in range(28):
            if masque.getpixel((x, y)):
                pix[x, y] = nuit
    return img


def main():
    os.makedirs(SORTIE, exist_ok=True)
    fond().save(os.path.join(SORTIE, 'fond.png'))
    for i, image in enumerate(rideau()):
        image.save(os.path.join(SORTIE, f'rideau_{i + 1}.png'))
    Image.open(os.path.join(PLANCHE, 'marqueur.png')).convert('RGBA').save(os.path.join(SORTIE, 'marqueur.png'))
    curseur().save(os.path.join(SORTIE, 'curseur.png'))
    fleche(True).save(os.path.join(SORTIE, 'fleche_haut.png'))
    fleche(False).save(os.path.join(SORTIE, 'fleche_bas.png'))
    onglet().save(os.path.join(SAC, 'tab_9.png'))
    print('images écrites dans', SORTIE, 'et', os.path.join(SAC, 'tab_9.png'))


if __name__ == '__main__':
    main()

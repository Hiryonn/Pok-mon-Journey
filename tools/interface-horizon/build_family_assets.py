# Résumé Horizon : graphismes de la page « Arbre familial » (graphics/interface/summary_pe/)
#   python tools/interface-horizon/build_family_assets.py
# - page_family.png (320 x 214) : cadre gris de gauche (comme la page Mémo) et, à droite, la bande sombre
#   avec les deux parents (cartes claires) et leurs parents (petites cases), reliés par des traits
# - family_unknown.png (32 x 32) : plaque « ? » pour un parent inconnu
# (lancer après recolor_summary.py : la page reprend le cadre de page_memo, puis passe aux couleurs Horizon)
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'graphics', 'interface', 'summary_pe')

DARK, MID, MID2, GREY, LIGHT, WHITE = (35, 35, 35), (61, 61, 61), (81, 81, 81), (138, 138, 138), (183, 183, 189), (255, 255, 255)
PINK = (224, 66, 101)

# Positions (reprises par la page Ruby : 012 Page Arbre familial.rb)
CARD_X, CARD_W, CARD_H = 128, 184, 30
CARD_Y = (58, 132)
GRAND_X = (232, 274)
GRAND_W, GRAND_H = 38, 34
GRAND_DY = 36


def page():
    im = Image.new('RGBA', (320, 214), (0, 0, 0, 0))
    memo = Image.open(os.path.join(OUT, 'page_memo.png')).convert('RGBA')
    im.alpha_composite(memo.crop((0, 0, 124, 214)), (0, 0))         # cadre gris de gauche (sans la bande)
    d = ImageDraw.Draw(im)
    # bande sombre de droite, haute, avec le biseau du design
    d.polygon([(124, 48), (319, 48), (319, 205), (124, 205), (118, 196), (118, 57)], fill=DARK)
    d.line((124, 50, 319, 50), fill=MID)
    for i, y in enumerate(CARD_Y):
        # carte du parent
        d.rounded_rectangle((CARD_X, y, CARD_X + CARD_W - 1, y + CARD_H - 1), 3, fill=GREY)
        d.rounded_rectangle((CARD_X + 1, y + 1, CARD_X + CARD_W - 2, y + CARD_H - 2), 2, fill=LIGHT)
        d.rounded_rectangle((CARD_X + 2, y + 2, CARD_X + 33, y + CARD_H - 3), 2, fill=WHITE)   # case de l'icône
        d.line((CARD_X + 3, y + CARD_H, CARD_X + CARD_W - 1, y + CARD_H), fill=MID)          # ombre
        # traits vers les grands-parents
        gy = y + GRAND_DY
        x_mid = CARD_X + 70
        d.line((x_mid, y + CARD_H + 1, x_mid, gy + GRAND_H // 2), fill=MID2, width=2)
        d.line((x_mid, gy + GRAND_H // 2, GRAND_X[0], gy + GRAND_H // 2), fill=MID2, width=2)
        d.line((GRAND_X[0] + GRAND_W, gy + GRAND_H // 2, GRAND_X[1], gy + GRAND_H // 2), fill=MID2, width=2)
        for gx in GRAND_X:
            d.rounded_rectangle((gx, gy, gx + GRAND_W - 1, gy + GRAND_H - 1), 3, fill=GREY)
            d.rounded_rectangle((gx + 1, gy + 1, gx + GRAND_W - 2, gy + GRAND_H - 2), 2, fill=LIGHT)
            d.line((gx + 2, gy + GRAND_H, gx + GRAND_W - 1, gy + GRAND_H), fill=MID)
    return im


def unknown():
    """Plaque « ? » (parent inconnu)."""
    q = ['.####.', '##..##', '....##', '...##.', '..##..', '..##..', '......', '..##..', '..##..']
    big = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    dd = ImageDraw.Draw(big)
    dd.rounded_rectangle((5, 3, 26, 28), 3, fill=GREY)
    dd.rounded_rectangle((6, 4, 25, 27), 2, fill=MID2)
    for y, row in enumerate(q):
        for x, c in enumerate(row):
            if c == '#':
                dd.rectangle((10 + x * 2 + 1, 6 + y * 2 + 1, 11 + x * 2 + 1, 7 + y * 2 + 1), fill=DARK)
    for y, row in enumerate(q):
        for x, c in enumerate(row):
            if c == '#':
                dd.rectangle((10 + x * 2, 6 + y * 2, 11 + x * 2, 7 + y * 2), fill=WHITE)
    return big


def main():
    page().save(os.path.join(OUT, 'page_family.png'))
    unknown().save(os.path.join(OUT, 'family_unknown.png'))
    # couleurs Horizon (comme le reste du résumé)
    import recolor_summary
    for name in ('page_family.png', 'family_unknown.png'):
        recolor_summary.recolor(os.path.join(OUT, name))
    print('Images écrites dans', OUT)


if __name__ == '__main__':
    main()

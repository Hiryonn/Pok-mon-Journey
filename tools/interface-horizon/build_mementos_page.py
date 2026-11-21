# Résumé Horizon : graphismes de la page « Souvenirs » (graphics/interface/summary_pe/)
#   python tools/interface-horizon/build_mementos_page.py
# - page_mementos.png (320 x 214) : page Mémo + filet sous l'en-tête de la bande sombre (tri, nombre)
# - memento_star.png / memento_star_off.png (9 x 9) : rang obtenu / pas encore obtenu
# - memento_arrow_up.png / memento_arrow_down.png (9 x 5) : la grille défile
# - memento_move.png (40 x 40) : souvenir en cours de déplacement
# (lancer après recolor_summary.py : la page reprend le cadre de page_memo, puis passe aux couleurs Horizon)
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'graphics', 'interface', 'summary_pe')

DARK, MID2, GREY, LIGHT = (35, 35, 35), (81, 81, 81), (138, 138, 138), (183, 183, 189)
GOLD, GOLD_DARK, CYAN = (248, 208, 48), (184, 128, 16), (72, 216, 240)

STAR = ['....#....', '...###...', '...###...', '#########', '.#######.', '..#####..', '.###.###.', '.##...##.', '##.....##']


def page():
    im = Image.open(os.path.join(OUT, 'page_memo.png')).convert('RGBA')
    d = ImageDraw.Draw(im)
    d.line((140, 80, 314, 80), fill=MID2)           # filet sous « Souvenirs ... 3/12 »
    return im


def star(fill, edge):
    im = Image.new('RGBA', (9, 9), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(STAR):
        for x, c in enumerate(row):
            if c == '#':
                px[x, y] = fill + (255,)
    # contour sombre en bas pour le relief
    for y, row in enumerate(STAR):
        for x, c in enumerate(row):
            if c == '#' and (y + 1 >= 9 or STAR[y + 1][x] != '#'):
                px[x, y] = edge + (255,)
    return im


def arrow(up):
    im = Image.new('RGBA', (9, 5), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(5):
        y = 4 - i if up else i
        d.line((i, y, 8 - i, y), fill=LIGHT)
    return im


def move_frame():
    im = Image.new('RGBA', (40, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 39, 39), 4, outline=CYAN, width=2)
    # petites flèches ⇄ dans le coin
    d.rectangle((1, 1, 13, 9), fill=CYAN)
    d.line((3, 3, 10, 3), fill=(255, 255, 255))
    d.point((9, 2), fill=(255, 255, 255))
    d.line((4, 7, 11, 7), fill=(255, 255, 255))
    d.point((5, 8), fill=(255, 255, 255))
    return im


def main():
    page().save(os.path.join(OUT, 'page_mementos.png'))
    star(GOLD, GOLD_DARK).save(os.path.join(OUT, 'memento_star.png'))
    star(GREY, MID2).save(os.path.join(OUT, 'memento_star_off.png'))
    arrow(True).save(os.path.join(OUT, 'memento_arrow_up.png'))
    arrow(False).save(os.path.join(OUT, 'memento_arrow_down.png'))
    move_frame().save(os.path.join(OUT, 'memento_move.png'))
    import recolor_summary
    for name in ('page_mementos.png', 'memento_star_off.png', 'memento_arrow_up.png', 'memento_arrow_down.png'):
        recolor_summary.recolor(os.path.join(OUT, name))
    print('Images écrites dans', OUT)


if __name__ == '__main__':
    main()

# Triple Triad, variante Tetra : graphismes (graphics/interface/triple_triad/)
#   python tools/triple_triad/build_tetra_assets.py
# - tetra_background.png (320 x 240) : fond vert à bandes (comme le Triple Triad) et plateau 4 x 4 en pointillés
#   (cases de 40 x 47, coin haut gauche en 80, 26 : mêmes valeurs que TripleTriad::TETRA_* dans le plugin)
# - tetra_block.png (40 x 47) : case bloquée (vert foncé)
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'graphics', 'interface', 'triple_triad')

GREEN, LINE, PALE, MID, WHITE = (48, 176, 104), (29, 107, 64), (184, 224, 200), (112, 200, 152), (248, 248, 248)
BOARD_X, BOARD_Y, CELL_W, CELL_H, SIZE = 80, 26, 40, 47, 4


def background():
    w, h = 320, 240
    im = Image.new('RGB', (w, h), GREEN)
    d = ImageDraw.Draw(im)
    # bandes des bords (blanc, vert pâle, vert moyen), comme le fond du Triple Triad
    for x0, col in ((0, WHITE), (5, PALE), (12, MID)):
        d.rectangle((x0, 0, x0 + 2 + (2 if col == PALE else 0), h), fill=col)
        d.rectangle((w - 1 - x0 - 2 - (2 if col == PALE else 0), 0, w - 1 - x0, h), fill=col)
    # plateau en pointillés
    right = BOARD_X + CELL_W * SIZE
    bottom = BOARD_Y + CELL_H * SIZE
    for i in range(SIZE + 1):
        x = min(BOARD_X + i * CELL_W, right - 1)
        y = min(BOARD_Y + i * CELL_H, bottom - 1)
        for yy in range(BOARD_Y, bottom, 2):
            im.putpixel((x, yy), LINE)
        for xx in range(BOARD_X, right, 2):
            im.putpixel((xx, y), LINE)
    return im


def block():
    im = Image.new('RGBA', (CELL_W, CELL_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((1, 1, CELL_W - 2, CELL_H - 2), fill=(32, 128, 74))
    d.rectangle((1, 1, CELL_W - 2, 2), fill=LINE)
    d.rectangle((1, 1, 2, CELL_H - 2), fill=LINE)
    return im


def main():
    background().save(os.path.join(OUT, 'tetra_background.png'))
    block().save(os.path.join(OUT, 'tetra_block.png'))
    print('Images écrites dans', OUT)


if __name__ == '__main__':
    main()

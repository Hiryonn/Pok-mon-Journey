# Pots à baies : graphismes du jeu (graphics/interface/pots_baies/), aux couleurs de l'interface Horizon
#   python tools/pots_baies/build_pots_baies_assets.py [dossier « BerryPots v21 1.2 » d'Essentials]
# - cans/<objet>.png (44 x 62) et cans/<objet>_anim.png (2 images) : arrosoirs de « BerryPots » (Caruban),
#   réduits de moitié (les images d'Essentials ont des pixels doublés). Sans dossier source, ceux déjà là sont gardés.
# - pot_dry.png, pot_damp.png, pot_wet.png (40 x 30) : pot en terre, sol sec / humide / mouillé
# - shelf_1.png / shelf_2.png (étagère avec 1 ou 2 planches), side.png (colonne de droite : arrosoir et Quitter)
# - cursor.png (curseur d'un pot, 2 images), cursor_can.png (curseur de l'arrosoir, 2 images), quit.png (bouton, 2 états)
# - arrows.png (flèches haut / bas, 2 images), info.png (bandeau du bas), drop.png (gouttes du sol : 3 états)
import os
import sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'graphics', 'interface', 'pots_baies')
SRC = sys.argv[1] if len(sys.argv) > 1 else None

LIGHT, SHEEN, PALE, SKY = (229, 243, 250), (250, 253, 254), (213, 238, 248), (145, 201, 247)
BLUE, STEEL, SLATE, DEEP = (80, 126, 166), (69, 103, 129), (51, 71, 81), (36, 52, 62)
WOOD, WOOD_D, WOOD_L = (176, 128, 84), (120, 82, 52), (208, 164, 116)
CLAY, CLAY_D, CLAY_L, CLAY_DD = (206, 112, 72), (160, 78, 48), (232, 150, 104), (112, 52, 34)
# Sol : sec, humide, mouillé (fond, grain, reflet)
SOILS = {
    'dry': ((176, 134, 92), (150, 110, 74), (198, 160, 118)),
    'damp': ((122, 84, 56), (98, 66, 44), (146, 104, 72)),
    'wet': ((76, 50, 36), (58, 38, 28), (120, 150, 176)),
}
# Arrosoirs d'Essentials -> objets de Studio
CANS = {'WAILMERPAIL': 'wailmer_pail', 'SPRINKLOTAD': 'sprinklotad', 'SQUIRTBOTTLE': 'squirt_bottle', 'SPRAYDUCK': 'sprayduck'}


def save(im, *path):
    p = os.path.join(OUT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)


def panel(w, h, fill, border, radius=3):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=border)
    d.rounded_rectangle((1, 1, w - 2, h - 2), max(radius - 1, 0), fill=fill)
    return im


def halve(path):
    im = Image.open(path).convert('RGBA')
    return im.resize((im.width // 2, im.height // 2), Image.NEAREST)


def import_sources():
    ui = os.path.join(SRC, 'Graphics', 'UI', 'BerryPots')
    for name, item in CANS.items():
        for suffix in ('', '_anim'):
            f = os.path.join(ui, name + suffix + '.png')
            if os.path.exists(f):
                save(halve(f), 'cans', item + suffix + '.png')


def pot(soil):
    """Pot en terre cuite vu de trois quarts : bord, sol (selon l'humidité), corps arrondi, ombre."""
    w, h = 40, 30
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    base, grain, shine = SOILS[soil]
    d.ellipse((6, 24, 33, 29), fill=(36, 52, 62, 70))                 # ombre
    d.polygon([(4, 7), (35, 7), (31, 26), (8, 26)], fill=CLAY_DD)      # contour du corps
    d.polygon([(5, 7), (34, 7), (30, 25), (9, 25)], fill=CLAY)
    d.polygon([(25, 8), (34, 8), (30, 25), (24, 25)], fill=CLAY_D)    # côté à l'ombre
    d.line((10, 10, 11, 22), fill=CLAY_L)                              # reflet
    d.line((9, 25, 30, 25), fill=CLAY_DD)
    d.ellipse((1, 1, 38, 12), fill=CLAY_DD)                            # bord
    d.ellipse((2, 2, 37, 11), fill=CLAY_L)
    d.ellipse((4, 3, 35, 10), fill=CLAY_D)
    d.ellipse((5, 4, 34, 10), fill=base)                               # sol
    for x, y in ((9, 6), (14, 8), (20, 5), (26, 7), (30, 6), (17, 7), (23, 9), (11, 8)):
        d.point((x, y), fill=grain)
    if soil == 'wet':
        d.line((11, 5, 15, 5), fill=shine)
        d.line((22, 8, 25, 8), fill=shine)
    elif soil == 'damp':
        d.point([(12, 5), (24, 8)], fill=shine)
    return im


def shelf(rows):
    """Étagère : panneau clair Horizon, une ou deux planches en bois sous les pots."""
    w, h = 246, 158
    im = panel(w, h, SHEEN, STEEL, 6)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((3, 3, w - 4, h - 4), 5, fill=LIGHT)
    for y in range(4, h - 4, 8):           # léger quadrillage
        d.line((4, y, w - 5, y), fill=PALE)
    for x in range(4, w - 4, 8):
        d.line((x, 4, x, h - 5), fill=PALE)
    d.line((5, 3, w - 6, 3), fill=SHEEN)
    planks = [124] if rows == 1 else [77, 149]
    for y in planks:
        d.rectangle((4, y, w - 5, y + 5), fill=WOOD)
        d.line((4, y, w - 5, y), fill=WOOD_L)
        d.line((4, y + 5, w - 5, y + 5), fill=WOOD_D)
        d.line((4, y + 6, w - 5, y + 6), fill=(36, 52, 62, 60))
    return im


def side():
    """Colonne de droite : fenêtre ronde de l'arrosoir, étiquette, place du bouton Quitter."""
    w, h = 58, 158
    im = panel(w, h, SHEEN, STEEL, 6)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((3, 3, w - 4, h - 4), 5, fill=LIGHT)
    d.ellipse((4, 10, 53, 59), fill=STEEL)
    d.ellipse((5, 11, 52, 58), fill=SKY)
    d.ellipse((8, 14, 49, 55), fill=PALE)
    d.arc((8, 14, 49, 55), 200, 290, fill=SHEEN, width=2)
    d.rounded_rectangle((4, 96, w - 5, 110), 3, fill=BLUE)            # étiquette « Arrosoir »
    return im


def brackets(w, h, color, inset=0):
    """Coins de sélection (style des curseurs Horizon)."""
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    a, b, c, e = inset, inset, w - 1 - inset, h - 1 - inset
    n = 8
    for (x, y, dx, dy) in ((a, b, 1, 1), (c, b, -1, 1), (a, e, 1, -1), (c, e, -1, -1)):
        d.line((x, y, x + dx * n, y), fill=DEEP, width=1)
        d.line((x, y, x, y + dy * n), fill=DEEP, width=1)
        d.line((x + dx, y + dy, x + dx * (n - 1), y + dy), fill=color, width=1)
        d.line((x + dx, y + dy, x + dx, y + dy * (n - 1)), fill=color, width=1)
        d.line((x + dx * 2, y + dy * 2, x + dx * (n - 2), y + dy * 2), fill=SHEEN, width=1)
        d.line((x + dx * 2, y + dy * 2, x + dx * 2, y + dy * (n - 2)), fill=SHEEN, width=1)
    return im


def cursor(w, h):
    out = Image.new('RGBA', (w * 2, h), (0, 0, 0, 0))
    out.alpha_composite(brackets(w, h, (240, 140, 48)), (0, 0))
    out.alpha_composite(brackets(w, h, (240, 140, 48), 2), (w, 0))
    return out


def quit_button():
    w, h = 50, 18
    out = Image.new('RGBA', (w, h * 2), (0, 0, 0, 0))
    out.alpha_composite(panel(w, h, PALE, STEEL, 4), (0, 0))
    sel = panel(w, h, BLUE, DEEP, 4)
    ImageDraw.Draw(sel).line((3, 2, w - 4, 2), fill=SKY)
    out.alpha_composite(sel, (0, h))
    return out


def arrows():
    """Flèches haut et bas (2 images chacune) pour changer d'arrosoir : 12 x 8, en ligne."""
    out = Image.new('RGBA', (48, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    for i, up in enumerate((True, True, False, False)):
        x = i * 12
        off = 1 if i % 2 else 0
        if up:
            pts = [(x + 1, 6 - off), (x + 10, 6 - off), (x + 5.5, 1 - off)]
        else:
            pts = [(x + 1, 1 + off), (x + 10, 1 + off), (x + 5.5, 6 + off)]
        d.polygon(pts, fill=DEEP)
        d.polygon([(p[0] + (1 if j == 0 else -1 if j == 1 else 0), p[1] + (1 if up and j < 2 else -1 if not up and j < 2 else 0)) for j, p in enumerate(pts)], fill=(240, 140, 48))
    return out


def info():
    w, h = 308, 20
    im = panel(w, h, SHEEN, STEEL, 4)
    d = ImageDraw.Draw(im)
    d.line((3, 2, w - 4, 2), fill=(255, 255, 255))
    d.rounded_rectangle((2, 2, 5, h - 3), 1, fill=SKY)
    return im


def drops():
    """Humidité du sol : 3 états (sec, humide, mouillé) de 18 x 8 en ligne ; 0, 2 ou 3 gouttes bleues."""
    out = Image.new('RGBA', (54, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    for state, blue in enumerate((0, 2, 3)):
        for i in range(3):
            x = state * 18 + i * 6
            wet = i < blue
            d.polygon([(x + 2, 0), (x + 4, 4), (x + 2, 6), (x, 4)], fill=STEEL if wet else (150, 170, 182))
            d.polygon([(x + 2, 1), (x + 3, 4), (x + 2, 5), (x + 1, 4)], fill=(80, 160, 232) if wet else (210, 222, 230))
    return out


def main():
    if SRC:
        import_sources()
    for soil in SOILS:
        save(pot(soil), f'pot_{soil}.png')
    save(shelf(1), 'shelf_1.png')
    save(shelf(2), 'shelf_2.png')
    save(side(), 'side.png')
    save(cursor(48, 78), 'cursor.png')
    save(cursor(54, 56), 'cursor_can.png')
    save(quit_button(), 'quit.png')
    save(arrows(), 'arrows.png')
    save(info(), 'info.png')
    save(drops(), 'drop.png')
    print('Images écrites dans', OUT)


if __name__ == '__main__':
    main()

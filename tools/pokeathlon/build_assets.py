# Pokéathlon : dessine les images du plugin (graphics/interface/pokeathlon)
#
# Usage : python build_assets.py [dossier du projet]
# Textures reprises de source_hgss.png (planche de HeartGold / SoulSilver : piste, neige, fond bleu, plots, tableau des
# points, Attrape-disques) ; le reste est dessiné ici (terrains vus de dessus, bandeau, écrans).
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..')
OUT = os.path.join(ROOT, 'graphics', 'interface', 'pokeathlon')
SHEET = Image.open(os.path.join(HERE, 'source_hgss.png')).convert('RGBA')
FONT = os.path.join(ROOT, 'Fonts', 'PokemonDS.ttf')
TEAM = [(232, 72, 72), (72, 120, 232), (240, 200, 48), (72, 184, 96)]
DARK = (24, 32, 56)
NAVY = (16, 40, 104)
BLUE = (32, 88, 200)
WHITE = (255, 255, 255)
random.seed(7)


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name + '.png'), optimize=True)


def font(size):
    return ImageFont.truetype(FONT, size)


def crop(x, y, w, h):
    return SHEET.crop((x, y, x + w, y + h))


def tile(texture, w, h):
    out = Image.new('RGBA', (w, h))
    for y in range(0, h, texture.height):
        for x in range(0, w, texture.width):
            out.paste(texture, (x, y))
    return out


def outlined_text(size, text, fill, outline=DARK, width=3):
    f = font(size)
    probe = ImageDraw.Draw(Image.new('RGBA', (1, 1)))
    box = probe.textbbox((0, 0), text, font=f)
    w, h = box[2] - box[0] + width * 2 + 4, box[3] - box[1] + width * 2 + 4
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.text((width + 2 - box[0], width + 2 - box[1]), text, font=f, fill=fill, stroke_width=width, stroke_fill=outline)
    return im


# --- Commun -----------------------------------------------------------------------------------------------------------
def common():
    # bandeau du haut : temps au centre, 4 équipes
    bar = Image.new('RGBA', (320, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(bar)
    d.rectangle((0, 0, 319, 21), fill=(16, 40, 104, 220))
    d.line((0, 21, 319, 21), fill=(96, 152, 248, 255))
    d.rounded_rectangle((128, 2, 192, 19), radius=6, fill=(8, 20, 60, 255), outline=(96, 152, 248, 255))
    save(bar, 'bandeau')
    aide = Image.new('RGBA', (320, 16), (16, 40, 104, 200))
    save(aide, 'aide')
    for i, c in enumerate(TEAM):
        p = Image.new('RGBA', (12, 14), (0, 0, 0, 0))
        d = ImageDraw.Draw(p)
        d.rounded_rectangle((0, 1, 11, 13), radius=3, fill=c + (255,), outline=WHITE)
        save(p, 'pastille_%d' % i)
        ring = Image.new('RGBA', (28, 12), (0, 0, 0, 0))
        d = ImageDraw.Draw(ring)
        d.ellipse((1, 1, 26, 10), outline=c + (255,), width=2)
        d.ellipse((3, 3, 24, 8), fill=c + (70,))
        save(ring, 'anneau_%d' % i)
    for n in (1, 2, 3):
        save(outlined_text(64, str(n), (255, 230, 80), width=4), 'compte_%d' % n)
    save(outlined_text(40, 'Partez !', (255, 255, 255), width=4), 'partez')
    save(outlined_text(40, 'Terminé !', (255, 255, 255), width=4), 'termine')
    cur = Image.new('RGBA', (11, 8), (0, 0, 0, 0))
    ImageDraw.Draw(cur).polygon([(0, 0), (10, 0), (5, 7)], fill=(255, 240, 80, 255), outline=DARK)
    save(cur, 'curseur')
    g = Image.new('RGBA', (64, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    d.rounded_rectangle((0, 0, 63, 9), radius=3, fill=(8, 20, 60, 230), outline=WHITE)
    save(g, 'jauge_fond')
    j = Image.new('RGBA', (60, 6), (0, 0, 0, 0))
    d = ImageDraw.Draw(j)
    for x in range(60):
        t = x / 59
        d.line((x, 0, x, 5), fill=(int(240 - 160 * t), int(80 + 140 * t), 64, 255))
    save(j, 'jauge')


# --- Terrains ---------------------------------------------------------------------------------------------------------
def grass(w=320, h=240, seed=1):
    rnd = random.Random(seed)
    im = Image.new('RGBA', (w, h), (104, 184, 72, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, h, 16):
        if (y // 16) % 2:
            d.rectangle((0, y, w, y + 15), fill=(96, 176, 64, 255))
    for _ in range(w * h // 90):
        x, y = rnd.randrange(w), rnd.randrange(h)
        d.line((x, y, x + 1, y - 2), fill=(80, 152, 56, 255))
    return im


def pennant():
    im = grass(seed=2)
    d = ImageDraw.Draw(im)
    d.rectangle((6, 24, 313, 219), outline=(255, 255, 255, 255), width=2)
    d.line((160, 24, 160, 219), fill=(255, 255, 255, 160), width=1)
    d.ellipse((130, 92, 190, 152), outline=(255, 255, 255, 160), width=1)
    save(im, 'terrain_fanions')
    for i, c in enumerate(TEAM):
        b = Image.new('RGBA', (44, 44), (0, 0, 0, 0))
        d = ImageDraw.Draw(b)
        d.ellipse((1, 1, 42, 42), fill=c + (110,), outline=c + (255,), width=3)
        d.ellipse((10, 10, 33, 33), outline=WHITE + (180,), width=1)
        save(b, 'base_%d' % i)
    fl = Image.new('RGBA', (10, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(fl)
    d.line((2, 1, 2, 13), fill=(80, 64, 48, 255), width=1)
    d.polygon([(3, 1), (9, 4), (3, 7)], fill=(255, 220, 40, 255), outline=(160, 96, 16, 255))
    save(fl, 'fanion')


def track_texture(w, h):
    return tile(crop(380, 40, 64, 64), w, h)


def stands(w, h):
    # tribunes : bandeau du Pokéathlon (stade de la planche) répété
    src = crop(258, 196, 252, 110).resize((252, 110))
    out = Image.new('RGBA', (w, h), (88, 168, 232, 255))
    band = src.crop((0, 0, 252, h))
    for x in range(0, w, 252):
        out.paste(band, (x, 0))
    return out


def hurdle():
    w, h = 384, 202
    im = Image.new('RGBA', (w, h), (0, 0, 0, 255))
    im.paste(stands(w, 44), (0, 0))
    im.paste(track_texture(w, 158), (0, 44))
    d = ImageDraw.Draw(im)
    for i in range(5):
        y = 44 + 4 + i * 38
        d.line((0, y, w, y), fill=(255, 255, 255, 255), width=2)
    for x in range(0, w, 64):
        d.line((x, 46, x, 50), fill=(255, 255, 255, 180))
    save(im, 'piste_haies')
    hd = Image.new('RGBA', (10, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(hd)
    d.rectangle((1, 2, 2, 23), fill=(220, 220, 230, 255))
    d.rectangle((7, 2, 8, 23), fill=(220, 220, 230, 255))
    d.rectangle((0, 2, 9, 7), fill=(240, 240, 255, 255), outline=(200, 40, 40, 255))
    d.rectangle((2, 4, 7, 5), fill=(200, 40, 40, 255))
    save(hd, 'haie')
    line = Image.new('RGBA', (3, 152), (255, 255, 255, 200))
    save(line, 'ligne_relais')
    fin = Image.new('RGBA', (8, 152), (0, 0, 0, 0))
    d = ImageDraw.Draw(fin)
    for y in range(0, 152, 4):
        for x in range(0, 8, 4):
            d.rectangle((x, y, x + 3, y + 3), fill=(255, 255, 255, 255) if (x // 4 + y // 4) % 2 == 0 else (30, 30, 30, 255))
    save(fin, 'arrivee')
    mp = Image.new('RGBA', (300, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(mp)
    d.rounded_rectangle((0, 2, 299, 7), radius=3, fill=(16, 40, 104, 220), outline=WHITE)
    for k in (1, 2):
        d.line((k * 100, 1, k * 100, 8), fill=WHITE)
    save(mp, 'mini_piste')


def relay():
    w, h = 320, 202
    cx, cy = 160, 102
    rx, ry = 138, 84
    lane = 11
    im = grass(w, h, seed=3)
    mask = Image.new('L', (w, h), 0)
    md = ImageDraw.Draw(mask)
    outer = 1.0 + lane / rx
    inner = 1.0 - 4 * lane * 2.0 / rx + lane / rx
    md.ellipse((cx - rx * outer, cy - ry * outer, cx + rx * outer, cy + ry * outer), fill=255)
    md.ellipse((cx - rx * inner, cy - ry * inner, cx + rx * inner, cy + ry * inner), fill=0)
    im.paste(track_texture(w, h), (0, 0), mask)
    d = ImageDraw.Draw(im)
    for k in range(5):
        sc = outer - k * lane * 2.0 / rx
        d.ellipse((cx - rx * sc, cy - ry * sc, cx + rx * sc, cy + ry * sc), outline=(255, 255, 255, 230), width=1)
    # ligne de départ et zone de relais (en bas)
    for k in range(-1, 2):
        a = math.pi / 2 + k * 0.22
        x1, y1 = cx + math.cos(a) * rx * inner, cy + math.sin(a) * ry * inner
        x2, y2 = cx + math.cos(a) * rx * outer, cy + math.sin(a) * ry * outer
        d.line((x1, y1, x2, y2), fill=(255, 255, 255, 255) if k == 0 else (255, 230, 80, 255), width=3 if k == 0 else 1)
    d.ellipse((cx - 40, cy - 20, cx + 40, cy + 20), outline=(255, 255, 255, 120))
    save(im, 'piste_relais')
    rk = Image.new('RGBA', (12, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(rk)
    d.ellipse((0, 2, 11, 9), fill=(40, 30, 20, 90))
    d.polygon([(1, 7), (3, 2), (7, 0), (11, 4), (10, 8)], fill=(150, 140, 130, 255), outline=(80, 70, 64, 255))
    d.line((4, 3, 6, 5), fill=(200, 196, 190, 255))
    save(rk, 'rocher')


def blue_back(w, h):
    # fond bleu à motifs de la planche (Pokéathlon)
    return tile(crop(0, 222, 256, 156), w, h)


def blocks():
    w, h = 320, 202
    im = blue_back(w, h)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((4, 2, 197, 199), radius=8, fill=(12, 28, 80, 230), outline=(96, 152, 248, 255), width=2)
    d.rectangle((8, 160, 193, 196), fill=(150, 104, 64, 255))
    for x in range(8, 194, 12):
        d.line((x, 160, x + 6, 196), fill=(130, 88, 52, 255))
    save(im, 'fond_blocs')
    cols = [(220, 96, 64), (232, 176, 64), (120, 168, 220)]
    big = Image.new('RGBA', (40, 54), (0, 0, 0, 0))
    small = Image.new('RGBA', (20, 27), (0, 0, 0, 0))
    for i, c in enumerate(cols):
        d = ImageDraw.Draw(big)
        d.rectangle((0, i * 18, 39, i * 18 + 17), fill=c + (255,), outline=DARK)
        d.line((2, i * 18 + 2, 37, i * 18 + 2), fill=tuple(min(255, v + 50) for v in c) + (255,))
        d.line((20, i * 18 + 1, 20, i * 18 + 16), fill=DARK)
        d = ImageDraw.Draw(small)
        d.rectangle((0, i * 9, 19, i * 9 + 8), fill=c + (255,), outline=DARK)
    save(big, 'bloc')
    save(small, 'bloc_petit')
    g = Image.new('RGBA', (172, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    d.rounded_rectangle((0, 0, 171, 11), radius=5, fill=(200, 60, 60, 255), outline=WHITE)
    save(g, 'jauge_blocs')
    z = Image.new('RGBA', (164, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(z)
    d.rectangle((0, 0, 163, 7), fill=(240, 200, 48, 255))
    d.rectangle((40, 0, 123, 7), fill=(72, 200, 96, 255))
    save(z, 'zone_blocs')
    n = Image.new('RGBA', (7, 18), (0, 0, 0, 0))
    ImageDraw.Draw(n).polygon([(0, 0), (6, 0), (6, 3), (4, 17), (2, 17), (0, 3)], fill=WHITE, outline=DARK)
    save(n, 'aiguille')
    for i, c in enumerate(TEAM):
        p = Image.new('RGBA', (112, 62), (0, 0, 0, 0))
        d = ImageDraw.Draw(p)
        d.rounded_rectangle((0, 0, 111, 61), radius=6, fill=(12, 28, 80, 230), outline=c + (255,), width=2)
        d.rectangle((2, 2, 109, 18), fill=c + (200,))
        save(p, 'panneau_%d' % i)


def sand(w, h, seed=4):
    rnd = random.Random(seed)
    im = Image.new('RGBA', (w, h), (232, 208, 152, 255))
    d = ImageDraw.Draw(im)
    for _ in range(w * h // 60):
        x, y = rnd.randrange(w), rnd.randrange(h)
        d.point((x, y), fill=(212, 184, 128, 255))
    return im


def circles():
    im = sand(320, 202)
    d = ImageDraw.Draw(im)
    d.rectangle((6, 2, 313, 197), outline=(255, 255, 255, 255), width=2)
    for x in range(0, 320, 40):
        d.line((x, 2, x, 197), fill=(220, 196, 140, 255))
    # plots de la planche sur le bord
    cone = crop(780, 0, 16, 14)
    for x in range(14, 310, 30):
        im.alpha_composite(cone.convert('RGBA'), (x, 186)) if False else None
    save(im, 'terrain_cercles')
    for i, (r, col) in enumerate(((20, (232, 72, 72)), (30, (240, 160, 48)), (42, (72, 160, 232)))):
        c = Image.new('RGBA', (r * 2 + 4, r * 2 + 4), (0, 0, 0, 0))
        d = ImageDraw.Draw(c)
        d.ellipse((1, 1, r * 2 + 2, r * 2 + 2), fill=col + (90,), outline=col + (255,), width=3)
        d.ellipse((r - 2, r - 2, r + 6, r + 6), fill=WHITE + (120,))
        save(c, 'cercle_%d' % i)


def goals():
    im = grass(320, 202, seed=5)
    d = ImageDraw.Draw(im)
    d.rectangle((7, 3, 312, 196), outline=WHITE, width=2)
    d.ellipse((130, 70, 190, 130), outline=WHITE, width=2)
    d.line((8, 100, 312, 100), fill=(255, 255, 255, 120))
    d.line((160, 4, 160, 196), fill=(255, 255, 255, 120))
    half = 34
    sides = [((160 - half, 192), (160 + half, 202)), ((0, 100 - half), (10, 100 + half)), ((160 - half, 0), (160 + half, 6)), ((310, 100 - half), (320, 100 + half))]
    for i, ((x1, y1), (x2, y2)) in enumerate(sides):
        d.rectangle((x1, y1, x2, y2), fill=TEAM[i] + (255,))
        for k in range(x1, x2, 4):
            d.line((k, y1, k, y2), fill=(255, 255, 255, 90))
    save(im, 'terrain_buts')
    for name, r, col in (('ballon', 7, (250, 250, 250)), ('ballon_or', 9, (248, 200, 40))):
        b = Image.new('RGBA', (r * 2 + 2, r * 2 + 2), (0, 0, 0, 0))
        d = ImageDraw.Draw(b)
        d.ellipse((0, 0, r * 2, r * 2), fill=col + (255,), outline=DARK)
        d.polygon([(r, r - 3), (r + 3, r), (r, r + 3), (r - 3, r)], fill=DARK)
        d.point((r - 3, r - 4), fill=WHITE)
        save(b, name)


def snow():
    rnd = random.Random(9)
    im = Image.new('RGBA', (320, 202), (236, 244, 252, 255))
    d = ImageDraw.Draw(im)
    for _ in range(140):
        x, y = rnd.randrange(320), rnd.randrange(202)
        r = rnd.randrange(3, 9)
        d.ellipse((x - r, y - r // 2, x + r, y + r // 2), fill=(214, 228, 244, 255))
        d.arc((x - r, y - r // 2, x + r, y + r // 2), 200, 340, fill=(250, 252, 255, 255))
    for _ in range(300):
        d.point((rnd.randrange(320), rnd.randrange(202)), fill=(196, 214, 236, 255))
    # bords des équipes : bas (joueur), gauche, haut, droite
    zones = [(40, 168, 280, 200), (2, 24, 42, 178), (40, 2, 280, 34), (278, 24, 318, 178)]
    for i, z in enumerate(zones):
        over = Image.new('RGBA', (320, 202), (0, 0, 0, 0))
        ImageDraw.Draw(over).rectangle(z, fill=TEAM[i] + (55,), outline=TEAM[i] + (200,))
        im.alpha_composite(over)
    d = ImageDraw.Draw(im)
    d.rectangle((44, 36, 276, 166), outline=(240, 200, 48, 200), width=2)
    # bonhomme de neige au centre
    d.ellipse((146, 98, 174, 124), fill=WHITE, outline=(150, 176, 216, 255))
    d.ellipse((150, 80, 170, 100), fill=WHITE, outline=(150, 176, 216, 255))
    d.point((156, 88), fill=DARK)
    d.point((163, 88), fill=DARK)
    d.polygon([(159, 91), (166, 93), (159, 94)], fill=(240, 140, 40, 255))
    save(im, 'terrain_neige')
    c = Image.new('RGBA', (20, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    y = (255, 230, 60, 255)
    d.ellipse((2, 2, 17, 17), outline=DARK, width=4)
    d.ellipse((2, 2, 17, 17), outline=y, width=2)
    for a, b in (((10, 0), (10, 5)), ((10, 14), (10, 19)), ((0, 10), (5, 10)), ((14, 10), (19, 10))):
        d.line(a + b, fill=DARK, width=3)
        d.line(a + b, fill=y, width=1)
    save(c, 'cible')
    b = Image.new('RGBA', (8, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(b)
    d.ellipse((0, 0, 7, 7), fill=WHITE, outline=(150, 176, 216, 255))
    save(b, 'boule')
    sh = Image.new('RGBA', (8, 4), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((0, 0, 7, 3), fill=(40, 60, 100, 110))
    save(sh, 'ombre_boule')


def lamps():
    w, h = 320, 202
    im = Image.new('RGBA', (w, h), (0, 0, 0, 255))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / h
        d.line((0, y, w, y), fill=(int(12 + 30 * t), int(16 + 40 * t), int(60 + 70 * t), 255))
    rnd = random.Random(11)
    for _ in range(60):
        x, y = rnd.randrange(w), rnd.randrange(120)
        d.point((x, y), fill=(200, 210, 255, 255))
    # gradins sombres en bas
    im.paste(stands(w, 44).point(lambda v: v // 3), (0, 150))
    d.rectangle((0, 176, w, h), fill=(40, 48, 80, 255))
    save(im, 'fond_lampes')
    t = Image.new('RGBA', (320, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(t)
    d.rectangle((14, 0, 305, 5), fill=(48, 120, 220, 255), outline=WHITE)
    for x in (24, 160, 296):
        d.rectangle((x - 2, 6, x + 2, 15), fill=(160, 160, 180, 255))
    save(t, 'trampoline')
    l = Image.new('RGBA', (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(l)
    d.ellipse((1, 1, 14, 14), fill=(255, 236, 120, 255), outline=(255, 255, 220, 255))
    d.ellipse((4, 4, 9, 9), fill=WHITE)
    d.ellipse((17, 1, 30, 14), fill=(64, 72, 96, 255), outline=(120, 128, 150, 255))
    save(l, 'lampe')


def discs():
    board = crop(776, 196, 242, 188)
    px = board.load()
    for y in range(board.height):
        for x in range(board.width):
            r, g, b, a = px[x, y]
            if (r, g, b) == (150, 255, 34):
                px[x, y] = (0, 0, 0, 0)
    save(board, 'plateforme_disques')
    w, h = 320, 202
    back = Image.new('RGBA', (w, h), (0, 0, 0, 255))
    d = ImageDraw.Draw(back)
    for y in range(h):
        t = y / h
        d.line((0, y, w, y), fill=(int(70 + 40 * t), int(150 + 40 * t), int(230 - 30 * t), 255))
    back.alpha_composite(stands(w, 44), (0, 0))
    save(back, 'fond_disques')
    for name, col in (('disque', (248, 248, 255)), ('disque_or', (248, 200, 40))):
        dk = Image.new('RGBA', (18, 10), (0, 0, 0, 0))
        d = ImageDraw.Draw(dk)
        d.ellipse((0, 0, 17, 9), fill=col + (255,), outline=DARK)
        d.ellipse((6, 3, 11, 6), outline=(180, 180, 200, 255))
        save(dk, name)
    sh = Image.new('RGBA', (18, 10), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((0, 0, 17, 9), fill=(30, 20, 20, 120))
    save(sh, 'ombre_disque')


def ring():
    w, h = 320, 202
    back = blue_back(w, h)
    back.alpha_composite(stands(w, 44), (0, 0))
    save(back, 'fond_anneau')
    r = 78
    size = r * 2 + 12
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = size // 2
    d.ellipse((c - r, c - r + 6, c + r, c + r + 6), fill=(60, 40, 30, 255))
    d.ellipse((c - r, c - r, c + r, c + r), fill=(224, 200, 144, 255), outline=(120, 80, 48, 255), width=3)
    d.ellipse((c - r + 8, c - r + 8, c + r - 8, c + r - 8), outline=(250, 250, 250, 255), width=3)
    d.ellipse((c - 30, c - 30, c + 30, c + 30), outline=(232, 72, 72, 160), width=2)
    for k in range(4):
        a = math.pi / 2 + k * math.pi / 2
        x, y = c + math.cos(a) * r * 0.55, c + math.sin(a) * r * 0.55
        d.ellipse((x - 9, y - 4, x + 9, y + 4), outline=TEAM[k] + (220,), width=2)
    save(im, 'anneau_sumo')


def frame(w, h, fill=(255, 255, 255, 255), edge=(40, 48, 72, 255), radius=4):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=edge)
    d.rounded_rectangle((1, 1, w - 2, h - 2), radius=max(1, radius - 1), fill=fill)
    return im


def menus():
    back = blue_back(320, 240)
    save(back, 'fond_menu')
    t = Image.new('RGBA', (320, 22), (8, 24, 72, 235))
    d = ImageDraw.Draw(t)
    d.line((0, 21, 319, 21), fill=(96, 152, 248, 255))
    save(t, 'titre')
    row = frame(300, 34, (244, 248, 255, 255))
    d = ImageDraw.Draw(row)
    d.rectangle((2, 2, 297, 6), fill=(214, 226, 246, 255))
    save(row, 'ligne')
    sel = frame(300, 34, (255, 244, 176, 255), (232, 120, 32, 255))
    ImageDraw.Draw(sel).rounded_rectangle((0, 0, 299, 33), radius=4, outline=(232, 120, 32, 255), width=2)
    save(sel, 'ligne_sel')
    cols = [(232, 72, 72), (72, 120, 232), (72, 184, 96), (240, 160, 48), (160, 96, 216)]
    for i, c in enumerate(cols):
        b = Image.new('RGBA', (22, 22), (0, 0, 0, 0))
        d = ImageDraw.Draw(b)
        d.ellipse((0, 0, 21, 21), fill=c + (255,), outline=DARK)
        d.ellipse((5, 5, 16, 16), outline=WHITE, width=2)
        save(b, 'coupe_%d' % i)
    for name, col in (('medaille', (240, 184, 48)), ('couronne', (250, 220, 80))):
        m = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(m)
        if name == 'medaille':
            d.polygon([(4, 0), (7, 6), (9, 6), (12, 0)], fill=(232, 72, 72, 255))
            d.ellipse((2, 5, 13, 15), fill=col + (255,), outline=DARK)
            d.ellipse((5, 8, 10, 12), outline=(255, 250, 200, 255))
        else:
            d.polygon([(1, 13), (1, 4), (5, 8), (8, 2), (11, 8), (15, 4), (15, 13)], fill=col + (255,), outline=DARK)
            d.ellipse((7, 9, 9, 11), fill=(232, 72, 72, 255))
        save(m, name)
    save(frame(140, 30, (244, 248, 255, 255)), 'case')
    cs = frame(140, 30, (255, 244, 176, 255), (232, 120, 32, 255))
    save(cs, 'case_sel')
    num = Image.new('RGBA', (42, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(num)
    f = font(13)
    for k in range(3):
        d.ellipse((k * 14, 0, k * 14 + 13, 13), fill=(232, 72, 72, 255), outline=WHITE)
        d.text((k * 14 + 4, 0), str(k + 1), font=f, fill=WHITE)
    save(num, 'numero')
    save(frame(160, 192, (12, 28, 80, 230), (96, 152, 248, 255), 6), 'panneau_perf')
    st = Image.new('RGBA', (27, 9), (0, 0, 0, 0))
    d = ImageDraw.Draw(st)
    def star(ox, fill, outline):
        pts = []
        for k in range(10):
            a = -math.pi / 2 + k * math.pi / 5
            r = 4.4 if k % 2 == 0 else 1.9
            pts.append((ox + 4.5 + r * math.cos(a), 4.6 + r * math.sin(a)))
        d.polygon(pts, fill=fill, outline=outline)
    star(0, (255, 220, 60, 255), (120, 80, 0, 255))
    star(9, (40, 56, 110, 255), (160, 176, 220, 255))
    star(18, (20, 28, 60, 140), None)
    save(st, 'etoile')
    for i, c in enumerate(TEAM):
        e = frame(146, 84, (12, 28, 80, 230), c + (255,), 6)
        ImageDraw.Draw(e).rectangle((2, 2, 143, 19), fill=c + (220,))
        save(e, 'equipe_%d' % i)
        r = frame(300, 36, (12, 28, 80, 230), c + (255,), 6)
        ImageDraw.Draw(r).rectangle((2, 2, 30, 33), fill=c + (220,))
        save(r, 'rang_%d' % i)
    save(frame(300, 172, (12, 28, 80, 230), (96, 152, 248, 255), 6), 'panneau_epreuve')
    pl = Image.new('RGBA', (80, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(pl)
    f = font(16)
    for k, col in enumerate(((250, 210, 60), (210, 216, 230), (214, 150, 90), (150, 160, 190))):
        d.ellipse((k * 20, 0, k * 20 + 19, 19), fill=col + (255,), outline=DARK)
        d.text((k * 20 + 6, 1), str(k + 1), font=f, fill=DARK)
    save(pl, 'places')


def summary():
    """Fond de la page Pokéathlon du résumé (style de page_memo)."""
    src = os.path.join(os.path.dirname(OUT), 'summary_pe', 'page_memo.png')
    im = Image.open(src).convert('RGBA')
    d = ImageDraw.Draw(im)
    d.line((140, 78, 314, 78), fill=(96, 152, 248, 255))
    d.line((140, 157, 314, 157), fill=(70, 96, 112, 255))
    d.line((10, 66, 109, 66), fill=(140, 176, 200, 255))
    save(im, 'resume')


def blender():
    """Mixeur à Noigrumes : case, barres de saveur."""
    c = frame(26, 26, (230, 240, 255, 255), (96, 152, 248, 255), 4)
    save(c, 'case_noigrume')
    b = Image.new('RGBA', (102, 8), (0, 0, 0, 0))
    ImageDraw.Draw(b).rectangle((0, 0, 101, 7), fill=(8, 16, 48, 255), outline=(96, 152, 248, 255))
    save(b, 'barre_fond')
    cols = {'spicy': (232, 72, 72), 'dry': (72, 120, 232), 'sweet': (240, 120, 184), 'bitter': (72, 184, 96), 'sour': (240, 200, 48)}
    for name, c in cols.items():
        bar = Image.new('RGBA', (100, 6), c + (255,))
        d = ImageDraw.Draw(bar)
        d.line((0, 0, 99, 0), fill=tuple(min(255, v + 60) for v in c) + (255,))
        d.line((0, 5, 99, 5), fill=tuple(max(0, v - 60) for v in c) + (255,))
        save(bar, 'barre_' + name)


def arrows():
    """Flèches de défilement (liste des coupes)."""
    for name, pts in (('fleche_haut', [(0, 6), (5, 0), (10, 6)]), ('fleche_bas', [(0, 0), (5, 6), (10, 0)])):
        im = Image.new('RGBA', (11, 7), (0, 0, 0, 0))
        ImageDraw.Draw(im).polygon(pts, fill=(255, 255, 255, 255), outline=(24, 40, 96, 255))
        save(im, name)


if __name__ == '__main__':
    only = os.environ.get('ONLY')
    if only:
        for name in only.split(','):
            globals()[name]()
        sys.exit()
    menus()
    ring()
    discs()
    lamps()
    snow()
    goals()
    circles()
    blocks()
    relay()
    common()
    pennant()
    hurdle()
    summary()
    blender()
    arrows()
    print('Images du Pokéathlon faites dans', OUT)

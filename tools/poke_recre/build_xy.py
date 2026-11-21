# Poké Récré : images de X / Y (planches de tools/poke_recre/sources)
#
# Usage : python build_xy.py [dossier du projet]
#   graphics/interface/poke_recre/
#     fonds/<id>.png          34 décors (320x240) : 18 types, 9 couleurs, 3 nuages, 3 styles, salon
#     deco/<id>.png           décorations (coussins, objets, grandes décorations)
#     pofiteroles.png         26 Pofiteroles (64x64) : 5 lignes de 4 (sucrée, mentholée, aigre, amère, épicée),
#                             puis 6 spéciales
#     main/<nom>.png          main de X / Y en bandes d'images (repos, caresse, pointe, effets des statuts...)
#     bouton_deco.png, bouton_jeux.png  boutons (30x30)
#     cueille/                Cueille-Baies : fond, tas, baies, bulle, nuage, chiffres, notes, étoile, pointeur
#     jongle/                 Jongle-Tête : fond, pelotes, pelote géante, arcs-en-ciel, bulles, chiffres
# Ne touche à aucune autre image.
import os
import sys
from collections import deque

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..')
OUT = os.path.join(ROOT, 'graphics', 'interface', 'poke_recre')
SRC = os.path.join(HERE, 'sources')
W, H = 320, 240

TYPES = ['normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug',
         'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy']
COLORS = ['rouge', 'bleu', 'orange', 'vert', 'violet', 'marron', 'jaune', 'blanc', 'noir']
CLOUDS = ['rose', 'bleu', 'orange']
STYLES = ['pois', 'rayures', 'carreaux']
BACKDROPS = [f'type_{t}' for t in TYPES] + [f'couleur_{c}' for c in COLORS] + [f'nuage_{c}' for c in CLOUDS] + \
            ['style_pois', 'style_rayures', 'style_carreaux', 'salon']


def path(*parts):
    p = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def save(im, *parts):
    im.save(path(*parts))


def src(name):
    return Image.open(os.path.join(SRC, name)).convert('RGBA')


def clear_border_white(im, tolerance=6):
    """Rend transparent le blanc relié au bord (fond des cases), sans toucher au blanc des objets."""
    im = im.copy()
    px = im.load()
    w, h = im.size
    seen = set()
    queue = deque([(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)])

    def white(c):
        return c[3] > 0 and all(v >= 255 - tolerance for v in c[:3])
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        if not white(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def trim(im):
    box = im.getbbox()
    return im.crop(box) if box else im


def backdrops():
    sheet = Image.open(os.path.join(SRC, 'xy_fonds.jpg')).convert('RGBA')
    for k, name in enumerate(BACKDROPS):
        y = round(2 + 234.45 * k)
        art = sheet.crop((2, y + 1, 313, y + 231)).resize((W, H), Image.LANCZOS)
        save(art, 'fonds', f'{name}.png')
    print('fonds', len(BACKDROPS))


def puffs():
    sheet = src('xy_pofiteroles.png')
    out = Image.new('RGBA', (64 * 6, 64 * 6), (0, 0, 0, 0))
    for r in range(6):
        for c in range(6 if r == 5 else 4):
            cell = clear_border_white(sheet.crop((2 + c * 66, 2 + r * 66, 66 + c * 66, 66 + r * 66)))
            out.alpha_composite(cell, (c * 64, r * 64))
    save(out, 'pofiteroles.png')
    print('pofiteroles')


def decorations():
    sheet = src('xy_decorations.png')
    rows_types = [266, 332, 398, 464, 530, 596, 662, 728, 794, 860, 990, 1056, 1122, 1188, 1254, 1384, 1450, 1516]
    rows_colors = [1582, 1648, 1714, 1780, 1846, 1912, 1978, 2044, 2110]
    rows_clouds = [2176, 2242, 2308]
    rows_styles = [2374, 2440, 2506]
    big_cells = {'flying': (266, 860, 394, 988), 'dragon': (266, 1254, 394, 1382)}
    out = []

    def cell(x, y, w=64, h=64):
        return trim(clear_border_white(sheet.crop((x, y, x + w, y + h))))

    def add(name, im):
        save(im, 'deco', f'{name}.png')
        out.append(name)
    for i, t in enumerate(TYPES):
        r, c = divmod(i, 5)
        add(f'coeur_{t}', cell(2 + c * 66, 2 + r * 66))
    for t, y in zip(TYPES, rows_types):
        for c, suffix in enumerate(['coussin_a', 'coussin_b', 'objet_a', 'objet_b']):
            add(f'{t}_{suffix}', cell(2 + c * 66, y))
        box = big_cells.get(t)
        add(f'{t}_grand', trim(clear_border_white(sheet.crop(box))) if box else cell(266, y))
    for color, y in zip(COLORS, rows_colors):
        for c, kind in enumerate(['rond', 'plat', 'etoile', 'cube']):
            add(f'{kind}_{color}', cell(2 + c * 66, y))
    for color, y in zip(CLOUDS, rows_clouds):
        for c, kind in enumerate(['nuage_a', 'nuage_b', 'nuage_etoile', 'nuage_cube']):
            add(f'{kind}_{color}', cell(2 + c * 66, y))
    for style, y in zip(STYLES, rows_styles):
        for c, kind in enumerate(['rond', 'plat', 'etoile', 'cube']):
            add(f'{kind}_{style}', cell(2 + c * 66, y))
    add('chic_chaise_a', cell(2, 2572))
    add('chic_chaise_b', cell(68, 2572))
    add('chic_table', cell(134, 2572))
    add('chic_lit', trim(clear_border_white(sheet.crop((200, 2572, 330, 2700)))))
    print('deco', len(out))


# Main : bandes d'images (x de la 1re case, y, taille, nombre)
HAND_STRIPS = {
    'repos': (2, 2, 32, 2), 'caresse': (2, 36, 32, 4), 'pointe': (2, 70, 32, 4), 'gel': (2, 104, 32, 4),
    'effets': (2, 138, 32, 7), 'brulure': (2, 172, 64, 4), 'soin': (2, 238, 64, 1), 'poison': (2, 304, 32, 3),
    'mouille': (2, 338, 64, 2), 'choc': (2, 404, 64, 4), 'eclat': (2, 470, 32, 5),
}


def hand():
    sheet = src('xy_main.png')
    px = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            if px[x, y][:3] == (0, 128, 128):
                px[x, y] = (0, 0, 0, 0)
    for name, (x0, y0, size, count) in HAND_STRIPS.items():
        strip = Image.new('RGBA', (size * count, size), (0, 0, 0, 0))
        pitch = size + 2
        for i in range(count):
            strip.alpha_composite(sheet.crop((x0 + i * pitch, y0, x0 + i * pitch + size, y0 + size)), (i * size, 0))
        save(strip, 'main', f'{name}.png')
    print('main', len(HAND_STRIPS))


def buttons():
    deco = Image.open(path('deco', 'coeur_normal.png'))
    yarn = trim(src('xy_jongle_tete.png').crop((237, 89, 282, 134)))
    for name, icon in (('bouton_deco', deco), ('bouton_jeux', yarn)):
        im = Image.new('RGBA', (30, 30), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle((0, 0, 29, 29), radius=8, fill=(229, 243, 250, 240), outline=(80, 126, 166, 255), width=2)
        icon = trim(icon)
        icon.thumbnail((22, 22), Image.LANCZOS)
        im.alpha_composite(icon, ((30 - icon.width) // 2, (30 - icon.height) // 2))
        save(im, f'{name}.png')
    print('boutons')


def berry_picker():
    sheet = src('xy_cueille_baies.png')
    bush = sheet.crop((320, 87, 720, 327)).crop((40, 0, 360, 240))
    save(bush, 'cueille', 'fond.png')
    tree = sheet.crop((0, 87, 320, 587))
    save(tree.crop((0, 260, 320, 500)), 'cueille', 'fond_arbre.png')
    pile = sheet.crop((0, 660, 320, 897))
    pile.putalpha(pile.getchannel('A').point(lambda v: 0 if v < 24 else v))
    pile = trim(pile)
    pile = pile.resize((pile.width * 3 // 5, pile.height * 3 // 5), Image.LANCZOS)
    save(pile, 'cueille', 'tas.png')
    grass = trim(sheet.crop((0, 593, 320, 657)))
    save(grass, 'cueille', 'herbe.png')
    xs = [333, 365, 396, 427, 460, 490, 524, 554, 586, 618]
    berries = Image.new('RGBA', (24 * 10, 24), (0, 0, 0, 0))
    for i, x in enumerate(xs):
        b = trim(sheet.crop((x - 1, 430, x + 24, 460)))
        if i == 9:
            b = trim(sheet.crop((619, 435, 638, 455)))
        berries.alpha_composite(b, (i * 24 + (24 - b.width) // 2, (24 - b.height) // 2))
    save(berries, 'cueille', 'baies.png')
    save(trim(sheet.crop((330, 336, 395, 416))), 'cueille', 'bulle.png')
    save(trim(sheet.crop((403, 348, 440, 384))), 'cueille', 'nuage.png')
    save(trim(sheet.crop((102, 897, 163, 958))), 'cueille', 'pointeur.png')
    digits = Image.new('RGBA', (30 * 11, 42), (0, 0, 0, 0))
    boxes = [(7, 0, 36, 41), (61, 1, 71, 40), (97, 1, 123, 40), (141, 1, 166, 40), (183, 1, 212, 40), (228, 1, 255, 40),
             (272, 1, 300, 41), (8, 45, 35, 84), (52, 44, 80, 85), (96, 44, 124, 84)]
    for i, b in enumerate(boxes):
        d = sheet.crop(b)
        digits.alpha_composite(d, (i * 30 + (30 - d.width) // 2, (42 - d.height) // 2))
    save(digits, 'cueille', 'chiffres.png')
    notes = Image.new('RGBA', (96, 42), (0, 0, 0, 0))
    for i, b in enumerate([(180, 44, 215, 82), (220, 44, 255, 82), (260, 47, 291, 77)]):
        d = sheet.crop(b)
        notes.alpha_composite(d, (i * 32 + (32 - d.width) // 2, (42 - d.height) // 2))
    save(notes, 'cueille', 'notes.png')
    print('cueille')


def head_it():
    sheet = src('xy_jongle_tete.png')
    save(sheet.crop((0, 966, 320, 1206)), 'jongle', 'fond.png')
    save(sheet.crop((0, 726, 400, 966)).crop((40, 0, 360, 240)), 'jongle', 'fond_haut.png')
    rows = [(1216, 1295, 1302, 1385), (1396, 1475, 1482, 1565), (1576, 1655, 1662, 1745), (1756, 1835, None, None)]
    cols_a = [(1, 56), (60, 120), (120, 180)]
    cols_b = [(6, 56), (66, 116), (126, 176)]
    out = Image.new('RGBA', (32 * 6, 44 * 4), (0, 0, 0, 0))
    for r, (a0, a1, b0, b1) in enumerate(rows):
        for c, (x0, x1) in enumerate(cols_a):
            f = trim(sheet.crop((x0, a0, x1, a1)))
            f = f.resize((max(1, f.width // 2), max(1, f.height // 2)), Image.LANCZOS)
            out.alpha_composite(f, (c * 32 + (32 - f.width) // 2, r * 44 + 44 - f.height))
        if b0:
            for c, (x0, x1) in enumerate(cols_b):
                f = trim(sheet.crop((x0, b0, x1, b1)))
                f = f.resize((max(1, f.width // 2), max(1, f.height // 2)), Image.LANCZOS)
                out.alpha_composite(f, ((c + 3) * 32 + (32 - f.width) // 2, r * 44 + 44 - f.height))
    save(out, 'jongle', 'pelotes.png')
    giant = Image.new('RGBA', (64 * 3, 96), (0, 0, 0, 0))
    for c, (x0, x1) in enumerate([(4, 126), (129, 256), (265, 376)]):
        f = trim(sheet.crop((x0, 1897, x1, 2087)))
        f = f.resize((f.width // 2, f.height // 2), Image.LANCZOS)
        giant.alpha_composite(f, (c * 64 + (64 - f.width) // 2, 96 - f.height))
    save(giant, 'jongle', 'geante.png')
    for name, box, scale in (('arc', (0, 227, 400, 378), 0.6), ('arc_moyen', (7, 431, 400, 495), 0.6)):
        f = sheet.crop(box)
        save(f.resize((int(f.width * scale), int(f.height * scale)), Image.LANCZOS), 'jongle', f'{name}.png')
    save(trim(sheet.crop((46, 90, 106, 152))), 'jongle', 'attention.png')
    save(trim(sheet.crop((110, 89, 168, 151))), 'jongle', 'attention2.png')
    digits = Image.new('RGBA', (30 * 10, 42), (0, 0, 0, 0))
    boxes = [(7, 1, 36, 42), (61, 2, 71, 41), (97, 2, 123, 41), (141, 2, 166, 41), (183, 2, 212, 41), (8, 46, 35, 85),
             (52, 46, 80, 86), (96, 46, 123, 85), (140, 45, 168, 86), (184, 45, 212, 85)]
    for i, b in enumerate(boxes):
        d = sheet.crop(b)
        digits.alpha_composite(d, (i * 30 + (30 - d.width) // 2, (42 - d.height) // 2))
    save(digits, 'jongle', 'chiffres.png')
    print('jongle')


if __name__ == '__main__':
    only = os.environ.get('ONLY')
    steps = [backdrops, puffs, decorations, hand, buttons, berry_picker, head_it]
    for step in steps:
        if not only or step.__name__ in only.split(','):
            step()

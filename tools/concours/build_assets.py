# Concours : prépare les images et les sons des Super Concours (accueil, scène, résultats, Mallette)
# d'après les ressources du plugin « Pokemon Super Contests » (Essentials, écran 512x384)
#
# Usage : python build_assets.py <dossier « Pokemon Super Contests Plugin »> [dossier du projet]
#   (le dossier contient Graphics/Pictures/Contest et Audio/BGM, ME, SE)
#   - graphics/interface/concours/accessoires/<nom>.png  accessoires (moitié de taille)
#   - graphics/interface/concours/fonds/<nom>.png         fonds (112x128) et carte_<nom>.png (26x36)
#   - graphics/interface/concours/concurrents/<rang>/<nom>.png  Pokémon habillés des concurrents
#   - scène, résultats, Mallette, tableau des gagnants redessinés en 320x240
#   - épreuves : habillage.png (Mallette et cadre photo), defile.png (défilé : rideau, cœurs), danse.png (piste,
#     pas, touches, notes), acteur.png (public, juges, tuiles des concurrents, capacités, ambiance)
#   - audio/bgm/concours_*.ogg, audio/me/concours_accessoire.ogg, audio/se/concours_*.ogg
import os
import re
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

SRC = sys.argv[1] if len(sys.argv) > 1 else '.'
ROOT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), '..', '..')
PICS = os.path.join(SRC, 'Graphics', 'Pictures', 'Contest')
OUT = os.path.join(ROOT, 'graphics', 'interface', 'concours')
W, H = 320, 240


def src(*parts):
    return Image.open(os.path.join(PICS, *parts)).convert('RGBA')


def half(im, smooth=False):
    return im.resize((max(1, im.width // 2), max(1, im.height // 2)), Image.BOX if smooth else Image.NEAREST)


def slug(name):
    return re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_')


def save(im, *name):
    path = os.path.join(OUT, *name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)


def tile(dest, piece, x0=0, y0=0, x1=None, y1=None):
    x1 = dest.width if x1 is None else x1
    y1 = dest.height if y1 is None else y1
    for y in range(y0, y1, piece.height):
        for x in range(x0, x1, piece.width):
            part = piece.crop((0, 0, min(piece.width, x1 - x), min(piece.height, y1 - y)))
            dest.alpha_composite(part, (x, y))


def panel(size, fill, edge, radius=4):
    im = Image.new('RGBA', size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=edge)
    d.rounded_rectangle((2, 2, size[0] - 3, size[1] - 3), radius=max(1, radius - 2), fill=fill)
    return im


def gingham(base=(123, 189, 255, 255), dark=(99, 165, 222, 255)):
    res = half(src('results', 'background.png'))
    piece = res.crop((0, 140, 32, 172))
    im = Image.new('RGBA', (W, H), base)
    tile(im, piece)
    return im


def font(size):
    for folder in ('Fonts', 'fonts'):
        path = os.path.join(ROOT, folder, 'PokemonDS.ttf')
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def outlined(text, size, fill, edge, scale=1):
    """Texte en police du jeu avec un contour épais."""
    f = font(size)
    canvas = Image.new('RGBA', (size * len(text) + 40, size * 5), (0, 0, 0, 0))
    ImageDraw.Draw(canvas).text((20, size * 3), text, font=f, fill=(255, 255, 255, 255))
    canvas = canvas.crop(canvas.getbbox())
    mask = canvas.split()[3].point(lambda v: 255 if v > 96 else 0)
    w, h = canvas.size
    im = Image.new('RGBA', (w + 4, h + 5), (0, 0, 0, 0))
    shade = Image.new('RGBA', (w, h), (edge[0] // 2, edge[1] // 2, edge[2] // 2, 255))
    rim = Image.new('RGBA', (w, h), edge)
    for dx in range(-1, 2):
        for dy in range(-1, 3):
            im.paste(shade if dy == 2 else rim, (2 + dx, 2 + dy), mask)
    im.paste(Image.new('RGBA', (w, h), fill), (2, 2), mask)
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def collection():
    for folder in ('accessories', 'backdrops'):
        dest = 'accessoires' if folder == 'accessories' else 'fonds'
        for name in sorted(os.listdir(os.path.join(PICS, 'dressup', folder))):
            if not name.lower().endswith('.png'):
                continue
            base = name[:-4]
            out = slug(base[5:]) if base.startswith('card_') else slug(base)
            if base.startswith('card_'):
                out = 'carte_' + out
            save(half(src('dressup', folder, name)), dest, out + '.png')
    contestants = os.path.join(PICS, 'dressup', 'contestants')
    if os.path.isdir(contestants):
        for rank in os.listdir(contestants):
            for name in os.listdir(os.path.join(contestants, rank)):
                if name.lower().endswith('.png'):
                    save(half(src('dressup', 'contestants', rank, name), True), 'concurrents', slug(rank), slug(name[:-4]) + '.png')


def stage():
    sky = half(src('dressup', 'reveal_background.png')).resize((W, H), Image.NEAREST)
    im = sky.copy()
    d = ImageDraw.Draw(im)
    # estrade
    for y in range(132, 196):
        t = (y - 132) / 64
        d.line((0, y, W, y), fill=(int(214 + 30 * t), int(132 + 40 * t), int(170 + 10 * t), 255))
    for y in range(140, 196, 10):
        d.line((0, y, W, y), fill=(196, 110, 150, 255))
    for x in range(-200, W + 200, 40):
        d.line((160 + (x - 160) * 0.55, 132, x, 196), fill=(200, 118, 158, 255))
    d.rectangle((0, 126, W, 131), fill=(255, 236, 246, 255))
    d.rectangle((0, 131, W, 132), fill=(170, 80, 130, 255))
    d.rectangle((0, 196, W, 203), fill=(206, 92, 128, 255))
    d.rectangle((0, 203, W, 206), fill=(150, 52, 90, 255))
    # rideaux
    curtain = half(src('dressup', 'reveal_curtain.png'))
    valance = curtain.crop((0, curtain.height - 26, curtain.width, curtain.height))
    side = curtain.crop((0, 0, 34, 120))
    for x in (0, W - 34):
        piece = side if x == 0 else side.transpose(Image.FLIP_LEFT_RIGHT)
        tile(im, piece, x, 0, x + 34, 160)
    tile(im, valance, 0, 0, W, 26)
    # public au premier plan
    crowd = half(src('dressup', 'reveal_crowd.png'))
    heads = crowd.crop((0, 120, crowd.width, crowd.height))
    tile(im, heads, 0, H - heads.height + 16, W, H)
    save(im, 'scene.png')
    # projecteurs (cône de lumière transparent)
    beam = Image.new('RGBA', (64, 150), (0, 0, 0, 0))
    d = ImageDraw.Draw(beam)
    for i in range(150):
        half_w = 8 + i * 22 // 150
        d.line((32 - half_w, i, 32 + half_w, i), fill=(255, 250, 200, 40 + i // 6))
    save(beam, 'faisceau.png')
    save(Image.new('RGBA', (W, H), (255, 255, 255, 255)), 'blanc.png')


def results():
    bg = gingham()
    d = ImageDraw.Draw(bg)
    d.rectangle((0, 0, W, 17), fill=(222, 70, 150, 255))
    d.rectangle((0, 17, W, 18), fill=(255, 198, 82, 255))
    save(bg, 'resultats.png')
    # ligne : cadre rose (moitié de taille) élargi à 312 px
    full = src('results', 'background.png').crop((0, 16, 494, 74))
    row = half(full)
    left = row.crop((0, 0, 110, row.height))
    middle = row.crop((110, 0, 150, row.height))
    right = row.crop((150, 0, row.width, row.height))
    out = Image.new('RGBA', (312, row.height), (0, 0, 0, 0))
    out.alpha_composite(left, (0, 0))
    tile(out, middle, 110, 0, 312 - right.width, row.height)
    out.alpha_composite(right, (312 - right.width, 0))
    save(out, 'ligne.png')
    bars = Image.new('RGBA', (216, 4 * 3), (0, 0, 0, 0))
    for i, name in enumerate(('dressup_bar', 'dance_bar', 'acting_bar')):
        bar = half(src('results', name + '.png')).resize((216, 4), Image.NEAREST)
        bars.alpha_composite(bar, (0, i * 4))
    save(bars, 'barres.png')
    save(half(src('results', 'placement_numbers.png')), 'places.png')
    spot = half(src('results', 'winner_spotlight.png')).resize((W, 96), Image.NEAREST)
    shade = Image.new('RGBA', (W, H), (20, 24, 40, 200))
    shade.paste(spot, (0, (H - 96) // 2 - 10))
    px = shade.load()
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            if r > 200 and g > 200 and b < 120:
                px[x, y] = (255, 250, 150, 90)
            else:
                px[x, y] = (16, 20, 36, 190)
    save(shade, 'projecteur.png')


def case():
    bg = Image.new('RGBA', (W, H), (255, 214, 232, 255))
    d = ImageDraw.Draw(bg)
    for y in range(0, H, 16):
        for x in range(0, W, 16):
            if (x // 16 + y // 16) % 2 == 0:
                d.rectangle((x, y, x + 15, y + 15), fill=(255, 196, 222, 255))
    d.rectangle((0, 0, W, 17), fill=(222, 70, 150, 255))
    d.rectangle((0, 17, W, 18), fill=(255, 198, 82, 255))
    bg.alpha_composite(panel((96, 196), (255, 250, 252, 255), (200, 80, 150, 255)), (4, 22))
    bg.alpha_composite(panel((216, 160), (255, 250, 252, 255), (200, 80, 150, 255)), (102, 22))
    bg.alpha_composite(panel((216, 34), (255, 250, 252, 255), (200, 80, 150, 255)), (102, 184))
    save(bg, 'mallette.png')
    cell = Image.new('RGBA', (40, 40), (0, 0, 0, 0))
    ImageDraw.Draw(cell).rounded_rectangle((0, 0, 39, 39), radius=4, fill=(255, 232, 242, 255), outline=(240, 170, 205, 255))
    save(cell, 'case.png')
    sel = Image.new('RGBA', (44, 44), (0, 0, 0, 0))
    ImageDraw.Draw(sel).rounded_rectangle((0, 0, 43, 43), radius=5, outline=(255, 140, 40, 255), width=2)
    save(sel, 'curseur.png')
    line = Image.new('RGBA', (88, 14), (0, 0, 0, 0))
    ImageDraw.Draw(line).rounded_rectangle((0, 0, 87, 13), radius=3, fill=(255, 214, 120, 255), outline=(232, 120, 40, 255))
    save(line, 'ligne_menu.png')
    # tableau des gagnants
    bg = gingham()
    d = ImageDraw.Draw(bg)
    d.rectangle((0, 0, W, 17), fill=(64, 96, 168, 255))
    d.rectangle((0, 17, W, 18), fill=(255, 198, 82, 255))
    bg.alpha_composite(panel((312, 150), (246, 250, 255, 255), (80, 110, 200, 255)), (4, 22))
    bg.alpha_composite(panel((312, 62), (246, 250, 255, 255), (80, 110, 200, 255)), (4, 176))
    save(bg, 'tableau.png')


def dressup_ui():
    # fond : bandes roses du fond d'origine, sur toute la largeur
    bg = half(src('dressup', 'background.png'))
    strip = bg.crop((128, 0, 129, bg.height)).resize((1, H), Image.NEAREST)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    tile(im, strip)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, W, 17), fill=(222, 70, 150, 255))
    d.rectangle((0, 17, W, 18), fill=(255, 198, 82, 255))
    edge, inner = (123, 82, 115, 255), (66, 58, 92, 255)
    im.alpha_composite(panel((142, 176), (126, 240, 214, 255), edge, 5), (6, 22))
    d.rectangle((12, 28, 141, 41), fill=(90, 206, 180, 255))
    im.alpha_composite(panel((128, 144), inner, edge, 5), (178, 26))
    d.rectangle((0, 200, W, H), fill=(214, 70, 150, 255))
    d.rectangle((0, 200, W, 201), fill=(255, 198, 82, 255))
    save(im, 'habillage.png')
    cell = Image.new('RGBA', (30, 30), (0, 0, 0, 0))
    ImageDraw.Draw(cell).rounded_rectangle((0, 0, 29, 29), radius=4, fill=(206, 255, 241, 255), outline=(90, 206, 180, 255))
    save(cell, 'case_habillage.png')
    sel = Image.new('RGBA', (34, 34), (0, 0, 0, 0))
    ImageDraw.Draw(sel).rounded_rectangle((0, 0, 33, 33), radius=5, outline=(255, 120, 40, 255), width=2)
    save(sel, 'curseur_habillage.png')
    # boutons : haut, bas (moitié de taille), onglets (2 images : choisi, pas choisi), bouton vide
    save(half(src('dressup', 'up button.png')), 'bouton_haut.png')
    save(half(src('dressup', 'down button.png')), 'bouton_bas.png')
    for name, base in (('onglet_accessoires', 'accessory'), ('onglet_fonds', 'backdrop')):
        on, off = half(src('dressup', base + '_sel.png')), half(src('dressup', base + '_desel.png'))
        both = Image.new('RGBA', (on.width, on.height * 2), (0, 0, 0, 0))
        both.alpha_composite(on, (0, 0))
        both.alpha_composite(off, (0, on.height))
        save(both, name + '.png')
    button = Image.new('RGBA', (76, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(button)
    d.rounded_rectangle((0, 0, 75, 25), radius=5, fill=(123, 82, 115, 255))
    d.rounded_rectangle((2, 2, 73, 23), radius=4, fill=(255, 99, 132, 255))
    d.rounded_rectangle((4, 4, 71, 12), radius=3, fill=(255, 140, 165, 255))
    save(button, 'bouton.png')
    # pointeur (clavier)
    hand = Image.new('RGBA', (12, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(hand)
    d.polygon([(0, 0), (0, 13), (3, 10), (6, 15), (8, 14), (5, 9), (10, 9)], fill=(255, 255, 255, 255), outline=(40, 30, 60, 255))
    save(hand, 'pointeur.png')
    # défilé : décor, rideau, cœurs
    sky = half(src('dressup', 'reveal_background.png')).resize((W, H), Image.NEAREST)
    crowd = half(src('dressup', 'reveal_crowd.png'))
    heads = crowd.crop((0, 120, crowd.width, crowd.height))
    tile(sky, heads, 0, H - heads.height + 30, W, H)
    frame = Image.new('RGBA', (124, 140), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, 123, 139), radius=5, fill=(255, 236, 160, 255), outline=(150, 52, 90, 255), width=2)
    sky.alpha_composite(frame, ((W - 124) // 2, 28))
    save(sky, 'defile.png')
    curtain = half(src('dressup', 'reveal_curtain.png'))
    rid = Image.new('RGBA', (112, 128), (0, 0, 0, 0))
    tile(rid, curtain.crop((0, 0, 64, 64)))
    save(rid, 'rideau.png')
    for name, base in (('coeur_rose', 'dressup'), ('coeur_rouge', 'condition')):
        strip = src('dressup', base + '_heart_animation.png')
        heart = strip.crop((0, 0, 45, 82))
        heart = heart.crop(heart.getbbox())
        save(half(heart), name + '.png')


def dance_ui():
    bg = half(src('dance', 'stage_background.png')).resize((W, H), Image.NEAREST)
    d = ImageDraw.Draw(bg)
    d.rectangle((0, 156, W, H), fill=(52, 40, 88, 255))
    d.rectangle((0, 156, W, 157), fill=(255, 198, 82, 255))
    save(bg, 'danse.png')
    # piste : 480 images (8 s) sur 312 px ; moitié gauche : danseur principal (bleu), droite : les autres (rose)
    track = Image.new('RGBA', (312, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(track)
    d.rounded_rectangle((0, 0, 311, 35), radius=4, fill=(40, 30, 70, 255))
    d.rectangle((2, 2, 155, 33), fill=(0, 181, 239, 255))
    d.rectangle((156, 2, 309, 33), fill=(255, 107, 181, 255))
    for i in range(1, 16):
        x = round(2 + i * 307 / 16)
        d.line((x, 3, x, 32), fill=(255, 255, 255, 120 if i % 4 else 220))
    d.rectangle((155, 2, 156, 33), fill=(255, 247, 165, 255))
    save(track, 'piste.png')
    # pas : saut (haut, rouge), devant (bas, bleu), gauche (vert), droite (jaune)
    colors = [(239, 82, 82), (82, 140, 239), (66, 198, 115), (239, 198, 33)]
    steps = Image.new('RGBA', (16 * 4, 16), (0, 0, 0, 0))
    for i, color in enumerate(colors):
        one = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
        g = ImageDraw.Draw(one)
        g.ellipse((0, 0, 15, 15), fill=(40, 30, 60, 255))
        g.ellipse((1, 1, 14, 14), fill=color + (255,))
        arrow = [(8, 3), (13, 9), (10, 9), (10, 12), (6, 12), (6, 9), (3, 9)]
        g.polygon(arrow, fill=(255, 255, 255, 255))
        one = one.rotate((0, 180, 90, -90)[i], resample=Image.NEAREST)
        steps.alpha_composite(one, (i * 16, 0))
    save(steps, 'pas.png')
    keys = Image.new('RGBA', (52 * 4, 30 * 2), (0, 0, 0, 0))
    for i, color in enumerate(colors):
        for pressed in range(2):
            one = Image.new('RGBA', (52, 30), (0, 0, 0, 0))
            g = ImageDraw.Draw(one)
            top = 4 if pressed else 0
            g.rounded_rectangle((0, 6, 51, 29), radius=10, fill=(33, 74, 156, 255))
            g.rounded_rectangle((0, top, 51, top + 21), radius=10, fill=tuple(c // 2 for c in color) + (255,))
            g.rounded_rectangle((2, top + 1, 49, top + 19), radius=9, fill=color + (255,))
            arrow = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
            ImageDraw.Draw(arrow).polygon([(8, 2), (14, 9), (10, 9), (10, 14), (6, 14), (6, 9), (2, 9)], fill=(255, 255, 255, 255))
            arrow = arrow.rotate((0, 180, 90, -90)[i], resample=Image.NEAREST)
            one.alpha_composite(arrow, (18, top + 3))
            keys.alpha_composite(one, (i * 52, pressed * 30))
    save(keys, 'touches.png')
    cursor = Image.new('RGBA', (4, 44), (0, 0, 0, 0))
    ImageDraw.Draw(cursor).rectangle((1, 0, 2, 43), fill=(255, 255, 255, 255))
    ImageDraw.Draw(cursor).rectangle((0, 0, 3, 3), fill=(255, 230, 80, 255))
    save(cursor, 'curseur_danse.png')
    save(half(src('dance', 'excellent.png'), True), 'note_excellent.png')
    save(half(src('dance', 'good.png'), True), 'note_good.png')
    save(half(src('dance', 'miss.png'), True), 'note_miss.png')
    save(outlined('Bien !', 16, (255, 255, 255, 255), (230, 80, 170, 255), 2), 'note_bien.png')
    save(outlined('Raté...', 16, (255, 255, 255, 255), (140, 110, 200, 255), 2), 'note_rate.png')
    save(half(src('dance', 'star small.png')), 'etoile.png')


def acting_ui():
    anim = half(src('acting', 'bgAnimation.png'))
    top = Image.new('RGBA', (W, 64), (90, 82, 181, 255))
    crowd = anim.crop((0, 0, anim.width, 64))
    top.alpha_composite(crowd.crop((96, 0, 416, 64)), (0, 0))
    top.alpha_composite(crowd.crop((0, 0, 80, 64)), (0, 0))
    top.alpha_composite(crowd.crop((432, 0, 512, 64)), (240, 0))
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    im.alpha_composite(top, (0, 0))
    band = anim.crop((0, 64, W, 128))
    im.alpha_composite(band, (0, 64))
    stripes = anim.crop((0, 136, W, 152))
    tile(im, stripes, 0, 128, W, H)
    save(im, 'acteur.png')
    save(half(src('acting', 'nonplayer_contestant_tile.png')), 'tuile.png')
    save(half(src('acting', 'player_tile.png')), 'tuile_joueur.png')
    # ambiance : case éteinte, case allumée (étincelle du plugin d'origine)
    volt = Image.new('RGBA', (20, 10), (0, 0, 0, 0))
    g = ImageDraw.Draw(volt)
    g.ellipse((0, 0, 9, 9), fill=(240, 225, 235, 255), outline=(200, 160, 185, 255))
    g.ellipse((10, 0, 19, 9), fill=(255, 170, 40, 255), outline=(214, 100, 30, 255))
    volt.alpha_composite(src('acting', 'voltage.png').crop((30, 0, 40, 10)), (10, 0))
    save(volt, 'ambiance.png')
    save(src('acting', 'reactions.png'), 'reactions.png')
    save(src('acting', 'score_heart.png'), 'coeur.png')
    save(half(src('acting', 'cursor2.png')), 'curseur_juge.png')
    for name, fill, edge in (('plaque', (255, 250, 252, 255), (200, 80, 150, 255)),
                             ('plaque_chef', (255, 246, 196, 255), (214, 150, 33, 255))):
        save(panel((84, 24), fill, edge, 4), name + '.png')
    # capacités : une ligne par type (sang-froid, beauté, grâce, intelligence, robustesse), puis grisée
    colors = [(255, 41, 0), (41, 181, 255), (255, 99, 198), (74, 181, 41), (247, 206, 0), (160, 160, 160)]
    tiles = Image.new('RGBA', (154, 34 * len(colors)), (0, 0, 0, 0))
    for i, color in enumerate(colors):
        one = Image.new('RGBA', (154, 34), (0, 0, 0, 0))
        g = ImageDraw.Draw(one)
        g.rounded_rectangle((0, 0, 153, 33), radius=5, fill=(60, 50, 80, 255))
        g.rounded_rectangle((2, 2, 151, 31), radius=4, fill=tuple(min(255, c + 90) for c in color) + (255,))
        g.rounded_rectangle((3, 4, 150, 31), radius=4, fill=color + (255,))
        light = Image.new('RGBA', (154, 34), (0, 0, 0, 0))
        ImageDraw.Draw(light).rounded_rectangle((6, 18, 147, 29), radius=3, fill=(255, 255, 255, 110))
        one.alpha_composite(light)
        tiles.alpha_composite(one, (0, i * 34))
    save(tiles, 'capacites.png')
    sel = Image.new('RGBA', (158, 38), (0, 0, 0, 0))
    ImageDraw.Draw(sel).rounded_rectangle((0, 0, 157, 37), radius=6, outline=(255, 255, 255, 255), width=2)
    save(sel, 'curseur_capacite.png')
    menu = Image.new('RGBA', (W, 116), (0, 0, 0, 0))
    g = ImageDraw.Draw(menu)
    g.rectangle((0, 0, W, 115), fill=(52, 40, 88, 235))
    g.rectangle((0, 0, W, 1), fill=(255, 198, 82, 255))
    g.rounded_rectangle((4, 86, W - 5, 113), radius=4, fill=(255, 250, 252, 255), outline=(200, 80, 150, 255))
    save(menu, 'menu_capacites.png')


def sounds():
    audio = os.path.join(SRC, 'Audio')
    copies = {
        ('BGM', 'Contests_Contest Hall.ogg'): ('bgm', 'concours_hall.ogg'),
        ('BGM', 'Contests_Judging.ogg'): ('bgm', 'concours_jugement.ogg'),
        ('BGM', 'Contests_Dress Up.ogg'): ('bgm', 'concours_habillage.ogg'),
        ('BGM', 'Contests_Results.ogg'): ('bgm', 'concours_resultats.ogg'),
        ('BGM', 'Contests_Winning.ogg'): ('bgm', 'concours_gagnant.ogg'),
        ('BGM', 'Contests_Contest Win.ogg'): ('bgm', 'concours_victoire.ogg'),
        ('ME', 'Contests_Get Accessory.ogg'): ('me', 'concours_accessoire.ogg'),
        ('SE', 'Contests_Crowd.ogg'): ('se', 'concours_foule.ogg'),
        ('SE', 'Contests_Camera_Shutter.ogg'): ('se', 'concours_appareil.ogg'),
        ('SE', 'Contests_Whistle.ogg'): ('se', 'concours_sifflet.ogg'),
        ('SE', 'Contests_Results_Drumroll.ogg'): ('se', 'concours_roulement.ogg'),
        ('SE', 'Contests_Results_Tally.ogg'): ('se', 'concours_total.ogg'),
        ('SE', 'Contests_Results_Tally_End.ogg'): ('se', 'concours_total_fin.ogg'),
        ('SE', 'Contests_Acting_Select_Move.ogg'): ('se', 'concours_choix.ogg'),
        ('SE', 'Contests_Heart.ogg'): ('se', 'concours_coeur.ogg'),
        ('SE', 'Contests_Start.ogg'): ('se', 'concours_debut.ogg'),
    }
    for (folder, name), (kind, new) in copies.items():
        path = os.path.join(audio, folder, name)
        if os.path.exists(path):
            shutil.copyfile(path, os.path.join(ROOT, 'audio', kind, new))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    collection()
    stage()
    results()
    case()
    dressup_ui()
    dance_ui()
    acting_ui()
    sounds()
    print('Concours : images dans', os.path.normpath(OUT))

# Pokéblocs : prépare les images et les sons du mixeur à baies et de la boîte à Pokéblocs
# d'après les ressources du plugin « Pokemon Contests and Pokeblocks » (Essentials v20.1, écran 512x384)
#
# Usage : python build_assets.py <dossier « Pokemon Contests and Pokeblocks v20.1 »> [dossier du projet]
#   (le dossier contient Graphics/Pictures/Pokeblock, Graphics/Items et Audio/SE)
#   - graphics/interface/pokeblocs/ : mixeur (cadres, disque, chiffres, Parfait / Bien / Raté, jauge de temps),
#     petits et grands Pokéblocs, barres d'état, fonds redessinés en 320x240 (textes en français dans le jeu)
#   - graphics/icons/pokeblock_case.png : icône de la Boîte Pokébloc
#   - audio/se/mixeur_*.wav : sons du mixeur
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

SRC = sys.argv[1] if len(sys.argv) > 1 else '.'
ROOT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), '..', '..')
PICS = os.path.join(SRC, 'Graphics', 'Pictures', 'Pokeblock')
OUT = os.path.join(ROOT, 'graphics', 'interface', 'pokeblocs')
W, H = 320, 240

COLORS = ['Red', 'Blue', 'Pink', 'Green', 'Yellow', 'Purple', 'Indigo', 'Brown', 'LiteBlue', 'Olive', 'Gold', 'Gray',
          'White', 'Black', 'Rainbow']
PLUS = ['Red', 'Blue', 'Pink', 'Green', 'Yellow', 'Rainbow']


def src(*parts):
    return Image.open(os.path.join(PICS, *parts)).convert('RGBA')


def half(im):
    """Moitié de la taille (le dessin d'origine est en pixels doubles)."""
    return im.resize((max(1, im.width // 2), max(1, im.height // 2)), Image.NEAREST if im.width % 2 == 0 else Image.BOX)


def save(im, *name):
    path = os.path.join(OUT, *name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)


def font(size):
    for folder in ('Fonts', 'fonts'):
        path = os.path.join(ROOT, folder, 'PokemonDS.ttf')
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def outlined(text, size, fill, edge, scale=2):
    """Texte en police du jeu, contour épais, agrandi en pixels doubles."""
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


def pattern_bg(base, dot, step=8):
    im = Image.new('RGBA', (W, H), base)
    d = ImageDraw.Draw(im)
    for y in range(0, H, step):
        for x in range((y // step % 2) * step // 2, W, step):
            d.rectangle((x, y, x + 1, y + 1), fill=dot)
    return im


def panel(size, fill, edge, inner=None, radius=4):
    im = Image.new('RGBA', size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=edge)
    d.rounded_rectangle((2, 2, size[0] - 3, size[1] - 3), radius=max(1, radius - 2), fill=inner or fill)
    if inner:
        d.rounded_rectangle((3, 3, size[0] - 4, size[1] - 4), radius=max(1, radius - 2), fill=fill)
    return im


def blender():
    # fond : motif sombre et fenêtres du mixeur (Behind) ; cadres transparents à poser par-dessus le disque et la jauge
    bg = pattern_bg((24, 26, 52, 255), (44, 48, 92, 255))
    behind = half(src('UI Berry Blender', 'Behind.png'))
    bg.alpha_composite(behind, ((W - behind.width) // 2, (H - behind.height) // 2))
    save(bg, 'mixeur_fond.png')
    for n, name in enumerate(['OnePlayer', 'TwoPlayers', 'ThreePlayers', 'FourPlayers']):
        save(half(src('UI Berry Blender', f'{name}.png').crop((0, 0, 512, 384))), f'mixeur_{n + 1}.png')
    bg = Image.new('RGBA', (W, H), (226, 250, 252, 255))
    d = ImageDraw.Draw(bg)
    for y in range(0, H, 8):
        d.rectangle((0, y, W, y + 3), fill=(205, 244, 250, 255))
    save(bg, 'mixeur_simple_fond.png')
    save(half(src('UI Berry Blender', 'Simple.png')), 'mixeur_simple.png')
    save(half(src('UI Berry Blender', 'Circle.png')), 'disque.png')
    save(half(src('UI Berry Blender', 'CircleSimple.png')), 'disque_simple.png')
    digits = [half(src('UI Berry Blender', f'{i}.png')) for i in (1, 2, 3)]
    sheet = Image.new('RGBA', (digits[0].width * 3, digits[0].height), (0, 0, 0, 0))
    for i, im in enumerate(digits):
        sheet.alpha_composite(im, (i * digits[0].width, 0))
    save(sheet, 'chiffres.png')
    save(outlined('PARTEZ !', 16, (255, 238, 40, 255), (210, 30, 40, 255)), 'partez.png')
    marks = [src('UI Berry Blender', f'{n}.png') for n in ('Perfect', 'Good', 'Miss')]
    sheet = Image.new('RGBA', (16 * 3, 16), (0, 0, 0, 0))
    for i, im in enumerate(marks):
        sheet.alpha_composite(half(im), (i * 16, 0))
    save(sheet, 'notes.png')
    save(half(src('UI Berry Blender', 'Time.png')), 'jauge.png')
    sparks = Image.new('RGBA', (14 + 10, 14), (0, 0, 0, 0))
    sparks.alpha_composite(src('UI Berry Blender', 'Effect_1.png'), (0, 0))
    sparks.alpha_composite(src('UI Berry Blender', 'Effect_2.png'), (14, 2))
    save(sparks, 'etincelles.png')
    # résultats : fond rose à motif sans le titre anglais
    res = half(src('UI Berry Blender', 'Results.png'))
    tile = res.crop((0, 64, 64, 128))
    bg = Image.new('RGBA', (W, H))
    for y in range(0, H, 64):
        for x in range(0, W, 64):
            bg.alpha_composite(tile, (x, y))
    save(bg, 'resultats.png')


def blocks():
    for color in COLORS:
        name = color.lower()
        save(src('Blocks', f'{color}.png'), 'blocs', f'{name}.png')
        if os.path.exists(os.path.join(PICS, 'Blocks', f'Block_{color}.png')):
            save(src('Blocks', f'Block_{color}.png'), 'blocs', f'grand_{name}.png')
        if color in PLUS:
            save(src('Blocks', f'Block_{color}_Plus.png'), 'blocs', f'grand_{name}_plus.png')
    # Marron : pas de grande image dans le plugin d'origine, on teinte la grise
    brown = os.path.join(PICS, 'Blocks', 'Block_Brown.png')
    if not os.path.exists(brown):
        gray = src('Blocks', 'Block_Gray.png')
        px = gray.load()
        for y in range(gray.height):
            for x in range(gray.width):
                r, g, b, a = px[x, y]
                if a:
                    v = (r + g + b) / 765
                    px[x, y] = (int(120 + 110 * v), int(70 + 100 * v), int(30 + 70 * v), a)
        save(gray, 'blocs', 'grand_brown.png')


def case_ui():
    # Boîte : fond à pois vert d'eau (comme la Boîte du plugin), panneaux blancs à bord lavande
    bg = pattern_bg((96, 188, 168, 255), (130, 212, 190, 255), 6)
    d = ImageDraw.Draw(bg)
    d.rectangle((0, 0, W, 17), fill=(64, 96, 168, 255))
    d.rectangle((0, 17, W, 18), fill=(150, 172, 232, 255))
    full = src('UI Pokeblock', 'pokeblock_background.png')
    kit = full.crop((40, 88, 184, 232))
    px = kit.load()
    for y in range(kit.height):
        for x in range(kit.width):
            if px[x, y][:3] in ((120, 200, 184), (120, 176, 184), (88, 160, 168), (255, 255, 255)):
                px[x, y] = (0, 0, 0, 0)
    ImageDraw.Draw(kit).rectangle((112, 80, 143, 143), fill=(0, 0, 0, 0))
    kit = half(kit)
    bg.alpha_composite(panel((116, 92), (236, 246, 244, 255), (110, 120, 230, 255)), (6, 24))
    bg.alpha_composite(kit, (6 + (116 - kit.width) // 2, 24 + (92 - kit.height) // 2))
    bg.alpha_composite(panel((116, 116), (246, 246, 246, 255), (110, 120, 230, 255)), (6, 120))
    bg.alpha_composite(panel((186, 212), (246, 246, 246, 255), (110, 120, 230, 255)), (128, 24))
    save(bg, 'boite.png')
    # ligne choisie de la liste
    sel = Image.new('RGBA', (178, 18), (0, 0, 0, 0))
    ImageDraw.Draw(sel).rounded_rectangle((0, 0, 177, 17), radius=3, fill=(255, 214, 120, 255), outline=(232, 120, 40, 255))
    save(sel, 'ligne.png')
    lv = half(src('UI Pokeblock', 'pokeblock_bg_lv.png'))
    save(lv, 'niveau.png')
    save(half(src('UI Pokeblock', 'Up_arrow.png')), 'fleche.png')
    save(src('UI Pokeblock', 'max.png'), 'max.png')
    # état : fond rose dégradé, cadre du Pokémon, barres de condition (128 px)
    bg = Image.new('RGBA', (W, H))
    d = ImageDraw.Draw(bg)
    for y in range(H):
        t = y / (H - 1)
        d.line((0, y, W, y), fill=(int(252 - 14 * t), int(190 - 30 * t), int(204 + 22 * t), 255))
    d.rectangle((0, 0, W, 17), fill=(222, 70, 150, 255))
    d.rectangle((0, 17, W, 18), fill=(255, 150, 210, 255))
    bg.alpha_composite(panel((120, 132), (255, 248, 252, 255), (200, 80, 150, 255)), (6, 24))
    bg.alpha_composite(panel((182, 154), (246, 246, 246, 255), (200, 80, 150, 255)), (132, 24))
    save(bg, 'etat.png')
    bars = Image.new('RGBA', (128, 6 * 7), (0, 0, 0, 0))
    for i, name in enumerate(['Cool', 'Beauty', 'Cute', 'Smart', 'Tough', 'Sheen']):
        bar = src('UI Pokeblock', f'Bar_{name}.png').resize((128, 6), Image.BOX)
        bars.alpha_composite(bar, (0, i * 7))
    save(bars, 'barres.png')
    slot = Image.new('RGBA', (132, 8), (0, 0, 0, 0))
    ImageDraw.Draw(slot).rounded_rectangle((0, 0, 131, 7), radius=2, fill=(40, 40, 52, 255), outline=(255, 255, 255, 255))
    save(slot, 'barre_fond.png')


def icon():
    im = Image.open(os.path.join(SRC, 'Graphics', 'Items', 'POKEBLOCKCASE.png')).convert('RGBA')
    im = half(im)
    out = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    out.alpha_composite(im, ((32 - im.width) // 2, (32 - im.height) // 2))
    path = os.path.join(ROOT, 'graphics', 'icons', 'pokeblock_case.png')
    out.save(path, optimize=True)


def sounds():
    dest = os.path.join(ROOT, 'audio', 'se')
    for name, new in (('Countdown', 'decompte'), ('Start', 'depart'), ('Perfect', 'parfait'), ('Good', 'bien'),
                      ('Miss', 'rate')):
        shutil.copyfile(os.path.join(SRC, 'Audio', 'SE', f'Berry Blender {name}.wav'), os.path.join(dest, f'mixeur_{new}.wav'))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    blender()
    blocks()
    case_ui()
    icon()
    sounds()
    print('Pokéblocs : images dans', os.path.normpath(OUT))

# Concours : images ajoutées d'après les planches de tools/concours/sources (DPPt Super Concours, RSE Concours)
#
# Usage : python build_extras.py [dossier du projet]
#   - bandeau_<type>.png   bandeau de couleur du concours (320x20) avec le ruban, texte écrit par le jeu
#   - ruban_rang.png       ruban des rangs (15x14)
#   - pastille_<type>.png  pastille de couleur de la catégorie (60x12), texte écrit par le jeu
#   - etincelles.png       étincelles du gagnant (6 images de 24x24 côte à côte)
# Ne touche à aucune autre image du dossier.
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..')
OUT = os.path.join(ROOT, 'graphics', 'interface', 'concours')
SRC = os.path.join(HERE, 'sources')

# couleurs des bandeaux (RSE) et des pastilles (DPPt)
BANNERS = {'cute': (255, 140, 255), 'cool': (255, 57, 57), 'beauty': (107, 148, 255), 'smart': (148, 255, 165), 'tough': (247, 214, 0)}
PILLS = {'tough': (255, 206, 82), 'cool': (255, 99, 82), 'beauty': (115, 189, 255), 'smart': (140, 231, 140), 'cute': (255, 99, 206)}


def save(im, name):
    im.save(os.path.join(OUT, name))
    print(name)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


def key_out(im, color):
    im = im.convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][:3] == color:
                px[x, y] = (0, 0, 0, 0)
    return im


def ribbon():
    rse = Image.open(os.path.join(SRC, 'rse_concours.png')).convert('RGBA')
    icon = key_out(rse.crop((314, 13, 329, 27)), BANNERS['cute'])
    save(icon, 'ruban_rang.png')
    return icon


def banners(icon):
    for kind, color in BANNERS.items():
        im = Image.new('RGBA', (320, 20), color + (255,))
        d = ImageDraw.Draw(im)
        d.line((0, 0, 319, 0), fill=shade(color, 1.15) if max(color) < 230 else (255, 255, 255, 255))
        d.line((0, 18, 319, 18), fill=shade(color, 0.8))
        d.line((0, 19, 319, 19), fill=shade(color, 0.6))
        im.alpha_composite(icon, (6, 3))
        save(im, f'bandeau_{kind}.png')


def pills():
    for kind, color in PILLS.items():
        im = Image.new('RGBA', (60, 12), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle((0, 0, 59, 11), radius=6, fill=color + (255,))
        d.rounded_rectangle((2, 1, 57, 4), radius=2, fill=shade(color, 1.12))
        d.rounded_rectangle((0, 0, 59, 11), radius=6, outline=shade(color, 0.75))
        save(im, f'pastille_{kind}.png')


def sparkles():
    sheet = Image.open(os.path.join(SRC, 'dppt_gagnant.png')).convert('RGBA')
    area = key_out(sheet.crop((280, 185, 545, 240)), (123, 198, 255))
    # composantes connexes (chaque étincelle)
    px = area.load()
    seen = set()
    parts = []
    for y in range(area.height):
        for x in range(area.width):
            if px[x, y][3] == 0 or (x, y) in seen:
                continue
            stack = [(x, y)]
            seen.add((x, y))
            pts = []
            while stack:
                cx, cy = stack.pop()
                pts.append((cx, cy))
                for nx in (cx - 1, cx, cx + 1):
                    for ny in (cy - 1, cy, cy + 1):
                        if 0 <= nx < area.width and 0 <= ny < area.height and (nx, ny) not in seen and px[nx, ny][3]:
                            seen.add((nx, ny))
                            stack.append((nx, ny))
            if len(pts) > 12:
                xs = [p[0] for p in pts]
                ys = [p[1] for p in pts]
                parts.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    parts.sort()
    out = Image.new('RGBA', (24 * len(parts), 24), (0, 0, 0, 0))
    for i, box in enumerate(parts):
        piece = area.crop(box)
        out.alpha_composite(piece, (i * 24 + (24 - piece.width) // 2, (24 - piece.height) // 2))
    save(out, 'etincelles.png')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    banners(ribbon())
    pills()
    sparkles()

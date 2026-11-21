# Pokémon Obscurs : dessine les images du plugin (320x240) et la Snatch Ball
#
# Usage : python build_assets.py [dossier du projet]
#   - graphics/interface/obscurs/ : Chambre de purification (fond, cases, curseur, jauges), scène de purification
#     (fond, aura, blanc), jauge du résumé
#   - graphics/icons/snag_ball.png et graphics/ball/ball_snag.png : Snatch Ball (Poké Ball recolorée en violet)
import colorsys
import math
import os
import sys

from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', '..')
OUT = os.path.join(ROOT, 'graphics', 'interface', 'obscurs')
W, H = 320, 240
PURPLE = (120, 60, 170, 255)
DARK = (34, 22, 52, 255)
EDGE = (170, 110, 230, 255)


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name), optimize=True)


def gradient(top, bottom):
    im = Image.new('RGBA', (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / (H - 1)
        d.line((0, y, W, y), fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return im


def panel(size, fill, edge, radius=5):
    im = Image.new('RGBA', size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=edge)
    d.rounded_rectangle((2, 2, size[0] - 3, size[1] - 3), radius=max(1, radius - 2), fill=fill)
    return im


def chamber():
    bg = gradient((22, 18, 48), (60, 34, 92))
    d = ImageDraw.Draw(bg)
    # étoiles
    for i in range(70):
        x, y = (i * 97) % W, (i * 53) % 200
        d.point((x, y), fill=(200, 180, 255, 120 + (i * 37) % 120))
    d.rectangle((0, 0, W, 17), fill=(70, 30, 110, 255))
    d.rectangle((0, 17, W, 18), fill=EDGE)
    bg.alpha_composite(panel((140, 140), (40, 28, 70, 230), EDGE), (6, 26))
    bg.alpha_composite(panel((156, 196), (40, 28, 70, 230), EDGE), (158, 20))
    # cercle de l'ensemble
    ring = Image.new('RGBA', (140, 140), (0, 0, 0, 0))
    g = ImageDraw.Draw(ring)
    g.ellipse((22, 22, 117, 117), outline=(150, 100, 220, 255), width=3)
    g.ellipse((49, 49, 90, 90), fill=(70, 40, 110, 255), outline=(220, 170, 255, 255), width=2)
    for k in range(4):
        a = math.pi / 2 * k - math.pi / 2
        cx, cy = 70 + 48 * math.cos(a), 70 + 48 * math.sin(a)
        g.ellipse((cx - 17, cy - 17, cx + 17, cy + 17), fill=(52, 34, 86, 255), outline=(170, 120, 230, 255), width=2)
        # repère du sens du cercle (sens des aiguilles d'une montre)
        b = a + math.pi / 4
        ax, ay = 70 + 48 * math.cos(b), 70 + 48 * math.sin(b)
        g.ellipse((ax - 3, ay - 3, ax + 3, ay + 3), fill=(255, 220, 120, 255))
    bg.alpha_composite(ring, (164, 34))
    d.rectangle((0, 216, W, H), fill=(30, 18, 50, 255))
    d.rectangle((0, 216, W, 216), fill=EDGE)
    save(bg, 'chambre.png')
    cell = panel((42, 42), (58, 38, 94, 255), (130, 90, 190, 255), 6)
    save(cell, 'case.png')
    cur = Image.new('RGBA', (44, 44), (0, 0, 0, 0))
    ImageDraw.Draw(cur).rounded_rectangle((0, 0, 43, 43), radius=7, outline=(255, 210, 90, 255), width=2)
    save(cur, 'curseur.png')
    small = Image.new('RGBA', (30, 4), (0, 0, 0, 0))
    g = ImageDraw.Draw(small)
    for k in range(5):
        g.rectangle((k * 6, 0, k * 6 + 4, 3), fill=(190, 90, 255, 255))
    save(small, 'jauge_petite.png')
    back = panel((140, 10), (24, 14, 36, 255), EDGE, 3)
    save(back, 'jauge_fond.png')
    bar = Image.new('RGBA', (136, 6), (0, 0, 0, 0))
    g = ImageDraw.Draw(bar)
    for x in range(136):
        t = x / 135
        g.line((x, 0, x, 5), fill=(int(120 + 100 * t), int(40 + 20 * t), int(200 - 40 * t), 255))
    for k in range(1, 5):
        g.line((k * 136 // 5, 0, k * 136 // 5, 5), fill=(30, 10, 40, 255))
    save(bar, 'jauge.png')
    resume = Image.new('RGBA', (136, 4), (0, 0, 0, 0))
    g = ImageDraw.Draw(resume)
    g.rectangle((0, 0, 135, 3), fill=(176, 80, 240, 255))
    for k in range(1, 5):
        g.line((k * 136 // 5, 0, k * 136 // 5, 3), fill=(60, 20, 80, 255))
    save(resume, 'jauge_resume.png')


def purification():
    bg = gradient((10, 6, 24), (52, 30, 80))
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    for r in range(110, 10, -4):
        g.ellipse((160 - r, 112 - r, 160 + r, 112 + r), fill=(150, 110, 220, 8))
    bg.alpha_composite(glow)
    d = ImageDraw.Draw(bg)
    d.ellipse((90, 150, 230, 178), fill=(80, 60, 120, 255), outline=(180, 150, 240, 255), width=2)
    save(bg, 'purification.png')
    aura = Image.new('RGBA', (140, 140), (0, 0, 0, 0))
    px = aura.load()
    for y in range(140):
        for x in range(140):
            dist = math.hypot(x - 70, y - 70) / 70
            if dist < 1:
                a = int(200 * (1 - dist) ** 1.5)
                px[x, y] = (110, 30, 170, a)
    save(aura, 'aura.png')
    save(Image.new('RGBA', (W, H), (255, 255, 255, 255)), 'blanc.png')


def recolor(im):
    """Rouge -> violet sombre, blanc -> gris lavande (Snatch Ball)."""
    im = im.convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if s > 0.35 and (h < 0.08 or h > 0.9):
                nr, ng, nb = colorsys.hls_to_rgb(0.77, l * 0.75, min(1, s))
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
            elif l > 0.7 and s < 0.3:
                px[x, y] = (int(r * 0.78), int(g * 0.72), int(b * 0.86), a)
    return im


def snag_ball():
    icon = recolor(Image.open(os.path.join(ROOT, 'graphics', 'icons', '004.png')))
    icon.save(os.path.join(ROOT, 'graphics', 'icons', 'snag_ball.png'), optimize=True)
    ball = recolor(Image.open(os.path.join(ROOT, 'graphics', 'ball', 'ball_1.png')))
    ball.save(os.path.join(ROOT, 'graphics', 'ball', 'ball_snag.png'), optimize=True)


if __name__ == '__main__':
    chamber()
    purification()
    snag_ball()

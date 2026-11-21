# Tournoi : prépare les images et la musique de l'écran de sélection d'équipe
# d'après les ressources du plugin « Tournament Selection » (Neiro) pour Essentials (écran 512x384)
#
# Usage : python build_assets.py <dossier « Tournament_Selection_Plugin_Essentials_v21.1-main »> [dossier du projet]
#   - fond animé et particules : une image sur 3, réduites en 320x240, rangées par planches de 10 images
#     (graphics/interface/tournoi/bg_0.png … et particles_0.png …)
#   - barres, emplacements de Ball, Ball, numéros, objet caché : redessinés en 320x240
#   - musique : audio/bgm/tournoi_selection.ogg
import os
import shutil
import sys

from PIL import Image, ImageDraw

SRC = sys.argv[1] if len(sys.argv) > 1 else '.'
ROOT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), '..', '..')
GFX = os.path.join(SRC, 'Graphics', 'Plugins', 'Tournament Selection')
OUT = os.path.join(ROOT, 'graphics', 'interface', 'tournoi')
W, H = 320, 240
STEP = 3          # une image sur 3 (80 images sur 239)
PER_SHEET = 10    # images par planche

FILL = (52, 21, 7, 255)
FILL_SEL = (68, 42, 28, 255)
EDGE = (238, 124, 75, 255)
EDGE_SEL = (254, 255, 104, 255)
YELLOW = (255, 216, 0, 255)
RED = (230, 30, 20, 255)


def frames(folder, prefix, mode):
    names = sorted(n for n in os.listdir(os.path.join(GFX, folder)) if n.startswith(prefix) and n.endswith('.png'))
    names = names[::STEP] if len(names) > 100 else names
    return [Image.open(os.path.join(GFX, folder, n)).convert(mode).resize((W, H), Image.LANCZOS) for n in names]


def sheets(images, name, mode):
    for k in range(0, len(images), PER_SHEET):
        part = images[k:k + PER_SHEET]
        sheet = Image.new(mode, (W * PER_SHEET, H), (0, 0, 0, 0) if mode == 'RGBA' else (0, 0, 0))
        for i, im in enumerate(part):
            sheet.paste(im, (i * W, 0))
        if mode == 'RGB':
            sheet = sheet.quantize(colors=256, method=Image.MEDIANCUT, dither=Image.FLOYDSTEINBERG)
        sheet.save(os.path.join(OUT, f'{name}_{k // PER_SHEET}.png'), optimize=True)
    return (len(images) + PER_SHEET - 1) // PER_SHEET


def poke_bar():
    # 2 états (normal, choisi) : parallélogramme 128x24, bord droit en biais
    bw, bh, slant = 128, 24, 4
    im = Image.new('RGBA', (bw * 2, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for k, (fill, edge) in enumerate(((FILL, EDGE), (FILL_SEL, EDGE_SEL))):
        ox = k * bw
        pts = [(ox, 0), (ox + bw - 1 - slant, 0), (ox + bw - 1, bh - 1), (ox, bh - 1)]
        d.polygon(pts, fill=fill, outline=edge)
        d.line([(ox, 1), (ox + bw - 2 - slant, 1)], fill=edge)
        d.line([(ox, bh - 2), (ox + bw - 2, bh - 2)], fill=edge)
    im.save(os.path.join(OUT, 'poke_bar.png'))


def ball_bar():
    # barre du joueur (bord jaune, à gauche) et de l'adversaire (bord rouge, à droite) : 2 lignes de 124x16
    bw, bh = 124, 16
    im = Image.new('RGBA', (bw, bh * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for k, edge in enumerate((YELLOW, RED)):
        oy = k * bh
        glow = edge[:3] + (70,)
        d.rounded_rectangle((0, oy, bw - 1, oy + bh - 1), radius=7, fill=glow)
        d.rounded_rectangle((0, oy + 1, bw - 2, oy + bh - 2), radius=6, fill=FILL, outline=edge)
    im.save(os.path.join(OUT, 'ball_bar.png'))


def balls():
    # emplacement vide (cercle) et Poké Ball, 11x11 chacun
    s = 11
    im = Image.new('RGBA', (s * 2, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, s - 1, s - 1), outline=(255, 170, 40, 255))
    d.ellipse((s, 0, 2 * s - 1, s - 1), fill=(250, 250, 250, 255), outline=(40, 40, 40, 255))
    d.pieslice((s, 0, 2 * s - 1, s - 1), 180, 360, fill=(230, 50, 50, 255), outline=(40, 40, 40, 255))
    d.line((s + 1, 5, 2 * s - 2, 5), fill=(40, 40, 40, 255))
    d.ellipse((s + 4, 3, s + 6, 7), fill=(250, 250, 250, 255), outline=(40, 40, 40, 255))
    im.save(os.path.join(OUT, 'balls.png'))


DIGITS = {
    '1': ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'],
    '2': ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'],
    '3': ['####.', '....#', '....#', '.###.', '....#', '....#', '####.'],
    '4': ['...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.'],
    '5': ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.'],
    '6': ['.###.', '#....', '#....', '####.', '#...#', '#...#', '.###.'],
}


def nums():
    # pastilles 1 à 6 (13x13), bleues comme celles du plugin d'origine
    s = 13
    im = Image.new('RGBA', (s * 6, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(6):
        ox = i * s
        d.rounded_rectangle((ox, 0, ox + s - 1, s - 1), radius=3, fill=(26, 66, 118, 255), outline=(17, 45, 81, 255))
        d.line((ox + 2, 1, ox + s - 3, 1), fill=(60, 110, 180, 255))
        for y, row in enumerate(DIGITS[str(i + 1)]):
            for x, c in enumerate(row):
                if c == '#':
                    im.putpixel((ox + 4 + x, 3 + y), (255, 255, 255, 255))
    im.save(os.path.join(OUT, 'nums.png'))


def item_hide():
    src = os.path.join(GFX, 'item_hide.png')
    im = Image.open(src).convert('RGBA')
    box = im.getbbox() or (0, 0, im.width, im.height)
    im = im.crop(box)
    k = 14 / max(im.width, im.height)
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    out = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    out.alpha_composite(im, ((16 - im.width) // 2, (16 - im.height) // 2))
    out.save(os.path.join(OUT, 'item_hide.png'))


def top_bar():
    im = Image.new('RGBA', (W, 14), (0, 0, 0, 163))
    d = ImageDraw.Draw(im)
    d.line((0, 0, W, 0), fill=(0, 0, 0, 81))
    d.line((0, 13, W, 13), fill=(0, 0, 0, 81))
    im.save(os.path.join(OUT, 'top_bar.png'))


def menu():
    # menu de 3 lignes (72x52) puis menu Oui / Non (72x20) ; curseurs (34x16 puis 68x14) ; bandeau de question
    im = Image.new('RGBA', (72, 72), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 71, 51), radius=4, fill=(30, 12, 4, 235), outline=EDGE)
    d.rounded_rectangle((0, 52, 71, 71), radius=4, fill=(30, 12, 4, 235), outline=EDGE)
    im.save(os.path.join(OUT, 'menu.png'))
    cur = Image.new('RGBA', (68, 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(cur)
    d.rounded_rectangle((0, 0, 33, 15), radius=3, fill=(254, 255, 104, 70), outline=EDGE_SEL)
    d.rounded_rectangle((0, 16, 67, 29), radius=3, fill=(254, 255, 104, 70), outline=EDGE_SEL)
    cur.save(os.path.join(OUT, 'menu_cursor.png'))
    ban = Image.new('RGBA', (248, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(ban)
    d.rounded_rectangle((0, 0, 247, 19), radius=5, fill=(30, 12, 4, 235), outline=EDGE_SEL)
    ban.save(os.path.join(OUT, 'banner.png'))


def bracket():
    # cases du tableau (150x13) : normale, joueur, éliminé ; trait (1 pixel : éteint, allumé) ; voile sombre
    w, hh = 150, 13
    im = Image.new('RGBA', (w, hh * 3), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    styles = [((52, 21, 7, 235), EDGE), ((68, 42, 28, 245), EDGE_SEL), ((25, 12, 6, 210), (110, 60, 40, 255))]
    for k, (fill, edge) in enumerate(styles):
        d.rectangle((0, k * hh, w - 1, k * hh + hh - 1), fill=fill, outline=edge)
    im.save(os.path.join(OUT, 'slot.png'))
    px = Image.new('RGBA', (2, 1), (0, 0, 0, 0))
    px.putpixel((0, 0), (120, 70, 50, 255))
    px.putpixel((1, 0), (254, 230, 104, 255))
    px.save(os.path.join(OUT, 'pixel.png'))
    Image.new('RGBA', (W, H), (0, 0, 0, 120)).save(os.path.join(OUT, 'shade.png'))


def main():
    os.makedirs(OUT, exist_ok=True)
    n_bg = sheets(frames('bg', 'bg_', 'RGB'), 'bg', 'RGB')
    n_pa = sheets(frames('particles', 'particles_', 'RGBA'), 'particles', 'RGBA')
    poke_bar()
    ball_bar()
    balls()
    nums()
    item_hide()
    top_bar()
    menu()
    bracket()
    music = os.path.join(SRC, 'Audio', 'BGM')
    for name in os.listdir(music) if os.path.isdir(music) else []:
        if name.lower().endswith('.ogg'):
            os.makedirs(os.path.join(ROOT, 'audio', 'bgm'), exist_ok=True)
            shutil.copyfile(os.path.join(music, name), os.path.join(ROOT, 'audio', 'bgm', 'tournoi_selection.ogg'))
            break
    print(f'{n_bg} planches de fond, {n_pa} planches de particules -> {OUT}')


if __name__ == '__main__':
    main()

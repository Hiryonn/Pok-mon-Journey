#!/usr/bin/env python3
"""Images d'exemple de l'appli Aide (graphics/interface/aide/*.png, 184 x 96).

Elles sont composées à partir des vrais graphismes du jeu (téléphone, roue des mécaniques, cuisine, casino) :
ce ne sont pas des captures d'écran. Pour les refaire : python3 tools/aide/generer_images.py
Pour mettre une vraie capture à la place, remplacer le fichier (même nom, 184 x 96).
Textes limités aux touches (A, B, L, R) : les images valent pour le français et l'anglais.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
UI = os.path.join(ROOT, 'graphics', 'interface')
OUT = os.path.join(UI, 'aide')
W, H = 184, 96
BG = (214, 228, 238, 255)
FONT = '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf'


def load(path):
    return Image.open(os.path.join(UI, path)).convert('RGBA')


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def canvas():
    return Image.new('RGBA', (W, H), BG)


def fit(im, box_w, box_h):
    ratio = min(box_w / im.width, box_h / im.height)
    return im.resize((max(1, int(im.width * ratio)), max(1, int(im.height * ratio))), Image.LANCZOS)


def badge(d, x, y, text, color=(40, 90, 150)):
    f = font(9)
    w = int(d.textlength(text, font=f)) + 8
    d.rounded_rectangle((x, y, x + w, y + 13), 3, fill=color)
    d.text((x + 4, y + 2), text, font=f, fill='white')
    return w


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    im.convert('RGBA').save(os.path.join(OUT, name + '.png'))
    print('ok', name)


def telephone_applis():
    im = canvas()
    phone = load('pokesmart/phone.png')
    base = Image.new('RGBA', phone.size, (0, 0, 0, 0))
    base.alpha_composite(phone)
    tile, tile_sel = load('pokesmart/tile.png'), load('pokesmart/tile_selected.png')
    icons = ['icon_pokedex', 'icon_party', 'icon_bag', 'icon_map', 'icon_pc', 'icon_book', 'icon_trainercard', 'icon_trophy', 'icon_help']
    for i, name in enumerate(icons):
        x, y = 99 - 99 + 6 + 5 + (i % 3) * 32, 52 + (i // 3) * 30
        base.alpha_composite(tile_sel if i == 4 else tile, (x, y))
        icon = load('pokesmart/%s.png' % name)
        frame = icon.crop((32 if i == 4 else 0, 0, 64 if i == 4 else 32, 32))
        base.alpha_composite(frame, (x + (tile.width - 32) // 2, y + (tile.height - 32) // 2))
    crop = base.crop((0, 0, phone.width, 150))
    crop = fit(crop, 110, H - 4)
    im.alpha_composite(crop, (6, 2))
    d = ImageDraw.Draw(im)
    for i, (key, label) in enumerate([('A', '>'), ('B', 'x'), ('L R', '< >')]):
        badge(d, 126, 14 + i * 26, key)
        d.text((126 + 30, 15 + i * 26), label, font=font(10), fill=(40, 60, 90))
    save(im, 'telephone_applis')


def telephone_reseau():
    im = canvas()
    d = ImageDraw.Draw(im)
    for i, (bars, ok) in enumerate([(4, True), (2, True), (0, False)]):
        y = 6 + i * 30
        d.rounded_rectangle((8, y, W - 8, y + 24), 4, fill=(36, 48, 90, 255))
        icon = load('pokesmart/reseau_mobile_%d.png' % bars)
        icon = icon.resize((icon.width * 2, icon.height * 2), Image.NEAREST)
        im.alpha_composite(icon, (14, y + (24 - icon.height) // 2))
        d.text((44, y + 5), str(bars), font=font(13), fill='white')
        pc = load('pokesmart/icon_pc.png').crop((0, 0, 32, 32)).resize((22, 22), Image.LANCZOS)
        if not ok:
            pc = pc.convert('LA').convert('RGBA')
            pc.putalpha(pc.getchannel('A').point(lambda v: v // 3))
        im.alpha_composite(pc, (W - 40, y + 1))
        if not ok:
            d.line((W - 38, y + 3, W - 20, y + 21), fill=(220, 60, 60), width=2)
            d.line((W - 38, y + 21, W - 20, y + 3), fill=(220, 60, 60), width=2)
    save(im, 'telephone_reseau')


def telephone_perso():
    im = canvas()
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((38, 3, W - 38, H - 3), 6, fill=(44, 52, 110, 255))
    choice, choice_sel = load('pokesmart/choice.png'), load('pokesmart/choice_selected.png')
    for i, text in enumerate(['1', '2', '3']):
        x, y = (W - choice.width) // 2, 10 + i * 26
        im.alpha_composite(choice_sel if i == 1 else choice, (x, y))
        d.text((x + choice.width // 2, y + 9), text, font=font(10), fill='black', anchor='mm')
    badge(d, 4, 12, 'A')
    badge(d, 4, 38, 'B')
    save(im, 'telephone_perso')


def combat_roue():
    im = canvas()
    ring = fit(load('gimmicks/wheel/ring.png'), 176, 90)
    im.alpha_composite(ring, ((W - ring.width) // 2, 3))
    slot = load('gimmicks/wheel/slot.png')
    slot = slot.resize((int(slot.width * 0.6), int(slot.height * 0.6)), Image.LANCZOS)
    names = ['mega', 'zmove', 'dynamax', 'tera']
    pos = [(8, 26), (W - 8 - slot.width, 26), (30, 62), (W - 30 - slot.width, 62)]
    d = ImageDraw.Draw(im)
    for name, (x, y) in zip(names, pos):
        im.alpha_composite(slot, (x, y))
        icon = load('gimmicks/wheel/icon_%s.png' % name)
        icon = icon.resize((icon.width * 3 // 2, icon.height * 3 // 2), Image.LANCZOS)
        im.alpha_composite(icon, (x + 3, y + (slot.height - icon.height) // 2))
    badge(d, 70, 38, 'Y')
    save(im, 'combat_roue')


def screen(path, name):
    im = canvas()
    shot = fit(load(path), W - 4, H - 4)
    im.alpha_composite(shot, ((W - shot.width) // 2, (H - shot.height) // 2))
    save(im, name)


if __name__ == '__main__':
    telephone_applis()
    telephone_reseau()
    telephone_perso()
    combat_roue()
    screen('poffin/fond_cuisine.png', 'poffin_cuisine')
    screen('casino_jp/machine.png', 'casino_jp')

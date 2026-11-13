# Interface Horizon : graphismes du sac (320 x 240) à partir de « Bag Screen with Party » (Essentials, images en 2x)
#   python build_bag_assets.py <dossier "Bag Screen with Party"> <racine du projet>
# Écrit graphics/interface/bag_horizon/*.png
import os
import sys
from PIL import Image, ImageDraw

SRC, ROOT = sys.argv[1], sys.argv[2]
OUT = os.path.join(ROOT, 'graphics/interface/bag_horizon')
os.makedirs(OUT, exist_ok=True)

W, H = 320, 240
LIST = (120, 22, 196, 168)        # boîte de la liste : x, y, largeur, hauteur
ROW_TOP, ROW_H = 4, 16            # 1re ligne de la liste, hauteur d'une ligne
BAR_Y = 194                       # barre de description


def load(name):
    im = Image.open(os.path.join(SRC, name)).convert('RGBA')
    return im.resize((im.width // 2, im.height // 2), Image.NEAREST)


def save(im, name):
    im.save(os.path.join(OUT, name + '.png'))


def hslice(im, width, left, right):
    """Étire une image en largeur en gardant ses bords (left / right pixels) et en répétant le milieu."""
    out = Image.new('RGBA', (width, im.height), (0, 0, 0, 0))
    out.paste(im.crop((0, 0, left, im.height)), (0, 0))
    out.paste(im.crop((im.width - right, 0, im.width, im.height)), (width - right, 0))
    mid = im.crop((left, 0, im.width - right, im.height))
    x = left
    while x < width - right:
        w = min(mid.width, width - right - x)
        out.paste(mid.crop((0, 0, w, mid.height)), (x, 0))
        x += w
    return out


# --- Fond -------------------------------------------------------------------------------
bg = load('bg.png')
top, bottom = bg.getpixel((10, 10)), bg.getpixel((10, 180))
im = Image.new('RGBA', (W, H), top)
ImageDraw.Draw(im).rectangle((0, BAR_Y - 6, W, H), fill=bottom)
save(im, 'background')
pano = load('panorama.png')
save(pano, 'panorama')
save(load('panoramaDark.png'), 'panorama_dark')
grad = Image.open(os.path.join(SRC, 'grad.png')).convert('RGBA').resize((W, BAR_Y), Image.BILINEAR)
save(grad, 'grad')

# --- Équipe ---------------------------------------------------------------------------------
ui1 = load('ui1.png')
save(ui1.crop((2, 2, 113, 145)), 'party_frame')
save(ui1.crop((116, 17, 181, 22)), 'title_line')
for shape in ('round', 'rect'):
    sheet = Image.new('RGBA', (55, 50 * 6), (0, 0, 0, 0))
    for i, state in enumerate(('desel', 'sel', 'faint', 'faint_sel', 'move', 'move_sel')):
        sheet.paste(load(f'ptpanel_{shape}_{state}.png'), (0, 50 * i))
    save(sheet, 'panel_' + shape)
hp_back = load('overlay_hp_back.png').crop((0, 1, 49, 6))
hp = Image.open(os.path.join(SRC, 'overlay_hp.png')).convert('RGBA').crop((0, 0, 94, 26))
hp = hp.resize((47, 13), Image.NEAREST)
bar = Image.new('RGBA', (49, 5 + 9), (0, 0, 0, 0))
bar.paste(hp_back, (0, 0))
for state, y in enumerate((9, 5, 1)):         # rouge, jaune, vert (état 0 = peu de PV)
    bar.paste(hp.crop((0, y, 47, y + 3)), (0, 5 + 3 * state))
save(bar, 'hp_bar')
save(load('overlay_lv.png'), 'lv')
save(load('shiny.png'), 'shiny')
save(load('icon_pokerus.png'), 'pokerus')

# --- Liste ------------------------------------------------------------------------------------
x, y, w, h = LIST
box = Image.new('RGBA', (w, h), (0, 0, 0, 0))
d = ImageDraw.Draw(box)
d.rectangle((0, 0, w - 1, h - 1), fill=(56, 56, 56, 128))
d.rectangle((1, 1, w - 2, h - 2), fill=(47, 46, 54, 255))
for c in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
    box.putpixel(c, (0, 0, 0, 0))
for ly in range(ROW_TOP + ROW_H - 1, h - 4, ROW_H):
    for lx in range(1, w - 1, 2):
        box.putpixel((lx, ly), (59, 57, 73, 255))
save(box, 'list')
money = Image.new('RGBA', (111, 18), (0, 0, 0, 0))
d = ImageDraw.Draw(money)
d.rectangle((0, 0, 110, 17), fill=(56, 56, 56, 128))
d.rectangle((1, 1, 109, 16), fill=(47, 46, 54, 255))
save(money, 'money')
for name in ('cursor', 'cursor_party1', 'cursor_party2', 'cursor_swap'):
    c = load(name + '.png').crop((2, 6, 139, 30))     # cadre + ombre
    save(hslice(c, w + 4, 12, 12), name)
track = Image.new('RGBA', (2, h - 8), (0, 0, 0, 128))
save(track, 'slider_track')
save(load('icon_slider.png').crop((25, 0, 29, 19)), 'slider')
save(load('icon_register.PNG'), 'register')
save(load('icon_pocket.png'), 'pockets')

# --- Barre de description --------------------------------------------------------------------
ui2 = load('ui2.png')
save(hslice(ui2.crop((0, 145, 256, 192)), W, 120, 16), 'info')
save(Image.new('RGBA', (W, H), (0, 0, 0, 96)), 'shadow')    # derrière les choix (Utiliser, Donner…)

# --- Couleurs du Pokédex Horizon (graphics/pokedex/pe) -------------------------------------
LIGHT, SHEEN = (229, 243, 250), (250, 253, 254)
BLUE, STEEL, SLATE, DEEP = (80, 126, 166), (69, 103, 129), (51, 71, 81), (36, 52, 62)
SKY, PALE = (145, 201, 247), (213, 238, 248)
COMMON = {
    (47, 46, 54): STEEL, (55, 58, 66): (62, 94, 120), (59, 57, 73): (88, 128, 160), (78, 83, 100): BLUE,
    (59, 65, 81): SLATE, (36, 36, 36): DEEP, (157, 171, 178): SKY, (56, 56, 56): DEEP, (0, 0, 0): DEEP,
    (82, 82, 82): SLATE, (117, 117, 117): BLUE, (57, 57, 57): DEEP,
    # cases « APTE » (vertes dans le pack) : bleues
    (29, 81, 52): (52, 120, 170), (29, 97, 60): (62, 140, 190), (194, 211, 201): (200, 232, 250), (128, 157, 153): (120, 180, 225),
}
SPECIAL = {
    'cursor': {(248, 248, 248): SKY, (78, 83, 100): (110, 170, 220)},
    'panel_rect': {(248, 248, 248): LIGHT}, 'panel_round': {(248, 248, 248): LIGHT},
    'pockets': {(78, 83, 100): STEEL},
    'slider': {(78, 83, 100): PALE},
}


def recolor(name, extra=None):
    path = os.path.join(OUT, name + '.png')
    im = Image.open(path).convert('RGBA')
    table = dict(COMMON)
    table.update(SPECIAL.get(name, {}))
    table.update(extra or {})
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in table:
                px[x, y] = table[(r, g, b)] + (a,)
    im.save(path)


for name in ('list', 'money', 'cursor', 'cursor_party1', 'cursor_party2', 'cursor_swap', 'party_frame', 'panel_rect',
             'panel_round', 'info', 'pockets', 'slider', 'title_line', 'hp_bar', 'lv'):
    recolor(name, {(0, 0, 0): (0, 0, 0)} if name in ('hp_bar', 'lv') else None)

# Fond clair avec le reflet en biais du Pokédex, bandeau bleu en bas
im = Image.new('RGBA', (W, H), LIGHT)
d = ImageDraw.Draw(im)
d.polygon([(150, 0), (230, 0), (110, BAR_Y), (30, BAR_Y)], fill=SHEEN)
d.rectangle((0, BAR_Y - 6, W, H), fill=BLUE)
save(im, 'background')
# Motif : pois bleu très clair, discrets
for name in ('panorama', 'panorama_dark'):
    src = Image.open(os.path.join(OUT, name + '.png')).convert('RGBA')
    alpha = src.split()[3].point(lambda a: a * 45 // 100)
    tinted = Image.new('RGBA', src.size, (190, 222, 244, 0))
    tinted.putalpha(alpha)
    save(tinted, name)
# Dégradé : bleu léger sur les bords
src = Image.open(os.path.join(OUT, 'grad.png')).convert('RGBA')
tinted = Image.new('RGBA', src.size, SKY + (0,))
tinted.putalpha(src.split()[3].point(lambda a: a * 35 // 100))
save(tinted, 'grad')
# Bandeau du haut (comme le POKÉDEX) : bleu, liseré, onglet ardoise pour le nom de la poche
im = Image.new('RGBA', (W, 20), BLUE)
d = ImageDraw.Draw(im)
d.rectangle((0, 12, W, 13), fill=STEEL)
d.rectangle((0, 18, W, 19), fill=SLATE)
d.polygon([(0, 0), (124, 0), (114, 19), (0, 19)], fill=SLATE)
save(im, 'header')
print('ok', OUT)

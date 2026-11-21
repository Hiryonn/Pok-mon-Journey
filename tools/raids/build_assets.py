# Raids : graphismes (style de l'interface Horizon) et ressources reprises du plugin « [DBK] Raid Battles »
#   python3 tools/raids/build_assets.py <dossier « Raid Battles »> [racine du projet]
# graphics/interface/raids/   écran de l'antre, récompenses, barre du boss, encouragements, aventures, transitions
# graphics/characters/        antres (raid_den_basic, raid_den_ultra, raid_den_max, raid_den_tera ; moitié de taille)
# graphics/battlebacks/       back_raid_ultra, back_raid_max, back_raid_tera (320 x 240)
# graphics/icons/raid_bait.png, audio/bgm/raid_*.ogg
import os
import shutil
import sys
from PIL import Image, ImageDraw, ImageFilter

SRC = sys.argv[1]
ROOT = sys.argv[2] if len(sys.argv) > 2 else '.'
DBK = os.path.join(SRC, 'Graphics/Plugins/Raid Battles')
OUT = os.path.join(ROOT, 'graphics/interface/raids')
S = 4
STEEL = (80, 126, 166)
SLATE = (51, 71, 81)
DEEP = (34, 46, 56)
NIGHT = (22, 30, 38)
WHITE = (240, 246, 250)
LINE = (196, 216, 234)
SHADE = (0, 0, 0, 153)
STYLES = {'basic': (214, 76, 64), 'ultra': (232, 190, 58), 'max': (206, 46, 110), 'tera': (86, 196, 228)}


def path(*p):
    full = os.path.join(OUT, *p)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    return full


def big(w, h):
    img = Image.new('RGBA', (w * S, h * S))
    return img, ImageDraw.Draw(img)


def small(img, w, h):
    return img.resize((w, h), Image.LANCZOS)


def rgba(c, a=255):
    return tuple(c[:3]) + (a,)


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


# --- Fonds d'écran (antre, récompenses, menus des aventures) -------------------------------------------------
def background(style, title_w=150):
    accent = STYLES[style]
    img = Image.new('RGBA', (320, 240))
    d = ImageDraw.Draw(img)
    for y in range(240):
        d.line((0, y, 319, y), fill=rgba(mix(DEEP, NIGHT, y / 239)))
    stripes = Image.new('RGBA', (320, 240))
    sd = ImageDraw.Draw(stripes)
    for x in range(-240, 320, 12):
        sd.line((x, 239, x + 240, 0), fill=(255, 255, 255, 7))
    img.alpha_composite(stripes)
    hi, hd = big(320, 24)
    hd.polygon([(0, 0), (title_w * S, 0), ((title_w - 14) * S, 22 * S), (0, 22 * S)], fill=rgba(STEEL))
    hd.polygon([((title_w - 14) * S, 22 * S), (title_w * S, 0), ((title_w + 6) * S, 0), ((title_w - 8) * S, 22 * S)], fill=rgba(accent))
    hd.rectangle((0, 22 * S, 320 * S, 23 * S), fill=rgba(LINE))
    img.alpha_composite(small(hi, 320, 24))
    return img


def frame(size, fill=SLATE, radius=5, accent=None, alpha=235):
    w, h = size
    im, d = big(w, h)
    d.rounded_rectangle((0, 0, w * S - 1, h * S - 1), radius * S, fill=rgba(WHITE))
    d.rounded_rectangle((S, S, (w - 1) * S - 1, (h - 1) * S - 1), (radius - 1) * S, fill=rgba(fill, alpha))
    if accent:
        d.rectangle((S, S, 4 * S, (h - 1) * S - 1), fill=rgba(accent))
    return small(im, w, h)


for style, accent in STYLES.items():
    bg = background(style)
    bg.alpha_composite(frame((148, 158), accent=accent), (6, 28))
    bg.alpha_composite(frame((158, 112)), (158, 28))
    bg.alpha_composite(frame((158, 40), fill=DEEP), (158, 146))
    bg.alpha_composite(frame((308, 46), fill=DEEP), (6, 190))
    bg.save(path('den', f'bg_{style}.png'))
    rw = background(style, 190)
    rw.alpha_composite(frame((130, 158), accent=accent), (6, 28))
    rw.alpha_composite(frame((176, 158)), (138, 28))
    rw.alpha_composite(frame((308, 46), fill=DEEP), (6, 190))
    rw.save(path('den', f'rewards_{style}.png'))
    mb = background(style, 170)
    mb.save(path('menus', f'bg_{style}.png'))
    # cadre de la case vide du joueur (icône d'équipe)
    slot, sd = big(30, 30)
    sd.ellipse((0, 0, 30 * S - 1, 30 * S - 1), fill=rgba(WHITE))
    sd.ellipse((S, S, 29 * S - 1, 29 * S - 1), fill=rgba(mix(SLATE, accent, 0.25)))
    small(slot, 30, 30).save(path('den', f'slot_{style}.png'))

# boutons de l'antre (normal / choisi), 146 x 22
btn = Image.new('RGBA', (146, 44))
for i, (fill, edge) in enumerate([(DEEP, LINE), (STEEL, WHITE)]):
    im, d = big(146, 22)
    d.polygon([(6 * S, 0), (146 * S - 1, 0), (140 * S, 22 * S - 1), (0, 22 * S - 1)], fill=rgba(edge))
    d.polygon([(7 * S, S), (144 * S, S), (139 * S, 21 * S - 1), (2 * S, 21 * S - 1)], fill=rgba(fill))
    btn.alpha_composite(small(im, 146, 22), (0, 22 * i))
btn.save(path('den', 'buttons.png'))

# étoile du rang (allumée / éteinte), 12 x 12
import math


def star(fill, edge):
    im, d = big(12, 12)
    pts = []
    for k in range(10):
        r = (5.6 if k % 2 == 0 else 2.6) * S
        a = math.radians(-90 + k * 36)
        pts.append((6 * S + r * math.cos(a), 6.2 * S + r * math.sin(a)))
    d.polygon(pts, fill=rgba(edge))
    pts2 = []
    for k in range(10):
        r = (4.2 if k % 2 == 0 else 1.9) * S
        a = math.radians(-90 + k * 36)
        pts2.append((6 * S + r * math.cos(a), 6.2 * S + r * math.sin(a)))
    d.polygon(pts2, fill=rgba(fill))
    return small(im, 12, 12)


stars = Image.new('RGBA', (12, 24))
stars.alpha_composite(star((255, 214, 64), (120, 70, 10)), (0, 0))
stars.alpha_composite(star((70, 84, 96), (30, 38, 46)), (0, 12))
stars.save(path('star.png'))

# ligne d'objet des récompenses (normal / choisie), 168 x 18
row = Image.new('RGBA', (168, 36))
for i, fill in enumerate([(255, 255, 255, 0), rgba(STEEL, 230)]):
    im, d = big(168, 18)
    if i:
        d.rounded_rectangle((0, 0, 168 * S - 1, 18 * S - 1), 4 * S, fill=fill, outline=rgba(WHITE), width=S)
    row.alpha_composite(small(im, 168, 18), (0, 18 * i))
row.save(path('den', 'row.png'))

# --- Combat : barre du boss, bouclier, compteurs ---------------------------------------------------------------
bar, d = big(320, 36)
d.polygon([(0, 0), (320 * S, 0), (320 * S, 26 * S), (296 * S, 34 * S), (0, 34 * S)], fill=SHADE)
d.line([(0, 34 * S), (296 * S, 34 * S), (320 * S, 26 * S)], fill=(0, 0, 0, 255), width=S)
d.rectangle((66 * S, 17 * S, 306 * S, 23 * S), fill=(0, 0, 0, 255))
small(bar, 320, 36).save(path('battle', 'boss_bar.png'))

src = Image.open(os.path.join(ROOT, 'graphics/interface/battle_pj/hp_bar.png')).convert('RGBA')
W = 238
hp = Image.new('RGBA', (W, src.height))
hp.paste(src.crop((0, 0, 1, src.height)), (0, 0))
mid = src.crop((40, 0, 41, src.height)).resize((W - 2, src.height))
hp.paste(mid, (1, 0))
hp.paste(src.crop((81, 0, 82, src.height)), (W - 1, 0))
hp.save(path('battle', 'hp_long.png'))

# barres du bouclier (pleine / vide), 13 x 7
cell = Image.new('RGBA', (13, 14))
for i, (fill, edge) in enumerate([((150, 206, 250), (230, 246, 255)), ((40, 52, 64), (90, 104, 118))]):
    im, d2 = big(13, 7)
    d2.polygon([(3 * S, 0), (13 * S - 1, 0), (10 * S, 7 * S - 1), (0, 7 * S - 1)], fill=rgba(edge))
    d2.polygon([(4 * S, S), (12 * S - 2, S), (9.5 * S, 6 * S - 1), (1.5 * S, 6 * S - 1)], fill=rgba(fill))
    cell.alpha_composite(small(im, 13, 7), (0, 7 * i))
cell.save(path('battle', 'shield.png'))

# compteurs (tours, K.O.), 64 x 15 chacun ; icônes 11 x 11 (sablier, cœur)
pill = frame((48, 15), fill=DEEP, radius=4, alpha=220)
pill.save(path('battle', 'counter.png'))
icons = Image.new('RGBA', (11, 22))
im, d = big(11, 11)
d.polygon([(1 * S, 1 * S), (10 * S, 1 * S), (5.5 * S, 5.5 * S)], fill=rgba(WHITE))
d.polygon([(1 * S, 10 * S), (10 * S, 10 * S), (5.5 * S, 5.5 * S)], fill=rgba(LINE))
d.rectangle((0, 0, 11 * S, S), fill=rgba(WHITE))
d.rectangle((0, 10 * S, 11 * S, 11 * S - 1), fill=rgba(WHITE))
icons.alpha_composite(small(im, 11, 11), (0, 0))
im, d = big(11, 11)
d.ellipse((0.5 * S, 1 * S, 6 * S, 6.5 * S), fill=(236, 72, 92, 255))
d.ellipse((5 * S, 1 * S, 10.5 * S, 6.5 * S), fill=(236, 72, 92, 255))
d.polygon([(0.8 * S, 4.5 * S), (10.2 * S, 4.5 * S), (5.5 * S, 10.3 * S)], fill=(236, 72, 92, 255))
icons.alpha_composite(small(im, 11, 11), (0, 11))
icons.save(path('battle', 'counter_icons.png'))

# --- Encouragements : cadre, lignes, niveaux, icônes ---------------------------------------------------------
cheer = frame((196, 132), fill=SLATE)
ci, cd = big(196, 132)
cd.polygon([(6 * S, 5 * S), (120 * S, 5 * S), (113 * S, 17 * S), (6 * S, 17 * S)], fill=rgba(STEEL))
cheer.alpha_composite(small(ci, 196, 132))
cheer.save(path('battle', 'cheer_panel.png'))
crow = Image.new('RGBA', (184, 36))
for i, fill in enumerate([rgba(DEEP, 200), rgba(STEEL, 255)]):
    im, d = big(184, 18)
    d.rounded_rectangle((0, 0, 184 * S - 1, 18 * S - 1), 4 * S, fill=fill, outline=rgba(WHITE if i else LINE, 255 if i else 90), width=S)
    crow.alpha_composite(small(im, 184, 18), (0, 18 * i))
crow.save(path('battle', 'cheer_row.png'))
pips = Image.new('RGBA', (8, 16))
for i, fill in enumerate([(255, 214, 64), (60, 72, 84)]):
    im, d = big(8, 8)
    d.polygon([(4 * S, 0), (8 * S - 1, 4 * S), (4 * S, 8 * S - 1), (0, 4 * S)], fill=rgba(WHITE))
    d.polygon([(4 * S, 1.3 * S), (6.7 * S, 4 * S), (4 * S, 6.7 * S), (1.3 * S, 4 * S)], fill=rgba(fill))
    pips.alpha_composite(small(im, 8, 8), (0, 8 * i))
pips.save(path('battle', 'cheer_pips.png'))
# icônes des encouragements (offense, défense, soin, contre, raid) 16 x 16
cic = Image.new('RGBA', (16, 80))
colors = [(236, 96, 72), (84, 150, 230), (96, 200, 120), (176, 110, 220), (255, 200, 64)]
for i, col in enumerate(colors):
    im, d = big(16, 16)
    d.ellipse((0, 0, 16 * S - 1, 16 * S - 1), fill=rgba(WHITE))
    d.ellipse((S, S, 15 * S - 1, 15 * S - 1), fill=rgba(col))
    c = 8 * S
    if i == 0:
        d.polygon([(c, 3 * S), (12 * S, 12 * S), (c, 9.5 * S), (4 * S, 12 * S)], fill=rgba(WHITE))
    elif i == 1:
        d.polygon([(4 * S, 4 * S), (12 * S, 4 * S), (12 * S, 8 * S), (c, 12.5 * S), (4 * S, 8 * S)], fill=rgba(WHITE))
    elif i == 2:
        d.rectangle((6.6 * S, 3.5 * S, 9.4 * S, 12.5 * S), fill=rgba(WHITE))
        d.rectangle((3.5 * S, 6.6 * S, 12.5 * S, 9.4 * S), fill=rgba(WHITE))
    elif i == 3:
        d.arc((3.5 * S, 3.5 * S, 12.5 * S, 12.5 * S), 200, 520, fill=rgba(WHITE), width=2 * S)
        d.polygon([(10.5 * S, 2.5 * S), (13 * S, 6 * S), (9 * S, 6.5 * S)], fill=rgba(WHITE))
    else:
        pts = []
        for k in range(10):
            r = (5.2 if k % 2 == 0 else 2.3) * S
            a = math.radians(-90 + k * 36)
            pts.append((c + r * math.cos(a), c + 0.3 * S + r * math.sin(a)))
        d.polygon(pts, fill=rgba(WHITE))
    cic.alpha_composite(small(im, 16, 16), (0, 16 * i))
cic.save(path('battle', 'cheer_icons.png'))
# éclair de l'action en plus du boss (voile coloré plein écran)
for style, accent in STYLES.items():
    Image.new('RGBA', (320, 240), rgba(accent, 110)).save(path('battle', f'flash_{style}.png'))

# --- Aventures : HUD, cases, curseur ---------------------------------------------------------------------------
hud = frame((92, 18), fill=DEEP, radius=4, alpha=220)
hud.save(path('adventure', 'hud.png'))
hearts = Image.new('RGBA', (12, 22))
for i, fill in enumerate([(236, 72, 92), (70, 80, 92)]):
    im, d = big(12, 11)
    d.ellipse((0.5 * S, 0.5 * S, 6.5 * S, 6.5 * S), fill=rgba(fill))
    d.ellipse((5.5 * S, 0.5 * S, 11.5 * S, 6.5 * S), fill=rgba(fill))
    d.polygon([(0.8 * S, 4.3 * S), (11.2 * S, 4.3 * S), (6 * S, 10.6 * S)], fill=rgba(fill))
    hearts.alpha_composite(small(im, 12, 11), (0, 11 * i))
hearts.save(path('adventure', 'hearts.png'))
im, d = big(12, 12)
d.ellipse((0.5 * S, 0.5 * S, 6.5 * S, 6.5 * S), outline=(255, 214, 64, 255), width=2 * S)
d.rectangle((5.5 * S, 3 * S, 11.5 * S, 4.6 * S), fill=(255, 214, 64, 255))
d.rectangle((9 * S, 3 * S, 10.5 * S, 7.5 * S), fill=(255, 214, 64, 255))
small(im, 12, 12).save(path('adventure', 'key.png'))
banner = frame((210, 40), fill=SLATE)
bi, bd = big(210, 40)
bd.polygon([(6 * S, 5 * S), (150 * S, 5 * S), (143 * S, 17 * S), (6 * S, 17 * S)], fill=rgba(STEEL))
banner.alpha_composite(small(bi, 210, 40))
banner.save(path('adventure', 'banner.png'))
info = frame((308, 42), fill=SLATE)
info.save(path('adventure', 'info.png'))
cur = Image.new('RGBA', (40, 40))
d = ImageDraw.Draw(cur)
for (x, y, dx, dy) in [(1, 1, 1, 1), (38, 1, -1, 1), (1, 38, 1, -1), (38, 38, -1, -1)]:
    d.line((x, y, x + 9 * dx, y), fill=rgba(WHITE), width=2)
    d.line((x, y, x, y + 9 * dy), fill=rgba(WHITE), width=2)
cur.save(path('adventure', 'cursor.png'))
arrows = Image.new('RGBA', (64, 16))
for i, ang in enumerate([0, 180, 270, 90]):  # haut, bas, gauche, droite
    im, d = big(16, 16)
    d.polygon([(8 * S, 1 * S), (15 * S, 11 * S), (1 * S, 11 * S)], fill=rgba(WHITE))
    d.polygon([(8 * S, 3.5 * S), (12.5 * S, 10 * S), (3.5 * S, 10 * S)], fill=rgba(STEEL))
    arrows.alpha_composite(small(im, 16, 16).rotate(-ang if ang != 270 else 90).rotate(0), (16 * i, 0))
arrows.save(path('adventure', 'arrows.png'))
dark = Image.new('RGBA', (640, 480), (6, 8, 12, 245))
mask = Image.new('L', (640, 480), 0)
ImageDraw.Draw(mask).ellipse((320 - 64, 240 - 64, 320 + 64, 240 + 64), fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(14))
dark.putalpha(Image.eval(mask, lambda v: 245 - v * 245 // 255))
dark.save(path('adventure', 'darkness.png'))
# cases (reprises du plugin d'origine)
tiles_dir = os.path.join(DBK, 'Adventures/Tiles')
for f in os.listdir(tiles_dir):
    if f.endswith('.png'):
        shutil.copy(os.path.join(tiles_dir, f), path('adventure', 'tiles', f))
for f in ['tile_bg.png']:
    shutil.copy(os.path.join(DBK, 'Adventures', f), path('adventure', f))
maps_dir = os.path.join(DBK, 'Adventures/Maps')
for f in os.listdir(maps_dir):
    if f.endswith('.png'):
        shutil.copy(os.path.join(maps_dir, f), path('adventure', 'maps', f))

# carte de Pokémon (choix des locations, échanges), 100 x 150 (normal / choisie)
card = Image.new('RGBA', (100, 300))
for i, (fill, edge) in enumerate([(SLATE, LINE), (STEEL, WHITE)]):
    im, d = big(100, 150)
    d.rounded_rectangle((0, 0, 100 * S - 1, 150 * S - 1), 6 * S, fill=rgba(edge))
    d.rounded_rectangle((S, S, 99 * S - 1, 149 * S - 1), 5 * S, fill=rgba(fill))
    d.rounded_rectangle((5 * S, 5 * S, 95 * S, 52 * S), 4 * S, fill=rgba(DEEP))
    card.alpha_composite(small(im, 100, 150), (0, 150 * i))
card.save(path('menus', 'card.png'))
mrow = Image.new('RGBA', (300, 40))
for i, (fill, edge) in enumerate([(SLATE, LINE), (STEEL, WHITE)]):
    im, d = big(300, 20)
    d.rounded_rectangle((0, 0, 300 * S - 1, 20 * S - 1), 4 * S, fill=rgba(edge, 120 if i == 0 else 255))
    d.rounded_rectangle((S, S, 299 * S - 1, 19 * S - 1), 3 * S, fill=rgba(fill))
    mrow.alpha_composite(small(im, 300, 20), (0, 20 * i))
mrow.save(path('menus', 'row.png'))
frame((308, 44), fill=DEEP).save(path('menus', 'desc.png'))

# --- Transitions (écran de 320 x 240) ------------------------------------------------------------------------------
for style, folder in [('basic', 'Basic'), ('ultra', 'Ultra'), ('max', 'Max'), ('tera', 'Tera')]:
    for name in ['bg', 'icon']:
        src_file = os.path.join(DBK, 'Transitions', folder, name + '.png')
        if os.path.exists(src_file):
            Image.open(src_file).convert('RGBA').resize((320, 240), Image.LANCZOS).save(path('transitions', f'{style}_{name}.png'))
for name in ['impact', 'shine']:
    Image.open(os.path.join(DBK, 'Transitions', name + '.png')).convert('RGBA').resize((320, 240), Image.LANCZOS).save(path('transitions', name + '.png'))

# --- Antres (charsets à moitié taille) ---------------------------------------------------------------------------------
chars = os.path.join(ROOT, 'graphics/characters')
for style, name in [('basic', 'Basic'), ('ultra', 'Ultra'), ('max', 'Max'), ('tera', 'Tera')]:
    im = Image.open(os.path.join(SRC, 'Graphics/Characters', f'Object den ({name}).png')).convert('RGBA')
    im.resize((im.width // 2, im.height // 2), Image.LANCZOS).save(os.path.join(chars, f'raid_den_{style}.png'))

# --- Fonds de combat (320 x 240) ------------------------------------------------------------------------------------
backs = os.path.join(ROOT, 'graphics/battlebacks')
bb = os.path.join(SRC, 'Graphics/Battlebacks')
for style in ['ultra', 'max', 'tera']:
    bg = Image.open(os.path.join(bb, f'raid_{style}_bg.png')).convert('RGBA')
    bg = bg.resize((round(bg.width * 240 / bg.height), 240), Image.LANCZOS)
    x0 = (bg.width - 320) // 2
    out = bg.crop((x0, 0, x0 + 320, 240))
    enemy = Image.open(os.path.join(bb, f'raid_{style}_base1.png')).convert('RGBA')
    enemy = enemy.resize((round(enemy.width * 0.66), round(enemy.height * 0.66)), Image.LANCZOS)
    out.alpha_composite(enemy, (242 - enemy.width // 2, 138 - enemy.height // 2 - 4))
    player = Image.open(os.path.join(bb, f'raid_{style}_base0.png')).convert('RGBA')
    player = player.resize((round(player.width * 0.625), round(player.height * 0.625)), Image.LANCZOS)
    out.alpha_composite(player, (0, 178))
    out.save(os.path.join(backs, f'back_raid_{style}.png'))

# --- Appât Raid ----------------------------------------------------------------------------------------------------
Image.open(os.path.join(SRC, 'Graphics/Items/RAIDBAIT.png')).convert('RGBA').resize((32, 32), Image.LANCZOS).save(
    os.path.join(ROOT, 'graphics/icons/raid_bait.png'))

# --- Musiques --------------------------------------------------------------------------------------------------------
bgm = os.path.join(ROOT, 'audio/bgm')
music = os.path.join(SRC, 'Audio/BGM')
if os.path.isdir(music):
    for f in os.listdir(music):
        if not f.endswith('.ogg'):
            continue
        style = f.split('(')[1].split(')')[0].lower()
        rest = f.split(')')[1].strip()[:-4].replace(' v', ' ').strip().replace(' ', '_').lower()
        shutil.copy(os.path.join(music, f), os.path.join(bgm, f'raid_{style}_{rest}.ogg'))
print('ok')

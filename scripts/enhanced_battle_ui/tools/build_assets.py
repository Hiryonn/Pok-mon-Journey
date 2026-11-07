# Construit les images du plugin « enhanced_battle_ui » (320 x 240) à partir des assets
# « Enhanced Battle UI » de Pokémon Essentials (dessinés en 512 x 384, pixels doublés).
# Les images sont réduites de moitié (pixel exact) puis étirées dans les zones unies.
#
# Usage : python build_assets.py <dossier des assets Essentials> <racine du projet>
import sys, os, json, glob
from PIL import Image, ImageDraw

SRC = sys.argv[1]
ROOT = sys.argv[2]
OUT = os.path.join(ROOT, 'graphics/interface/enhanced_battle_ui')
os.makedirs(OUT, exist_ok=True)


def load(name):
    return Image.open(os.path.join(SRC, name)).convert('RGBA')


def half(img):
    return img.resize((img.width // 2, img.height // 2), Image.NEAREST)


def widen(img, at, count):
    """Insère count copies de la colonne at (zone unie)."""
    out = Image.new('RGBA', (img.width + count, img.height))
    out.paste(img.crop((0, 0, at, img.height)), (0, 0))
    col = img.crop((at, 0, at + 1, img.height))
    for i in range(count):
        out.paste(col, (at + i, 0))
    out.paste(img.crop((at, 0, img.width, img.height)), (at + count, 0))
    return out


def heighten(img, at, count):
    return widen(img.rotate(90, expand=True), img.height - 1 - at, count).rotate(-90, expand=True)


def save(img, name):
    img.save(os.path.join(OUT, name))


# --- Panneau d'infos de l'attaque : une ligne de 82 px par type du projet --------------
ESS_ROW = {'normal': 1, 'fighting': 2, 'flying': 3, 'poison': 4, 'ground': 5, 'rock': 6, 'bug': 7, 'ghost': 8,
           'steel': 9, 'unknown': 10, 'fire': 11, 'water': 12, 'grass': 13, 'electric': 14, 'psychic': 15,
           'ice': 16, 'dragon': 17, 'dark': 18, 'fairy': 19, 'cosmic': 20, 'light': 16, 'nuke': 14,
           'beast': 5, 'shadow': 18, 'stellar': 20}
types = {}
for f in glob.glob(os.path.join(ROOT, 'Data/Studio/types/*.json')):
    d = json.load(open(f, encoding='utf-8'))
    types[d['id']] = d['dbSymbol']
count = max(types) + 1 if types else 20
move_bg = load('move_bg.png')
rows = []
for i in range(move_bg.height // 164):
    row = half(move_bg.crop((0, i * 164, 512, (i + 1) * 164)))   # 256 x 82
    # colonnes unies : 34 au milieu du nom, 10 dans chacune des 3 pastilles du bas
    for at, n in ((235, 10), (190, 10), (145, 10), (100, 34)):
        row = widen(row, at, n)
    rows.append(row)                                                 # 320 x 82
sheet = Image.new('RGBA', (320, 82 * count))
for i in range(count):
    sheet.paste(rows[ESS_ROW.get(types.get(i), 0)], (0, i * 82))
save(sheet, 'move_panel.png')

# Cases d'efficacité : ?, immunisé, peu efficace, super efficace, normal (32 x 38)
save(half(load('move_effectiveness.png')), 'move_effectiveness.png')

# Pictogrammes des particularités (13 x 14) dans l'ordre de FLAGS (Configuration)
FLAGS = ['Contact', 'Punching', 'Biting', 'Slicing', 'Sound', 'Pulse', 'Bomb', 'Powder', 'Dance', 'Wind',
         'HighCriticalHitRate', 'ThawsUser', 'NoProtect', 'NoMirrorMove', 'TramplesMinimize', 'ElectrocuteUser']
flags = Image.new('RGBA', (13 * len(FLAGS), 14))
for i, f in enumerate(FLAGS):
    flags.paste(half(load(f'Move Flags/{f}.png')), (i * 13, 0))
save(flags, 'move_flags.png')

# --- Sélection du combattant -------------------------------------------------------
sel = half(load('select_bg.png'))                       # 256 x 76
sel = widen(sel, 128, 64)
sel = heighten(sel, 38, 44)                             # 320 x 120
save(sel, 'select_bg.png')
box = load('select_cursor.png')
save(Image.merge('RGBA', box.split()).resize((83, 52), Image.NEAREST), 'select_box.png')

# --- Écran d'infos : fond + cases fixes ----------------------------------------------
bg = half(load('info_bg.png'))                         # 256 x 192 (bandes : 12-14 / 176-178)
bg = widen(bg, 128, 64)
bg = heighten(bg, 100, 48)                             # 320 x 240, bande du bas 224-226
data = half(load('info_bg_data.png'))
LIGHT = (228, 236, 236, 255)

def light_part(w, h):
    img = Image.new('RGBA', (w, h), LIGHT)
    return img

poke_box = data.crop((14, 29, 97, 55))                 # 83 x 26 (barre de PV : 28..75, 14..16)
lv_box = widen(data.crop((14, 59, 97, 77)), 40, 47)     # 130 x 18
used_box = widen(data.crop((134, 59, 243, 77)), 50, 41) # 150 x 18
row = data.crop((14, 79, 125, 90))                     # 111 x 11 : étiquette 0..49, points 50..110
d = ImageDraw.Draw(row)
d.rectangle((52, 1, 109, 9), fill=LIGHT)               # points effacés (dessinés par le jeu)
stat_row = widen(widen(row, 80, 11), 25, 8)            # 130 x 11 : étiquette 0..57, points 58..129
desc = half(load('info_effects.png'))                  # 109 x 34
desc = heighten(widen(desc, 54, 41), 17, 10)            # 150 x 44
slider_base = half(load('info_slider_base.png'))       # 9 x 60

LAYOUT = {
    'poke_box': (12, 30), 'lv_box': (12, 60), 'used_box': (162, 60), 'stat_rows': (12, 82, 14),
    'desc_box': (162, 148), 'slider': (305, 82),
}
page = bg.copy()
page.alpha_composite(poke_box, LAYOUT['poke_box'])
page.alpha_composite(lv_box, LAYOUT['lv_box'])
page.alpha_composite(used_box, LAYOUT['used_box'])
sx, sy, pitch = LAYOUT['stat_rows']
for i in range(8):
    page.alpha_composite(stat_row, (sx, sy + i * pitch))
page.alpha_composite(desc, LAYOUT['desc_box'])
# bandes transparentes du haut et du bas assombries (le combat reste deviné derrière)
dim = Image.new('RGBA', page.size, (0, 0, 0, 150))
dim.alpha_composite(page)
save(dim, 'info_bg.png')
save(slider_base, 'info_slider_base.png')

# Lignes d'effets (140 x 13) : normal / choisi
cur = half(load('info_cursor.png'))                    # 109 x 39 : 3 lignes de 13
effect_rows = Image.new('RGBA', (138, 26))
effect_rows.paste(widen(cur.crop((0, 13, 109, 26)), 40, 29), (0, 0))
effect_rows.paste(widen(cur.crop((0, 26, 109, 39)), 40, 29), (0, 13))
save(effect_rows, 'info_effect_rows.png')
# Ligne Talent / Objet (étiquette sombre | valeur claire) 150 x 13
save(widen(widen(cur.crop((0, 0, 109, 13)), 80, 31), 10, 10), 'info_extra_row.png')  # étiquette 0..39

# Petits éléments
save(half(load('info_owner.png')), 'info_owner.png')       # 64 x 20 : sombre / clair
party = load('info_party.png')                              # 4 boules de 15 px
pb = Image.new('RGBA', (32, 8))
for i in range(4):
    pb.paste(party.crop((i * 15, 0, i * 15 + 15, 15)).resize((8, 8), Image.NEAREST), (i * 8, 0))
save(pb, 'info_party.png')
save(half(load('info_gender.png')), 'info_gender.png')     # 22 x 11
save(half(load('info_hp.png')), 'info_hp.png')             # 48 x 9 : vert / jaune / rouge
save(half(load('info_stats.png')), 'info_stats.png')       # 18 x 9 : hausse / baisse
sl = half(load('info_slider.png'))                         # 18 x 19
save(sl, 'info_slider.png')
# point vide des stats (4 x 4) pris dans les cases
save(data.crop((14 + 57, 79 + 4, 14 + 61, 79 + 8)), 'info_dot.png')

# Flèches gauche / droite (orange) pour changer de Pokémon : 6 x 11 chacune
arr = Image.new('RGBA', (12, 11), (0, 0, 0, 0))
d = ImageDraw.Draw(arr)
d.polygon([(5, 0), (5, 10), (0, 5)], fill=(232, 96, 32, 255), outline=(120, 40, 16, 255))
d.polygon([(6, 0), (6, 10), (11, 5)], fill=(232, 96, 32, 255), outline=(120, 40, 16, 255))
save(arr, 'info_arrows.png')


# --- Lancer rapide de Poké Ball (combat sauvage) ------------------------------------------
def extend_sides(img, count):
    """Prolonge les bords gauche et droit (onglets sombres) de count pixels chacun."""
    out = Image.new('RGBA', (img.width + count * 2, img.height))
    out.paste(img, (count, 0))
    left = img.crop((0, 0, 1, img.height))
    right = img.crop((img.width - 1, 0, img.width, img.height))
    for i in range(count):
        out.paste(left, (i, 0))
        out.paste(right, (img.width + count + i, 0))
    return out

save(extend_sides(half(load('pokeball_bg.png')), 32), 'ball_bg.png')       # 320 x 66
save(widen(half(load('pokeball_desc.png')), 128, 64), 'ball_desc.png')      # 320 x 53


print('ok', OUT, sorted(os.listdir(OUT)))

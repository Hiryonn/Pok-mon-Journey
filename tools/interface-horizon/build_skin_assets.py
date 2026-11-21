# Interface Horizon : habillage des autres interfaces de PSDK (PC, Journal de quêtes, Carte Dresseur, Sauvegarde, Options)
#   python build_skin_assets.py <racine du projet>
# Lit les images d'origine dans graphics/interface/<dossier>/ et écrit leurs versions aux couleurs du Pokédex Horizon
# dans graphics/interface/horizon/<dossier>/ (les originaux ne sont pas modifiés ; le jeu prend la version « horizon »
# quand elle existe, voir scripts/interface_horizon/scripts/00150 Habillage).
import colorsys
import os
import sys
from PIL import Image, ImageDraw

ROOT = sys.argv[1]
SRC = os.path.join(ROOT, 'graphics/interface')
OUT = os.path.join(SRC, 'horizon')

LIGHT, SHEEN = (229, 243, 250), (250, 253, 254)
BLUE, STEEL, SLATE, DEEP = (80, 126, 166), (69, 103, 129), (51, 71, 81), (36, 52, 62)
SKY, PALE = (145, 201, 247), (213, 238, 248)
# gris -> rampe bleutée du Pokédex (luminosité d'origine -> couleur)
RAMP = [(0, (16, 24, 30)), (36, DEEP), (56, SLATE), (75, STEEL), (105, BLUE), (150, (120, 170, 210)), (200, PALE),
        (235, LIGHT), (248, SHEEN), (256, (255, 255, 255))]


def ramp(l):
    for (a, ca), (b, cb) in zip(RAMP, RAMP[1:]):
        if a <= l < b:
            t = (l - a) / (b - a)
            return tuple(round(ca[i] + (cb[i] - ca[i]) * t) for i in range(3))
    return RAMP[-1][1]


def recolor_pixel(r, g, b, keep_hues):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if s < 0.22 or v < 0.12:                      # gris, noirs, blancs
        return ramp(0.299 * r + 0.587 * g + 0.114 * b)
    deg = h * 360
    if any(lo <= deg <= hi for lo, hi in keep_hues):
        return (r, g, b)
    # autres teintes (violet, rose, vert des options…) -> bleu Horizon, même saturation et luminosité
    nr, ng, nb = colorsys.hsv_to_rgb(207 / 360, min(1.0, s * 0.85), v)
    return (round(nr * 255), round(ng * 255), round(nb * 255))


def recolor(rel, keep_hues=()):
    src = os.path.join(SRC, rel + '.png')
    if not os.path.exists(src):
        print('absent :', rel)
        return
    im = Image.open(src).convert('RGBA')
    px = im.load()
    cache = {}
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if a < 255 and 0.299 * r + 0.587 * g + 0.114 * b < 90:
                # zones sombres transparentes (cases de la Carte Dresseur…) : bleu acier plus couvrant,
                # pour garder le texte blanc lisible sur le fond clair
                px[x, y] = STEEL + (min(255, round(a * 1.7)),)
                continue
            key = (r, g, b)
            if key not in cache:
                cache[key] = recolor_pixel(r, g, b, keep_hues)
            px[x, y] = cache[key] + (a,)
    save(im, rel)


def save(im, rel):
    path = os.path.join(OUT, rel + '.png')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)


# --- Éléments repris du Pokédex Horizon (graphics/pokedex/pe) ------------------------------------
DEX = os.path.join(ROOT, 'graphics/pokedex/pe')
bg_list = Image.open(os.path.join(DEX, 'bg_list.png')).convert('RGBA')
bg_map = Image.open(os.path.join(DEX, 'bg_map.png')).convert('RGBA')
# fond commun des menus (team/fond) : le fond clair à reflet du Pokédex (fixe : le défilement est coupé en jeu)
save(bg_map.copy(), 'team/fond')
# barre du bas (à la place de la barre des boutons de PSDK) : bandes bleues du bas du Pokédex
save(bg_map.crop((0, 214, 320, 240)), 'tcard/button_background')
# bandeau du haut : celui du Pokédex (28 px), pastille ardoise vide au milieu (le titre est écrit par le jeu)
header = bg_list.crop((0, 2, 320, 30))
hp = header.load()
for y in range(header.height):
    for x in range(96, 224):
        if hp[x, y][:3] in ((255, 255, 255), (50, 55, 57), (167, 197, 220)):
            hp[x, y] = (51, 71, 81, 255)
save(header, 'header')
HEADER_H = header.height


# bandeau mince (20 px) pour le PC : le haut de la boîte commence juste en dessous
slim = header.crop((0, 4, 320, 24))
save(slim, 'header_slim')


def with_header(rel, band=None):
    """Cadre d'origine (recoloré) dont le bandeau du haut est remplacé par celui du Pokédex"""
    band = band or header
    recolor(rel)
    path = os.path.join(OUT, rel + '.png')
    im = Image.open(path).convert('RGBA')
    im.paste((0, 0, 0, 0), (0, 0, im.width, HEADER_H))
    im.alpha_composite(band, (0, 0))
    im.save(path)


RED, YELLOW, GREEN, ORANGE = (345, 360), (40, 70), (90, 160), (15, 40)
KEEP_STATUS = (RED, (0, 15), ORANGE, YELLOW, GREEN)

# barre des boutons et zone de texte communes
recolor('team/win_txt')
# Carte Dresseur
recolor('tcard/background')
# PC
with_header('pc/frame', slim)
for name in ('frame_split', 'button_list', 'button_list_ext', 'button_scroll', 'scroll', 'folders', 'name_frame',
             'resume', 'select', 'slots', 'win_txt', 'key_leftright', 'key_mode', 'arrow_frame_l', 'arrow_frame_r'):
    recolor('pc/' + name)
recolor('pc/win_modes', KEEP_STATUS)
# Journal de quêtes
with_header('quest/frame')
for name in ('quest_bg', 'prize_back', 'prize_button', 'quest_selector', 'quest_selector_list', 'selec_button',
             'win_border', 'win_cat', 'scroll', 'button_scroll', 'arrow_frame_l', 'arrow_frame_r'):
    recolor('quest/' + name)
for name in ('win_active', 'win_failed', 'win_finished'):
    recolor('quest/' + name, KEEP_STATUS)
# Sauvegarde / chargement
for name in ('box_main', 'box_new', 'shadow_save'):
    recolor('load/' + name)
with_header('load/frame_load')
with_header('load/frame_save')
# Options
for name in ('description', 'option'):
    recolor('options/' + name)
with_header('options/frame')
print('ok', OUT)

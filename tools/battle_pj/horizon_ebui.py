# Enhanced Battle UI aux couleurs de l'interface Horizon (fonds ardoise sombres comme les boîtes du combat, bandeaux bleu
# acier, cases blanches, panneau des attaques coloré comme les boutons d'attaque Horizon).
# Les images d'origine sont gardées dans tools/battle_pj/ebui_source ; le script les recolore dans
# graphics/interface/enhanced_battle_ui (on peut le relancer sans perte).
#   python3 tools/battle_pj/horizon_ebui.py [racine du projet]
import os
import sys
from PIL import Image

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'
SRC = os.path.join(ROOT, 'tools/battle_pj/ebui_source')
OUT = os.path.join(ROOT, 'graphics/interface/enhanced_battle_ui')
MOVE_BUTTONS = os.path.join(ROOT, 'graphics/interface/battle_pj/move_buttons.png')

STEEL = (80, 126, 166)
DEEP = (34, 46, 56)
WHITE = (240, 246, 250)

# Couleur d'origine (RVB) -> couleur Horizon (l'opacité d'origine est gardée)
COLORS = {
    (104, 136, 144): DEEP,            # fond de l'écran d'infos
    (111, 145, 153): DEEP,            # fonds des bandeaux (sélection, Poké Ball)
    (77, 91, 91): STEEL,              # barres de titre
    (81, 101, 119): (62, 90, 110),    # cases des étiquettes (ardoise éclaircie sur le fond sombre)
    (228, 236, 236): WHITE,           # cases des valeurs
    (210, 221, 221): (224, 235, 244),
    (187, 203, 206): (206, 222, 236),
    (172, 192, 196): (150, 182, 208),  # bords des cases
    (203, 209, 221): (196, 216, 234),  # liserés, pastilles
    # Cadre de sélection : vert -> bleu Horizon
    (57, 189, 132): (110, 170, 222),
    (49, 165, 90): (84, 140, 196),
    (51, 149, 76): (70, 124, 180),
    (49, 148, 74): (66, 120, 176),
}
# Bandeaux noirs transparents (haut et bas de l'écran d'infos) -> bleu acier
BLACK_BAND = ((0, 0, 0), 150)


def recolor(img):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if (r, g, b) == BLACK_BAND[0] and a == BLACK_BAND[1]:
                px[x, y] = STEEL + (255,)
            elif (r, g, b) in COLORS:
                px[x, y] = COLORS[(r, g, b)] + (a,)
    return img


def move_panel():
    # Une ligne de 82 pixels par type, comme les boutons d'attaque Horizon (22 pixels par type)
    src = Image.open(os.path.join(SRC, 'move_panel.png')).convert('RGBA')
    buttons = Image.open(MOVE_BUTTONS).convert('RGBA')
    out = src.copy()
    rows = src.height // 82
    for r in range(rows):
        row = src.crop((0, r * 82, 320, r * 82 + 82))
        counts = {}
        for p in getattr(row, 'get_flattened_data', row.getdata)():
            counts[p] = counts.get(p, 0) + 1
        ranked = [p for p, _ in sorted(counts.items(), key=lambda kv: -kv[1])]
        pill, band, border, line = ranked[:4]
        br = min(r, buttons.height // 22 - 1)
        bcounts = {}
        cell = buttons.crop((0, br * 22, 94, br * 22 + 22))
        for p in getattr(cell, 'get_flattened_data', cell.getdata)():
            bcounts[p] = bcounts.get(p, 0) + 1
        bmain, bdark, blight = [p[:3] for p, _ in sorted(bcounts.items(), key=lambda kv: -kv[1])[:3]]
        mapping = {pill[:3]: WHITE, band[:3]: bmain, border[:3]: blight, line[:3]: bdark}
        px = out.load()
        for y in range(82):
            for x in range(320):
                p = px[x, r * 82 + y]
                if p[3] and p[:3] in mapping:
                    px[x, r * 82 + y] = mapping[p[:3]] + (p[3],)
                elif p[3]:
                    # Couleurs intermédiaires : la plus proche des quatre
                    near = min(mapping, key=lambda c: sum((c[i] - p[i]) ** 2 for i in range(3)))
                    px[x, r * 82 + y] = mapping[near] + (p[3],)
    out.save(os.path.join(OUT, 'move_panel.png'))


for name in sorted(os.listdir(SRC)):
    if not name.endswith('.png') or name == 'move_panel.png':
        continue
    img = Image.open(os.path.join(SRC, name)).convert('RGBA')
    recolor(img).save(os.path.join(OUT, name))
move_panel()
print('ok')

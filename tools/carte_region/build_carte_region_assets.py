# Fabrique les images du plugin « carte_region » (graphics/interface/carte_region/)
#   themes/<thème>/ : box (cadre 9 morceaux de 8 px), bar_top, bar_bottom, select (ligne choisie), cursor (2 images),
#                     arrow_up / arrow_down
#   icons/          : vol, quêtes (couleurs), baies, errants, dresseurs, météo, attrapé / vu, barre de progression
# Les icônes viennent d'« Arcky's Region Map » (Essentials, crédits : Arcky), réduites de moitié (32 -> 16 px).
#   python tools/carte_region/build_carte_region_assets.py
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'graphics', 'interface', 'carte_region')
SRC = os.path.join(HERE, 'sources')

# thème : (fond, fond clair, bord / accent, ombre)
THEMES = {
    'rouge': ((55, 58, 69), (72, 76, 90), (242, 64, 76), (30, 32, 38)),
    'bleu': ((43, 63, 174), (74, 99, 240), (24, 24, 40), (20, 28, 90)),
    'vert': ((38, 92, 70), (56, 128, 96), (120, 214, 150), (20, 50, 38)),
    'sombre': ((28, 30, 38), (44, 47, 58), (150, 156, 178), (12, 12, 16)),
    'violet': ((70, 44, 110), (98, 66, 150), (232, 170, 255), (40, 24, 66)),
}


def save(img, *path):
    p = os.path.join(OUT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)


def box(base, light, accent, shadow, alpha=235):
    im = Image.new('RGBA', (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 23, 23), 5, fill=accent + (255,))
    d.rounded_rectangle((2, 2, 21, 21), 4, fill=base + (alpha,))
    d.line((4, 3, 19, 3), fill=light + (alpha,))
    return im


def bar(base, light, accent, shadow, top):
    im = Image.new('RGBA', (24, 24), base + (245,))
    d = ImageDraw.Draw(im)
    if top:
        d.rectangle((0, 21, 23, 23), fill=accent + (255,))
        d.line((0, 20, 23, 20), fill=shadow + (255,))
        d.line((0, 0, 23, 0), fill=light + (255,))
    else:
        d.rectangle((0, 0, 23, 2), fill=accent + (255,))
        d.line((0, 3, 23, 3), fill=shadow + (255,))
    return im


def select(base, light, accent, shadow):
    im = Image.new('RGBA', (24, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 23, 15), 3, fill=accent + (110,))
    d.rounded_rectangle((0, 0, 23, 15), 3, outline=accent + (255,))
    return im


def cursor(accent):
    """Anneau autour de la case visée (2 images de 22 x 22, la 2e un peu plus petite)."""
    im = Image.new('RGBA', (44, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for f, inset in ((0, 0), (1, 2)):
        x = f * 22
        box = (x + inset, inset, x + 21 - inset, 21 - inset)
        d.rounded_rectangle(box, 4, outline=(255, 255, 255, 255), width=1)
        d.rounded_rectangle((box[0] + 1, box[1] + 1, box[2] - 1, box[3] - 1), 3, outline=accent + (255,), width=2)
        d.rounded_rectangle((box[0] + 3, box[1] + 3, box[2] - 3, box[3] - 3), 2, outline=(255, 255, 255, 160), width=1)
    return im


def arrow(color, up):
    im = Image.new('RGBA', (9, 5), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(0, 4), (8, 4), (4, 0)] if up else [(0, 0), (8, 0), (4, 4)]
    d.polygon(pts, fill=color + (255,))
    return im


def halve(name):
    """Réduit une icône 32 x 32 (pixels doublés) à 16 x 16 en gardant les pixels nets."""
    src = Image.open(os.path.join(SRC, name)).convert('RGBA')
    w, h = src.size
    best = None
    for ox in (0, 1):
        for oy in (0, 1):
            small = Image.new('RGBA', (w // 2, h // 2))
            for y in range(h // 2):
                for x in range(w // 2):
                    small.putpixel((x, y), src.getpixel((min(x * 2 + ox, w - 1), min(y * 2 + oy, h - 1))))
            back = small.resize((w // 2 * 2, h // 2 * 2), Image.NEAREST)
            diff = sum(sum(abs(a - b) for a, b in zip(p, q)) for p, q in zip(back.getdata(), src.getdata()))
            if best is None or diff < best[0]:
                best = (diff, small)
    return best[1]


# Thème « horizon » : mêmes couleurs et mêmes formes que l'interface Horizon du projet (sac, quêtes, PC)
H_BLUE = (80, 126, 166)
H_MID = (69, 103, 129)
H_SLATE = (54, 77, 89)
H_DARK = (31, 45, 54)
H_LIGHT = (145, 201, 247)
WHITE = (254, 255, 255)


def horizon_theme():
    out = os.path.join('themes', 'horizon')
    hz = os.path.join(ROOT, 'graphics', 'interface', 'horizon')
    # barre du haut : celle des écrans Horizon (bandes bleues, onglet sombre au milieu)
    top = Image.open(os.path.join(hz, 'header_slim.png')).convert('RGBA')
    save(top, out, 'bar_top.png')
    # barre du bas : bas du cadre des quêtes (ligne blanche, fond ardoise)
    frame = Image.open(os.path.join(hz, 'quest', 'frame.png')).convert('RGBA')
    bottom = frame.crop((0, 240 - 26, 320, 240))
    save(bottom, out, 'bar_bottom.png')
    # fond derrière la carte : celui de l'équipe Horizon
    save(Image.open(os.path.join(hz, 'team', 'fond.png')).convert('RGBA'), out, 'background.png')
    # fenêtre : bord ardoise foncé, liseré blanc, fond ardoise (comme les boutons Horizon)
    im = Image.new('RGBA', (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 23, 23), 4, fill=H_DARK + (255,))
    d.rounded_rectangle((1, 1, 22, 22), 3, fill=WHITE + (255,))
    d.rounded_rectangle((2, 2, 21, 21), 3, fill=H_SLATE + (240,))
    save(im, out, 'box.png')
    # bandeau de titre des fenêtres (bleu Horizon, ligne sombre dessous)
    im = Image.new('RGBA', (24, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 23, 17), 2, fill=H_BLUE + (255,))
    d.line((0, 17, 23, 17), fill=H_DARK + (255,))
    d.line((2, 1, 21, 1), fill=(110, 158, 196, 255))
    save(im, out, 'title.png')
    # ligne choisie : bleu clair des listes Horizon, liseré blanc
    im = Image.new('RGBA', (24, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 23, 15), 3, fill=WHITE + (255,))
    d.rounded_rectangle((1, 1, 22, 14), 2, fill=H_BLUE + (255,))
    d.line((3, 2, 20, 2), fill=H_LIGHT + (255,))
    save(im, out, 'select.png')
    # curseur : anneau blanc et bleu, coins arrondis
    im = Image.new('RGBA', (44, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for f, inset in ((0, 0), (1, 2)):
        x = f * 22
        box_ = (x + inset, inset, x + 21 - inset, 21 - inset)
        d.rounded_rectangle(box_, 5, outline=H_DARK + (255,), width=1)
        d.rounded_rectangle((box_[0] + 1, box_[1] + 1, box_[2] - 1, box_[3] - 1), 4, outline=WHITE + (255,), width=2)
        d.rounded_rectangle((box_[0] + 3, box_[1] + 3, box_[2] - 3, box_[3] - 3), 3, outline=H_BLUE + (255,), width=1)
    save(im, out, 'cursor.png')
    save(arrow(WHITE, True), out, 'arrow_up.png')
    save(arrow(WHITE, False), out, 'arrow_down.png')


def main():
    horizon_theme()
    for name, (base, light, accent, shadow) in THEMES.items():
        save(box(base, light, accent, shadow), 'themes', name, 'box.png')
        save(bar(base, light, accent, shadow, True), 'themes', name, 'bar_top.png')
        save(bar(base, light, accent, shadow, False), 'themes', name, 'bar_bottom.png')
        save(select(base, light, accent, shadow), 'themes', name, 'select.png')
        save(cursor(accent if name != 'bleu' else (240, 64, 64)), 'themes', name, 'cursor.png')
        save(arrow((255, 255, 255), True), 'themes', name, 'arrow_up.png')
        save(arrow((255, 255, 255), False), 'themes', name, 'arrow_down.png')

    icons = {
        'fly': 'mapFly.png', 'fly_off': 'mapFlyDis.png', 'fly_here': 'mapFlySel.png', 'unknown': 'map000.png',
        'quest': 'mapQuest.png', 'quest_red': 'mapQuestRed.png', 'quest_blue': 'mapQuestBlue.png',
        'quest_cyan': 'mapQuestCyan.png', 'quest_green': 'mapQuestGreen.png', 'quest_magenta': 'mapQuestMagenta.png',
        'quest_orange': 'mapQuestOrange.png', 'quest_purple': 'mapQuestPurple.png', 'quest_yellow': 'mapQuestYellow.png',
        'berry': 'mapBerry.png', 'berry_ready': 'mapBerryReady.png', 'berry_dry': 'mapBerryDry.png',
        'berry_pest': 'mapBerryPest.png', 'berry_weeds': 'mapBerryWeeds.png', 'trainer': 'mapTrainerHIKER.png',
        'weather_rain': 'mapRain.png', 'weather_hardrain': 'mapStorm.png', 'weather_sunny': 'mapSun.png',
        'weather_hardsun': 'mapSun.png', 'weather_sandstorm': 'mapSand.png', 'weather_hail': 'mapBlizzard.png',
        'weather_snow': 'mapSnow.png', 'weather_fog': 'mapFog.png', 'weather_strong_winds': 'mapFog.png',
    }
    for out, src in icons.items():
        save(halve(src), 'icons', out + '.png')

    # Errant : cercle « ? » (si le Pokémon n'a pas d'icône de carte)
    # Attrapé / vu : petite Poké Ball / œil pour la fiche détaillée
    ball = Image.new('RGBA', (8, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(ball)
    d.ellipse((0, 0, 7, 7), fill=(240, 64, 64, 255), outline=(30, 30, 30, 255))
    d.rectangle((1, 4, 6, 6), fill=(250, 250, 250, 255))
    d.line((0, 4, 7, 4), fill=(30, 30, 30, 255))
    d.rectangle((3, 3, 4, 4), fill=(250, 250, 250, 255))
    save(ball, 'icons', 'caught.png')
    # Barre de progression : ligne 0 = fond, ligne 1 = remplie
    prog = Image.new('RGBA', (100, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(prog)
    d.rectangle((0, 0, 99, 5), fill=(20, 20, 26, 220))
    d.rectangle((0, 6, 99, 11), fill=(88, 208, 120, 255))
    d.line((0, 6, 99, 6), fill=(150, 240, 170, 255))
    save(prog, 'icons', 'progress.png')
    print('Images écrites dans', OUT)


if __name__ == '__main__':
    main()

# Étui à badges : graphismes du jeu (graphics/interface/etui_badges/), aux couleurs de l'interface Horizon
#   python tools/etui_badges/build_etui_badges_assets.py [dossier « badgecase » d'Essentials]
# - badges/<id>.png (40 x 40) et badges/<id>_off.png (badge pas encore obtenu) : badges de « Badge Case » (Roei),
#   réduits de moitié (les images d'Essentials ont des pixels doublés)
# - leaders/<nom>.png : champions d'arène (réduits de moitié)
# - tray.png (étui), slot.png (emplacement), cursor.png (2 images), info.png (bandeau du bas),
#   shine.png (éclat quand on obtient un badge), pokesmart/icon_badges.png (appli du téléphone, 64 x 32)
# - fiche du badge : card_name.png (onglet du nom), card_badge.png (disque sous le badge), card_ace.png (Pokémon fétiche),
#   card_panel.png (cadre de droite), card_table.png (tableau à 4 lignes), card_stage.png (sol quadrillé du champion)
import os
import sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'graphics', 'interface', 'etui_badges')
SRC = sys.argv[1] if len(sys.argv) > 1 else None

LIGHT, SHEEN, PALE, SKY = (229, 243, 250), (250, 253, 254), (213, 238, 248), (145, 201, 247)
BLUE, STEEL, SLATE, DEEP = (80, 126, 166), (69, 103, 129), (51, 71, 81), (36, 52, 62)
VELVET, VELVET_D, VELVET_L = (58, 84, 112), (40, 60, 82), (74, 104, 136)
GOLD, GOLD_D = (240, 192, 64), (168, 112, 24)


def save(im, *path):
    p = os.path.join(OUT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)


def panel(w, h, fill, border, radius=3):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=border)
    d.rounded_rectangle((1, 1, w - 2, h - 2), max(radius - 1, 0), fill=fill)
    return im


def halve(path):
    im = Image.open(path).convert('RGBA')
    return im.resize((im.width // 2, im.height // 2), Image.NEAREST)


def import_sources():
    """Badges et champions de « Badge Case » (Essentials), réduits de moitié."""
    badges = os.path.join(SRC, 'Graphics', 'UI', 'Badgecase', 'Badges')
    for f in os.listdir(badges):
        if f.lower().endswith('.png'):
            bid = f[:-4].lower().replace('badge', '')
            save(halve(os.path.join(badges, f)), 'badges', bid + '.png')
            off = os.path.join(badges, 'unobtained', f)
            if os.path.exists(off):
                save(halve(off), 'badges', bid + '_off.png')
    leaders = os.path.join(SRC, 'Graphics', 'Trainers')
    for f in os.listdir(leaders):
        if f.lower().endswith('.png'):
            save(halve(os.path.join(leaders, f)), 'leaders', f[:-4].replace('LEADER_', '').lower() + '.png')


def tray():
    """Étui ouvert : bord acier, velours bleu nuit, reflet en haut."""
    w, h = 300, 146
    im = panel(w, h, STEEL, DEEP, 6)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((3, 3, w - 4, h - 4), 5, fill=SLATE)
    d.rounded_rectangle((6, 6, w - 7, h - 7), 4, fill=VELVET)
    # grain du velours (un pixel plus sombre sur quatre, en diagonale)
    for y in range(8, h - 8):
        for x in range(8 + (y % 4), w - 8, 4):
            im.putpixel((x, y), (54, 78, 105, 255))
    d.line((8, 7, w - 9, 7), fill=VELVET_L)
    d.line((4, 2, w - 5, 2), fill=BLUE)
    return im


def slot():
    im = Image.new('RGBA', (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((1, 1, 46, 46), fill=VELVET_D)
    d.ellipse((3, 3, 44, 44), fill=(46, 67, 90))
    d.arc((3, 3, 44, 44), 200, 340, fill=(30, 44, 60), width=2)
    d.arc((1, 1, 46, 46), 20, 160, fill=VELVET_L, width=1)
    return im


def cursor():
    im = Image.new('RGBA', (104, 52), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for f, inset in ((0, 0), (1, 2)):
        x = f * 52
        box = (x + inset, inset, x + 51 - inset, 51 - inset)
        d.rounded_rectangle(box, 8, outline=DEEP, width=1)
        d.rounded_rectangle((box[0] + 1, box[1] + 1, box[2] - 1, box[3] - 1), 7, outline=SHEEN, width=2)
        d.rounded_rectangle((box[0] + 3, box[1] + 3, box[2] - 3, box[3] - 3), 6, outline=SKY, width=1)
    return im


def shine():
    """Éclat (4 branches) pour l'obtention d'un badge."""
    im = Image.new('RGBA', (15, 15), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.line((7, 0, 7, 14), fill=(255, 255, 255, 230))
    d.line((0, 7, 14, 7), fill=(255, 255, 255, 230))
    d.line((4, 4, 10, 10), fill=(255, 255, 255, 140))
    d.line((4, 10, 10, 4), fill=(255, 255, 255, 140))
    d.rectangle((6, 6, 8, 8), fill=(255, 255, 255, 255))
    return im


def app_icon():
    """Icône de l'appli « Badges » du téléphone (comme les autres : 32 x 32, contour sombre)."""
    def one(selected):
        im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        outline = (40, 40, 48)
        # étui ouvert : couvercle en haut, plateau en bas
        d.rounded_rectangle((3, 4, 28, 13), 3, fill=outline)
        d.rounded_rectangle((4, 5, 27, 12), 2, fill=STEEL)
        d.line((6, 6, 25, 6), fill=BLUE)
        d.rounded_rectangle((2, 13, 29, 28), 3, fill=outline)
        d.rounded_rectangle((3, 14, 28, 27), 2, fill=VELVET)
        d.line((4, 15, 27, 15), fill=VELVET_L)
        # trois badges
        cols = [((200, 200, 208), (120, 120, 132)), ((80, 168, 240), (32, 96, 168)), (GOLD, GOLD_D)]
        for i, (c, s) in enumerate(cols):
            cx = 9 + i * 7
            d.polygon([(cx, 17), (cx + 3, 20), (cx, 24), (cx - 3, 20)], fill=s)
            d.polygon([(cx, 18), (cx + 2, 20), (cx, 22), (cx - 2, 20)], fill=c)
        if selected:
            d.point([(25, 7), (26, 8), (24, 8), (25, 9), (25, 8)], fill=(255, 255, 255))
        return im
    out = Image.new('RGBA', (64, 32), (0, 0, 0, 0))
    out.alpha_composite(one(False), (0, 0))
    out.alpha_composite(one(True), (32, 0))
    out.save(os.path.join(ROOT, 'graphics', 'interface', 'pokesmart', 'icon_badges.png'))


def tab(w, h, fill, border, radius=6):
    """Onglet collé au bord gauche de l'écran (coins arrondis à droite seulement)."""
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((-radius - 2, 0, w - 1, h - 1), radius, fill=border)
    d.rounded_rectangle((-radius - 2, 2, w - 3, h - 3), radius - 1, fill=fill)
    d.line((0, 3, w - 9, 3), fill=SHEEN if fill != SHEEN else (255, 255, 255))
    return im


def card_name():
    im = tab(124, 22, SHEEN, STEEL)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 2, 3, 19), fill=SKY)
    return im


def card_badge():
    """Disque clair sous le badge, avec un anneau et une ombre."""
    im = Image.new('RGBA', (100, 100), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((4, 6, 97, 99), fill=(36, 52, 62, 40))
    d.ellipse((2, 2, 95, 95), fill=STEEL)
    d.ellipse((4, 4, 93, 93), fill=SKY)
    d.ellipse((8, 8, 89, 89), fill=PALE)
    d.ellipse((14, 14, 83, 83), fill=SHEEN)
    d.arc((10, 10, 87, 87), 200, 290, fill=(255, 255, 255), width=2)
    return im


def card_ace():
    im = tab(124, 44, SHEEN, STEEL)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 2, 3, 41), fill=SKY)
    d.rounded_rectangle((6, 4, 41, 39), 4, fill=STEEL)
    d.rounded_rectangle((7, 5, 40, 38), 3, fill=PALE)
    d.line((46, 26, 116, 26), fill=SKY)
    return im


def card_panel():
    im = panel(186, 178, PALE, STEEL, 8)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((2, 2, 183, 175), 7, outline=SHEEN)
    return im


def card_table():
    w, rows, row_h, label_w = 172, 4, 19, 74
    h = 1 + rows * row_h + (rows - 1) + 1
    im = Image.new('RGBA', (w, h), STEEL)
    d = ImageDraw.Draw(im)
    for i in range(rows):
        y = 1 + i * (row_h + 1)
        d.rectangle((1, y, label_w, y + row_h - 1), fill=BLUE)
        d.line((1, y, label_w, y), fill=(104, 150, 190))
        d.rectangle((label_w + 2, y, w - 2, y + row_h - 1), fill=SHEEN)
        d.line((label_w + 2, y + row_h - 1, w - 2, y + row_h - 1), fill=LIGHT)
    return im


def card_stage():
    """Sol quadrillé où se tient le champion."""
    w, h = 172, 82
    im = Image.new('RGBA', (w, h), STEEL)
    d = ImageDraw.Draw(im)
    d.rectangle((1, 1, w - 2, h - 2), fill=LIGHT)
    for x in range(1, w - 1, 8):
        d.line((x, 1, x, h - 2), fill=PALE)
    for y in range(1, h - 1, 8):
        d.line((1, y, w - 2, y), fill=PALE)
    for y in range(h - 22, h - 1):
        t = (y - (h - 22)) / 21
        col = tuple(int(LIGHT[i] * (1 - t) + SKY[i] * t) for i in range(3))
        for x in range(1, w - 1):
            if (x - 1) % 8 and (y - 1) % 8:
                im.putpixel((x, y), col + (255,))
    d.ellipse((w // 2 - 34, h - 14, w // 2 + 34, h - 4), fill=(69, 103, 129, 90))
    return im


def main():
    if SRC:
        import_sources()
    save(tray(), 'tray.png')
    save(slot(), 'slot.png')
    save(cursor(), 'cursor.png')
    save(panel(308, 30, SHEEN, STEEL), 'info.png')
    save(shine(), 'shine.png')
    save(card_name(), 'card_name.png')
    save(card_badge(), 'card_badge.png')
    save(card_ace(), 'card_ace.png')
    save(card_panel(), 'card_panel.png')
    save(card_table(), 'card_table.png')
    save(card_stage(), 'card_stage.png')
    app_icon()
    print('Images écrites dans', OUT)


if __name__ == '__main__':
    main()

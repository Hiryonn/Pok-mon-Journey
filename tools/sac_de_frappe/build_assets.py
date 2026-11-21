# Sac de frappe : graphismes (graphics/interface/sac_de_frappe/)
#   python tools/sac_de_frappe/build_assets.py chemin/vers/Files
# Files : dossier des images du « Punch Bag Game » de FL pour Essentials (bg, punch_bag, star, arrow, bar), dessinées en
# double taille (écran 512 x 384) : elles sont réduites de moitié (pixels exacts), le fond est mis à la largeur de
# l'écran (320 x 180). Le bandeau du bas (hud.png) est dessiné aux couleurs de l'interface Horizon.
# - bg.png (320 x 180)      fond de la salle
# - bag.png (52 x 128)      sac (accroché par le haut de la corde)
# - star.png / star_empty.png (24 x 20)  étoile gagnée / case vide
# - arrow.png (16 x 16)     curseur de la jauge
# - bar.png (131 x 10)      jauge (le centre vaut 5 étoiles)
# - hud.png (320 x 66)      bandeau : cadre des étoiles, cadre du score, cadre de la jauge
import os
import sys
from PIL import Image, ImageDraw, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'graphics', 'interface', 'sac_de_frappe')

LIGHT, SHEEN, PALE = (229, 243, 250), (250, 253, 254), (213, 238, 248)
BLUE, STEEL, DEEP, SLATE = (80, 126, 166), (69, 103, 129), (36, 52, 62), (51, 71, 81)

# Cadres du bandeau (x, y, largeur, hauteur), y relatif au bandeau ; repris par la scène Ruby
STARS_BOX = (4, 3, 312, 27)
SCORE_BOX = (4, 33, 104, 31)
BAR_BOX = (111, 33, 205, 31)


def half(im):
    return im.resize((im.width // 2, im.height // 2), Image.NEAREST)


def box(d, rect):
    x, y, w, h = rect
    d.rounded_rectangle((x, y, x + w - 1, y + h - 1), 5, fill=DEEP)
    d.rounded_rectangle((x + 1, y + 1, x + w - 2, y + h - 2), 4, fill=SHEEN)
    d.rounded_rectangle((x + 2, y + 2, x + w - 3, y + h - 3), 3, fill=LIGHT)
    d.line((x + 4, y + h - 3, x + w - 5, y + h - 3), fill=PALE)


def hud():
    im = Image.new('RGBA', (320, 66), BLUE + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 319, 1), fill=SLATE)
    d.line((0, 2, 319, 2), fill=STEEL)
    for rect in (STARS_BOX, SCORE_BOX, BAR_BOX):
        box(d, rect)
    return im


def main():
    if len(sys.argv) < 2:
        sys.exit('usage : build_assets.py dossier_Files')
    src = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    load = lambda n: Image.open(os.path.join(src, n + '.png')).convert('RGBA')
    load('bg').resize((320, 180), Image.LANCZOS).save(os.path.join(OUT, 'bg.png'))
    half(load('punch_bag')).save(os.path.join(OUT, 'bag.png'))
    star = half(load('star'))
    star.save(os.path.join(OUT, 'star.png'))
    # case vide : l'étoile en creux, aux couleurs du cadre
    empty = Image.new('RGBA', star.size, (0, 0, 0, 0))
    alpha = star.getchannel('A').point(lambda a: 110 if a > 0 else 0)
    empty.paste(Image.new('RGBA', star.size, (145, 175, 198, 255)), (0, 0), alpha)
    empty.save(os.path.join(OUT, 'star_empty.png'))
    half(load('arrow')).save(os.path.join(OUT, 'arrow.png'))
    half(load('bar')).save(os.path.join(OUT, 'bar.png'))
    hud().save(os.path.join(OUT, 'hud.png'))
    print('Images écrites dans', OUT)


if __name__ == '__main__':
    main()

# Poké Récré : graphismes (graphics/interface/poke_recre/) et sons (audio/se/poke_recre_*.ogg)
#   python tools/poke_recre/build_assets.py "chemin/vers/Pokemon Amie for 20.1"
# Les images du plugin « Pokémon Amie » d'Essentials (écran 512 x 384) sont mises à l'échelle de PSDK (320 x 240) :
# - décors (bg_*.png, 320 x 240)                     : Field, Forest, Cave… réduits
# - affection / satiete / bonne_humeur (+ _off, 16 x 14) : cœur, pomme, note de musique
# - heart.png (20 x 17), hand.png / hand_press.png (22 x 21), crumbs.png (miettes)
# - feed.png (36 x 36), switch.png (30 x 30), back.png (30 x 30)
# Et, aux couleurs de l'interface Horizon :
# - stats.png (104 x 70)   cadre du nom et des trois jauges
# - tray.png (312 x 40)    plateau des friandises
# - party.png (300 x 150)  cadre du choix du Pokémon ; slot.png / slot_active.png (40 x 36)
# - icon_amie.png (64 x 32) dans graphics/interface/pokesmart/ (appli du téléphone)
import os
import shutil
import sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'graphics', 'interface', 'poke_recre')
SE = os.path.join(ROOT, 'audio', 'se')

LIGHT, SHEEN, PALE = (229, 243, 250), (250, 253, 254), (213, 238, 248)
BLUE, STEEL, DEEP, SKY = (80, 126, 166), (69, 103, 129), (36, 52, 62), (145, 201, 247)
PINK = (240, 112, 160)

BACKDROPS = {
    'field': 'Field', 'forest': 'Forest', 'cave': 'Cave', 'cave_dark': 'CaveDark', 'city': 'City', 'mountain': 'Mountain',
    'snow': 'Snow', 'water': 'Water', 'underwater': 'Underwater', 'indoor_a': 'IndoorA', 'indoor_b': 'IndoorB',
    'indoor_c': 'IndoorC', 'champion': 'Champion', 'elite_a': 'EliteA', 'elite_b': 'EliteB', 'elite_c': 'EliteC',
    'elite_d': 'EliteD',
}


def panel(w, h, radius=6):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=DEEP)
    d.rounded_rectangle((1, 1, w - 2, h - 2), radius - 1, fill=SHEEN)
    d.rounded_rectangle((2, 2, w - 3, h - 3), radius - 2, fill=LIGHT)
    d.line((radius, h - 3, w - radius - 1, h - 3), fill=PALE)
    return im


def slot(active):
    im = Image.new('RGBA', (40, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 39, 35), 6, fill=PINK if active else STEEL)
    d.rounded_rectangle((2, 2, 37, 33), 5, fill=SHEEN if active else PALE)
    return im


def main():
    if len(sys.argv) < 2:
        sys.exit('usage : build_assets.py "dossier Pokemon Amie for 20.1"')
    src = os.path.join(sys.argv[1], 'Graphics', 'Pictures', 'Pokemon Amie')
    os.makedirs(OUT, exist_ok=True)
    load = lambda n: Image.open(os.path.join(src, n + '.png')).convert('RGBA')
    size = lambda im, w, h: im.resize((w, h), Image.LANCZOS)
    for name, file in BACKDROPS.items():
        size(load(file), 320, 240).save(os.path.join(OUT, f'bg_{name}.png'))
    for src_name, name in (('affect', 'affection'), ('full', 'satiete'), ('enjoy', 'bonne_humeur')):
        size(load(src_name), 16, 14).save(os.path.join(OUT, f'{name}.png'))
        size(load(src_name + '_empty'), 16, 14).save(os.path.join(OUT, f'{name}_off.png'))
    size(load('heart'), 20, 17).save(os.path.join(OUT, 'heart.png'))
    size(load('hand2'), 22, 21).save(os.path.join(OUT, 'hand.png'))
    size(load('hand1'), 22, 21).save(os.path.join(OUT, 'hand_press.png'))
    crumbs = load('eaten3')
    box = crumbs.getbbox() or (0, 0, crumbs.width, crumbs.height)
    crumbs.crop(box).save(os.path.join(OUT, 'crumbs.png'))
    size(load('feed'), 36, 36).save(os.path.join(OUT, 'feed.png'))
    size(load('switch'), 30, 30).save(os.path.join(OUT, 'switch.png'))
    size(load('back'), 30, 30).save(os.path.join(OUT, 'back.png'))
    panel(104, 70).save(os.path.join(OUT, 'stats.png'))
    panel(312, 40).save(os.path.join(OUT, 'tray.png'))
    panel(300, 150, 8).save(os.path.join(OUT, 'party.png'))
    slot(False).save(os.path.join(OUT, 'slot.png'))
    slot(True).save(os.path.join(OUT, 'slot_active.png'))
    # Appli du téléphone : le cœur sur 2 images (normale / choisie)
    heart = size(load('affect'), 26, 23)
    icon = Image.new('RGBA', (64, 32), (0, 0, 0, 0))
    icon.alpha_composite(heart, (3, 5))
    icon.alpha_composite(heart, (35, 4))
    ImageDraw.Draw(icon).point([(58, 4), (59, 3), (59, 5), (60, 4), (59, 4)], fill=(255, 255, 255))
    icon.save(os.path.join(ROOT, 'graphics', 'interface', 'pokesmart', 'icon_amie.png'))
    audio = os.path.join(sys.argv[1], 'Audio', 'SE')
    for name in ('eat', 'pet'):
        path = os.path.join(audio, name + '.ogg')
        if os.path.exists(path):
            shutil.copyfile(path, os.path.join(SE, f'poke_recre_{name}.ogg'))
    print('Images écrites dans', OUT)


if __name__ == '__main__':
    main()

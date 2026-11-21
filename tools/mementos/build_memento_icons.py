# Souvenirs : icônes des nouveaux rubans et insignes (graphics/interface/ribbons/<symbole>_ribbon.png, 40 x 40)
#   python tools/mementos/build_memento_icons.py chemin/vers/mementos.png
# mementos.png : planche du plugin « Improved Mementos » (cases de 78 x 78, 8 par ligne). Chaque case est réduite
# de moitié (dessin en double taille) et centrée dans 40 x 40, comme les rubans de PSDK.
# ICONS : place de chaque souvenir dans la planche (IconPosition du plugin)
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'graphics', 'interface', 'ribbons')
CELL = 78

ICONS = {
    'red': 106, 'green': 107, 'blue': 108, 'marine': 109, 'land': 110, 'sky': 111,
    'lunchtime_mark': 113, 'sleepy_time_mark': 114, 'dusk_mark': 115, 'dawn_mark': 116, 'cloudy_mark': 117,
    'rainy_mark': 118, 'stormy_mark': 119, 'snowy_mark': 120, 'blizzard_mark': 121, 'dry_mark': 122,
    'sandstorm_mark': 123, 'misty_mark': 124, 'destiny_mark': 125, 'fishing_mark': 126, 'curry_mark': 127,
    'rare_mark': 128, 'uncommon_mark': 129, 'rowdy_mark': 130, 'absent_minded_mark': 131, 'jittery_mark': 132,
    'excited_mark': 133, 'charismatic_mark': 134, 'calmness_mark': 135, 'intense_mark': 136, 'zoned_out_mark': 137,
    'joyful_mark': 138, 'angry_mark': 139, 'smiley_mark': 140, 'teary_mark': 141, 'upbeat_mark': 142,
    'peeved_mark': 143, 'intellectual_mark': 144, 'ferocious_mark': 145, 'crafty_mark': 146, 'scowling_mark': 147,
    'kindly_mark': 148, 'flustered_mark': 149, 'pumped_up_mark': 150, 'zero_energy_mark': 151, 'prideful_mark': 152,
    'unsure_mark': 153, 'humble_mark': 154, 'thorny_mark': 155, 'vigor_mark': 156, 'slump_mark': 157,
    'jumbo_mark': 158, 'mini_mark': 159, 'itemfinder_mark': 160, 'partner_mark': 161, 'gourmand_mark': 162,
    'alpha_mark': 163, 'mightiest_mark': 164, 'titan_mark': 165, 'partner': 166,
}


def icon(sheet, index):
    x, y = CELL * (index % 8), CELL * (index // 8)
    cell = sheet.crop((x + 1, y + 1, x + CELL + 1, y + CELL + 1)).resize((CELL // 2, CELL // 2), Image.NEAREST)
    out = Image.new('RGBA', (40, 40), (0, 0, 0, 0))
    out.alpha_composite(cell, (0, 0))
    return out


def main():
    if len(sys.argv) < 2:
        print(__doc__ or 'usage : build_memento_icons.py mementos.png')
        sys.exit(1)
    sheet = Image.open(sys.argv[1]).convert('RGBA')
    for symbol, index in ICONS.items():
        icon(sheet, index).save(os.path.join(OUT, f'{symbol}_ribbon.png'))
    print(len(ICONS), 'icônes écrites dans', OUT)


if __name__ == '__main__':
    main()

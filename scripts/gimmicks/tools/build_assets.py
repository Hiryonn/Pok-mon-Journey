"""Prépare les images du plugin gimmicks (graphics/interface/gimmicks) à partir des ressources d'Essentials.

Les ressources d'Essentials sont faites pour un écran 512 x 384 avec des pixels doublés : on les réduit de moitié
(un pixel sur deux) pour l'écran 320 x 240 de PSDK.

    python build_assets.py <dossier Pokémon (contenant Dynamax, Terastallization, Z-Power)> <racine du projet>
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))


def half(img):
    img = img.convert('RGBA')
    return img.resize((img.width // 2, img.height // 2), Image.NEAREST)


def main(res, root):
    out = os.path.join(root, 'graphics', 'interface', 'gimmicks')
    os.makedirs(out, exist_ok=True)
    src = os.path.join(HERE, 'source')
    jobs = {
        # onglets « ACTION » (2 états : éteint / allumé ; Téra : éteint puis un par type)
        'tab_mega': os.path.join(src, 'cursor_mega.png'),
        'tab_zmove': os.path.join(res, 'Z-Power/Graphics/Plugins/Z-Power/cursor_zmove.png'),
        'tab_ultra': os.path.join(res, 'Z-Power/Graphics/Plugins/Z-Power/cursor_ultra.png'),
        'tab_dynamax': os.path.join(res, 'Dynamax/Graphics/Plugins/Dynamax/cursor_dynamax.png'),
        'tab_tera': os.path.join(res, 'Terastallization/Graphics/Plugins/Terastallization/cursor_tera.png'),
        # icônes des boîtes d'infos
        'icon_mega': os.path.join(src, 'icon_mega.png'),
        'icon_primal_alpha': os.path.join(src, 'icon_primal_alpha.png'),
        'icon_primal_omega': os.path.join(src, 'icon_primal_omega.png'),
        'icon_dynamax': os.path.join(res, 'Dynamax/Graphics/Plugins/Dynamax/icon_dynamax.png'),
        'icon_gmax': os.path.join(res, 'Dynamax/Graphics/Plugins/Dynamax/gmax_factor.png'),
        'icon_ultra': os.path.join(res, 'Z-Power/Graphics/Plugins/Z-Power/icon_ultra.png'),
        'icon_zcrystal': os.path.join(res, 'Z-Power/Graphics/UI/Party/icon_zcrystal.png'),
        'tera_types': os.path.join(res, 'Terastallization/Graphics/Plugins/Terastallization/tera_types.png'),
        'dynamax_meter': os.path.join(res, 'Dynamax/Graphics/Plugins/Dynamax/dynamax_meter.png'),
        'dynamax_levels': os.path.join(res, 'Dynamax/Graphics/Plugins/Dynamax/dynamax_levels.png'),
        # cinématiques
        'tera_crystal_1': os.path.join(res, 'Terastallization/Graphics/Plugins/Deluxe Battle Kit/Tera/crystal_1.png'),
        'tera_crystal_2': os.path.join(res, 'Terastallization/Graphics/Plugins/Deluxe Battle Kit/Tera/crystal_2.png'),
        'tera_crystal_3': os.path.join(res, 'Terastallization/Graphics/Plugins/Deluxe Battle Kit/Tera/crystal_3.png'),
        'tera_crystal_4': os.path.join(res, 'Terastallization/Graphics/Plugins/Deluxe Battle Kit/Tera/crystal_4.png'),
        'tera_icon': os.path.join(res, 'Terastallization/Graphics/Plugins/Deluxe Battle Kit/Tera/icon.png'),
        'tera_pulse': os.path.join(res, 'Terastallization/Graphics/Plugins/Deluxe Battle Kit/Tera/pulse.png'),
        'tera_shine': os.path.join(res, 'Terastallization/Graphics/Plugins/Deluxe Battle Kit/Tera/shine.png'),
        'z_particle': os.path.join(res, 'Z-Power/Graphics/Plugins/Deluxe Battle Kit/Z-Power/particle.png'),
        'z_ultra_icon': os.path.join(res, 'Z-Power/Graphics/Plugins/Deluxe Battle Kit/Z-Power/ultra_icon.png'),
        'z_ultra_strobes': os.path.join(res, 'Z-Power/Graphics/Plugins/Deluxe Battle Kit/Z-Power/ultra_strobes.png'),
        'dynamax_pattern': os.path.join(res, 'Dynamax/Graphics/Plugins/Dynamax/Patterns/dynamax.png'),
    }
    for name, path in jobs.items():
        if not os.path.exists(path):
            print('absent :', path)
            continue
        half(Image.open(path)).save(os.path.join(out, name + '.png'))
        print('ok :', name)
    # motifs Téra (un par type) et titres des capacités Z
    pat = os.path.join(res, 'Terastallization/Graphics/Plugins/Terastallization/Patterns')
    if os.path.isdir(pat):
        os.makedirs(os.path.join(out, 'tera_patterns'), exist_ok=True)
        for f in os.listdir(pat):
            if f.lower().endswith('.png'):
                name = f[:-4].replace('tera_pattern', '').strip('_').lower() or 'default'
                half(Image.open(os.path.join(pat, f))).save(os.path.join(out, 'tera_patterns', name + '.png'))
    titles = os.path.join(res, 'Z-Power/Graphics/Plugins/Deluxe Battle Kit/Z-Power/Z-Titles')
    if os.path.isdir(titles):
        os.makedirs(os.path.join(out, 'z_titles'), exist_ok=True)
        for f in os.listdir(titles):
            if f.lower().endswith('.png'):
                half(Image.open(os.path.join(titles, f))).save(os.path.join(out, 'z_titles', f.lower()))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])

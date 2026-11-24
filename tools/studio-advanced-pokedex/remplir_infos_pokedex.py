"""Remplit Couleur, Habitat et Apparence du corps des Pokémon du projet avec les données officielles (n° national 1 à 1025).

    python remplir_infos_pokedex.py <dossier du projet> [--ecraser] [--dry-run]

Écrit Data/configs/plugins/pokedex_infos.json. Par défaut, ce qui est déjà réglé (à la main dans Studio) est conservé :
seules les cases vides sont remplies ; --ecraser remplace aussi les valeurs existantes.
Les Pokémon hors n° 1 à 1025 (Fakemon) ne sont pas touchés. La génération n'est pas écrite : elle se déduit du n° national.
Source : PokéAPI (infos_officielles.json, à côté de ce fichier).
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def load(path, default):
    if not os.path.exists(path):
        return default
    with open(path, encoding='utf-8-sig') as f:
        return json.load(f)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    force, dry = '--ecraser' in sys.argv, '--dry-run' in sys.argv
    project = args[0] if args else os.path.abspath(os.path.join(HERE, '..', '..'))
    folder = os.path.join(project, 'Data', 'Studio', 'pokemon')
    if not os.path.isdir(folder):
        sys.exit('Projet introuvable (pas de Data/Studio/pokemon) : ' + project)
    official = load(os.path.join(HERE, 'infos_officielles.json'), {})['species']
    target = os.path.join(project, 'Data', 'configs', 'plugins', 'pokedex_infos.json')
    data = load(target, {})
    data['klass'] = 'PokedexInfosConfig'
    creatures = data.setdefault('creatures', {})
    filled = {'color': 0, 'habitat': 0, 'shape': 0}
    touched = 0
    for path in sorted(glob.glob(os.path.join(folder, '*.json'))):
        try:
            info = load(path, {})
        except ValueError:
            continue
        db, number = info.get('dbSymbol'), info.get('id')
        if not db or db == '__undef__' or str(number) not in official:
            continue
        color, habitat, shape = official[str(number)]
        entry = creatures.setdefault(db, {})
        changed = False
        for key, value in (('color', color), ('habitat', habitat), ('shape', shape)):
            if value in ('', 0, None):
                continue
            if force or entry.get(key) in (None, '', 0):
                if entry.get(key) != value:
                    entry[key] = value
                    filled[key] += 1
                    changed = True
        touched += changed
        if not entry:
            del creatures[db]
    print('Pokémon modifiés : %d (couleurs %d, habitats %d, apparences du corps %d)' % (touched, filled['color'], filled['habitat'], filled['shape']))
    if dry:
        print('(essai : rien écrit)')
        return
    os.makedirs(os.path.dirname(target), exist_ok=True)
    if os.path.exists(target) and not os.path.exists(target + '.bak'):
        os.replace(target, target + '.bak')
    with open(target, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print('Écrit : ' + target)


if __name__ == '__main__':
    main()

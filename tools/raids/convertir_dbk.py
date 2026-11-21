# Raids : conversion des données du plugin « [DBK] Raid Battles » d'Essentials (Lucidious89) pour le plugin raids
#   python3 tools/raids/convertir_dbk.py <dossier « Raid Battles »> [racine du projet]
# Écrit Data/configs/plugins/raids.json (réglages, styles, espèces des raids, récompenses) et
# Data/configs/plugins/raids_cartes.json (cartes des aventures). Les espèces et formes absentes de Studio sont ignorées.
import json
import os
import re
import sys

SRC = sys.argv[1]
ROOT = sys.argv[2] if len(sys.argv) > 2 else '.'
PBS = os.path.join(SRC, 'PBS')
STUDIO = os.path.join(ROOT, 'Data/Studio')
OUT = os.path.join(ROOT, 'Data/configs/plugins')


def load_dir(name):
    out = {}
    folder = os.path.join(STUDIO, name)
    for f in os.listdir(folder):
        if f.endswith('.json'):
            with open(os.path.join(folder, f), encoding='utf-8') as h:
                d = json.load(h)
            if d.get('dbSymbol') and d['dbSymbol'] != '__undef__':
                out[d['dbSymbol']] = d
    return out


POKEMON = load_dir('pokemon')
KEY = {re.sub(r'[^a-z0-9]', '', k): k for k in POKEMON}


SPECIAL = {'NIDORANfE': 'nidoranf', 'NIDORANmA': 'nidoranm'}


def species(essentials_id):
    if essentials_id in SPECIAL and SPECIAL[essentials_id] in POKEMON:
        return SPECIAL[essentials_id]
    return KEY.get(re.sub(r'[^a-z0-9]', '', essentials_id.lower()))


def read_pbs(path):
    entries = []
    cur = None
    with open(path, encoding='utf-8-sig') as h:
        for line in h:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            m = re.match(r'^\[(.+)\]$', line)
            if m:
                cur = {'_id': m.group(1)}
                entries.append(cur)
                continue
            m = re.match(r'^(\w+)\s*=\s*(.*)$', line)
            if m and cur is not None:
                key, value = m.group(1), m.group(2)
                if key in cur:
                    cur[key] = cur[key] if isinstance(cur[key], list) else [cur[key]]
                    cur[key].append(value)
                else:
                    cur[key] = value
    return entries


# --- Espèces des raids --------------------------------------------------------------------------------
species_list = []
skipped = []
folder = os.path.join(PBS, 'Plugins', '[DBK] Raid Battles')
for name in ['pokemon.txt', 'pokemon_base_Gen_9_Pack.txt', 'pokemon_forms.txt', 'pokemon_forms_Gen_9_Pack.txt',
             'pokemon_forms_gmax.txt']:
    path = os.path.join(folder, name)
    if not os.path.exists(path):
        continue
    gmax_file = 'gmax' in name
    for e in read_pbs(path):
        parts = e['_id'].split(',')
        sym = species(parts[0])
        form = int(parts[1]) if len(parts) > 1 else 0
        ranks = [int(r) for r in str(e.get('RaidRanks', '')).split(',') if r.strip().isdigit()]
        styles = [s.strip().lower() for s in str(e.get('RaidStyle', '')).split(',') if s.strip()]
        if not sym or not ranks:
            skipped.append(e['_id'])
            continue
        entry = {'pokemon': sym, 'form': 0 if gmax_file else form, 'ranks': ranks, 'styles': styles}
        if gmax_file:
            entry['gmax'] = True
        else:
            forms = [f.get('form', 0) for f in POKEMON[sym].get('forms', [])]
            if form not in forms:
                skipped.append(e['_id'])
                continue
        species_list.append(entry)

# --- Cartes des aventures -------------------------------------------------------------------------------
NAMES = {'Debug Maze': 'Labyrinthe d’essai', 'Cavernous Lair': 'Antre caverneux'}
DESCS = {'A map designed for testing each map tile in debug mode.': 'Une carte pour essayer chaque case.',
         'A small cavern filled with Raid Pokémon.': 'Une petite caverne remplie de Pokémon de raid.'}


def coord(text):
    text = text.strip()
    return [int(text[0:2]), int(text[2:4])]


maps = []
for e in read_pbs(os.path.join(PBS, 'adventure_maps.txt')):
    tiles = []
    for t in (e.get('Tile') if isinstance(e.get('Tile'), list) else [e.get('Tile')] if e.get('Tile') else []):
        p = [x.strip() for x in t.split(',')]
        tile = {'id': p[0], 'x': coord(p[1])[0], 'y': coord(p[1])[1]}
        if len(p) > 2 and p[2].lower() == 'true':
            tile['toggle'] = True
        if len(p) > 3 and p[3]:
            tile['warp'] = coord(p[3])
        tiles.append(tile)
    dims = [int(v) for v in e.get('Dimensions', '1,1').split(',')]
    name = e.get('Name', 'Carte')
    desc = e.get('Description', '')
    maps.append({
        'id': int(e['_id']), 'name': {'fr': NAMES.get(name, name), 'en': name},
        'description': {'fr': DESCS.get(desc, desc), 'en': desc}, 'image': e.get('Filename', 'Cave'),
        'darkness': int(e.get('DarknessChance', 10)), 'width': dims[0], 'height': dims[1],
        'start': coord(e.get('PlayerStart', '0000')),
        'pathways': [coord(c) for c in e.get('Pathways', '').split(',') if c.strip()],
        'battles': [coord(c) for c in e.get('Battles', '').split(',') if c.strip()], 'tiles': tiles
    })

os.makedirs(OUT, exist_ok=True)
raids_file = os.path.join(OUT, 'raids.json')
config = {}
if os.path.exists(raids_file):
    with open(raids_file, encoding='utf-8') as h:
        config = json.load(h)
config['klass'] = 'RaidsConfig'
config['species'] = species_list
with open(raids_file, 'w', encoding='utf-8') as h:
    json.dump(config, h, ensure_ascii=False, indent=2)
    h.write('\n')
with open(os.path.join(OUT, 'raids_cartes.json'), 'w', encoding='utf-8') as h:
    json.dump({'klass': 'RaidMapsConfig', 'maps': maps}, h, ensure_ascii=False, indent=1)
    h.write('\n')
print(len(species_list), 'espèces,', len(skipped), 'ignorées ;', len(maps), 'cartes')
print('ignorées :', ', '.join(skipped[:60]))

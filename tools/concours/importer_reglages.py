# Concours : crée Data/configs/plugins/concours.json d'après les réglages du plugin « Pokemon Super Contests »
# (thèmes, accessoires et leurs points par thème, fonds, concurrents par rang), avec les noms en français.
#
# Usage : python importer_reglages.py <dossier Plugins/Pokemon Super Contests> [dossier du projet] [--force]
#   Sans --force, un concours.json existant n'est pas remplacé (les réglages faits dans Studio sont gardés) : seuls
#   les réglages manquants y sont ajoutés (juges, danse, capacités du jeu d'acteur).
#   moves : capacités du jeu d'acteur d'après moves.txt, { "megahorn": ["cool", 2, "plus2_if_last"] }
#           (type, cœurs d'attrait de 0 à 3, effet), rangées par nom de capacité de Studio (Data/Studio/moves)
import json
import os
import re
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else '.'
ROOT = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith('--') else os.path.join(os.path.dirname(__file__), '..', '..')
FORCE = '--force' in sys.argv
OUT = os.path.join(ROOT, 'Data', 'configs', 'plugins', 'concours.json')


def slug(name):
    return re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_')


THEMES = [
    ('bright', 'The Bright', 'Lumineux'), ('colorful', 'The Colorful', 'Coloré'), ('created', 'The Created', 'Créatif'),
    ('festive', 'The Festive', 'Festif'), ('flexible', 'The Flexible', 'Souple'), ('gaudy', 'The Gaudy', 'Tape-à-l’œil'),
    ('intangible', 'The Intangible', 'Intangible'), ('natural', 'The Natural', 'Naturel'), ('relaxed', 'The Relaxed', 'Détendu'),
    ('shapely', 'The Shapely', 'Harmonieux'), ('sharp', 'The Sharp', 'Tranchant'), ('solid', 'The Solid', 'Solide'),
]
CATEGORIES = [
    ('fluffs', 'Fluffs', 'Duvets'), ('pebbles', 'Pebbles and Boulders', 'Cailloux'), ('scales', 'Scales', 'Écailles'),
    ('feathers', 'Feathers', 'Plumes'), ('facial_hair', 'Facial Hair', 'Pilosité'), ('natural', 'Natural', 'Nature'),
    ('effects', 'Effects', 'Effets'), ('flowers', 'Flowers', 'Fleurs'), ('specs', 'Specs', 'Lunettes'),
    ('misc', 'Misc', 'Divers'), ('barrettes', 'Barrettes', 'Barrettes'), ('balloons', 'Balloons', 'Ballons'),
    ('headwear', 'Headwear', 'Chapeaux'), ('stages', 'Stages', 'Estrades'), ('special', 'Special', 'Spécial'),
]
PAGE_TO_CATEGORY = {
    'Fluffs': 'fluffs', 'Pebbles_and_Boulders': 'pebbles', 'Scales': 'scales', 'Feathers': 'feathers',
    'Facial_Hair': 'facial_hair', 'Natural': 'natural', 'Massage_Accessories': 'effects', 'Flowers': 'flowers',
    'Specs': 'specs', 'Misc': 'misc', 'Barrettes': 'barrettes', 'Balloons': 'balloons', 'Headwear': 'headwear',
    'Stages': 'stages', 'Special': 'special',
}
FR = {
    'Black Fluff': 'Duvet noir', 'Brown Fluff': 'Duvet marron', 'Orange Fluff': 'Duvet orange', 'Pink Fluff': 'Duvet rose',
    'White Fluff': 'Duvet blanc', 'Yellow Fluff': 'Duvet jaune', 'Black Pebble': 'Caillou noir',
    'Glitter Boulder': 'Rocher brillant', 'Jagged Boulder': 'Rocher pointu', 'Mini Pebble': 'Mini caillou',
    'Round Pebble': 'Caillou rond', 'Snaggy Pebble': 'Caillou crochu', 'Big Scale': 'Grande écaille',
    'Blue Scale': 'Écaille bleue', 'Green Scale': 'Écaille verte', 'Narrow Scale': 'Écaille fine',
    'Pink Scale': 'Écaille rose', 'Purple Scale': 'Écaille violette', 'Blue Feather': 'Plume bleue',
    'Red Feather': 'Plume rouge', 'White Feather': 'Plume blanche', 'Yellow Feather': 'Plume jaune',
    'Black Beard': 'Barbe noire', 'Black Moustache': 'Moustache noire', 'White Beard': 'Barbe blanche',
    'White Moustache': 'Moustache blanche', 'Big Leaf': 'Grande feuille', 'Narrow Leaf': 'Feuille fine',
    'Shed Claw': 'Griffe perdue', 'Shed Horn': 'Corne perdue', 'Small Leaf': 'Petite feuille', 'Stump': 'Souche',
    'Thick Mushroom': 'Gros champignon', 'Thin Mushroom': 'Champignon fin', 'Determination': 'Détermination',
    'Eerie Thing': 'Truc étrange', 'Glitter Powder': 'Poudre scintillante', 'Humming Note': 'Note fredonnée',
    'Mystic Fire': 'Feu mystique', 'Peculiar Spoon': 'Cuillère bizarre', 'Poison Extract': 'Extrait de poison',
    'Pretty Dewdrop': 'Jolie rosée', 'Puffy Smoke': 'Fumée gonflée', 'Seashell': 'Coquillage',
    'Shimmering Fire': 'Feu chatoyant', 'Shiny Powder': 'Poudre brillante', 'Snow Crystal': 'Cristal de neige',
    'Sparks': 'Étincelles', 'Spring': 'Ressort', 'Wealthy Coin': 'Pièce de fortune', 'Blue Flower': 'Fleur bleue',
    'Orange Flower': 'Fleur orange', 'Pink Flower': 'Fleur rose', 'Red Flower': 'Fleur rouge',
    'White Flower': 'Fleur blanche', 'Yellow Flower': 'Fleur jaune', 'Black Specs': 'Lunettes noires',
    'Googly Specs': 'Lunettes rigolotes', 'Gorgeous Specs': 'Lunettes chics', 'Cape': 'Cape', 'Carpet': 'Tapis',
    'Colored Parasol': 'Ombrelle colorée', 'Confetti': 'Confettis', 'Fluffy Bed': 'Lit douillet',
    'Mirror Ball': 'Boule à facettes', 'Old Umbrella': 'Vieux parapluie', 'Photo Board': 'Panneau photo',
    'Retro Pipe': 'Pipe rétro', 'Spotlight': 'Projecteur', 'Standing Mike': 'Micro sur pied', 'Surfboard': 'Planche de surf',
    'Sweet Candy': 'Bonbon sucré', 'Blue Barrette': 'Barrette bleue', 'Green Barrette': 'Barrette verte',
    'Pink Barrette': 'Barrette rose', 'Red Barrette': 'Barrette rouge', 'Yellow Barrette': 'Barrette jaune',
    'Blue Balloons': 'Ballons bleus', 'Green Balloons': 'Ballons verts', 'Pink Balloons': 'Ballon rose',
    'Red Balloons': 'Ballons rouges', 'Yellow Balloons': 'Ballon jaune', 'Heroic Headband': 'Bandeau héroïque',
    'Lace Headress': 'Coiffe en dentelle', 'Professor Hat': 'Toque de professeur', 'Silk Veil': 'Voile de soie',
    'Top Hat': 'Haut-de-forme', 'Award Podium': 'Podium', 'Cube Stage': 'Estrade cube', 'Flower Stage': 'Estrade fleurie',
    'Glass Stage': 'Estrade de verre', 'Gold Pedestal': 'Piédestal doré', 'Big Tree': 'Grand arbre',
    'Chimchar Mask': 'Masque Ouisticram', 'Comet': 'Comète', 'Crown': 'Couronne', 'Flag': 'Drapeau',
    'Piplup Mask': 'Masque Tiplouf', 'Tiara': 'Diadème', 'Turtwig Mask': 'Masque Tortipouss',
}
BACKDROPS_FR = {
    'City at Night': 'Ville la nuit', 'Cumulus Cloud': 'Cumulus', 'Desert': 'Désert', 'Dress up': 'Habillage',
    'Fiery': 'Flammes', 'Flower Patch': 'Champ de fleurs', 'Future Room': 'Salle futuriste',
    'Gingerbread Room': 'Maison en pain d’épice', 'Open Sea': 'Haute mer', 'Outer Space': 'Espace',
    'Ranch': 'Ranch', 'Seafloor': 'Fonds marins', 'Sky': 'Ciel', 'Snowy town': 'Village enneigé',
    'Tatami Room': 'Salle à tatamis', 'Theater': 'Théâtre', 'Total Darkness': 'Obscurité totale',
    'Underground': 'Souterrain',
}
SPECIES = {
    'PIKACHU': 'pikachu', 'SPINARAK': 'spinarak', 'EKANS': 'ekans', 'PIDGEY': 'pidgey', 'PACHIRISU': 'pachirisu',
    'ARIADOS': 'ariados', 'ARBOK': 'arbok', 'PIDGEOTTO': 'pidgeotto', 'MANECTRIC': 'manectric', 'CROBAT': 'crobat',
    'RHYDON': 'rhydon', 'SCYTHER': 'scyther', 'AGGRON': 'aggron', 'TYRANITAR': 'tyranitar', 'GARDEVOIR': 'gardevoir',
    'PIDGEOT': 'pidgeot',
}
CHARSETS = {'NPC 01': 'NPC_awakening_1', 'NPC 02': 'NPC_awakening_17', 'NPC 03': 'NPC_awakening_25', 'NPC 04': 'NPC_awakening_20'}
TYPES = [
    ('cool', 'Sang-froid', 'Coolness'), ('beauty', 'Beauté', 'Beauty'), ('cute', 'Grâce', 'Cuteness'),
    ('smart', 'Intelligence', 'Smartness'), ('tough', 'Robustesse', 'Toughness'),
]
RANKS = [('normal', 'Normal', 'Normal'), ('great', 'Méga', 'Great'), ('ultra', 'Ultra', 'Ultra'), ('master', 'Master', 'Master')]


def accessories(text, files):
    out = []
    pages = re.split(r'\n([A-Za-z_]+) = \{', text)
    for k in range(1, len(pages), 2):
        page, body = pages[k], pages[k + 1]
        for name, values in re.findall(r'"([^"]+)":\s*\{([^}]*)\}', body):
            points = dict((t, int(v)) for t, v in re.findall(r'"The (\w+)":\s*(\d+)', values))
            ident = slug(name)
            file = ident if ident in files else (ident[:-1] if ident.endswith('s') and ident[:-1] in files else ident)
            out.append({
                'id': ident, 'file': file, 'category': PAGE_TO_CATEGORY.get(page, 'misc'),
                'name': {'fr': FR.get(name, name), 'en': name},
                'points': [points.get(t[1].split(' ', 1)[1], 0) for t in THEMES],
            })
    return out


def backdrops(text):
    block = re.search(r'BACKDROPS = \[(.*?)\]', text, re.S).group(1)
    return [{'id': slug(n), 'file': slug(n), 'name': {'fr': BACKDROPS_FR.get(n, n), 'en': n}}
            for n in re.findall(r'"([^"]+)"', block)]


def contestants(text):
    out = {}
    for rank in ('NORMAL', 'GREAT', 'ULTRA', 'MASTER'):
        block = re.search(r'CONTESTANTS_%s = \[(.*?)\n\]' % rank, text, re.S).group(1)
        rows = []
        for entry in re.findall(r'\{(.*?)\}', block, re.S):
            def get(key, default=None):
                m = re.search(key + r':\s*("([^"]*)"|:?(\w+))', entry)
                return default if not m else (m.group(2) if m.group(2) is not None else m.group(3))
            rows.append({
                'trainer': get('TrainerName'), 'charset': CHARSETS.get(get('TrainerCharacter'), 'NPC_awakening_1'),
                'species': SPECIES.get(get('PkmnSpecies'), get('PkmnSpecies', '').lower()), 'nickname': get('PkmnName'),
                'gender': int(get('PkmnGender', 0)) + 1 if get('PkmnGender') else 1, 'form': int(get('PkmnForm', 0)),
                'shiny': get('PkmnShiny') == 'true', 'dressup': int(get('DressupPoints', 0)),
                'condition': int(get('ConditionPoints', 0)), 'picture': slug(get('PkmnName')),
            })
        out[rank.lower()] = rows
    return out


CONTEST_TYPES = {'Cool': 'cool', 'Beauty': 'beauty', 'Cute': 'cute', 'Smart': 'smart', 'Tough': 'tough'}
JUDGES = [
    {'name': 'Jordan', 'charset': 'npc_ace-trainer-m-01'},
    {'name': '', 'charset': ''},
    {'name': 'Keira', 'charset': 'npc_lady'},
]
# Danse : chances des concurrents (excellent, bien, bonne direction) et du danseur principal (pas rapprochés,
# pas au début ou à la fin, pas différents), en % par rang
DANCE = {
    'timing': [[10, 70, 80], [35, 50, 85], [60, 30, 90], [80, 15, 95]],
    'lead': [[20, 10, 20], [40, 30, 40], [60, 60, 60], [80, 80, 80]],
}
# Jeu d'acteur : chance qu'un concurrent évite le juge déjà choisi par d'autres, par rang
ACTING_AVOID = [90, 50, 20, 0]


def snake(name):
    name = re.sub(r'(?<=[a-z])(?=[A-Z0-9])|(?<=[0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])', '_', name)
    return name.lower()


def moves(src, root):
    path = os.path.join(src, 'moves.txt')
    if not os.path.exists(path):
        return {}
    studio = os.path.join(root, 'Data', 'Studio', 'moves')
    symbols = {}
    if os.path.isdir(studio):
        for name in os.listdir(studio):
            if name.endswith('.json'):
                with open(os.path.join(studio, name), encoding='utf-8') as f:
                    symbol = json.load(f).get('dbSymbol', '')
                symbols[symbol.replace('_', '')] = symbol
    text = open(path, encoding='utf-8-sig').read()
    out = {}
    for name, body in re.findall(r'^\[(\w+)\]\n(.*?)(?=^#-|\Z)', text, re.S | re.M):
        flags = re.search(r'Flags = (.*)', body)
        flags = flags.group(1) if flags else ''
        kind = re.search(r'Contest_(Cool|Beauty|Cute|Smart|Tough)\b', flags)
        if not kind:
            continue
        appeal = re.search(r'Contest_Appeal_(\d)', flags)
        effect = re.search(r'Contest_Effect_(\w+)', flags)
        symbol = symbols.get(name.lower(), name.lower())
        out[symbol] = [CONTEST_TYPES[kind.group(1)], int(appeal.group(1)) if appeal else 0,
                       snake(effect.group(1)) if effect else 'basic']
    return dict(sorted(out.items()))


def complete(path):
    with open(path, encoding='utf-8') as f:
        config = json.load(f)
    settings = config.setdefault('settings', {})
    settings.setdefault('judges', JUDGES)
    settings.setdefault('dance', DANCE)
    settings.setdefault('acting_avoid', ACTING_AVOID)
    if not config.get('moves'):
        config['moves'] = moves(SRC, ROOT)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(config, ensure_ascii=False, indent=2) + '\n')
    print('Réglages complétés :', path, f"({len(config['moves'])} capacités)")


def main():
    if os.path.exists(OUT) and not FORCE:
        complete(OUT)
        return
    acc_dir = os.path.join(ROOT, 'graphics', 'interface', 'concours', 'accessoires')
    files = {f[:-4] for f in os.listdir(acc_dir)} if os.path.isdir(acc_dir) else set()
    dressup = open(os.path.join(SRC, '03_Dressup', 'Dressup - Settings.rb'), encoding='utf-8').read()
    people = open(os.path.join(SRC, '02_Reception and Stage', 'Contestants Settings.rb'), encoding='utf-8').read()
    teams = contestants(people)
    config = {
        'klass': 'ConcoursConfig',
        'settings': {
            'hall_bgm': 'concours_hall', 'judging_bgm': 'concours_jugement', 'results_bgm': 'concours_resultats',
            'winner_bgm': 'concours_gagnant', 'win_bgm': 'concours_victoire', 'mc_name': 'Dexter',
            'mc_charset': 'chef_orchestre', 'pass_item': '', 'heal': False, 'dressup_time': 60,
            'max_accessories': [5, 10, 15, 20], 'win_switch': 0, 'result_variable': 0,
            'judges': JUDGES, 'dance': DANCE, 'acting_avoid': ACTING_AVOID,
        },
        'types': [{'id': i, 'name': {'fr': fr, 'en': en}} for i, fr, en in TYPES],
        'ranks': [{'id': i, 'name': {'fr': fr, 'en': en}, 'switch': 0, 'contestants': teams[i]} for i, fr, en in RANKS],
        'ribbons': {t: [f'{t}_{r}_sinnoh' for r, _, _ in RANKS] for t, _, _ in TYPES},
        'themes': [{'id': i, 'name': {'fr': fr, 'en': en}} for i, en, fr in THEMES],
        'categories': [{'id': i, 'name': {'fr': fr, 'en': en}} for i, en, fr in CATEGORIES],
        'accessories': accessories(dressup, files),
        'backdrops': backdrops(dressup),
        'starter': {'accessories': {'black_fluff': 2, 'orange_fluff': 1, 'big_leaf': 1, 'small_leaf': 1, 'glitter_powder': 1},
                    'backdrops': ['dress_up']},
        'rewards': [],
        'moves': moves(SRC, ROOT),
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(config, ensure_ascii=False, indent=2) + '\n')
    print('Réglages des concours :', OUT, f"({len(config['accessories'])} accessoires, {len(config['backdrops'])} fonds)")


if __name__ == '__main__':
    main()

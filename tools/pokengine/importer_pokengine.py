#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Importe des créatures « free to use » de Pokéngine (pokengine.org) dans le projet Pokémon Studio / PSDK.

Ce que tu fournis (téléchargé toi-même depuis la fiche de la créature, le script n'ouvre jamais le site) :
  - la fiche imprimée en PDF (ou enregistrée en .txt) : "Geckrow - Pokéngine.pdf"
  - ses images : <code>.webp (icône), <code>_1.webp (face), <code>_2.webp (dos)   (le code est entre parenthèses
    dans le titre de la fiche, ex. 00xjjwow) ; .png accepté aussi ; <code>_3 (planche du follower, convertie au format RPG Maker)
  - mode --formes : la fiche est une forme d'un Pokémon déjà présent (importer_formes_pokengine.bat)

Ce que le script écrit dans le projet :
  - graphics/pokedex/{pokefront,pokeback,pokeicon}/<id>.png (+ les versions shiny, copies des normales)
  - Data/Studio/pokemon/<symbole>.json   (stats, types, talents, capacités, évolutions, ressources...)
  - Data/Text/Dialogs/{100000,100001,100002}.csv   (nom, catégorie, description ; anglais dans toutes les langues)
  - Data/Studio/dex/<dex>.json   (par défaut national_fakedex)
  - tools/pokengine/importes.json (mémoire des imports) et CREDITS_POKENGINE.md (auteurs et permissions)

Usage :
  python3 importer_pokengine.py <dossier des téléchargements> <dossier du projet> [options]
Options : voir --help. Utilise --dry-run pour voir ce qui serait fait sans rien écrire.
Dépendances : Python 3, Pillow (images .webp comprises) ; pour lire un PDF : pdftotext (poppler) ou le module pypdf.
"""
import argparse
import csv
import io
import json
import re
import shutil
import subprocess
import sys
import unicodedata
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow est nécessaire : pip install pillow")

HERE = Path(__file__).resolve().parent
DEFAULT_TYPES = ['normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug',
                 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy']
# groupes d'œufs -> numéros de Studio (vérifiés sur les données du projet)
EGG_GROUPS = {'monster': 1, 'water 1': 2, 'bug': 3, 'flying': 4, 'field': 5, 'fairy': 6, 'grass': 7, 'plant': 7, 'human-like': 8,
              'humanlike': 8, 'human like': 8, 'water 3': 9, 'mineral': 10, 'amorphous': 11, 'water 2': 12, 'ditto': 13, 'dragon': 14,
              'undiscovered': 15, 'no eggs': 15}
GROWTH = {'fast': 0, 'medium fast': 1, 'slow': 2, 'medium slow': 3, 'fluctuating': 4, 'erratic': 5}
STAT_KEYS = ['baseHp', 'baseAtk', 'baseDfe', 'baseAts', 'baseDfs', 'baseSpd']      # ordre de la fiche : HP Att Def SpA SpD Spe
EV_NAMES = {'hp': 'evHp', 'att': 'evAtk', 'atk': 'evAtk', 'def': 'evDfe', 'sp. att': 'evAts', 'sp att': 'evAts', 'sp. def': 'evDfs',
            'sp def': 'evDfs', 'spe': 'evSpd', 'speed': 'evSpd'}
LABELS = ('Height', 'Weight', 'Egg', 'Gender', 'Growth', 'Exp.', 'Catch', 'Happiness', 'Effort', 'Designer', 'Owner', 'Permission',
          'Region', 'Obtained')
TEXT_FILES = (100000, 100001, 100002)          # noms, catégories, descriptions
LANG_COLUMNS = 7                               # en,fr,it,de,es,ko,kana

WARNINGS = []


def warn(mon, message):
    text = f'[{mon}] {message}'
    if text not in WARNINGS:
        WARNINGS.append(text)


def slug(text):
    text = unicodedata.normalize('NFD', str(text)).encode('ascii', 'ignore').decode()
    text = text.lower().replace("'", '').replace('’', '')
    return re.sub(r'[^a-z0-9]+', '_', text).strip('_')


# ---------------------------------------------------------------------------------------------------------------------
# Lecture de la fiche
# ---------------------------------------------------------------------------------------------------------------------
def read_sheet(path):
    """Texte d'une fiche (.txt, ou .pdf lu avec pdftotext -layout, sinon pypdf)."""
    path = Path(path)
    if path.suffix.lower() != '.pdf':
        return path.read_text(encoding='utf-8', errors='replace')
    exe = shutil.which('pdftotext')
    if exe:
        out = subprocess.run([exe, '-layout', str(path), '-'], capture_output=True, check=True)
        return out.stdout.decode('utf-8', errors='replace')
    try:
        from pypdf import PdfReader
    except ImportError:
        sys.exit("Pour lire un PDF il faut pdftotext (poppler) ou le module pypdf (pip install pypdf), "
                 "sinon enregistre la fiche en .txt.")
    reader = PdfReader(str(path))
    pages = []
    for page in reader.pages:
        try:
            pages.append(page.extract_text(extraction_mode='layout'))
        except TypeError:
            pages.append(page.extract_text())
    return '\n'.join(pages)


def known_name(words, known):
    """Plus long début de `words` (3 mots au plus) dont le symbole est connu ; renvoie (symbole, mots utilisés)."""
    for n in range(min(4, len(words)), 0, -1):
        sym = slug(' '.join(words[:n]))
        if sym in known:
            return sym, n
    return None, 0


def parse_sheet(text, types, moves, abilities):
    mon = {'warnings': []}
    lines = text.splitlines()
    m = re.search(r'#\s*(\d+)\s+(.+?)\s+\(([a-z0-9]{6,12})\)', text)
    if not m:
        raise ValueError("titre introuvable (attendu : « #1 Nom (code) »)")
    mon['number'], mon['name'], mon['code'] = int(m.group(1)), m.group(2).strip(), m.group(3)
    name = mon['name']

    def find(pattern, flags=0):
        pattern = pattern.replace(r'\s+', r'[ \t]+')      # une étiquette vide ne doit pas prendre la ligne suivante
        r = re.search(pattern, text, flags | re.M)
        return r.group(1).strip() if r else None

    # stats : les six nombres sont posés au-dessus de leur étiquette (HP Att Def Att Def Spe), à des hauteurs différentes
    # selon la barre ; on prend, pour chaque étiquette, le nombre le plus proche au-dessus dans sa colonne
    label_re = re.compile(r'\bHP\b.*\bAtt\b.*\bDef\b.*\bAtt\b.*\bDef\b.*\bSpe\b')
    stats_line = next((i for i, l in enumerate(lines) if label_re.search(l)), None)
    if stats_line is None:
        raise ValueError("étiquettes des statistiques (HP Att Def Att Def Spe) introuvables")
    centers = [(m_.start() + m_.end()) / 2 for m_ in re.finditer(r'HP|Att|Def|Spe', lines[stats_line])]
    if len(centers) != 6:
        raise ValueError('étiquettes des statistiques illisibles')
    found = []
    for col in centers:
        best = None
        for i in range(stats_line - 1, max(-1, stats_line - 14), -1):
            for n in re.finditer(r'(?<!\d)\d{1,3}(?!\d)', lines[i]):
                if abs((n.start() + n.end()) / 2 - col) <= 4.5 and int(n.group()) <= 255:
                    best = int(n.group())
                    break
            if best is not None:
                break
        found.append(best)
    if None in found:
        raise ValueError(f'statistiques de base introuvables (trouvé : {found})')
    mon['stats'] = dict(zip(STAT_KEYS, found))

    h = find(r'Height\s+([\d.]+)\s*m')
    w = find(r'Weight\s+([\d.]+)\s*kg')
    mon['height'] = float(h) if h else None
    mon['weight'] = float(w) if w else None
    groups = find(r'Egg groups\s+(.+?)\s*$')
    mon['egg_groups'] = [g.strip() for g in groups.split(',')] if groups else []
    cycles = find(r'Egg cycles\s+(\d+)')
    mon['egg_cycles'] = int(cycles) if cycles else None
    mon['growth'] = find(r'Growth rate\s+([A-Za-z ]+?)\s*$')
    for key, label in (('exp_yield', r'Exp\. yield'), ('catch_rate', r'Catch rate'), ('happiness', r'Happiness')):
        v = find(label + r'\s+(\d+)')
        mon[key] = int(v) if v else None
    mon['effort'] = {}
    effort = find(r'Effort points\s+(.+?)\s*$')
    if effort:
        for amount, stat in re.findall(r'(\d)\s*(HP|Att|Atk|Def|Sp\.?\s*Att|Sp\.?\s*Def|Spe(?:ed)?)', effort, re.I):
            key = EV_NAMES.get(re.sub(r'\s+', ' ', stat.lower()))
            if key:
                mon['effort'][key] = int(amount)
    mon['female_rate'] = None
    gender = find(r'^.*?Gender\s+(.+?)\s*$')
    if gender:
        if re.search(r'genderless', gender, re.I):
            mon['female_rate'] = -1
        else:
            g = re.search(r'([\d.]+)\s*%\s*(male|female)', gender, re.I)
            if g:
                pct = float(g.group(1))
                mon['female_rate'] = round(100 - pct if g.group(2).lower() == 'male' else pct, 2)
    mon['owner'] = find(r'Owner\s+(.+?)\s*$')
    mon['permission'] = find(r'Permission\s+(.+?)\s*$')
    mon['designer'] = find(r'Designer\s+(.+?)\s*$')

    # types et catégorie : lignes entre les statistiques et « Gender » qui n'ont pas d'étiquette de l'autre colonne
    mon['types'] = []
    mon['category'] = None
    for line in lines[stats_line + 1:stats_line + 16]:
        if re.search(r'\bGender\b', line):
            break
        if any(label in line for label in LABELS):
            continue
        for piece in re.split(r'\s{2,}', line.strip()):
            if piece.lower() in types and piece.lower() not in mon['types']:
                mon['types'].append(piece.lower())
            elif re.fullmatch(r"[\w' -]+ Mon", piece) and not mon['category']:
                mon['category'] = piece
    if not mon['types']:
        raise ValueError('type introuvable')

    # talents
    ab = {}
    moves_at = next((i for i, l in enumerate(lines) if 'Level-up moves' in l), len(lines))
    for line in lines[:moves_at]:          # avant les listes de capacités (« Hidden Power » y est une capacité)
        r = re.search(r'\bAbility\s*(\d)\s+(.+)$', line)
        if r:
            ab[int(r.group(1))] = r.group(2)
        r = re.match(r'\s*Hidden\s+(?!Power\b)(.+)$', line)
        if r:
            ab['hidden'] = r.group(1)
    mon['abilities'] = {}
    for key, value in ab.items():
        sym, _ = known_name(value.split(), abilities)
        if sym:
            mon['abilities'][key] = sym
        else:
            warn(name, f"talent inconnu du projet : « {value[:40]} »")

    # textes
    def block(start_label, stops):
        out, on = [], False
        for line in lines:
            s = line.strip()
            if not on:
                on = s == start_label
                continue
            if s in stops or s.startswith(stops_prefix):
                break
            if s:
                out.append(s)
        return ' '.join(out)
    stops_prefix = ('Evo line', 'Name:', '#')
    mon['flavor'] = block('Flavor', ('Notes',))
    mon['notes'] = block('Notes', ())

    # évolutions : « Geckrow Lv. 16 Goanopy Lv. 34 Varanitor »
    mon['chain'] = []
    mon['evolutions'] = []
    for line in lines:
        if re.search(r'\bLv\.\s*\d+', line) and not re.search(r'moves', line):
            parts = re.split(r'\s+Lv\.\s*(\d+)\s+', line.strip())
            names = parts[0::2]
            levels = parts[1::2]
            mon['chain'] = [n.strip() for n in names]
            mon['evolutions'] = [(slug(names[i]), slug(names[i + 1]), int(levels[i])) for i in range(len(levels)) if i + 1 < len(names)]
            break

    # capacités : trois colonnes (niveau, à apprendre, œuf) repérées par leur titre
    mon['moves'] = {'level': [], 'tech': [], 'egg': []}
    head = next((i for i, l in enumerate(lines) if 'Level-up moves' in l and 'Teach moves' in l), None)
    if head is None:
        mon['warnings'].append('aucune liste de capacités')
    else:
        h = lines[head]
        p2 = h.index('Teach moves') - 3
        p3 = h.index('Egg moves') - 3 if 'Egg moves' in h else None      # pas de colonne « œuf » pour certaines créatures
        for line in lines[head + 1:]:
            if 'Expand' in line:
                mon['warnings'].append("la liste « à apprendre » est repliée (bouton Expand) : elle est peut-être incomplète ; "
                                       "déplie-la avant d'imprimer la fiche")
                break
            if 'Check out' in line:
                break
            columns = ((0, p2), (p2, p3), (p3, None)) if p3 is not None else ((0, p2), (p2, None))
            for col, (a, b) in zip(('level', 'tech', 'egg'), columns):
                piece = line[a:b] if b else line[a:]
                bits = [x for x in re.split(r'\s{2,}', piece.strip()) if x]
                if not bits:
                    continue
                level = 1
                if col == 'level':
                    if len(bits) < 2 or not re.fullmatch(r'\d+|-', bits[0]):
                        continue
                    level = 1 if bits[0] == '-' else int(bits[0])
                    bits = bits[1:]
                move = re.sub(r'\s+STAB$', '', bits[0]).strip()
                sym = slug(move)
                if sym not in moves:
                    warn(name, f"capacité inconnue du projet : « {move} » ({sym})")
                    continue
                if (sym, level) not in mon['moves'][col]:
                    mon['moves'][col].append((sym, level))
    return mon


# ---------------------------------------------------------------------------------------------------------------------
# Images
# ---------------------------------------------------------------------------------------------------------------------
def find_image(folder, code, suffix):
    """Image du code donné : <code><suffixe> ou, quand Windows a renommé les doublons, <code> (1) pour _1 et <code> (2) pour _2.
    Extensions png/webp/gif/jpg, sous-dossiers compris, majuscules ignorées."""
    number = suffix.lstrip('_')
    wanted = set()
    for ext in ('.png', '.webp', '.gif', '.jpg', '.jpeg'):
        wanted.add(f'{code}{suffix}{ext}'.lower())
        if number:
            wanted.add(f'{code} ({number}){ext}'.lower())
            wanted.add(f'{code}({number}){ext}'.lower())
    for p in sorted(Path(folder).rglob('*')):
        if p.is_file() and p.name.lower() in wanted:
            return p
    return None


def files_with_code(folder, code):
    return sorted(p.name for p in Path(folder).rglob('*') if p.is_file() and code.lower() in p.name.lower() and p.suffix.lower() != '.pdf')


def trim(img):
    box = img.getbbox()
    return img.crop(box) if box else img


def scaled(img, scale):
    if scale == 1:
        return img
    return img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.NEAREST)


def battler(img, scale, size=96, bottom=4):
    """Sprite de combat : taille d'origine (ou agrandi si --scale), au centre bas d'une image transparente d'au moins
    96 x 96 ; le cadre grandit si le sprite est plus grand que lui."""
    sprite = scaled(trim(img.convert('RGBA')), scale)
    size = max(size, sprite.width, sprite.height + bottom)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.alpha_composite(sprite, ((size - sprite.width) // 2, size - bottom - sprite.height))
    return out


def icon_sheet(img, scale):
    """Icône : deux images de 32 x 32 côte à côte (la seconde un peu plus bas, comme le rebond des icônes de Pokémon)."""
    sprite = scaled(trim(img.convert('RGBA')), scale)
    sprite = sprite.crop((0, 0, min(sprite.width, 32), min(sprite.height, 30)))
    out = Image.new('RGBA', (64, 32), (0, 0, 0, 0))
    x = (32 - sprite.width) // 2
    y = 30 - sprite.height
    out.alpha_composite(sprite, (x, y))
    out.alpha_composite(sprite, (32 + x, y + 2))
    return out


def follower_sheet(img, inverse=False):
    """Follower au format RPG Maker : 4 colonnes (pas) x 4 lignes (bas, gauche, droite, haut).
    La planche Pokéngine a 2 colonnes (2 images d'animation) x 4 lignes (bas, haut, droite, gauche) : les 2 images
    sont répétées (A B A B) et les lignes remises dans l'ordre de RPG Maker. `inverse` échange gauche et droite."""
    img = img.convert('RGBA')
    cw, ch = img.width // 2, img.height // 4
    source_rows = [0, 2, 3, 1] if inverse else [0, 3, 2, 1]       # ligne RPG Maker -> ligne Pokéngine
    out = Image.new('RGBA', (cw * 4, ch * 4), (0, 0, 0, 0))
    for row, src in enumerate(source_rows):
        for col in range(4):
            cell = img.crop(((col % 2) * cw, src * ch, (col % 2 + 1) * cw, (src + 1) * ch))
            out.paste(cell, (col * cw, row * ch))
    return out


def auto_scale(images, limit=88):
    widest = max(max(i.width, i.height) for i in images)
    return max(1, limit // widest)


# ---------------------------------------------------------------------------------------------------------------------
# Projet
# ---------------------------------------------------------------------------------------------------------------------
def stems(folder):
    return {p.stem for p in Path(folder).glob('*.json')} if Path(folder).exists() else set()


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding='utf-8', newline='\n')


def csv_records(path):
    if not path.exists():
        return [['en', 'fr', 'it', 'de', 'es', 'ko', 'kana']]
    with open(path, encoding='utf-8', newline='') as f:
        return list(csv.reader(f))


def set_text_rows(project, row_index, values, dry, files=TEXT_FILES, replace=False):
    """Écrit la ligne `row_index` (0 = première ligne après l'en-tête) de chaque fichier de textes ; ajoute si besoin."""
    for file_id, value in zip(files, values):
        path = project / 'Data/Text/Dialogs' / f'{file_id}.csv'
        rows = csv_records(path)
        records = len(rows) - 1
        new = [value] * LANG_COLUMNS
        if not replace and row_index < records and any(c.strip() for c in rows[1 + row_index]) and rows[1 + row_index][0] != value:
            raise RuntimeError(f"{path.name} : la ligne {row_index} est déjà prise par « {rows[1 + row_index][0][:30]} »")
        if dry:
            continue
        raw = path.read_bytes() if path.exists() else b''
        eol = '\r\n' if b'\r\n' in raw else '\n'
        if row_index >= records:
            buf = io.StringIO(newline='')
            writer = csv.writer(buf, lineterminator=eol)
            for _ in range(row_index - records):
                writer.writerow([''] * LANG_COLUMNS)
            writer.writerow(new)
            text = raw.decode('utf-8')
            if text and not text.endswith('\n'):
                text += eol
            path.write_bytes((text + buf.getvalue()).encode('utf-8'))
        else:
            rows[1 + row_index] = new
            buf = io.StringIO(newline='')
            csv.writer(buf, lineterminator=eol).writerows(rows)
            path.write_bytes(buf.getvalue().encode('utf-8'))


FIRST_ID = 10000          # les créatures Pokéngine commencent ici, bien au-dessus des Pokémon du jeu


def next_free_id(project):
    ids = []
    for f in (project / 'Data/Studio/pokemon').glob('*.json'):
        try:
            ids.append(json.loads(f.read_text(encoding='utf-8'))['id'])
        except (ValueError, KeyError):
            pass
    first = max([i for i in ids if i >= FIRST_ID], default=FIRST_ID - 1) + 1
    rows = max(len(csv_records(project / 'Data/Text/Dialogs' / f'{n}.csv')) - 1 for n in TEXT_FILES)
    return max(first, FIRST_ID) if rows <= FIRST_ID else max(first, rows)


def build_species(mon, sp_id, symbol, project, args, known_species, overrides):
    types = mon['types']
    cycles = mon['egg_cycles']
    chain_first = slug(mon['chain'][0]) if mon['chain'] else symbol
    abilities = mon['abilities']
    first_ab = abilities.get(1) or abilities.get('hidden') or 'none'
    ab_list = [first_ab, abilities.get(2, first_ab), abilities.get('hidden', first_ab)]
    exp = GROWTH.get((mon['growth'] or '').lower())
    if exp is None:
        warn(mon['name'], f"courbe d'expérience « {mon['growth']} » inconnue : Medium Slow par défaut")
        exp = 3
    groups = [EGG_GROUPS.get(g.lower()) for g in mon['egg_groups']]
    groups = [g for g in groups if g]
    if not groups:
        warn(mon['name'], "groupes d'œufs absents : Undiscovered (15)")
        groups = [15]
    if len(groups) == 1:
        groups = [groups[0], groups[0]]
    missing = []
    catch = mon['catch_rate']
    if catch is None:
        catch, _ = 45, missing.append("taux de capture (45)")
    female = mon['female_rate']
    if female is None:
        female, _ = 50, missing.append('ratio de genre (50 % de femelles)')
    if mon['effort'] == {}:
        missing.append("points d'effort (0)")
    if cycles is None:
        cycles, _ = 20, missing.append("cycles d'œuf (20)")
    if missing:
        warn(mon['name'], "absent de la fiche, valeurs par défaut : " + ', '.join(missing) + " — à régler dans Studio ou avec overrides.json")
    pid = f'{sp_id:04d}'
    form = {
        'form': 0, 'formTextId': {'name': 0, 'description': 0},
        'height': mon['height'] if mon['height'] is not None else 1.0, 'weight': mon['weight'] if mon['weight'] is not None else 10.0,
        'type1': types[0], 'type2': types[1] if len(types) > 1 else '__undef__',
        **mon['stats'],
        'evHp': 0, 'evAtk': 0, 'evDfe': 0, 'evSpd': 0, 'evAts': 0, 'evDfs': 0,
        'evolutions': [],
        'experienceType': exp, 'baseExperience': mon['exp_yield'] or 64, 'baseLoyalty': mon['happiness'] if mon['happiness'] is not None else 50,
        'catchRate': catch, 'femaleRate': female, 'breedGroups': groups[:2], 'hatchSteps': cycles * 128,
        'babyDbSymbol': chain_first, 'babyForm': 0,
        'itemHeld': [{'dbSymbol': 'none', 'chance': 0}, {'dbSymbol': 'none', 'chance': 0}],
        'abilities': ab_list, 'frontOffsetY': 0,
        'resources': {
            'icon': pid, 'iconShiny': pid + 's', 'front': pid, 'frontShiny': pid + 's', 'back': pid, 'backShiny': pid + 's',
            'footprint': '', 'character': '', 'characterShiny': '', 'egg': 'egg', 'iconEgg': 'egg',
            'cry': args.cry, 'hasFemale': False,
        },
        'moveSet': [],
    }
    form.update(mon['effort'])
    for sym, level in sorted(mon['moves']['level'], key=lambda x: x[1]):
        form['moveSet'].append({'klass': 'LevelLearnableMove', 'move': sym, 'level': level})
    for sym, _ in mon['moves']['tech']:
        form['moveSet'].append({'klass': 'TechLearnableMove', 'move': sym})
    for sym, _ in mon['moves']['egg']:
        form['moveSet'].append({'klass': 'BreedLearnableMove', 'move': sym})
    form.update(overrides.get(symbol, overrides.get(mon['code'], {})))
    return {'klass': 'Specie', 'id': sp_id, 'dbSymbol': symbol, 'forms': [form]}


def add_evolution(project, state, symbol, target, level, dry):
    path = project / 'Data/Studio/pokemon' / f'{symbol}.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    evs = data['forms'][0]['evolutions']
    if any(e['dbSymbol'] == target for e in evs):
        return False
    evs.append({'dbSymbol': target, 'form': 0, 'conditions': [{'type': 'minLevel', 'value': level}]})
    if not dry:
        write_json(path, data)
    return True


def split_name(full, override=None):
    """« Mobipup Green » -> (« Mobipup », « Green ») : le premier mot est le nom du Pokémon, le reste le nom de sa forme.
    Un nom en un seul mot n'a pas de forme. noms.json (dans le dossier des fiches) corrige : {"code": ["Mr. Mime", ""]}."""
    if override:
        return override[0], (override[1] if len(override) > 1 else '')
    words = full.split()
    if len(words) >= 2:
        return words[0], ' '.join(words[1:])
    return full, ''


def migrate_symbol(project, state, species, old, new, name, form_label, dry, dex_name):
    """Un Pokémon importé avant la séparation nom / forme (ex. mobipup_green) devient `mobipup` : fichier, textes, dex, mémoire."""
    entry = state.pop(old)
    old_path = project / 'Data/Studio/pokemon' / f'{old}.json'
    new_path = project / 'Data/Studio/pokemon' / f'{new}.json'
    print(f'~ {old} devient {new} (nom « {name} », forme « {form_label or name} »)')
    if not dry:
        if old_path.exists():
            data = json.loads(old_path.read_text(encoding='utf-8'))
            data['dbSymbol'] = new
            write_json(new_path, data)
            old_path.unlink()
        dex_path = project / 'Data/Studio/dex' / f'{dex_name}.json'
        if dex_path.exists():
            dex = json.loads(dex_path.read_text(encoding='utf-8'))
            for c in dex['creatures']:
                if c['dbSymbol'] == old:
                    c['dbSymbol'] = new
            write_json(dex_path, dex)
    set_text_rows(project, entry['id'], (name,), dry, (100000,), replace=True)
    if entry.get('form_name_row'):
        set_text_rows(project, entry['form_name_row'], (form_label or name,), dry, (100067,), replace=True)
    species.discard(old)
    species.add(new)
    entry['name'], entry['form_label'] = name, form_label
    state[new] = entry


def apply_bars(mon, sheet):
    """Complète la fiche avec ce qui est dessiné dans le PDF : taux de capture, genre, points d'effort (voir pdf_barres.py)."""
    if Path(sheet).suffix.lower() != '.pdf':
        return
    try:
        import pdf_barres
        bars = pdf_barres.read_bars(sheet)
    except ImportError:
        warn(mon['name'], "module pypdf absent : taux de capture, genre et points d'effort non lus dans le PDF (pip install pypdf)")
        return
    except Exception as e:      # noqa: BLE001
        warn(mon['name'], f"barres du PDF illisibles ({e}) : valeurs par défaut")
        return
    if mon['catch_rate'] is None and 'catch_rate' in bars:
        mon['catch_rate'] = bars['catch_rate']
    if mon['female_rate'] is None and 'female_rate' in bars:
        mon['female_rate'] = bars['female_rate']
    if not mon['effort'] and 'effort' in bars:
        mon['effort'] = dict(bars['effort']) or {'evHp': 0}


def split_base(name, species, mapping, code):
    """Trouve le Pokémon de base d'une fiche de forme. Renvoie (symbole, mot(s) restant(s) du nom) ou (None, '').
    Ordre : formes.json du dossier (code ou nom -> symbole), nom entier, puis le plus long groupe de mots du nom qui est un Pokémon."""
    for key in (code, slug(name)):
        if key in mapping and mapping[key] in species:
            return mapping[key], ''
    words = [w for w in re.split(r"[\s\-–—()/]+", name) if w]
    for length in range(len(words), 0, -1):
        for i in range(len(words) - length + 1):
            cand = slug(' '.join(words[i:i + length]))
            if cand in species:
                return cand, ' '.join(words[:i] + words[i + length:])
    return None, ''


def next_text_row(project, file_id):
    return len(csv_records(project / 'Data/Text/Dialogs' / f'{file_id}.csv')) - 1


def run_formes(args, sources, project, sheets, types, moves, abilities, species, overrides):
    """Mode --formes : chaque fiche devient une nouvelle forme d'un Pokémon qui existe déjà."""
    state_file = HERE / 'formes_importees.json'
    state = json.loads(state_file.read_text(encoding='utf-8')) if state_file.exists() else {}
    mapping_file = sources / 'formes.json'
    mapping = json.loads(mapping_file.read_text(encoding='utf-8')) if mapping_file.exists() else {}
    pk = project / 'graphics'
    done = []
    for sheet in sheets:
        try:
            mon = parse_sheet(read_sheet(sheet), types, moves, abilities)
            apply_bars(mon, sheet)
        except Exception as e:      # noqa: BLE001
            print(f'ERREUR {sheet.name} : {e}')
            continue
        name, code = mon['name'], mon['code']
        for w in mon['warnings']:
            warn(name, w)
        base, rest = split_base(name, species, mapping, code)
        if not base:
            print(f"ERREUR {name} : aucun Pokémon du projet ne correspond à ce nom. Mets un fichier formes.json dans {sources} : "
                  f'{{"{code}": "symbole_du_pokemon_de_base"}}')
            continue
        path = project / 'Data/Studio/pokemon' / f'{base}.json'
        species_data = json.loads(path.read_text(encoding='utf-8'))
        base_form = species_data['forms'][0]
        known = state.get(code)
        fid = None
        have = {f['form'] for f in species_data['forms']}
        if known and known['base'] == base:
            fid = known['form']
        exists = fid in have
        if args.images_seulement and not (known and exists):
            print(f'= {name} : forme pas encore importée : ignorée (--images-seulement ne refait que les images)')
            continue
        if known and exists and not args.force and not args.images_seulement:
            print(f'= {name} : déjà importée comme forme {fid} de {base} : ignorée (--force pour la refaire)')
            continue
        if known and not exists and not args.images_seulement:
            print(f'~ {name} : importée avant, mais la forme a disparu du JSON de {base} : je la refais (forme {fid})')
        if fid is None:
            fid = args.form_id or max(have) + 1
            if fid in have:
                print(f'ERREUR {name} : la forme {fid} existe déjà dans {base} (--form-id pour en choisir une autre)')
                continue
        front_p, back_p, icon_p = (find_image(sources, code, x) for x in ('_1', '_2', ''))
        if not (front_p and back_p):
            seen = files_with_code(sources, code)
            print(f'ERREUR {name} : il me faut {code}_1 (face) et {code}_2 (dos) dans {sources}. '
                  + ('Fichiers trouvés avec ce code : ' + ', '.join(seen) if seen else 'Aucun fichier ne contient ce code.'))
            continue
        front, back = Image.open(front_p).convert('RGBA'), Image.open(back_p).convert('RGBA')
        scale = auto_scale([trim(front), trim(back)]) if args.scale == 'auto' else float(args.scale)
        pid = f'{species_data["id"]:04d}'
        n, ns = f'{pid}_{fid}', f'{pid}s_{fid}'
        icon = icon_sheet(Image.open(icon_p), args.icon_scale) if icon_p else icon_sheet(front, min(1, 28 / max(trim(front).size)))
        if not icon_p:
            warn(name, "pas d'icône téléchargée : fabriquée à partir de la face")
        outputs = {
            f'pokedex/pokefront/{n}.png': battler(front, scale), f'pokedex/pokefrontshiny/{ns}.png': battler(front, scale),
            f'pokedex/pokeback/{n}.png': battler(back, scale), f'pokedex/pokebackshiny/{ns}.png': battler(back, scale),
            f'pokedex/pokeicon/{n}.png': icon, f'pokedex/pokeiconshiny/{ns}.png': icon,
        }
        follower_p = find_image(sources, code, '_3')
        if follower_p:
            sheet_f = follower_sheet(Image.open(follower_p), args.follower_inverse)
            outputs[f'characters/{n}.png'] = sheet_f
            outputs[f'characters/{ns}.png'] = sheet_f

        def save_images():
            for rel, img in outputs.items():
                (pk / rel).parent.mkdir(parents=True, exist_ok=True)
                img.save(pk / rel)

        if args.images_seulement:
            print(f'~ {name} (forme {fid} de {base}) : images refaites (x{scale})' + (' + follower' if follower_p else ''))
            if not args.dry_run:
                save_images()
                if follower_p:
                    for f in species_data['forms']:
                        if f['form'] == fid and not f['resources'].get('character'):
                            f['resources']['character'], f['resources']['characterShiny'] = n, ns
                            write_json(path, species_data)
            done.append(code)
            continue
        built = build_species(mon, species_data['id'], slug(name), project, args, species, overrides)['forms'][0]
        built['form'] = fid
        built['evolutions'] = []
        built['babyDbSymbol'] = base_form.get('babyDbSymbol', base)
        built['babyForm'] = base_form.get('babyForm', 0)
        res = built['resources']
        res.update({'icon': n, 'iconShiny': ns, 'front': n, 'frontShiny': ns, 'back': n, 'backShiny': ns,
                    'footprint': base_form['resources'].get('footprint', ''), 'character': n if follower_p else '',
                    'characterShiny': ns if follower_p else ''})
        if mon['evolutions']:
            warn(name, "évolutions de la fiche ignorées pour une forme : à régler dans Studio si besoin")
        name_row = known['name_row'] if known else next_text_row(project, 100067)
        desc_row = known['desc_row'] if known else next_text_row(project, 100068)
        built['formTextId'] = {'name': name_row, 'description': desc_row}
        print(f'+ {name} -> forme {fid} de {base} (id {species_data["id"]})  (types {"/".join(mon["types"])}, PV {mon["stats"]["baseHp"]}, '
              f'{len(mon["moves"]["level"])} capacités par niveau, sprites x{scale}' + (', follower' if follower_p else ', pas de follower') + ')')
        species_data['forms'] = [f for f in species_data['forms'] if f['form'] != fid] + [built]
        species_data['forms'].sort(key=lambda f: f['form'])
        if not args.dry_run:
            save_images()
            write_json(path, species_data)
        set_text_rows(project, name_row, (rest or name,), args.dry_run, (100067,))
        set_text_rows(project, desc_row, (mon['flavor'] or '...',), args.dry_run, (100068,))
        state[code] = {'base': base, 'form': fid, 'name': name, 'name_row': name_row, 'desc_row': desc_row,
                       'owner': mon['owner'], 'permission': mon['permission'], 'notes': mon['notes']}
        done.append(code)
    if done and not args.dry_run:
        state_file.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding='utf-8')
        credits = HERE / 'CREDITS_POKENGINE.md'
        text = credits.read_text(encoding='utf-8') if credits.exists() else '# Crédits des créatures importées de Pokéngine\n\n'
        for code, e in state.items():
            if f'code Pokéngine {code})' not in text:
                text += (f"- **{e['name']}** (forme {e['form']} de {e['base']}, code Pokéngine {code}) — propriétaire : {e.get('owner') or '?'} ; "
                         f"permission : {e.get('permission') or '?'}" + (f" ; {e['notes']}" if e.get('notes') else '') + '\n')
        credits.write_text(text, encoding='utf-8')
    print()
    if WARNINGS:
        print('À vérifier :')
        for w in WARNINGS:
            print('  -', w)
    print(f"\n{'[essai, rien écrit] ' if args.dry_run else ''}{len(done)} forme(s) importée(s)."
          + (" Rouvre Studio : il régénère ses fichiers de textes au prochain lancement." if done and not args.dry_run else ''))


def main():
    ap = argparse.ArgumentParser(description='Importe des créatures Pokéngine (fiche PDF + images) dans le projet.')
    ap.add_argument('sources', help='dossier contenant les fiches (.pdf/.txt) et les images téléchargées')
    ap.add_argument('project', help='dossier du projet (celui qui contient Data/ et graphics/)')
    ap.add_argument('--start-id', type=int, help='numéro de la première créature (défaut : 10000, puis le suivant libre)')
    ap.add_argument('--dex', default='national_fakedex', help="dex de Studio où les ajouter (défaut : national_fakedex ; « aucun » pour ne pas)")
    ap.add_argument('--scale', default='1', help="agrandissement des sprites (défaut 1 : taille d'origine, posés en bas d'un cadre 96 x 96) ; ex. 2, 2.5, ou auto (entier le plus grand qui rentre)")
    ap.add_argument('--icon-scale', type=float, default=1, help="agrandissement de l'icône (défaut 1)")
    ap.add_argument('--cry', default='', help='cri à utiliser (nom du fichier de audio/se/cries, ex. 0001.ogg) ; vide : aucun')
    ap.add_argument('--images-seulement', action='store_true',
                    help="refait seulement les images des créatures déjà importées (JSON, textes et dex intacts : tes réglages dans Studio sont gardés)")
    ap.add_argument('--formes', action='store_true',
                    help="les fiches sont des FORMES de Pokémon déjà dans le projet : ajoute la forme au JSON du Pokémon de base au lieu de créer un Pokémon")
    ap.add_argument('--form-id', type=int, help='numéro de la forme (défaut : le suivant libre du Pokémon de base)')
    ap.add_argument('--follower-inverse', action='store_true', help='échange gauche et droite du follower si le sens est inversé dans le jeu')
    ap.add_argument('--force', action='store_true', help='réécrire une créature déjà importée')
    ap.add_argument('--dry-run', action='store_true', help="n'écrit rien, montre seulement le résultat")
    args = ap.parse_args()

    sources, project = Path(args.sources), Path(args.project)
    if not (project / 'Data/Studio/pokemon').exists():
        sys.exit(f"{project} n'est pas un projet Studio (Data/Studio/pokemon introuvable).")
    types = set(stems(project / 'Data/Studio/types')) or set(DEFAULT_TYPES)
    moves = stems(project / 'Data/Studio/moves')
    abilities = stems(project / 'Data/Studio/abilities')
    species = stems(project / 'Data/Studio/pokemon')
    state_file = HERE / 'importes.json'
    state = json.loads(state_file.read_text(encoding='utf-8')) if state_file.exists() else {}
    overrides_file = sources / 'overrides.json'
    overrides = json.loads(overrides_file.read_text(encoding='utf-8')) if overrides_file.exists() else {}
    names_file = sources / 'noms.json'
    names_override = json.loads(names_file.read_text(encoding='utf-8')) if names_file.exists() else {}

    sheets = sorted(p for p in sources.iterdir() if p.suffix.lower() in ('.pdf', '.txt'))
    if not sheets:
        sys.exit('Aucune fiche (.pdf ou .txt) dans ' + str(sources))
    if args.formes:
        return run_formes(args, sources, project, sheets, types, moves, abilities, species, overrides)
    next_id = args.start_id or next_free_id(project)
    done = []
    for sheet in sheets:
        try:
            mon = parse_sheet(read_sheet(sheet), types, moves, abilities)
            apply_bars(mon, sheet)
        except Exception as e:      # noqa: BLE001
            print(f'ERREUR {sheet.name} : {e}')
            continue
        full_name = mon['name']
        name, form_label = split_name(full_name, names_override.get(mon['code']))
        symbol = slug(name)
        old_symbol = slug(full_name)
        if old_symbol != symbol and old_symbol in state and symbol not in state and not args.images_seulement:
            migrate_symbol(project, state, species, old_symbol, symbol, name, form_label, args.dry_run, args.dex)
            done.append(symbol)
        for w in mon['warnings']:
            warn(name, w)
        known = state.get(symbol)
        existing = project / 'Data/Studio/pokemon' / f'{symbol}.json'
        if args.images_seulement and not known and existing.exists():      # importé sans mémoire : on reprend son numéro
            known = {'id': json.loads(existing.read_text(encoding='utf-8'))['id']}
        if args.images_seulement and not known:
            print(f'= {name} pas encore importé : ignoré (--images-seulement ne refait que les images)')
            continue
        if known and not existing.exists() and not args.images_seulement:
            print(f'~ {name} : importé avant, mais son JSON a été supprimé : je le refais (id {known["id"]})')
        elif known and not args.force and not args.images_seulement:
            print(f'= {name} déjà importé (id {known["id"]}) : ignoré (--force pour le refaire)')
            continue
        if symbol in species and not known:
            print(f'! {name} : un Pokémon « {symbol} » existe déjà dans le projet : ignoré')
            continue
        sp_id = known['id'] if known else next_id
        if not known:
            next_id += 1
        front_p, back_p, icon_p = (find_image(sources, mon['code'], s) for s in ('_1', '_2', ''))
        if not (front_p and back_p):
            seen = files_with_code(sources, mon['code'])
            print(f'ERREUR {name} : il me faut {mon["code"]}_1 (face) et {mon["code"]}_2 (dos) en .webp/.png dans {sources}. '
                  + ('Fichiers trouvés avec ce code : ' + ', '.join(seen) if seen else 'Aucun fichier ne contient ce code.'))
            continue
        front, back = Image.open(front_p).convert('RGBA'), Image.open(back_p).convert('RGBA')
        scale = auto_scale([trim(front), trim(back)]) if args.scale == 'auto' else float(args.scale)
        pid = f'{sp_id:04d}'
        pk = project / 'graphics'
        outputs = {
            f'pokedex/pokefront/{pid}.png': battler(front, scale), f'pokedex/pokefrontshiny/{pid}s.png': battler(front, scale),
            f'pokedex/pokeback/{pid}.png': battler(back, scale), f'pokedex/pokebackshiny/{pid}s.png': battler(back, scale),
        }
        if icon_p:
            icon = icon_sheet(Image.open(icon_p), args.icon_scale)
        else:
            icon = icon_sheet(front, min(1, 28 / max(trim(front).size)))
            warn(name, 'pas d\'icône téléchargée : fabriquée à partir de la face')
        outputs[f'pokedex/pokeicon/{pid}.png'] = icon
        outputs[f'pokedex/pokeiconshiny/{pid}s.png'] = icon
        follower_p = find_image(sources, mon['code'], '_3')
        if follower_p:
            sheet_f = follower_sheet(Image.open(follower_p), args.follower_inverse)
            outputs[f'characters/{pid}.png'] = sheet_f
            outputs[f'characters/{pid}s.png'] = sheet_f
        if args.images_seulement:
            print(f'~ {name} (id {sp_id}) : images refaites (x{scale})' + (' + follower' if follower_p else ''))
            if not args.dry_run:
                for rel, img in outputs.items():
                    (pk / rel).parent.mkdir(parents=True, exist_ok=True)
                    img.save(pk / rel)
                if follower_p and existing.exists():
                    sp = json.loads(existing.read_text(encoding='utf-8'))
                    res = sp['forms'][0]['resources']
                    if not res.get('character'):
                        res['character'], res['characterShiny'] = pid, pid + 's'
                        write_json(existing, sp)
            done.append(symbol)
            continue
        data = build_species(mon, sp_id, symbol, project, args, species, overrides)
        if follower_p:
            data['forms'][0]['resources'].update({'character': pid, 'characterShiny': pid + 's'})
        else:
            print(f'  (pas de follower : ajoute {mon["code"]}_3 ou « {mon["code"]} (3) » pour en avoir un)')
        category = (mon['category'] or '').replace(' Mon', ' Pokémon') or '??? Pokémon'
        print(f'+ {name} -> id {sp_id}, {symbol}  (types {"/".join(mon["types"])}, PV {mon["stats"]["baseHp"]}, '
              f'{len(mon["moves"]["level"])} capacités par niveau, sprites x{scale})')
        if not args.dry_run:
            for rel, img in outputs.items():
                (pk / rel).parent.mkdir(parents=True, exist_ok=True)
                img.save(pk / rel)
            write_json(project / 'Data/Studio/pokemon' / f'{symbol}.json', data)
            set_text_rows(project, sp_id, (name, category, mon['flavor'] or '...'), False)
        else:
            set_text_rows(project, sp_id, (name, category, mon['flavor'] or '...'), True)
        form_row = (known or {}).get('form_name_row') or next_text_row(project, 100067)      # nom de la forme de base (Studio l'affiche)
        data['forms'][0]['formTextId']['name'] = form_row
        if not args.dry_run:
            write_json(project / 'Data/Studio/pokemon' / f'{symbol}.json', data)
        set_text_rows(project, form_row, (form_label or name,), args.dry_run, (100067,))
        species.add(symbol)
        state[symbol] = {'id': sp_id, 'form_name_row': form_row, 'code': mon['code'], 'name': name, 'form_label': form_label, 'full_name': full_name, 'chain': mon['chain'], 'evolutions': mon['evolutions'],
                         'owner': mon['owner'], 'designer': mon['designer'], 'permission': mon['permission'], 'notes': mon['notes']}
        done.append(symbol)
        if args.dex.lower() not in ('aucun', 'none') and not args.dry_run:
            dex_path = project / 'Data/Studio/dex' / f'{args.dex}.json'
            if dex_path.exists():
                dex = json.loads(dex_path.read_text(encoding='utf-8'))
                if not any(c['dbSymbol'] == symbol for c in dex['creatures']):
                    dex['creatures'].append({'dbSymbol': symbol, 'form': 0})
                    write_json(dex_path, dex)
            else:
                warn(name, f'dex « {args.dex} » introuvable : non ajouté')

    # Pokémon importés avant que le nom de forme soit créé : on le crée (formTextId.name valait 0 = « Bulbizarre »)
    if not args.images_seulement:
        for symbol, entry in state.items():
            path = project / 'Data/Studio/pokemon' / f'{symbol}.json'
            if not path.exists():
                continue
            data = json.loads(path.read_text(encoding='utf-8'))
            ftid = data['forms'][0].get('formTextId', {})
            if ftid.get('name', 0) == 0:
                row = entry.get('form_name_row') or next_text_row(project, 100067)
                print(f'~ {entry["name"]} : nom de forme créé (ligne {row} de 100067)')
                ftid['name'] = row
                data['forms'][0]['formTextId'] = ftid
                entry['form_name_row'] = row
                if not args.dry_run:
                    write_json(path, data)
                set_text_rows(project, row, (entry.get('form_label') or entry['name'],), args.dry_run, (100067,))
                done.append(symbol)

    # évolutions : on relie celles dont les deux Pokémon existent (même s'ils viennent d'imports différents)
    for symbol, entry in state.items():
        if not (project / 'Data/Studio/pokemon' / f'{symbol}.json').exists():
            continue
        for src, target, level in entry.get('evolutions', []):
            if src != symbol:
                continue
            if target in species:
                if add_evolution(project, state, symbol, target, level, args.dry_run):
                    print(f'  évolution : {symbol} -> {target} au niveau {level}')
            else:
                warn(entry['name'], f"évolution vers « {target} » (niv. {level}) en attente : importe aussi sa fiche puis relance")
    if done and not args.dry_run:
        state_file.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding='utf-8')
        lines = ['# Crédits des créatures importées de Pokéngine', '',
                 'Créatures « free to use » : respecte la permission indiquée pour chacune (souvent un crédit demandé).', '']
        for symbol, e in sorted(state.items(), key=lambda kv: kv[1]['id']):
            lines.append(f"- **{e['name']}** (id {e['id']}, code Pokéngine {e['code']}) — propriétaire : {e.get('owner') or '?'} ; "
                         f"permission : {e.get('permission') or '?'}" + (f" ; {e['notes']}" if e.get('notes') else ''))
        (HERE / 'CREDITS_POKENGINE.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print()
    if WARNINGS:
        print('À vérifier :')
        for w in WARNINGS:
            print('  -', w)
    print(f"\n{'[essai, rien écrit] ' if args.dry_run else ''}{len(done)} créature(s) importée(s)."
          + (" Rouvre Studio : il régénère ses fichiers de textes au prochain lancement." if done and not args.dry_run else ''))


if __name__ == '__main__':
    main()

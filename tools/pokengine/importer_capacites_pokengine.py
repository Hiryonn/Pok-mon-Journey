#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Importe des capacités « free to use » de Pokéngine (fiche imprimée en PDF ou .txt) dans le projet Pokémon Studio / PSDK.

Écrit :
  - Data/Studio/moves/<symbole>.json   (type, catégorie, puissance, précision, PP, contact, cible, effets devinés)
  - Data/Text/Dialogs/100006.csv (nom) et 100007.csv (description) ; anglais dans toutes les langues
  - tools/pokengine/capacites_importees.json (mémoire) et CREDITS_POKENGINE.md (auteur, permission)
Les effets (hausse/baisse de stats, statut, chance) sont DEVINÉS depuis le texte de la fiche : le script le dit et tu dois
les vérifier dans Studio. `overrides_capacites.json` (dans le dossier des fiches) corrige n'importe quel champ :
  {"07nonuuq": {"battleEngineAimedTarget": "adjacent_foe", "priority": 1}}
L'animation n'est pas importée.

Usage : python3 importer_capacites_pokengine.py <dossier des fiches> <dossier du projet> [--start-id N] [--force] [--dry-run]
"""
import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import importer_pokengine as pe      # noqa: E402  (lecture de fiche, textes CSV, JSON : mêmes outils que pour les Pokémon)

FIRST_ID = 10000
MOVE_TEXT_FILES = (100006, 100007)       # noms, descriptions
STATS = [('special attack', 'ATS_STAGE'), ('special defense', 'DFS_STAGE'), ('sp. atk', 'ATS_STAGE'), ('sp. def', 'DFS_STAGE'),
         ('attack', 'ATK_STAGE'), ('defense', 'DFE_STAGE'), ('speed', 'SPD_STAGE'), ('accuracy', 'ACC_STAGE'),
         ('evasiveness', 'EVA_STAGE'), ('evasion', 'EVA_STAGE')]
STATUSES = [('badly poison', 'TOXIC'), ('poison', 'POISONED'), ('burn', 'BURN'), ('paraly', 'PARALYZED'), ('freez', 'FROZEN'),
            ('frozen', 'FROZEN'), ('sleep', 'ASLEEP'), ('asleep', 'ASLEEP'), ('confus', 'CONFUSED'), ('flinch', 'FLINCH')]
TARGETS = [                                    # (mots du texte de cible, battleEngineAimedTarget) ; le premier qui correspond gagne
    (('but the user',), 'any_other_pokemon'), (('random foe', 'random opponent'), 'random_foe'),
    (('all foes', 'every foe', 'all opposing', 'both foes'), 'adjacent_all_foe'), (('all allies',), 'all_ally'),
    (('everyone', 'every mon', 'all mons', 'all pokémon', 'all pokemon'), 'all_pokemon'),
    (('one foe', 'a foe', 'single foe', 'adjacent foe'), 'adjacent_foe'), (('the user only', 'only the user', 'affects the user'), 'user'),
    (('ally',), 'adjacent_ally'),
]


def parse_move(text, types):
    lines = [l.rstrip() for l in text.splitlines()]
    flat = '\n'.join(lines)

    def find(label):
        m = re.search(rf'^[ \t]*{label}[ \t]+(.+?)[ \t]*$', flat, re.M | re.I)
        return m.group(1).strip() if m else None

    # le titre de la capacité est « #N Nom (code) » ; « HUB Collection (code) » plus haut est la collection, pas la capacité
    title = re.search(r'^[ \t]*#\d+[ \t]+([^\n(]+?)[ \t]+\(([a-z0-9]{6,12})\)[ \t]*$', flat, re.M) \
        or re.search(r'^[ \t]*([^\n(]+?)[ \t]+\(([a-z0-9]{6,12})\)[ \t]*$', flat, re.M)
    if not title:
        raise ValueError("titre introuvable (je cherche « Nom (code) »)")
    name, code = title.group(1).strip(), title.group(2)
    head = re.search(r'^[ \t]*(?:\d+[ \t]+)?([A-Za-z]+)[ \t]+(Physical|Special|Status)[ \t]*$', flat[title.end():], re.M)
    if not head:
        raise ValueError("type et catégorie introuvables (ex. « Steel   Physical »)")
    mtype, category = head.group(1).lower(), head.group(2).lower()
    if mtype not in types:
        raise ValueError(f"type « {mtype} » inconnu dans le projet")

    def number(label, default):
        v = find(label)
        m = re.match(r'\d+', v or '')
        return int(m.group()) if m else default

    flavor = ''
    m = re.search(r'^[ \t]*Flavor[ \t]*\n(.*?)(?=^[ \t]*(?:Notes|Check out|This Move)\b)', flat, re.M | re.S)
    if m:
        flavor = ' '.join(l.strip() for l in m.group(1).splitlines() if l.strip())
    target_txt = ''
    m = re.search(r'Editor(.*?)^[ \t]*Flavor', flat, re.M | re.S)
    if m:
        keep = [l.strip() for l in m.group(1).splitlines() if l.strip() and not re.fullmatch(r'(?:(?:Foe|User|Ally)\s*)+', l.strip())]
        target_txt = ' '.join(keep)
    notes = ''
    m = re.search(r'^[ \t]*Notes[ \t]*\n(.*?)(?=^[ \t]*Check out)', flat, re.M | re.S)
    if m:
        notes = ' '.join(l.strip() for l in m.group(1).splitlines() if l.strip())
    return {
        'name': name, 'code': code, 'type': mtype, 'category': category, 'pp': number('PP', 10), 'power': number('Power', 0),
        'accuracy': number('Accuracy', 0), 'contact': (find('Contact') or '').lower().startswith('y'),
        'copyable': (find('Copyable') or 'yes').lower().startswith('y'), 'classification': find('Classification'),
        'target_text': target_txt, 'flavor': flavor, 'owner': find('Owner'), 'permission': find('Permission'), 'notes': notes,
    }


def guess_effects(mv):
    """Devine hausses/baisses de stats, statuts, chance et cible du texte. Renvoie (stage_mods, statuses, chance, target, user_side, notes)."""
    text = mv['flavor']
    low = text.lower()
    notes = []
    stages, user_side = [], False
    for sentence in re.split(r'(?<=[.!])\s+', low):
        m = re.search(r'\b(sharply|greatly|drastically|harshly|severely)?\s*(raises?|boosts?|increases?|lowers?|reduces?|decreases?|drops?|cuts?)\b'
                      r'(?:\s+(sharply|greatly|drastically|harshly|severely))?\s+(.*)', sentence)
        if not m:
            continue
        verb, rest = m.group(2), m.group(4)
        adverb = m.group(1) or m.group(3) or ''
        amount = 3 if adverb == 'drastically' else 2 if adverb else 1
        sign = 1 if re.match(r'rais|boost|increas', verb) else -1
        owner = re.match(r"(?:the\s+)?(user'?s?|its|their|target'?s?|foe'?s?|opponent'?s?)\b", rest)
        self_side = (sign == 1 and not (owner and re.match(r'target|foe|opponent', owner.group(1)))) or \
                    bool(owner and re.match(r'user|its', owner.group(1)))
        found = []
        for word, stage in STATS:
            for sm in re.finditer(r'\b' + re.escape(word) + r'\b', rest):
                if stage not in [f[0] for f in found] and not (word in ('attack', 'defense') and rest[max(0, sm.start() - 8):sm.start()].endswith('special ')):
                    found.append((stage, sm.start()))
        for stage, _ in sorted(found, key=lambda f: f[1]):
            stages.append((stage, sign * amount, self_side))
    status = []
    for word, st in STATUSES:
        if re.search(r'\b(may|can|will|might)?\b[^.]*\b' + word, low) and st not in [s for s in status]:
            if st == 'POISONED' and 'TOXIC' in status:
                continue
            if word == 'poison' and 'badly poison' in low:
                continue
            status.append(st)
    chance = 100
    pm = re.search(r'(\d+)\s*%', low)
    if pm:
        chance = int(pm.group(1))
    elif re.search(r'\b(may|sometimes|occasionally|might)\b', low):
        chance = 30
        notes.append('chance de l\'effet devinée à 30 % (le texte dit « may »)')
    tt = mv['target_text'].lower()
    target = None
    for words, value in TARGETS:
        if any(w in tt for w in words):
            target = value
            break
    if target is None:
        target = 'adjacent_pokemon'
        notes.append(f'cible non reconnue (« {mv["target_text"][:50]} ») : adjacent_pokemon par défaut')
    return stages, status, chance, target, notes


def build_move(mv, move_id, symbol):
    stages, statuses, chance, target, notes = guess_effects(mv)
    mods = [{'battleStage': s, 'modificator': a} for s, a, own in stages]
    self_stats = [x for x in stages if x[2]]
    foe_stats = [x for x in stages if not x[2]]
    damaging = mv['category'] != 'status'
    method = 's_basic'
    if self_stats and not foe_stats:
        method = 's_self_stat' if damaging else 's_stat'
        if not damaging:
            target = 'user'
    elif foe_stats and not damaging:
        method = 's_stat'
    elif statuses and not damaging and not mods:
        method = 's_status'
    status_list = [{'status': s, 'luckRate': chance} for s in statuses[:1 if len(statuses) > 1 else 1]]
    if mods or status_list:
        notes.append('effet deviné depuis le texte : ' + ', '.join(
            [f'{"toi" if o else "cible"} {s[:3]} {a:+d}' for s, a, o in stages] + [f'statut {x["status"]}' for x in status_list]) + f' ({chance} %)')
    else:
        notes.append("aucun effet reconnu dans le texte : capacité « simple » (à compléter dans Studio si elle a un effet)")
    move = {
        'klass': 'Move', 'id': move_id, 'dbSymbol': symbol, 'mapUse': 0, 'battleEngineMethod': method, 'type': mv['type'],
        'power': mv['power'], 'accuracy': mv['accuracy'], 'pp': mv['pp'], 'category': mv['category'], 'movecriticalRate': 1, 'priority': 0,
        'isAuthentic': False, 'isBallistics': False, 'isBite': False, 'isBlocable': True, 'isCharge': False, 'isDance': False,
        'isDirect': mv['contact'], 'isEffectChance': False, 'isGravity': False, 'isHeal': False, 'isKingRockUtility': damaging,
        'isMagicCoatAffected': False, 'isMental': False, 'isMirrorMove': mv['copyable'], 'isNonSkyBattle': False, 'isPowder': False,
        'isPulse': False, 'isPunch': False, 'isRecharge': False, 'isSnatchable': False, 'isSoundAttack': False, 'isSlicingAttack': False,
        'isUnfreeze': False, 'isWind': False, 'battleEngineAimedTarget': target, 'battleStageMod': mods, 'moveStatus': status_list,
        'effectChance': chance if (mods or status_list) else 0, 'condition': 'tough', 'appeal': 4, 'jam': 0, 'comboMoves': [], 'effectTags': [],
    }
    return move, notes


def next_free_id(project):
    ids = []
    for f in (project / 'Data/Studio/moves').glob('*.json'):
        try:
            ids.append(json.loads(f.read_text(encoding='utf-8'))['id'])
        except (ValueError, KeyError):
            pass
    return max([i for i in ids if i >= FIRST_ID], default=FIRST_ID - 1) + 1


def main():
    ap = argparse.ArgumentParser(description='Importe des capacités Pokéngine (fiche PDF) dans le projet.')
    ap.add_argument('sources')
    ap.add_argument('project')
    ap.add_argument('--start-id', type=int, help='numéro de la première capacité (défaut : 10000, puis le suivant libre)')
    ap.add_argument('--force', action='store_true', help='réécrire une capacité déjà importée')
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()
    sources, project = Path(args.sources), Path(args.project)
    if not (project / 'Data/Studio/moves').exists():
        sys.exit(f"{project} n'est pas un projet Studio (Data/Studio/moves introuvable).")
    types = pe.stems(project / 'Data/Studio/types')
    moves = pe.stems(project / 'Data/Studio/moves')
    state_file = HERE / 'capacites_importees.json'
    state = json.loads(state_file.read_text(encoding='utf-8')) if state_file.exists() else {}
    ov_file = sources / 'overrides_capacites.json'
    overrides = json.loads(ov_file.read_text(encoding='utf-8')) if ov_file.exists() else {}
    sheets = sorted(p for p in sources.iterdir() if p.suffix.lower() in ('.pdf', '.txt'))
    if not sheets:
        sys.exit('Aucune fiche (.pdf ou .txt) dans ' + str(sources))
    next_id = args.start_id or next_free_id(project)
    done, skipped = [], 0
    for sheet in sheets:
        try:
            mv = parse_move(pe.read_sheet(sheet), types)
        except Exception as e:      # noqa: BLE001
            print(f'= {sheet.name} : pas une fiche de capacité ({e}) : ignorée')
            skipped += 1
            continue
        name = mv['name']
        symbol = pe.slug(name)
        known = state.get(symbol)
        path = project / 'Data/Studio/moves' / f'{symbol}.json'
        if known and path.exists() and not args.force:
            print(f'= {name} déjà importée (id {known["id"]}) : ignorée (--force pour la refaire)')
            continue
        if symbol in moves and not known:
            print(f'! {name} : une capacité « {symbol} » existe déjà dans le projet : ignorée')
            continue
        if known and not path.exists():
            print(f'~ {name} : importée avant, mais son JSON a été supprimé : je la refais (id {known["id"]})')
        move_id = known['id'] if known else next_id
        if not known:
            next_id += 1
        move, notes = build_move(mv, move_id, symbol)
        move.update(overrides.get(symbol, overrides.get(mv['code'], {})))
        print(f'+ {name} -> id {move_id}, {symbol}  ({mv["type"]}, {mv["category"]}, puissance {mv["power"]}, précision {mv["accuracy"]}, PP {mv["pp"]}, '
              f'cible {move["battleEngineAimedTarget"]})')
        for n in notes:
            pe.warn(name, n)
        if not args.dry_run:
            pe.write_json(path, move)
        pe.set_text_rows(project, move_id, (name, mv['flavor'] or '...'), args.dry_run, MOVE_TEXT_FILES)
        moves.add(symbol)
        state[symbol] = {'id': move_id, 'code': mv['code'], 'name': name, 'owner': mv['owner'], 'permission': mv['permission'], 'notes': mv['notes']}
        done.append(symbol)
    if done and not args.dry_run:
        state_file.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding='utf-8')
        credits = HERE / 'CREDITS_POKENGINE.md'
        text = credits.read_text(encoding='utf-8') if credits.exists() else '# Crédits des créatures importées de Pokéngine\n\n'
        for symbol, e in state.items():
            if f'capacité {e["name"]} (code Pokéngine {e["code"]})' not in text:
                text += (f"- **{e['name']}** (capacité {e['name']} (code Pokéngine {e['code']})) — propriétaire : {e.get('owner') or '?'} ; "
                         f"permission : {e.get('permission') or '?'}" + (f" ; {e['notes']}" if e.get('notes') else '') + '\n')
        credits.write_text(text, encoding='utf-8')
    print()
    if pe.WARNINGS:
        print('À vérifier :')
        for w in pe.WARNINGS:
            print('  -', w)
    print(f"\n{'[essai, rien écrit] ' if args.dry_run else ''}{len(done)} capacité(s) importée(s)."
          + (" Rouvre Studio : il régénère ses fichiers de textes au prochain lancement." if done and not args.dry_run else ''))


if __name__ == '__main__':
    main()

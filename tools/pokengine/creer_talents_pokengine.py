#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Crée dans la base de données les TALENTS Pokéngine des collections HUB et Uranium (liste dans talents_pokengine.py).
  - Data/Studio/abilities/<symbole>.json (id suivant libre) ;
  - nom et description dans Data/Text/Dialogs/100004.csv et 100005.csv (anglais dans toutes les langues : traduis ensuite avec l'outil de traduction) ;
  - une ligne de crédit dans CREDITS_POKENGINE.md.
Les talents déjà présents dans le projet sont ignorés. Relançable. Les EFFETS sont dans le plugin extra_abilities_additions.
Usage : python3 creer_talents_pokengine.py <dossier du projet> [--essai]"""
import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import importer_pokengine as pe      # noqa: E402
from talents_pokengine import TALENTS  # noqa: E402

TEXT_FILES = (100004, 100005)       # noms, descriptions


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('project')
    ap.add_argument('--essai', action='store_true', help="n'écrit rien")
    args = ap.parse_args()
    project, dry = Path(args.project), args.essai
    folder = project / 'Data/Studio/abilities'
    if not folder.exists():
        sys.exit(f"{project} n'est pas un projet Studio (Data/Studio/abilities introuvable).")
    existing = {}
    for p in folder.glob('*.json'):
        try:
            d = json.loads(p.read_text(encoding='utf-8'))
            existing[d['dbSymbol']] = d['id']
        except (ValueError, KeyError):
            pass
    next_id = max(existing.values(), default=0) + 1
    made = []
    for name, desc, code, collection in TALENTS:
        symbol = pe.slug(name)
        if symbol in existing:
            print(f'= {name} : déjà dans le projet ({symbol}, id {existing[symbol]})')
            continue
        print(f'+ {name} -> id {next_id}, {symbol}')
        if not dry:
            pe.write_json(folder / f'{symbol}.json', {'klass': 'Ability', 'id': next_id, 'dbSymbol': symbol, 'textId': next_id})
        pe.set_text_rows(project, next_id, (name, desc), dry, TEXT_FILES)
        existing[symbol] = next_id
        made.append((name, code, collection))
        next_id += 1
    if made and not dry:
        credits = HERE / 'CREDITS_POKENGINE.md'
        text = credits.read_text(encoding='utf-8') if credits.exists() else '# Crédits des créatures importées de Pokéngine\n\n'
        for name, code, collection in made:
            line = f'talent {name} (code Pokéngine {code})'
            if line not in text:
                text += f'- **{name}** ({line}) — collection : {collection}\n'
        credits.write_text(text, encoding='utf-8')
    print(f"\n{'[essai, rien écrit] ' if dry else ''}{len(made)} talent(s) créé(s)."
          + (' Rouvre Studio : il régénère ses fichiers de textes au prochain lancement.' if made and not dry else ''))


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Écrit resume_capacites.md : toutes les capacités ajoutées (id >= 10000) avec ce que le projet contient vraiment
(fonction, puissance, stats, statuts, chances, description anglaise). À envoyer à Claude pour vérifier les effets.
Usage : python3 resume_capacites.py <dossier du projet>"""
import csv
import json
import sys
from pathlib import Path


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    project = Path(sys.argv[1])
    texts = {}
    for n, key in ((100006, 'name'), (100007, 'desc')):
        p = project / f'Data/Text/Dialogs/{n}.csv'
        if p.exists():
            with open(p, encoding='utf-8-sig', newline='') as f:
                rows = list(csv.reader(f))
            for i, row in enumerate(rows[1:]):
                texts[(key, i)] = row[0] if row else ''
    moves = []
    for p in (project / 'Data/Studio/moves').glob('*.json'):
        d = json.loads(p.read_text(encoding='utf-8'))
        if d.get('id', 0) >= 10000:
            moves.append(d)
    moves.sort(key=lambda d: d['id'])
    out = [f'# Capacités ajoutées ({len(moves)})\n']
    for d in moves:
        flags = [k for k in ('isDirect', 'isMirrorMove', 'isSnatchable', 'isBlocable', 'isSoundAttack', 'isPunch', 'isBite', 'isPulse', 'isWind') if d.get(k)]
        out.append(f"## {texts.get(('name', d['id']), d['dbSymbol'])} — `{d['dbSymbol']}` (#{d['id']})\n"
                   f"- {d['type']} / {d['category']} ; puissance {d['power']}, précision {d['accuracy']}, PP {d['pp']}, priorité {d['priority']}, critique {d.get('movecriticalRate')}\n"
                   f"- fonction : `{d['battleEngineMethod']}` ; cible : {d['battleEngineAimedTarget']} ; chance de l'effet : {d.get('effectChance')}\n"
                   f"- stats : {d['battleStageMod']} ; statuts : {d['moveStatus']} ; drapeaux : {', '.join(flags) or '-'}\n"
                   f"- description : {texts.get(('desc', d['id']), '').strip()}\n")
    (Path(__file__).resolve().parent / 'resume_capacites.md').write_text('\n'.join(out), encoding='utf-8')
    print(f'{len(moves)} capacité(s) écrites dans tools/pokengine/resume_capacites.md')


if __name__ == '__main__':
    main()

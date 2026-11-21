#!/usr/bin/env python3
"""Pour chaque Pokémon et chaque forme : les capacités de l'onglet « Technique » (TechLearnableMove) qui n'ont
PAS de vrai objet CT/CS/DT (aucun TechItem dans Data/Studio/items pour cette capacité) passent dans
« Maître des capacités » (TutorLearnableMove). Les vraies CT restent dans « Technique ».
Par défaut la ligne est déplacée (retirée de Technique) ; « --copier » la laisse aussi dans Technique.
Par défaut, « Maître des capacités » n'est PAS vidé : on y ajoute seulement ce qui manque.
« --vider » le vide d'abord pour chaque forme qui a des capacités à y mettre ; « --vider-tout » le vide pour toutes les formes.
Usage : ct_vers_maitre.py <dossier du projet> [--essai] [--copier] [--vider] [--vider-tout]"""
import json, sys
from pathlib import Path


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    essai = '--essai' in sys.argv
    copier = '--copier' in sys.argv
    vider_tout = '--vider-tout' in sys.argv
    vider = vider_tout or '--vider' in sys.argv
    project = Path(args[0] if args else '.').resolve()
    folder = project / 'Data/Studio/pokemon'
    if not folder.is_dir() or not (project / 'Data/Studio/items').is_dir():
        print(f'ERREUR : Data/Studio/pokemon ou Data/Studio/items introuvable dans {project}')
        return 1
    real = set()
    for it in (project / 'Data/Studio/items').glob('*.json'):
        d = json.loads(it.read_text(encoding='utf-8'))
        if d.get('klass') == 'TechItem':
            real.add(d['move'])
    print(f'{len(real)} capacités ont un vrai objet CT/CS : elles restent dans Technique.')
    files = changed = moved = 0
    for f in sorted(folder.glob('*.json')):
        raw = f.read_bytes().decode('utf-8')
        data = json.loads(raw)
        n = 0
        for form in data.get('forms', []):
            moves = form.get('moveSet', [])
            fake = [m for m in moves if m.get('klass') == 'TechLearnableMove' and m['move'] not in real]
            if not fake and not (vider_tout and any(m.get('klass') == 'TutorLearnableMove' for m in moves)):
                continue
            cleared = 0
            if vider:
                before = len(moves)
                moves[:] = [m for m in moves if m.get('klass') != 'TutorLearnableMove']
                cleared = before - len(moves)
            have = {m['move'] for m in moves if m.get('klass') == 'TutorLearnableMove'}
            new = []
            for m in fake:
                if m['move'] not in have:
                    have.add(m['move'])
                    new.append({'move': m['move'], 'klass': 'TutorLearnableMove'})
            if not copier:
                moves[:] = [m for m in moves if not any(m is x for x in fake)]
            last = max((i for i, m in enumerate(moves) if m.get('klass') == 'TutorLearnableMove'), default=len(moves) - 1)
            moves[last + 1:last + 1] = new
            n += len(fake) + cleared
        files += 1
        if not n:
            continue
        out = json.dumps(data, indent=2, ensure_ascii=False)
        if raw.endswith('\n'):
            out += '\n'
        if '\r\n' in raw:
            out = out.replace('\n', '\r\n')
        if not essai:
            f.write_bytes(out.encode('utf-8'))
        changed += 1
        moved += n
        print(f'+ {f.stem} : {n} modification(s)')
    print()
    print(f'{files} Pokémon vérifiés, {changed} modifié(s), {moved} modification(s)' + (' (essai : rien écrit)' if essai else ''))
    return 0


sys.exit(main())

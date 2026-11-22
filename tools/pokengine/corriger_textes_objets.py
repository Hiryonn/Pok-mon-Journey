#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Ajoute les textes (nom + description) des objets créés par les plugins, quand ils manquent
(Studio affiche « Unable to find text N in dialog file 100012 »). Écrit dans Data/Text/Dialogs/100012.csv (noms) et 100013.csv (descriptions).
Pour un nouvel objet de plugin : ajoute une ligne à TEXTES ci-dessous (symbole : (nom EN, nom FR, description EN, description FR)).
Les autres objets sans texte sont seulement signalés. Relançable. Usage : python3 corriger_textes_objets.py <projet> [--essai]"""
import csv
import io
import json
import sys
from pathlib import Path

TEXTES = {
    'allure_mulch': ('Allure Mulch', 'Paillis Attrait',
                     'A special mulch spread over the soil of a Berry pot to make it more attractive.',
                     'Un paillis spécial à étaler sur la terre d’un pot à baies pour la rendre plus attrayante.'),
    'raid_bait': ('Raid Bait', 'Appât Raid',
                  'A lure thrown into an empty Raid den. It attracts a new Pokémon there.',
                  'Un appât à jeter dans un antre de raid vide pour y attirer un nouveau Pokémon.'),
    'pokeblock_case': ('Pokéblock Case', 'Boîte Pokébloc',
                       'A case that holds Pokéblocks. Open it to see the Pokéblocks you have collected.',
                       'Une boîte pour ranger les Pokéblocs. Ouvre-la pour voir ceux que tu as récoltés.'),
    'snag_ball': ('Snag Ball', 'Ball Chipeuse',
                  'A special Ball that can catch the Shadow Pokémon of other Trainers.',
                  'Une Ball spéciale capable de capturer les Pokémon Obscurs des autres dresseurs.'),
}
NAMES, DESCS = 100012, 100013
COLS = 7        # en, fr, it, de, es, ko, kana


def read(path):
    raw = path.read_bytes().decode('utf-8')
    return raw, list(csv.reader(io.StringIO(raw, newline='')))


def write(path, rows, raw):
    eol = '\r\n' if '\r\n' in raw else '\n'
    buf = io.StringIO(newline='')
    csv.writer(buf, lineterminator=eol).writerows(rows)
    path.write_bytes(buf.getvalue().encode('utf-8'))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if not args:
        sys.exit(__doc__)
    dry = '--essai' in sys.argv
    project = Path(args[0])
    files = {}
    for fid in (NAMES, DESCS):
        path = project / 'Data/Text/Dialogs' / f'{fid}.csv'
        raw, rows = read(path)
        files[fid] = (path, raw, rows)
    changed = False
    for p in sorted((project / 'Data/Studio/items').glob('*.json')):
        item = json.loads(p.read_text(encoding='utf-8'))
        tid = item.get('textId', item['id'])
        for fid in (NAMES, DESCS):
            rows = files[fid][2]
            if tid < len(rows) - 1 and rows[1 + tid] and rows[1 + tid][0].strip():
                continue
            symbol = item['dbSymbol']
            if symbol not in TEXTES:
                print(f'  ! {symbol} (texte {tid}, fichier {fid}) : pas de texte connu, à écrire dans Studio')
                continue
            en_n, fr_n, en_d, fr_d = TEXTES[symbol]
            en, fr = (en_n, fr_n) if fid == NAMES else (en_d, fr_d)
            while len(rows) - 1 < tid:
                rows.append([''] * COLS)
            new = [en, fr] + [en] * (COLS - 2)
            if tid == len(rows) - 1:
                rows.append(new)
            else:
                rows[1 + tid] = new
            print(f'  + {symbol} : {"nom" if fid == NAMES else "description"} -> « {en[:40]} »')
            changed = True
    if changed and not dry:
        for path, raw, rows in files.values():
            write(path, rows, raw)
    print('[essai, rien écrit]' if dry else ('Textes ajoutés.' if changed else 'Rien à ajouter.'))


if __name__ == '__main__':
    main()

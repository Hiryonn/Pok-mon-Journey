# Thème rouge (Pokéball) pour Pokémon Studio : remplace le bleu-violet de Studio par du rouge.
# Usage : python theme_rouge.py "<dossier de Studio>\resources\app\.vite\renderer\main_window"
# (à relancer après une mise à jour de Studio ; une copie .bak-rouge est gardée la première fois)
import glob
import os
import shutil
import sys

REPLACEMENTS = [
    # couleurs principales de Studio (boutons, onglets, sélection, interrupteurs…)
    ('rgba(101, 98, 248, 1)', 'rgba(222, 44, 44, 1)'),
    ('rgba(111, 109, 248, 1)', 'rgba(236, 72, 72, 1)'),
    ('rgba(101, 98, 248, 0.12)', 'rgba(222, 44, 44, 0.12)'),
    ('rgba(111, 116, 246, 0.16)', 'rgba(236, 72, 72, 0.16)'),
    ('rgba(101, 98, 248, 0.35)', 'rgba(222, 44, 44, 0.35)'),
    # logo et icônes
    ('#6562F8', '#DE2C2C'),
    # listes déroulantes
    ('primary:`#2684FF`,primary75:`#4C9AFF`,primary50:`#B2D4FF`,primary25:`#DEEBFF`',
     'primary:`#DE2C2C`,primary75:`#E5585A`,primary50:`#F2A6A8`,primary25:`#FBDEDF`'),
    # éditeur d'évènements
    ('--pje-accent: #7d6ff5;', '--pje-accent: #de2c2c;'),
    ('--pje-accent-2: #5e50db;', '--pje-accent-2: #b51f1f;'),
    ('rgba(125,111,245,', 'rgba(222,44,44,'),
    ('#e5e1ff', '#ffe1e1'),
    # sélection des graphes
    ('#0059dc', '#de2c2c'),
]


def main(root):
    files = glob.glob(os.path.join(root, 'assets', 'index-*.js')) + glob.glob(os.path.join(root, 'assets', 'index-*.css'))
    files += glob.glob(os.path.join(root, 'pj-*', '*.css')) + glob.glob(os.path.join(root, 'pj-*', '*.js'))
    for path in files:
        if path.endswith('.bak-rouge'):
            continue
        with open(path, encoding='utf-8') as f:
            text = f.read()
        new = text
        for old, rep in REPLACEMENTS:
            new = new.replace(old, rep)
        if new != text:
            if not os.path.exists(path + '.bak-rouge'):
                shutil.copyfile(path, path + '.bak-rouge')
            with open(path, 'w', encoding='utf-8', newline='') as f:
                f.write(new)
            print('rouge :', os.path.relpath(path, root))


if __name__ == '__main__':
    main(sys.argv[1])

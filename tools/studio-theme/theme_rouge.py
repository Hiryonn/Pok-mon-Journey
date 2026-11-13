# Thème rouge (Pokéball) pour Pokémon Studio : remplace le bleu-violet de Studio par du rouge foncé
# et renomme l'interface en « Pokémon Studio Extra ».
# Usage : python theme_rouge.py "<dossier de Studio>\resources\app\.vite\renderer\main_window"
# (à relancer après une mise à jour de Studio ; une copie .bak-rouge est gardée la première fois)
import glob
import os
import shutil
import sys

REPLACEMENTS = [
    # couleurs principales de Studio (boutons, onglets, sélection, interrupteurs…)
    ('rgba(101, 98, 248, 1)', 'rgba(184, 29, 36, 1)'),
    ('rgba(111, 109, 248, 1)', 'rgba(204, 46, 52, 1)'),
    ('rgba(101, 98, 248, 0.12)', 'rgba(184, 29, 36, 0.12)'),
    ('rgba(111, 116, 246, 0.16)', 'rgba(204, 46, 52, 0.16)'),
    ('rgba(101, 98, 248, 0.35)', 'rgba(184, 29, 36, 0.35)'),
    # logo et icônes
    ('#6562F8', '#B81D24'),
    # listes déroulantes
    ('primary:`#2684FF`,primary75:`#4C9AFF`,primary50:`#B2D4FF`,primary25:`#DEEBFF`',
     'primary:`#B81D24`,primary75:`#CC3A40`,primary50:`#EBA3A6`,primary25:`#F8DCDD`'),
    # éditeur d'évènements
    ('--pje-accent: #7d6ff5;', '--pje-accent: #b81d24;'),
    ('--pje-accent-2: #5e50db;', '--pje-accent-2: #921519;'),
    ('rgba(125,111,245,', 'rgba(184,29,36,'),
    ('#e5e1ff', '#ffe1e1'),
    # sélection des graphes
    ('#0059dc', '#b81d24'),
    # premier rouge (plus clair) -> rouge foncé
    ('rgba(222, 44, 44,', 'rgba(184, 29, 36,'),
    ('rgba(236, 72, 72,', 'rgba(204, 46, 52,'),
    ('--pje-accent: #de2c2c;', '--pje-accent: #b81d24;'),
    ('--pje-accent-2: #b51f1f;', '--pje-accent-2: #921519;'),
    ('rgba(222,44,44,', 'rgba(184,29,36,'),
    ('#DE2C2C', '#B81D24'),
    ('primary:`#DE2C2C`,primary75:`#E5585A`,primary50:`#F2A6A8`,primary25:`#FBDEDF`',
     'primary:`#B81D24`,primary75:`#CC3A40`,primary50:`#EBA3A6`,primary25:`#F8DCDD`'),
]

# Nom affiché : Pokémon Studio Extra (textes de l'interface et titre de la fenêtre ; le dossier des réglages ne change pas)
NAME = ('Pokémon Studio', 'Pokémon Studio Extra')


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
        if os.path.basename(path).startswith('index-') and path.endswith('.js') and NAME[1] not in new:
            new = new.replace(NAME[0], NAME[1])
        if new != text:
            if not os.path.exists(path + '.bak-rouge'):
                shutil.copyfile(path, path + '.bak-rouge')
            with open(path, 'w', encoding='utf-8', newline='') as f:
                f.write(new)
            print('rouge :', os.path.relpath(path, root))
    html = os.path.join(root, 'index.html')
    with open(html, encoding='utf-8') as f:
        text = f.read()
    new = text.replace('<title>Pokémon Studio</title>', '<title>Pokémon Studio Extra</title>')
    if new != text:
        with open(html, 'w', encoding='utf-8', newline='') as f:
            f.write(new)
        print('titre :', 'index.html')


if __name__ == '__main__':
    main(sys.argv[1])

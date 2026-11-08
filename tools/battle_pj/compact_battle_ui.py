# Interface de combat PE plus basse : bande du bas de 51 px (graphics/interface/battle_pj/command_panel.png)
# et boutons de 22 px de haut (au lieu de 28) pour que deux lignes tiennent dans la bande.
# Ne s'applique qu'une fois (les images déjà en 22 px sont laissées telles quelles).
# Usage : python tools/battle_pj/compact_battle_ui.py <image de la bande 320 x 51>
import os, sys
from PIL import Image
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
D = os.path.join(ROOT, 'graphics/interface/battle_pj')
OLD, NEW = 28, 22

def drop_rows(img, rows):
    """Retire des lignes de chaque bouton (feuille de boutons de 28 px)."""
    n = img.height // OLD
    out = Image.new('RGBA', (img.width, NEW * n), (0, 0, 0, 0))
    keep = [y for y in range(OLD) if y not in rows]
    assert len(keep) == NEW
    for i in range(n):
        for j, y in enumerate(keep):
            out.paste(img.crop((0, i * OLD + y, img.width, i * OLD + y + 1)), (0, i * NEW + j))
    return out

def convert(name, rows=None, resize=False):
    path = os.path.join(D, name)
    img = Image.open(path).convert('RGBA')
    if img.height % OLD or img.height % NEW == 0 and img.height % OLD != 0:
        print('déjà fait :', name); return
    if resize:   # images avec du dessin partout : réduction de l'intérieur
        n = img.height // OLD
        out = Image.new('RGBA', (img.width, NEW * n), (0, 0, 0, 0))
        for i in range(n):
            b = img.crop((0, i * OLD, img.width, (i + 1) * OLD))
            fr = drop_rows(b, set(range(11, 17)))                       # bord gardé
            fr.paste(b.crop((1, 1, img.width - 1, OLD - 1)).resize((img.width - 2, NEW - 2), Image.NEAREST), (1, 1))
            out.paste(fr, (0, i * NEW))
        img = out
    else:
        img = drop_rows(img, rows)
    img.save(path)
    print('converti :', name, img.size)

# Boutons unis (action, curseur) : 6 lignes retirées au milieu
convert('action_buttons.png', set(range(11, 17)))
convert('button_cursor.png', set(range(11, 17)))
# Boutons d'attaque : 4 lignes de la zone du nom + 2 lignes unies de la zone du bas (type / PP)
convert('move_buttons.png', {2, 3, 4, 5, 17, 26})
# Safari : dessin réduit
convert('safari_buttons.png', resize=True)

# Bande du bas + fond des messages de combat
if len(sys.argv) > 1:
    panel = Image.open(sys.argv[1]).convert('RGBA')
    panel.save(os.path.join(D, 'command_panel.png'))
    panel.crop((0, panel.height - 50, 320, panel.height)).save(os.path.join(ROOT, 'graphics/windowskins/battle_pj_message.png'))
    print('bande du bas :', panel.size)

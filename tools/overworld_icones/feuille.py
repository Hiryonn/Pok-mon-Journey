"""Convertit n'importe quelle image (icône 16x16, 24x24, 32x32…) en feuille de personnage 4x4 de cases 32x32 pour le plugin
Pokémon visibles (graphics/characters/<nom>.png). L'image est centrée dans chaque case, sans lissage (pixels nets).
  python3 feuille.py mon_icone_rouge.png ../../graphics/characters/ow_baron.png
  python3 feuille.py mon_icone_blanche.png ../../graphics/characters/ow_dominant.png
Option : --zoom 2 agrandit l'icône (entier) avant de la centrer."""
import sys
from PIL import Image

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    zoom = int(sys.argv[sys.argv.index('--zoom') + 1]) if '--zoom' in sys.argv else 1
    if '--zoom' in sys.argv:
        args.remove(str(zoom))
    if len(args) != 2:
        sys.exit(__doc__)
    icon = Image.open(args[0]).convert('RGBA')
    if zoom > 1:
        icon = icon.resize((icon.width * zoom, icon.height * zoom), Image.NEAREST)
    if icon.width > 32 or icon.height > 32:
        icon.thumbnail((32, 32), Image.LANCZOS)
    out = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
    for i in range(4):
        for j in range(4):
            out.paste(icon, (i * 32 + (32 - icon.width) // 2, j * 32 + (32 - icon.height) // 2), icon)
    out.save(args[1])

main()

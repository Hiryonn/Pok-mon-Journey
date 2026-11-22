"""Génère les icônes Baron (rouge) et Dominant (blanc) de graphics/characters : ow_baron.png / ow_dominant.png.
Feuille 4x4 de cases 32x32 (même icône partout, pas d'animation). python3 generer_icones.py [dossier de sortie]"""
import sys, os
from PIL import Image, ImageDraw

S = 8  # sur-échantillonnage

def glyph(fill, edge, glow):
    img = Image.new('RGBA', (32 * S, 32 * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = 16 * S
    # halo
    for r, a in ((15, 50), (13, 80)):
        d.ellipse([c - r * S, c - r * S, c + r * S, c + r * S], fill=glow + (a,))
    # losange à pointes (éclat) : quatre branches, la verticale plus longue
    pts = [(c, 2 * S), (c + 4 * S, c - 4 * S), (c + 13 * S, c), (c + 4 * S, c + 4 * S),
           (c, 30 * S), (c - 4 * S, c + 4 * S), (c - 13 * S, c), (c - 4 * S, c - 4 * S)]
    d.polygon(pts, fill=fill, outline=edge)
    d.line(pts + [pts[0]], fill=edge, width=int(1.6 * S), joint='curve')
    # œil central
    d.ellipse([c - 4 * S, c - 4 * S, c + 4 * S, c + 4 * S], fill=edge)
    d.ellipse([c - 2.2 * S, c - 2.2 * S, c + 2.2 * S, c + 2.2 * S], fill=fill)
    return img.resize((32, 32), Image.LANCZOS)

def sheet(icon):
    out = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
    for i in range(4):
        for j in range(4):
            out.paste(icon, (i * 32, j * 32))
    return out

if __name__ == '__main__':
    folder = sys.argv[1] if len(sys.argv) > 1 else '.'
    os.makedirs(folder, exist_ok=True)
    sheet(glyph((220, 40, 45, 255), (70, 8, 20, 255), (255, 70, 60))).save(os.path.join(folder, 'ow_baron.png'))
    sheet(glyph((255, 255, 255, 255), (60, 70, 90, 255), (200, 225, 255))).save(os.path.join(folder, 'ow_dominant.png'))

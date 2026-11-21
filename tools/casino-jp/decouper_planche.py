"""Découpe la planche du casino japonais (tools/casino-jp/planche/Casino_Slot.png) en images pour le plugin casino_jp.
Écrit graphics/interface/casino_jp/ : machine.png, grille.png, fond.png, fond_gain.png, s0..s4.png (symboles), n0..n9.png + nv.png (chiffres).
Les textes japonais de la machine sont effacés (le plugin écrit les textes lui-même, en français ou en anglais).
Utilisation : python tools/casino-jp/decouper_planche.py
"""
import os
from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
PLANCHE = os.path.join(ICI, 'planche', 'Casino_Slot.png')
SORTIE = os.path.join(ICI, '..', '..', 'graphics', 'interface', 'casino_jp')

BARRE = (41, 41, 41, 255)          # fond des barres sombres
VERT = {(198, 255, 41), (123, 165, 49)}   # vert des textes japonais
MACHINE = (15, 229, 272, 421)      # machine du bas (257x192)
# zones de la machine (coordonnées dans machine.png)
BARRE_HAUT = (0, 0, 257, 26)
BARRE_BAS = (2, 176, 255, 192)
CHIFFRES = {'credit': (82, 146, 122, 157), 'payout': (186, 146, 226, 157)}


def effacer_vert(img, zone):
    px = img.load()
    for y in range(zone[1], zone[3]):
        for x in range(zone[0], zone[2]):
            if px[x, y][:3] in VERT:
                px[x, y] = BARRE


def main():
    planche = Image.open(PLANCHE).convert('RGBA')
    os.makedirs(SORTIE, exist_ok=True)

    machine = planche.crop(MACHINE)
    effacer_vert(machine, BARRE_HAUT)
    effacer_vert(machine, BARRE_BAS)
    # chiffres éteints : la case est vidée, le plugin dessine les chiffres
    px = machine.load()
    for (x0, y0, x1, y1) in CHIFFRES.values():
        for y in range(y0 - 1, y1 + 1):
            for x in range(x0 - 1, x1 + 1):
                px[x, y] = BARRE
    machine.save(os.path.join(SORTIE, 'machine.png'))

    # rouleaux : cadre transparent posé par-dessus (36x76)
    planche.crop((206, 499, 242, 575)).save(os.path.join(SORTIE, 'grille.png'))

    # symboles : baie, Pikachu, 7, Marill, Replay (36x28)
    for i, x in enumerate((30, 78, 126, 174, 222)):
        planche.crop((x, 752, x + 36, 780)).save(os.path.join(SORTIE, f's{i}.png'))

    # chiffres : bande de 12 cases de 6x11 (pas 8) à partir de x = 16, y = 549 ; la première est éteinte, la deuxième est un tiret, puis 0 à 9
    petits = [planche.crop((16 + 8 * k, 549, 22 + 8 * k, 560)) for k in range(12)]
    petits[0].save(os.path.join(SORTIE, 'nv.png'))
    for d in range(10):
        petits[2 + d].save(os.path.join(SORTIE, f'n{d}.png'))

    # fond : 256x256 répété en largeur -> 320x240
    fond = planche.crop((9, 974, 265, 1230))
    cible = Image.new('RGBA', (320, 240))
    for x in range(0, 320, 256):
        cible.paste(fond, (x, -8))
    cible.save(os.path.join(SORTIE, 'fond.png'))

    # fond de gain (rayons) : agrandi x2 puis recadré au centre
    gain = planche.crop((575, 6, 800, 149)).resize((450, 286), Image.NEAREST)
    gain.crop((65, 23, 385, 263)).save(os.path.join(SORTIE, 'fond_gain.png'))
    print('écrit dans', os.path.normpath(SORTIE), len(os.listdir(SORTIE)), 'images')


if __name__ == '__main__':
    main()

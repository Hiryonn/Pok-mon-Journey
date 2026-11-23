#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Passe le projet en 640x360 (fenêtre de 1280x720 avec windowScale 2).
Modifie Data/Viewport.json (viewport « main ») et Data/configs/display_config.json (résolution et réglages de carte).
Une copie .bak est faite avant. Relançable.

Usage : python3 appliquer_640x360.py <dossier du projet> [--largeur 640 --hauteur 360 --echelle 2]

Calcul des réglages de carte (tuiles de 16 px, l'unité des positions est 128 par tuile) :
  tilemapSize = tuiles visibles arrondies au-dessus + 2   (320x240 : 20x15 -> 22x17)
  center      = (moitié de la largeur en tuiles - 0,5) x 128 ; hauteur : moitié arrondie en tuiles x 128   (320x240 : 1216, 896)
  maplinkerOffset = moitié des tuiles visibles (320x240 : 10, 7)
"""
import argparse
import json
import math
import shutil
import sys
from pathlib import Path


def save(path, data):
    if path.exists() and not path.with_suffix(path.suffix + '.bak').exists():
        shutil.copy(path, path.with_suffix(path.suffix + '.bak'))
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8', newline='\n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('project')
    ap.add_argument('--largeur', type=int, default=640)
    ap.add_argument('--hauteur', type=int, default=360)
    ap.add_argument('--echelle', type=int, default=2)
    a = ap.parse_args()
    p = Path(a.project)
    w, h = a.largeur, a.hauteur
    vp = p / 'Data/Viewport.json'
    vp_data = json.loads(vp.read_text(encoding='utf-8')) if vp.exists() else {}
    vp_data['main'] = {'x': 0, 'y': 0, 'width': w, 'height': h}
    save(vp, vp_data)
    cfg_path = p / 'Data/configs/display_config.json'
    cfg = json.loads(cfg_path.read_text(encoding='utf-8'))
    cfg['gameResolution'] = {'x': w, 'y': h}
    cfg['windowScale'] = a.echelle
    ts = cfg['tilemapSettings']
    tiles_x, tiles_y = w / 16, h / 16
    ts['tilemapSize'] = {'x': math.ceil(tiles_x) + 2, 'y': math.ceil(tiles_y) + 2}
    ts['center'] = {'x': int((tiles_x / 2 - 0.5) * 128), 'y': int(math.floor(tiles_y / 2)) * 128}
    ts['maplinkerOffset'] = {'x': int(tiles_x / 2), 'y': int(tiles_y / 2)}
    save(cfg_path, cfg)
    print(f'Résolution {w}x{h} (fenêtre {w * a.echelle}x{h * a.echelle}).')
    print('tilemapSize', ts['tilemapSize'], 'center', ts['center'], 'maplinkerOffset', ts['maplinkerOffset'])
    print('Relance le jeu (supprime Data/Viewport.rxdata et Data/configs/display_config.rxdata si le jeu garde les anciens réglages).')


if __name__ == '__main__':
    sys.exit(main())

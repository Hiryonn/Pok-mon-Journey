#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Règle la « Fonction » (battleEngineMethod) des capacités Pokéngine déjà importées, selon leurs effets.
Usage : python3 appliquer_capacites_extra.py <dossier du projet> [--essai]
Les capacités absentes du projet sont ignorées ; relançable."""
import json
import sys
from pathlib import Path

METHODES = {
    # existe déjà dans PSDK
    'heartfelt_pulse': 's_return', 'cloud_crash': 's_stomp', 'vital_tide': 's_u_turn',
    'bananarang': 's_multi_hit', 'bombshell': 's_multi_hit', 'coal_throw': 's_multi_hit', 'clone_attack': 's_multi_hit',
    'ensnare': 's_bind', 'amber_wave': 's_bind',
    # plugin Extra Moves Additions
    'fatal_tide': 's_extra_fatal_tide', 'oil_fire': 's_extra_oil_fire', 'beach_tide': 's_extra_beach_tide',
    'faceplant': 's_extra_faceplant', 'shadowfall': 's_extra_shadowfall',
}
def st(stat, n):
    return {'battleStage': stat, 'modificator': n}


def status(name, chance):
    return {'status': name, 'luckRate': chance}


# champs Studio à régler en plus (ou à la place) de la fonction : {symbole: {champ: valeur}}
# (valeurs tirées des notes de CREDITS_POKENGINE.md ; ce que la note ne chiffre pas n'est pas touché)
CHAMPS = {
    'shadowfall': {'movecriticalRate': 2},                                   # +1 niveau de critique
    'cuddle': {'effectChance': 50, 'battleStageMod': [st('ATK_STAGE', -1)]},
    'air_bubble': {'effectChance': 10, 'battleStageMod': [st('SPD_STAGE', -1)]},
    'dust_kick': {'effectChance': 10, 'battleStageMod': [st('ACC_STAGE', -1)]},
    'caustic_breath': {'effectChance': 100, 'battleStageMod': [st('DFE_STAGE', -1), st('DFS_STAGE', -1)]},
    'aqua_slap': {'effectChance': 10, 'moveStatus': [status('FLINCH', 10)]},
    'dragon_fang': {'effectChance': 10, 'moveStatus': [status('FLINCH', 10)]},   # la hausse d'Attaque du lanceur (10 %) n'existe pas en s_basic
    'blaze_arrow': {'effectChance': 20, 'moveStatus': [status('BURN', 20)]},
    'corrosive_bite': {'effectChance': 20, 'moveStatus': [status('TOXIC', 20)]},
    'burning_sneeze': {'effectChance': 30, 'moveStatus': [status('BURN', 30), status('POISONED', 15)]},
}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if not args:
        sys.exit(__doc__)
    dry = '--essai' in sys.argv
    folder = Path(args[0]) / 'Data/Studio/moves'
    for symbol in dict.fromkeys(list(METHODES) + list(CHAMPS)):
        p = folder / f'{symbol}.json'
        if not p.exists():
            print(f'  absente : {symbol}')
            continue
        raw = p.read_bytes().decode('utf-8')
        d = json.loads(raw)
        wanted = dict(CHAMPS.get(symbol, {}))
        if symbol in METHODES:
            wanted['battleEngineMethod'] = METHODES[symbol]
        changes = {k: v for k, v in wanted.items() if d.get(k) != v}
        if not changes:
            print(f'  déjà réglée : {symbol}')
            continue
        print(f'  {symbol} : ' + ', '.join(f'{k} -> {v}' for k, v in changes.items()))
        if not dry:
            d.update(changes)
            nl = '\r\n' if '\r\n' in raw else '\n'
            p.write_bytes((json.dumps(d, indent=2, ensure_ascii=False).replace('\n', nl) + (nl if raw.endswith('\n') else '')).encode('utf-8'))


if __name__ == '__main__':
    main()

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


# --- 2e vague : revue du résumé des 114 capacités ---------------------------------------------------------------
METHODES.update({
    # plugin Extra Moves Additions (un fichier .rb par capacité)
    'the_oceane_collection': 's_extra_fatal_tide',          # même description que Fatal Tide
    'corrosion_wave': 's_extra_corrosion_wave', 'liquefaction': 's_extra_liquefaction', 'snow_slide': 's_extra_snow_slide',
    'love_lariat': 's_extra_love_lariat', 'magic_backlash': 's_extra_magic_backlash', 'setting_sun': 's_extra_setting_sun',
    'cryopreserve': 's_extra_cryopreserve', 'crop_circle': 's_extra_crop_circle',
    # fonctions déjà présentes dans PSDK
    'landslide': 's_revenge', 'vine_swing': 's_acrobatics', 'team_up': 's_beat_up', 'puff_up': 's_fury_cutter',
    'paradise_display': 's_outrage', 'coral_break': 's_psyshock', 'relic_pillar': 's_psyshock', 'psi_bullet': 's_full_crit',
    'bananarang': 's_2hits', 'flurry_peck': 's_multi_hit', 'prickle_barbs': 's_multi_hit', 'rebound_strike': 's_multi_hit',
    'pinch': 's_bind', 'hair_sweep': 's_bind',
    'caffeine_sip': 's_heal', 'self_repair': 's_heal', 'fruit_munch': 's_heal', 'reservoir': 's_heal',
    'hammer_throw': 's_2turns', 'solar_flare': 's_2turns', 'depth_charge': 's_2turns',
    'jumpstart': 's_basic', 'downpour': 's_self_stat', 'bramble_up': 's_self_stat', 'echolocate': 's_self_stat',
    'shadow_dance': 's_self_stat', 'mystic_song': 's_self_stat',
    'cheer_up': 's_stat', 'electric_cheer': 's_stat', 'pester': 's_stat', 'honey_pour': 's_stat', 'anticoagulant': 's_stat',
})
ALL_AROUND, FOES = 'adjacent_all_pokemon', 'adjacent_all_foe'
CHAMPS.update({
    'anticoagulant': {'effectChance': 100, 'battleStageMod': [st('DFS_STAGE', -3)]},
    'breakdown': {'battleStageMod': [st('DFE_STAGE', -1), st('DFS_STAGE', -1)]},
    'downpour': {'battleStageMod': [st('ATS_STAGE', -2)]},
    'jumpstart': {'effectChance': 100, 'battleStageMod': [st('SPD_STAGE', 1)]},   # la Vitesse de la CIBLE monte
    'windblast': {'effectChance': 30, 'battleStageMod': [st('DFS_STAGE', -1)]},
    'mystic_song': {'effectChance': 30, 'battleStageMod': [st('DFS_STAGE', 1)]},
    'echolocate': {'battleStageMod': [st('ATS_STAGE', 1), st('ACC_STAGE', 1)]},
    'shadow_dance': {'battleStageMod': [st('DFS_STAGE', 1), st('SPD_STAGE', 1)]},
    'cheer_up': {'effectChance': 100, 'battleStageMod': [st('ATS_STAGE', 1)]},
    'electric_cheer': {'effectChance': 100, 'battleStageMod': [st('ATS_STAGE', 1), st('SPD_STAGE', 1)]},
    'pester': {'effectChance': 100, 'battleStageMod': [st('ATK_STAGE', -1), st('ATS_STAGE', -1)]},
    'honey_pour': {'effectChance': 100, 'battleStageMod': [st('SPD_STAGE', -1)]},
    # soins : plus de statut deviné
    'caffeine_sip': {'moveStatus': [], 'effectChance': 0}, 'self_repair': {'moveStatus': [], 'effectChance': 0},
    'fruit_munch': {'moveStatus': [], 'effectChance': 0}, 'reservoir': {'moveStatus': [], 'effectChance': 0, 'battleEngineAimedTarget': 'user_or_adjacent_ally'},
    'cryopreserve': {'moveStatus': [], 'effectChance': 0},
    # critique augmenté (« critical hits land more easily »)
    'blaze_arrow': {'effectChance': 20, 'moveStatus': [status('BURN', 20)], 'movecriticalRate': 2},
    'feather_slash': {'movecriticalRate': 2}, 'ice_blade': {'movecriticalRate': 2}, 'savage_slash': {'movecriticalRate': 2},
    'thunder_tail': {'movecriticalRate': 2},
    # « always goes first »
    'coal_throw': {'priority': 1}, 'poison_dart': {'priority': 1},
    # cibles : adversaires / tout ce qui entoure le lanceur
    'caustic_breath': {'effectChance': 100, 'battleStageMod': [st('DFE_STAGE', -1), st('DFS_STAGE', -1)], 'battleEngineAimedTarget': FOES},
    'mud_slide': {'battleEngineAimedTarget': FOES}, 'supercell': {'battleEngineAimedTarget': FOES},
    'fatal_tide': {'battleEngineAimedTarget': FOES}, 'the_oceane_collection': {'battleEngineAimedTarget': FOES},
    'violent_swarm': {'battleEngineAimedTarget': FOES},
    'festive_shot': {'battleEngineAimedTarget': ALL_AROUND}, 'harrowing_wail': {'battleEngineAimedTarget': ALL_AROUND},
    'meteor_shower': {'battleEngineAimedTarget': ALL_AROUND}, 'solar_charger': {'battleEngineAimedTarget': ALL_AROUND},
    'toxic_fumes': {'battleEngineAimedTarget': ALL_AROUND}, 'ear_split': {'battleEngineAimedTarget': ALL_AROUND},
    'cyclone': {'battleEngineAimedTarget': ALL_AROUND}, 'setting_sun': {'battleEngineAimedTarget': ALL_AROUND},
})


# --- 3e vague : capacités #10114 à #10127 --------------------------------------------------------------------------
METHODES.update({
    'infernal_blade': 's_extra_infernal_blade', 'vaporize': 's_extra_vaporize', 'sandy_splash': 's_extra_sandy_splash',
    'laser_pulse': 's_extra_laser_pulse', 'subduction': 's_extra_subduction',
    'metal_whip': 's_bind', 'oceans_wrath': 's_bind', 'duress': 's_fury_cutter',
    'ambuscade': 's_protect',                       # protège le lanceur ; la baisse de Vitesse au contact n'est pas codée
    'flame_impact': 's_basic', 'sudden_strike': 's_basic', 'metal_cruncher': 's_basic', 'engulf': 's_basic', 'glacial_spear': 's_basic',
})
CHAMPS.update({
    'ambuscade': {'battleStageMod': [], 'effectChance': 0, 'priority': 4, 'battleEngineAimedTarget': 'user'},
    'flame_impact': {'priority': 1}, 'sudden_strike': {'priority': 1},
    'metal_cruncher': {'effectChance': 30, 'battleStageMod': [st('DFE_STAGE', -1)]},
    'engulf': {'effectChance': 100, 'battleStageMod': [st('DFE_STAGE', -1), st('EVA_STAGE', -1)]},
    'infernal_blade': {'effectChance': 30, 'moveStatus': [status('BURN', 30)]},
    'subduction': {'effectChance': 0, 'moveStatus': []},                # la confusion du lanceur est codée dans le plugin
})


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

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Génère la démo de Pokémon Journey à partir des cartes de démo PSDK (Hub 003, Rivière, Plage, Grotte, Marais, Toundra, Piste cyclable…).

  - Data/Studio/groups/group_N.json   nouveaux groupes de Pokémon sauvages par environnement (eau, sable, grotte, marais, neige, route)
  - Data/Studio/zones/zone_N.json     les zones de ces cartes pointent vers ces nouveaux groupes (les anciens fichiers restent)
  - Data/studio_events/map_events/    PNJ de test (« [Démo] … ») : Hub = tests de base et de plugins, autres cartes = retour + combat de test
Les positions sont choisies sur des tuiles libres lues dans Data/Tiled/Maps/*.tmx (couche « passages »).
Relançable : les groupes et les événements « [Démo] » précédents sont remplacés, rien d'autre n'est touché.

Usage : python3 generer_demo.py <dossier du projet> [--sortie <dossier>] [--essai]
"""
import argparse
import json
import re
import sys
from pathlib import Path

PREFIX = '[Démo]'
HUB = 3
# nom de carte -> (id de carte, fichier tmx)
MAPS = {
    'river': (5, '005 River'), 'beach': (6, '006 Beach'), 'cave': (7, '007 Cave'), 'marsh': (8, '008 Marsh'),
    'tundra': (9, '009 Tundra'), 'road': (10, '010 CyclingRoad'), 'rocket': (11, '011 RocketHQ'), 'labo': (13, '013 Labo'),
    'library': (14, '014 Library'), 'photo': (15, '015 PhotoStudio'), 'corner': (16, '016 GameCorner'), 'arena': (17, '017 BattleArena'),
}
LABELS = {'river': 'Rivière', 'beach': 'Plage', 'cave': 'Grotte', 'marsh': 'Marais', 'tundra': 'Toundra', 'road': 'Piste cyclable',
          'rocket': 'Quartier Rocket', 'labo': 'Laboratoire', 'library': 'Bibliothèque', 'photo': 'Studio photo', 'corner': 'Salle de jeux',
          'arena': 'Arène de combat'}

# ---------------------------------------------------------------------------------------------------------------------
# Groupes sauvages : (carte, systemTag, outil, [(espèce, niveau min, niveau max, chance)])  — la somme des chances = 100
# ---------------------------------------------------------------------------------------------------------------------
def rods(a, b, c, lv=((3, 10), (10, 25), (25, 50))):
    return [('Ocean', 'OldRod', [('magikarp', lv[0][0], lv[0][1], 100)]), ('Ocean', 'GoodRod', [(s, lv[1][0], lv[1][1], p) for s, p in b]),
            ('Ocean', 'SuperRod', [(s, lv[2][0], lv[2][1], p) for s, p in c])]


GROUPS = {
    'river': [('Grass', None, [('bidoof', 5, 9, 25), ('pidgey', 5, 9, 20), ('oddish', 5, 9, 15), ('lotad', 5, 9, 15), ('wooper', 5, 9, 10), ('bellsprout', 5, 9, 10), ('psyduck', 5, 9, 5)]),
              ('Ocean', None, [('psyduck', 8, 14, 30), ('poliwag', 8, 14, 30), ('goldeen', 8, 14, 25), ('wooper', 8, 14, 15)])]
             + rods(0, [('goldeen', 40), ('poliwag', 30), ('barboach', 30)], [('seaking', 40), ('barboach', 40), ('gyarados', 20)]),
    'beach': [('Sand', None, [('sandshrew', 7, 12, 25), ('krabby', 7, 12, 25), ('wingull', 7, 12, 20), ('sandile', 7, 12, 15), ('staryu', 7, 12, 10), ('sandygast', 7, 12, 5)]),
              ('Ocean', None, [('tentacool', 10, 16, 30), ('wingull', 10, 16, 20), ('krabby', 10, 16, 20), ('staryu', 10, 16, 15), ('shellder', 10, 16, 15)])]
             + rods(0, [('tentacool', 40), ('horsea', 30), ('shellder', 30)], [('wailmer', 40), ('qwilfish', 30), ('corsola', 30)]),
    'cave': [('Cave', None, [('zubat', 8, 14, 35), ('geodude', 8, 14, 25), ('machop', 8, 14, 15), ('onix', 8, 14, 10), ('roggenrola', 8, 14, 10), ('woobat', 8, 14, 5)]),
             ('Cave', 'RockSmash', [('geodude', 8, 14, 70), ('roggenrola', 8, 14, 30)]),
             ('Ocean', None, [('wooper', 8, 14, 40), ('barboach', 8, 14, 40), ('goldeen', 8, 14, 20)])]
            + rods(0, [('barboach', 60), ('wooper', 40)], [('barboach', 60), ('seaking', 40)]),
    'marsh': [('Grass', None, [('ekans', 8, 13, 20), ('wooper', 8, 13, 20), ('stunky', 8, 13, 15), ('croagunk', 8, 13, 15), ('tangela', 8, 13, 10), ('venonat', 8, 13, 10), ('oddish', 8, 13, 10)]),
              ('Ocean', None, [('poliwag', 8, 13, 30), ('tympole', 8, 13, 30), ('barboach', 8, 13, 25), ('lotad', 8, 13, 15)])]
             + rods(0, [('barboach', 50), ('tympole', 50)], [('quagsire', 50), ('seaking', 50)] if False else [('barboach', 50), ('tympole', 50)]),
    'tundra': [('Grass', None, [('snover', 10, 16, 25), ('swinub', 10, 16, 25), ('snorunt', 10, 16, 20), ('sneasel', 10, 16, 10), ('cubchoo', 10, 16, 10), ('vanillite', 10, 16, 10)]),
               ('Ocean', None, [('seel', 12, 18, 35), ('spheal', 12, 18, 35), ('shellder', 12, 18, 20), ('lapras', 12, 18, 10)])]
              + rods(0, [('seel', 50), ('shellder', 50)], [('lapras', 40), ('spheal', 60)]),
    'road': [('Grass', None, [('doduo', 6, 12, 20), ('spearow', 6, 12, 20), ('fletchling', 6, 12, 15), ('electrike', 6, 12, 15), ('voltorb', 6, 12, 10), ('ponyta', 6, 12, 10), ('rattata', 6, 12, 10)])],
}
# espèce montrée par le PNJ « combat de test » de chaque carte
TEST_BATTLE = {'river': ('psyduck', 10), 'beach': ('krabby', 10), 'cave': ('zubat', 10), 'marsh': ('croagunk', 10), 'tundra': ('snover', 12),
               'road': ('doduo', 10), 'rocket': ('rattata', 8), 'labo': ('pikachu', 10), 'library': ('abra', 10), 'photo': ('eevee', 10),
               'corner': ('voltorb', 10), 'arena': ('machop', 12)}


# ---------------------------------------------------------------------------------------------------------------------
# Cartes : tuiles libres
# ---------------------------------------------------------------------------------------------------------------------
def load_free(project, tmx_name):
    path = project / 'Data/Tiled/Maps' / f'{tmx_name}.tmx'
    s = path.read_text(encoding='utf-8')
    head = re.search(r'<map [^>]*>', s).group(0)
    w, h = int(re.search(r'\bwidth="(\d+)"', head).group(1)), int(re.search(r'\bheight="(\d+)"', head).group(1))
    m = re.search(r'<layer id="\d+" name="passages".*?<data encoding="csv">(.*?)</data>', s, re.S)
    vals = [int(x) for x in re.split(r'[,\s]+', m.group(1).strip()) if x]
    return w, h, {(i % w, i // w) for i, v in enumerate(vals) if v == 0}


def biggest_component(free):
    seen, best = set(), []
    for start in sorted(free):
        if start in seen:
            continue
        stack, comp = [start], []
        seen.add(start)
        while stack:
            x, y = stack.pop()
            comp.append((x, y))
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if q in free and q not in seen:
                    seen.add(q)
                    stack.append(q)
        if len(comp) > len(best):
            best = comp
    return set(best)


def openness(free, p, r=3):
    return sum((p[0] + dx, p[1] + dy) in free for dx in range(-r, r + 1) for dy in range(-r, r + 1))


def pick_spawn(comp, toward=None):
    """Tuile de la plus grande zone libre, au milieu d'un espace dégagé (le plus proche de `toward` à égalité)."""
    best = max(openness(comp, p) for p in comp)
    cands = [p for p in comp if openness(comp, p) >= best - 2]
    if toward is None:
        xs, ys = [p[0] for p in comp], [p[1] for p in comp]
        toward = ((min(xs) + max(xs)) // 2, max(ys))
    return min(cands, key=lambda p: (abs(p[0] - toward[0]) + abs(p[1] - toward[1]), p))


def open_tiles(comp):
    """Tuiles dont les 8 voisines sont libres : un PNJ posé là reste contournable."""
    return {p for p in comp if all((p[0] + dx, p[1] + dy) in comp for dx in (-1, 0, 1) for dy in (-1, 0, 1))}


# ---------------------------------------------------------------------------------------------------------------------
# Événements
# ---------------------------------------------------------------------------------------------------------------------
def msg(text):
    return {'klass': 'ShowMessage', 'text': text}


def choices(options, cancel='disallow'):
    return {'klass': 'ShowChoices', 'cancel': cancel, 'choices': [{'text': t, 'commands': c} for t, c in options], 'cancelCommands': []}


def transfer(map_id, x, y):
    return {'klass': 'TransferPlayer', 'mapId': map_id, 'x': x, 'y': y, 'direction': 0, 'fade': True}


def page(sprite, commands, conditions=None, direction=2):
    return {
        'conditions': conditions or {'switch1': None, 'switch2': None, 'variable': None, 'selfSwitch': None},
        'graphic': {'characterName': sprite, 'tileId': 0, 'hue': 0, 'direction': direction, 'pattern': 0, 'opacity': 255, 'blendType': 0},
        'moveType': 'fixed', 'moveSpeed': 3, 'moveFrequency': 3, 'moveRoute': {'repeat': True, 'skippable': False, 'commands': []},
        'walkAnime': True, 'stepAnime': False, 'directionFix': False, 'through': False, 'alwaysOnTop': False, 'trigger': 'action',
        'commands': commands,
    }


def event(eid, name, x, y, sprite, commands, direction=2, once_text=None):
    pages = [page(sprite, commands, direction=direction)]
    if once_text is not None:
        pages[0]['commands'] = commands + [{'klass': 'ControlSelfSwitch', 'ch': 'A', 'value': True}]
        pages.append(page(sprite, [msg(once_text)], {'switch1': None, 'switch2': None, 'variable': None, 'selfSwitch': 'A'}, direction))
    return {'klass': 'MapEvent', 'id': eid, 'name': f'{PREFIX} {name}', 'x': x, 'y': y, 'pages': pages}


def plugin(klass, **kw):
    return {'klass': klass, **kw}


def hub_npcs(spawn_back, destinations):
    """Liste (zone, nom, sprite, commandes, texte_une_fois) des PNJ du Hub. zone : 'base' (hall sud) ou 'plugins' (salons nord)."""
    L = []
    d = destinations

    def nature(a, b, c):
        return [msg('Où veux-tu aller ?'),
                choices([(LABELS[k], [transfer(*d[k])]) for k in (a, b, c)] + [('Annuler', [])])]

    L.append(('base', 'Guide des cartes', 'npc_prof-oak', [
        msg("Bienvenue dans la démo ! Je t'emmène sur les cartes de test. Chaque carte a un PNJ « Retour au Hub » près de l'arrivée."),
        choices([('Nature 1', nature('river', 'beach', 'cave')), ('Nature 2', nature('marsh', 'tundra', 'road')),
                 ('Intérieurs', nature('labo', 'library', 'corner')), ('Autres', nature('arena', 'photo', 'rocket'))])], None))
    L.append(('base', 'Pokémon de départ', 'npc_ace-trainer-m-01', [
        msg("Choisis un Pokémon de niveau 30 pour tester les combats (une seule fois)."),
        choices([('Florizarre', [plugin('GivePokemon', pokemon='venusaur', level=30, form=None, variant='')]),
                 ('Dracaufeu', [plugin('GivePokemon', pokemon='charizard', level=30, form=None, variant='')]),
                 ('Tortank', [plugin('GivePokemon', pokemon='blastoise', level=30, form=None, variant='')]),
                 ('Pikachu', [plugin('GivePokemon', pokemon='pikachu', level=30, form=None, variant='')])])],
        "Tu as déjà reçu ton Pokémon de test."))
    L.append(('base', 'Objets de test', 'npc_clerk', [
        msg("Voici de quoi tester : Balls, soins, Super Bonbons, Repousse et Corde Sortie. Reviens quand tu veux."),
        plugin('GiveItem', item='poke_ball', count=20), plugin('GiveItem', item='great_ball', count=10),
        plugin('GiveItem', item='potion', count=10), plugin('GiveItem', item='super_potion', count=10),
        plugin('GiveItem', item='revive', count=5), plugin('GiveItem', item='rare_candy', count=20),
        plugin('GiveItem', item='repel', count=5), plugin('GiveItem', item='escape_rope', count=3)], None))
    L.append(('base', 'Combat sauvage', 'npc_camper-m', [
        msg("Combat contre un Pokémon sauvage de ton choix."),
        choices([('Pikachu niv. 10', [plugin('WildBattle', pokemon='pikachu', level=10)]),
                 ('Magicarpe niv. 5', [plugin('WildBattle', pokemon='magikarp', level=5)]),
                 ('Houndour niv. 30', [plugin('WildBattle', pokemon='houndour', level=30)]),
                 ('Annuler', [])])], None))
    L.append(('base', 'Combat de dresseur', 'npc_black-belt-01', [
        msg("Combat de dresseur de test : un contre un ou en double."),
        choices([('1 contre 1', [plugin('TrainerBattle', trainerId=0, troopId=3, bgm='')]),
                 ('Combat double', [plugin('TrainerBattle', trainerId=2, troopId=3, bgm='')]),
                 ('Annuler', [])])], None))
    L.append(('base', 'Mécaniques (Téra)', 'npc_scientist-m', [
        msg("Test des mécaniques spéciales : le prochain Pokémon sauvage aura la Téracristallisation."),
        choices([('Recharger l’Orbe', [plugin('PJ_TeraRecharge')]),
                 ('Combat Téra', [plugin('PJ_GimmickWild', mega=False, zmove=False, dynamax=False, tera=True),
                                  plugin('WildBattle', pokemon='charizard', level=30)]),
                 ('Annuler', [])])], None))
    L.append(('base', 'Variantes', 'npc_collector', [
        msg("Je te donne un Pikachu d'une variante (plugin Variantes)."),
        plugin('PJ_AddVariantPokemon', pokemon='pikachu', level=10, variant='silver')], 'Tu as déjà ton Pikachu variante.'))
    L.append(('base', 'Pokémon Obscurs', 'npc_galactic-grunt-m', [
        msg("Plugin Obscurs : un Pokémon Obscur, sa purification et la Pierre Relique."),
        choices([('Recevoir un Obscur', [plugin('PJ_GiveShadow', pokemon='houndour', level=30, id='')]),
                 ('Chambre de purification', [plugin('PJ_PurifyChamber')]),
                 ('Pierre Relique', [plugin('PJ_RelicStone')]),
                 ('Annuler', [])])], None))
    L.append(('base', 'Raids', 'npc_ranger', [
        msg("Plugin Raids : remplir les antres puis lancer un combat de raid."),
        choices([('Remplir les antres', [plugin('PJ_RaidRefill')]),
                 ('Combat de raid', [plugin('PJ_RaidBattle', pokemon='charizard', style='basic', rank=0, capture=True, rewards=True)]),
                 ('Annuler', [])])], None))
    # --- plugins ---
    L.append(('plugins', 'Générateur de personnage', 'npc_artist', [
        msg('Générateur de personnage : change ton apparence (annulable).'), plugin('PJ_CustomizePlayer', cancellable=True)], None))
    L.append(('plugins', 'Personnages', 'npc_actress', [
        msg('Plugin Personnages : choisis ton héros.'), plugin('PJ_ChooseHero', name=True, cancellable=True)], None))
    L.append(('plugins', 'Carte de la région', 'npc_book-girl', [
        msg('Plugin Carte de la région.'), plugin('PJ_RegionMap', mode='map', worldmap=0)], None))
    L.append(('plugins', 'Succès et badges', 'npc_battle-girl', [
        msg('Succès et étui à badges.'),
        choices([('Succès', [plugin('PJ_Achievements')]), ('Étui à badges', [plugin('PJ_BadgeCase', region='')]), ('Annuler', [])])], None))
    L.append(('plugins', 'Triple Triad', 'npc_gentleman-01', [
        msg('Triple Triad : cartes, boutique et parties.'),
        choices([('Une partie', [plugin('PJ_TriadDuel', name='Dresseur de test', minLevel=0, maxLevel=9)]),
                 ('Collection', [plugin('PJ_TriadCollection')]), ('Boutique', [plugin('PJ_TriadShop')]),
                 ('Carte Pikachu', [plugin('PJ_TriadGiveCard', pokemon='pikachu', count=1, message=True)])])], None))
    L.append(('plugins', 'Baies', 'npc_pkmn-breeder', [
        msg('Baies : Berrydex, pots et mixeur.'),
        choices([('Berrydex', [plugin('PJ_Berrydex')]), ('Pots à baies', [plugin('PJ_AddPots', amount=2), plugin('PJ_BerryPots')]),
                 ('Mixeur à baies', [plugin('PJ_BerryBlender', mode='play', players=0)]), ('Annuler', [])])], None))
    L.append(('plugins', 'Concours', 'npc_hostess-01', [
        msg('Concours : mallette de départ, mallette et gagnants.'),
        choices([('Mallette de départ', [plugin('PJ_StarterCase')]), ('Mallette', [plugin('PJ_FashionCase')]),
                 ('Gagnants', [plugin('PJ_ContestWinners')]), ('Annuler', [])])], None))
    L.append(('plugins', 'Pokéblocs', 'npc_chocolatier', [
        msg('Pokéblocs : boîte, état des Pokémon, Pokéblocs offerts.'),
        choices([('Boîte Pokébloc', [plugin('PJ_PokeblockCase')]), ('État des Pokémon', [plugin('PJ_PokemonCondition')]),
                 ('5 Pokéblocs rouges', [plugin('PJ_GivePokeblock', color='red', count=5, plus=False)]), ('Annuler', [])])], None))
    L.append(('plugins', 'Montures', 'npc_cyclist-m', [
        msg('Montures : appli et roue des montures.'),
        choices([('Appli Monture', [plugin('PJ_MountApp')]), ('Roue des montures', [plugin('PJ_MountWheel')]), ('Annuler', [])])], None))
    L.append(('plugins', 'Pokéathlon', 'npc_jogger', [
        msg('Pokéathlon : données, boutique, mixeur à Noigrumes.'),
        choices([('Données', [plugin('PJ_AthlonData')]), ('Boutique', [plugin('PJ_AthlonShop')]),
                 ('Noigrumes', [plugin('PJ_AprijuiceBlender')]), ('+100 points', [plugin('PJ_AthlonPoints', amount=100)])])], None))
    L.append(('plugins', 'Poké Récré', 'npc_mom-01', [
        msg('Poké Récré : jouer avec ton premier Pokémon.'),
        choices([('Ouvrir la Récré', [plugin('PJ_PokeRecre', index=0)]), ('+50 affection', [plugin('PJ_GiveAffection', index=1, points=50)]),
                 ('Annuler', [])])], None))
    L.append(('plugins', 'Mini-jeux', 'npc_mr-game', [
        msg('Mini-jeux : Qui est ce Pokémon ?, Cueillette Dodrio, Lance-Ball.'),
        choices([('Qui est ce Pokémon ?', [plugin('PJ_WhosThat', variable=0)]), ('Cueillette Dodrio', [plugin('PJ_DodrioPicking', players=0, variable=0)]),
                 ('Lance-Ball', [plugin('PJ_LanceBall', count=0, variable=0)]), ('Annuler', [])])], None))
    L.append(('plugins', 'Boutique et réassort', 'npc_clerk', [
        msg('Magasins : boutique de test et réassort.'),
        choices([('Boutique', [plugin('PJ_Store', shop='boutique')]), ('Réassort', [plugin('PJ_StoreRestock', shop='boutique')]), ('Annuler', [])])], None))
    return L


# ---------------------------------------------------------------------------------------------------------------------
def write_json(path, data, dry):
    if dry:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding='utf-8', newline='\n')


def main():
    ap = argparse.ArgumentParser(description='Génère la démo (groupes sauvages + PNJ de test) pour les cartes de démo PSDK.')
    ap.add_argument('project')
    ap.add_argument('--sortie', help='dossier où écrire (défaut : le projet)')
    ap.add_argument('--essai', action='store_true', help="n'écrit rien")
    args = ap.parse_args()
    project = Path(args.project)
    out = Path(args.sortie) if args.sortie else project
    dry = args.essai
    species = {p.stem for p in (project / 'Data/Studio/pokemon').glob('*.json')}
    items = {p.stem for p in (project / 'Data/Studio/items').glob('*.json')}
    chars = {p.stem for p in (project / 'graphics/characters').glob('npc_*.png')}

    def sprite(name):
        return name if name in chars else ('npc_boy' if 'npc_boy' in chars else name)

    # ---- cartes : tuiles libres -----------------------------------------------------------------------------------
    comps, spawns = {}, {}
    for key, (mid, tmx) in {**MAPS, 'hub': (HUB, '003 Hub')}.items():
        try:
            w, h, free = load_free(project, tmx)
        except (OSError, AttributeError) as e:
            print(f'! carte {tmx} illisible ({e}) : ignorée')
            continue
        comps[key] = biggest_component(free)
    spawns = {k: pick_spawn(c) for k, c in comps.items() if k != 'hub'}
    hub_back = pick_spawn(comps['hub'], toward=(29, 45))
    destinations = {k: (MAPS[k][0], *spawns[k]) for k in spawns}

    # ---- groupes -------------------------------------------------------------------------------------------------
    groups_dir = project / 'Data/Studio/groups'
    state_path = Path(__file__).resolve().parent / 'demo_groupes.json'
    state = json.loads(state_path.read_text(encoding='utf-8')) if state_path.exists() else {}
    next_gid = max([int(re.search(r'(\d+)$', p.stem).group(1)) for p in groups_dir.glob('group_*.json')] + [0]) + 1
    new_zone_groups = {}
    for key, defs in GROUPS.items():
        ids = []
        for n, (tag, tool, enc) in enumerate(defs):
            enc = [e for e in enc if e[0] in species]
            if not enc:
                continue
            total = sum(e[3] for e in enc)
            gid_key = f'{key}:{n}'
            gid = state.get(gid_key)
            if gid is None:
                gid = next_gid
                next_gid += 1
                state[gid_key] = gid
            fixed, running = [], 0
            for i, (sp, lo, hi, chance) in enumerate(enc):
                c = round(chance * 100 / total) if i < len(enc) - 1 else 100 - running
                running += c
                fixed.append({'specie': sp, 'form': 0, 'shinySetup': {'kind': 'automatic', 'rate': -1},
                              'levelSetup': {'kind': 'minmax', 'level': {'minimumLevel': lo, 'maximumLevel': hi}},
                              'randomEncounterChance': c, 'expandPokemonSetup': []})
            write_json(out / f'Data/Studio/groups/group_{gid}.json',
                       {'klass': 'Group', 'id': gid, 'dbSymbol': f'group_{gid}', 'systemTag': tag, 'terrainTag': 0, 'tool': tool,
                        'vsType': 'simple', 'customConditions': [], 'stepsAverage': 30, 'encounters': fixed}, dry)
            ids.append(gid)
        new_zone_groups[key] = ids
    if not dry:
        state_path.write_text(json.dumps(state, indent=2), encoding='utf-8')
    # ---- zones ---------------------------------------------------------------------------------------------------
    zones = {}
    for p in (project / 'Data/Studio/zones').glob('zone_*.json'):
        z = json.loads(p.read_text(encoding='utf-8'))
        for m in z['maps']:
            zones.setdefault(m, (p, z))
    for key, ids in new_zone_groups.items():
        mid = MAPS[key][0]
        if mid not in zones:
            print(f'! aucune zone pour la carte {mid} ({LABELS[key]}) : groupes créés mais non reliés')
            continue
        p, z = zones[mid]
        z['wildGroups'] = [f'group_{g}' for g in ids]
        write_json(out / 'Data/Studio/zones' / p.name, z, dry)
        print(f'zone {z["id"]} (carte {mid}, {LABELS[key]}) : {len(ids)} groupe(s) -> {z["wildGroups"]}')

    # ---- événements des cartes d'environnement ---------------------------------------------------------------------
    def load_events(mid):
        p = project / 'Data/studio_events/map_events' / f'map{mid:03d}.json'
        if p.exists():
            d = json.loads(p.read_text(encoding='utf-8'))
        else:
            d = {'klass': 'MapEvents', 'mapId': mid, 'mapDbSymbol': f'map{mid:03d}', 'events': []}
        d['events'] = [e for e in d['events'] if not str(e.get('name', '')).startswith(PREFIX)]
        return d

    for key, (mid, tmx) in MAPS.items():
        if key not in spawns:
            continue
        comp = comps[key]
        sp = spawns[key]
        cands = sorted((open_tiles(comp) - {sp}), key=lambda p: (abs(p[0] - sp[0]) + abs(p[1] - sp[1]), p))
        cands = [p for p in cands if 2 <= abs(p[0] - sp[0]) + abs(p[1] - sp[1]) <= 6] or cands
        doc = load_events(mid)
        eid = max([e['id'] for e in doc['events']] + [0]) + 1
        spot = lambda i: cands[min(i, len(cands) - 1)]
        mon, lv = TEST_BATTLE[key]
        e1 = spot(0)
        e2 = spot(3) if len(cands) > 3 else spot(1)
        doc['events'].append(event(eid, 'Retour au Hub', e1[0], e1[1], sprite('npc_prof-oak'), [
            msg(f'Tu es dans : {LABELS[key]}. Retourner au Hub de démo ?'),
            choices([('Oui', [transfer(HUB, *hub_back)]), ('Non', [])])]))
        if mon in species:
            doc['events'].append(event(eid + 1, 'Combat de test', e2[0], e2[1], sprite('npc_camper-m'), [
                msg(f'Combat de test ({LABELS[key]}) : {mon} niveau {lv}. Pour les groupes sauvages, marche dans l’herbe, l’eau ou la grotte.'),
                plugin('WildBattle', pokemon=mon, level=lv)]))
        write_json(out / 'Data/studio_events/map_events' / f'map{mid:03d}.json', doc, dry)
        print(f'carte {mid} {LABELS[key]} : arrivée {sp}, PNJ en {e1} et {e2}')

    # ---- Hub -------------------------------------------------------------------------------------------------------
    doc = load_events(HUB)
    taken = {(e['x'], e['y']) for e in doc['events']} | {hub_back}
    slots = sorted(t for t in open_tiles(comps['hub']) if t[0] % 2 == 0 and t[1] % 2 == 0 and t not in taken
                   and abs(t[0] - hub_back[0]) + abs(t[1] - hub_back[1]) > 2)
    south = [t for t in slots if t[1] >= 42]
    north = [t for t in slots if t[1] <= 38]
    south.sort(key=lambda t: (t[1], t[0]))
    north.sort(key=lambda t: (t[1], t[0]))
    eid = max([e['id'] for e in doc['events']] + [0]) + 1
    sign = hub_back[0], hub_back[1] - 2
    npcs = hub_npcs(hub_back, destinations)
    placed = 0
    for zone, name, spr, cmds, once in npcs:
        pool = south if zone == 'base' else north
        if not pool:
            pool = north if zone == 'base' and north else south
        if not pool:
            print(f'! plus de place dans le Hub pour « {name} »')
            continue
        x, y = pool.pop(0)
        cmds = [c for c in cmds if not (c.get('klass') == 'GiveItem' and c['item'] not in items)]
        doc['events'].append(event(eid, name, x, y, sprite(spr), cmds, once_text=once))
        eid += 1
        placed += 1
    doc['events'].append(event(eid, 'Panneau de la démo', sign[0], sign[1], sprite('npc_boy'), [
        msg("Démo Pokémon Journey. Au sud : soin, boutique, PC, Pokémon et objets de départ, combats, mécaniques. "
            "Au nord : un PNJ par plugin. Le Guide des cartes t'emmène sur Rivière, Plage, Grotte, Marais, Toundra et Piste cyclable (groupes sauvages).")]))
    write_json(out / 'Data/studio_events/map_events/map003.json', doc, dry)
    print(f'Hub : {placed} PNJ de test + panneau ; arrivée de retour {hub_back}')
    print(('[essai] rien écrit' if dry else 'Démo générée.'))


if __name__ == '__main__':
    main()

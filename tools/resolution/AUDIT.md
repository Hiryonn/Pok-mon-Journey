# Audit des interfaces pour l'écran 640×360

Base : 320×240 → 640×360 (largeur ×2, hauteur ×1,5). « Placements » = lignes qui posent un élément (add_sprite, add_text, set_position…) ; « Tailles » = nombres liés à 320×240 (320, 240, 160, 120, 308, 312).

| Plugin | Fichiers d'interface | Placements | Tailles 320×240 |
|---|---|---|---|
| interface_horizon | 30 | 230 | 3 |
| pokeathlon | 16 | 205 | 55 |
| concours | 9 | 143 | 23 |
| poke_recre | 2 | 95 | 16 |
| pokesmart | 11 | 88 | 12 |
| berrydex | 3 | 80 | 11 |
| gimmicks | 6 | 80 | 38 |
| raids | 4 | 71 | 20 |
| enhanced_battle_ui | 6 | 69 | 7 |
| pokeblocs | 3 | 65 | 22 |
| advanced_pokedex | 3 | 53 | 3 |
| poffin | 3 | 45 | 7 |
| etui_badges | 1 | 44 | 13 |
| succes | 2 | 42 | 6 |
| tournoi | 2 | 42 | 11 |
| triple_triad | 4 | 42 | 0 |
| carte_region | 2 | 41 | 4 |
| pots_baies | 1 | 39 | 6 |
| dodrio | 1 | 35 | 7 |
| magasins | 3 | 33 | 5 |
| lance_ball | 1 | 29 | 11 |
| montures | 2 | 29 | 12 |
| tele | 1 | 28 | 1 |
| generateur | 1 | 24 | 1 |
| icone_pss | 1 | 24 | 0 |
| obscurs | 5 | 23 | 9 |
| sac_de_frappe | 1 | 20 | 5 |
| personnages | 1 | 14 | 2 |
| wardrobe | 1 | 14 | 0 |
| peche | 1 | 13 | 0 |
| base_secrete | 1 | 11 | 1 |
| styles_pla | 1 | 11 | 9 |
| interface_pe | 1 | 10 | 0 |
| casino_jp | 1 | 8 | 0 |
| quel_pokemon | 1 | 2 | 1 |
| mementos | 1 | 1 | 0 |
| overworld_pokemon | 1 | 1 | 0 |

## Déjà fait
- `scripts/10002 Ecran.rb` : cadre central 320×240 (`Ecran.viewport`), sans effet avec un écran de 320×240.
- Appliqué aux animations de titre des styles PLA (gimmicks, styles_pla) et à la transition des antres de raid ; fondu noir de la cinématique en plein écran.
- Carte de région : viewports en `:main` + `rect`.

## À faire (par ordre)
1. Écrans qui héritent des classes de base de PSDK (menus, sac, équipe, Pokédex, boutique…) : il faut les scripts de PSDK pour poser le cadre au bon endroit (création du viewport de `GamePlay::Base` / `UI::GenericBase`).
2. Combat : positions des Pokémon et des barres de vie pour 5 par camp (interface_horizon/00130 Combat, enhanced_battle_ui).
3. Barre du smartphone sur la carte (pokesmart), à couper dans les réglages.
4. Fonds 320×240 : fonds de combat, panoramas, titres, transitions (étirer ou répéter avec les ressources existantes, sans image générée).
5. Écrans de plugins, du plus chargé au moins chargé (voir le tableau).
6. Notifications (succès, téléphone) : ancrées au coin de l'écran réel.
7. Cartes : `tilemapSize`, `center`, `maplinkerOffset` pour 640×360 (voir la note ci-dessous).

## Réglage de carte pour 640×360 (à confirmer en jeu)
`gameResolution` 640×360, `windowScale` 2. Tuiles de 16 px : 40×22,5 tuiles visibles. `tilemapSize` ≈ 42×25. `center` ≈ x 2496, y 1408 (unités de 128 par tuile, comme 1216/896 pour 320×240). `maplinkerOffset` ≈ 20×11. Ces valeurs viennent de mon calcul à partir de celles de 320×240, pas d'un essai.

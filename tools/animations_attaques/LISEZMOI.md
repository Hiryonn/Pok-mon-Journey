# Animations d'attaques (planches découpées)

Trois planches d'effets d'attaques, découpées en une feuille transparente par attaque (titres et fond retirés) :
`graphics/animations/atk_<nom>.png`. Elles se choisissent comme les autres images d'animation de Studio.

- `decouper_attaques.py` : refait le découpage depuis `sources/` (`python3 decouper_attaques.py`). Les zones sont écrites à la main en haut du script.
- `index.json` : position (x, y) et taille de chaque feuille dans sa planche d'origine.
- `sources/` : les planches d'origine (`poison.png`, `dragon.png`, `joshr.png`).

## Crédits
- `atk_joshr_*` : planche « 100% Custom Pokemon Attack Sheet » de **JoshR_691** — son auteur demande de **lui donner un crédit important** si elle est utilisée (à mettre dans les crédits du jeu).
- Poison et Dragon : extraits par redblueyellow (aucun crédit demandé).

## Feuilles

| Fichier | Taille |
|---|---|
| `atk_acid_armor.png` | 544 x 50 |
| `atk_acid.png` | 100 x 22 |
| `atk_cross_poison.png` | 501 x 51 |
| `atk_poison_fang.png` | 86 x 24 |
| `atk_gastro_acid.png` | 485 x 40 |
| `atk_poison_sting.png` | 46 x 78 |
| `atk_gunk_shot.png` | 399 x 78 |
| `atk_poison_tail.png` | 258 x 32 |
| `atk_sludge.png` | 25 x 17 |
| `atk_sludge_bomb.png` | 77 x 146 |
| `atk_poison_extra_1.png` | 141 x 110 |
| `atk_poison_vagues.png` | 358 x 336 |
| `atk_toxic_spikes.png` | 301 x 31 |
| `atk_poisoned.png` | 111 x 16 |
| `atk_badly_poisoned.png` | 111 x 16 |
| `atk_poison_gas_smog.png` | 528 x 50 |
| `atk_poison_jab.png` | 642 x 137 |
| `atk_poisonpowder.png` | 700 x 49 |
| `atk_toxic.png` | 486 x 29 |
| `atk_draco_meteor.png` | 699 x 547 |
| `atk_dragon_claw.png` | 737 x 296 |
| `atk_dragon_dance.png` | 547 x 178 |
| `atk_dragon_pulse.png` | 579 x 242 |
| `atk_dragon_rage.png` | 624 x 36 |
| `atk_dragon_rush.png` | 676 x 121 |
| `atk_dragonbreath.png` | 224 x 29 |
| `atk_outrage.png` | 512 x 103 |
| `atk_roar_of_time.png` | 570 x 165 |
| `atk_spacial_rend.png` | 580 x 62 |
| `atk_twister.png` | 669 x 271 |
| `atk_joshr_divers.png` | 304 x 434 |
| `atk_joshr_vignes.png` | 240 x 47 |
| `atk_joshr_explosions_fumee.png` | 168 x 22 |
| `atk_joshr_vitres_grises.png` | 272 x 135 |
| `atk_joshr_notes_soleil.png` | 150 x 85 |
| `atk_joshr_vitres_vertes.png` | 272 x 135 |
| `atk_joshr_vitres_jaunes.png` | 272 x 135 |
| `atk_joshr_vitres_bleues.png` | 272 x 135 |

Poison : acid, acid_armor, cross_poison, gastro_acid, gunk_shot, poison_fang, poison_sting, poison_tail, sludge, sludge_bomb, toxic_spikes, poisoned, badly_poisoned, poison_gas_smog, poison_jab, poisonpowder, toxic ; `poison_extra_1` et `poison_vagues` n'avaient pas de titre sur la planche.
Dragon : draco_meteor, dragon_claw, dragon_dance, dragon_pulse, dragon_rage, dragon_rush, dragonbreath, outrage, roar_of_time, spacial_rend, twister.
JoshR : `divers` (la grande masse d'effets : feu, glace, éclairs, bulles, mains, tornades…), vignes, explosions et fumée, notes de musique et soleil, vitres (grises, vertes, jaunes, bleues : 7 images sur 2 rangées).
Les images d'une feuille sont découpées à la main par l'animation (leur taille n'est pas régulière) : repère-les avec la grille de Studio.

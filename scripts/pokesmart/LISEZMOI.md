# Plugin pokesmart

Menu principal de PSDK en smartphone (pack PokeSmart), indépendant du plugin interface_pe.

## Contenu
- `scripts/00130 Menu Smartphone.rb` : le menu (module `UI::PokeSmart`, `ENABLED = false` pour le couper)
- graphismes : `graphics/interface/pokesmart/` (coque, icônes, barre d'état) et `wallpapers/`

## Construire le plugin
Depuis la racine du projet : `psdk.bat --util=plugin build pokesmart`
(ou double-clic sur `construire_plugin_pokesmart.bat`).
Le fichier `scripts/pokesmart.psdkplug` est créé ; PSDK l'installe au lancement suivant.

## Applis et icônes
Les applis sont rangées dans l'ordre des icônes de `menu_icons.png` (table `APP_ICONS`) :
0 Pokédex, 1 Équipe, 2 Sac, 3 Carte (`open_map`), 4 PC (`open_pc`), 5 Journal de quête (`open_quest`),
6 Carte de dresseur, 7 Amis (`open_friends`), 8 Sauvegarde, 9 Options, 10 Personnalisation (`open_customization`),
11 Cadeau mystère (`open_mystery_gift`), 12 Monture (`open_mount`), 13 Troupeaux (`open_herds`),
14 Jeu de cartes (`open_card_game`), 15 Pension (`open_daycare`), 16-17 libres.
Pour activer une appli future : définir la méthode dans `GamePlay::Menu` puis
`GamePlay::Menu.register_button(:open_map) { true }` ; l'icône et le nom sont déjà prêts.

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

Les applis 0 à 9 sont au-dessus du trait, les autres en dessous (`SECONDARY_FROM`).

## Appli Troupeaux (radar)
Ajoutée par le plugin (`HERDS_APP = false` pour la retirer). Elle affiche dans le téléphone :
- le nom de la zone ;
- les Pokémon sauvages des groupes actifs ici (conditions de carte et d'interrupteur de Studio respectées) :
  « ? » si jamais vu, l'icône si vu, l'icône + Poké Ball si capturé ;
- le marqueur bleu si la zone n'a que des rencontres sur l'eau / à la canne, orange sinon ;
- le moment de la journée.
Haut / bas pour faire défiler au-delà de 9 Pokémon, A / B / clic pour revenir aux applis.

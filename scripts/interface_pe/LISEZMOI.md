# Plugin interface_pe

Interfaces Pokédex, résumé du Pokémon, sac et menu smartphone pour PSDK (projet Pokémon Journey).

## Contenu
- `scripts/00100 Pokedex PE.rb` : Pokédex (liste, fiche, carte, page seule)
- `scripts/00110 Resume Pokemon PE.rb` : résumé du Pokémon (Infos, Stats, Capacités, Concours, Rubans, Mémo)
- `scripts/00120 Sac PE.rb` : sac en grille
- `scripts/00130 Menu Smartphone PE.rb` : menu principal en smartphone (pack PokeSmart)
- graphismes : `graphics/pokedex/pe/`, `graphics/interface/summary_pe/`, `graphics/interface/bag_pe/`, `graphics/interface/menu_pe/`

Chaque interface se désactive avec `ENABLED = false` en haut de son script.

## Construire le plugin
Depuis la racine du projet : `psdk.bat --util=plugin build interface_pe`
(ou double-clic sur `construire_plugin_interface_pe.bat`).
Le fichier `scripts/interface_pe.psdkplug` est créé ; PSDK l'installe au lancement suivant.

Après une modification d'un script du plugin, il faut reconstruire le plugin
(puis `psdk.bat --util=plugin load` pour forcer la réinstallation).

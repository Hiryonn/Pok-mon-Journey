# Plugin interface_pe

Interfaces Pokédex, résumé du Pokémon, sac et combat pour PSDK (projet Pokémon Journey).

## Contenu
Un dossier par interface dans `scripts/` (chargés dans l'ordre des numéros, fichiers numérotés 001, 002…) :
- `00100 Pokedex/` : configuration, base, liste, fiche, animation d'ouverture, variante du Pokédex, scènes
- `00110 Resume/` : configuration, base, boutons des capacités, bandeau, une page par fichier (Infos, Stats,
  Capacités, Concours, Rubans, Mémo), scène
- `00120 Sac/` : configuration, base, onglets et titre, grille, panneau du bas, éléments cachés, scène
- `00130 Combat/` : configuration, boîtes d'infos, éléments communs, menu d'action, menu Safari,
  choix de l'attaque, boîte de message, scène (position du Pokémon, boîte d'infos, Poké Balls de l'équipe)
- graphismes : `graphics/pokedex/pe/`, `graphics/interface/summary_pe/`, `graphics/interface/bag_pe/`,
  `graphics/interface/battle_pj/` (sources dans `battle_pj/source/`), `graphics/windowskins/battle_pj_message.png`

Chaque interface se désactive avec `ENABLED = false` dans son fichier `001 Configuration.rb`.

## Construire le plugin
Depuis la racine du projet : `psdk.bat --util=plugin build interface_pe`
(ou double-clic sur `construire_plugin_interface_pe.bat`).
Le fichier `scripts/interface_pe.psdkplug` est créé ; PSDK l'installe au lancement suivant.

Après une modification d'un script du plugin, il faut reconstruire le plugin
(puis `psdk.bat --util=plugin load` pour forcer la réinstallation).

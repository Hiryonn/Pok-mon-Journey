# Plugin interface_horizon (Interface Horizon)

Anciennement « interface_pe ». Interfaces Pokédex, résumé du Pokémon, sac, équipe et combat pour PSDK (projet Pokémon Journey).

## Contenu
Un dossier par interface dans `scripts/` (chargés dans l'ordre des numéros, fichiers numérotés 001, 002…) :
- `00100 Pokedex/` : configuration, base, liste, fiche, animation d'ouverture, variante du Pokédex, scènes,
  habillage des pages Taille / Poids du plugin advanced_pokedex
- `00110 Resume/` : configuration, base, boutons des capacités, bandeau, une page par fichier (Infos, Stats,
  Capacités, Concours, Rubans, Mémo), scène
- `00120 Sac/` : style « Bag Screen with Party » (Essentials) : configuration, fond qui défile, poches et argent,
  liste des objets, équipe (PV, APTE / PAS APTE), barre de description, éléments cachés, scène.
  Graphismes refaits en 320 x 240 par `tools/interface-horizon/build_bag_assets.py`
- `00140 Equipe/` : configuration, base (bandeau, message, barre du bas), carte d'un Pokémon, scène
  (menu Équipe, choix d'un Pokémon, combat, sélection : style du Pokédex Horizon)
- `00130 Combat/` : configuration, boîtes d'infos, éléments communs, menu d'action, menu Safari,
  choix de l'attaque, boîte de message, scène (position du Pokémon, boîte d'infos, Poké Balls de l'équipe)
- graphismes : `graphics/pokedex/pe/`, `graphics/interface/summary_pe/`, `graphics/interface/bag_horizon/` (+ sons `audio/se/bag_horizon/`), `graphics/interface/party_pe/`,
  `graphics/interface/battle_pj/` (sources dans `battle_pj/source/`), `graphics/windowskins/battle_pj_message.png`

Chaque interface se désactive avec `ENABLED = false` dans son fichier `001 Configuration.rb`.

## Construire le plugin
Depuis la racine du projet : `psdk.bat --util=plugin build interface_horizon`
(ou double-clic sur `construire_plugin_interface_horizon.bat`).
Le fichier `scripts/interface_horizon.psdkplug` est créé ; PSDK l'installe au lancement suivant.

Après une modification d'un script du plugin, il faut reconstruire le plugin
(puis `psdk.bat --util=plugin load` pour forcer la réinstallation).

# Plugin pokesmart

Menu principal de PSDK en smartphone (pack PokeSmart), indépendant du plugin interface_pe.

## Contenu
- `scripts/00130 Menu Smartphone.rb` : le menu (module `UI::PokeSmart`, `ENABLED = false` pour le couper)
- graphismes : `graphics/interface/pokesmart/` (coque, icônes, barre d'état) et `wallpapers/`

## Construire le plugin
Depuis la racine du projet : `psdk.bat --util=plugin build pokesmart`
(ou double-clic sur `construire_plugin_pokesmart.bat`).
Le fichier `scripts/pokesmart.psdkplug` est créé ; PSDK l'installe au lancement suivant.

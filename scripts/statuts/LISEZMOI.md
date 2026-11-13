# Statuts

Nouveaux statuts pour les Pokémon, réglés dans Studio : **Données > Statuts**
(`tools/studio-statuts/installer_statuts.bat`, Studio fermé, puis `construire_plugins.bat` une fois).

## Saignement (fourni)

| | |
|---|---|
| Défense (physique) | divisée par 1,5 tant que le Pokémon saigne |
| Dégâts | 1/16 des PV max à la fin de chaque tour (pas avec Garde Magik) |
| Icône | `SAI` / `BLD` / `SAN` (ligne 10 de `graphics/interface/statuts<fr|en|es>.png`) |
| Animation | `graphics/animations/status/bleeding.png` (gouttes rouges) |
| Guérison | Total Soin, Baie Prine, centre Pokémon… (tout ce qui soigne un statut quelconque) |

Comme les autres statuts majeurs, un Pokémon n'en a qu'un à la fois.

## Studio

Pour chaque statut du projet : nom, icône (abréviation et couleur), statistiques divisées, dégâts par tour,
types immunisés, bonus de capture, attaques qui l'infligent (avec leur chance) et messages de combat.
Les statuts de PSDK (Poison, Brûlure…) sont affichés avec leurs effets. « Nouveau statut » en ajoute un
(numéro 11, 12…).

Enregistré dans `Data/configs/plugins/statuts.json` ; les icônes sont redessinées dans
`graphics/interface/statuts<fr|en|es>.png` (originaux gardés dans `graphics/interface/.pj-statuts-originaux`).

## Commandes (Script)

```ruby
infliger_statut(:bleeding)            # premier Pokémon de l'équipe (s'il n'a pas déjà un statut)
infliger_statut(:bleeding, 2, forcer: true)
a_le_statut?(:bleeding)               # true / false
```

En combat, les autres scripts peuvent utiliser `:bleeding` comme les statuts de PSDK :
`logic.status_change_handler.status_change_with_process(:bleeding, cible, lanceur, attaque)`,
`pokemon.bleeding?`, `pokemon.status_bleeding`, `pokemon.can_be_bleeding?`.

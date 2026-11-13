# Personnages (héros et alliés)

Réglages dans Studio : **Données > Personnages** (Héros, Alliés, Générateur), enregistrés dans
`Data/configs/plugins/personnages.json`. Après un changement des scripts : `construire_plugins.bat`.

## Héros
- Nouvelle partie : le joueur prend le **héros par défaut** (nom, garçon / fille, personnage de la carte, dresseur de dos).
- Commandes d'évent (**Script**) :
  - `choisir_heros` : écran de choix (s'il y a plusieurs héros), puis le nom si « Demander le nom » est coché
  - `choisir_heros(nom: false)` / `choisir_heros(annulable: true)`
  - `changer_heros('hero_2')` : prend ce héros sans écran (`changer_heros('hero_2', nom: true)` donne aussi son nom)
  - `heros_actuel == 'hero_2'` : condition
  - `demander_nom_heros` : écran du nom
- Un héros « Générateur de personnages » ouvre ensuite l'écran du générateur (`personnaliser_joueur`).

## Alliés
Un allié est lié à un dresseur de **Données > Dresseurs** : son équipe (soignée à chaque combat) combat au côté du
héros, en combat double.
- `allie_rejoint('ally_1')` / `allie_quitte` / `allie_actuel` / `allie_present?`
- Réglages par allié : combats contre dresseurs, combats sauvages, suit le héros sur la carte.

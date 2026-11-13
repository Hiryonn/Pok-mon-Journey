# Plugin « variantes » : Pokémon Cuivrés, Argentés, Dorés, Prismatiques et Radiants

## Installation
1. Lance `construire_plugin_variantes.bat` à la racine du projet (une seule fois : il reconstruit aussi
   interface_horizon et pokesmart, puis installe tous les plugins).
2. Studio : `tools/studio-variantes/installer_variantes.bat` (l'éditeur Smartphone doit être installé), puis redémarre Studio.

## Les variantes
- **Cuivré / Argenté / Doré** : le sprite normal est recoloré en jeu (tout cuivre / argent / or) selon sa luminosité.
  Rien à dessiner. Dégradés réglables dans Studio (Données > Pokémon > Variantes > Métaux).
- **Prismatique** : le sprite normal est recoloré en jeu en arc-en-ciel (relief et contours gardés),
  avec un halo lumineux et quelques éclats de cristal autour. Rien à dessiner.
- **Radiant** : sprites recolorés dans Studio (Données > Pokémon > Variantes > Shiny / Radiant) à partir du sprite normal
  ou chromatique : teinte / saturation / luminosité, et chaque couleur de la palette au choix.
  Images écrites dans `graphics/pokedex/pokefrontradiant`, `pokebackradiant`, `pokeiconradiant`
  (même nom que le sprite normal). Un Pokémon sans sprite Radiant ne peut pas être Radiant.
- **Chromatique (shiny)** : même éditeur que les Radiants (Données > Pokémon > Variantes > Shiny / Radiant, onglet
  Chromatique) pour créer ou refaire un sprite chromatique à partir du sprite normal. Images écrites dans
  `graphics/pokedex/pokefrontshiny`, `pokebackshiny`, `pokeiconshiny` ; l'ancien est gardé dans
  `graphics/pokedex/.pj-chromatiques-originaux` (remis si on annule).
- Tirage à chaque nouveau Pokémon : Prismatique, puis Radiant, Doré, Argenté et Cuivré (« 1 chance sur N », 0 = jamais).
- Par défaut une variante compte aussi comme chromatique (étoile, scintillement en combat).
- Les sprites animés (.gif) ne sont pas recolorés : le sprite fixe est utilisé.

## Commandes (Script d'évent)
```ruby
add_pokemon_variant(:pikachu, 10, :gold)       # Pikachu Doré N.10
store_pokemon_variant(:eevee, 5, :radiant)     # envoyé au PC
add_specific_pokemon(id: :pikachu, level: 10, variant: :silver)
set_pokemon_variant(0, :silver)                # 1er de l'équipe ; nil = normal
pokemon_variant(0)                             # :copper, :silver, :gold, :prismatic, :radiant ou nil
```
En Ruby : `pokemon.variant`, `pokemon.variant = :gold`, `pokemon.copper?`, `silver?`, `gold?`, `prismatic?`, `radiant?`, `variant_name`.

## Appli Debug du téléphone
- Pokémon : ligne « Variante donnée » (Normal, Chromatique, Argenté, Doré, Radiant) pour les Pokémon reçus avec A.
- Équipe : X change la variante du Pokémon sélectionné.

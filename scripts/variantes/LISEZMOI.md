# Plugin « variantes » : Pokémon Argentés, Dorés et Radiants

## Installation
1. Lance `construire_plugin_variantes.bat` à la racine du projet (une seule fois : il reconstruit aussi
   interface_pe et pokesmart, puis installe tous les plugins).
2. Studio : `tools/studio-variantes/installer_variantes.bat` (l'éditeur Smartphone doit être installé), puis redémarre Studio.

## Les variantes
- **Argenté / Doré** : le sprite normal est recoloré en jeu (tout argent / tout or) selon sa luminosité.
  Rien à dessiner. Dégradés réglables dans Studio (Plugins > Variantes > Argenté, Doré & taux).
- **Radiant** : sprites recolorés dans Studio (Plugins > Variantes > Radiant) à partir du sprite normal
  ou chromatique : teinte / saturation / luminosité, et chaque couleur de la palette au choix.
  Images écrites dans `graphics/pokedex/pokefrontradiant`, `pokebackradiant`, `pokeiconradiant`
  (même nom que le sprite normal). Un Pokémon sans sprite Radiant ne peut pas être Radiant.
- Tirage à chaque nouveau Pokémon : Radiant, puis Doré, puis Argenté (« 1 chance sur N », 0 = jamais).
- Par défaut une variante compte aussi comme chromatique (étoile, scintillement en combat).
- Les sprites animés (.gif) ne sont pas recolorés : le sprite fixe est utilisé.

## Commandes (Script d'évent)
```ruby
add_pokemon_variant(:pikachu, 10, :gold)       # Pikachu Doré N.10
store_pokemon_variant(:eevee, 5, :radiant)     # envoyé au PC
add_specific_pokemon(id: :pikachu, level: 10, variant: :silver)
set_pokemon_variant(0, :silver)                # 1er de l'équipe ; nil = normal
pokemon_variant(0)                             # :copper, :silver, :gold, :radiant ou nil
```
En Ruby : `pokemon.variant`, `pokemon.variant = :gold`, `pokemon.copper?`, `silver?`, `gold?`, `radiant?`, `variant_name`.

## Appli Debug du téléphone
- Pokémon : ligne « Variante donnée » (Normal, Chromatique, Argenté, Doré, Radiant) pour les Pokémon reçus avec A.
- Équipe : X change la variante du Pokémon sélectionné.

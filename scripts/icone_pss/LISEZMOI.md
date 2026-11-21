# Icône PSS (en jeu)

La photo de profil du mode en ligne. **Indépendante du générateur de personnages** : l'icône n'a rien à voir avec le
personnage du joueur, et les deux n'utilisent pas les mêmes pièces ni les mêmes réglages.

## Mise en place

1. Les pièces sont déjà découpées (`graphics/icones_pss/pieces`, catalogue `Data/configs/plugins/icone_pss_pieces.json`).
   Pour les refaire depuis la planche : `python tools/pss-icones/decouper_planches.py` (voir `tools/pss-icones/LISEZMOI.md`).
2. Lancer `construire_plugins.bat`.
3. Dans un évènement, commande **Script** :
   - `creer_icone_pss` : écran de création (le joueur doit valider)
   - `creer_icone_pss(true)` : idem, B annule
   - `icone_pss_creee?` : condition, le joueur a déjà créé son icône
   - `icone_pss_au_hasard` / `icone_pss_au_hasard('a')` : icône au hasard, sans écran (série `'a'` ou `'b'`)

Le réglage de l'icône est sauvegardé avec la partie (`$user_data[:pss_icone]`).
Pense à inclure `graphics/icones_pss/pieces` dans la version distribuée du jeu.

## Écran de création

Catégories : Série, Visage (peau et yeux), Haut, Coiffure (modèle et couleur), Détails (sourcils, frange), Chapeau, Accessoire.
La coiffure et le chapeau sont obligatoires ; l'accessoire est dessiné par-dessus le chapeau ; les sourcils ont leur propre couleur (ou celle des cheveux).
▲▼ change de catégorie, ◄► change le choix de la carte au bord jaune, A passe d'une carte à l'autre,
X tire au hasard, Y termine, B annule (si `creer_icone_pss(true)`).
La frange n'existe que dans la série A.

## Pour le mode en ligne

L'icône est assemblée à la volée à partir de son réglage, aucune image n'est envoyée : seul un court texte l'est.

```ruby
code = IconePss.to_code(IconePss.spec)   # ex. "a.1.2.-1.3.0.1.-1.5.4" : à envoyer avec le profil
spec = IconePss.from_code(code)          # chez l'autre joueur (nil si le texte est invalide)
texture = IconePss.compose_texture(spec) # image de 40x40 (à libérer avec texture.dispose)
IconePss.texture                         # icône du joueur, gardée en cache
```

## Fichiers

| Fichier | Rôle |
|---|---|
| `00100 Configuration.rb` | catalogue, règles d'assemblage, réglage du joueur, code texte |
| `00101 Assemblage.rb` | image / texture assemblée |
| `00102 Commandes.rb` | commandes d'évent |
| `00103 Scene.rb` | écran de création |

Les mêmes règles d'assemblage sont dans l'outil Studio (`tools/studio-pss/pj-pss-logic.js`) : une icône créée dans
Studio et la même icône créée en jeu sont identiques.

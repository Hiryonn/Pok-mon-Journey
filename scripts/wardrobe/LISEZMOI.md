# Wardrobe (tenues préfaites)

Des tenues toutes faites pour le héros. Une tenue est un **objet** du sac auquel on associe soit des **sprites tout faits** (charset +
image de face, comme celles de Félix et d'Ann), soit des **pièces du générateur** de personnages (haut, bas, chapeau, sac, coiffure +
couleurs). Pas de personnalisation : porter une tenue change l'apparence d'un bloc ; le genre et la peau du personnage ne changent pas. Le joueur peut toujours revenir à son apparence d'origine (« Ma tenue »).

Prérequis : le générateur (pièces préparées dans Studio) et, pour l'onglet du sac, le sac PE (`interface_pe`). Installer ce plugin
après `interface_pe` (c'est l'ordre de `construire_plugins.bat`).

## Ajouter une tenue
**Le plus simple : la page Studio « Plugins > Tenues »** (`tools/studio-wardrobe`, `installer_wardrobe.bat`). Elle écrit
`Data/configs/plugins/wardrobe.json`, lu par le plugin, et peut créer l'objet. À la main, c'est ci-dessous (la page et `OUTFITS`
dans `00100 Configuration.rb` se complètent ; pour un même objet, le fichier JSON gagne).
1. **Studio** : créer un objet (ex. dbSymbol `tenue_sport`, nom, description, icône). Le mettre par exemple dans les objets rares.
2. **`00100 Configuration.rb`** : ajouter l'objet à `OUTFITS`. L'objet devient une tenue.
   Tenue toute faite (comme Félix et Ann) :
   ```ruby
   {'item' => :tenue_felix, 'name' => ['Tenue de Félix', 'Felix\'s outfit'], 'gender' => 'm',
    'sprites' => {'charset' => 'NPC_Felix', 'front' => 'Felix'}}
   ```
   `charset` : image de marche dans `graphics/characters` (4x4 images ; elle sert aussi pour la course, le vélo et la nage),
   `front` : image de face (80x80) dans `graphics/pictures`, utilisée par le dresseur `pj_joueur_front`. Le dos en combat reste celui du
   personnage du générateur (pas d'image de dos fournie). L'icône de l'objet est la première case du charset (`graphics/icons/<objet>.png`).
   Tenue avec des pièces du générateur :
   ```ruby
   {'item' => :tenue_sport, 'name' => ['Tenue de sport', 'Sportswear'], 'gender' => nil,
    'description' => ['Pour courir partout.', 'For running everywhere.'],
    'pieces' => {'top' => {'key' => 'tank top', 'color' => 'red'}, 'bottom' => {'key' => 'capris', 'color' => 'black'}, 'hat' => nil}}
   ```
   `pieces` : `top`, `bottom`, `hat`, `bag`, `hair` ; `nil` retire le chapeau / le sac ; une pièce absente reste comme elle est.
   Les clés et couleurs sont celles du générateur. `gender` : `'m'`, `'f'` ou `nil` (les deux). `name` et `description` sont facultatifs
   (ceux de l'objet sont alors utilisés).
   **Astuce** : habille le héros avec le générateur, puis lance `tenue_actuelle_en_texte` : la ligne à copier est écrite dans la console.
3. **Donner l'objet** au joueur comme n'importe quel objet (trouvé, acheté, reçu) ou avec `donner_tenue(:tenue_sport)`.
Félix (`tenue_felix`, garçons) et Ann (`tenue_ann`, filles) sont déjà dans `wardrobe.json` ; leurs objets (ids 2749 et 2750, poche des objets rares),
icônes et textes (`Data/Text/Dialogs/100012.csv` et `100013.csv`) sont fournis. Les textes sont recompilés par Studio / au lancement du jeu.

## Où le joueur choisit sa tenue
- **Onglet « Tenues » du sac** (après la dernière poche, dès qu'il possède une tenue) : montre les objets-tenues ; **A** enfile la tenue,
  **A** sur la tenue portée retrouve l'apparence d'origine. Le titre indique la tenue portée.
- **Salle d'essayage** (commande `ouvrir_wardrobe`) : haut / bas choisit, le héros essaie la tenue dans l'alcôve, **A** ferme le rideau,
  change le héros et rouvre le rideau, **B** quitte. La première ligne « Ma tenue » est l'apparence d'origine ; un marqueur rose indique
  ce que le héros porte.

## Commandes d'évent (Script)
```ruby
ouvrir_wardrobe                 # la salle d'essayage ; vrai si le héros a changé de tenue
porter_tenue(:tenue_sport)      # enfile la tenue sans écran
retirer_tenue                   # retrouve l'apparence d'origine
tenue_portee                    # dbSymbol de la tenue portée, ou nil
tenue_portee?(:tenue_sport)     # condition d'évent
possede_tenue?(:tenue_sport)    # condition d'évent : l'objet est dans le sac
donner_tenue(:tenue_sport)      # ajoute l'objet au sac (une seule fois)
nombre_tenues                   # combien de tenues le joueur peut porter
tenue_actuelle_en_texte         # la tenue du héros, prête à coller dans OUTFITS
```

## À savoir
- L'apparence d'origine est mémorisée au premier changement. Si le joueur repasse par le générateur, ce nouveau personnage devient
  l'origine. Tout est sauvegardé avec la partie (`$user_data[:wardrobe]`).
- Repasser par le générateur (`personnaliser_joueur`) retire la tenue toute faite : le personnage retrouve ses propres sprites.
- Une tenue n'est proposée qu'aux héros du bon genre ; une pièce inconnue du générateur est ignorée (message dans `Error.log`).
- Si l'onglet du sac pose problème (autre version de PSDK), il se désactive tout seul et le sac reste normal ;
  `Wardrobe::TAB_ENABLED = false` le retire.
- Le rideau (`rideau_1` à `9`) est ancré au bord droit de l'alcôve ; la salle est adaptée de la planche (le panneau recouvre la droite).
  Images : `graphics/interface/wardrobe/` et `graphics/interface/bag_pe/tab_9.png`.

## Fichiers
| Fichier | Rôle |
|---|---|
| `00100 Configuration.rb` | lecture de `wardrobe.json` et de `OUTFITS`, données, habillage, sauvegarde |
| `Data/configs/plugins/wardrobe.json` | les tenues (écrit par la page Studio) |
| `tools/studio-wardrobe/` | la page Studio « Tenues » |
| `00101 Scene Wardrobe.rb` | la salle d'essayage |
| `00102 Commandes.rb` | commandes d'évent |
| `00103 Sac.rb` | l'onglet « Tenues » du sac PE |
| `tools/wardrobe/preparer_wardrobe.py` | prépare les images depuis `tools/wardrobe/planche/` |

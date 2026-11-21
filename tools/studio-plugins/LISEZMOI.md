# Pages des plugins dans Pokémon Studio

`patch_studio_pages.py` modifie Studio (fichier `index-xxxx.js`) pour que les éditeurs du projet soient de vraies pages :

- onglet **Plugins** dans la barre de gauche (icône pièce de puzzle, sous Monde), avec son menu :
  Advanced Pokédex, Smartphone, Triple Triad, Variantes… ;
- **Monde > Événements** : la page et la liste de gauche sont celles de l'éditeur d'événements.

Après une mise à jour de Studio : `installer_studio_extra.bat` à la racine du projet (réinstalle tout, voir `tools\studio-extra\LISEZMOI.md`).
Seul : `installer_pages.bat` (Studio fermé). Une copie du fichier d'origine
est gardée (`index-xxxx.js.bak-pages`).

## Ajouter une page de plugin

Pas besoin de relancer le script : un script `pj-*.js` chargé par Studio s'inscrit et remplit sa page.

```js
(window.pjPluginPages = window.pjPluginPages || []).push({ id: 'mon-plugin', label: 'Mon plugin' });
window.dispatchEvent(new Event('pj-plugin-pages'));
// la page est la balise #pj-page-mon-plugin (créée par Studio quand on ouvre Plugins > Mon plugin)
// window.pjNavigate('/plugins/mon-plugin') ouvre la page
```

## Dossiers des icônes

`patch_studio_icons.py` (lancé aussi par `installer_pages.bat`) : Studio range les icônes comme les sprites —
`graphics/pokedex/pokeicon` (normales), `pokeiconshiny` (chromatiques), `pokeiconegg` (œufs). Une icône choisie dans
Studio est copiée dans le bon dossier.

`ranger_icones.bat` déplace les icônes déjà dans `pokeicon` (une image aussi utilisée comme icône normale est copiée).

En jeu : `scripts/10000 Dossiers des icones.rb` (une icône absente de `pokeicon` est cherchée dans `pokeiconshiny` puis
`pokeiconegg`).

## Onglet Générateurs

Sous l'onglet Plugins (icône baguette magique). Une page s'y inscrit avec `place: 'generator'` :

```js
(window.pjPluginPages = window.pjPluginPages || []).push({ id: 'personnages', label: 'Personnages', place: 'generator' });
```

Générateur de personnages : `tools/studio-generateur` (installer_generateur.bat).

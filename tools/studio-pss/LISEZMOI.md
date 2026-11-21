# Générateur d'icônes PSS (Pokémon Studio)

Onglet **Générateurs > Icônes PSS** : crée la photo de profil (icône de 40x40) du mode en ligne.
Indépendant du générateur de personnages (`tools/studio-generateur`) : il a ses propres pièces et ses propres fichiers.

## Réglages

Série (A ou B), peau, yeux, sourcils (couleur au choix, ou « Comme les cheveux »), couleur du haut, coiffure et couleur des cheveux, frange (série A), chapeau, accessoire.
La **coiffure** et le **chapeau** sont obligatoires ; la frange et l'accessoire sont facultatifs. L'accessoire est dessiné **par-dessus** le chapeau.
Chaque réglage a un cadenas : « 🎲 Au hasard » (Ctrl+R) garde les réglages verrouillés.

**Enregistrer l'icône** écrit `graphics/icones_pss/icones/<nom>.png` (40x40) et garde le réglage dans
`Data/configs/pss_icones.json` (liste « Icônes enregistrées » : cliquer sur une icône la reprend, « Oublier » la retire de
la liste sans supprimer le .png).

## Installation

1. Les pièces doivent exister : `graphics/icones_pss/pieces` et `Data/configs/plugins/icone_pss_pieces.json`
   (`python tools/pss-icones/decouper_planches.py`).
2. `tools/studio-plugins/installer_pages.bat` (onglet Générateurs), puis `installer_pss.bat`, Studio fermé.
3. Rouvrir Studio. À relancer après chaque mise à jour de Studio.

## Fichiers

| Fichier | Rôle |
|---|---|
| `pj-pss-main.js` | lecture des pièces et écriture des icônes (canaux `pj-pss:*`) |
| `pj-pss-logic.js` | règles d'assemblage (mêmes que le plugin en jeu, testables avec Node) |
| `pj-pss.js`, `pj-pss.css` | la page |
| `installer_pss.bat` / `.ps1` | installation dans Studio |

/* eslint-disable */
// =============================================================================
// Générateur d'icônes PSS — règles d'assemblage (sans interface, testable avec Node)
// Mêmes règles que le plugin en jeu (scripts/icone_pss/scripts/00101 Assemblage.rb).
//
// Réglage d'une icône (spec) :
//   { serie: 'a'|'b', peau: n, yeux: n, haut: n (couleur), coiffure: n (-1 : aucune), couleur_cheveux: n,
//     frange: n (couleur, -1 : aucune), accessoire: n (-1 : aucun), chapeau: n (-1 : aucun) }
// Couches, de l'arrière vers l'avant : cheveux (arrière), haut, peau, yeux, frange, cheveux (avant), accessoire, chapeau.
// =============================================================================
(function (root, factory) {
  const api = factory();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.pjPssLogic = api;
})(typeof window !== 'undefined' ? window : this, () => {
  const mod = (n, len) => (len > 0 ? ((n % len) + len) % len : 0);
  const serieOf = (catalog, id) => (catalog.series || []).find((s) => s.id === id) || (catalog.series || [])[0];

  // tous les accessoires d'une série, à plat : [{ file, genre, label }]
  function accessories(serie) {
    const out = [];
    (serie.accessoires || []).forEach((g) => (g.fichiers || []).forEach((file) => out.push({ file, genre: g.genre, label: g.label })));
    return out;
  }

  // ramène chaque choix dans les valeurs possibles de la série
  function fixSpec(catalog, spec) {
    const s = serieOf(catalog, spec.serie);
    spec.serie = s.id;
    spec.peau = mod(spec.peau | 0, s.peau.length);
    spec.yeux = mod(spec.yeux | 0, s.yeux.length);
    spec.haut = mod(spec.haut | 0, s.hauts.length);
    const style = spec.coiffure | 0;
    spec.coiffure = style >= 0 && style < s.cheveux.length ? style : -1;
    spec.couleur_cheveux = spec.coiffure < 0 ? 0 : Math.min(Math.max(spec.couleur_cheveux | 0, 0), s.cheveux[spec.coiffure].couleurs.length - 1);
    const fr = spec.frange | 0;
    spec.frange = fr >= 0 && fr < s.frange.length ? fr : -1;
    const acc = spec.accessoire | 0;
    spec.accessoire = acc >= 0 && acc < accessories(s).length ? acc : -1;
    const hat = spec.chapeau | 0;
    spec.chapeau = hat >= 0 && hat < s.chapeaux.length ? hat : -1;
    return spec;
  }

  // fichiers à superposer, dans l'ordre
  function layers(catalog, spec) {
    const s = serieOf(catalog, spec.serie);
    const out = [];
    const hair = spec.coiffure >= 0 ? s.cheveux[spec.coiffure].couleurs[spec.couleur_cheveux] : null;
    if (hair && hair.arriere) out.push(hair.arriere);
    out.push(s.hauts[spec.haut], s.peau[spec.peau], s.yeux[spec.yeux]);
    if (spec.frange >= 0 && s.frange[spec.frange]) out.push(s.frange[spec.frange]);
    if (hair && hair.avant) out.push(hair.avant);
    if (spec.accessoire >= 0) out.push(accessories(s)[spec.accessoire].file);
    if (spec.chapeau >= 0) out.push(s.chapeaux[spec.chapeau]);
    return out.filter(Boolean);
  }

  const pick = (n, rnd) => Math.floor(rnd() * n);
  // icône au hasard ; `locks` : réglages à garder tels quels ({ haut: true, … })
  function randomSpec(catalog, previous, locks, rnd) {
    rnd = rnd || Math.random;
    locks = locks || {};
    const prev = previous || {};
    const keep = (k) => locks[k] && prev[k] !== undefined;
    const spec = { serie: keep('serie') ? prev.serie : catalog.series[pick(catalog.series.length, rnd)].id };
    const s = serieOf(catalog, spec.serie);
    spec.peau = keep('peau') ? prev.peau : pick(s.peau.length, rnd);
    spec.yeux = keep('yeux') ? prev.yeux : pick(s.yeux.length, rnd);
    spec.haut = keep('haut') ? prev.haut : pick(s.hauts.length, rnd);
    spec.coiffure = keep('coiffure') ? prev.coiffure : (rnd() < 0.05 ? -1 : pick(s.cheveux.length, rnd));
    spec.couleur_cheveux = keep('couleur_cheveux') ? prev.couleur_cheveux : pick(5, rnd);
    spec.frange = keep('frange') ? prev.frange : (s.frange.length && rnd() < 0.3 ? pick(s.frange.length, rnd) : -1);
    const accs = accessories(s);
    spec.accessoire = keep('accessoire') ? prev.accessoire : (accs.length && rnd() < 0.35 ? pick(accs.length, rnd) : -1);
    spec.chapeau = keep('chapeau') ? prev.chapeau : (s.chapeaux.length && rnd() < 0.3 ? pick(s.chapeaux.length, rnd) : -1);
    return fixSpec(catalog, spec);
  }

  return { serieOf, accessories, fixSpec, layers, randomSpec };
});

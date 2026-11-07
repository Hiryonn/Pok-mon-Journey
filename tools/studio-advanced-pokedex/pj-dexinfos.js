/* eslint-disable */
// =============================================================================
// Infos Pokédex — ajout à la page « Pokémon » de Pokémon Studio (plugin « advanced_pokedex »)
// Ajoute un bloc « Couleur, habitat, génération » à côté du bloc « Pokédex » du Pokémon affiché.
// Un clic ouvre une fenêtre de réglage ; Valider écrit aussitôt Data/configs/plugins/pokedex_infos.json.
//   { "klass": "PokedexInfosConfig", "creatures": { "bulbasaur": { "color": "green", "habitat": "grassland",
//     "generation": 1, "forms": { "1": { "color": "…" } } } } }
// Génération 0 = Fakemon. Sans génération choisie : celle du n° national (1 à 1025), sinon 0.
// =============================================================================
(() => {
  'use strict';
  if (window.__pjDexInfosLoaded) return;
  window.__pjDexInfosLoaded = true;

  // Listes (les mêmes que PokedexInfos dans le plugin)
  const COLORS = [
    ['red', 'Rouge', '#e0493e'], ['blue', 'Bleu', '#3f7fe0'], ['yellow', 'Jaune', '#efcf3a'], ['green', 'Vert', '#4cb04c'],
    ['black', 'Noir', '#303030'], ['brown', 'Marron', '#9a6b3c'], ['purple', 'Violet', '#9a5bc4'], ['gray', 'Gris', '#9a9aa4'],
    ['white', 'Blanc', '#f0f0f0'], ['pink', 'Rose', '#f08cc0'],
  ];
  const HABITATS = [
    ['grassland', 'Plaine'], ['forest', 'Forêt'], ['waters-edge', "Bord de l'eau"], ['sea', 'Mer'], ['cave', 'Grotte'],
    ['mountain', 'Montagne'], ['rough-terrain', 'Terrain accidenté'], ['urban', 'Ville'], ['rare', 'Rare'],
  ];
  // Dernier n° national de chaque génération
  const GEN_LAST = [151, 251, 386, 493, 649, 721, 809, 905, 1025];
  const autoGeneration = (id) => { const i = GEN_LAST.findIndex((last) => id <= last); return id > 0 && i >= 0 ? i + 1 : 0; };
  const genLabel = (g) => (g === 0 ? 'Génération 0 (Fakemon)' : `Génération ${g}`);
  const colorLabel = (k) => { const c = COLORS.find(([key]) => key === k); return c ? c[1] : k; };
  const habitatLabel = (k) => { const c = HABITATS.find(([key]) => key === k); return c ? c[1] : k; };

  const api = window.pjAdex;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API Advanced Pokédex n'est pas disponible : relance l'installateur puis redémarre Studio.");
    const r = await api[name](payload);
    if (!r || !r.ok) throw new Error((r && r.error) || 'Erreur inconnue');
    return r.value;
  };
  function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    if (attrs) {
      for (const [k, v] of Object.entries(attrs)) {
        if (v === undefined || v === null || v === false) continue;
        if (k === 'class') el.className = v;
        else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
        else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2).toLowerCase(), v);
        else if (k === 'value') el.value = v;
        else if (k === 'checked') el.checked = !!v;
        else if (k === 'selected') el.selected = !!v;
        else el.setAttribute(k, v === true ? '' : v);
      }
    }
    const add = (c) => {
      if (c === null || c === undefined || c === false) return;
      if (Array.isArray(c)) c.forEach(add);
      else el.appendChild(c instanceof Node ? c : document.createTextNode(String(c)));
    };
    kids.forEach(add);
    return el;
  }
  function toast(msg, err) {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    setTimeout(() => t.remove(), err ? 6000 : 2500);
  }
  const projectPath = () => { try { return (JSON.parse(localStorage.getItem('projectList') || '[]')[0] || {}).projectPath || null; } catch (e) { return null; } };

  // ---------------------------------------------------------------------------
  // Données : fichier pokedex_infos.json (chargé une fois par projet)
  // ---------------------------------------------------------------------------
  const S = { path: null, data: null, loading: null };
  async function data() {
    const p = projectPath();
    if (S.data && S.path === p) return S.data;
    if (!S.loading || S.path !== p) {
      S.path = p;
      S.loading = call('getInfos', { projectPath: p }).then((d) => {
        S.data = d && typeof d === 'object' ? d : {};
        if (!S.data.creatures || typeof S.data.creatures !== 'object') S.data.creatures = {};
        S.data.klass = 'PokedexInfosConfig';
        return S.data;
      }).catch((e) => { S.loading = null; throw e; });
    }
    return S.loading;
  }
  // valeurs d'une forme (la forme hérite de l'espèce)
  function infosOf(d, db, form) {
    const base = (d.creatures && d.creatures[db]) || {};
    const own = (base.forms && base.forms[String(form)]) || {};
    const pick = (k) => (own[k] !== undefined && own[k] !== '' && own[k] !== null ? own[k] : base[k]);
    return { color: pick('color') || '', habitat: pick('habitat') || '', generation: pick('generation'), own };
  }

  // ---------------------------------------------------------------------------
  // Pokémon affiché : état global de Studio (selectedDataIdentifier.pokemon), lu dans l'arbre React
  // ---------------------------------------------------------------------------
  function stateFromValue(value) {
    if (!value || typeof value !== 'object') return null;
    if (value.selectedDataIdentifier) return value;
    if (Array.isArray(value) && value[0] && value[0].selectedDataIdentifier) return value[0];
    for (const key of Reflect.ownKeys(value)) {
      let v;
      try { v = value[key]; } catch (e) { continue; }
      if (!v || typeof v !== 'object') continue;
      if (v.selectedDataIdentifier) return v;
      if (v.current && v.current.selectedDataIdentifier) return v.current;
      if (v.v && v.v.current && v.v.current.selectedDataIdentifier) return v.v.current;
    }
    return null;
  }
  function studioState(el) {
    const key = el && Object.keys(el).find((k) => k.startsWith('__reactFiber$'));
    let fiber = key && el[key];
    for (let i = 0; fiber && i < 400; i++, fiber = fiber.return) {
      const st = stateFromValue(fiber.memoizedProps && fiber.memoizedProps.value);
      if (st) return st;
      // état gardé par un hook (useState / useReducer) du composant qui fournit le contexte
      let hook = fiber.memoizedState;
      for (let j = 0; hook && typeof hook === 'object' && j < 30; j++, hook = hook.next) {
        const v = hook.memoizedState;
        const found = (v && v.selectedDataIdentifier && v) || stateFromValue(v);
        if (found) return found;
      }
    }
    return null;
  }
  function selected(el) {
    const st = studioState(el);
    const sel = st && st.selectedDataIdentifier && st.selectedDataIdentifier.pokemon;
    if (!sel) return null;
    const creature = st.projectData && st.projectData.pokemon && st.projectData.pokemon[sel.specie];
    return { db: sel.specie, form: sel.form | 0, id: creature ? creature.id : 0 };
  }

  // ---------------------------------------------------------------------------
  // Bloc ajouté à la page Pokémon (copie du bloc « Pokédex » pour garder le style de Studio)
  // ---------------------------------------------------------------------------
  // Bloc « Pokédex » de la page Pokémon : enfant de la grille des blocs (Pokédex, Évolution, Talents, Expérience…),
  // titre « Pokédex », contient Taille (m) et Poids (kg). Le menu de gauche (lien « Pokédex ») est ignoré.
  function databaseMenu() {
    const quests = document.querySelector('a[href$="/database/quests"]');
    return quests && quests.parentElement && quests.parentElement.parentElement;
  }
  function findPokedexBlock() {
    const menu = databaseMenu();
    const titles = [...document.querySelectorAll('h1, h2, h3, h4, span, div, p')]
      .filter((el) => el.childElementCount === 0 && el.textContent.trim() === 'Pokédex'
        && !el.closest('a, #pjs-root, #pjv-root, #pjx-root, [data-pjd-block], .pjd-overlay') && !(menu && menu.contains(el)));
    for (const title of titles) {
      let block = title;
      for (let up = 0; up < 6 && block.parentElement; up++) {
        const grid = block.parentElement;
        // la grille contient d'autres blocs (Évolution, Talents, Expérience…)
        if (grid.children.length >= 3 && /Talent|Évolution|Expérience/.test(grid.textContent)) {
          const text = block.textContent;
          const small = text.length < 200 && block.querySelectorAll('*').length < 60;
          if (small && / kg/.test(text) && /\d\s?m/.test(text)) return { block, title };
          break;
        }
        block = grid;
      }
    }
    return null;
  }

  let current = null; // { db, form, id }
  function update() {
    const found = findPokedexBlock();
    if (!found) return;
    const { block, title } = found;
    let mine = block.parentElement.querySelector(':scope > [data-pjd-block]');
    if (!mine) {
      mine = block.cloneNode(true);
      mine.setAttribute('data-pjd-block', '1');
      mine.removeAttribute('id');
      // titre
      const leaves = [...mine.querySelectorAll('*')].filter((el) => el.childElementCount === 0 && el.textContent.trim());
      const titleLeaf = leaves.find((el) => el.textContent.trim() === 'Pokédex');
      if (titleLeaf) titleLeaf.textContent = 'Couleur, habitat, génération';
      // 3 lignes : libellé / valeur
      const rows = leaves.filter((el) => el !== titleLeaf);
      mine._rows = [];
      for (let i = 0; i + 1 < rows.length && mine._rows.length < 3; i += 2) mine._rows.push([rows[i], rows[i + 1]]);
      ['Couleur', 'Habitat', 'Génération'].forEach((l, i) => { if (mine._rows[i]) mine._rows[i][0].textContent = l; });
      mine.style.cursor = 'pointer';
      mine.title = 'Couleur, habitat et génération du Pokémon (plugin Advanced Pokédex)';
      mine.addEventListener('click', (e) => { e.preventDefault(); e.stopPropagation(); openDialog(); });
      // nouvelle case à la fin des blocs de la page Pokémon
      block.parentElement.appendChild(mine);
    }
    const sel = selected(block) || selected(title);
    if (!sel) { setRows(mine, ['?', '?', '?']); return; }
    const key = `${sel.db}/${sel.form}`;
    if (mine._key === key && mine._version === version) return;
    mine._key = key; mine._version = version;
    current = sel;
    data().then((d) => {
      if (mine._key !== key) return;
      const inf = infosOf(d, sel.db, sel.form);
      const gen = inf.generation === undefined || inf.generation === null || inf.generation === '' ? null : inf.generation | 0;
      setRows(mine, [
        inf.color ? colorLabel(inf.color) : '—',
        inf.habitat ? habitatLabel(inf.habitat) : '—',
        gen === null ? `${autoGeneration(sel.id)} (auto)` : (gen === 0 ? '0 (Fakemon)' : String(gen)),
      ]);
    }).catch((e) => setRows(mine, ['!', '!', e.message.slice(0, 40)]));
  }
  let version = 0;
  function setRows(mine, values) {
    (mine._rows || []).forEach(([, value], i) => { if (value.textContent !== values[i]) value.textContent = values[i]; });
  }

  // ---------------------------------------------------------------------------
  // Fenêtre de réglage
  // ---------------------------------------------------------------------------
  async function openDialog() {
    const sel = current;
    if (!sel) { toast('Pokémon affiché introuvable', true); return; }
    let d;
    try { d = await data(); } catch (e) { toast('Lecture impossible : ' + e.message, true); return; }
    const entry = d.creatures[sel.db] || {};
    const formOwn = sel.form !== 0 && entry.forms && entry.forms[String(sel.form)];
    const target = { scope: formOwn ? 'form' : 'species' };
    const read = () => (target.scope === 'form' ? Object.assign({}, entry, (entry.forms || {})[String(sel.form)] || {}) : entry);
    let v = read();

    const overlay = h('div', { class: 'pjd-overlay' });
    const close = () => overlay.remove();
    overlay.addEventListener('mousedown', (e) => { if (e.target === overlay) close(); });

    const colorWrap = h('div', { class: 'pjd-colors' });
    const habitatSel = h('select', { class: 'pjs-select pjd-wide' });
    const habitatFree = h('input', { class: 'pjs-input pjd-wide', placeholder: 'Habitat personnalisé (ex. volcan)' });
    const genInput = h('input', { class: 'pjs-input num', type: 'number', min: 0, max: 99, step: 1, placeholder: String(autoGeneration(sel.id)) });
    const genInfo = h('span', { class: 'pjs-hint inline' });
    let color = '';
    const fill = () => {
      v = read();
      color = v.color || '';
      colorWrap.textContent = '';
      [['', 'Aucune', null]].concat(COLORS).forEach(([key, label, hex]) => {
        const b = h('button', { class: 'pjd-color' + (color === key ? ' active' : ''), title: label, onclick: () => { color = key; [...colorWrap.children].forEach((c) => c.classList.toggle('active', c === b)); } },
          hex ? h('span', { class: 'pjd-dot', style: { background: hex } }) : null, label);
        colorWrap.appendChild(b);
      });
      const hab = v.habitat || '';
      const known = !hab || HABITATS.some(([k]) => k === hab);
      habitatSel.textContent = '';
      [['', 'Aucun']].concat(HABITATS).concat([['__custom', 'Autre…']]).forEach(([k, l]) => habitatSel.appendChild(h('option', { value: k, selected: known ? k === hab : k === '__custom' }, l)));
      habitatFree.value = known ? '' : hab;
      habitatFree.style.display = known ? 'none' : '';
      genInput.value = v.generation === undefined || v.generation === null || v.generation === '' ? '' : v.generation;
      showGen();
    };
    const showGen = () => {
      const g = genInput.value === '' ? null : Math.max(0, parseInt(genInput.value, 10) || 0);
      genInfo.textContent = g === null ? `vide : ${genLabel(autoGeneration(sel.id))} (d'après le n° ${sel.id})` : genLabel(g);
    };
    habitatSel.addEventListener('change', () => { habitatFree.style.display = habitatSel.value === '__custom' ? '' : 'none'; if (habitatSel.value === '__custom') habitatFree.focus(); });
    genInput.addEventListener('input', showGen);

    const scope = sel.form !== 0 ? h('div', { class: 'pjs-variants' }, [['species', 'Toute l\'espèce'], [`form`, `Forme ${sel.form} seulement`]].map(([k, l]) => {
      const b = h('button', { class: 'pjs-variant' + (target.scope === k ? ' active' : ''), onclick: () => { target.scope = k; [...b.parentElement.children].forEach((c) => c.classList.toggle('active', c === b)); fill(); } }, l);
      return b;
    })) : null;

    const save = async () => {
      const habitat = habitatSel.value === '__custom' ? habitatFree.value.trim() : habitatSel.value;
      const generation = genInput.value === '' ? null : Math.max(0, parseInt(genInput.value, 10) || 0);
      const values = { color: color || undefined, habitat: habitat || undefined, generation: generation === null ? undefined : generation };
      const e = d.creatures[sel.db] = d.creatures[sel.db] || {};
      let dest = e;
      if (target.scope === 'form') { e.forms = e.forms || {}; dest = e.forms[String(sel.form)] = e.forms[String(sel.form)] || {}; }
      ['color', 'habitat', 'generation'].forEach((k) => { if (values[k] === undefined) delete dest[k]; else dest[k] = values[k]; });
      if (e.forms) { Object.keys(e.forms).forEach((f) => { if (!Object.keys(e.forms[f]).length) delete e.forms[f]; }); if (!Object.keys(e.forms).length) delete e.forms; }
      if (!Object.keys(e).length) delete d.creatures[sel.db];
      try {
        await call('saveInfos', { projectPath: S.path, data: d });
        version++;
        toast('Couleur, habitat et génération enregistrés');
        close();
        update();
      } catch (err) { toast('Enregistrement impossible : ' + err.message, true); }
    };

    overlay.appendChild(h('div', { class: 'pjd-dialog' },
      h('div', { class: 'pjd-head' }, h('h2', null, 'Couleur, habitat, génération'), h('span', { class: 'pjs-hint inline' }, `${sel.db}${sel.form ? ` (forme ${sel.form})` : ''}`)),
      scope,
      h('div', { class: 'pjs-label' }, 'Couleur (Pokédex)'), colorWrap,
      h('div', { class: 'pjs-label' }, 'Habitat'), habitatSel, habitatFree,
      h('div', { class: 'pjs-label' }, 'Génération'), h('div', { class: 'pjs-inline' }, genInput, genInfo),
      h('div', { class: 'pjs-hint' }, '0 = Fakemon. Vide : génération du n° national (1 à 1025), 0 au-delà. Enregistré dans Data/configs/plugins/pokedex_infos.json (en jeu : pokemon.dex_color, dex_habitat, dex_generation).'),
      h('div', { class: 'pjd-actions' },
        h('button', { class: 'pjs-btn secondary', onclick: close }, 'Annuler'),
        h('button', { class: 'pjs-btn primary', onclick: save }, 'Valider'))));
    fill();
    overlay.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); if (e.key === 'Enter' && e.target.tagName !== 'SELECT') save(); });
    document.body.appendChild(overlay);
    genInput.focus();
  }

  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; try { update(); } catch (e) { /* page en cours de rendu */ } }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true, characterData: true }); update(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  window.pjDexInfos = { update, data, autoGeneration };
})();

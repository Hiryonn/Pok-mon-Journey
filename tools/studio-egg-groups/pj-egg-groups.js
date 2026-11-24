/* eslint-disable */
// =============================================================================
// Groupes d'Œuf — page « Données > Pokémon > Groupes d'Œuf » de Pokémon Studio (plugin « egg_groups »)
//   Groupes : les 15 groupes de PSDK + les groupes créés ici ; pour chacun, les Pokémon qui en font partie
//   (ceux de Studio, et ceux ajoutés ici : espèce ou forme précise).
//   Exceptions : recettes (deux espèces donnent l'œuf d'une autre) et œufs par encens (bébés).
// Enregistre Data/configs/plugins/egg_groups.json. Style de l'éditeur Smartphone (classes pjs-*).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjEggGroupsLoaded) return;
  window.__pjEggGroupsLoaded = true;

  const PAGE_ID = 'egg-groups';
  const BUILTIN = [
    [1, 'Monstre'], [2, 'Eau 1'], [3, 'Insecte'], [4, 'Vol'], [5, 'Terrestre'], [6, 'Fée'], [7, 'Végétal'], [8, 'Humanoïde'],
    [9, 'Eau 3'], [10, 'Minéral'], [11, 'Amorphe'], [12, 'Eau 2'], [13, 'Métamorph'], [14, 'Dragon'], [15, 'Inconnu'],
  ];
  const BUILTIN_HINT = { 13: 'Se reproduit avec tous les groupes (sauf Inconnu).', 15: 'Ne se reproduit pas.' };
  // œufs par encens de PSDK : [parent, objet, bébé]
  const DEFAULT_INCENSE = [
    ['marill', 'sea_incense', 'azurill'], ['azumarill', 'sea_incense', 'azurill'], ['wobbuffet', 'lax_incense', 'wynaut'],
    ['roselia', 'rose_incense', 'budew'], ['roserade', 'rose_incense', 'budew'], ['chimecho', 'pure_incense', 'chingling'],
    ['sudowoodo', 'rock_incense', 'bonsly'], ['mr_mime', 'odd_incense', 'mime_jr'], ['mr_rime', 'odd_incense', 'mime_jr'],
    ['chansey', 'luck_incense', 'happiny'], ['blissey', 'luck_incense', 'happiny'], ['snorlax', 'full_incense', 'munchlax'],
    ['mantine', 'wave_incense', 'mantyke'],
  ];
  const DEFAULTS = () => ({ klass: 'EggGroupsConfig', groups: [], creatures: {}, recipes: [], incense: [], disabled_incense: [] });
  const MAX_ROWS = 250;

  const api = window.pjEggGroups;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API des groupes d'œuf n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const toast = (msg, err) => {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    setTimeout(() => t.remove(), err ? 6000 : 2500);
  };
  const plain = (t) => String(t || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = { open: false, projectPath: null, ctx: null, config: null, saved: null, error: null, building: false,
    tab: 'groups', group: 1, search: '', onlyMembers: false };
  let root = null;
  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => S.config && S.saved !== snapshot();
  const byDb = () => S._byDb || (S._byDb = new Map(S.ctx.creatures.map((c) => [c.db, c])));
  const itemByDb = () => S._itemByDb || (S._itemByDb = new Map(S.ctx.items.map((i) => [i.db, i])));
  const speciesLabel = (c) => `${c.name} (#${c.id})`;
  const nameOf = (db) => { const c = byDb().get(db); return c ? c.name : db; };
  const itemName = (db) => { const i = itemByDb().get(db); return i ? i.name : db; };
  const customGroups = () => S.config.groups;
  const groupName = (id) => {
    const b = BUILTIN.find(([n]) => n === id);
    if (b) return b[1];
    const g = customGroups().find((x) => x.id === id);
    return g ? ((g.name && (g.name.fr || g.name.en)) || `Groupe ${id}`) : `Groupe ${id}`;
  };
  const allGroups = () => BUILTIN.map(([id]) => id).concat(customGroups().map((g) => g.id));
  const cfgCreature = (db) => S.config.creatures[db];
  const extraSpecies = (db, id) => ((cfgCreature(db) || {}).groups || []).includes(id);
  const extraForm = (db, form, id) => ((((cfgCreature(db) || {}).forms || {})[String(form)] || {}).groups || []).includes(id);
  const nativeGroups = (c) => { const f = c.forms.find((x) => x.form === 0) || c.forms[0]; return f ? f.groups : []; };
  const nativeForm = (c, form) => { const f = c.forms.find((x) => x.form === form); return f ? f.groups : []; };
  function memberCount(id) {
    let native = 0;
    let extra = 0;
    S.ctx.creatures.forEach((c) => {
      if (nativeGroups(c).includes(id)) native++;
      else if (extraSpecies(c.db, id) || c.forms.some((f) => f.form > 0 && extraForm(c.db, f.form, id))) extra++;
    });
    return [native, extra];
  }
  function toggleExtra(db, form, id, on) {
    const e = S.config.creatures[db] = S.config.creatures[db] || {};
    let dest = e;
    if (form > 0) { e.forms = e.forms || {}; dest = e.forms[String(form)] = e.forms[String(form)] || {}; }
    const list = new Set(dest.groups || []);
    if (on) list.add(id); else list.delete(id);
    if (list.size) dest.groups = [...list].sort((a, b) => a - b); else delete dest.groups;
    if (e.forms) { Object.keys(e.forms).forEach((f) => { if (!Object.keys(e.forms[f]).length) delete e.forms[f]; }); if (!Object.keys(e.forms).length) delete e.forms; }
    if (!Object.keys(e).length) delete S.config.creatures[db];
  }
  const parseSpecies = (text) => {
    const t = plain(text).trim();
    if (!t) return '';
    const exact = S.ctx.creatures.find((c) => plain(speciesLabel(c)) === t || c.db === t || plain(c.name) === t);
    return exact ? exact.db : null;
  };
  const parseItem = (text) => {
    const t = plain(text).trim();
    if (!t) return '';
    const it = S.ctx.items.find((i) => plain(`${i.name} (${i.db})`) === t || i.db === t || plain(i.name) === t);
    return it ? it.db : null;
  };

  // ---------------------------------------------------------------------------
  // Chargement / enregistrement
  // ---------------------------------------------------------------------------
  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null; S._byDb = null; S._itemByDb = null;
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      const c = Object.assign(DEFAULTS(), S.ctx.config || {});
      c.klass = 'EggGroupsConfig';
      ['groups', 'recipes', 'incense', 'disabled_incense'].forEach((k) => { if (!Array.isArray(c[k])) c[k] = []; });
      if (!c.creatures || typeof c.creatures !== 'object' || Array.isArray(c.creatures)) c.creatures = {};
      S.config = c;
      S.saved = snapshot();
    } catch (e) { S.error = 'Lecture impossible :\n' + e.message; }
    render();
  }
  async function save() {
    if (!S.config) return;
    try {
      const clean = JSON.parse(snapshot());
      clean.recipes = clean.recipes.filter((r) => r.a && r.b && r.result);
      clean.incense = clean.incense.filter((r) => r.parent && r.item && r.baby);
      const r = await call('save', { projectPath: S.projectPath, config: clean });
      S.config.recipes = clean.recipes; S.config.incense = clean.incense;
      S.saved = snapshot();
      toast('Groupes d’œuf enregistrés' + (r.plugin && r.plugin.installed ? '' : ' (lance construire_plugins.bat une fois pour installer le plugin)'));
    } catch (e) { toast('Enregistrement impossible : ' + e.message, true); }
    render();
  }
  async function buildPlugin() {
    S.building = true; render();
    try { const r = await call('buildPlugin', { projectPath: S.projectPath }); toast(r.built ? 'Plugin reconstruit' : 'Plugin non reconstruit : ' + (r.error || '?'), !r.built); }
    catch (e) { toast('Plugin non reconstruit : ' + e.message, true); }
    S.building = false; render();
  }
  const set = (fn) => { fn(); render(); };

  // ---------------------------------------------------------------------------
  // Onglet Groupes
  // ---------------------------------------------------------------------------
  function renderGroupList() {
    const list = h('div', { class: 'pjeg-list' });
    allGroups().forEach((id) => {
      const [n, x] = memberCount(id);
      list.appendChild(h('button', { class: 'pjeg-group' + (S.group === id ? ' active' : ''), onclick: () => set(() => { S.group = id; S.search = ''; }) },
        h('span', { class: 'pjeg-gname' }, groupName(id)), h('span', { class: 'pjeg-count', title: `${n} dans Studio, ${x} ajoutés ici` }, x ? `${n} + ${x}` : String(n))));
    });
    const add = h('button', { class: 'pjs-btn secondary', onclick: () => set(() => {
      const id = Math.max(99, ...customGroups().map((g) => g.id)) + 1;
      customGroups().push({ id, name: { fr: 'Nouveau groupe', en: 'New group' } });
      S.group = id; S.search = '';
    }) }, '+ Nouveau groupe');
    return h('div', { class: 'pjs-block pjeg-left' }, h('div', { class: 'pjs-block-head' }, h('h2', null, 'Groupes'), add), list);
  }
  function renderMembers() {
    const id = S.group;
    const builtin = BUILTIN.some(([n]) => n === id);
    const g = customGroups().find((x) => x.id === id);
    const head = h('div', { class: 'pjs-block-head' }, h('h2', null, groupName(id)),
      g ? h('button', { class: 'pjs-btn small danger', onclick: () => {
        if (!confirm(`Supprimer le groupe « ${groupName(id)} » ? Il sera retiré des Pokémon à qui il a été ajouté ici.`)) return;
        set(() => {
          Object.keys(S.config.creatures).forEach((db) => {
            const forms = Object.keys((S.config.creatures[db] || {}).forms || {});
            toggleExtra(db, 0, id, false);
            forms.forEach((f) => toggleExtra(db, Number(f), id, false));
          });
          S.config.groups = customGroups().filter((y) => y.id !== id); S.group = 1;
        });
      } }, 'Supprimer le groupe') : null);
    const kids = [head];
    if (g) {
      g.name = g.name || { fr: '', en: '' };
      kids.push(h('div', { class: 'pjeg-names' },
        h('label', { class: 'pjeg-field' }, h('span', { class: 'pjs-label' }, 'Nom (français)'), h('input', { class: 'pjs-input', value: g.name.fr || '', 'data-focus': 'fr', oninput: (e) => { g.name.fr = e.target.value; refreshList(); } })),
        h('label', { class: 'pjeg-field' }, h('span', { class: 'pjs-label' }, 'Nom (anglais)'), h('input', { class: 'pjs-input', value: g.name.en || '', 'data-focus': 'en', oninput: (e) => { g.name.en = e.target.value; } })),
        h('span', { class: 'pjs-hint inline' }, `Numéro du groupe : ${id}`)));
    } else if (builtin) kids.push(h('div', { class: 'pjs-hint' }, `Groupe de PSDK n°${id}. ${BUILTIN_HINT[id] || ''} Les Pokémon cochés « Studio » se règlent dans la page Pokémon de Studio ; tu peux ajouter ici d'autres Pokémon à ce groupe.`));
    const q = plain(S.search);
    const rows = S.ctx.creatures.filter((c) => {
      const inNative = nativeGroups(c).includes(id);
      const inExtra = extraSpecies(c.db, id) || c.forms.some((f) => f.form > 0 && extraForm(c.db, f.form, id));
      if (S.onlyMembers && !inNative && !inExtra) return false;
      return !q || plain(c.name).includes(q) || c.db.includes(q) || String(c.id) === q;
    });
    kids.push(h('div', { class: 'pjeg-tools' },
      h('input', { class: 'pjs-input', placeholder: 'Rechercher un Pokémon…', value: S.search, 'data-focus': 'search', oninput: (e) => { S.search = e.target.value; render(); } }),
      h('label', { class: 'pjs-inline pjeg-check' }, h('input', { type: 'checkbox', checked: S.onlyMembers, onchange: (e) => set(() => { S.onlyMembers = e.target.checked; }) }), 'Membres seulement'),
      h('span', { class: 'pjs-hint inline' }, `${rows.length} Pokémon`)));
    const table = h('div', { class: 'pjeg-members' });
    rows.slice(0, MAX_ROWS).forEach((c) => {
      const native = nativeGroups(c).includes(id);
      const forms = c.forms.filter((f) => f.form > 0);
      const cb = h('input', { type: 'checkbox', checked: native || extraSpecies(c.db, id), disabled: native, title: native ? 'Groupe réglé dans Studio (page Pokémon)' : 'Ajouter ce groupe à tout le Pokémon',
        onchange: (e) => set(() => toggleExtra(c.db, 0, id, e.target.checked)) });
      table.appendChild(h('div', { class: 'pjeg-member' + (native || extraSpecies(c.db, id) ? ' on' : '') },
        cb, h('span', { class: 'pjeg-id' }, '#' + c.id), h('span', { class: 'pjeg-mname' }, c.name),
        native ? h('span', { class: 'pjeg-tag' }, 'Studio') : null,
        forms.length ? h('span', { class: 'pjeg-forms' }, forms.map((f) => {
          const fn = nativeForm(c, f.form).includes(id);
          return h('button', { class: 'pjeg-form' + (fn || extraForm(c.db, f.form, id) ? ' on' : ''), title: fn ? 'Réglé dans Studio' : `Forme ${f.form} seulement`, disabled: fn,
            onclick: () => set(() => toggleExtra(c.db, f.form, id, !extraForm(c.db, f.form, id))) }, 'F' + f.form);
        })) : null));
    });
    if (rows.length > MAX_ROWS) table.appendChild(h('div', { class: 'pjs-hint' }, `Les ${MAX_ROWS} premiers sont affichés : affine la recherche.`));
    kids.push(table);
    return h('div', { class: 'pjs-block pjeg-right' }, kids);
  }
  function refreshList() {
    const old = root && root.querySelector('.pjeg-list');
    if (!old) return;
    const fresh = renderGroupList().querySelector('.pjeg-list');
    old.replaceWith(fresh);
    const title = root.querySelector('.pjeg-right .pjs-block-head h2');
    if (title) title.textContent = groupName(S.group);
  }

  // ---------------------------------------------------------------------------
  // Onglet Exceptions
  // ---------------------------------------------------------------------------
  function speciesInput(value, onset, placeholder) {
    const el = h('input', { class: 'pjs-input', list: 'pjeg-species', placeholder: placeholder || 'Pokémon…', value: value ? (byDb().get(value) ? speciesLabel(byDb().get(value)) : value) : '' });
    el.addEventListener('change', () => {
      const db = parseSpecies(el.value);
      if (db === null) { el.classList.add('bad'); toast('Pokémon inconnu : ' + el.value, true); return; }
      el.classList.remove('bad'); set(() => onset(db));
    });
    return el;
  }
  function itemInput(value, onset) {
    const el = h('input', { class: 'pjs-input', list: 'pjeg-items', placeholder: 'Objet…', value: value ? `${itemName(value)} (${value})` : '' });
    el.addEventListener('change', () => {
      const db = parseItem(el.value);
      if (db === null) { el.classList.add('bad'); toast('Objet inconnu : ' + el.value, true); return; }
      el.classList.remove('bad'); set(() => onset(db));
    });
    return el;
  }
  function renderRecipes() {
    const list = S.config.recipes;
    const body = h('div', { class: 'pjeg-table' });
    if (!list.length) body.appendChild(h('div', { class: 'pjs-hint' }, 'Aucune recette. Exemple : Pikachu + Évoli → œuf de Pichu.'));
    list.forEach((r, i) => {
      const result = byDb().get(r.result);
      const forms = result ? result.forms.map((f) => f.form) : [0];
      body.appendChild(h('div', { class: 'pjeg-recipe' },
        speciesInput(r.a, (db) => { r.a = db; }, 'Parent A'), h('span', { class: 'pjeg-op' }, '+'),
        speciesInput(r.b, (db) => { r.b = db; }, 'Parent B'), h('span', { class: 'pjeg-op' }, '→'),
        speciesInput(r.result, (db) => { r.result = db; r.form = 0; }, 'Œuf de…'),
        h('select', { class: 'pjs-select pjeg-formsel', title: 'Forme de l\'œuf', onchange: (e) => set(() => { r.form = Number(e.target.value); }) },
          forms.map((f) => h('option', { value: f, selected: (r.form | 0) === f }, f === 0 ? 'Forme 0' : 'Forme ' + f))),
        h('button', { class: 'pjs-btn small danger', onclick: () => set(() => list.splice(i, 1)) }, 'Supprimer')));
    });
    return h('div', { class: 'pjs-block' },
      h('div', { class: 'pjs-block-head' }, h('h2', null, 'Recettes d’œuf'), h('button', { class: 'pjs-btn secondary', onclick: () => set(() => list.push({ a: '', b: '', result: '', form: 0 })) }, '+ Ajouter une recette')),
      h('div', { class: 'pjs-hint', style: { marginTop: 0, marginBottom: 12 } }, 'Quand les deux Pokémon sont à la Pension (dans n’importe quel ordre), ils peuvent donner l’œuf de l’espèce choisie, même sans groupe d’œuf en commun. Les règles habituelles (sexes différents, Métamorph…) s’appliquent.'),
      body);
  }
  function renderIncense() {
    const list = S.config.incense;
    const body = h('div', { class: 'pjeg-table' });
    if (!list.length) body.appendChild(h('div', { class: 'pjs-hint' }, 'Aucune règle ajoutée. Exemple : Pikachu + Encens Chance → œuf de Pichu (au lieu de Pikachu).'));
    list.forEach((r, i) => {
      body.appendChild(h('div', { class: 'pjeg-recipe pjeg-incense' },
        speciesInput(r.parent, (db) => { r.parent = db; }, 'Parent'), h('span', { class: 'pjeg-op' }, 'tient'),
        itemInput(r.item, (db) => { r.item = db; }), h('span', { class: 'pjeg-op' }, '→'),
        speciesInput(r.baby, (db) => { r.baby = db; }, 'Bébé'),
        h('button', { class: 'pjs-btn small danger', onclick: () => set(() => list.splice(i, 1)) }, 'Supprimer')));
    });
    const defaults = h('div', { class: 'pjeg-defaults' });
    DEFAULT_INCENSE.forEach(([parent, item, baby]) => {
      const off = S.config.disabled_incense.includes(parent);
      defaults.appendChild(h('label', { class: 'pjeg-default' + (off ? ' off' : '') },
        h('input', { type: 'checkbox', checked: !off, onchange: (e) => set(() => {
          const d = new Set(S.config.disabled_incense);
          if (e.target.checked) d.delete(parent); else d.add(parent);
          S.config.disabled_incense = [...d];
        }) }), `${nameOf(parent)} + ${itemName(item)} → ${nameOf(baby)}`));
    });
    return h('div', { class: 'pjs-block' },
      h('div', { class: 'pjs-block-head' }, h('h2', null, 'Bébés par encens'), h('button', { class: 'pjs-btn secondary', onclick: () => set(() => list.push({ parent: '', item: '', baby: '' })) }, '+ Ajouter une règle')),
      h('div', { class: 'pjs-hint', style: { marginTop: 0, marginBottom: 12 } }, 'Si un des deux parents tient l’objet, le Pokémon « parent » donne l’œuf du bébé choisi. Sans l’objet, l’œuf est celui de l’espèce habituelle.'),
      body,
      h('div', { class: 'pjs-label', style: { marginTop: 20 } }, 'Règles de PSDK (décocher pour les désactiver)'), defaults);
  }

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function statusText() {
    if (!S.config) return ['', ''];
    if (S.building) return ['Mise à jour du plugin…', ' busy'];
    if (dirty()) return ['Modifications non enregistrées', ' dirty'];
    return ['Enregistré', ''];
  }
  function updateStatus() {
    const el = root && root.querySelector('.pjs-status');
    if (!el) return;
    const [t, cls] = statusText();
    el.textContent = t; el.className = 'pjs-status' + cls;
  }
  function render() {
    if (!root) return;
    const prev = root.querySelector('.pjeg-detail');
    const scroll = prev ? prev.scrollTop : 0;
    const memberScroll = (root.querySelector('.pjeg-members') || {}).scrollTop || 0;
    const focused = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.focus : null;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Groupes d’Œuf'), h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    if (S.error) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty err' }, S.error))); return; }
    if (!S.config) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty' }, 'Chargement…'))); return; }
    const detail = h('div', { class: 'pjeg-detail' });
    root.appendChild(detail);
    const p = S.ctx.plugin;
    if (p && !p.source) detail.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/egg_groups est introuvable.'));
    else if (p && !p.installed) detail.appendChild(h('div', { class: 'pjs-warn' }, 'Le plugin « egg_groups » n’est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul).'));
    detail.appendChild(h('div', { class: 'pjeg-tabs' }, [['groups', 'Groupes'], ['exceptions', 'Exceptions']].map(([k, l]) =>
      h('button', { class: 'pjeg-tab' + (S.tab === k ? ' active' : ''), onclick: () => set(() => { S.tab = k; }) }, l))));
    detail.appendChild(h('datalist', { id: 'pjeg-species' }, S.ctx.creatures.map((c) => h('option', { value: speciesLabel(c) }))));
    detail.appendChild(h('datalist', { id: 'pjeg-items' }, S.ctx.items.map((i) => h('option', { value: `${i.name} (${i.db})` }))));
    if (S.tab === 'groups') detail.appendChild(h('div', { class: 'pjeg-cols' }, renderGroupList(), renderMembers()));
    else { detail.appendChild(renderRecipes()); detail.appendChild(renderIncense()); }
    detail.scrollTop = scroll;
    const members = root.querySelector('.pjeg-members');
    if (members) members.scrollTop = memberScroll;
    if (focused) { const el = root.querySelector(`[data-focus="${focused}"]`); if (el) { el.focus(); if (el.setSelectionRange && el.type === 'text') el.setSelectionRange(el.value.length, el.value.length); } }
  }

  // ---------------------------------------------------------------------------
  // Page : Données > Pokémon > Groupes d'Œuf (/database/egg-groups)
  // ---------------------------------------------------------------------------
  function mount(hostEl) {
    root = h('div', { id: 'pjeg-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = true;
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.config || (latest && latest !== S.projectPath && !dirty())) loadProject(latest || null); else render();
  }
  function checkPage() {
    const hostEl = document.getElementById('pj-page-' + PAGE_ID);
    if (root && hostEl && hostEl.contains(root)) return;
    if (root && root.parentNode) root.remove();
    if (root) { root = null; S.open = false; }
    if (hostEl) mount(hostEl);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);
  window.addEventListener('keydown', (e) => {
    if (!S.open) return;
    if (e.ctrlKey && e.key.toLowerCase() === 's') { e.preventDefault(); e.stopPropagation(); save(); }
  }, true);
  setInterval(() => { if (S.open) updateStatus(); }, 1000);

  window.pjEggGroupsEditor = { state: S, render, buildPlugin };
})();

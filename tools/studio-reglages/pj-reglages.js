/* eslint-disable */
// =============================================================================
// Réglages des plugins récents — pages de Pokémon Studio
//   Données > Pokédex > Tâches                 tâches de recherche du Pokédex (advanced_pokedex)
//   Données > Baies > Champs de baies          mutations, sols, engrais, nuisibles… (berrydex)
//   Données > Gimmicks > Styles PLA            Style Puissant / Rapide (gimmicks)
//   Level design > Mini-jeux > Sac de frappe   séances d'entraînement (sac_de_frappe)
//   Level design > Mini-jeux > Poké Récré      friandises, jauges, décors (poke_recre)
//   Données > Gimmicks > Raids                 réglages, styles, Pokémon des raids, récompenses (raids)
//   Level design > Carte de région > Cartes d'aventure  éditeur des cartes des Aventures Raid (raids)
//   Level design > Dresseurs > Tournois        tournois, participants, règles, récompenses (tournoi)
// Chaque page lit et enregistre son fichier Data/configs/plugins/*.json (pj-reglages-main.js).
// Utilise le style de l'éditeur Smartphone (classes pjs-*), installé avant lui.
// =============================================================================
(() => {
  'use strict';
  if (window.__pjReglagesLoaded) return;
  window.__pjReglagesLoaded = true;

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjReglages;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API des réglages n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const clone = (o) => JSON.parse(JSON.stringify(o));
  const plain = (t) => String(t || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  const isObj = (o) => o && typeof o === 'object' && !Array.isArray(o);
  const int = (v, d = 0) => { const n = parseInt(v, 10); return Number.isFinite(n) ? n : d; };
  let toastTimer = null;
  function toast(msg, err) {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.remove(), err ? 6000 : 2500);
  }
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  function copy(t) { try { navigator.clipboard.writeText(t); toast('Copié : ' + t); } catch (e) { /* rien */ } }

  // images du projet (graphics/..., sans extension)
  const imageCache = new Map();
  function image(rel) {
    if (!rel) return Promise.resolve(null);
    if (!imageCache.has(rel)) {
      imageCache.set(rel, call('readImages', { projectPath: cur().projectPath, files: [rel] }).then((m) => m[rel]).catch(() => null));
    }
    return imageCache.get(rel);
  }
  function pic(rel, cls) {
    const el = h('span', { class: 'pjr-pic ' + (cls || '') });
    image(rel).then((url) => { if (url) el.style.backgroundImage = `url("${url}")`; });
    return el;
  }
  let audio = null;
  async function play(file) {
    if (!file) return;
    try {
      const url = await call('readSound', { projectPath: cur().projectPath, file });
      if (!url) { toast('Son introuvable : ' + file, true); return; }
      if (audio) audio.pause();
      audio = new Audio(url); audio.play();
    } catch (e) { toast(e.message, true); }
  }

  // ---------------------------------------------------------------------------
  // État : une entrée par page
  // ---------------------------------------------------------------------------
  const STATES = {};
  let activeId = null;
  let root = null;
  const cur = () => STATES[activeId];
  const snapshot = (S) => JSON.stringify(S.config);
  const dirty = (S) => S && S.config && S.saved !== snapshot(S);

  async function loadProject(id, projectPath) {
    const S = STATES[id] = STATES[id] || {};
    Object.assign(S, { projectPath, ctx: null, config: null, saved: null, error: null, building: false, ui: S.ui || {} });
    imageCache.clear();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath, page: id });
      const page = PAGES[id];
      S.config = page.normalize(clone(S.ctx.config || {}), S);
      S.saved = S.ctx.config ? snapshot(S) : null;
    } catch (e) { S.error = e.message; }
    if (activeId === id) render();
  }

  async function save() {
    const S = cur();
    if (!S || !S.config) return;
    const page = PAGES[activeId];
    if (page.readonly) { toast('Cette page ne s’enregistre pas : elle vérifie seulement.'); return; }
    const problems = page.problems ? page.problems(S) : [];
    if (problems.length) { toast('À corriger avant d’enregistrer : ' + problems[0], true); return; }
    const id = activeId;
    try {
      const out = page.serialize ? page.serialize(clone(S.config), S) : S.config;
      const r = await call('save', { projectPath: S.projectPath, page: id, config: out });
      S.saved = snapshot(S);
      const pl = r.plugin || {};
      if (pl.source) S.ctx.plugin = Object.assign(S.ctx.plugin || {}, { source: true, installed: pl.installed, outdated: [], stale: [] });
      toast('Enregistré' + (pl.source && !pl.installed ? ` — plugin « ${pl.name} » pas encore installé : lance construire_plugins.bat une fois` : ''));
      render();
      if (pl.source && pl.installed) rebuild(id);
    } catch (e) { toast('Erreur de sauvegarde : ' + e.message, true); }
  }
  async function rebuild(id) {
    const S = STATES[id];
    if (S.building) return;
    S.building = true; updateStatus();
    try {
      const r = await call('buildPlugin', { projectPath: S.projectPath, page: id });
      if (!r.built) toast('Paquet du plugin non reconstruit : ' + (r.error || '?'), true);
    } catch (e) { toast('Paquet du plugin non reconstruit : ' + e.message, true); }
    S.building = false; updateStatus();
  }
  function statusText() {
    const S = cur();
    if (!S || !S.config) return ['', ''];
    if (PAGES[activeId] && PAGES[activeId].readonly) return [S.ctx && S.ctx.balance ? `${S.ctx.balance.types.length} types` : S.ctx && S.ctx.overview ? `${S.ctx.overview.length} plugins` : S.ctx && S.ctx.audit ? `Vérifié à ${new Date(S.ctx.audit.at).toLocaleTimeString()}` : '', ''];
    if (S.building) return ['Mise à jour du plugin…', ' busy'];
    if (dirty(S)) return ['Modifications non enregistrées', ' dirty'];
    const p = S.ctx && S.ctx.plugin;
    if (p && p.source && !p.installed) return [`Plugin « ${p.name} » pas installé : construire_plugins.bat`, ' dirty'];
    if (p && p.source && ((p.outdated || []).length || (p.stale || []).length)) return ['Plugin installé pas à jour : Enregistrer', ' dirty'];
    return [S.saved ? 'Tout est enregistré' : 'Pas encore enregistré (valeurs de base)', ''];
  }
  function updateStatus() {
    const el = root && root.querySelector('.pjs-status');
    if (!el) return;
    const [t, cls] = statusText();
    el.textContent = t; el.className = 'pjs-status' + cls;
  }
  // changement de structure : la page est refaite ; saisie : seulement l'état
  const redo = (fn) => { if (fn) fn(); render(); };
  const soft = (fn) => { if (fn) fn(); updateStatus(); };

  // ---------------------------------------------------------------------------
  // Champs
  // ---------------------------------------------------------------------------
  function block(title, head, ...kids) {
    return h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title), head || null), ...kids);
  }
  const hint = (t) => h('div', { class: 'pjs-hint' }, t);
  function labeled(lab, el, tip) {
    return h('label', { class: 'pjr-field', title: tip || null }, h('span', { class: 'pjs-label' }, lab), el);
  }
  // nombre lié à obj[key] ; vide : clé retirée si optional
  function numInput(obj, key, { min, max, step = 1, optional = false, placeholder = '', onChange, cls = '' } = {}) {
    const v = obj[key];
    const el = h('input', { class: 'pjs-input pjr-num ' + cls, type: 'number', step, min, max, placeholder, value: v === undefined || v === null ? '' : v });
    el.addEventListener('input', () => soft(() => {
      if (el.value === '' && optional) delete obj[key];
      else {
        let n = Number(el.value);
        if (!Number.isFinite(n)) n = 0;
        if (step === 1 || step === '1') n = Math.round(n);
        if (min !== undefined && n < min) n = min;
        if (max !== undefined && n > max) n = max;
        obj[key] = n;
      }
      if (onChange) onChange();
    }));
    // refaite après le changement de champ (Tab), pour que le champ suivant garde la main
    el.addEventListener('change', () => { if (onChange) setTimeout(render, 0); });
    return el;
  }
  function textInput(obj, key, { placeholder = '', cls = '', onChange } = {}) {
    const el = h('input', { class: 'pjs-input ' + cls, placeholder, value: obj[key] == null ? '' : obj[key] });
    el.addEventListener('input', () => soft(() => { obj[key] = el.value; if (onChange) onChange(el.value); }));
    return el;
  }
  function check(obj, key, lab, { tip, onChange, invert = false } = {}) {
    return h('label', { class: 'pjs-inline pjr-check', title: tip || null },
      h('input', { type: 'checkbox', checked: invert ? !obj[key] : !!obj[key], onchange: (e) => { obj[key] = invert ? !e.target.checked : e.target.checked; if (onChange) redo(onChange); else soft(); } }), lab);
  }
  function select(obj, key, options, { onChange, cls = '' } = {}) {
    return h('select', { class: 'pjs-select ' + cls, onchange: (e) => { obj[key] = e.target.value; if (onChange) redo(onChange); else soft(); } },
      options.map(([v, l]) => h('option', { value: v, selected: String(obj[key] ?? '') === String(v) }, l)));
  }
  // [min, max] lié à obj[key]
  function rangeInput(obj, key, { min = 0, max, single = false } = {}) {
    let v = obj[key];
    if (!Array.isArray(v)) v = obj[key] = single ? v || 0 : [v || 0, v || 0];
    if (single) return numInput(obj, key, { min, max });
    const pair = obj[key];
    const a = numInput(pair, 0, { min, max, cls: 'tiny' });
    const b = numInput(pair, 1, { min, max, cls: 'tiny' });
    return h('span', { class: 'pjr-range' }, a, h('span', { class: 'pjs-hint inline' }, 'à'), b);
  }
  // texte { fr, en }
  function langInputs(obj, key) {
    if (!isObj(obj[key])) obj[key] = { fr: String(obj[key] || ''), en: String(obj[key] || '') };
    const t = obj[key];
    return h('span', { class: 'pjr-langs' }, ['fr', 'en'].map((lang) => h('label', { class: 'pjs-inline' }, h('span', { class: 'pjr-lang' }, lang), textInput(t, lang))));
  }

  // Liste déroulante avec recherche : items() -> [{ value, label, sub, icon }]
  let openCombo = null;
  function closeCombo() { if (openCombo) { openCombo.remove(); openCombo = null; } }
  document.addEventListener('mousedown', (e) => { if (openCombo && !openCombo.contains(e.target) && !(e.target.closest && e.target.closest('.pjr-combo'))) closeCombo(); }, true);
  function combo({ value, items, onPick, placeholder = 'Choisir…', cls = '', allowEmpty = false, emptyLabel = '(aucun)' }) {
    const list = () => (allowEmpty ? [{ value: '', label: emptyLabel }] : []).concat(items());
    const current = list().find((i) => i.value === value);
    const btn = h('button', { class: 'pjs-select pjr-combo ' + cls, type: 'button', title: value || '' },
      current && current.icon ? pic(current.icon, 'small ' + (current.iconCls || '')) : null,
      h('span', { class: 'pjr-combo-label' + (current ? '' : ' empty') }, current ? current.label : (value ? value + ' (inconnu)' : placeholder)));
    btn.addEventListener('click', () => {
      if (openCombo && openCombo.__owner === btn) { closeCombo(); return; }
      closeCombo();
      const pop = h('div', { class: 'pjr-pop' });
      pop.__owner = btn;
      const search = h('input', { class: 'pjs-input', placeholder: 'Rechercher…' });
      const box = h('div', { class: 'pjr-pop-list' });
      const fill = () => {
        box.textContent = '';
        const q = plain(search.value);
        const shown = list().filter((i) => !q || plain(i.label + ' ' + i.value + ' ' + (i.sub || '')).includes(q)).slice(0, 300);
        shown.forEach((i) => box.appendChild(h('div', { class: 'pjr-pop-item' + (i.value === value ? ' active' : ''), onmousedown: (e) => { e.preventDefault(); closeCombo(); onPick(i.value, i); } },
          i.icon ? pic(i.icon, 'small ' + (i.iconCls || '')) : null, h('span', null, i.label), i.sub ? h('span', { class: 'pjs-hint inline' }, i.sub) : null)));
        if (!shown.length) box.appendChild(h('div', { class: 'pjs-hint' }, 'Rien trouvé.'));
      };
      search.addEventListener('input', fill);
      search.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') closeCombo();
        if (e.key === 'Enter') { const first = box.querySelector('.pjr-pop-item'); if (first) first.dispatchEvent(new MouseEvent('mousedown')); }
      });
      pop.append(search, box);
      document.body.appendChild(pop);
      const r = btn.getBoundingClientRect();
      pop.style.left = Math.min(r.left, window.innerWidth - 330) + 'px';
      const below = window.innerHeight - r.bottom > 300;
      pop.style.top = (below ? r.bottom + 4 : Math.max(8, r.top - 324)) + 'px';
      openCombo = pop;
      fill();
      search.focus();
    });
    return btn;
  }
  // listes de Studio
  const L = {
    moves: () => cur().ctx.moves.map((m) => ({ value: m.db, label: m.name, sub: m.db })),
    types: () => cur().ctx.types.map((t) => ({ value: t.db, label: t.name, sub: t.db })),
    items: () => cur().ctx.items.map((i) => ({ value: i.db, label: i.name, sub: i.db, icon: `graphics/icons/${i.icon || '000'}` })),
    berries: () => cur().ctx.items.filter((i) => i.berry).map((i) => ({ value: i.db, label: i.name, sub: i.db, icon: `graphics/icons/${i.icon || '000'}` })),
    creatures: () => cur().ctx.creatures.map((c) => ({ value: c.db, label: c.name, sub: `n° ${c.id} · ${c.db}`, icon: `graphics/pokedex/pokeicon/${c.icon || '000'}`, iconCls: 'poke' })),
  };
  const nameOf = (list, db) => { const x = (cur().ctx[list] || []).find((i) => i.db === db); return x ? x.name : db; };
  const itemIcon = (db) => { const i = cur().ctx.items.find((x) => x.db === db); return `graphics/icons/${(i && i.icon) || '000'}`; };

  function rowButtons(list, i, { onRemove, confirmText } = {}) {
    return h('span', { class: 'pjr-rowbtns' },
      h('button', { class: 'pjs-btn small', disabled: i === 0, title: 'Monter', onclick: () => redo(() => { [list[i - 1], list[i]] = [list[i], list[i - 1]]; }) }, '▲'),
      h('button', { class: 'pjs-btn small', disabled: i === list.length - 1, title: 'Descendre', onclick: () => redo(() => { [list[i + 1], list[i]] = [list[i], list[i + 1]]; }) }, '▼'),
      h('button', { class: 'pjs-btn small danger', title: 'Supprimer', onclick: () => { if (!confirmText || confirm(confirmText)) redo(() => { list.splice(i, 1); if (onRemove) onRemove(); }); } }, '✕'));
  }
  function commands(list) {
    return block('Commandes d’évènement (Script)', null, h('div', { class: 'pjr-cmds' }, list.map(([cmd, tip]) => h('div', { class: 'pjr-cmdrow' },
      h('code', { class: 'pjr-cmd', title: 'Cliquer pour copier', onclick: () => copy(cmd) }, cmd), h('span', { class: 'pjs-hint inline' }, tip)))));
  }

  // ===========================================================================
  // Données > Pokédex > Tâches (pokedex_tasks.json)
  // ===========================================================================
  const TASK_TYPES = {
    capture: { label: 'Capturer', game: ['Pokémon capturés', 'Number caught'], steps: [1, 3, 5, 8, 10] },
    capture_night: { label: 'Capturer la nuit', game: ['Capturés la nuit', 'Caught at night'], steps: [1, 3, 5, 8] },
    defeat: { label: 'Vaincre', game: ['Pokémon vaincus', 'Number defeated'], steps: [1, 3, 5, 8, 10] },
    defeat_type: { label: 'Vaincre avec un type', target: 'types', game: ['Vaincus avec une capacité %s', 'Defeated with %s-type moves'], steps: [1, 3, 5, 8, 10] },
    move: { label: 'Voir utiliser une capacité', target: 'moves', game: ['Vu utiliser %s', 'Times you’ve seen it use %s'], steps: [1, 3, 6, 10, 15] },
    evolve: { label: 'Évoluer', game: ['Évolutions', 'Times evolved'], steps: [1, 3, 5] },
    item_win: { label: 'Gagner en tenant un objet', target: 'items', game: ['Victoires en tenant %s', 'Battles won holding %s'], steps: [1, 5, 10, 15, 20] },
    herd: { label: 'Troupeau du jour (radar)', game: ['Pris dans un troupeau du jour', 'Caught or beaten in the daily herd'], steps: [1, 3, 5] },
  };
  const ATTACK_TYPES = ['normal', 'fire', 'water', 'grass', 'electric', 'ice', 'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy'];

  const stepsOf = (S, type) => {
    const list = ((S.config.thresholds || {})[type] || []).map(int).filter((n) => n > 0);
    return (list.length ? list : TASK_TYPES[type].steps).slice().sort((a, b) => a - b).slice(0, 5);
  };
  const taskSteps = (S, task) => (Array.isArray(task[2]) && task[2].filter((n) => n > 0).length ? task[2].filter((n) => n > 0).sort((a, b) => a - b).slice(0, 5) : stepsOf(S, task[0]));
  // les mêmes tâches automatiques qu'en jeu (00106 Taches.rb)
  function autoTasks(S, c) {
    const list = [['capture'], ['defeat']];
    const moveData = (db) => S.ctx.moves.find((m) => m.db === db);
    const moves = c.levelMoves.slice().sort((a, b) => a[1] - b[1]);
    const damaging = moves.filter(([m]) => { const d = moveData(m); return d && d.power > 0; });
    const pick = damaging.filter(([, lv]) => lv <= 40).pop() || damaging[0] || moves[moves.length - 1];
    if (pick) list.push(['move', pick[0]]);
    const typeData = (db) => S.ctx.types.find((t) => t.db === db);
    let best = null;
    ATTACK_TYPES.forEach((atk) => {
      const t = typeData(atk); if (!t) return;
      const f = c.types.reduce((acc, def) => acc * (t.damage[def] === undefined ? 1 : t.damage[def]), 1);
      if (!best || f > best[1]) best = [atk, f];
    });
    if (best && best[1] > 1) list.push(['defeat_type', best[0]]);
    if (c.evolves) list.push(['evolve']);
    return list;
  }
  function taskLabel(task) {
    const t = TASK_TYPES[task[0]];
    if (!t) return task[0];
    const target = task[1] ? (t.target ? nameOf(t.target, task[1]) : task[1]) : '?';
    return t.game[0].replace('%s', target);
  }

  const dexTasks = {
    title: 'Tâches du Pokédex',
    normalize(c) {
      c.klass = 'PokedexTasksConfig';
      c.settings = Object.assign({ points_needed: 10, auto_tasks: true, herd_task: true, reward_level: 0, reward_default: 'card', reward_ribbon: 'hisui', charm_rate: 1365, reward_notify: true }, isObj(c.settings) ? c.settings : {});
      if (!isObj(c.rewards)) c.rewards = {};
      c.thresholds = isObj(c.thresholds) ? c.thresholds : {};
      Object.keys(TASK_TYPES).forEach((k) => { if (!Array.isArray(c.thresholds[k])) c.thresholds[k] = TASK_TYPES[k].steps.slice(); });
      c.species = isObj(c.species) ? c.species : {};
      Object.keys(c.species).forEach((k) => { c.species[k] = (Array.isArray(c.species[k]) ? c.species[k] : []).map((e) => (Array.isArray(e) ? e : [e])); });
      return c;
    },
    serialize(c) {
      Object.keys(c.thresholds).forEach((k) => { c.thresholds[k] = c.thresholds[k].map(int).filter((n) => n > 0).sort((a, b) => a - b).slice(0, 5); });
      Object.keys(c.species).forEach((k) => {
        c.species[k] = c.species[k].map((t) => {
          const out = [t[0]];
          const steps = Array.isArray(t[2]) ? t[2].map(int).filter((n) => n > 0).sort((a, b) => a - b).slice(0, 5) : [];
          if (t[1] || steps.length) out.push(t[1] || null);
          if (steps.length) out.push(steps);
          return out;
        });
        if (!c.species[k].length) delete c.species[k];
      });
      return c;
    },
    problems(S) {
      const out = [];
      Object.entries(S.config.species).forEach(([sp, list]) => list.forEach((t, i) => {
        if (TASK_TYPES[t[0]] && TASK_TYPES[t[0]].target && !t[1]) out.push(`${nameOf('creatures', sp)} : la tâche n° ${i + 1} n’a pas de cible.`);
      }));
      return out;
    },
    render(S) {
      const c = S.config;
      const ui = S.ui;
      if (!ui.species) ui.species = (S.ctx.creatures[0] || {}).db;
      const content = h('div', { class: 'pjr-content' });
      if (!S.ctx.creatures.length) content.appendChild(h('div', { class: 'pjs-warn' }, 'Aucun Pokémon trouvé dans Données > Pokémon.'));
      const row = h('div', { class: 'pjr-row' });
      content.appendChild(row);
      const left = h('div', { class: 'pjr-col narrow' });
      row.appendChild(left);
      // --- réglages
      left.appendChild(block('Recherche', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Points pour terminer', numInput(c.settings, 'points_needed', { min: 1, max: 99, onChange: () => {} }), 'Chaque palier atteint donne 1 point.')),
        check(c.settings, 'auto_tasks', 'Tâches automatiques pour les Pokémon sans liste réglée', { onChange: () => {} }),
        hint('Automatiques : capturer, vaincre, voir utiliser une de ses capacités (apprise par niveau), vaincre avec un type super efficace, évoluer (s’il évolue).')));
      // --- paliers par type
      const steps = h('div', { class: 'pjr-steps' });
      Object.entries(TASK_TYPES).forEach(([k, t]) => {
        const arr = c.thresholds[k];
        steps.appendChild(h('div', { class: 'pjr-steprow' }, h('span', { class: 'pjr-steplabel' }, t.label),
          [0, 1, 2, 3, 4].map((j) => numInput(arr, j, { min: 1, max: 999, optional: true, cls: 'tiny' }))));
      });
      left.appendChild(block('Paliers de chaque type de tâche', h('button', { class: 'pjs-btn small', onclick: () => redo(() => { Object.keys(TASK_TYPES).forEach((k) => { c.thresholds[k] = TASK_TYPES[k].steps.slice(); }); }) }, 'Valeurs de base'),
        steps, hint('5 paliers au plus, en ordre croissant (une case vide est ignorée). Une tâche peut aussi avoir ses propres paliers.')));
      left.appendChild(block('Récompenses de recherche', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Niveau de recherche (0 : points pour terminer)', numInput(c.settings, 'reward_level', { min: 0, max: 99, onChange: () => {} })),
          labeled('Récompense par défaut', select(c.settings, 'reward_default', [['charm', 'Charme Chroma de l’espèce'], ['card', 'Carte Triple Triad'], ['memento', 'Souvenir (ruban)'], ['none', 'Rien']])),
          labeled('Souvenir par défaut (ruban)', textInput(c.settings, 'reward_ribbon', { placeholder: 'hisui' })),
          labeled('Charme Chroma : 1 chance sur N', numInput(c.settings, 'charm_rate', { min: 1, max: 100000, onChange: () => {} }))),
        check(c.settings, 'reward_notify', 'Bannière du téléphone à la récompense'),
        check(c.settings, 'herd_task', 'Tâche « troupeau du jour » dans les tâches automatiques'),
        hint('Donnée une seule fois par espèce. Récompense propre à une espèce : rewards dans pokedex_tasks.json, ex. { "eevee": { "type": "memento", "ribbon": "hisui" } }.')));
      left.appendChild(commands([
        ['tache_pokedex(:bulbasaur, :capture)', 'avance une tâche (cible et nombre en plus : tache_pokedex(:bulbasaur, :move, :vine_whip, 2))'],
        ['recherche_pokedex(:bulbasaur)', 'points de recherche de l’espèce'],
        ['recherche_terminee?(:bulbasaur)', 'condition : recherche terminée'],
        ['nombre_recherches_terminees', 'nombre d’espèces dont la recherche est terminée'],
      ]));
      // --- espèces
      const mid = h('div', { class: 'pjr-col list' });
      row.appendChild(mid);
      const search = h('input', { class: 'pjs-input', placeholder: 'Rechercher un Pokémon…', value: ui.search || '' });
      const onlyBox = h('label', { class: 'pjs-inline pjr-check' }, h('input', { type: 'checkbox', checked: !!ui.onlyCustom, onchange: (e) => { ui.onlyCustom = e.target.checked; fill(); } }), 'Seulement ceux réglés');
      const listEl = h('div', { class: 'pjr-list' });
      const fill = () => {
        listEl.textContent = '';
        const q = plain(search.value);
        S.ctx.creatures.filter((cr) => (!q || plain(`${cr.name} ${cr.db} ${cr.id}`).includes(q)) && (!ui.onlyCustom || c.species[cr.db])).slice(0, 600).forEach((cr) => {
          const n = c.species[cr.db] ? c.species[cr.db].length : 0;
          const el = h('div', { class: 'pjr-list-item' + (ui.species === cr.db ? ' active' : ''), onclick: () => redo(() => { ui.species = cr.db; }) },
            pic(`graphics/pokedex/pokeicon/${cr.icon || '000'}`, 'icon'),
            h('span', { class: 'pjr-list-name' }, h('span', null, cr.name), h('span', { class: 'pjs-hint inline' }, `n° ${cr.id}`)),
            n ? h('span', { class: 'pjr-badge' }, String(n)) : h('span', { class: 'pjr-badge auto', title: 'Tâches automatiques' }, 'auto'));
          listEl.appendChild(el);
        });
      };
      search.addEventListener('input', () => { ui.search = search.value; fill(); });
      fill();
      mid.appendChild(block(`Pokémon (${Object.keys(c.species).length} réglés)`, null, h('div', { class: 'pjr-listhead' }, search, onlyBox), listEl));
      requestAnimationFrame(() => { const a = listEl.querySelector('.active'); if (a) a.scrollIntoView({ block: 'nearest' }); });
      // --- tâches de l'espèce
      const right = h('div', { class: 'pjr-col wide' });
      row.appendChild(right);
      const cr = S.ctx.creatures.find((x) => x.db === ui.species);
      if (cr) right.appendChild(this.renderSpecies(S, cr));
      return content;
    },
    renderSpecies(S, cr) {
      const c = S.config;
      const custom = c.species[cr.db];
      const tasks = custom || (c.settings.auto_tasks ? autoTasks(S, cr) : []);
      const head = h('span', { class: 'pjr-actions' },
        custom ? h('button', { class: 'pjs-btn small', onclick: () => { if (confirm('Revenir aux tâches automatiques (la liste réglée est effacée) ?')) redo(() => { delete c.species[cr.db]; }); } }, 'Revenir aux tâches automatiques')
          : h('button', { class: 'pjs-btn small primary', onclick: () => redo(() => { c.species[cr.db] = autoTasks(S, cr).map((t) => t.slice()); }) }, 'Personnaliser'),
        custom ? h('button', { class: 'pjs-btn small', onclick: () => redo(() => { custom.push(['capture']); }) }, 'Ajouter une tâche') : null);
      const box = block(`${cr.name} — ${custom ? 'tâches réglées' : (c.settings.auto_tasks ? 'tâches automatiques' : 'aucune tâche')}`, head);
      box.insertBefore(h('div', { class: 'pjr-spechead' }, pic(`graphics/pokedex/pokeicon/${cr.icon || '000'}`, 'big'),
        h('div', null, h('div', { class: 'pjr-specname' }, cr.name), h('div', { class: 'pjs-hint inline' }, `${cr.db} · ${cr.types.map((t) => nameOf('types', t)).join(' / ')}`))), box.children[1] || null);
      if (!tasks.length) box.appendChild(hint('Ce Pokémon n’a pas de tâche : sa page Tâches dira « Pas de tâche pour ce Pokémon ». Personnalise-le pour en ajouter.'));
      let total = 0;
      tasks.forEach((task, i) => {
        const t = TASK_TYPES[task[0]];
        const st = taskSteps(S, task);
        total += st.length;
        const rowEl = h('div', { class: 'pjr-task' + (custom ? '' : ' readonly') });
        if (custom) {
          const typeSel = h('select', { class: 'pjs-select', onchange: (e) => redo(() => { task[0] = e.target.value; task[1] = TASK_TYPES[task[0]].target ? '' : null; }) },
            Object.entries(TASK_TYPES).map(([k, x]) => h('option', { value: k, selected: k === task[0] }, x.label)));
          const target = t && t.target ? combo({ value: task[1] || '', items: L[t.target], placeholder: t.target === 'moves' ? 'Capacité…' : t.target === 'types' ? 'Type…' : 'Objet…', onPick: (v) => redo(() => { task[1] = v; }) }) : h('span', { class: 'pjs-hint inline' }, '—');
          const own = Array.isArray(task[2]);
          const stepBox = h('span', { class: 'pjr-taskstep' },
            h('label', { class: 'pjs-inline pjr-check', title: 'Paliers propres à cette tâche' }, h('input', { type: 'checkbox', checked: own, onchange: (e) => redo(() => {
              if (e.target.checked) { task[1] = task[1] || null; task[2] = stepsOf(S, task[0]).slice(); } else task.length = 2;
            }) }), 'Paliers propres'),
            own ? [0, 1, 2, 3, 4].map((j) => numInput(task[2], j, { min: 1, max: 999, optional: true, cls: 'tiny', onChange: () => {} })) : h('span', { class: 'pjs-hint inline' }, st.join(' · ')));
          rowEl.append(h('div', { class: 'pjr-taskline' }, h('span', { class: 'pjr-tasknum' }, String(i + 1)), typeSel, target, rowButtons(custom, i)), stepBox);
        } else {
          rowEl.append(h('div', { class: 'pjr-taskline' }, h('span', { class: 'pjr-tasknum' }, String(i + 1)), h('span', { class: 'pjr-taskname' }, t ? t.label : task[0]),
            task[1] ? h('span', { class: 'pjs-hint inline' }, t && t.target ? nameOf(t.target, task[1]) : task[1]) : null, h('span', { class: 'pjs-hint inline right' }, st.join(' · '))));
        }
        rowEl.appendChild(h('div', { class: 'pjr-taskgame' }, h('span', { class: 'pjr-gamelabel' }, taskLabel(task)),
          st.map((n) => h('span', { class: 'pjr-pill' }, String(n)))));
        box.appendChild(rowEl);
      });
      const need = int(c.settings.points_needed, 10);
      box.appendChild(h('div', { class: 'pjr-total' + (total < need ? ' bad' : '') },
        `${total} point${total > 1 ? 's' : ''} possible${total > 1 ? 's' : ''} / ${need} pour terminer la recherche`,
        total < need ? ' — la recherche ne pourra jamais être terminée : ajoute des tâches ou des paliers.' : ''));
      box.appendChild(hint(custom ? 'En jeu : 5 tâches par écran (A montre les suivantes), chaque palier atteint donne 1 point.' : 'Aperçu des tâches calculées en jeu pour ce Pokémon. « Personnaliser » les recopie dans une liste à modifier.'));
      return box;
    },
  };

  // ===========================================================================
  // Données > Baies > Champs de baies (champs_baies.json)
  // ===========================================================================
  const FIELD_SETTINGS = [
    ['enabled', 'Champs de baies améliorés', 'bool'],
    ['common_event', 'Évènement commun des plants de baies', 'num', 1, 999],
    ['max_replants', 'Replantations avant de disparaître', 'num', 1, 99],
    ['ripe_stages', 'Durée mûre avant de flétrir (en stades)', 'num', 1, 20],
    ['rain_waters', 'La pluie arrose', 'bool'],
    ['need_can', 'Arrosoir obligatoire pour arroser', 'bool'],
    ['mutations', 'Mutations', 'bool'],
    ['mutation_chance', 'Chance de mutation (%)', 'num', 0, 100],
    ['mutation_count', 'Baies mutées à la récolte', 'num', 1, 20],
    ['replant_resets_mutation', 'Une replantation efface la mutation', 'bool'],
    ['propagation', 'Propagation aux emplacements voisins', 'bool'],
    ['propagation_chance', 'Chance de propagation (pour mille)', 'num', 0, 1000],
    ['persistent_chance', 'Chance qu’un plant repousse après la cueillette (%)', 'num', 0, 100],
    ['persistent_stage', 'Stade où il repart (0 graine … 3 fleur)', 'num', 0, 3],
    ['dig_up', 'On peut déterrer une baie qui vient d’être plantée', 'bool'],
    ['dig_up_keep_chance', 'Chance de récupérer la baie déterrée (%)', 'num', 0, 100],
    ['weeds', 'Mauvaises herbes', 'bool'],
    ['weed_hours', 'Mauvaises herbes : tirage toutes les … heures', 'num', 1, 99],
    ['weed_chance', 'Chance de mauvaises herbes (%)', 'num', 0, 100],
    ['pests', 'Nuisibles (Pokémon cachés)', 'bool'],
    ['pest_hours', 'Nuisibles : tirage toutes les … heures', 'num', 1, 99],
    ['pest_chance', 'Chance de nuisibles (%)', 'num', 0, 100],
    ['repel_on_pests', 'Un Repousse actif fait fuir les nuisibles', 'bool'],
    ['zone_message', 'Messages du sol et de la zone en plantant', 'bool'],
  ];
  const FIELD_DEFAULTS = {
    enabled: true, common_event: 18, max_replants: 5, ripe_stages: 4, rain_waters: true, need_can: true, mutations: true, mutation_chance: 20,
    mutation_count: 1, replant_resets_mutation: true, propagation: true, propagation_chance: 1, persistent_chance: 0, persistent_stage: 2, dig_up: true,
    dig_up_keep_chance: 25, weeds: true, weed_hours: 2, weed_chance: 15, pests: true, pest_hours: 2, pest_chance: 15, repel_on_pests: true,
    zone_message: true, default_soil: 'loamy',
  };
  const MULCH_KEYS = [
    ['growth', 'Pousse %', 'Durée de chaque stade (100 = normale, 75 = plus rapide)'], ['drying', 'Séchage %', 'Durée de l’humidité (100 = normale, 200 = sèche deux fois moins vite)'],
    ['yield', 'Baies +', 'Baies en plus à la récolte'], ['replants', 'Replant. %', 'Nombre de replantations (150 = 50 % de plus)'],
    ['ripe', 'Mûre %', 'Temps avant de flétrir (150 = 50 % de plus)'], ['mutation', 'Mutation %', 'Remplace la chance de mutation'],
    ['propagation', 'Propag. ‰', 'Remplace la chance de propagation vers cet emplacement'], ['weeds', 'Herbes %', 'Remplace la chance de mauvaises herbes'],
    ['pests', 'Nuisibles %', 'Remplace la chance de nuisibles'],
  ];
  const TRAIT_KEYS = [
    ['yield', 'Baies +'], ['hours_per_stage', 'Heures / stade +'], ['drying_per_hour', 'Séchage % +'], ['mutation_chance', 'Mutation % +'],
    ['max_replants', 'Replant. +'], ['weed_chance', 'Herbes % +'], ['pest_chance', 'Nuisibles % +'],
  ];
  const TRAITS = [
    ['pref_weather', 'Météo préférée vue pendant la pousse'], ['pref_zone', 'Zone préférée'], ['unpref_zone', 'Zone évitée'],
    ['pref_soil', 'Sol préféré'], ['weeds', 'Mauvaises herbes présentes'], ['pests', 'Nuisibles présents'],
  ];
  const COLORS = [['', 'Toutes'], ['red', 'Rouge'], ['blue', 'Bleue'], ['pink', 'Rose'], ['green', 'Verte'], ['yellow', 'Jaune'], ['purple', 'Violette']];

  // tableau de nombres (clé vide : retirée)
  function numGrid(obj, keys, { allowRange = [] } = {}) {
    return keys.map(([k, , tip]) => {
      if (allowRange.includes(k) && Array.isArray(obj[k])) return h('span', { title: tip || null }, rangeInput(obj, k, { min: -99 }));
      return h('span', { title: tip || null }, numInput(obj, k, { optional: true, min: -999, max: 9999, cls: 'tiny' }));
    });
  }

  const champsBaies = {
    title: 'Champs de baies',
    normalize(c) {
      c.klass = 'ChampsBaiesConfig';
      c.settings = Object.assign(clone(FIELD_DEFAULTS), isObj(c.settings) ? c.settings : {});
      c.mutations = Array.isArray(c.mutations) ? c.mutations : [];
      c.mutations.forEach((m) => { m.parents = Array.isArray(m.parents) ? m.parents.concat(['', '']).slice(0, 2) : ['', '']; m.results = Array.isArray(m.results) ? m.results : []; });
      c.withered_items = Array.isArray(c.withered_items) ? c.withered_items : [];
      c.mulches = isObj(c.mulches) ? c.mulches : {};
      c.traits = isObj(c.traits) ? c.traits : {};
      TRAITS.forEach(([k]) => { if (!isObj(c.traits[k])) c.traits[k] = {}; });
      c.soils = isObj(c.soils) ? c.soils : {};
      c.pests = Array.isArray(c.pests) ? c.pests : [];
      return c;
    },
    serialize(c) {
      c.mutations = c.mutations.filter((m) => m.parents[0] && m.parents[1] && m.results.length);
      c.withered_items = c.withered_items.filter((w) => w.item);
      c.pests = c.pests.filter((p) => p.pokemon);
      return c;
    },
    problems(S) {
      const out = [];
      const c = S.config;
      const total = c.withered_items.reduce((a, w) => a + int(w.weight), 0);
      if (total > 100) out.push(`Les chances des objets des plants flétris dépassent 100 % (${total} %).`);
      if (!c.soils[c.settings.default_soil]) out.push('Le sol de base n’existe pas dans la liste des sols.');
      return out;
    },
    render(S) {
      const c = S.config;
      const ui = S.ui;
      const content = h('div', { class: 'pjr-content' });
      const row = h('div', { class: 'pjr-row' });
      content.appendChild(row);
      // --- réglages
      const left = h('div', { class: 'pjr-col narrow' });
      row.appendChild(left);
      const sets = h('div', { class: 'pjr-settings' });
      FIELD_SETTINGS.forEach(([k, lab, kind, min, max]) => {
        if (kind === 'bool') sets.appendChild(check(c.settings, k, lab));
        else sets.appendChild(h('label', { class: 'pjr-setrow' }, h('span', null, lab), numInput(c.settings, k, { min, max, cls: 'tiny' })));
      });
      sets.appendChild(h('label', { class: 'pjr-setrow' }, h('span', null, 'Sol de base (sans berrysoil)'),
        select(c.settings, 'default_soil', Object.keys(c.soils).map((k) => [k, (c.soils[k].name && c.soils[k].name.fr) || k]))));
      left.appendChild(block('Réglages', null, sets));
      left.appendChild(block('Sur les cartes', null,
        hint('Les emplacements sont les évènements qui appellent l’évènement commun des baies. Dans le nom de l’évènement :'),
        h('div', { class: 'pjr-cmds' },
          [['berrysoil(sandy)', 'sol de l’emplacement (voir « Sols »)'], ['berryzone(field)', 'zone : field, city ou desert (zones préférées / évitées : page Berrydex)']]
            .map(([cmd, tip]) => h('div', { class: 'pjr-cmdrow' }, h('code', { class: 'pjr-cmd', onclick: () => copy(cmd) }, cmd), h('span', { class: 'pjs-hint inline' }, tip)))),
        hint('Météo préférée d’une baie : page Berrydex. Sol préféré : clé « soil » de la baie dans berrydex.json.')));
      left.appendChild(commands([
        ['champ_de_baies', 'interaction avec l’emplacement (faite à la place de l’évènement commun)'],
        ['planter_baie(@event_id, :oran_berry)', 'plante une baie sans passer par le sac'],
        ['baies_mures?(@event_id)', 'condition : les baies de l’emplacement sont mûres'],
      ]));
      const right = h('div', { class: 'pjr-col wide' });
      row.appendChild(right);
      // --- mutations
      const muts = h('div', { class: 'pjr-table' });
      muts.appendChild(h('div', { class: 'pjr-thead mut' }, h('span', null, 'Plant'), h('span', null, 'Voisin'), h('span', null, 'Baie(s) obtenue(s)'), h('span')));
      c.mutations.forEach((m, i) => {
        muts.appendChild(h('div', { class: 'pjr-trow mut' },
          combo({ value: m.parents[0], items: L.berries, placeholder: 'Baie…', onPick: (v) => redo(() => { m.parents[0] = v; }) }),
          combo({ value: m.parents[1], items: L.berries, placeholder: 'Baie…', onPick: (v) => redo(() => { m.parents[1] = v; }) }),
          h('span', { class: 'pjr-chips' }, m.results.map((r, j) => h('span', { class: 'pjr-chip' }, pic(itemIcon(r), 'small'), nameOf('items', r),
            h('button', { class: 'pjr-chip-x', title: 'Retirer', onclick: () => redo(() => { m.results.splice(j, 1); }) }, '✕'))),
          combo({ value: '', items: L.berries, placeholder: '+ baie', cls: 'add', onPick: (v) => redo(() => { if (!m.results.includes(v)) m.results.push(v); }) })),
          rowButtons(c.mutations, i)));
      });
      right.appendChild(block(`Mutations (${c.mutations.length})`, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.mutations.push({ parents: ['', ''], results: [] }); }) }, 'Ajouter'),
        muts, hint('Deux plants côte à côte (haut, bas, gauche, droite) : quand le plant fleurit, il peut préparer une mutation ; à la récolte, la baie obtenue (au hasard parmi celles de la ligne) remplace une de ses baies. L’ordre des deux parents ne compte pas.')));
      // --- sols
      const soils = h('div', { class: 'pjr-cards' });
      Object.entries(c.soils).forEach(([id, soil]) => {
        soils.appendChild(h('div', { class: 'pjr-card' },
          h('div', { class: 'pjr-cardhead' }, h('code', { class: 'pjr-cmd', title: 'berrysoil(' + id + ')', onclick: () => copy(`berrysoil(${id})`) }, id),
            h('button', { class: 'pjs-btn small danger', disabled: id === c.settings.default_soil, title: id === c.settings.default_soil ? 'Sol de base' : 'Supprimer', onclick: () => { if (confirm(`Supprimer le sol « ${id} » ?`)) redo(() => { delete c.soils[id]; }); } }, '✕')),
          labeled('Nom', langInputs(soil, 'name')),
          labeled('En plantant : « La terre est … »', langInputs(soil, 'plant')),
          labeled('Après la cueillette : « Le sol est redevenu … »', langInputs(soil, 'picked')),
          h('div', { class: 'pjr-numrow' }, TRAIT_KEYS.map(([k, lab]) => h('label', { class: 'pjr-mini' }, h('span', null, lab),
            k === 'yield' ? h('span', { class: 'pjr-yield' }, Array.isArray(soil.yield) ? rangeInput(soil, 'yield', { min: -9, max: 20 }) : numInput(soil, 'yield', { min: -9, max: 20, cls: 'tiny' }),
              h('button', { class: 'pjs-btn small', title: Array.isArray(soil.yield) ? 'Nombre fixe' : 'Au hasard entre deux nombres', onclick: () => redo(() => { soil.yield = Array.isArray(soil.yield) ? int(soil.yield[0]) : [int(soil.yield), int(soil.yield) + 1]; }) }, Array.isArray(soil.yield) ? '=' : '↔'))
              : numInput(soil, k, { min: -99, max: 999, cls: 'tiny' }))))));
      });
      const newSoil = h('input', { class: 'pjs-input pjr-short', placeholder: 'nouveau_sol' });
      right.appendChild(block(`Sols (${Object.keys(c.soils).length})`, h('span', { class: 'pjr-actions' }, newSoil, h('button', { class: 'pjs-btn small', onclick: () => {
        const id = newSoil.value.trim().toLowerCase().replace(/[^a-z0-9_]+/g, '_');
        if (!id) return toast('Donne un identifiant au sol (lettres, chiffres, _).', true);
        if (c.soils[id]) return toast('Ce sol existe déjà.', true);
        redo(() => { c.soils[id] = { name: { fr: id, en: id }, plant: { fr: '', en: '' }, picked: { fr: '', en: '' } }; });
      } }, 'Ajouter')), soils, hint('Les valeurs s’ajoutent à celles du plant (Heures / stade : -1 fait pousser plus vite ; Séchage : 15 = la terre sèche 15 % plus vite).')));
      // --- engrais
      const mul = h('div', { class: 'pjr-table' });
      mul.appendChild(h('div', { class: 'pjr-thead mulch' }, h('span', null, 'Engrais'), MULCH_KEYS.map(([, lab, tip]) => h('span', { title: tip }, lab)), h('span')));
      Object.keys(c.mulches).forEach((item) => {
        mul.appendChild(h('div', { class: 'pjr-trow mulch' }, h('span', { class: 'pjr-itemname' }, pic(itemIcon(item), 'small'), nameOf('items', item)),
          numGrid(c.mulches[item], MULCH_KEYS),
          h('button', { class: 'pjs-btn small danger', onclick: () => redo(() => { delete c.mulches[item]; }) }, '✕')));
      });
      right.appendChild(block(`Engrais (${Object.keys(c.mulches).length})`, combo({ value: '', items: L.items, placeholder: '+ Ajouter un objet', cls: 'add', onPick: (v) => redo(() => { if (!c.mulches[v]) c.mulches[v] = {}; }) }),
        mul, hint('Case vide : pas d’effet. Le joueur choisit l’engrais en plantant ; il reste jusqu’à ce que le plant disparaisse. Survole les titres pour le détail.')));
      // --- traits
      const tr = h('div', { class: 'pjr-table' });
      tr.appendChild(h('div', { class: 'pjr-thead trait' }, h('span', null, 'Quand…'), TRAIT_KEYS.map(([, lab]) => h('span', null, lab))));
      TRAITS.forEach(([k, lab]) => tr.appendChild(h('div', { class: 'pjr-trow trait' }, h('span', null, lab), numGrid(c.traits[k], TRAIT_KEYS, { allowRange: ['yield'] }))));
      right.appendChild(block('Bonus et malus', null, tr, hint('S’ajoutent tant que la condition est vraie. Exemple : en zone préférée, +2 baies et un stade d’une heure plus court.')));
      // --- objets des plants flétris
      const wi = h('div', { class: 'pjr-table' });
      c.withered_items.forEach((w, i) => {
        const parent = w.item === 'parent';
        wi.appendChild(h('div', { class: 'pjr-trow withered' }, h('span', { class: 'pjr-yield' }, numInput(w, 'weight', { min: 0, max: 100, cls: 'tiny' }), '%'),
          h('label', { class: 'pjs-inline pjr-check' }, h('input', { type: 'checkbox', checked: parent, onchange: (e) => redo(() => { w.item = e.target.checked ? 'parent' : ''; }) }), 'Sa propre baie'),
          parent ? h('span') : combo({ value: w.item, items: L.items, placeholder: 'Objet…', onPick: (v) => redo(() => { w.item = v; }) }),
          rowButtons(c.withered_items, i)));
      });
      const totalW = c.withered_items.reduce((a, w) => a + int(w.weight), 0);
      right.appendChild(block('Objets laissés par un plant flétri', h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.withered_items.push({ weight: 5, item: '' }); }) }, 'Ajouter'),
        wi, hint(`Quand un plant disparaît pour de bon, il peut laisser un objet par terre (le joueur le ramasse en touchant l’emplacement). Total : ${totalW} % (rien le reste du temps).`)));
      // --- nuisibles
      const pe = h('div', { class: 'pjr-table' });
      pe.appendChild(h('div', { class: 'pjr-thead pest' }, h('span', null, 'Pokémon'), h('span', null, 'Couleur de baie'), h('span', null, 'Poids'), h('span', null, 'Niveaux'), h('span')));
      c.pests.forEach((p, i) => {
        if (!Array.isArray(p.levels)) p.levels = [5, 5];
        pe.appendChild(h('div', { class: 'pjr-trow pest' },
          combo({ value: p.pokemon, items: L.creatures, placeholder: 'Pokémon…', onPick: (v) => redo(() => { p.pokemon = v; }) }),
          select(p, 'color', COLORS), numInput(p, 'weight', { min: 1, max: 999, cls: 'tiny' }), rangeInput(p, 'levels', { min: 1, max: 100 }), rowButtons(c.pests, i)));
      });
      right.appendChild(block(`Nuisibles (${c.pests.length})`, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.pests.push({ weight: 20, pokemon: '', levels: [5, 10], color: '' }); }) }, 'Ajouter'),
        pe, hint('Le Pokémon est tiré parmi ceux de la couleur de la baie (couleur des Poffins / Pokéblocs) et ceux sans couleur ; plus le poids est grand, plus il sort souvent.')));
      void ui;
      return content;
    },
  };

  // ===========================================================================
  // Données > Gimmicks > Styles PLA (styles_pla.json)
  // ===========================================================================
  const STYLE_DEFAULTS = { enabled: true, turns: 2, cooldown: 3, extra_pp: 1, pla_mastery: true, wild_chance: 10, trainer_mastery: true, disable_switch: 0, show_info: true, ai: true };
  const stylesPla = {
    title: 'Styles de combat (Légendes Arceus)',
    normalize(c) {
      c.klass = 'StylesPLAConfig';
      c.settings = Object.assign(clone(STYLE_DEFAULTS), isObj(c.settings) ? c.settings : {});
      c.cant_master = Array.isArray(c.cant_master) ? c.cant_master : [];
      return c;
    },
    render(S) {
      const c = S.config;
      const ui = S.ui;
      const content = h('div', { class: 'pjr-content' });
      const row = h('div', { class: 'pjr-row' });
      content.appendChild(row);
      const left = h('div', { class: 'pjr-col narrow' });
      row.appendChild(left);
      const sets = h('div', { class: 'pjr-settings' },
        check(c.settings, 'enabled', 'Styles Puissant et Rapide en combat'),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Durée d’un style (tours)'), numInput(c.settings, 'turns', { min: 1, max: 9, cls: 'tiny' })),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Attente avant le style suivant (tours)'), numInput(c.settings, 'cooldown', { min: 0, max: 20, cls: 'tiny' })),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'PP en plus pour une capacité avec style'), numInput(c.settings, 'extra_pp', { min: 0, max: 5, cls: 'tiny' })),
        check(c.settings, 'pla_mastery', 'La Graine Maîtrise ne marche pas sur les capacités apprises par niveau (comme dans PLA)'),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Pokémon sauvages qui maîtrisent une capacité (%)'), numInput(c.settings, 'wild_chance', { min: 0, max: 100, cls: 'tiny' })),
        check(c.settings, 'trainer_mastery', 'Les Pokémon des dresseurs maîtrisent leurs capacités'),
        check(c.settings, 'ai', 'Les dresseurs utilisent les styles'),
        check(c.settings, 'show_info', 'Cadre qui explique les effets du style'),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Interrupteur qui bloque les styles (0 : aucun)'), numInput(c.settings, 'disable_switch', { min: 0, max: 9999, cls: 'tiny' })));
      left.appendChild(block('Réglages', null, sets,
        hint('Maîtrise : une capacité apprise par niveau est maîtrisée 9 à 11 niveaux plus tard. Puissant : plus fort, agit après les autres. Rapide : moins fort, agit en premier.')));
      left.appendChild(commands([
        ['maitriser_capacite(0, :flamethrower)', 'le 1er Pokémon de l’équipe maîtrise la capacité'],
        ['capacite_maitrisee?(0, :flamethrower)', 'condition : capacité maîtrisée'],
        ['oublier_maitrise(0, :flamethrower)', 'retire la maîtrise'],
      ]));
      const right = h('div', { class: 'pjr-col wide' });
      row.appendChild(right);
      const search = h('input', { class: 'pjs-input pjr-short', placeholder: 'Filtrer…', value: ui.filter || '' });
      const chips = h('div', { class: 'pjr-chips big' });
      const fill = () => {
        chips.textContent = '';
        const q = plain(search.value);
        c.cant_master.forEach((m, i) => {
          const name = nameOf('moves', m);
          if (q && !plain(name + ' ' + m).includes(q)) return;
          chips.appendChild(h('span', { class: 'pjr-chip', title: m }, name,
            h('button', { class: 'pjr-chip-x', title: 'Retirer', onclick: () => redo(() => { c.cant_master.splice(i, 1); }) }, '✕')));
        });
      };
      search.addEventListener('input', () => { ui.filter = search.value; fill(); });
      fill();
      const add = combo({ value: '', items: () => L.moves().filter((m) => !c.cant_master.includes(m.value)), placeholder: '+ Ajouter une capacité', cls: 'add', onPick: (v) => redo(() => { c.cant_master.push(v); }) });
      right.appendChild(block(`Capacités qui ne peuvent pas être maîtrisées (${c.cant_master.length})`, h('span', { class: 'pjr-actions' }, search, add), chips,
        hint('Ces capacités ne sont jamais maîtrisées (ni par niveau, ni avec la Graine Maîtrise) : pas de style possible avec elles.')));
      return content;
    },
  };

  // ===========================================================================
  // Level design > Mini-jeux > Sac de frappe (sac_de_frappe.json)
  // ===========================================================================
  const STATS = [['hp', 'PV'], ['atk', 'Attaque'], ['dfe', 'Défense'], ['spd', 'Vitesse'], ['ats', 'Atq. Spé.'], ['dfs', 'Déf. Spé.']];
  function soundPicker(obj, key) {
    const list = cur().ctx.ses || [];
    return h('span', { class: 'pjr-sound' },
      combo({ value: obj[key] || '', items: () => list.map((s) => ({ value: s, label: s.replace(/^audio\/se\//, '') })), allowEmpty: true, emptyLabel: '(aucun son)', onPick: (v) => redo(() => { obj[key] = v; }) }),
      h('button', { class: 'pjs-btn small', title: 'Écouter', disabled: !obj[key], onclick: () => play(obj[key]) }, '▶'));
  }
  // Sacs du Super Training de X / Y (graphics/interface/sac_de_frappe/sacs/), mêmes ids que le plugin (BAGS)
  const PUNCH_BAGS = [['', 'Sac d’origine'], ['gris', 'Sac gris'], ['rose', 'Sac rose'], ['team_flare', 'Sac Team Flare'], ['jaune', 'Sac jaune'], ['bleu', 'Sac bleu'], ['violet', 'Sac violet'],
    ['vert', 'Sac vert'], ['double', 'Sac ×2'], ['noir', 'Sac noir']].concat(...[['aquatique', 'aquatique'], ['scarabee', 'scarabée'], ['acier', 'acier'], ['spectre', 'spectre'], ['givre', 'givre'], ['plante', 'plante']]
    .map(([id, fr]) => [1, 2, 3].map((n) => [`${id}_${n}`, `Sac ${fr} ${n}`])));
  const bagPic = (id) => (id ? `graphics/interface/sac_de_frappe/sacs/${id}` : 'graphics/interface/sac_de_frappe/bag');
  const bagPicker = (obj, key) => combo({ value: obj[key] || '', items: () => PUNCH_BAGS.map(([id, name]) => ({ value: id, label: name, sub: id, icon: bagPic(id), iconCls: 'bag' })),
    onPick: (v) => redo(() => { obj[key] = v; }) });
  const sacDeFrappe = {
    title: 'Sac de frappe',
    normalize(c) {
      c.klass = 'SacDeFrappeConfig';
      c.settings = Object.assign({ rounds: 10, arrow_speed: 320, can_cancel: true, perfect_se: 'audio/se/pokemove', hit_se: ['audio/se/hitlow', 'audio/se/hit', 'audio/se/hitplus'], bag: '' }, isObj(c.settings) ? c.settings : {});
      if (!Array.isArray(c.settings.hit_se)) c.settings.hit_se = ['', '', ''];
      while (c.settings.hit_se.length < 3) c.settings.hit_se.push('');
      c.sessions = Array.isArray(c.sessions) ? c.sessions : [];
      c.sessions.forEach((s) => { if (!Array.isArray(s.stats)) s.stats = []; });
      return c;
    },
    problems(S) {
      const out = [];
      const seen = new Set();
      S.config.sessions.forEach((s, i) => {
        if (!s.id) out.push(`La séance n° ${i + 1} n’a pas d’identifiant.`);
        else if (seen.has(s.id)) out.push(`Identifiant de séance en double : ${s.id}`);
        seen.add(s.id);
      });
      return out;
    },
    render(S) {
      const c = S.config;
      const st = c.settings;
      const content = h('div', { class: 'pjr-content' });
      const row = h('div', { class: 'pjr-row' });
      content.appendChild(row);
      const left = h('div', { class: 'pjr-col narrow' });
      row.appendChild(left);
      left.appendChild(block('Réglages', null, h('div', { class: 'pjr-settings' },
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Coups par partie (sac_de_frappe sans nombre)'), numInput(st, 'rounds', { min: 1, max: 99, cls: 'tiny' })),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Vitesse de la flèche (pixels / seconde)'), numInput(st, 'arrow_speed', { min: 40, max: 2000, step: 10, cls: 'tiny' })),
        check(st, 'can_cancel', 'B arrête la partie'),
        labeled('Sac par défaut', h('span', { class: 'pjr-bagpick' }, bagPicker(st, 'bag'), pic(bagPic(st.bag), 'bag'))),
        labeled('Son d’un coup parfait (5 étoiles)', soundPicker(st, 'perfect_se')),
        ...['faible', 'normal', 'fort'].map((l, i) => labeled(`Son d’un coup ${l}`, soundPicker(st.hit_se, i))))));
      left.appendChild(commands([
        ['sac_de_frappe', 'partie libre (sac_de_frappe(5) : 5 coups ; options : min_score:, stats: [:atk], ev:, iv:…)'],
        ['sac_de_frappe_seance(:attaque)', 'lance une séance de la liste'],
        ['score_sac_de_frappe', 'score de la dernière partie'],
        ['sac_de_frappe_reussi?', 'condition : le score minimum a été atteint'],
      ]));
      const right = h('div', { class: 'pjr-col wide' });
      row.appendChild(right);
      const list = h('div', { class: 'pjr-cards' });
      c.sessions.forEach((s, i) => {
        const max = int(s.rounds, st.rounds) * 5;
        list.appendChild(h('div', { class: 'pjr-card' },
          h('div', { class: 'pjr-cardhead' }, h('code', { class: 'pjr-cmd', title: 'Cliquer pour copier la commande', onclick: () => copy(`sac_de_frappe_seance(:${s.id})`) }, `:${s.id || '?'}`), rowButtons(c.sessions, i, { confirmText: `Supprimer « ${s.name || s.id} » ?` })),
          h('div', { class: 'pjr-grid2' },
            labeled('Identifiant', textInput(s, 'id', { onChange: () => {} })),
            labeled('Nom affiché', textInput(s, 'name'))),
          labeled('Sac (vide : sac par défaut)', h('span', { class: 'pjr-bagpick' }, bagPicker(s, 'bag'), pic(bagPic(s.bag || st.bag), 'bag'))),
          h('div', { class: 'pjr-numrow' },
            h('label', { class: 'pjr-mini' }, h('span', null, 'Coups'), numInput(s, 'rounds', { min: 1, max: 99, cls: 'tiny', onChange: () => {} })),
            h('label', { class: 'pjr-mini' }, h('span', null, `Score mini (max ${max})`), numInput(s, 'min_score', { min: 0, max, cls: 'tiny' })),
            h('label', { class: 'pjr-mini' }, h('span', null, 'EV gagnés'), numInput(s, 'ev', { min: 0, max: 252, cls: 'tiny' })),
            h('label', { class: 'pjr-mini' }, h('span', null, 'IV gagnés'), numInput(s, 'iv', { min: 0, max: 31, cls: 'tiny' })),
            h('label', { class: 'pjr-mini' }, h('span', null, 'Niveau mini'), numInput(s, 'min_level', { min: 0, max: 100, cls: 'tiny' }))),
          h('div', { class: 'pjr-stats' }, h('span', { class: 'pjs-label' }, 'Stats entraînées'), STATS.map(([k, lab]) => h('label', { class: 'pjs-inline pjr-check' },
            h('input', { type: 'checkbox', checked: s.stats.includes(k), onchange: (e) => soft(() => { s.stats = STATS.map(([x]) => x).filter((x) => (x === k ? e.target.checked : s.stats.includes(x))); }) }), lab))),
          h('div', { class: 'pjr-flags' }, check(s, 'max_iv', 'IV mis à 31'), check(s, 'fainted', 'Un Pokémon K.O. peut jouer'), check(s, 'block_max', 'Refuse un Pokémon déjà au maximum'))));
      });
      right.appendChild(block(`Séances (${c.sessions.length})`, h('button', { class: 'pjs-btn small', onclick: () => redo(() => {
        let n = c.sessions.length + 1; while (c.sessions.some((s) => s.id === 'seance' + n)) n++;
        c.sessions.push({ id: 'seance' + n, name: 'Nouvelle séance', rounds: 10, min_score: 30, stats: ['atk'], ev: 4, iv: 0, max_iv: false, fainted: false, block_max: true, min_level: 0 });
      }) }, 'Ajouter'), list, hint('Chaque coup vaut 1 à 5 étoiles (plus la flèche est près du centre, plus il vaut). Si le score atteint le minimum, le Pokémon gagne les EV / IV dans chaque stat cochée.')));
      right.appendChild(block(`Sacs (${PUNCH_BAGS.length})`, null, h('div', { class: 'pjr-bags' }, PUNCH_BAGS.map(([id, name]) => h('span', { class: 'pjr-bd', title: id || 'bag' },
        pic(bagPic(id), 'bag big'), h('span', { class: 'pjs-hint inline' }, name)))), hint('Commande : sac_de_frappe(10, bag: \'team_flare\'). Une séance peut avoir son propre sac.')));
      return content;
    },
  };

  // ===========================================================================
  // Level design > Mini-jeux > Poké Récré (poke_recre.json)
  // ===========================================================================
  const BACKDROPS = ['field', 'forest', 'cave', 'cave_dark', 'city', 'mountain', 'snow', 'water', 'underwater', 'indoor_a', 'indoor_b', 'indoor_c', 'champion', 'elite_a', 'elite_b', 'elite_c', 'elite_d'];
  // Décors de X / Y (graphics/interface/poke_recre/fonds/) et décorations (deco/), mêmes ids que le plugin (00103)
  const XY_TYPES = [['normal', 'Normal'], ['fire', 'Feu'], ['water', 'Eau'], ['electric', 'Électrik'], ['grass', 'Plante'], ['ice', 'Glace'], ['fighting', 'Combat'], ['poison', 'Poison'], ['ground', 'Sol'],
    ['flying', 'Vol'], ['psychic', 'Psy'], ['bug', 'Insecte'], ['rock', 'Roche'], ['ghost', 'Spectre'], ['dragon', 'Dragon'], ['dark', 'Ténèbres'], ['steel', 'Acier'], ['fairy', 'Fée']];
  const XY_COLORS = ['rouge', 'bleu', 'orange', 'vert', 'violet', 'marron', 'jaune', 'blanc', 'noir'];
  const XY_BACKDROPS = [].concat(XY_TYPES.map(([t, fr]) => [`type_${t}`, `Type ${fr}`]), XY_COLORS.map((c) => [`couleur_${c}`, `Poké Ball ${c}`]),
    ['rose', 'bleu', 'orange'].map((c) => [`nuage_${c}`, `Nuages ${c}`]), [['style_pois', 'Pois'], ['style_rayures', 'Rayures'], ['style_carreaux', 'Carreaux'], ['salon', 'Salon chic']]);
  const backdropPic = (b) => (XY_BACKDROPS.some(([id]) => id === b) ? `graphics/interface/poke_recre/fonds/${b}` : `graphics/interface/poke_recre/bg_${b}`);
  const XY_SHAPES = [['rond', 'Coussin rond'], ['plat', 'Coussin plat'], ['etoile', 'Coussin étoile'], ['cube', 'Cube']];
  const XY_DECOS = [].concat(
    XY_TYPES.map(([t, fr]) => [`coeur_${t}`, `Coussin cœur ${fr}`]),
    ...XY_TYPES.map(([t, fr]) => [[`${t}_coussin_a`, `Coussin ${fr}`], [`${t}_coussin_b`, `Coussin ${fr} 2`], [`${t}_objet_a`, `Objet ${fr}`], [`${t}_objet_b`, `Objet ${fr} 2`], [`${t}_grand`, `Grand décor ${fr}`]]),
    ...XY_COLORS.map((col) => XY_SHAPES.map(([sh, fr]) => [`${sh}_${col}`, `${fr} ${col}`])),
    ...['rose', 'bleu', 'orange'].map((col) => [['nuage_a', 'Nuage'], ['nuage_b', 'Nuage 2'], ['nuage_etoile', 'Étoile nuage'], ['nuage_cube', 'Cube nuage']].map(([sh, fr]) => [`${sh}_${col}`, `${fr} ${col}`])),
    ...[['pois', 'à pois'], ['rayures', 'rayé'], ['carreaux', 'à carreaux']].map(([st, sfr]) => XY_SHAPES.map(([sh, fr]) => [`${sh}_${st}`, `${fr} ${sfr}`])),
    [['chic_chaise_a', 'Chaise chic'], ['chic_chaise_b', 'Chaise chic 2'], ['chic_table', 'Table chic'], ['chic_lit', 'Lit chic']]);
  const PUFF_LEVELS = ['Simple', 'Crème', 'Décorée', 'Deluxe', 'Spéciale'];
  const pokeRecre = {
    title: 'Poké Récré',
    normalize(c) {
      c.klass = 'PokeRecreConfig';
      c.settings = Object.assign({ follower: 'ask', steps: 50, sylveon_hearts: 2, all_berries: true, pet_distance: 500, berry_affection: [3, 6], berry_fullness: 90,
        puff_affection: [[4, 8], [8, 12], [12, 18], [18, 25], [20, 30]], puff_fullness: 60, puff_liked_bonus: 50, all_decorations: false, start_decorations: ['coeur_normal', 'rond_rouge'],
        decoration_chance: 35, cure_pets: 3, hand_style: 'xy', game_time: 60, berry_stars: [5, 10, 15, 20, 30], head_stars: [10, 20, 35, 50, 80] }, isObj(c.settings) ? c.settings : {});
      const st = c.settings;
      if (!Array.isArray(st.puff_affection)) st.puff_affection = [];
      for (let i = 0; i < 5; i++) if (!Array.isArray(st.puff_affection[i])) st.puff_affection[i] = [4 + i * 5, 8 + i * 6];
      ['berry_stars', 'head_stars'].forEach((k) => { if (!Array.isArray(st[k])) st[k] = []; for (let i = 0; i < 5; i++) st[k][i] = int(st[k][i], (i + 1) * 5); });
      if (!Array.isArray(st.start_decorations)) st.start_decorations = [];
      if (!Array.isArray(c.settings.berry_affection)) c.settings.berry_affection = [int(c.settings.berry_affection, 3), int(c.settings.berry_affection, 3)];
      c.foods = Array.isArray(c.foods) ? c.foods : [];
      c.foods.forEach((f) => { if (!Array.isArray(f.affection)) f.affection = [int(f.affection), int(f.affection)]; });
      c.backdrops = isObj(c.backdrops) ? c.backdrops : {};
      return c;
    },
    serialize(c) {
      c.foods = c.foods.filter((f) => f.item);
      return c;
    },
    render(S) {
      const c = S.config;
      const st = c.settings;
      const content = h('div', { class: 'pjr-content' });
      const row = h('div', { class: 'pjr-row' });
      content.appendChild(row);
      const left = h('div', { class: 'pjr-col narrow' });
      row.appendChild(left);
      left.appendChild(block('Réglages', null, h('div', { class: 'pjr-settings' },
        h('label', { class: 'pjr-setrow' }, h('span', null, 'En parlant au Pokémon qui suit'), select(st, 'follower', [['ask', 'Proposer de jouer'], ['direct', 'Ouvrir tout de suite'], ['off', 'Rien']])),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Pas pour perdre 1 point de satiété et de bonne humeur'), numInput(st, 'steps', { min: 1, max: 9999, cls: 'tiny' })),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Cœurs d’affection pour Nymphali'), numInput(st, 'sylveon_hearts', { min: 0, max: 5, cls: 'tiny' })),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Mouvement de la main pour une caresse'), numInput(st, 'pet_distance', { min: 50, max: 5000, step: 10, cls: 'tiny' })),
        check(st, 'all_berries', 'Toutes les baies se mangent'),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Affection donnée par une baie'), rangeInput(st, 'berry_affection', { min: 0, max: 255 })),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Satiété donnée par une baie'), numInput(st, 'berry_fullness', { min: 0, max: 255, cls: 'tiny' }))),
        hint('Jauges de 0 à 255 (5 niveaux à l’écran). L’affection ne baisse jamais ; la satiété et la bonne humeur baissent en marchant.')));
      left.appendChild(commands([
        ['poke_recre', 'ouvre Poké Récré (poke_recre(0) : avec le 1er Pokémon de l’équipe)'],
        ['affection_pokemon(0)', 'niveau d’affection (0 à 5) du 1er Pokémon (affection_pokemon(0, true) : points)'],
        ['donner_affection(0, 50)', 'donne des points d’affection'],
        ['satiete_pokemon(0)', 'niveau de satiété'],
        ['bonne_humeur_pokemon(0)', 'niveau de bonne humeur'],
        ['cueille_baies(0)', 'mini-jeu Cueille-Baies (jongle_tete(0) : Jongle-Tête) ; renvoie les points'],
        ['donner_pofiterole(\'sucree_creme\', 2)', 'donne des Pofiteroles (nil : au hasard) ; pofiteroles : combien on en a'],
        ['donner_decoration(\'coeur_fire\')', 'débloque une décoration (nil : au hasard) ; decoration_debloquee?(id)'],
        ['changer_fond_poke_recre(\'type_fire\')', 'impose le fond (\'auto\' : selon l’endroit)'],
        ['record_poke_recre(\'cueille\')', 'meilleur score (\'cueille\' ou \'jongle\')'],
      ]));
      left.appendChild(block('Pofiteroles', null, h('div', { class: 'pjr-settings' },
        ...PUFF_LEVELS.map((name, i) => h('label', { class: 'pjr-setrow' }, h('span', null, `Affection (${name})`), rangeInput(st.puff_affection, i, { min: 0, max: 255 }))),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Satiété donnée'), numInput(st, 'puff_fullness', { min: 0, max: 255, cls: 'tiny' })),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Bonus pour la saveur aimée (%)'), numInput(st, 'puff_liked_bonus', { min: 0, max: 500, cls: 'tiny' }))),
        pic('graphics/interface/poke_recre/pofiteroles', 'puffs'),
        hint('5 saveurs (sucrée, mentholée, aigre, amère, épicée) × 4 niveaux, plus 6 spéciales (×1,5). La saveur aimée dépend de la nature (mentholée = sec). On en gagne aux mini-jeux.')));
      left.appendChild(block('Mini-jeux et soins', null, h('div', { class: 'pjr-settings' },
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Durée d’une partie (secondes)'), numInput(st, 'game_time', { min: 10, max: 300, cls: 'tiny' })),
        h('div', { class: 'pjr-stars' }, h('span', null, 'Cueille-Baies : baies pour 1 à 5 étoiles'), h('span', { class: 'pjr-range' }, [0, 1, 2, 3, 4].map((i) => numInput(st.berry_stars, i, { min: 0, max: 999, cls: 'tiny' })))),
        h('div', { class: 'pjr-stars' }, h('span', null, 'Jongle-Tête : points pour 1 à 5 étoiles'), h('span', { class: 'pjr-range' }, [0, 1, 2, 3, 4].map((i) => numInput(st.head_stars, i, { min: 0, max: 9999, cls: 'tiny' })))),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Chance de gagner une décoration (%)'), numInput(st, 'decoration_chance', { min: 0, max: 100, cls: 'tiny' })),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Caresses pour guérir un statut (0 : jamais)'), numInput(st, 'cure_pets', { min: 0, max: 99, cls: 'tiny' })),
        h('label', { class: 'pjr-setrow' }, h('span', null, 'Main'), select(st, 'hand_style', [['xy', 'Main de X / Y (animée, statuts)'], ['classic', 'Main simple']]))),
        hint('Récompenses : 1 Pofiterole (Simple à Deluxe selon les étoiles, 2 à 5 étoiles), parfois une décoration à partir de 3 étoiles. Brûlure, gel, poison et paralysie se voient sur la main pendant les caresses.')));
      const right = h('div', { class: 'pjr-col wide' });
      row.appendChild(right);
      const foods = h('div', { class: 'pjr-table' });
      foods.appendChild(h('div', { class: 'pjr-thead food' }, h('span', null, 'Friandise'), h('span', null, 'Affection'), h('span', null, 'Satiété'), h('span')));
      c.foods.forEach((f, i) => foods.appendChild(h('div', { class: 'pjr-trow food' },
        combo({ value: f.item, items: L.items, placeholder: 'Objet…', onPick: (v) => redo(() => { f.item = v; }) }),
        rangeInput(f, 'affection', { min: 0, max: 255 }), numInput(f, 'fullness', { min: 0, max: 255, cls: 'tiny' }), rowButtons(c.foods, i))));
      right.appendChild(block(`Friandises (${c.foods.length})`, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.foods.push({ item: '', affection: [3, 6], fullness: 90 }); }) }, 'Ajouter'),
        foods, hint('Objets que le joueur peut donner à manger (en plus des baies). L’affection gagnée est tirée entre les deux nombres.')));
      const bd = h('div', { class: 'pjr-table' });
      const maps = S.ctx.maps || [];
      Object.keys(c.backdrops).sort((a, b) => int(a) - int(b)).forEach((id) => {
        const m = maps.find((x) => String(x.id) === String(id));
        bd.appendChild(h('div', { class: 'pjr-trow backdrop' },
          h('span', null, m ? `${m.name} (n° ${id})` : `Carte n° ${id}`),
          select(c.backdrops, id, BACKDROPS.map((b) => [b, b]).concat(XY_BACKDROPS), { onChange: () => {} }),
          pic(backdropPic(c.backdrops[id]), 'thumb'),
          h('button', { class: 'pjs-btn small danger', onclick: () => redo(() => { delete c.backdrops[id]; }) }, '✕')));
      });
      const addMap = combo({ value: '', items: () => maps.filter((m) => !(String(m.id) in c.backdrops)).map((m) => ({ value: String(m.id), label: m.name, sub: `n° ${m.id}` })), placeholder: '+ Ajouter une carte', cls: 'add',
        onPick: (v) => redo(() => { c.backdrops[v] = 'field'; }) });
      right.appendChild(block(`Décors imposés (${Object.keys(c.backdrops).length})`, addMap, bd,
        hint('Sur les autres cartes, le décor est choisi selon l’endroit (grotte, eau, ville, intérieur…).'),
        h('div', { class: 'pjr-backdrops' }, BACKDROPS.map((b) => h('span', { class: 'pjr-bd', title: b }, pic(`graphics/interface/poke_recre/bg_${b}`, 'thumb'), h('span', { class: 'pjs-hint inline' }, b)))),
        h('div', { class: 'pjr-backdrops' }, XY_BACKDROPS.map(([b, name]) => h('span', { class: 'pjr-bd', title: b }, pic(backdropPic(b), 'thumb'), h('span', { class: 'pjs-hint inline' }, name))))));
      // Décorations
      const decoName = (id) => (XY_DECOS.find((d) => d[0] === id) || [id, id])[1];
      const startList = h('div', { class: 'pjr-decos' }, st.start_decorations.map((id, i) => h('span', { class: 'pjr-deco', title: id },
        pic(`graphics/interface/poke_recre/deco/${id}`, 'deco'), h('span', { class: 'pjs-hint inline' }, decoName(id)),
        h('button', { class: 'pjs-btn small danger', onclick: () => redo(() => { st.start_decorations.splice(i, 1); }) }, '✕'))));
      const addDeco = combo({ value: '', items: () => XY_DECOS.filter(([id]) => !st.start_decorations.includes(id)).map(([id, name]) => ({ value: id, label: name, sub: id, icon: `graphics/interface/poke_recre/deco/${id}` })),
        placeholder: '+ Ajouter une décoration', cls: 'add', onPick: (v) => redo(() => { st.start_decorations.push(v); }) });
      right.appendChild(block(`Décorations (${XY_DECOS.length})`, addDeco, h('div', { class: 'pjr-settings' }, check(st, 'all_decorations', 'Toutes les décorations sont disponibles dès le début')),
        h('div', { class: 'pjs-hint' }, 'Décorations données au départ :'), startList,
        hint('Dans Poké Récré, L (ou le bouton coussin) choisit le fond et une décoration à gauche et à droite du Pokémon. Les autres se gagnent aux mini-jeux ou avec la commande donner_decoration.'),
        h('div', { class: 'pjr-decos all' }, XY_DECOS.map(([id, name]) => h('span', { class: 'pjr-deco', title: `${name} (${id})` }, pic(`graphics/interface/poke_recre/deco/${id}`, 'deco'))))));
      return content;
    },
  };

  // ===========================================================================
  // Level design > Mini-jeux > Raids (raids.json)
  // ===========================================================================
  const RAID_STYLES = [['basic', 'Basique'], ['ultra', 'Ultra (Z)'], ['max', 'Dynamax'], ['tera', 'Téracristal']];
  const RAID_SETTINGS = [
    ['party_size', 'Pokémon du joueur en combat (1 à 3)', 'num', 1, 3],
    ['turn_limit', 'Tours de base (+ selon l’équipe et le rang)', 'num', 1, 99],
    ['knock_outs', 'K.O. de base (+ selon l’équipe et le rang)', 'num', 1, 20],
    ['shields', 'Bouclier du boss', 'bool'],
    ['shield_threshold', 'PV du boss où le bouclier apparaît (%)', 'num', 1, 99],
    ['extra_actions', 'Actions en plus du boss (rang 3 et plus)', 'bool'],
    ['double_attack', 'Le boss affaibli attaque deux fois', 'bool'],
    ['cheers', 'Encouragements (à la place de la Fuite)', 'bool'],
    ['z_power_every', 'Raid Ultra : capacité Z du boss tous les … tours', 'num', 1, 10],
    ['badge_ranks', 'Rang au hasard selon les badges', 'bool'],
    ['den_daily_reset', 'Les antres vaincus se remplissent chaque jour', 'bool'],
    ['den_daily_change', 'Tous les antres changent chaque jour (Pokémon retirés au hasard)', 'bool'],
    ['den_notify', 'Notification du téléphone pour un raid rare', 'bool'],
    ['den_rewards', 'Récompenses après un antre', 'bool'],
    ['no_exp', 'Pas d’expérience pendant les raids', 'bool'],
    ['heal_after', 'Soigner les statuts de l’équipe après le raid', 'bool'],
    ['obscur_chance', 'Raid Obscur : chance par antre (%, plugin Pokémon Obscurs)', 'num', 0, 100],
    ['obscur_gauge', 'Raid Obscur : taille de la jauge cœur (0 : celle des Obscurs)', 'num', 0, 99],
  ];
  const RAID_DEFAULTS = {
    party_size: 2, turn_limit: 10, knock_outs: 4, shields: true, shield_threshold: 50, extra_actions: true, double_attack: true,
    cheers: true, z_power_every: 2, badge_ranks: true, den_daily_reset: true, den_daily_change: true, den_notify: true, den_rewards: true, no_exp: true, heal_after: true, obscur_chance: 0, obscur_gauge: 0, bait_item: 'raid_bait',
  };
  const STYLE_BASE = {
    basic: { name: ['Raid', 'Raid'], den: ['Antre de raid', 'Raid Den'], adventure: ['Aventure Raid', 'Raid Adventure'], charset: 'raid_den_basic', background: 'back_cave', bgm: ['raid_basic_battle_1', 'raid_basic_battle_2'], capture_bgm: 'raid_basic_capture', adventure_bgm: 'raid_basic_adventure', appear: ['%s sort de l’antre !', '%s emerged from within the den!'], flee: ['%s disparaît au fond de l’antre…', '%s disappeared somewhere into the den...'] },
    ultra: { name: ['Raid Ultra', 'Ultra Raid'], den: ['Brèche Ultra', 'Ultra Raid Wormhole'], adventure: ['Aventure Ultra', 'Ultra Adventure'], charset: 'raid_den_ultra', background: 'back_raid_ultra', bgm: ['raid_ultra_battle_1', 'raid_ultra_battle_2'], capture_bgm: 'raid_ultra_capture', adventure_bgm: 'raid_ultra_adventure', appear: ['%s sort de la brèche !', '%s emerged from the wormhole!'], flee: ['%s repart par la brèche…', '%s disappeared through the wormhole...'] },
    max: { name: ['Raid Dynamax', 'Max Raid'], den: ['Antre Dynamax', 'Max Raid Den'], adventure: ['Aventure Dynamax', 'Dynamax Adventure'], charset: 'raid_den_max', background: 'back_raid_max', bgm: ['raid_max_battle_1', 'raid_max_battle_2'], capture_bgm: 'raid_max_capture', adventure_bgm: 'raid_max_adventure', appear: ['%s Dynamax sort de l’antre !', 'A Dynamaxed %s emerged from within the den!'], flee: ['%s disparaît au fond de l’antre…', '%s disappeared somewhere into the den...'] },
    tera: { name: ['Raid Téracristal', 'Tera Raid'], den: ['Antre Téracristal', 'Tera Raid Den'], adventure: ['Aventure Téracristal', 'Terastal Adventure'], charset: 'raid_den_tera', background: 'back_raid_tera', bgm: ['raid_tera_battle_1', 'raid_tera_battle_2'], capture_bgm: 'raid_tera_capture', adventure_bgm: 'raid_tera_adventure', appear: ['%s Téracristallisé sort de l’antre !', 'A Terastallized %s emerged from within the den!'], flee: ['%s disparaît au fond de l’antre…', '%s disappeared somewhere into the den...'] },
  };
  const LANG_KEYS = ['name', 'den', 'adventure', 'appear', 'flee'];
  function bgmPicker(obj, key) {
    const list = (cur().ctx.bgms || []).map((s) => s.replace(/^audio\/bgm\//, ''));
    return h('span', { class: 'pjr-sound' },
      combo({ value: obj[key] || '', items: () => list.map((s) => ({ value: s, label: s })), allowEmpty: true, emptyLabel: '(aucune)', onPick: (v) => redo(() => { obj[key] = v; }) }),
      h('button', { class: 'pjs-btn small', title: 'Écouter', disabled: !obj[key], onclick: () => play('audio/bgm/' + obj[key]) }, '▶'));
  }
  const raidsPage = {
    title: 'Raids',
    normalize(c) {
      c.klass = 'RaidsConfig';
      c.settings = Object.assign(clone(RAID_DEFAULTS), isObj(c.settings) ? c.settings : {});
      c.styles = isObj(c.styles) ? c.styles : {};
      RAID_STYLES.forEach(([st]) => {
        const base = STYLE_BASE[st];
        const s = c.styles[st] = isObj(c.styles[st]) ? c.styles[st] : {};
        LANG_KEYS.forEach((k) => { if (!isObj(s[k])) s[k] = { fr: base[k][0], en: base[k][1] }; });
        ['charset', 'background', 'capture_bgm', 'adventure_bgm'].forEach((k) => { if (s[k] === undefined) s[k] = base[k]; });
        if (!Array.isArray(s.bgm)) s.bgm = base.bgm.slice();
        while (s.bgm.length < 2) s.bgm.push('');
        if (s.enabled === undefined) s.enabled = true;
      });
      c.species = Array.isArray(c.species) ? c.species : [];
      c.species.forEach((e) => { e.ranks = Array.isArray(e.ranks) ? e.ranks.map(int) : []; e.styles = Array.isArray(e.styles) ? e.styles : []; e.form = int(e.form); });
      c.rewards = Array.isArray(c.rewards) ? c.rewards : [];
      c.adventure = isObj(c.adventure) ? c.adventure : {};
      return c;
    },
    serialize(c) {
      c.species = c.species.filter((e) => e.pokemon);
      c.species.forEach((e) => { e.ranks = [...new Set(e.ranks)].sort((a, b) => a - b); if (!e.gmax) delete e.gmax; });
      c.rewards = c.rewards.filter((r) => r.item);
      Object.values(c.styles).forEach((s) => { s.bgm = s.bgm.filter(Boolean); });
      return c;
    },
    problems(S) {
      const out = [];
      if (!S.config.species.length) out.push('Aucun Pokémon de raid.');
      return out;
    },
    render(S) {
      const c = S.config;
      const ui = S.ui;
      const content = h('div', { class: 'pjr-content' });
      const row = h('div', { class: 'pjr-row' });
      content.appendChild(row);
      const left = h('div', { class: 'pjr-col narrow' });
      row.appendChild(left);
      const sets = h('div', { class: 'pjr-settings' });
      RAID_SETTINGS.forEach(([k, lab, kind, min, max]) => {
        if (kind === 'bool') sets.appendChild(check(c.settings, k, lab));
        else sets.appendChild(h('label', { class: 'pjr-setrow' }, h('span', null, lab), numInput(c.settings, k, { min, max, cls: 'tiny' })));
      });
      sets.appendChild(labeled('Appât (antre vide)', combo({ value: c.settings.bait_item || '', items: L.items, allowEmpty: true, emptyLabel: '(aucun)', onPick: (v) => redo(() => { c.settings.bait_item = v; }) })));
      left.appendChild(block('Réglages', null, sets,
        hint('Tours, K.O. et bouclier se calculent selon le rang (1 à 7) et la taille de l’équipe, comme dans le plugin d’origine. Le boss d’un rang plus haut a plus de PV, d’IV et d’actions.')));
      left.appendChild(block('Sur les cartes', null,
        hint('Un évènement dont le nom contient « antre_raid » (ou antre_raid_ultra, antre_raid_max, antre_raid_tera) prend l’apparence de l’antre. Sa page lance la commande antre_raid.')));
      left.appendChild(commands([
          ['antre_raid', 'antre (options : antre_raid(:max, pokemon: :charizard, rang: 5, taille: 3))'],
          ['combat_raid(:charizard, style: :max, rang: 5)', 'combat de raid direct (niveau:, tours:, ko:, bouclier:, capture: false, recompenses: true)'],
          ['raid_gagne?', 'condition : dernier raid gagné'],
          ['raid_capture?', 'condition : boss du dernier raid capturé'],
          ['aventure_raid(:max)', 'Aventure Raid (carte: n° ; sinon au choix)'],
          ['aventure_reussie?', 'condition : dernière aventure terminée'],
          ['remplir_antres', 'tous les antres retrouvent un Pokémon'],
          ['vider_antre(@event_id)', 'l’antre redevient vide'],
          ['raids_gagnes', 'nombre de raids gagnés (aussi antres_vaincus, aventures_terminees)'],
        ]));
      const right = h('div', { class: 'pjr-col wide' });
      row.appendChild(right);
      // --- styles
      ui.style = ui.style || 'basic';
      const tabs = h('span', { class: 'pjr-actions' }, RAID_STYLES.map(([st, lab]) => h('button', { class: 'pjs-btn small' + (ui.style === st ? ' primary' : ''), onclick: () => redo(() => { ui.style = st; }) }, lab)));
      const s = c.styles[ui.style];
      const bgs = (S.ctx.battlebacks || []).map((b) => [b, b]);
      if (s.background && !bgs.some(([b]) => b === s.background)) bgs.unshift([s.background, s.background + ' (introuvable)']);
      const chars = (S.ctx.charsets || []).map((b) => [b, b]);
      if (s.charset && !chars.some(([b]) => b === s.charset)) chars.unshift([s.charset, s.charset + ' (introuvable)']);
      right.appendChild(block('Styles de raid', tabs,
        ui.style !== 'basic' ? check(s, 'enabled', 'Style utilisable (sa mécanique doit être active dans le plugin Gimmicks)') : null,
        h('div', { class: 'pjr-grid2' },
          labeled('Nom', langInputs(s, 'name')), labeled('Nom de l’antre', langInputs(s, 'den'))),
        labeled('Nom de l’aventure', langInputs(s, 'adventure')),
        labeled('Le boss apparaît (%s : nom)', langInputs(s, 'appear')),
        labeled('Le boss s’en va (combat perdu)', langInputs(s, 'flee')),
        h('div', { class: 'pjr-grid2' },
          labeled('Charset de l’antre', select(s, 'charset', chars)),
          labeled('Fond de combat', select(s, 'background', bgs))),
        h('div', { class: 'pjr-grid2' },
          labeled('Musique de combat', bgmPicker(s.bgm, 0)), labeled('Musique (rang 6+, boss d’aventure)', bgmPicker(s.bgm, 1)),
          labeled('Musique de capture', bgmPicker(s, 'capture_bgm')), labeled('Musique de l’aventure', bgmPicker(s, 'adventure_bgm'))),
        pic(`graphics/battlebacks/${s.background}`, 'thumb')));
      // --- espèces
      const filterBox = h('div', { class: 'pjr-actions' });
      const search = h('input', { class: 'pjs-input pjr-short', placeholder: 'Rechercher…', value: ui.q || '' });
      search.addEventListener('input', () => { ui.q = search.value; ui.limit = 60; fillSpecies(); });
      const rankSel = h('select', { class: 'pjs-select', onchange: (e) => { ui.rank = e.target.value; ui.limit = 60; fillSpecies(); } },
        [['', 'Tous les rangs'], ...[1, 2, 3, 4, 5, 6].map((r) => [String(r), `Rang ${r}`])].map(([v, l]) => h('option', { value: v, selected: (ui.rank || '') === v }, l)));
      filterBox.append(search, rankSel, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.species.unshift({ pokemon: '', form: 0, ranks: [1], styles: [] }); ui.q = ''; ui.rank = ''; }) }, 'Ajouter'));
      const table = h('div', { class: 'pjr-table' });
      const more = h('div');
      const fillSpecies = () => {
        table.textContent = '';
        more.textContent = '';
        table.appendChild(h('div', { class: 'pjr-thead raidsp' }, h('span', null, 'Pokémon'), h('span', null, 'Forme'), h('span', null, 'Rangs'), h('span', null, 'Styles (aucun : tous)'), h('span', null, 'G-Max'), h('span')));
        const q = plain(ui.q || '');
        const list = c.species.map((e, i) => [e, i]).filter(([e]) => (!q || plain(e.pokemon + ' ' + nameOf('creatures', e.pokemon)).includes(q)) && (!ui.rank || e.ranks.includes(int(ui.rank))));
        const limit = ui.limit || 60;
        list.slice(0, limit).forEach(([e, i]) => {
          table.appendChild(h('div', { class: 'pjr-trow raidsp' },
            combo({ value: e.pokemon, items: L.creatures, placeholder: 'Pokémon…', onPick: (v) => redo(() => { e.pokemon = v; }) }),
            numInput(e, 'form', { min: 0, max: 99, cls: 'tiny' }),
            h('span', { class: 'pjr-checks' }, [1, 2, 3, 4, 5, 6].map((r) => h('label', { class: 'pjs-inline pjr-check', title: `Rang ${r}` },
              h('input', { type: 'checkbox', checked: e.ranks.includes(r), onchange: (ev) => soft(() => { e.ranks = ev.target.checked ? [...e.ranks, r] : e.ranks.filter((x) => x !== r); }) }), String(r)))),
            h('span', { class: 'pjr-checks' }, RAID_STYLES.map(([st, lab]) => h('label', { class: 'pjs-inline pjr-check', title: lab },
              h('input', { type: 'checkbox', checked: e.styles.includes(st), onchange: (ev) => soft(() => { e.styles = ev.target.checked ? [...e.styles, st] : e.styles.filter((x) => x !== st); }) }), lab.split(' ')[0].slice(0, 4)))),
            h('input', { type: 'checkbox', checked: !!e.gmax, title: 'Forme Gigamax (raids Dynamax seulement)', onchange: (ev) => soft(() => { e.gmax = ev.target.checked; }) }),
            h('button', { class: 'pjs-btn small danger', onclick: () => redo(() => { c.species.splice(i, 1); }) }, '✕')));
        });
        if (list.length > limit) more.appendChild(h('button', { class: 'pjs-btn small', onclick: () => { ui.limit = limit + 120; fillSpecies(); } }, `Afficher plus (${list.length - limit} de plus)`));
        more.appendChild(hint(`${list.length} sur ${c.species.length} Pokémon. Rang 1 : niveau 10 à 15 … rang 5 : 65 à 70, rang 6 : 75 à 80 (boss des aventures), rang 7 : niveau 100 (tous).`));
      };
      fillSpecies();
      right.appendChild(block(`Pokémon des raids (${c.species.length})`, filterBox, table, more));
      // --- récompenses en plus
      const rw = h('div', { class: 'pjr-table' });
      rw.appendChild(h('div', { class: 'pjr-thead raidrw' }, h('span', null, 'Objet'), h('span', null, 'Quantité'), h('span', null, 'Rang mini'), h('span', null, 'Chance %'), h('span', null, 'Style'), h('span')));
      c.rewards.forEach((r, i) => {
        if (r.min === undefined) r.min = 1;
        rw.appendChild(h('div', { class: 'pjr-trow raidrw' },
          combo({ value: r.item, items: L.items, placeholder: 'Objet…', onPick: (v) => redo(() => { r.item = v; }) }),
          h('span', { class: 'pjr-range' }, numInput(r, 'min', { min: 1, max: 99, cls: 'tiny' }), h('span', { class: 'pjs-hint inline' }, 'à'), numInput(r, 'max', { min: 1, max: 99, cls: 'tiny', optional: true })),
          numInput(r, 'rank', { min: 1, max: 7, cls: 'tiny', optional: true }), numInput(r, 'chance', { min: 1, max: 100, cls: 'tiny', optional: true }),
          select(r, 'style', [['', 'Tous'], ...RAID_STYLES]), rowButtons(c.rewards, i)));
      });
      right.appendChild(block(`Récompenses en plus (${c.rewards.length})`, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.rewards.push({ item: '', min: 1, max: 1, chance: 100 }); }) }, 'Ajouter'),
        rw, hint('S’ajoutent aux récompenses de base (Bonbons Exp., CT, plumes, vitamines, baies, menthes, Poké Balls…, plus nombreuses selon le rang).')));
      return content;
    },
  };

  // ===========================================================================
  // Level design > Mini-jeux > Cartes d'aventure (raids_cartes.json)
  // ===========================================================================
  const ADV_TILES = ['Pathway', 'Battle', 'StartPoint', 'Crossroad', 'TurnNorth', 'TurnSouth', 'TurnWest', 'TurnEast', 'RandomTurn', 'ReverseTurn',
    'Door', 'Key', 'Chest', 'Switch', 'Warp', 'Portal', 'Teleporter', 'Roadblock', 'HiddenTrap', 'Berries', 'Flare', 'Assistant', 'ItemVendor',
    'StatTrainer', 'MoveTutor', 'Nurse', 'Mystic', 'MysteryNPC', 'Researcher', 'PartnerA', 'PartnerB'];
  const ADV_NAMES = {
    Pathway: 'Chemin', Battle: 'Combat', StartPoint: 'Départ', Crossroad: 'Croisement', TurnNorth: 'Tourner haut', TurnSouth: 'Tourner bas', TurnWest: 'Tourner gauche',
    TurnEast: 'Tourner droite', RandomTurn: 'Virage au hasard', ReverseTurn: 'Demi-tour', Door: 'Porte (clé)', Key: 'Clé', Chest: 'Coffre (clé)', Switch: 'Interrupteur',
    Warp: 'Téléport (paire)', Portal: 'Portail (retour au départ)', Teleporter: 'Téléporteur (croisements)', Roadblock: 'Obstacle (type)', HiddenTrap: 'Piège caché',
    Berries: 'Baies (soin 50 %)', Flare: 'Torche (lumière)', Assistant: 'Assistant (échange)', ItemVendor: 'Marchand (objet tenu)', StatTrainer: 'Coach (EV)',
    MoveTutor: 'Maître des capacités', Nurse: 'Infirmière', Mystic: 'Mystique (cœurs)', MysteryNPC: 'Inconnu (PNJ au hasard)', Researcher: 'Chercheuse (style)',
    PartnerA: 'Partenaire (+1 cœur)', PartnerB: 'Partenaire 2 (+1 cœur)',
  };
  const CELL = 16;
  // grille de travail : 'x_y' => { id, toggle }
  function mapGrid(m) {
    if (m.__grid) return m.__grid;
    const g = {};
    (m.pathways || []).forEach(([x, y]) => { g[`${x}_${y}`] = { id: 'Pathway' }; });
    (m.battles || []).forEach(([x, y], i) => { g[`${x}_${y}`] = { id: 'Battle', order: i }; });
    (m.tiles || []).forEach((t) => { g[`${t.x}_${t.y}`] = Object.assign({ id: t.id }, t.toggle ? { toggle: true } : {}, t.warp ? { warp: t.warp } : {}); });
    m.__grid = g;
    return g;
  }
  function gridToMap(m) {
    const g = mapGrid(m);
    m.pathways = []; m.tiles = [];
    const battles = [];
    Object.entries(g).forEach(([k, t]) => {
      const [x, y] = k.split('_').map(int);
      if (t.id === 'Pathway') m.pathways.push([x, y]);
      else if (t.id === 'Battle') battles.push([t.order === undefined ? 999 : t.order, x, y]);
      else m.tiles.push(Object.assign({ id: t.id, x, y }, t.toggle ? { toggle: true } : {}, t.warp ? { warp: t.warp } : {}));
    });
    battles.sort((a, b) => a[0] - b[0]);
    m.battles = battles.map(([, x, y]) => [x, y]);
    m.pathways.sort((a, b) => a[1] - b[1] || a[0] - b[0]);
  }
  const imageCache2 = {};
  function loadImg(rel, cb) {
    if (imageCache2[rel]) { if (imageCache2[rel].complete) cb(imageCache2[rel]); else imageCache2[rel].addEventListener('load', () => cb(imageCache2[rel])); return; }
    image(rel).then((url) => { if (!url) return; const im = new Image(); im.src = url; imageCache2[rel] = im; im.addEventListener('load', () => cb(im)); });
  }
  const raidMapsPage = {
    title: 'Cartes d’aventure',
    normalize(c) {
      c.klass = 'RaidMapsConfig';
      c.maps = Array.isArray(c.maps) ? c.maps : [];
      c.maps.forEach((m) => { mapGrid(m); if (!isObj(m.name)) m.name = { fr: String(m.name || ''), en: String(m.name || '') }; if (!isObj(m.description)) m.description = { fr: String(m.description || ''), en: String(m.description || '') }; });
      return c;
    },
    serialize(c) {
      c.maps.forEach((m) => { gridToMap(m); delete m.__grid; });
      return c;
    },
    problems(S) {
      const out = [];
      S.config.maps.forEach((m) => {
        const g = mapGrid(m);
        const name = m.name.fr || m.id;
        if (!Object.values(g).some((t) => t.id === 'Battle')) out.push(`« ${name} » n’a pas de case Combat.`);
        if (!m.start || !g[`${m.start[0]}_${m.start[1]}`]) out.push(`« ${name} » : le départ n’est pas sur une case.`);
      });
      return out;
    },
    render(S) {
      const c = S.config;
      const ui = S.ui;
      if (ui.map === undefined || !c.maps[ui.map]) ui.map = 0;
      ui.tool = ui.tool || 'Pathway';
      const content = h('div', { class: 'pjr-content' });
      const row = h('div', { class: 'pjr-row' });
      content.appendChild(row);
      const left = h('div', { class: 'pjr-col narrow' });
      row.appendChild(left);
      const list = h('div', { class: 'pjr-list short' });
      c.maps.forEach((m, i) => list.appendChild(h('div', { class: 'pjr-list-item' + (ui.map === i ? ' active' : ''), onclick: () => redo(() => { ui.map = i; }) },
        h('span', { class: 'pjr-list-name' }, h('span', null, m.name.fr || `Carte ${m.id}`), h('span', { class: 'pjs-hint inline' }, `n° ${m.id} · ${m.width}×${m.height}`)))));
      left.appendChild(block(`Cartes (${c.maps.length})`, h('span', { class: 'pjr-actions' },
        h('button', { class: 'pjs-btn small', onclick: () => redo(() => {
          const id = c.maps.reduce((a, m) => Math.max(a, int(m.id)), -1) + 1;
          const m = { id, name: { fr: 'Nouvelle carte', en: 'New map' }, description: { fr: '', en: '' }, image: (S.ctx.mapImages || [])[0] || 'Cave', darkness: 10, width: 20, height: 15, start: [10, 14], pathways: [[10, 14]], battles: [], tiles: [] };
          mapGrid(m); c.maps.push(m); ui.map = c.maps.length - 1;
        }) }, 'Ajouter'),
        c.maps.length ? h('button', { class: 'pjs-btn small danger', onclick: () => { if (confirm('Supprimer cette carte ?')) redo(() => { c.maps.splice(ui.map, 1); ui.map = 0; }); } }, '✕') : null), list));
      const m = c.maps[ui.map];
      if (!m) { row.appendChild(h('div', { class: 'pjr-col wide' }, block('Carte', null, hint('Aucune carte : « Ajouter » en crée une.')))); return content; }
      const imgs = (S.ctx.mapImages || []).map((x) => [x, x]);
      left.appendChild(block('Réglages de la carte', null,
        labeled('Nom', langInputs(m, 'name')), labeled('Description', langInputs(m, 'description')),
        h('div', { class: 'pjr-grid2' }, labeled('Image (adventure/maps)', select(m, 'image', imgs, { onChange: () => {} })), labeled('Chance d’obscurité %', numInput(m, 'darkness', { min: 0, max: 100, cls: 'tiny' }))),
        h('div', { class: 'pjr-grid2' }, labeled('Largeur (cases)', numInput(m, 'width', { min: 4, max: 64, cls: 'tiny', onChange: () => {} })), labeled('Hauteur (cases)', numInput(m, 'height', { min: 4, max: 64, cls: 'tiny', onChange: () => {} }))),
        hint('Image : graphics/interface/raids/adventure/maps (32 px par case dans l’image, affichée à moitié en jeu). Les combats sont numérotés dans l’ordre où ils sont posés : le dernier est le boss.')));
      // palette
      const pal = h('div', { class: 'pjr-palette' });
      [['__erase', 'Effacer'], ['__start', 'Départ du joueur'], ['__boss', 'Mettre en boss'], ...ADV_TILES.map((t) => [t, ADV_NAMES[t] || t])].forEach(([id, lab]) => {
        const btn = h('button', { class: 'pjr-tool' + (ui.tool === id ? ' active' : ''), title: lab, onclick: () => redo(() => { ui.tool = id; }) },
          id.startsWith('__') ? h('span', { class: 'pjr-tool-x' }, { __erase: '✕', __start: '▶', __boss: '★' }[id]) : pic(`graphics/interface/raids/adventure/tiles/${id}`, 'small'), h('span', null, lab));
        pal.appendChild(btn);
      });
      left.appendChild(block('Cases', null, check(ui, 'toggle', 'Case cachée au départ (montrée par un Interrupteur)'), pal));
      // grille
      const right = h('div', { class: 'pjr-col wide' });
      row.appendChild(right);
      const W = int(m.width, 20), H = int(m.height, 15);
      const canvas = h('canvas', { class: 'pjr-mapcanvas', width: W * CELL, height: H * CELL });
      const g = mapGrid(m);
      const status = h('div', { class: 'pjs-hint' }, '');
      const draw = () => {
        const ctx = canvas.getContext('2d');
        ctx.imageSmoothingEnabled = false;
        ctx.fillStyle = '#111'; ctx.fillRect(0, 0, canvas.width, canvas.height);
        loadImg(`graphics/interface/raids/adventure/maps/${m.image}`, (im) => { ctx.globalAlpha = 0.85; ctx.drawImage(im, 0, 0, im.width / 2, im.height / 2); ctx.globalAlpha = 1; drawTiles(); });
        drawTiles();
      };
      const battleCount = () => Object.values(g).filter((t) => t.id === 'Battle').length;
      const drawTiles = () => {
        const ctx = canvas.getContext('2d');
        ctx.strokeStyle = 'rgba(255,255,255,0.08)';
        for (let x = 0; x <= W; x++) { ctx.beginPath(); ctx.moveTo(x * CELL + 0.5, 0); ctx.lineTo(x * CELL + 0.5, H * CELL); ctx.stroke(); }
        for (let y = 0; y <= H; y++) { ctx.beginPath(); ctx.moveTo(0, y * CELL + 0.5); ctx.lineTo(W * CELL, y * CELL + 0.5); ctx.stroke(); }
        const order = Object.values(g).filter((t) => t.id === 'Battle').sort((a, b) => (a.order ?? 999) - (b.order ?? 999));
        Object.entries(g).forEach(([k, t]) => {
          const [x, y] = k.split('_').map(int);
          if (x >= W || y >= H) return;
          loadImg(`graphics/interface/raids/adventure/tiles/${t.id}`, (im) => {
            ctx.globalAlpha = t.toggle ? 0.45 : 1;
            ctx.drawImage(im, x * CELL, y * CELL, CELL, CELL);
            ctx.globalAlpha = 1;
            if (t.id === 'Battle') {
              const n = order.indexOf(t);
              ctx.fillStyle = n === order.length - 1 ? '#ffd23f' : '#fff';
              ctx.font = 'bold 9px sans-serif';
              ctx.fillText(n === order.length - 1 ? '★' : String(n + 1), x * CELL + 1, y * CELL + 9);
            }
          });
        });
        if (m.start) { ctx.strokeStyle = '#4cff7a'; ctx.lineWidth = 2; ctx.strokeRect(m.start[0] * CELL + 1, m.start[1] * CELL + 1, CELL - 2, CELL - 2); ctx.lineWidth = 1; }
      };
      const cellAt = (ev) => { const r = canvas.getBoundingClientRect(); const sx = canvas.width / r.width; return [Math.floor((ev.clientX - r.left) * sx / CELL), Math.floor((ev.clientY - r.top) * sx / CELL)]; };
      let painting = false;
      const paint = (ev) => {
        const [x, y] = cellAt(ev);
        if (x < 0 || y < 0 || x >= W || y >= H) return;
        const k = `${x}_${y}`;
        const tool = ui.tool;
        if (tool === '__erase') delete g[k];
        else if (tool === '__start') { m.start = [x, y]; if (!g[k]) g[k] = { id: 'Pathway' }; }
        else if (tool === '__boss') { if (g[k] && g[k].id === 'Battle') g[k].order = 1000 + battleCount(); }
        else if (tool === 'Battle') { if (!g[k] || g[k].id !== 'Battle') g[k] = { id: 'Battle', order: 500 + battleCount() }; }
        else g[k] = Object.assign({ id: tool }, ui.toggle ? { toggle: true } : {});
        // ordre des combats : 0, 1, 2… (le boss reste dernier)
        Object.values(g).filter((t) => t.id === 'Battle').sort((a, b) => (a.order ?? 999) - (b.order ?? 999)).forEach((t, i) => { t.order = i; });
        soft();
        draw();
        status.textContent = `${Object.keys(g).length} cases, ${battleCount()} combats`;
      };
      canvas.addEventListener('mousedown', (ev) => { painting = !['__start', '__boss'].includes(ui.tool); paint(ev); });
      canvas.addEventListener('mousemove', (ev) => {
        const [x, y] = cellAt(ev);
        const t = g[`${x}_${y}`];
        status.textContent = `Case ${x}, ${y}${t ? ' : ' + (ADV_NAMES[t.id] || t.id) + (t.toggle ? ' (cachée)' : '') : ''}`;
        if (painting) paint(ev);
      });
      window.addEventListener('mouseup', () => { painting = false; }, { once: false });
      draw();
      right.appendChild(block(`${m.name.fr || 'Carte'} — ${W} × ${H}`, h('span', { class: 'pjs-hint inline' }, 'Clic : poser la case choisie (glisser pour peindre)'),
        h('div', { class: 'pjr-mapwrap' }, canvas), status,
        hint('Le joueur avance tout seul ; il choisit sa route aux croisements et quand plusieurs chemins s’offrent. Une case Combat lance un raid (rangs 3 à 5, le boss est de rang 6).')));
      return content;
    },
  };

  // ===========================================================================
  // Level design > Dresseurs > Tournois (tournois.json)
  // ===========================================================================
  const TOUR_TONES = [['default', 'Normale (orange)'], ['red', 'Rouge'], ['orange', 'Orange'], ['yellow', 'Jaune'], ['lime', 'Vert clair'],
    ['green', 'Vert'], ['cyan', 'Cyan'], ['blue', 'Bleu'], ['deep_blue', 'Bleu nuit'], ['purple', 'Violet'], ['magenta', 'Magenta'], ['grey', 'Gris']];
  const TOUR_RULES = { pick: 3, mode: 1, max_level: 0, items: 'hide', show_opponent: true, opponent_pick: 'random', bag: true, exp: false, heal: true, background: '', battle_bgm: '' };
  const TOUR_SIZE = (n) => { let s = 2; while (s < n) s *= 2; return Math.min(s, 16); };
  const TOUR_ROUNDS = { 2: 'finale', 4: 'demi-finales, finale', 8: 'quarts, demies, finale', 16: 'huitièmes, quarts, demies, finale' };
  const trainerOf = (db) => (cur().ctx.trainers || []).find((t) => t.db === db || String(t.id) === String(db));
  const trainerLabel = (t) => [t.klass, t.name].filter(Boolean).join(' ');
  const tournoisPage = {
    title: 'Tournois',
    normalize(c) {
      c.klass = 'TournoisConfig';
      c.settings = Object.assign({ bgm: 'tournoi_selection', bracket_bgm: 'tournoi_selection', tone: 'default', speed: 1 }, isObj(c.settings) ? c.settings : {});
      c.tournaments = Array.isArray(c.tournaments) ? c.tournaments : [];
      c.tournaments.forEach((t) => {
        if (!isObj(t.name)) t.name = { fr: String(t.name || ''), en: String(t.name || '') };
        t.participants = Array.isArray(t.participants) ? t.participants.map(String) : [];
        t.rules = Object.assign(clone(TOUR_RULES), isObj(t.rules) ? t.rules : {});
        t.rewards = Array.isArray(t.rewards) ? t.rewards : [];
        if (t.shuffle === undefined) t.shuffle = true;
        t.switch = int(t.switch); t.variable = int(t.variable);
      });
      return c;
    },
    serialize(c) {
      c.tournaments.forEach((t) => {
        t.id = String(t.id || '').trim();
        t.participants = t.participants.filter(Boolean);
        t.rewards = t.rewards.filter((r) => r.item || int(r.money) > 0).map((r) => ({ place: int(r.place, 1), item: r.item || '', count: Math.max(1, int(r.count, 1)), money: int(r.money) }));
      });
      return c;
    },
    problems(S) {
      const out = [];
      const ids = new Set();
      S.config.tournaments.forEach((t, i) => {
        const id = String(t.id || '').trim();
        const name = t.name.fr || id || `n° ${i + 1}`;
        if (!/^[a-z_][a-z0-9_]*$/.test(id)) out.push(`« ${name} » : l’identifiant doit être en minuscules, chiffres et _ (ex. coupe_debutant).`);
        if (ids.has(id)) out.push(`Identifiant « ${id} » utilisé deux fois.`);
        ids.add(id);
        if (!t.participants.filter(Boolean).length) out.push(`« ${name} » n’a aucun dresseur.`);
        if (t.participants.filter(Boolean).length > 15) out.push(`« ${name} » : 15 dresseurs au plus (16 places avec le joueur).`);
      });
      return out;
    },
    render(S) {
      const c = S.config;
      const ui = S.ui;
      if (ui.cup === undefined || !c.tournaments[ui.cup]) ui.cup = 0;
      const content = h('div', { class: 'pjr-content' });
      const row = h('div', { class: 'pjr-row' });
      content.appendChild(row);
      const left = h('div', { class: 'pjr-col narrow' });
      row.appendChild(left);
      // --- liste des tournois
      const list = h('div', { class: 'pjr-list short' });
      c.tournaments.forEach((t, i) => {
        const n = t.participants.filter(Boolean).length;
        list.appendChild(h('div', { class: 'pjr-list-item' + (ui.cup === i ? ' active' : ''), onclick: () => redo(() => { ui.cup = i; }) },
          h('span', { class: 'pjr-list-name' }, h('span', null, t.name.fr || t.id || 'Tournoi'), h('span', { class: 'pjs-hint inline' }, `${t.id} · ${n + 1} participants · ${t.rules.pick} Pokémon`))));
      });
      left.appendChild(block(`Tournois (${c.tournaments.length})`, h('span', { class: 'pjr-actions' },
        h('button', { class: 'pjs-btn small', onclick: () => redo(() => {
          let k = c.tournaments.length + 1;
          while (c.tournaments.some((t) => t.id === `tournoi_${k}`)) k++;
          c.tournaments.push({ id: `tournoi_${k}`, name: { fr: 'Nouveau tournoi', en: 'New tournament' }, participants: [], shuffle: true, rules: clone(TOUR_RULES), rewards: [], switch: 0, variable: 0 });
          ui.cup = c.tournaments.length - 1;
        }) }, 'Ajouter'),
        c.tournaments.length ? h('button', { class: 'pjs-btn small', title: 'Copier ce tournoi', onclick: () => redo(() => {
          const copy = clone(c.tournaments[ui.cup]); copy.id = copy.id + '_2'; c.tournaments.push(copy); ui.cup = c.tournaments.length - 1;
        }) }, 'Copier') : null,
        c.tournaments.length ? h('button', { class: 'pjs-btn small danger', onclick: () => { if (confirm('Supprimer ce tournoi ?')) redo(() => { c.tournaments.splice(ui.cup, 1); ui.cup = 0; }); } }, '✕') : null), list));
      // --- réglages communs
      const st = c.settings;
      left.appendChild(block('Écrans du tournoi', null,
        labeled('Musique de la sélection d’équipe', bgmPicker(st, 'bgm')),
        labeled('Musique du tableau', bgmPicker(st, 'bracket_bgm')),
        h('div', { class: 'pjr-grid2' },
          labeled('Teinte du fond', select(st, 'tone', TOUR_TONES)),
          labeled('Vitesse de l’animation', select(st, 'speed', [['0.5', 'Lente'], ['1', 'Normale'], ['2', 'Rapide']], { onChange: () => { st.speed = Number(st.speed); } }))),
        hint('Écran de sélection d’après « Tournament Selection » (Neiro) : fond animé, Balls de l’équipe choisie, équipe adverse à droite.')));
      const t = c.tournaments[ui.cup];
      const cmdId = t ? t.id : 'coupe_debutant';
      left.appendChild(commands([
        [`tournoi(:${cmdId})`, 'lance le tournoi (renvoie la place : 1 = vainqueur)'],
        [`tournoi_gagne?(:${cmdId})`, 'condition : dernier essai gagné'],
        [`tournoi_place(:${cmdId})`, 'place au dernier essai (0 : jamais joué)'],
        [`tournois_gagnes(:${cmdId})`, 'nombre de victoires (sans argument : tous les tournois)'],
        ['combat_selection(:trainer_3, nombre: 3)', 'un combat avec écran de sélection (double: true, niveau_max: 50, objets: :cacher…)'],
        ['combat_selection_gagne?', 'condition : ce combat a été gagné'],
        ['selection_equipe(:trainer_3, nombre: 3)', 'sélection seule : équipe réduite jusqu’à la fin du prochain combat'],
      ]));
      const right = h('div', { class: 'pjr-col wide' });
      row.appendChild(right);
      if (!t) { right.appendChild(block('Tournoi', null, hint('Aucun tournoi : « Ajouter » en crée un.'))); return content; }
      // --- identité
      right.appendChild(block('Tournoi', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Identifiant (commande tournoi(:…))', textInput(t, 'id', { placeholder: 'coupe_debutant', onChange: () => updateStatus() })),
          labeled('Nom', langInputs(t, 'name'))),
        h('div', { class: 'pjr-grid2' },
          labeled('Interrupteur activé si gagné (0 : aucun)', numInput(t, 'switch', { min: 0, max: 9999, cls: 'tiny' })),
          labeled('Variable : place du joueur (0 : aucune)', numInput(t, 'variable', { min: 0, max: 9999, cls: 'tiny' })))));
      // --- participants
      const n = t.participants.filter(Boolean).length;
      const size = TOUR_SIZE(n + 1);
      const parts = h('div', { class: 'pjr-table' });
      parts.appendChild(h('div', { class: 'pjr-thead tourp' }, h('span', null, 'Dresseur'), h('span', null, 'Équipe'), h('span')));
      t.participants.forEach((db, i) => {
        const tr = trainerOf(db);
        parts.appendChild(h('div', { class: 'pjr-trow tourp' },
          combo({ value: db, items: () => (S.ctx.trainers || []).map((x) => ({ value: x.db, label: trainerLabel(x) || x.db, sub: `${x.db} · ${x.size} Pokémon` })), placeholder: 'Dresseur…', onPick: (v) => redo(() => { t.participants[i] = v; }) }),
          h('span', { class: 'pjr-team' }, tr ? tr.species.map((sp, k) => {
            const cr = (S.ctx.creatures || []).find((x) => x.db === sp);
            return h('span', { class: 'pjr-teammon', title: `${cr ? cr.name : sp} N.${tr.levels[k]}` }, pic(`graphics/pokedex/pokeicon/${(cr && cr.icon) || '000'}`, 'small poke'), h('span', { class: 'pjs-hint inline' }, String(tr.levels[k])));
          }) : h('span', { class: 'pjs-hint inline' }, db ? 'dresseur introuvable' : ''), tr && tr.size === 0 ? h('span', { class: 'pjs-hint inline' }, 'équipe vide (ignoré)') : null),
          rowButtons(t.participants, i)));
      });
      right.appendChild(block(`Participants (${n} + le joueur)`, h('span', { class: 'pjr-actions' },
        check(t, 'shuffle', 'Tirage au sort', { tip: 'Sinon : ordre de la liste, le joueur en premier' }),
        h('button', { class: 'pjs-btn small', disabled: n >= 15, onclick: () => redo(() => { t.participants.push(''); }) }, 'Ajouter')),
        parts,
        hint(`Tableau de ${size} places (${TOUR_ROUNDS[size] || ''})${size - n - 1 > 0 ? ` : ${size - n - 1} place(s) vide(s), qualifié d’office` : ''}. Les matchs entre dresseurs se jouent tout seuls : le niveau de leurs meilleurs Pokémon compte.`)));
      // --- règles
      const r = t.rules;
      const bgs = [['', '(celui de la carte)'], ...(S.ctx.battlebacks || []).map((b) => [b, b])];
      if (r.background && !bgs.some(([b]) => b === r.background)) bgs.push([r.background, r.background + ' (introuvable)']);
      right.appendChild(block('Règles des combats', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Pokémon à choisir', numInput(r, 'pick', { min: 1, max: 6, cls: 'tiny' })),
          labeled('Combat', select(r, 'mode', [['1', 'Simple'], ['2', 'Double']], { onChange: () => { r.mode = int(r.mode, 1); } }))),
        h('div', { class: 'pjr-grid2' },
          labeled('Niveau maximum (0 : aucun)', numInput(r, 'max_level', { min: 0, max: 100, cls: 'tiny' }), 'Les Pokémon plus forts combattent à ce niveau (sans gagner d’expérience)'),
          labeled('Objets tenus de l’adversaire', select(r, 'items', [['show', 'Montrés'], ['hide', 'Cachés (« ? »)'], ['none', 'Pas affichés']]))),
        h('div', { class: 'pjr-grid2' },
          labeled('L’adversaire choisit', select(r, 'opponent_pick', [['random', 'Au hasard'], ['first', 'Ses premiers Pokémon'], ['strongest', 'Ses plus forts']])),
          labeled('Fond de combat', select(r, 'background', bgs))),
        labeled('Musique de combat (vide : celle du dresseur)', bgmPicker(r, 'battle_bgm')),
        h('div', { class: 'pjr-checks wrap' },
          check(r, 'show_opponent', 'Voir l’équipe adverse (Droite, résumé)'),
          check(r, 'bag', 'Objets du sac utilisables'),
          check(r, 'exp', 'Gain d’expérience'),
          check(r, 'heal', 'Soins avant chaque match et à la fin'))));
      // --- récompenses
      const rw = h('div', { class: 'pjr-table' });
      rw.appendChild(h('div', { class: 'pjr-thead tourrw' }, h('span', null, 'Place'), h('span', null, 'Objet'), h('span', null, 'Quantité'), h('span', null, 'Argent'), h('span')));
      t.rewards.forEach((rew, i) => {
        if (rew.place === undefined) rew.place = 1;
        if (rew.count === undefined) rew.count = 1;
        rw.appendChild(h('div', { class: 'pjr-trow tourrw' },
          select(rew, 'place', [['1', 'Vainqueur'], ['2', 'Finaliste ou mieux'], ['3', 'Demi-finaliste ou mieux'], ['5', 'Quart de finaliste ou mieux'], ['9', 'Tous']], { onChange: () => { rew.place = int(rew.place, 1); } }),
          combo({ value: rew.item || '', items: L.items, allowEmpty: true, emptyLabel: '(aucun objet)', onPick: (v) => redo(() => { rew.item = v; }) }),
          numInput(rew, 'count', { min: 1, max: 999, cls: 'tiny' }),
          numInput(rew, 'money', { min: 0, max: 9999999, cls: 'tiny', optional: true, placeholder: '0' }),
          rowButtons(t.rewards, i)));
      });
      right.appendChild(block(`Récompenses (${t.rewards.length})`, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { t.rewards.push({ place: 1, item: '', count: 1, money: 0 }); }) }, 'Ajouter'),
        rw, hint('Chaque ligne est donnée si le joueur finit à cette place ou mieux (vainqueur = 1, finaliste = 2, demi-finaliste = 3…).')));
      return content;
    },
  };

  // ===========================================================================
  // Données > Baies > Pokéblocs (pokeblocs.json)
  // ===========================================================================
  const PB_DEFAULTS = {
    mode: 'rse', sheen: true, max_blocks: 40, npc_random: false, bgm: '',
    npc_names: [['Alice', 'Alex', 'André'], ['Barry', 'Béatrice', 'Bob'], ['Carl', 'Chris', 'Caroline']],
    master_names: ['Devin', 'Drew', 'Diane'],
    master_berries: ['liechi_berry', 'ganlon_berry', 'salac_berry', 'petaya_berry', 'apicot_berry', 'lansat_berry', 'starf_berry', 'enigma_berry', 'micle_berry', 'custap_berry', 'jaboca_berry', 'rowap_berry', 'kee_berry', 'maranga_berry'],
  };
  const PB_COLORS = [['red', 'Rouge', '1 saveur : épicé'], ['blue', 'Bleu', '1 saveur : sec'], ['pink', 'Rose', '1 saveur : sucré'], ['green', 'Vert', '1 saveur : amer'], ['yellow', 'Jaune', '1 saveur : acide'],
    ['purple', 'Violet', '2 saveurs, épicé en tête'], ['indigo', 'Indigo', '2 saveurs, sec en tête'], ['brown', 'Marron', '2 saveurs, sucré en tête'], ['liteblue', 'Bleu clair', '2 saveurs, amer en tête'], ['olive', 'Kaki', '2 saveurs, acide en tête'],
    ['gold', 'Or', '1 ou 2 saveurs, plus de 50'], ['gray', 'Gris', '3 saveurs'], ['white', 'Blanc', '4 ou 5 saveurs'], ['black', 'Noir', 'raté : deux baies identiques'], ['rainbow', 'Arc-en-ciel', 'Kit : 4 baies de couleurs différentes']];
  const namesText = (list) => (Array.isArray(list) ? list : []).join(', ');
  const namesInput = (obj, key) => {
    const el = h('input', { class: 'pjs-input', value: namesText(obj[key]), placeholder: 'Noms séparés par des virgules' });
    el.addEventListener('input', () => soft(() => { obj[key] = el.value.split(',').map((s) => s.trim()).filter(Boolean); }));
    return el;
  };
  const pokeblocsPage = {
    title: 'Pokéblocs',
    normalize(c) {
      c.klass = 'PokeblocsConfig';
      c.settings = Object.assign(clone(PB_DEFAULTS), isObj(c.settings) ? c.settings : {});
      const st = c.settings;
      if (!Array.isArray(st.npc_names)) st.npc_names = clone(PB_DEFAULTS.npc_names);
      while (st.npc_names.length < 3) st.npc_names.push([]);
      st.npc_names = st.npc_names.slice(0, 3).map((l) => (Array.isArray(l) ? l : []));
      if (!Array.isArray(st.master_names)) st.master_names = [];
      if (!Array.isArray(st.master_berries)) st.master_berries = [];
      st.max_blocks = int(st.max_blocks, 40);
      return c;
    },
    serialize(c) { return c; },
    problems(S) {
      const st = S.config.settings;
      const out = [];
      const berries = new Set((S.ctx.items || []).filter((i) => i.berry && i.color).map((i) => i.db));
      st.master_berries.forEach((b) => { if (b && !berries.has(b)) out.push(`Baie du Maître Baies « ${b} » sans données de cuisine (Studio : Objets > Baie > Cuisine).`); });
      if (!(S.ctx.items || []).some((i) => i.db === 'pokeblock_case')) out.push('L’objet « pokeblock_case » (Boîte Pokébloc) n’existe pas dans Studio.');
      return out;
    },
    render(S) {
      const st = S.config.settings;
      const content = h('div', { class: 'pjr-content' });
      const row = h('div', { class: 'pjr-row' });
      content.appendChild(row);
      const left = h('div', { class: 'pjr-col narrow' });
      const right = h('div', { class: 'pjr-col wide' });
      row.append(left, right);
      left.appendChild(block('Mixeur à baies', null,
        labeled('Mode', select(st, 'mode', [['rse', 'Rubis / Saphir / Émeraude (mini-jeu)'], ['oras', 'Rubis Oméga / Saphir Alpha (simple)']], { onChange: () => {} })),
        st.mode === 'rse' ? check(st, 'sheen', 'Lustre : un Pokémon ne mange plus quand il atteint 255') : hint('Mode simple : chaque condition s’arrête à 255 (1275 au total), l’effet baisse quand elles sont déjà hautes.'),
        h('div', { class: 'pjr-grid2' },
          labeled('Pokéblocs dans la Boîte (0 : sans limite)', numInput(st, 'max_blocks', { min: 0, max: 999, cls: 'tiny' })),
          labeled('Musique du mixeur', bgmPicker(st, 'bgm'))),
        hint('Les saveurs, la douceur, la couleur et la chance de Pokébloc + viennent des données de cuisine des baies (Studio : Objets).')));
      left.appendChild(commands([
        ['mixeur_baies', 'mixeur à jouer, seul (renvoie le nombre de Pokéblocs)'],
        ['mixeur_baies(3)', 'avec 1 à 3 autres joueurs (noms: [\'Léa\', \'Tom\'] pour les nommer)'],
        ['mixeur_maitre', 'avec le Maître Baies'],
        ['mixeur_simple', 'mixeur du Kit Pokébloc (1 à 4 baies)'],
        ['mixeur', 'celui du mode réglé ici'],
        ['boite_pokeblocs', 'ouvre la Boîte Pokébloc'],
        ['etat_pokemon', 'conditions de concours de l’équipe'],
        ['donner_pokebloc(:red, 2, plus: true)', 'donne des Pokéblocs'],
        ['pokeblocs_nombre(:red)', 'nombre de Pokéblocs (d’une couleur)'],
      ]));
      right.appendChild(block('Autres joueurs du mixeur', check(st, 'npc_random', 'Baies au hasard', { onChange: () => {} }),
        ...st.npc_names.map((list, i) => labeled(`Joueur ${i + 2}`, namesInput(st.npc_names, i))),
        labeled('Maître Baies', namesInput(st, 'master_names')),
        hint(st.npc_random ? 'Les autres joueurs prennent une baie au hasard ; le Maître Baies une de la liste ci-dessous.' : 'Les autres joueurs choisissent la baie qui complète la vôtre (tables de Rubis / Saphir / Émeraude).')));
      if (st.npc_random) {
        const chips = h('div', { class: 'pjr-chips' }, st.master_berries.map((b, i) => h('span', { class: 'pjr-chip' }, pic(itemIcon(b), 'small'), nameOf('items', b),
          h('button', { class: 'pjr-chip-x', onclick: () => redo(() => { st.master_berries.splice(i, 1); }) }, '✕'))),
        combo({ value: '', items: L.berries, placeholder: 'Ajouter une baie…', cls: 'add', onPick: (v) => redo(() => { if (!st.master_berries.includes(v)) st.master_berries.push(v); }) }));
        right.appendChild(block('Baies du Maître Baies', null, chips));
      }
      right.appendChild(block('Couleurs des Pokéblocs', null, h('div', { class: 'pjr-table' },
        PB_COLORS.map(([id, name, how]) => h('div', { class: 'pjr-trow pbcol' }, pic(`graphics/interface/pokeblocs/blocs/${id}`, 'small'), h('span', null, `Pokébloc ${name}`), h('span', { class: 'pjs-hint inline' }, how))))));
      return content;
    },
  };

  // ===========================================================================
  // Level design > Mini-jeux > Concours (concours.json)
  // ===========================================================================
  const CO_TYPES = [['cool', 'Sang-froid', 'Cool'], ['beauty', 'Beauté', 'Beauty'], ['cute', 'Grâce', 'Cute'], ['smart', 'Intelligence', 'Smart'], ['tough', 'Robustesse', 'Tough']];
  const CO_RANKS = [['normal', 'Normal', 'Normal'], ['great', 'Méga', 'Great'], ['ultra', 'Ultra', 'Ultra'], ['master', 'Master', 'Master']];
  const CO_DEFAULTS = { hall_bgm: 'concours_hall', judging_bgm: 'concours_jugement', results_bgm: 'concours_resultats', winner_bgm: 'concours_gagnant', win_bgm: 'concours_victoire',
    mc_name: 'Dexter', mc_charset: 'chef_orchestre', pass_item: '', dressup_time: 60, max_accessories: [5, 10, 15, 20], win_switch: 0, result_variable: 0,
    minigames: true, dressup_bgm: 'concours_habillage', dance_bgm: 'concours_danse', acting_bgm: 'concours_acteur', animations: true, winner_photo: true, dance_animations: { jump: '', front: '', left: '', right: '' },
    judges: [{ name: 'Jordan', charset: 'npc_ace-trainer-m-01' }, { name: '', charset: '' }, { name: 'Keira', charset: 'npc_lady' }],
    dance: { timing: [[10, 70, 80], [35, 50, 85], [60, 30, 90], [80, 15, 95]], lead: [[20, 10, 20], [40, 30, 40], [60, 60, 60], [80, 80, 80]] },
    acting_avoid: [90, 50, 20, 0] };
  const CO_EFFECTS = [['basic', 'Prestation de base'], ['plus_2_if_first', '+2 si premier'], ['plus_2_if_last', '+2 si dernier'],
    ['prevent_voltage_up_same_turn', 'Ambiance bloquée (ne monte plus)'], ['prevent_voltage_down_same_turn', 'Ambiance protégée (ne baisse plus)'],
    ['can_perform_move_twice_in_a_row', 'Peut être reprise au tour suivant'], ['plus_3_if_previous_pokemon_hit_max_voltage', '+3 après une ambiance au max'],
    ['double_score_next_turn', 'Double les points du tour suivant'], ['raise_score_if_voltage_low', 'Plus de points si ambiance basse'],
    ['increased_voltage_added_to_score', 'Ambiance ajoutée aux points'], ['next_1', 'Premier au tour suivant'], ['next_4', 'Dernier au tour suivant'],
    ['double_score_if_final_turn', 'Double les points s’il passe en dernier'], ['plus_3_if_2_voltage_in_a_row', '+3 si l’ambiance monte deux fois de suite'],
    ['plus_2_if_voltage_up', '+2 si l’ambiance monte'], ['steal_voltage_previous_pokemon', 'Reprend le bonus d’ambiance du précédent'],
    ['plus_3_if_get_lowest_score', '+3 s’il a le moins de points'], ['lower_voltage_of_all_judges_1', 'Baisse l’ambiance de tous les juges'],
    ['higher_score_the_later_performs', 'Plus de points s’il passe tard'], ['plus_3_if_no_pokemon_chose_judge', '+3 s’il est seul avec son juge'],
    ['plus_15_if_all_chose_same_judge', '+15 si tous choisissent le même juge'], ['random_order', 'Ordre du tour suivant au hasard'],
    ['points_equal_to_order', 'Points selon l’ordre de passage']];
  const CO_RIBBONS = [];
  CO_TYPES.forEach(([t]) => { ['normal', 'super', 'hyper', 'master'].forEach((r) => CO_RIBBONS.push(`${t}_${r}_hoenn`)); ['normal', 'great', 'ultra', 'master'].forEach((r) => CO_RIBBONS.push(`${t}_${r}_sinnoh`)); });
  const CO_TABS = [['contestants', 'Concurrents'], ['ribbons', 'Rubans'], ['accessories', 'Accessoires'], ['backdrops', 'Fonds'], ['themes', 'Thèmes'], ['starter', 'Mallette de départ'], ['rewards', 'Récompenses'], ['dance', 'Danse'], ['acting', 'Jeu d’acteur']];
  const charsetItems = () => (cur().ctx.npcCharsets || []).map((n) => ({ value: n, label: n, icon: `graphics/characters/${n}`, iconCls: 'chara' }));
  const concoursPage = {
    title: 'Concours',
    normalize(c) {
      c.klass = 'ConcoursConfig';
      c.settings = Object.assign(clone(CO_DEFAULTS), isObj(c.settings) ? c.settings : {});
      if (!Array.isArray(c.settings.max_accessories)) c.settings.max_accessories = [5, 10, 15, 20];
      const st = c.settings;
      st.minigames = st.minigames !== false;
      st.judges = [0, 1, 2].map((i) => { const j = Array.isArray(st.judges) && isObj(st.judges[i]) ? st.judges[i] : {}; return { name: String(j.name || ''), charset: String(j.charset || '') }; });
      if (!isObj(st.dance)) st.dance = {};
      ['timing', 'lead'].forEach((k) => {
        const old = Array.isArray(st.dance[k]) ? st.dance[k] : [];
        st.dance[k] = CO_DEFAULTS.dance[k].map((row, i) => row.map((v, j) => (Array.isArray(old[i]) && old[i][j] !== undefined ? int(old[i][j]) : v)));
      });
      st.animations = st.animations !== false;
      st.winner_photo = st.winner_photo !== false;
      if (!isObj(st.dance_animations)) st.dance_animations = {};
      ['jump', 'front', 'left', 'right'].forEach((k) => { st.dance_animations[k] = String(st.dance_animations[k] || ''); });
      st.acting_avoid = CO_DEFAULTS.acting_avoid.map((v, i) => (Array.isArray(st.acting_avoid) && st.acting_avoid[i] !== undefined ? int(st.acting_avoid[i]) : v));
      c.moves = isObj(c.moves) ? c.moves : {};
      c.types = CO_TYPES.map(([id, fr, en]) => {
        const old = (Array.isArray(c.types) ? c.types : []).find((t) => t && t.id === id) || {};
        return { id, name: isObj(old.name) ? old.name : { fr, en } };
      });
      c.ranks = CO_RANKS.map(([id, fr, en]) => {
        const old = (Array.isArray(c.ranks) ? c.ranks : []).find((r) => r && r.id === id) || {};
        const contestants = Array.isArray(old.contestants) ? old.contestants : [];
        contestants.forEach((x) => { if (!Array.isArray(x.moves)) x.moves = []; });
        return { id, name: isObj(old.name) ? old.name : { fr, en }, switch: int(old.switch), contestants };
      });
      c.ribbons = isObj(c.ribbons) ? c.ribbons : {};
      CO_TYPES.forEach(([t]) => {
        const list = Array.isArray(c.ribbons[t]) ? c.ribbons[t] : [];
        c.ribbons[t] = CO_RANKS.map(([r], i) => list[i] || `${t}_${r}_sinnoh`);
      });
      ['themes', 'categories', 'accessories', 'backdrops', 'rewards'].forEach((k) => { if (!Array.isArray(c[k])) c[k] = []; });
      c.accessories.forEach((a) => {
        if (!isObj(a.name)) a.name = { fr: String(a.name || a.id || ''), en: String(a.name || a.id || '') };
        a.points = Array.isArray(a.points) ? a.points.map((n) => int(n)) : [];
        while (a.points.length < c.themes.length) a.points.push(0);
      });
      c.backdrops.forEach((b) => { if (!isObj(b.name)) b.name = { fr: String(b.name || b.id || ''), en: String(b.name || b.id || '') }; });
      c.starter = isObj(c.starter) ? c.starter : {};
      if (!isObj(c.starter.accessories)) c.starter.accessories = {};
      if (!Array.isArray(c.starter.backdrops)) c.starter.backdrops = [];
      return c;
    },
    serialize(c) {
      c.rewards = c.rewards.filter((r) => r.item || int(r.money) > 0 || r.accessory || r.backdrop || r.pokeblock || r.triad_card || r.outfit)
        .map((r) => ({ rank: r.rank || '', item: r.item || '', count: Math.max(1, int(r.count, 1)), money: int(r.money), accessory: r.accessory || '', backdrop: r.backdrop || '', pokeblock: r.pokeblock || '', triad_card: r.triad_card || '', outfit: r.outfit || '' }));
      c.ranks.forEach((r) => { r.contestants = r.contestants.filter((x) => x.species); r.contestants.forEach((x) => { x.moves = (x.moves || []).filter(Boolean).slice(0, 4); }); });
      Object.keys(c.moves).forEach((k) => { const m = c.moves[k]; c.moves[k] = [String(m[0] || 'cool'), Math.max(0, Math.min(3, int(m[1]))), String(m[2] || 'basic')]; });
      return c;
    },
    problems(S) {
      const c = S.config;
      const out = [];
      const species = new Set((S.ctx.creatures || []).map((x) => x.db));
      c.ranks.forEach((r) => {
        const n = r.contestants.filter((x) => x.species).length;
        if (n < 3) out.push(`Rang ${r.name.fr} : il faut au moins 3 concurrents (${n} pour l’instant).`);
        r.contestants.forEach((x) => { if (x.species && !species.has(x.species)) out.push(`Rang ${r.name.fr} : Pokémon « ${x.species} » introuvable.`); });
      });
      const ids = new Set();
      c.accessories.forEach((a) => { if (ids.has(a.id)) out.push(`Accessoire « ${a.id} » en double.`); ids.add(a.id); if (!/^[a-z0-9_]+$/.test(a.id || '')) out.push(`Accessoire « ${a.id} » : identifiant en minuscules, chiffres et _.`); });
      return out;
    },
    render(S) {
      const c = S.config;
      const ui = S.ui;
      ui.tab = ui.tab || 'contestants';
      ui.rank = ui.rank || 'normal';
      const st = c.settings;
      const content = h('div', { class: 'pjr-content' });
      const row = h('div', { class: 'pjr-row' });
      content.appendChild(row);
      const left = h('div', { class: 'pjr-col narrow' });
      const right = h('div', { class: 'pjr-col wide' });
      row.append(left, right);
      left.appendChild(block('Concours', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Présentateur', textInput(st, 'mc_name')),
          labeled('Apparence', combo({ value: st.mc_charset, items: charsetItems, onPick: (v) => redo(() => { st.mc_charset = v; }) }))),
        labeled('Objet exigé à l’accueil', combo({ value: st.pass_item || '', items: L.items, allowEmpty: true, emptyLabel: '(aucun)', onPick: (v) => redo(() => { st.pass_item = v; }) }), 'Par exemple le Passe Concours (contest_pass)'),
        h('div', { class: 'pjr-grid2' },
          labeled('Interrupteur : dernier concours gagné (0 : aucun)', numInput(st, 'win_switch', { min: 0, max: 9999, cls: 'tiny' })),
          labeled('Variable : place du joueur (0 : aucune)', numInput(st, 'result_variable', { min: 0, max: 9999, cls: 'tiny' })))));
      left.appendChild(block('Musiques', null,
        labeled('Salle des concours (scène)', bgmPicker(st, 'hall_bgm')),
        labeled('Épreuves', bgmPicker(st, 'judging_bgm')),
        labeled('Résultats', bgmPicker(st, 'results_bgm')),
        labeled('Annonce du gagnant', bgmPicker(st, 'winner_bgm')),
        labeled('Remise du ruban', bgmPicker(st, 'win_bgm')),
        labeled('Habillage', bgmPicker(st, 'dressup_bgm')),
        labeled('Danse', bgmPicker(st, 'dance_bgm')),
        labeled('Jeu d’acteur', bgmPicker(st, 'acting_bgm')),
        hint('Danse et jeu d’acteur : concours_danse / concours_acteur (si le fichier manque, la musique de jugement est jouée).'),
        check(st, 'winner_photo', 'Photo du gagnant rangée dans l’appli Appareil photo (et visible dans le tableau des gagnants)')));
      left.appendChild(block('Habillage', null,
        h('div', { class: 'pjr-grid2' }, ...CO_RANKS.map(([id, fr], i) => labeled(`Accessoires max (${fr})`, numInput(st.max_accessories, i, { min: 1, max: 40, cls: 'tiny' })))),
        labeled('Temps de l’habillage (secondes)', numInput(st, 'dressup_time', { min: 10, max: 300, cls: 'tiny' })),
        check(st, 'minigames', 'Jouer les épreuves (habillage, danse, jeu d’acteur)'),
        hint('Décoché : l’habillage prend les meilleurs accessoires de la Mallette pour le thème ; la danse et le jeu d’acteur sont simulés.')));
      left.appendChild(block('Noms', null,
        ...c.types.map((t) => labeled(`Concours ${t.id}`, langInputs(t, 'name'))),
        ...c.ranks.map((r) => h('div', { class: 'pjr-grid2' }, labeled(`Rang ${r.id}`, langInputs(r, 'name')), labeled('Ouvert par l’interrupteur (0 : toujours)', numInput(r, 'switch', { min: 0, max: 9999, cls: 'tiny' }))))));
      left.appendChild(commands([
        ['concours', 'accueil complet puis le concours (renvoie la place, 0 : abandon)'],
        ['concours(:cool, :master)', 'type (et rang) imposés'],
        ['concours_direct(:cute, :great)', 'sans les messages d’accueil'],
        ['concours_gagne?', 'condition : dernier concours gagné'],
        ['concours_place', 'place au dernier concours'],
        ['concours_victoires(:cool, :normal)', 'nombre de victoires (sans argument : toutes)'],
        ['mallette', 'ouvre la Mallette'],
        ['mallette_depart', 'Mallette de départ (une seule fois)'],
        ['donner_accessoire(:top_hat, 2)', 'donne un accessoire (silencieux: true sans message)'],
        ['donner_fond(:sky)', 'donne un fond'],
        ['accessoire_nombre(:top_hat)', 'exemplaires dans la Mallette'],
        ['tableau_gagnants', 'tableau des gagnants'],
        ['dernier_gagnant', 'message : dernier gagnant'],
      ]));
      right.appendChild(h('div', { class: 'pjr-actions pjr-tabs' }, CO_TABS.map(([id, lab]) => h('button', { class: 'pjs-btn small' + (ui.tab === id ? ' primary' : ''), onclick: () => redo(() => { ui.tab = id; }) }, lab))));
      const tabs = { contestants: coContestants, ribbons: coRibbons, accessories: coAccessories, backdrops: coBackdrops, themes: coThemes, starter: coStarter, rewards: coRewards, dance: coDance, acting: coActing };
      right.appendChild(tabs[ui.tab](S));
      return content;
    },
  };
  function coContestants(S) {
    const c = S.config;
    const ui = S.ui;
    const rank = c.ranks.find((r) => r.id === ui.rank) || c.ranks[0];
    const head = h('span', { class: 'pjr-actions' }, c.ranks.map((r) => h('button', { class: 'pjs-btn small' + (r.id === rank.id ? ' primary' : ''), onclick: () => redo(() => { ui.rank = r.id; }) }, r.name.fr || r.id)),
      h('button', { class: 'pjs-btn small', onclick: () => redo(() => { rank.contestants.push({ trainer: 'Nouveau', charset: 'NPC_awakening_1', species: 'pikachu', nickname: '', gender: 1, form: 0, shiny: false, dressup: 5, condition: 10, picture: '', moves: [] }); }) }, 'Ajouter'));
    const table = h('div', { class: 'pjr-table' });
    table.appendChild(h('div', { class: 'pjr-thead concp' }, ...['Dresseur', 'Apparence', 'Pokémon', 'Surnom', 'Sexe', 'Forme', 'Habillage', 'Condition', ''].map((t) => h('span', null, t))));
    rank.contestants.forEach((x, i) => {
      if (!Array.isArray(x.moves)) x.moves = [];
      const moves = h('div', { class: 'pjr-trow comoves' }, h('span', { class: 'pjs-hint inline' }, 'Capacités (jeu d’acteur) :'),
        ...x.moves.map((m, k) => h('span', { class: 'pjr-chip' }, nameOf('moves', m), h('button', { class: 'pjs-btn small danger', onclick: () => redo(() => { x.moves.splice(k, 1); }) }, '✕'))),
        x.moves.length < 4 ? combo({ value: '', items: L.moves, placeholder: x.moves.length ? '+ capacité' : 'auto (ce que le Pokémon apprend) — + capacité', cls: 'add', onPick: (v) => redo(() => { x.moves.push(v); }) }) : null);
      table.appendChild(h('div', { class: 'pjr-trow concp' },
        textInput(x, 'trainer'),
        combo({ value: x.charset || '', items: charsetItems, onPick: (v) => redo(() => { x.charset = v; }) }),
        combo({ value: x.species || '', items: L.creatures, onPick: (v) => redo(() => { x.species = v; }) }),
        textInput(x, 'nickname', { placeholder: 'nom de l’espèce' }),
        select(x, 'gender', [['1', 'Mâle'], ['2', 'Femelle'], ['0', 'Aucun']], { onChange: () => { x.gender = int(x.gender); } }),
        h('span', { class: 'pjr-nowrap' }, numInput(x, 'form', { min: 0, max: 99, cls: 'tiny' }), check(x, 'shiny', '✦', { tip: 'Chromatique' })),
        numInput(x, 'dressup', { min: 0, max: 999, cls: 'tiny' }),
        numInput(x, 'condition', { min: 0, max: 9999, cls: 'tiny' }),
        rowButtons(rank.contestants, i)));
      table.appendChild(moves);
    });
    return block(`Concurrents (${rank.name.fr})`, head, table,
      hint('3 concurrents sont tirés au sort parmi la liste du rang (le joueur est l’entrée n° 4). Points de condition du joueur : condition principale + secondaires ÷ 2 + Lustre ÷ 2 (jusqu’à ~630). Repères du plugin d’origine : Normal 8–19, Méga 114–150, Ultra 270–320, Master 540–600.'));
  }
  function coDance(S) {
    const st = S.config.settings;
    const table = h('div', { class: 'pjr-table' });
    table.appendChild(h('div', { class: 'pjr-thead codance' }, ...['Rang', 'Excellent %', 'Bien %', 'Bon pas %', 'Pas rapprochés %', 'Début / fin %', 'Pas différents %'].map((t) => h('span', null, t))));
    CO_RANKS.forEach(([id, fr], i) => table.appendChild(h('div', { class: 'pjr-trow codance' }, h('span', null, fr),
      ...[0, 1, 2].map((k) => numInput(st.dance.timing[i], k, { min: 0, max: 100, cls: 'tiny' })),
      ...[0, 1, 2].map((k) => numInput(st.dance.lead[i], k, { min: 0, max: 100, cls: 'tiny' })))));
    const steps = h('div', { class: 'pjr-grid2' }, ...[['jump', 'Saut (haut)'], ['front', 'Devant (bas)'], ['left', 'Gauche'], ['right', 'Droite']].map(([k, lab]) =>
      labeled(`Animation du pas « ${lab} »`, combo({ value: st.dance_animations[k] || '', items: L.moves, allowEmpty: true, emptyLabel: '(aucune)', onPick: (v) => redo(() => { st.dance_animations[k] = v; }) }))));
    return block('Épreuve de danse', null, check(st, 'animations', 'Jouer les animations de capacités de Studio (danse et jeu d’acteur)'), steps,
      hint('Les animations viennent de l’éditeur d’animations de Studio (Données > Attaques > Animations) : celle de la capacité choisie est jouée sur le danseur à chaque pas. Au jeu d’acteur, c’est l’animation de la capacité présentée.'),
      table,
      hint('Chacun mène la danse pendant 2 morceaux de 8 secondes ; les autres refont ses pas sur la seconde moitié. Excellent : +2, bien : +1. Concurrents : chances de pas excellent, bien (sinon raté) et dans la bonne direction. Danseur principal (concurrent) : chances de pas rapprochés, de commencer au début ou finir à la fin, et de changer de pas.'));
  }
  function coActing(S) {
    const c = S.config;
    const st = c.settings;
    const ui = S.ui;
    const judges = h('div', { class: 'pjr-table' });
    judges.appendChild(h('div', { class: 'pjr-thead cojudge' }, ...['Juge', 'Nom', 'Apparence'].map((t) => h('span', null, t))));
    st.judges.forEach((j, i) => judges.appendChild(h('div', { class: 'pjr-trow cojudge' }, h('span', null, i === 1 ? 'Principal (milieu)' : (i === 0 ? 'Gauche' : 'Droite')),
      textInput(j, 'name', { placeholder: i === 1 ? `présentateur (${st.mc_name})` : '' }),
      combo({ value: j.charset, items: charsetItems, allowEmpty: true, emptyLabel: i === 1 ? '(celle du présentateur)' : '(aucune)', onPick: (v) => redo(() => { j.charset = v; }) }))));
    const avoid = h('div', { class: 'pjr-grid2' }, ...CO_RANKS.map(([id, fr], i) => labeled(`Évite le juge du joueur (${fr}) %`, numInput(st.acting_avoid, i, { min: 0, max: 100, cls: 'tiny' }))));
    ui.mq = ui.mq || '';
    ui.mt = ui.mt || '';
    const q = plain(ui.mq);
    const keys = Object.keys(c.moves).filter((k) => (!ui.mt || c.moves[k][0] === ui.mt) && (!q || plain(k + ' ' + nameOf('moves', k)).includes(q))).sort((a, b) => String(nameOf('moves', a)).localeCompare(String(nameOf('moves', b))));
    const shown = keys.slice(0, 80);
    const table = h('div', { class: 'pjr-table' });
    table.appendChild(h('div', { class: 'pjr-thead comove' }, ...['Capacité', 'Type', 'Cœurs', 'Effet', ''].map((t) => h('span', null, t))));
    shown.forEach((k) => {
      const m = c.moves[k];
      table.appendChild(h('div', { class: 'pjr-trow comove' }, h('span', { title: k }, nameOf('moves', k)),
        select(m, 0, CO_TYPES.map(([id, fr]) => [id, fr]), { cls: 'small' }),
        select(m, 1, [['0', '0'], ['1', '1'], ['2', '2'], ['3', '3']], { onChange: () => { m[1] = int(m[1]); }, cls: 'tiny' }),
        select(m, 2, CO_EFFECTS),
        h('button', { class: 'pjs-btn small danger', onclick: () => redo(() => { delete c.moves[k]; }) }, '✕')));
    });
    const search = textInput(ui, 'mq', { placeholder: 'Rechercher une capacité…' });
    search.addEventListener('change', () => render());
    const head = h('span', { class: 'pjr-actions' }, search, select(ui, 'mt', [['', 'Tous les types'], ...CO_TYPES.map(([id, fr]) => [id, fr])], { onChange: () => {} }),
      combo({ value: '', items: () => L.moves().filter((x) => !c.moves[x.value]), placeholder: '+ Ajouter', cls: 'add', onPick: (v) => redo(() => { c.moves[v] = ['cool', 1, 'basic']; ui.mq = v; }) }));
    return h('div', null,
      block('Juges', null, judges, avoid, hint('Le juge du milieu est le juge principal : ambiance au maximum, +8 (les autres +5). Nom et apparence vides : ceux du présentateur.')),
      block(`Capacités (${keys.length}${keys.length > shown.length ? `, ${shown.length} affichées` : ''} / ${Object.keys(c.moves).length})`, head, table,
        hint('Type de concours, cœurs d’attrait (0 à 3) et effet de chaque capacité (d’après le plugin d’origine). Une capacité absente prend sa condition et son attrait de Studio, avec l’effet de base.')));
  }
  function coRibbons(S) {
    const c = S.config;
    const grid = h('div', { class: 'pjr-table' });
    grid.appendChild(h('div', { class: 'pjr-thead coribbon' }, h('span'), ...c.ranks.map((r) => h('span', null, r.name.fr))));
    c.types.forEach((t) => grid.appendChild(h('div', { class: 'pjr-trow coribbon' }, h('span', null, t.name.fr),
      ...c.ranks.map((r, i) => select(c.ribbons[t.id], i, CO_RIBBONS.map((x) => [x, x]))))));
    return block('Rubans gagnés', null, grid, hint('Rubans de PSDK (sinnoh : Super Concours de Diamant et Perle ; hoenn : Concours de Rubis et Saphir). Le nom affiché vient des textes de Studio.'));
  }
  function coAccessories(S) {
    const c = S.config;
    const ui = S.ui;
    const cats = c.categories.map((x) => [x.id, (x.name && x.name.fr) || x.id]);
    ui.cat = ui.cat || (cats[0] && cats[0][0]) || '';
    const list = c.accessories.filter((a) => a.category === ui.cat);
    const table = h('div', { class: 'pjr-table' });
    table.appendChild(h('div', { class: 'pjr-thead coacc' }, h('span'), h('span', null, 'Identifiant / image / catégorie'), h('span', null, 'Nom (fr / en)'),
      ...c.themes.map((t) => h('span', { title: (t.name && t.name.fr) || t.id }, ((t.name && t.name.fr) || t.id).slice(0, 4))), h('span')));
    list.forEach((a) => {
      const i = c.accessories.indexOf(a);
      table.appendChild(h('div', { class: 'pjr-trow coacc' },
        pic(`graphics/interface/concours/accessoires/${a.file || a.id}`, 'acc'),
        h('span', { class: 'pjr-stack' }, textInput(a, 'id'), textInput(a, 'file', { placeholder: 'image (accessoires/…)' }), select(a, 'category', cats, { onChange: () => {} })),
        h('span', { class: 'pjr-stack' }, textInput(a.name, 'fr', { placeholder: 'fr' }), textInput(a.name, 'en', { placeholder: 'en' })),
        ...c.themes.map((t, k) => select(a.points, k, [['0', '0'], ['1', '1'], ['2', '2'], ['3', '3']], { onChange: () => { a.points[k] = int(a.points[k]); }, cls: 'tiny' })),
        rowButtons(c.accessories, i)));
    });
    const head = h('span', { class: 'pjr-actions' }, select(ui, 'cat', cats, { onChange: () => {} }),
      h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.accessories.push({ id: 'nouvel_accessoire', file: '', category: ui.cat, name: { fr: 'Nouvel accessoire', en: 'New accessory' }, points: c.themes.map(() => 1) }); }) }, 'Ajouter'));
    return block(`Accessoires (${c.accessories.length})`, head, table,
      hint('Points par thème : 0 (rien), 1 (bas), 2 (moyen), 3 (haut). Images : graphics/interface/concours/accessoires/<image>.png.'));
  }
  function coBackdrops(S) {
    const c = S.config;
    const table = h('div', { class: 'pjr-table' });
    c.backdrops.forEach((b, i) => table.appendChild(h('div', { class: 'pjr-trow cobd' },
      pic(`graphics/interface/concours/fonds/carte_${b.file || b.id}`, 'card'), h('span', { class: 'pjr-stack' }, textInput(b, 'id'), textInput(b, 'file')), langInputs(b, 'name'), rowButtons(c.backdrops, i))));
    return block(`Fonds (${c.backdrops.length})`, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.backdrops.push({ id: 'nouveau_fond', file: '', name: { fr: 'Nouveau fond', en: 'New backdrop' } }); }) }, 'Ajouter'),
      table, hint('Images : graphics/interface/concours/fonds/<image>.png (112x128) et carte_<image>.png (26x36).'));
  }
  function coThemes(S) {
    const c = S.config;
    return block(`Thèmes de l’habillage (${c.themes.length})`, null, ...c.themes.map((t) => labeled(t.id, langInputs(t, 'name'))),
      ...c.categories.map((x) => labeled(`Catégorie ${x.id}`, langInputs(x, 'name'))));
  }
  function coStarter(S) {
    const c = S.config;
    const acc = c.starter.accessories;
    const accItems = () => c.accessories.map((a) => ({ value: a.id, label: (a.name && a.name.fr) || a.id, sub: a.id, icon: `graphics/interface/concours/accessoires/${a.file || a.id}` }));
    const rows = h('div', { class: 'pjr-table' }, Object.keys(acc).map((id) => h('div', { class: 'pjr-trow costart' },
      pic(`graphics/interface/concours/accessoires/${(c.accessories.find((a) => a.id === id) || {}).file || id}`, 'small'), h('span', null, ((c.accessories.find((a) => a.id === id) || {}).name || {}).fr || id),
      numInput(acc, id, { min: 1, max: 99, cls: 'tiny' }), h('button', { class: 'pjs-btn small danger', onclick: () => redo(() => { delete acc[id]; }) }, '✕'))));
    const bds = h('div', { class: 'pjr-checks wrap' }, c.backdrops.map((b) => h('label', { class: 'pjs-inline pjr-check' },
      h('input', { type: 'checkbox', checked: c.starter.backdrops.includes(b.id), onchange: (e) => soft(() => { const l = c.starter.backdrops; if (e.target.checked) { if (!l.includes(b.id)) l.push(b.id); } else l.splice(l.indexOf(b.id), 1); }) }), b.name.fr || b.id)));
    return block('Mallette de départ', null, rows,
      combo({ value: '', items: accItems, placeholder: 'Ajouter un accessoire…', cls: 'add', onPick: (v) => redo(() => { acc[v] = (acc[v] || 0) + 1; }) }),
      h('h3', { class: 'pjr-sub' }, 'Fonds'), bds, hint('Donnée par la commande mallette_depart (une seule fois par partie).'));
  }
  function coRewards(S) {
    const c = S.config;
    const accItems = () => c.accessories.map((a) => ({ value: a.id, label: (a.name && a.name.fr) || a.id, sub: a.id }));
    const table = h('div', { class: 'pjr-table' });
    table.appendChild(h('div', { class: 'pjr-thead corw' }, ...['Rang', 'Objet', 'Quantité', 'Argent', 'Accessoire', 'Fond', 'Pokébloc rare', 'Carte Triad', 'Tenue', ''].map((t) => h('span', null, t))));
    c.rewards.forEach((r, i) => {
      if (r.count === undefined) r.count = 1;
      table.appendChild(h('div', { class: 'pjr-trow corw' },
        select(r, 'rank', [['', 'Tous'], ...c.ranks.map((x) => [x.id, x.name.fr])]),
        combo({ value: r.item || '', items: L.items, allowEmpty: true, emptyLabel: '(aucun)', onPick: (v) => redo(() => { r.item = v; }) }),
        numInput(r, 'count', { min: 1, max: 999, cls: 'tiny' }),
        numInput(r, 'money', { min: 0, max: 9999999, cls: 'tiny', optional: true, placeholder: '0' }),
        combo({ value: r.accessory || '', items: accItems, allowEmpty: true, emptyLabel: '(aucun)', onPick: (v) => redo(() => { r.accessory = v; }) }),
        select(r, 'backdrop', [['', '(aucun)'], ...c.backdrops.map((b) => [b.id, b.name.fr])]),
        select(r, 'pokeblock', [['', '(aucun)'], ['rainbow', 'Arc-en-ciel'], ['red', 'Rouge'], ['blue', 'Bleu'], ['pink', 'Rose'], ['green', 'Vert'], ['yellow', 'Jaune']]),
        textInput(r, 'triad_card', { placeholder: 'ex. mew' }),
        textInput(r, 'outfit', { placeholder: 'objet de la tenue' }),
        rowButtons(c.rewards, i)));
    });
    return block(`Récompenses de victoire (${c.rewards.length})`, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.rewards.push({ rank: '', item: '', count: 1, money: 0, accessory: '', backdrop: '', pokeblock: '', triad_card: '', outfit: '' }); }) }, 'Ajouter'),
      table, hint('Données au joueur quand il gagne un concours de ce rang (en plus du ruban). Pokébloc rare, carte Triple Triad (espèce) et tenue (objet de la Garde-robe) : pour le rang Master par exemple.'));
  }

  // ===========================================================================
  // Données > Gimmicks > Pokémon Obscurs (obscurs.json)
  // ===========================================================================
  const OB_DEFAULTS = { mode: 'both', gauge: 4000, fury_chance: [0, 0, 4, 6, 8, 10], hyper_disobey: 40, reverse_damage: 8, reverse_gauge: 50,
    battle_gauge: 100, call_gauge: 300, walk_gauge: 1, daycare_gauge: 2, chamber_gauge: 2,
    scents: { joy_scent: 500, excite_scent: 1000, vivid_scent: 2000 }, shadow_vs_normal: 2.0, shadow_vs_shadow: 0.5, shadow_vs_purified: 0.5, purified_loyalty: true, purified_exp_percent: 120,
    shadow_sky_turns: 5, shadow_sky_boost: 1.5, default_moves: ['shadow_rush'], snag_machine: 'snag_machine', snag_ball: 'snag_ball',
    ribbon: 'national', purify_me: '', aura: true, team_gauge: true, team_aura: true, mark: true, mark_icon: 'rang_obscur', purified_mark_icon: 'rang_purifie', mark_zoom: 75, mark_x: 2, mark_y: 0 };
  const OB_MODES = [['both', 'Les deux (Hyper + Inversion)'], ['hyper', 'Mode Hyper (XD)'], ['reverse', 'Mode Inversion (Colosseum)']];
  const shadowMoves = () => (cur().ctx.moves || []).filter((m) => m.type === 'shadow').map((m) => ({ value: m.db, label: m.name, sub: m.db }));
  function obMoves(list) {
    return h('span', { class: 'pjr-chips' },
      ...list.map((m, k) => h('span', { class: 'pjr-chip' }, nameOf('moves', m), h('button', { class: 'pjs-btn small danger', onclick: () => redo(() => { list.splice(k, 1); }) }, '✕'))),
      list.length < 4 ? combo({ value: '', items: () => shadowMoves().filter((x) => !list.includes(x.value)), placeholder: '+ capacité Obscure', cls: 'add', onPick: (v) => redo(() => { list.push(v); }) }) : null);
  }
  function mePicker(obj, key) {
    const list = (cur().ctx.mes || []).map((s) => s.replace(/^audio\/me\//, ''));
    return h('span', { class: 'pjr-sound' },
      combo({ value: obj[key] || '', items: () => list.map((s) => ({ value: s, label: s })), allowEmpty: true, emptyLabel: '(aucune)', onPick: (v) => redo(() => { obj[key] = v; }) }),
      h('button', { class: 'pjs-btn small', title: 'Écouter', disabled: !obj[key], onclick: () => play('audio/me/' + obj[key]) }, '▶'));
  }
  const obscursPage = {
    title: 'Pokémon Obscurs',
    normalize(c) {
      c.klass = 'ObscursConfig';
      c.settings = Object.assign(clone(OB_DEFAULTS), isObj(c.settings) ? c.settings : {});
      const st = c.settings;
      st.fury_chance = OB_DEFAULTS.fury_chance.map((v, i) => (Array.isArray(st.fury_chance) && st.fury_chance[i] !== undefined ? int(st.fury_chance[i]) : v));
      st.scents = Object.assign(clone(OB_DEFAULTS.scents), isObj(st.scents) ? st.scents : {});
      if (!Array.isArray(st.default_moves)) st.default_moves = ['shadow_rush'];
      st.aura = st.aura !== false;
      st.mark = st.mark !== false;
      st.team_gauge = st.team_gauge !== false;
      st.team_aura = st.team_aura !== false;
      st.purified_loyalty = st.purified_loyalty !== false;
      c.designs = (Array.isArray(c.designs) ? c.designs : []).filter(isObj).map((d) => ({ species: String(d.species || ''), form: d.form === undefined || d.form === null || d.form === '' ? -1 : int(d.form, -1), front: String(d.front || ''), back: String(d.back || ''), icon: String(d.icon || '') }));
      c.trainers = Array.isArray(c.trainers) ? c.trainers : [];
      c.trainers.forEach((e) => { if (!Array.isArray(e.moves)) e.moves = []; e.slot = int(e.slot); e.gauge = int(e.gauge, 4000); });
      return c;
    },
    serialize(c) {
      c.trainers = c.trainers.filter((e) => e.trainer).map((e) => ({ id: String(e.id || ''), trainer: e.trainer, slot: int(e.slot), gauge: Math.max(100, int(e.gauge, 4000)), moves: (e.moves || []).slice(0, 4) }));
      ['shadow_vs_normal', 'shadow_vs_shadow', 'shadow_vs_purified', 'shadow_sky_boost'].forEach((k) => { c.settings[k] = Number(c.settings[k]) || OB_DEFAULTS[k]; });
      c.settings.purified_exp_percent = Math.min(1000, Math.max(0, int(c.settings.purified_exp_percent, 120)));
      c.settings.mark_icon = String(c.settings.mark_icon || '').trim();
      c.settings.purified_mark_icon = String(c.settings.purified_mark_icon || '').trim();
      ['mark_x', 'mark_y'].forEach((k) => { c.settings[k] = int(c.settings[k], 0); });
      c.settings.mark_zoom = Math.min(400, Math.max(10, int(c.settings.mark_zoom, 75)));
      c.designs = c.designs.filter((d) => d.species).map((d) => ({ species: d.species, form: int(d.form, -1), front: d.front.trim(), back: d.back.trim(), icon: d.icon.trim() }));
      return c;
    },
    problems(S) {
      const out = [];
      const ids = new Set();
      S.config.trainers.forEach((e, i) => {
        const t = trainerOf(e.trainer);
        if (!t) out.push(`Ligne ${i + 1} : dresseur « ${e.trainer} » introuvable.`);
        else if (e.slot >= t.size) out.push(`Ligne ${i + 1} : le dresseur ${trainerLabel(t)} n’a que ${t.size} Pokémon.`);
        const id = e.id || `${e.trainer}_${e.slot}`;
        if (ids.has(id)) out.push(`Identifiant en double : ${id}`);
        ids.add(id);
      });
      const known = new Set((S.ctx.creatures || []).map((x) => x.db));
      const seen = new Set();
      S.config.designs.forEach((d, i) => {
        if (d.species && !known.has(d.species)) out.push(`Design ${i + 1} : Pokémon « ${d.species} » introuvable.`);
        const key = `${d.species}/${d.form}`;
        if (d.species && seen.has(key)) out.push(`Design en double : ${d.species} (forme ${d.form < 0 ? 'toutes' : d.form}).`);
        seen.add(key);
      });
      return out;
    },
    renderDesigns(S) {
      const c = S.config;
      const wrap = h('div');
      const table = h('div', { class: 'pjr-table' });
      table.appendChild(h('div', { class: 'pjr-thead obdes' }, ...['Pokémon', 'Forme', 'Face', 'Dos', 'Icône', ''].map((t) => h('span', null, t))));
      c.designs.forEach((d, i) => {
        table.appendChild(h('div', { class: 'pjr-trow obdes' },
          combo({ value: d.species || '', items: L.creatures, placeholder: 'Pokémon…', onPick: (v) => redo(() => { d.species = v; }) }),
          numInput(d, 'form', { min: -1, max: 99, cls: 'tiny' }),
          textInput(d, 'front', { placeholder: 'auto : <nom>_shadow' }),
          textInput(d, 'back', { placeholder: 'auto' }),
          textInput(d, 'icon', { placeholder: 'auto' }),
          rowButtons(c.designs, i)));
      });
      wrap.appendChild(block(`Designs des Pokémon Obscurs (${c.designs.length})`,
        h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.designs.push({ species: '', form: -1, front: '', back: '', icon: '' }); }) }, 'Ajouter'),
        c.designs.length ? table : h('div', { class: 'pjr-empty' }, 'Aucun design réglé : seules les images nommées « <sprite>_shadow » sont utilisées.'),
        hint('Un Pokémon Obscur peut avoir ses propres images (Mewtwo Obscur, ses Méga-évolutions…). Forme -1 : toutes les formes. Face et dos sont dans graphics/pokedex/pokefront et pokeback, l’icône dans pokeicon : écris le nom du fichier sans « .png ». Une case vide suit la règle automatique.')));
      wrap.appendChild(block('Règle automatique', null,
        h('div', { class: 'pjr-summary' }, 'Sans rien régler ici, une image nommée comme le sprite normal suivi de _shadow est utilisée, au même endroit.'),
        commands([
          ['pokefront/0150_shadow.png', 'face de Mewtwo Obscur (dos : pokeback/0150_shadow.png, icône : pokeicon/0150_shadow.png)'],
          ['pokefront/0150_1_shadow.png', 'face de la forme 1 de Mewtwo, par exemple Méga-Mewtwo X (selon la numérotation des formes de Studio)'],
        ]),
        hint('Une fois purifié, le Pokémon retrouve ses images normales. Un chromatique Obscur utilise le même design. Un design sans dos garde le dos normal.')));
      return wrap;
    },
    render(S) {
      const c = S.config;
      const st = c.settings;
      const content = h('div', { class: 'pjr-content' });
      S.ui.ob = S.ui.ob || { tab: 'main' };
      const ob = S.ui.ob;
      content.appendChild(h('div', { class: 'pjr-actions pjr-tabs' }, [['main', 'Réglages'], ['designs', `Designs (${c.designs.length})`]].map(([id, lab]) =>
        h('button', { class: 'pjs-btn small' + (ob.tab === id ? ' primary' : ''), onclick: () => redo(() => { ob.tab = id; }) }, lab))));
      if (ob.tab === 'designs') { content.appendChild(this.renderDesigns(S)); return content; }
      const row = h('div', { class: 'pjr-row' });
      content.appendChild(row);
      const left = h('div', { class: 'pjr-col narrow' });
      const right = h('div', { class: 'pjr-col wide' });
      row.append(left, right);
      left.appendChild(block('Furie', null,
        labeled('Comportement', select(st, 'mode', OB_MODES)),
        h('div', { class: 'pjr-grid3' }, ...[0, 1, 2, 3, 4, 5].map((i) => labeled(`${i} barre${i > 1 ? 's' : ''} : %`, numInput(st.fury_chance, i, { min: 0, max: 100, cls: 'tiny' })))),
        h('div', { class: 'pjr-grid2' },
          labeled('Mode Hyper : désobéit (%)', numInput(st, 'hyper_disobey', { min: 0, max: 100, cls: 'tiny' })),
          labeled('Mode Inversion : perte de PV (1 / n)', numInput(st, 'reverse_damage', { min: 2, max: 64, cls: 'tiny' })),
          labeled('Mode Inversion : la jauge remonte de', numInput(st, 'reverse_gauge', { min: 0, max: 9999, cls: 'tiny' }))),
        check(st, 'aura', 'Aura violette en combat (rouge en furie)'),
        hint('Chance d’entrer en furie à chaque fin de tour selon les barres de la jauge cœur (Pokémon du joueur). L’Appel (à la place de Fuite) l’apaise.')));
      left.appendChild(block('Jauge cœur', null,
        labeled('Taille par défaut', numInput(st, 'gauge', { min: 100, max: 99999, cls: 'tiny' })),
        h('div', { class: 'pjr-grid2' },
          labeled('Combat livré', numInput(st, 'battle_gauge', { min: 0, max: 9999, cls: 'tiny' })),
          labeled('Appel (fin de la furie)', numInput(st, 'call_gauge', { min: 0, max: 9999, cls: 'tiny' })),
          labeled('Par pas dans l’équipe', numInput(st, 'walk_gauge', { min: 0, max: 999, cls: 'tiny' })),
          labeled('Par pas à la Pension', numInput(st, 'daycare_gauge', { min: 0, max: 999, cls: 'tiny' })),
          labeled('Par pas en Chambre (× tempo)', numInput(st, 'chamber_gauge', { min: 0, max: 999, cls: 'tiny' })),
          labeled('Parfum Doux', numInput(st.scents, 'joy_scent', { min: 0, max: 99999, cls: 'tiny' })),
          labeled('Parfum Excitant', numInput(st.scents, 'excite_scent', { min: 0, max: 99999, cls: 'tiny' })),
          labeled('Parfum Vivifiant', numInput(st.scents, 'vivid_scent', { min: 0, max: 99999, cls: 'tiny' }))),
        hint('Valeurs retirées de la jauge. 5 barres ; vide : purification possible (Pierre Relique ou Chambre de purification).')));
      left.appendChild(block('Capacités Obscures', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Contre un Pokémon normal ×', numInput(st, 'shadow_vs_normal', { min: 0, max: 8, step: 0.1, cls: 'tiny' })),
          labeled('Contre un Pokémon Obscur ×', numInput(st, 'shadow_vs_shadow', { min: 0, max: 8, step: 0.1, cls: 'tiny' })),
          labeled('Contre un Pokémon purifié ×', numInput(st, 'shadow_vs_purified', { min: 0, max: 8, step: 0.1, cls: 'tiny' })),
          labeled('Ciel Obscur : tours', numInput(st, 'shadow_sky_turns', { min: 1, max: 20, cls: 'tiny' })),
          labeled('Ciel Obscur : puissance ×', numInput(st, 'shadow_sky_boost', { min: 1, max: 4, step: 0.1, cls: 'tiny' }))),
        labeled('Capacités par défaut', obMoves(st.default_moves))));
      left.appendChild(block('Capture et purification', null,
        labeled('Snatcheur (objet clé)', combo({ value: st.snag_machine || '', items: L.items, allowEmpty: true, emptyLabel: '(aucun)', onPick: (v) => redo(() => { st.snag_machine = v; }) })),
        labeled('Snatch Ball', combo({ value: st.snag_ball || '', items: L.items, allowEmpty: true, emptyLabel: '(aucune)', onPick: (v) => redo(() => { st.snag_ball = v; }) })),
        labeled('Ruban de purification', textInput(st, 'ribbon', { placeholder: 'national' })),
        check(st, 'purified_loyalty', 'Un Pokémon purifié a le bonheur au maximum'),
        labeled('Expérience gagnée par un Pokémon purifié (%)', numInput(st, 'purified_exp_percent', { min: 0, max: 1000, cls: 'tiny' }), '120 : un cinquième de plus ; 100 : normale'),
        labeled('Musique de la purification', mePicker(st, 'purify_me')),
        hint('Avec le Snatcheur dans le sac, toutes les Balls capturent les Pokémon Obscurs des dresseurs ; la Snatch Ball le fait sans Snatcheur.')));
      left.appendChild(block('Marque Obscure', null,
        check(st, 'team_gauge', 'Écran d’équipe : jauge cœur en 5 barres sous la barre de PV'),
        check(st, 'team_aura', 'Écran d’équipe : aura violette autour de la carte d’un Pokémon Obscur'),
        check(st, 'mark', 'Afficher la marque à côté de la barre de vie en combat et dans le résumé (Obscur et purifié)'),
        h('div', { class: 'pjr-grid2' },
          labeled('Image : Pokémon Obscur', textInput(st, 'mark_icon', { placeholder: 'rang_obscur' }), 'graphics/interface : 16 px'),
          labeled('Image : Pokémon purifié', textInput(st, 'purified_mark_icon', { placeholder: 'rang_purifie' }), 'vide : aucune marque une fois purifié')),
        h('div', { class: 'pjr-grid3' },
          labeled('Décalage horizontal', numInput(st, 'mark_x', { min: -200, max: 400, cls: 'tiny' }), 'px'),
          labeled('Décalage vertical', numInput(st, 'mark_y', { min: -200, max: 400, cls: 'tiny' }), 'px'),
          labeled('Taille', numInput(st, 'mark_zoom', { min: 10, max: 400, cls: 'tiny' }), '%')),
        hint('Même emplacement que la marque des Barons : à droite de la barre de vie ; si le Pokémon a aussi une marque Baron ou Dominant, celle-ci passe à côté.')));
      left.appendChild(commands([
        ['pokemon_obscur(:houndour, 30)', 'crée un Pokémon Obscur (id:, gauge:, moves:)'],
        ['ajouter_pokemon_obscur(:houndour, 30)', 'donne un Pokémon Obscur'],
        ['combat_obscur(:houndour, 30)', 'combat contre un Pokémon Obscur sauvage'],
        ['pierre_relique', 'Pierre Relique : purifie un Pokémon à la jauge vide'],
        ['chambre_purification', 'ouvre la Chambre de purification'],
        ['obscur?(0)', 'condition : Pokémon n° 1 de l’équipe Obscur'],
        ['jauge_coeur(0)', 'barres de la jauge du Pokémon n° 1 (0 à 5)'],
        ['statut_obscur(\'id\')', 'seen, missed, snagged, purified ou nil'],
        ['obscurs_captures', 'nombre capturés'],
        ['obscurs_purifies', 'nombre purifiés'],
      ]));
      const table = h('div', { class: 'pjr-table' });
      table.appendChild(h('div', { class: 'pjr-thead obtr' }, ...['Dresseur', 'Pokémon', 'Jauge', 'Capacités Obscures', 'Identifiant', ''].map((t) => h('span', null, t))));
      c.trainers.forEach((e, i) => {
        const t = trainerOf(e.trainer);
        const slots = t ? t.species.map((sp, k) => [String(k), `${k + 1} · ${nameOf('creatures', sp)} (n. ${t.levels[k] || '?'})`]) : [['0', '1']];
        table.appendChild(h('div', { class: 'pjr-trow obtr' },
          combo({ value: e.trainer || '', items: () => (S.ctx.trainers || []).map((x) => ({ value: x.db, label: trainerLabel(x) || x.db, sub: `${x.db} · ${x.size} Pokémon` })), placeholder: 'Dresseur…', onPick: (v) => redo(() => { e.trainer = v; e.slot = 0; }) }),
          select(e, 'slot', slots, { onChange: () => { e.slot = int(e.slot); } }),
          numInput(e, 'gauge', { min: 100, max: 99999, cls: 'tiny' }),
          obMoves(e.moves),
          textInput(e, 'id', { placeholder: e.trainer ? `${e.trainer}_${e.slot}` : 'auto' }),
          rowButtons(c.trainers, i)));
      });
      right.appendChild(block(`Pokémon Obscurs des dresseurs (${c.trainers.length})`,
        h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.trainers.push({ id: '', trainer: '', slot: 0, gauge: int(st.gauge, 4000), moves: [] }); }) }, 'Ajouter'),
        table,
        hint('Au début du combat, ce Pokémon du dresseur devient Obscur (sauf s’il a déjà été capturé ou purifié). Sans capacité : celles par défaut. L’identifiant suit le Pokémon (registre, commande statut_obscur).')));
      return content;
    },
  };

  // ===========================================================================
  // Données > Personnages > Montures (montures.json)
  // ===========================================================================
  const MT_DEFAULTS = { key: 'R', hold_frames: 18, prefer_mount: true, ask_on_contact: true, hm_animation: false, cry_on_call: true,
    outdoor_only: true, block_switch: 0, auto_switch: true, ride_bgm: '', item: '' };
  const MT_MOUNT = { id: '', name: '', name_en: '', species: '', form: 0, shiny: false, level: 50, powers: [], speed: 4, gallop: true,
    water_only: false, encounters: 100, start: false, bgm: '' };
  const MT_POWERS = [['surf', 'Surf'], ['waterfall', 'Cascade'], ['whirlpool', 'Siphon'], ['dive', 'Plongée'], ['strength', 'Force'],
    ['rock_smash', 'Éclate-Roc'], ['cut', 'Coupe'], ['rock_climb', 'Escalade'], ['headbutt', 'Coup d’Boule'], ['flash', 'Flash'],
    ['fly', 'Vol'], ['search', 'Flair']];
  const MT_KEYS = [['R', 'R (touche G)'], ['L', 'L (touche F)'], ['Y', 'Y'], ['X', 'X'], ['L2', 'L2'], ['R2', 'R2'], ['SELECT', 'SELECT']];
  const MT_SPEEDS = [['3', '3 · marche'], ['4', '4 · course'], ['5', '5 · vélo'], ['6', '6 · très rapide']];
  const mtPowerName = (p) => (MT_POWERS.find((x) => x[0] === p) || [p, p])[1];
  const MT_POWER_ORDER = MT_POWERS.map((x) => x[0]);
  // icône d'un pouvoir (graphics/interface/montures/pouvoirs.png : 12 icônes de 14 × 14)
  function mtIcon(power, size = 18) {
    const el = pic('graphics/interface/montures/pouvoirs', 'mtpow');
    const i = MT_POWER_ORDER.indexOf(power);
    Object.assign(el.style, { width: size + 'px', height: size + 'px', backgroundSize: `${size * 12}px ${size}px`, backgroundPosition: `${-i * size}px 0` });
    el.title = mtPowerName(power);
    return el;
  }
  const mtSpecies = (m) => (cur().ctx.creatures || []).find((x) => x.db === m.species);
  const mtLabel = (m) => { const cr = mtSpecies(m); return m.name || (cr ? cr.name : m.species || 'Nouvelle monture'); };
  const mtTerrain = (m) => (m.powers.includes('surf') ? (m.water_only ? 'eau' : 'terre et eau') : 'terre');
  const monturesPage = {
    title: 'Montures',
    normalize(c) {
      c.klass = 'MonturesConfig';
      c.settings = Object.assign(clone(MT_DEFAULTS), isObj(c.settings) ? c.settings : {});
      ['prefer_mount', 'ask_on_contact', 'cry_on_call', 'outdoor_only', 'auto_switch'].forEach((k) => { c.settings[k] = c.settings[k] !== false; });
      c.settings.hm_animation = c.settings.hm_animation === true;
      c.mounts = (Array.isArray(c.mounts) ? c.mounts : []).filter(isObj).map((m) => {
        const e = Object.assign(clone(MT_MOUNT), m);
        e.powers = Array.isArray(e.powers) ? e.powers.filter((p) => MT_POWERS.some((x) => x[0] === p)) : [];
        ['form', 'level', 'speed', 'encounters'].forEach((k) => { e[k] = int(e[k], MT_MOUNT[k]); });
        e.speed = String(e.speed);
        return e;
      });
      return c;
    },
    serialize(c) {
      c.settings.hold_frames = Math.max(4, int(c.settings.hold_frames, 18));
      c.settings.block_switch = Math.max(0, int(c.settings.block_switch));
      c.mounts = c.mounts.filter((m) => m.species).map((m) => Object.assign({}, m, {
        id: String(m.id || m.species), form: int(m.form), level: Math.min(100, Math.max(1, int(m.level, 50))),
        speed: Math.min(6, Math.max(1, int(m.speed, 4))), encounters: Math.min(100, Math.max(0, int(m.encounters, 100))),
        water_only: !!m.water_only && m.powers.includes('surf'),
      }));
      return c;
    },
    problems(S) {
      const out = [];
      const ids = new Set();
      S.config.mounts.forEach((m, i) => {
        const id = m.id || m.species;
        if (!m.species) out.push(`Monture ${i + 1} : choisir un Pokémon.`);
        else if (!(S.ctx.creatures || []).some((x) => x.db === m.species)) out.push(`Monture ${i + 1} : Pokémon « ${m.species} » introuvable.`);
        if (id && ids.has(id)) out.push(`Identifiant en double : ${id}`);
        ids.add(id);
        if (m.water_only && !m.powers.includes('surf')) out.push(`${id} : « seulement sur l’eau » demande le pouvoir Surf.`);
      });
      return out;
    },
    render(S) {
      const c = S.config;
      const st = c.settings;
      const ui = S.ui;
      ui.mt = ui.mt || { tab: 'mounts', sel: 0, q: '', power: '' };
      const mt = ui.mt;
      if (!c.mounts[mt.sel]) mt.sel = 0;
      const content = h('div', { class: 'pjr-content' });
      content.appendChild(h('div', { class: 'pjr-actions pjr-tabs' }, [['mounts', `Montures (${c.mounts.length})`], ['settings', 'Réglages'], ['commands', 'Commandes']].map(([id, lab]) =>
        h('button', { class: 'pjs-btn small' + (mt.tab === id ? ' primary' : ''), onclick: () => redo(() => { mt.tab = id; }) }, lab))));
      if (mt.tab === 'settings') { content.appendChild(this.renderSettings(st)); return content; }
      if (mt.tab === 'commands') { content.appendChild(this.renderCommands(c)); return content; }
      const row = h('div', { class: 'pjr-row' });
      content.appendChild(row);
      // --- liste
      const left = h('div', { class: 'pjr-col list mtlistcol' });
      row.appendChild(left);
      const search = h('input', { class: 'pjs-input', placeholder: 'Rechercher une monture…', value: mt.q });
      const filter = h('select', { class: 'pjs-select', onchange: (e) => { mt.power = e.target.value; fill(); } },
        h('option', { value: '' }, 'Tous les pouvoirs'), ...MT_POWERS.map(([v, l]) => h('option', { value: v, selected: mt.power === v }, l)));
      const listEl = h('div', { class: 'pjr-list' });
      const fill = () => {
        listEl.textContent = '';
        const q = plain(mt.q);
        c.mounts.forEach((m, i) => {
          if (q && !plain(`${mtLabel(m)} ${m.id} ${m.species}`).includes(q)) return;
          if (mt.power && !m.powers.includes(mt.power)) return;
          const cr = mtSpecies(m);
          listEl.appendChild(h('div', { class: 'pjr-list-item mtitem' + (mt.sel === i ? ' active' : ''), onclick: () => redo(() => { mt.sel = i; }) },
            pic(`graphics/pokedex/pokeicon/${(cr && cr.icon) || '000'}`, 'icon'),
            h('span', { class: 'pjr-list-name' }, h('span', null, mtLabel(m)),
              h('span', { class: 'pjs-hint inline' }, `${m.id || m.species || '—'} · vitesse ${m.speed} · ${mtTerrain(m)}`),
              m.powers.length ? h('span', { class: 'mticons' }, ...MT_POWER_ORDER.filter((p) => m.powers.includes(p)).map((p) => mtIcon(p, 14))) : null),
            m.start ? h('span', { class: 'pjr-badge', title: 'Débloquée dès le début' }, 'début') : null));
        });
        if (!listEl.children.length) listEl.appendChild(h('div', { class: 'pjs-hint' }, c.mounts.length ? 'Aucune monture ne correspond.' : 'Aucune monture : clique sur Ajouter.'));
      };
      search.addEventListener('input', () => { mt.q = search.value; fill(); });
      fill();
      const add = () => redo(() => { c.mounts.push(Object.assign(clone(MT_MOUNT), { speed: '4' })); mt.sel = c.mounts.length - 1; mt.q = ''; mt.power = ''; });
      const cur0 = c.mounts[mt.sel];
      left.appendChild(block('Montures', h('span', { class: 'pjr-actions' },
        h('button', { class: 'pjs-btn small', onclick: add }, 'Ajouter'),
        cur0 ? h('button', { class: 'pjs-btn small', title: 'Copier cette monture', onclick: () => redo(() => { const k = clone(cur0); k.id = (k.id || k.species) + '_2'; c.mounts.splice(mt.sel + 1, 0, k); mt.sel += 1; }) }, 'Copier') : null),
        h('div', { class: 'pjr-listhead' }, search, filter), listEl));
      requestAnimationFrame(() => { const el = listEl.querySelector('.active'); if (el) el.scrollIntoView({ block: 'nearest' }); });
      // --- détail
      const right = h('div', { class: 'pjr-col wide' });
      row.appendChild(right);
      const m = cur0;
      if (!m) { right.appendChild(block('Monture', null, hint('Ajoute une monture pour la régler.'))); return content; }
      const cr = mtSpecies(m);
      const forms = (cr && cr.forms && cr.forms.length ? cr.forms : [0]).map((f) => [String(f), `Forme ${f}`]);
      const move = (d) => redo(() => { const j = mt.sel + d; if (j < 0 || j >= c.mounts.length) return; const [x] = c.mounts.splice(mt.sel, 1); c.mounts.splice(j, 0, x); mt.sel = j; });
      right.appendChild(h('div', { class: 'mthero' },
        pic(`graphics/pokedex/pokeicon/${(cr && cr.icon) || '000'}`, 'big'),
        h('div', { class: 'mthero-text' },
          h('div', { class: 'mthero-name' }, mtLabel(m)),
          h('div', { class: 'pjs-hint inline' }, `${cr ? cr.name : 'Pokémon à choisir'} · ${mtTerrain(m)} · vitesse ${m.speed}${m.gallop ? ' (+1 au galop)' : ''} · rencontres ${m.encounters} %`),
          h('code', { class: 'mtcode' }, `donner_monture('${m.id || m.species || 'id'}')`)),
        h('span', { class: 'pjr-actions' },
          h('button', { class: 'pjs-btn small', title: 'Monter dans la liste', disabled: mt.sel === 0, onclick: () => move(-1) }, '▲'),
          h('button', { class: 'pjs-btn small', title: 'Descendre dans la liste', disabled: mt.sel === c.mounts.length - 1, onclick: () => move(1) }, '▼'),
          h('button', { class: 'pjs-btn small danger', title: 'Supprimer cette monture', onclick: () => { if (confirm(`Supprimer la monture « ${mtLabel(m)} » ?`)) redo(() => { c.mounts.splice(mt.sel, 1); mt.sel = Math.max(0, mt.sel - 1); }); } }, '✕'))));
      const grid = h('div', { class: 'mtgrid' });
      right.appendChild(grid);
      grid.appendChild(block('Pokémon', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Espèce', combo({ value: m.species || '', items: L.creatures, placeholder: 'Pokémon…', onPick: (v) => redo(() => { const old = m.species; m.species = v; m.form = 0; if (!m.id || m.id === old) m.id = v; }) })),
          labeled('Forme', select(m, 'form', forms, { onChange: () => { m.form = int(m.form); } })),
          labeled('Nom (vide : nom de l’espèce)', textInput(m, 'name', { placeholder: cr ? cr.name : '' })),
          labeled('Nom anglais', textInput(m, 'name_en', { placeholder: m.name || '' })),
          labeled('Identifiant (commandes)', textInput(m, 'id', { placeholder: m.species || 'auto' })),
          labeled('Niveau (bandeau des CS)', numInput(m, 'level', { min: 1, max: 100, cls: 'tiny' }))),
        check(m, 'shiny', 'Chromatique')));
      const powers = h('div', { class: 'mtpowers' }, ...MT_POWERS.map(([p, l]) => h('label', { class: 'mtpower' + (m.powers.includes(p) ? ' on' : '') },
        h('input', { type: 'checkbox', checked: m.powers.includes(p), onchange: (e) => redo(() => {
          if (e.target.checked) m.powers.push(p); else m.powers.splice(m.powers.indexOf(p), 1);
          m.powers.sort((x, y) => MT_POWER_ORDER.indexOf(x) - MT_POWER_ORDER.indexOf(y));
          if (p === 'surf' && !e.target.checked) m.water_only = false;
        }) }), mtIcon(p), h('span', null, l))));
      grid.appendChild(block(`Pouvoirs (${m.powers.length})`, null, powers,
        hint('Sans pouvoir : monture de promenade (vitesse seulement). Les pouvoirs remplacent les CS dans les évents communs ; le Vol et le Flair se lancent depuis l’appli Monture.')));
      grid.appendChild(block('Déplacement', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Vitesse', select(m, 'speed', MT_SPEEDS)),
          labeled('Rencontres sauvages (%)', numInput(m, 'encounters', { min: 0, max: 100, cls: 'tiny' }))),
        check(m, 'gallop', 'Galop : +1 en courant (B)'),
        m.powers.includes('surf') ? check(m, 'water_only', 'Seulement sur l’eau (descend en arrivant sur la terre)') : hint('Avec le pouvoir Surf, la monture peut être réservée à l’eau.')));
      grid.appendChild(block('Déblocage et musique', null,
        check(m, 'start', 'Débloquée dès le début de la partie'),
        labeled('Musique (vide : celle des réglages)', bgmPicker(m, 'bgm')),
        hint('Sinon : donner_monture(\'' + (m.id || m.species || 'id') + '\') dans un évent.')));
      // sprites des héros
      const heroes = S.ctx.heroRides || [];
      const id = m.id || m.species;
      grid.appendChild(block('Sprites des héros', null,
        heroes.length ? h('div', { class: 'mtheroes' }, ...heroes.map((x) => {
          const file = x.generator ? null : (x.rides[id] || null);
          return h('div', { class: 'mtherorow' + (file ? ' ok' : '') },
            file ? pic(`graphics/characters/${file}`, 'chara mtchara') : h('span', { class: 'mtnone' }, '—'),
            h('span', { class: 'pjr-list-name' }, h('span', null, x.name || x.id), h('span', { class: 'pjs-hint inline' }, x.generator ? 'générateur : sprite habituel' : (file || 'aucun sprite : sprite habituel'))));
        })) : null,
        hint('Chaque héros a une case par monture dans Personnages > Héros > Ressources > Montures.')));
      return content;
    },
    renderSettings(st) {
      const row = h('div', { class: 'mtgrid' });
      row.appendChild(block('Appel', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Touche des montures', select(st, 'key', MT_KEYS)),
          labeled('Appui long (images)', numInput(st, 'hold_frames', { min: 4, max: 120, cls: 'tiny' }))),
        labeled('Objet nécessaire', combo({ value: st.item || '', items: L.items, allowEmpty: true, emptyLabel: '(aucun)', onPick: (v) => redo(() => { st.item = v; }) })),
        check(st, 'cry_on_call', 'Cri de la monture quand on l’appelle'),
        hint('Appui court : monter sur la dernière monture (une monture d’eau sur l’eau) ou descendre. Appui long : roue des montures. L’appli Monture du téléphone apparaît dès qu’une monture est débloquée.')));
      row.appendChild(block('Où monter', null,
        check(st, 'outdoor_only', 'Seulement là où le vélo est permis (dehors)'),
        labeled('Interrupteur qui interdit les montures (0 = aucun)', numInput(st, 'block_switch', { min: 0, max: 9999, cls: 'tiny' })),
        labeled('Musique sur une monture', bgmPicker(st, 'ride_bgm')),
        hint('En entrant dans une carte interdite, le joueur descend tout seul.')));
      row.appendChild(block('CS et contact', null,
        check(st, 'prefer_mount', 'La monture agit même si un Pokémon de l’équipe connaît la CS'),
        check(st, 'ask_on_contact', 'Demander avant d’entrer dans l’eau (à pied)'),
        check(st, 'auto_switch', 'Passer seul d’une monture de terre à une monture d’eau'),
        check(st, 'hm_animation', 'Bandeau des CS quand une monture agit (sinon son cri)'),
        hint('Les évents communs des CS (Surf, Force, Éclate-Roc, Coupe, Cascade, Siphon, Plongée, Escalade, Coup d’Boule, Flash, Vol) acceptent une monture qui a le pouvoir ; sans monture, les CS de l’équipe marchent comme avant.')));
      return row;
    },
    renderCommands(c) {
      const id = (c.mounts[0] && (c.mounts[0].id || c.mounts[0].species)) || 'wyrdeer';
      return h('div', { class: 'mtgrid' }, commands([
        [`donner_monture('${id}')`, 'débloque une monture (message: false pour aucun message)'],
        [`retirer_monture('${id}')`, 'la reprend'],
        [`monture?('${id}')`, 'condition : monture débloquée'],
        [`monter('${id}')`, 'monte dessus (sans argument : la dernière)'],
        ['descendre', 'descend de la monture'],
        ['monte?', 'condition : le joueur est sur une monture'],
        ['monture_actuelle', 'identifiant de la monture (nil à pied)'],
        ['roue_montures', 'ouvre la roue des montures'],
        ['appli_monture', 'ouvre l’appli Monture'],
        ['toutes_les_montures', 'débloque tout (tests)'],
      ]));
    },
  };
  // ===========================================================================
  // Level design > Mini-jeux > Pokéathlon (pokeathlon.json)
  // ===========================================================================
  const PA_EVENTS = [['hurdle', 'Course de haies'], ['pennant', 'Capture de fanions'], ['relay', 'Relais'], ['block', 'Casse-blocs'],
    ['circle', 'Pousse-cercle'], ['goal', 'Tir au but'], ['snow', 'Bataille de neige'], ['lamp', 'Saut lumineux'], ['disc', 'Attrape-disques'], ['ring', 'Anneau']];
  const PA_EVENT_UNITS = { hurdle: 'temps (s) : plus petit = meilleur', pennant: 'fanions', relay: 'tours', block: 'blocs', circle: 'points', goal: 'buts',
    snow: 'touches', lamp: 'points', disc: 'points', ring: 'Pokémon tombés' };
  const PA_EVENT_DEFAULTS = { hurdle: [90, 28, 24], pennant: [60, 18, 28], relay: [60, 9, 11], block: [45, 220, 300], circle: [60, 250, 340],
    goal: [60, 3, 6], snow: [60, 10, 16], lamp: [60, 800, 1300], disc: [60, 25, 40], ring: [60, 3, 6] };
  const PA_STATS = [['speed', 'Vitesse'], ['power', 'Force'], ['skill', 'Technique'], ['stamina', 'Endurance'], ['jump', 'Saut']];
  const PA_FLAVORS = [['spicy', 'Épicé', 'Force'], ['dry', 'Sec', 'Technique'], ['sweet', 'Sucré', 'Vitesse'], ['bitter', 'Amer', 'Saut'], ['sour', 'Acide', 'Endurance']];
  const PA_DAYS = [['1', 'Lundi'], ['2', 'Mardi'], ['3', 'Mercredi'], ['4', 'Jeudi'], ['5', 'Vendredi'], ['6', 'Samedi'], ['0', 'Dimanche']];
  const PA_DEFAULTS = { rank_points: [100, 70, 45, 25], score_points: 60, first_bonus: 100, difficulty: 2, menu_bgm: '', event_bgm: '', win_me: '',
    juice_steps: 100, juice_uses: 3, juice_apricorns: 5, blender_item: 'apricorn_box', juice_pc_reset: true, daily_range: 1, nature_effect: true };
  const PA_COURSES = [['speed', 'Coupe Vitesse', 'Speed Course', ['hurdle', 'pennant', 'relay']], ['power', 'Coupe Force', 'Power Course', ['block', 'circle', 'goal']],
    ['skill', 'Coupe Technique', 'Skill Course', ['snow', 'goal', 'pennant']], ['stamina', 'Coupe Endurance', 'Stamina Course', ['block', 'ring', 'relay']],
    ['jump', 'Coupe Saut', 'Jump Course', ['lamp', 'disc', 'hurdle']]].map(([id, fr, en, events]) => ({ id, name: { fr, en }, events }));
  const PA_OPPONENTS = [['Les Fulgurants', 'The Bolts', ['pikachu', 'jolteon', 'electabuzz']], ['Les Plumes', 'The Feathers', ['pidgeotto', 'fearow', 'doduo']],
    ['Les Costauds', 'The Brawlers', ['machoke', 'hitmonlee', 'tauros']], ['Les Bondissants', 'The Bouncers', ['buneary', 'spoink', 'wooper']],
    ['Les Flammèches', 'The Embers', ['ponyta', 'growlithe', 'vulpix']], ['Les Vagues', 'The Waves', ['psyduck', 'marill', 'totodile']],
    ['Les Feuillus', 'The Leaves', ['oddish', 'chikorita', 'sunkern']], ['Les Rapides', 'The Speedsters', ['rattata', 'zubat', 'sentret']],
    ['Les Malins', 'The Clever', ['abra', 'natu', 'smoochum']], ['Les Rocs', 'The Rocks', ['geodude', 'onix', 'sudowoodo']],
    ['Les Étoiles', 'The Stars', ['clefairy', 'staryu', 'togepi']], ['Les Champions', 'The Champions', ['gyarados', 'dragonite', 'tyranitar']]]
    .map(([fr, en, team]) => ({ name: { fr, en }, team }));
  const PA_APRICORNS = { red_apricorn: [12, 0, 3, 0, 0], yellow_apricorn: [3, 0, 0, 0, 12], blue_apricorn: [0, 12, 0, 3, 0], green_apricorn: [0, 3, 0, 12, 0],
    pink_apricorn: [0, 0, 12, 0, 3], white_apricorn: [-3, -3, -3, -3, -3], black_apricorn: [6, 6, 6, 6, 6] };
  const PA_EVENT_STATS = { hurdle: ['speed', 'jump', 'skill'], pennant: ['speed', 'skill', 'stamina', 'power'], relay: ['speed', 'stamina', 'skill', 'power'],
    block: ['power', 'stamina', 'skill'], circle: ['power', 'speed', 'stamina'], goal: ['power', 'skill', 'speed', 'stamina'], snow: ['power', 'skill', 'stamina'],
    lamp: ['jump', 'skill', 'stamina'], disc: ['jump', 'speed', 'power'], ring: ['power', 'stamina', 'speed', 'jump'] };
  const PA_STAT_NAMES = { speed: 'Vitesse', power: 'Force', skill: 'Technique', stamina: 'Endurance', jump: 'Saut' };
  const paStarsOf = (v) => (v < 45 ? 1 : v < 65 ? 2 : v < 85 ? 3 : v < 105 ? 4 : 5);
  // performances calculées comme en jeu (statistiques de base)
  function paAuto(cr) {
    const [hp, atk, dfe, spd, ats, dfs] = (cr && cr.stats) || [50, 50, 50, 50, 50, 50];
    const base = [spd, atk, Math.floor((ats + dfs) / 2), Math.floor((hp + dfe) / 2), Math.floor((spd + ats) / 2)].map(paStarsOf);
    const total = hp + atk + dfe + spd + ats + dfs;
    return { base, max: base.map((b) => Math.min(5, b + (total >= 500 ? 2 : 1))) };
  }
  const paSpecies = (db) => (cur().ctx.creatures || []).find((x) => x.db === db);
  const paEventName = (id) => (PA_EVENTS.find((e) => e[0] === id) || [id, id])[1];
  const paLang = (v) => (isObj(v) ? v.fr || v.en || '' : String(v || ''));
  const pokeathlonPage = {
    title: 'Pokéathlon',
    normalize(c) {
      c.klass = 'PokeathlonConfig';
      c.settings = Object.assign(clone(PA_DEFAULTS), isObj(c.settings) ? c.settings : {});
      const st = c.settings;
      st.rank_points = [0, 1, 2, 3].map((i) => int(Array.isArray(st.rank_points) ? st.rank_points[i] : undefined, PA_DEFAULTS.rank_points[i]));
      ['juice_pc_reset', 'nature_effect'].forEach((k) => { st[k] = st[k] !== false; });
      st.difficulty = String(int(st.difficulty, 2));
      c.courses = (Array.isArray(c.courses) && c.courses.length ? c.courses : clone(PA_COURSES)).filter(isObj).map((x) => {
        const events = (Array.isArray(x.events) ? x.events : []).slice(0, 3);
        while (events.length < 3) events.push('hurdle');
        return { id: String(x.id || ''), name: isObj(x.name) ? x.name : { fr: String(x.name || ''), en: '' }, icon: x.icon == null ? '' : x.icon, switch: int(x.switch), events };
      });
      const ev = isObj(c.events) ? c.events : {};
      c.events = {};
      PA_EVENTS.forEach(([id]) => {
        const d = PA_EVENT_DEFAULTS[id];
        const o = isObj(ev[id]) ? ev[id] : {};
        c.events[id] = Object.assign({}, o, { time: Number(o.time ?? d[0]), medal: Number(o.medal ?? d[1]), crown: Number(o.crown ?? d[2]) });
      });
      c.opponents = (Array.isArray(c.opponents) && c.opponents.length ? c.opponents : clone(PA_OPPONENTS)).filter(isObj).map((o) => {
        const team = (Array.isArray(o.team) ? o.team : []).slice(0, 3);
        while (team.length < 3) team.push('');
        return { name: isObj(o.name) ? o.name : { fr: String(o.name || ''), en: '' }, team };
      });
      c.performance = isObj(c.performance) ? c.performance : {};
      Object.keys(c.performance).forEach((k) => {
        const p = c.performance[k];
        if (!isObj(p) || !Array.isArray(p.base) || !Array.isArray(p.max)) delete c.performance[k];
      });
      const apr = isObj(c.apricorns) && Object.keys(c.apricorns).length ? c.apricorns : clone(PA_APRICORNS);
      c.apricorns = Object.keys(apr).map((item) => ({ item, flavors: [0, 1, 2, 3, 4].map((i) => int((apr[item] || [])[i])) }));
      const shop = isObj(c.shop) && Object.keys(c.shop).length ? c.shop : null;
      c.shop = {};
      PA_DAYS.forEach(([d]) => {
        c.shop[d] = shop ? (Array.isArray(shop[d]) ? shop[d] : []).filter(isObj).map((e) => ({ item: String(e.item || ''), price: int(e.price) })) : null;
      });
      if (!shop) {
        const def = { 1: [['red_apricorn', 200], ['blue_apricorn', 200], ['green_apricorn', 200], ['moomoo_milk', 100], ['moon_stone', 3000], ['rare_candy', 2000]],
          2: [['yellow_apricorn', 200], ['pink_apricorn', 200], ['white_apricorn', 200], ['moomoo_milk', 100], ['fire_stone', 3000], ['pp_up', 1000]],
          3: [['blue_apricorn', 200], ['pink_apricorn', 200], ['black_apricorn', 200], ['moomoo_milk', 100], ['water_stone', 2500], ['heart_scale', 1000]],
          4: [['yellow_apricorn', 200], ['pink_apricorn', 200], ['white_apricorn', 200], ['moomoo_milk', 100], ['thunder_stone', 2500], ['pp_up', 500]],
          5: [['red_apricorn', 200], ['yellow_apricorn', 200], ['green_apricorn', 200], ['moomoo_milk', 100], ['metal_coat', 2500], ['nugget', 500]],
          6: [['green_apricorn', 200], ['white_apricorn', 200], ['black_apricorn', 200], ['moomoo_milk', 100], ['leaf_stone', 2500], ['rare_candy', 2000]],
          0: [['red_apricorn', 200], ['blue_apricorn', 200], ['black_apricorn', 200], ['moomoo_milk', 100], ['kings_rock', 3000], ['heart_scale', 1000]] };
        PA_DAYS.forEach(([d]) => { c.shop[d] = def[d].map(([item, price]) => ({ item, price })); });
      }
      return c;
    },
    serialize(c) {
      const st = c.settings;
      st.difficulty = Math.min(3, Math.max(1, int(st.difficulty, 2)));
      ['score_points', 'first_bonus', 'juice_steps', 'juice_uses', 'juice_apricorns', 'daily_range'].forEach((k) => { st[k] = Math.max(0, int(st[k], PA_DEFAULTS[k])); });
      st.juice_apricorns = Math.min(10, Math.max(1, st.juice_apricorns));
      st.juice_uses = Math.max(1, st.juice_uses);
      st.daily_range = Math.min(2, st.daily_range);
      c.courses = c.courses.filter((x) => x.id).map((x) => {
        const o = { id: x.id, name: x.name, events: x.events.slice(0, 3) };
        if (x.icon !== '' && x.icon != null) o.icon = int(x.icon);
        if (int(x.switch) > 0) o.switch = int(x.switch);
        return o;
      });
      c.opponents = c.opponents.map((o) => ({ name: o.name, team: o.team.filter(Boolean) })).filter((o) => o.team.length);
      const apr = {};
      c.apricorns.filter((a) => a.item).forEach((a) => { apr[a.item] = a.flavors.map((v) => int(v)); });
      c.apricorns = apr;
      PA_DAYS.forEach(([d]) => { c.shop[d] = c.shop[d].filter((e) => e.item).map((e) => ({ item: e.item, price: Math.max(0, int(e.price)) })); });
      return c;
    },
    problems(S) {
      const out = [];
      const c = S.config;
      const ids = new Set();
      c.courses.forEach((x, i) => {
        if (!x.id) out.push(`Coupe ${i + 1} : identifiant vide.`);
        else if (ids.has(x.id)) out.push(`Coupe en double : ${x.id}`);
        ids.add(x.id);
      });
      const known = new Set((S.ctx.creatures || []).map((x) => x.db));
      c.opponents.forEach((o, i) => o.team.forEach((sp) => { if (sp && !known.has(sp)) out.push(`Équipe ${i + 1} : Pokémon « ${sp} » introuvable.`); }));
      const items = new Set((S.ctx.items || []).map((x) => x.db));
      c.apricorns.forEach((a) => { if (a.item && !items.has(a.item)) out.push(`Noigrume : objet « ${a.item} » introuvable.`); });
      PA_DAYS.forEach(([d, day]) => c.shop[d].forEach((e) => { if (e.item && !items.has(e.item)) out.push(`Boutique (${day}) : objet « ${e.item} » introuvable.`); }));
      return out;
    },
    render(S) {
      const c = S.config;
      const ui = S.ui;
      ui.pa = ui.pa || { tab: 'courses', day: String(new Date().getDay()), sel: '', q: '', form: 0 };
      const pa = ui.pa;
      const content = h('div', { class: 'pjr-content' });
      const tabs = [['courses', `Coupes (${c.courses.length})`], ['events', 'Épreuves'], ['opponents', `Adversaires (${c.opponents.length})`],
        ['performance', `Performances (${Object.keys(c.performance).length})`], ['apricorns', 'Noigrumes'], ['shop', 'Boutique'], ['settings', 'Réglages'], ['commands', 'Commandes']];
      content.appendChild(h('div', { class: 'pjr-actions pjr-tabs' }, tabs.map(([id, lab]) =>
        h('button', { class: 'pjs-btn small' + (pa.tab === id ? ' primary' : ''), onclick: () => redo(() => { pa.tab = id; }) }, lab))));
      const fn = { courses: 'renderCourses', events: 'renderEvents', opponents: 'renderOpponents', performance: 'renderPerformance',
        apricorns: 'renderApricorns', shop: 'renderShop', settings: 'renderSettings', commands: 'renderCommands' }[pa.tab] || 'renderCourses';
      content.appendChild(this[fn](S, pa));
      return content;
    },
    renderCourses(S, pa) {
      const c = S.config;
      const list = c.courses;
      pa.course = Math.min(Math.max(int(pa.course), 0), Math.max(list.length - 1, 0));
      const iconOf = (x, i) => (x.icon === '' || x.icon == null ? i % 5 : int(x.icon) % 5);
      const statsOf = (x) => {
        const n = {};
        x.events.forEach((e) => (PA_EVENT_STATS[e] || []).forEach((st, k) => { n[st] = (n[st] || 0) + (k === 0 ? 2 : 1); }));
        return n;
      };
      const row = h('div', { class: 'pjr-row parow' });
      // --- liste des coupes ---
      const items = list.map((x, i) => h('div', { class: 'pjr-list-item pacourse' + (i === pa.course ? ' active' : ''), onclick: () => redo(() => { pa.course = i; }) },
        pic(`graphics/interface/pokeathlon/coupe_${iconOf(x, i)}`, 'pacup'),
        h('span', { class: 'pjr-list-name' }, h('span', { class: 'pacourse-name' }, paLang(x.name) || x.id || `Coupe ${i + 1}`),
          h('span', { class: 'pjs-hint inline' }, x.events.map(paEventName).join(' · '))),
        int(x.switch) > 0 ? h('span', { class: 'pjr-badge', title: `Disponible quand l’interrupteur ${x.switch} est activé` }, `int. ${x.switch}`) : null));
      row.appendChild(h('div', { class: 'pjr-col list mtlistcol' }, block(`Coupes (${list.length})`, h('span', { class: 'pjr-actions' },
        h('button', { class: 'pjs-btn small primary', onclick: () => redo(() => {
          let n = list.length + 1;
          while (list.some((x) => x.id === `coupe_${n}`)) n += 1;
          list.push({ id: `coupe_${n}`, name: { fr: 'Nouvelle coupe', en: 'New Course' }, icon: '', switch: 0, events: ['hurdle', 'block', 'lamp'] });
          pa.course = list.length - 1;
        }) }, '+ Nouvelle coupe')),
      h('div', { class: 'pjr-list' }, ...(items.length ? items : [h('div', { class: 'pjs-hint' }, 'Aucune coupe : les 5 coupes de HGSS seront utilisées.')])),
      h('div', { class: 'pjr-actions' }, h('button', { class: 'pjs-btn small', onclick: () => { if (confirm('Remplacer toutes les coupes par les 5 coupes de HGSS ?')) redo(() => { list.splice(0, list.length, ...clone(PA_COURSES)); pa.course = 0; }); } }, 'Remettre les coupes de HGSS')))));
      // --- détail ---
      const right = h('div', { class: 'pjr-col wide' });
      row.appendChild(right);
      const x = list[pa.course];
      if (!x) return row;
      const i = pa.course;
      const move = (d) => redo(() => { const j = i + d; if (j < 0 || j >= list.length) return; [list[i], list[j]] = [list[j], list[i]]; pa.course = j; });
      right.appendChild(h('div', { class: 'mthero' },
        pic(`graphics/interface/pokeathlon/coupe_${iconOf(x, i)}`, 'pacup big'),
        h('div', { class: 'mthero-text' }, h('div', { class: 'mthero-name' }, paLang(x.name) || x.id),
          h('code', { class: 'mtcode' }, `pokeathlon('${x.id || 'id'}')`)),
        h('span', { class: 'pjr-actions' },
          h('button', { class: 'pjs-btn small', title: 'Monter', disabled: i === 0, onclick: () => move(-1) }, '▲'),
          h('button', { class: 'pjs-btn small', title: 'Descendre', disabled: i === list.length - 1, onclick: () => move(1) }, '▼'),
          h('button', { class: 'pjs-btn small', onclick: () => redo(() => {
            const copy = clone(x);
            let n = 2;
            while (list.some((y) => y.id === `${x.id}_${n}`)) n += 1;
            copy.id = `${x.id}_${n}`;
            list.splice(i + 1, 0, copy);
            pa.course = i + 1;
          }) }, 'Dupliquer'),
          h('button', { class: 'pjs-btn small danger', onclick: () => { if (confirm(`Supprimer la coupe « ${paLang(x.name) || x.id} » ?`)) redo(() => { list.splice(i, 1); pa.course = Math.max(0, i - 1); }); } }, 'Supprimer'))));
      const live = () => {
        const label = paLang(x.name) || x.id || `Coupe ${i + 1}`;
        const item = row.querySelectorAll('.pacourse-name')[i];
        if (item) item.textContent = label;
        const name = right.querySelector('.mthero-name');
        if (name) name.textContent = label;
        const code = right.querySelector('.mthero .mtcode');
        if (code) code.textContent = `pokeathlon('${x.id || 'id'}')`;
      };
      right.addEventListener('input', () => requestAnimationFrame(live));
      right.appendChild(block('Coupe', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Identifiant', textInput(x, 'id', { placeholder: 'speed' }), 'utilisé par les commandes et pour les records'),
          labeled('Nom', langInputs(x, 'name'))),
        h('div', { class: 'pjr-grid2' },
          labeled('Icône', h('span', { class: 'paicons' }, ...[0, 1, 2, 3, 4].map((k) => h('button', {
            type: 'button', class: 'paicon' + (iconOf(x, i) === k ? ' on' : ''), title: `Icône ${k + 1}`,
            onclick: () => redo(() => { x.icon = k; }) }, pic(`graphics/interface/pokeathlon/coupe_${k}`, 'pacup'))))),
          labeled('Disponible si l’interrupteur', numInput(x, 'switch', { min: 0, cls: 'tiny' }), '0 : toujours disponible'))));
      const used = new Set();
      const slots = [0, 1, 2].map((k) => {
        const ev = x.events[k];
        const dup = used.has(ev);
        used.add(ev);
        return h('div', { class: 'paslot' + (dup ? ' dup' : '') },
          h('div', { class: 'paslot-num' }, `Épreuve ${k + 1}`),
          select(x.events, k, PA_EVENTS, { onChange: () => {} }),
          h('div', { class: 'paslot-stats' }, ...(PA_EVENT_STATS[ev] || []).map((st, n) => h('span', { class: 'pastat-chip' + (n === 0 ? ' main' : '') }, PA_STAT_NAMES[st]))),
          dup ? h('div', { class: 'pjs-hint inline' }, 'Déjà dans cette coupe') : null);
      });
      const n = statsOf(x);
      right.appendChild(block('Épreuves', null, h('div', { class: 'paslots' }, ...slots),
        h('div', { class: 'pjs-hint' }, 'Performances sollicitées : ' + PA_STATS.map(([st, name]) => `${name} ${'●'.repeat(Math.min(n[st] || 0, 6))}${n[st] ? '' : '–'}`).join('   ')),
        hint('La première statistique de chaque épreuve (en couleur) compte le plus. Gagner la coupe donne sa médaille aux 3 Pokémon.')));
      return row;
    },
    renderEvents(S) {
      const c = S.config;
      const rows = PA_EVENTS.map(([id, name]) => h('div', { class: 'pjr-trow paev' },
        h('span', { class: 'pjr-itemname' }, name), h('span', { class: 'pjs-hint inline' }, PA_EVENT_UNITS[id]),
        numInput(c.events[id], 'time', { min: 15, max: 300, cls: 'tiny' }),
        numInput(c.events[id], 'medal', { min: 0, step: id === 'hurdle' ? 0.1 : 1, cls: 'tiny' }),
        numInput(c.events[id], 'crown', { min: 0, step: id === 'hurdle' ? 0.1 : 1, cls: 'tiny' })));
      return block('Épreuves', h('button', { class: 'pjs-btn small', onclick: () => { if (confirm('Remettre les valeurs par défaut ?')) redo(() => { c.events = {}; this.normalize(c); }); } }, 'Valeurs par défaut'),
        h('div', { class: 'pjr-table' }, h('div', { class: 'pjr-thead paev' }, h('span', null, 'Épreuve'), h('span', null, 'Score'), h('span', null, 'Durée (s)'), h('span', null, 'Médaille'), h('span', null, 'Couronne')), ...rows),
        hint('Score de l’équipe du joueur à atteindre pour une médaille ou une couronne (Données du Pokéathlon). Les points gagnés à une épreuve : place + score / médaille × « points selon le score ». La course de haies n’a pas de durée : c’est le temps des 3 relais.'));
    },
    renderOpponents(S) {
      const c = S.config;
      const rows = c.opponents.map((o, i) => h('div', { class: 'pjr-trow paop' },
        langInputs(o, 'name'),
        ...[0, 1, 2].map((k) => combo({ value: o.team[k] || '', items: L.creatures, placeholder: 'Pokémon…', allowEmpty: true, onPick: (v) => redo(() => { o.team[k] = v; }) })),
        rowButtons(c.opponents, i)));
      return block('Équipes adverses', h('span', { class: 'pjr-actions' },
        h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.opponents.push({ name: { fr: 'Nouvelle équipe', en: 'New Team' }, team: ['', '', ''] }); }) }, 'Ajouter'),
        h('button', { class: 'pjs-btn small', onclick: () => { if (confirm('Remettre les 12 équipes par défaut ?')) redo(() => { c.opponents = clone(PA_OPPONENTS); }); } }, 'Équipes par défaut')),
        h('div', { class: 'pjr-table' }, h('div', { class: 'pjr-thead paop' }, h('span', null, 'Nom'), h('span', null, 'Pokémon 1'), h('span', null, 'Pokémon 2'), h('span', null, 'Pokémon 3'), h('span', null, '')), ...rows),
        hint('3 équipes sont tirées au hasard à chaque coupe (Pokémon niveau 30). Leur force dépend de leurs performances et de la difficulté (Réglages).'));
    },
    renderPerformance(S, pa) {
      const c = S.config;
      const row = h('div', { class: 'pjr-row parow' });
      const left = h('div', { class: 'pjr-col list mtlistcol' });
      row.appendChild(left);
      const search = h('input', { class: 'pjs-input', placeholder: 'Rechercher un Pokémon…', value: pa.q });
      const onlyOwn = h('label', { class: 'pjs-inline pjr-check' }, h('input', { type: 'checkbox', checked: !!pa.own, onchange: (e) => { pa.own = e.target.checked; fill(); } }), 'Seulement les espèces réglées');
      const listEl = h('div', { class: 'pjr-list' });
      const isOwn = (db) => Object.keys(c.performance).some((k) => k === db || k.startsWith(db + '_'));
      const fill = () => {
        listEl.textContent = '';
        const q = plain(pa.q);
        let n = 0;
        (S.ctx.creatures || []).forEach((cr) => {
          if (n > 400) return;
          if (q && !plain(`${cr.name} ${cr.db} ${cr.id}`).includes(q)) return;
          if (pa.own && !isOwn(cr.db)) return;
          n += 1;
          listEl.appendChild(h('div', { class: 'pjr-list-item' + (pa.sel === cr.db ? ' active' : ''), onclick: () => redo(() => { pa.sel = cr.db; pa.form = 0; }) },
            pic(`graphics/pokedex/pokeicon/${cr.icon || '000'}`, 'icon'),
            h('span', { class: 'pjr-list-name' }, h('span', null, cr.name), h('span', { class: 'pjs-hint inline' }, `n° ${cr.id} · ${cr.db}`)),
            isOwn(cr.db) ? h('span', { class: 'pjr-badge' }, 'réglé') : null));
        });
        if (!listEl.children.length) listEl.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun Pokémon.'));
      };
      search.addEventListener('input', () => { pa.q = search.value; fill(); });
      fill();
      left.appendChild(block('Pokémon', null, h('div', { class: 'pjr-listhead' }, search, onlyOwn), listEl));
      requestAnimationFrame(() => { const el = listEl.querySelector('.active'); if (el) el.scrollIntoView({ block: 'nearest' }); });
      const right = h('div', { class: 'pjr-col wide' });
      row.appendChild(right);
      const cr = paSpecies(pa.sel);
      if (!cr) {
        right.appendChild(block('Performances', null, hint('Choisis un Pokémon à gauche. Sans réglage, ses performances sont calculées depuis ses statistiques de base : Vitesse ← Vitesse, Force ← Attaque, Technique ← (Atq. Spé. + Déf. Spé.) / 2, Endurance ← (PV + Défense) / 2, Saut ← (Vitesse + Atq. Spé.) / 2 ; maximum = base + 1 (+2 si le total des statistiques dépasse 500).')));
        return row;
      }
      const forms = (cr.forms && cr.forms.length ? cr.forms : [0]);
      const form = forms.includes(pa.form) ? pa.form : 0;
      const key = form > 0 ? `${cr.db}_${form}` : cr.db;
      const auto = paAuto(cr);
      const own = c.performance[key];
      const perf = own || auto;
      const setStar = (i, v, which) => redo(() => {
        const p = c.performance[key] || (c.performance[key] = clone(auto));
        if (which === 'max') { p.max[i] = Math.max(v, p.base[i]); } else { p.base[i] = v; p.max[i] = Math.max(p.max[i], v); }
      });
      const statRows = PA_STATS.map(([, name], i) => h('div', { class: 'pastat' },
        h('span', { class: 'pastat-name' }, name),
        h('span', { class: 'pastars' }, ...[1, 2, 3, 4, 5].map((v) => h('button', {
          class: 'pastar' + (v <= perf.base[i] ? ' on' : v <= perf.max[i] ? ' max' : ''), type: 'button',
          title: 'Clic : étoiles de base · Clic droit : maximum',
          onclick: () => setStar(i, v, 'base'), oncontextmenu: (e) => { e.preventDefault(); setStar(i, v, 'max'); } }, '★'))),
        h('span', { class: 'pjs-hint inline' }, `base ${perf.base[i]} · max ${perf.max[i]}` + (own ? ` (auto ${auto.base[i]} / ${auto.max[i]})` : ''))));
      right.appendChild(h('div', { class: 'mthero' },
        pic(`graphics/pokedex/pokeicon/${cr.icon || '000'}`, 'big'),
        h('div', { class: 'mthero-text' }, h('div', { class: 'mthero-name' }, cr.name),
          h('div', { class: 'pjs-hint inline' }, own ? 'Performances réglées' : 'Performances calculées (statistiques de base)')),
        forms.length > 1 ? select(pa, 'form', forms.map((f) => [String(f), `Forme ${f}`]), { onChange: () => { pa.form = int(pa.form); } }) : null,
        own ? h('button', { class: 'pjs-btn small', onclick: () => redo(() => { delete c.performance[key]; }) }, 'Calcul automatique') : null));
      right.appendChild(block('Performances', null, h('div', { class: 'pastats' }, ...statRows),
        hint('Étoiles jaunes : base. Étoiles bleues : maximum (atteint avec la variation du jour, la nature ou un Jus de Noigrume). En jeu : base ± variation du jour, +1 / −1 selon la nature, + jus, entre 1 et le maximum.')));
      return row;
    },
    renderApricorns(S) {
      const c = S.config;
      const rows = c.apricorns.map((a, i) => h('div', { class: 'pjr-trow paapr' },
        combo({ value: a.item, items: L.items, placeholder: 'Objet…', onPick: (v) => redo(() => { a.item = v; }) }),
        ...[0, 1, 2, 3, 4].map((k) => numInput(a.flavors, k, { min: -63, max: 63, cls: 'tiny' })),
        rowButtons(c.apricorns, i)));
      return h('div', { class: 'pjr-row parow' }, h('div', { class: 'pjr-col wide' },
        block('Noigrumes', h('span', { class: 'pjr-actions' },
          h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.apricorns.push({ item: '', flavors: [0, 0, 0, 0, 0] }); }) }, 'Ajouter'),
          h('button', { class: 'pjs-btn small', onclick: () => { if (confirm('Remettre les 7 Noigrumes par défaut ?')) redo(() => { c.apricorns = Object.keys(PA_APRICORNS).map((item) => ({ item, flavors: PA_APRICORNS[item].slice() })); }); } }, 'Par défaut')),
          h('div', { class: 'pjr-table' }, h('div', { class: 'pjr-thead paapr' }, h('span', null, 'Objet'), ...PA_FLAVORS.map(([, f, s]) => h('span', { title: s }, f)), h('span', null, '')), ...rows))),
        h('div', { class: 'pjr-col narrow' }, block('Jus de Noigrume', null,
          h('div', { class: 'pjr-stack' }, ...PA_FLAVORS.map(([, f, s]) => h('div', { class: 'pjs-hint' }, `${f} → ${s}`))),
          hint('Les saveurs des Noigrumes du mixeur s’additionnent (63 au plus chacune, 100 au total). Un verre : saveur la plus forte +1 (+2 à partir de 24), deuxième saveur +1 à partir de 12, saveur la plus faible −1 si la douceur est sous 60. La douceur monte de 1 tous les 20 pas.'))));
    },
    renderShop(S, pa) {
      const c = S.config;
      const list = c.shop[pa.day] || (c.shop[pa.day] = []);
      const dayName = (PA_DAYS.find((d) => d[0] === pa.day) || ['', ''])[1];
      const rows = list.map((e, i) => h('div', { class: 'pjr-trow food' },
        combo({ value: e.item, items: L.items, placeholder: 'Objet…', onPick: (v) => redo(() => { e.item = v; }) }),
        h('span', null), numInput(e, 'price', { min: 0, cls: 'tiny' }), rowButtons(list, i)));
      return h('div', null,
        h('div', { class: 'pjr-actions pjr-tabs' }, ...PA_DAYS.map(([d, n]) => h('button', { class: 'pjs-btn small' + (pa.day === d ? ' primary' : ''), onclick: () => redo(() => { pa.day = d; }) }, `${n} (${(c.shop[d] || []).length})`))),
        block(`Boutique du ${dayName.toLowerCase()}`, h('span', { class: 'pjr-actions' },
          h('button', { class: 'pjs-btn small', onclick: () => redo(() => { list.push({ item: '', price: 100 }); }) }, 'Ajouter'),
          h('button', { class: 'pjs-btn small', onclick: () => { if (confirm(`Copier la boutique du ${dayName.toLowerCase()} sur tous les jours ?`)) redo(() => { PA_DAYS.forEach(([d]) => { c.shop[d] = clone(list); }); }); } }, 'Copier sur tous les jours')),
          h('div', { class: 'pjr-table' }, h('div', { class: 'pjr-thead food' }, h('span', null, 'Objet'), h('span', null, ''), h('span', null, 'Prix (points)'), h('span', null, '')), ...rows),
          hint('boutique_pokeathlon ouvre le comptoir du jour (plugin magasins) ; on paie avec les points Pokéathlon. Un magasin « pokeathlon » réglé dans Level design > Magasins remplace celui-ci.')));
    },
    renderSettings(S) {
      const st = S.config.settings;
      const row = h('div', { class: 'mtgrid' });
      row.appendChild(block('Points', null,
        labeled('Points par place (1er, 2e, 3e, 4e)', h('span', { class: 'pjr-range' }, ...[0, 1, 2, 3].map((i) => numInput(st.rank_points, i, { min: 0, cls: 'tiny' })))),
        h('div', { class: 'pjr-grid2' },
          labeled('Points selon le score', numInput(st, 'score_points', { min: 0, cls: 'tiny' }), 'score / médaille × ce nombre, au plus le double'),
          labeled('Bonus de la 1re place', numInput(st, 'first_bonus', { min: 0, cls: 'tiny' }))),
        labeled('Difficulté des adversaires', select(st, 'difficulty', [['1', '1 · facile'], ['2', '2 · normale'], ['3', '3 · difficile']])),
        hint('Les points gagnés à chaque coupe se dépensent à la boutique.')));
      row.appendChild(block('Musiques', null,
        labeled('Menus (vide : musique de la carte)', bgmPicker(st, 'menu_bgm')),
        labeled('Épreuves (vide : celle des menus)', bgmPicker(st, 'event_bgm')),
        labeled('Victoire (ME)', mePicker(st, 'win_me'))));
      row.appendChild(block('Jus de Noigrume', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Pas pour mixer', numInput(st, 'juice_steps', { min: 0, cls: 'tiny' })),
          labeled('Verres par mixage', numInput(st, 'juice_uses', { min: 1, max: 99, cls: 'tiny' })),
          labeled('Noigrumes dans le mixeur', numInput(st, 'juice_apricorns', { min: 1, max: 10, cls: 'tiny' }))),
        labeled('Objet nécessaire (mixeur_noigrumes)', combo({ value: st.blender_item || '', items: L.items, allowEmpty: true, emptyLabel: '(aucun)', onPick: (v) => redo(() => { st.blender_item = v; }) })),
        check(st, 'juice_pc_reset', 'Le jus s’en va quand le Pokémon va au PC')));
      row.appendChild(block('Performances', null,
        labeled('Variation du jour (étoiles)', select(st, 'daily_range', [['0', 'aucune'], ['1', '± 1'], ['2', '± 2']], { onChange: () => { st.daily_range = int(st.daily_range); } })),
        check(st, 'nature_effect', 'La nature change les performances (+1 / −1)'),
        hint('La variation du jour dépend du Pokémon et change chaque jour (Pokéathlon du jour).')));
      return row;
    },
    renderCommands(S) {
      const id = (S.config.courses[0] && S.config.courses[0].id) || 'speed';
      return h('div', { class: 'mtgrid' }, commands([
        ['pokeathlon', 'ouvre le Pokéathlon (choix de la coupe)'],
        [`pokeathlon('${id}')`, 'coupe imposée'],
        ['pokeathlon_resultat', 'dernier résultat : { course:, rank:, points: } (nil si abandon)'],
        ['pokeathlon_gagne?', 'condition : la dernière coupe est gagnée'],
        [`pokeathlon_gagnees('${id}')`, 'nombre de victoires dans une coupe'],
        ['mixeur_noigrumes', 'ouvre le Mixeur à Noigrumes'],
        ['pokeathlon_jus_pret?', 'condition : un jus est prêt'],
        ['donnees_pokeathlon', 'Données du Pokéathlon (records, médailles)'],
        ['boutique_pokeathlon', 'boutique du jour (points Pokéathlon)'],
        ['points_pokeathlon', 'points du joueur'],
        ['ajouter_points_pokeathlon(100)', 'ajoute (ou retire) des points'],
      ]));
    },
  };
  // ===========================================================================
  // Level design > Mini-jeux > Cueillette Dodrio (dodrio.json)
  // ===========================================================================
  const DO_DEFAULTS = { players: 3, max_misses: 10, time: 0, difficulty: 2, start_speed: 0.9, speed_step: 0.12, max_speed: 3.2,
    require_dodrio: true, species: 'dodrio', bgm: '' };
  const DO_NAMES = [['Léa', 'Lea'], ['Tom', 'Tom'], ['Max', 'Max'], ['Zoé', 'Zoe'], ['Hugo', 'Hugo'], ['Inès', 'Ines']];
  const DO_PRIZES = [[30, 'oran_berry', 1], [60, 'sitrus_berry', 1], [100, 'lum_berry', 1], [150, 'leppa_berry', 3], [220, 'starf_berry', 1]];
  const dodrioPage = {
    title: 'Cueillette Dodrio',
    normalize(c) {
      c.klass = 'DodrioConfig';
      c.settings = Object.assign({}, DO_DEFAULTS, isObj(c.settings) ? c.settings : {});
      const st = c.settings;
      st.require_dodrio = st.require_dodrio !== false;
      st.players = String(int(st.players, 3));
      st.difficulty = String(int(st.difficulty, 2));
      const names = Array.isArray(st.npc_names) && st.npc_names.length ? st.npc_names : DO_NAMES;
      st.npc_names = names.map((n) => (Array.isArray(n) ? { fr: String(n[0] || ''), en: String(n[1] || n[0] || '') }
        : isObj(n) ? { fr: String(n.fr || ''), en: String(n.en || '') } : { fr: String(n), en: String(n) }));
      const prizes = Array.isArray(c.prizes) ? c.prizes : DO_PRIZES.map(([points, item, count]) => ({ points, item, count }));
      c.prizes = prizes.filter(isObj).map((p) => ({ points: int(p.points), item: String(p.item || ''), count: Math.max(1, int(p.count, 1)) }));
      return c;
    },
    serialize(c) {
      const st = c.settings;
      st.players = Math.min(3, Math.max(1, int(st.players, 3)));
      st.difficulty = Math.min(3, Math.max(1, int(st.difficulty, 2)));
      st.max_misses = Math.min(20, Math.max(1, int(st.max_misses, 10)));
      st.time = Math.max(0, int(st.time));
      ['start_speed', 'speed_step', 'max_speed'].forEach((k) => { st[k] = Math.max(0.1, Number(st[k]) || DO_DEFAULTS[k]); });
      st.npc_names = st.npc_names.filter((n) => n.fr || n.en).map((n) => [n.fr || n.en, n.en || n.fr]);
      c.prizes = c.prizes.filter((p) => p.item).sort((a, b) => a.points - b.points);
      return c;
    },
    problems(S) {
      const out = [];
      const items = new Set((S.ctx.items || []).map((x) => x.db));
      S.config.prizes.forEach((p, i) => { if (p.item && !items.has(p.item)) out.push(`Lot ${i + 1} : objet « ${p.item} » introuvable.`); });
      const sp = S.config.settings.species;
      if (S.config.settings.require_dodrio && sp && !(S.ctx.creatures || []).some((x) => x.db === sp)) out.push(`Pokémon demandé « ${sp} » introuvable.`);
      return out;
    },
    render(S) {
      const c = S.config;
      const st = c.settings;
      const content = h('div', { class: 'pjr-content' });
      const grid = h('div', { class: 'mtgrid' });
      grid.appendChild(block('Partie', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Dodrio sur le terrain', select(st, 'players', [['1', '1 · seul'], ['2', '2 · avec un voisin'], ['3', '3 · joueur au milieu']])),
          labeled('Adresse de l’ordinateur', select(st, 'difficulty', [['1', '1 · facile'], ['2', '2 · normale'], ['3', '3 · difficile']]))),
        h('div', { class: 'pjr-grid2' },
          labeled('Baies ratées avant la fin', numInput(st, 'max_misses', { min: 1, max: 20, cls: 'tiny' })),
          labeled('Durée (secondes)', numInput(st, 'time', { min: 0, cls: 'tiny' }), '0 : jusqu’aux ratés')),
        hint('Avec 2 ou 3 Dodrio, les voisins partagent une colonne avec le joueur et peuvent lui voler des baies.')));
      grid.appendChild(block('Vitesse des baies', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Au départ', numInput(st, 'start_speed', { min: 0.1, max: 6, step: 0.05, cls: 'tiny' }), 'pixels par image'),
          labeled('Toutes les 10 baies', numInput(st, 'speed_step', { min: 0, max: 2, step: 0.01, cls: 'tiny' }), 'vitesse ajoutée')),
        labeled('Vitesse maximale', numInput(st, 'max_speed', { min: 0.5, max: 8, step: 0.1, cls: 'tiny' })),
        hint('Petite baie : 1 point, moyenne : 2, grosse : 3 (elle tombe un peu plus vite).')));
      grid.appendChild(block('Accès et musique', null,
        check(st, 'require_dodrio', 'Il faut ce Pokémon dans l’équipe pour jouer'),
        labeled('Pokémon demandé', combo({ value: st.species || '', items: L.creatures, placeholder: 'dodrio', onPick: (v) => redo(() => { st.species = v; }) })),
        labeled('Musique (vide : celle de la carte)', bgmPicker(st, 'bgm'))));
      grid.appendChild(block('Noms des autres joueurs', h('button', { class: 'pjs-btn small', onclick: () => redo(() => { st.npc_names.push({ fr: '', en: '' }); }) }, 'Ajouter'),
        h('div', { class: 'pjr-table' }, ...st.npc_names.map((n, i) => h('div', { class: 'pjr-trow donames' }, langInputs(st.npc_names, i), rowButtons(st.npc_names, i)))),
        hint('Tirés au hasard pour les Dodrio de l’ordinateur.')));
      content.appendChild(grid);
      const rows = c.prizes.map((p, i) => h('div', { class: 'pjr-trow doprize' },
        numInput(p, 'points', { min: 0, cls: 'tiny' }),
        combo({ value: p.item, items: L.items, placeholder: 'Objet…', onPick: (v) => redo(() => { p.item = v; }) }),
        numInput(p, 'count', { min: 1, max: 99, cls: 'tiny' }), rowButtons(c.prizes, i)));
      content.appendChild(block('Lots', h('span', { class: 'pjr-actions' },
        h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.prizes.push({ points: (c.prizes.length ? c.prizes[c.prizes.length - 1].points : 0) + 50, item: '', count: 1 }); }) }, 'Ajouter'),
        h('button', { class: 'pjs-btn small', onclick: () => { if (confirm('Remettre les lots par défaut ?')) redo(() => { c.prizes = DO_PRIZES.map(([points, item, count]) => ({ points, item, count })); }); } }, 'Par défaut')),
        h('div', { class: 'pjr-table' }, h('div', { class: 'pjr-thead doprize' }, h('span', null, 'À partir de (points)'), h('span', null, 'Objet'), h('span', null, 'Nombre'), h('span', null, '')), ...rows),
        hint('Le joueur reçoit le lot du meilleur palier atteint.')));
      content.appendChild(h('div', { class: 'mtgrid' }, commands([
        ['cueillette_dodrio', 'lance le mini-jeu (renvoie les points)'],
        ['cueillette_dodrio(1)', 'nombre de Dodrio sur le terrain (1 à 3)'],
        ['cueillette_dodrio_points', 'points de la dernière partie'],
        ['cueillette_dodrio_record', 'meilleur score'],
        ['cueillette_dodrio_parties', 'nombre de parties jouées'],
        ['dodrio_dans_equipe?', 'condition : un Dodrio est dans l’équipe'],
      ])));
      return content;
    },
  };
  // ===========================================================================
  // Level design > Mini-jeux > Lance-Ball (lance_ball.json)
  // ===========================================================================
  const LB_DEFAULTS = { time: 60, count: 6, difficulty: 2, party: false, catch_points: 100, time_points: 10, bgm: '' };
  const LB_POKEMON = ['pidove', 'patrat', 'lillipup', 'purrloin', 'pansage', 'pansear', 'panpour', 'munna', 'sewaddle', 'venipede', 'cottonee', 'petilil'];
  const LB_PRIZES = [[300, 'poke_ball', 5], [600, 'great_ball', 5], [900, 'ultra_ball', 3], [1200, 'quick_ball', 3]];
  const lanceBallPage = {
    title: 'Lance-Ball',
    normalize(c) {
      c.klass = 'LanceBallConfig';
      c.settings = Object.assign({}, LB_DEFAULTS, isObj(c.settings) ? c.settings : {});
      const st = c.settings;
      st.party = st.party === true;
      st.count = String(int(st.count, 6));
      st.difficulty = String(int(st.difficulty, 2));
      st.pokemon = (Array.isArray(st.pokemon) && st.pokemon.length ? st.pokemon : LB_POKEMON).map((s) => String(s));
      const prizes = Array.isArray(c.prizes) ? c.prizes : LB_PRIZES.map(([points, item, count]) => ({ points, item, count }));
      c.prizes = prizes.filter(isObj).map((p) => ({ points: int(p.points), item: String(p.item || ''), count: Math.max(1, int(p.count, 1)) }));
      return c;
    },
    serialize(c) {
      const st = c.settings;
      st.count = Math.min(6, Math.max(1, int(st.count, 6)));
      st.difficulty = Math.min(3, Math.max(1, int(st.difficulty, 2)));
      st.time = Math.min(600, Math.max(10, int(st.time, 60)));
      st.catch_points = Math.max(0, int(st.catch_points, 100));
      st.time_points = Math.max(0, int(st.time_points, 10));
      st.pokemon = st.pokemon.filter(Boolean);
      c.prizes = c.prizes.filter((p) => p.item).sort((a, b) => a.points - b.points);
      return c;
    },
    problems(S) {
      const out = [];
      const items = new Set((S.ctx.items || []).map((x) => x.db));
      const known = new Set((S.ctx.creatures || []).map((x) => x.db));
      S.config.prizes.forEach((p, i) => { if (p.item && !items.has(p.item)) out.push(`Lot ${i + 1} : objet « ${p.item} » introuvable.`); });
      S.config.settings.pokemon.forEach((s) => { if (s && !known.has(s)) out.push(`Pokémon « ${s} » introuvable.`); });
      return out;
    },
    render(S) {
      const c = S.config;
      const st = c.settings;
      const content = h('div', { class: 'pjr-content' });
      const grid = h('div', { class: 'mtgrid' });
      grid.appendChild(block('Partie', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Durée (secondes)', numInput(st, 'time', { min: 10, max: 600, cls: 'tiny' })),
          labeled('Pokémon à capturer', select(st, 'count', [1, 2, 3, 4, 5, 6].map((n) => [String(n), String(n)])))),
        labeled('Difficulté', select(st, 'difficulty', [['1', '1 · Pokémon lents et confiants'], ['2', '2 · normale'], ['3', '3 · rapides et méfiants']])),
        hint('Trois captures de suite donnent une balle dorée : points doublés et zone de capture plus large.')));
      grid.appendChild(block('Points', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Par capture', numInput(st, 'catch_points', { min: 0, cls: 'tiny' })),
          labeled('Par seconde restante', numInput(st, 'time_points', { min: 0, cls: 'tiny' }), 'si tout est capturé')),
        labeled('Musique (vide : celle de la carte)', bgmPicker(st, 'bgm'))));
      const mons = h('div', { class: 'pjr-table' }, ...st.pokemon.map((sp, i) => h('div', { class: 'pjr-trow lbmon' },
        combo({ value: sp, items: L.creatures, placeholder: 'Pokémon…', onPick: (v) => redo(() => { st.pokemon[i] = v; }) }), rowButtons(st.pokemon, i))));
      grid.appendChild(block('Pokémon cachés', h('span', { class: 'pjr-actions' },
        h('button', { class: 'pjs-btn small', onclick: () => redo(() => { st.pokemon.push(''); }) }, 'Ajouter'),
        h('button', { class: 'pjs-btn small', onclick: () => { if (confirm('Remettre les Pokémon de Noir / Blanc ?')) redo(() => { st.pokemon = LB_POKEMON.slice(); }); } }, 'Par défaut')),
        check(st, 'party', 'Cacher plutôt les Pokémon de l’équipe du joueur (comme le Poké Transfert)'),
        st.party ? hint('La liste sert si l’équipe est vide.') : null, mons,
        hint('Tirés au hasard à chaque partie. Il faut leur sprite de déplacement (graphics/characters).')));
      content.appendChild(grid);
      const rows = c.prizes.map((p, i) => h('div', { class: 'pjr-trow doprize' },
        numInput(p, 'points', { min: 0, cls: 'tiny' }),
        combo({ value: p.item, items: L.items, placeholder: 'Objet…', onPick: (v) => redo(() => { p.item = v; }) }),
        numInput(p, 'count', { min: 1, max: 99, cls: 'tiny' }), rowButtons(c.prizes, i)));
      content.appendChild(block('Lots', h('span', { class: 'pjr-actions' },
        h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.prizes.push({ points: (c.prizes.length ? c.prizes[c.prizes.length - 1].points : 0) + 300, item: '', count: 1 }); }) }, 'Ajouter'),
        h('button', { class: 'pjs-btn small', onclick: () => { if (confirm('Remettre les lots par défaut ?')) redo(() => { c.prizes = LB_PRIZES.map(([points, item, count]) => ({ points, item, count })); }); } }, 'Par défaut')),
        h('div', { class: 'pjr-table' }, h('div', { class: 'pjr-thead doprize' }, h('span', null, 'À partir de (points)'), h('span', null, 'Objet'), h('span', null, 'Nombre'), h('span', null, '')), ...rows),
        hint('Le joueur reçoit le lot du meilleur palier atteint.')));
      content.appendChild(h('div', { class: 'mtgrid' }, commands([
        ['lance_ball', 'lance le mini-jeu (renvoie les points)'],
        ['lance_ball(3)', 'nombre de Pokémon à capturer (1 à 6)'],
        ['lance_ball_points', 'points de la dernière partie'],
        ['lance_ball_record', 'meilleur score'],
        ['lance_ball_parties', 'nombre de parties jouées'],
        ['lance_ball_captures', 'total des Pokémon capturés'],
      ])));
      return content;
    },
  };

  // ===========================================================================
  // Level design > Zones > Pokémon visibles (overworld_pokemon.json)
  // ===========================================================================
  const OW_DEFAULTS = {
    enabled: true, disable_switch: 0, max_per_map: 5, tiles_per_pokemon: 350, min_distance: 5, notice_distance: 4,
    wander_rate: 70, flee_rate: 15, charge_rate: 15, move_speed: 3, move_frequency: 3, cry: true, level_variation: 2,
    shiny_se: 'audio/se/se_shiny', shiny_persist: true, shiny_rate: 0,
    monarch_rate: 1, monarch_level_bonus: 10, monarch_perfect_ivs: 4, monarch_exp_percent: 175, monarch_icon: '', monarch_se: '', monarch_boost: 'random', monarch_boost_stages: 1, monarch_battle_icon: 'rang_monarque', monarch_glow: true,
    baron_rate: 4, baron_level_bonus: 8, baron_perfect_ivs: 3, baron_exp_percent: 150, baron_icon: '', baron_se: '', baron_boost: 'random', baron_boost_stages: 1,
    battle_icon: true, battle_icon_x: 2, battle_icon_y: 0, battle_icon_zoom: 75, baron_battle_icon: 'rang_baron', dominant_battle_icon: 'rang_dominant',
    dominant_rate: 2, dominant_level_bonus: 3, dominant_boost: 'random', dominant_boost_stages: 1, dominant_exp_percent: 150, dominant_icon: '', dominant_se: '',
    outbreak_chance: 3, outbreak_count: 8, outbreak_radius: 4, outbreak_shiny_rate: 100, outbreak_baron_rate: 10, outbreak_se: '', excluded_maps: [], excluded_species: [], tag_aliases: {},
  };
  const owNormalize = (c) => {
    c.klass = 'OverworldPokemonConfig';
    c.settings = Object.assign(clone(OW_DEFAULTS), isObj(c.settings) ? c.settings : {});
    const st = c.settings;
    st.enabled = st.enabled !== false;
    st.cry = st.cry !== false;
    st.shiny_persist = st.shiny_persist !== false;
    st.battle_icon = st.battle_icon !== false;
    st.monarch_glow = st.monarch_glow !== false;
    st.excluded_maps = (Array.isArray(st.excluded_maps) ? st.excluded_maps : []).map((m) => int(m, -1));
    st.excluded_species = (Array.isArray(st.excluded_species) ? st.excluded_species : []).map((x) => String(x));
    if (!isObj(st.tag_aliases)) st.tag_aliases = {};
    return c;
  };
  const owSerialize = (c) => {
    const st = c.settings;
    const clampInt = (k, lo, hi, d) => { st[k] = Math.min(hi, Math.max(lo, int(st[k], d))); };
    clampInt('max_per_map', 0, 40, 5); clampInt('tiles_per_pokemon', 1, 100000, 350); clampInt('min_distance', 0, 40, 5);
    clampInt('notice_distance', 0, 20, 4); clampInt('move_speed', 1, 6, 3); clampInt('move_frequency', 1, 5, 3);
    clampInt('level_variation', 0, 20, 2); clampInt('shiny_rate', 0, 1000000, 0); clampInt('disable_switch', 0, 99999, 0);
    ['wander_rate', 'flee_rate', 'charge_rate', 'monarch_rate', 'baron_rate', 'dominant_rate', 'outbreak_chance', 'outbreak_baron_rate'].forEach((k) => clampInt(k, 0, 100, 0));
    clampInt('monarch_level_bonus', 0, 99, 10); clampInt('monarch_perfect_ivs', 0, 6, 4); clampInt('monarch_exp_percent', 0, 1000, 175); clampInt('monarch_boost_stages', 0, 6, 1);
    clampInt('baron_level_bonus', 0, 99, 8); clampInt('baron_perfect_ivs', 0, 6, 3); clampInt('baron_exp_percent', 0, 1000, 150);
    clampInt('dominant_level_bonus', 0, 99, 3); clampInt('dominant_boost_stages', 0, 6, 1); clampInt('dominant_exp_percent', 0, 1000, 150);
    clampInt('baron_boost_stages', 0, 6, 1); clampInt('battle_icon_x', -200, 400, 2); clampInt('battle_icon_y', -200, 400, 0); clampInt('battle_icon_zoom', 10, 400, 75);
    clampInt('outbreak_count', 0, 40, 8); clampInt('outbreak_radius', 1, 20, 4); clampInt('outbreak_shiny_rate', 0, 1000000, 100);
    ['baron_boost', 'dominant_boost', 'monarch_boost'].forEach((k) => { if (!['none', 'random', 'atk', 'dfe', 'spd', 'ats', 'dfs'].includes(st[k])) st[k] = 'random'; });
    ['baron_icon', 'dominant_icon', 'monarch_icon', 'baron_se', 'dominant_se', 'monarch_se', 'outbreak_se', 'baron_battle_icon', 'dominant_battle_icon', 'monarch_battle_icon'].forEach((k) => { st[k] = String(st[k] || '').trim(); });
    st.excluded_maps = [...new Set(st.excluded_maps.filter((m) => m >= 0))];
    st.excluded_species = [...new Set(st.excluded_species.filter(Boolean))];
    return c;
  };
  const OW_STATS = [['random', 'Au hasard'], ['none', 'Aucune'], ['atk', 'Attaque'], ['dfe', 'Défense'], ['spd', 'Vitesse'], ['ats', 'Attaque Spé.'], ['dfs', 'Défense Spé.']];
  const owSub = (text) => h('div', { class: 'pjr-sub' }, text);
  const owTabs = (ui, tabs) => h('div', { class: 'pjr-actions pjr-tabs' }, tabs.map(([id, lab]) =>
    h('button', { class: 'pjs-btn small' + (ui.tab === id ? ' primary' : ''), onclick: () => redo(() => { ui.tab = id; }) }, lab)));
  const owSummary = (text) => h('div', { class: 'pjr-summary' }, text);

  // Level design > Zones > Pokémon visibles (onglets : apparition, comportement, chromatiques, exclusions, commandes)
  const overworldPage = {
    title: 'Pokémon visibles',
    normalize: owNormalize,
    serialize: owSerialize,
    problems(S) {
      const out = [];
      const known = new Set((S.ctx.creatures || []).map((x) => x.db));
      const maps = new Set((S.ctx.maps || []).map((m) => int(m.id)));
      const st = S.config.settings;
      st.excluded_species.forEach((sp) => { if (sp && !known.has(sp)) out.push(`Pokémon « ${sp} » introuvable.`); });
      if (maps.size) st.excluded_maps.forEach((m) => { if (m >= 0 && !maps.has(m)) out.push(`Carte n° ${m} introuvable.`); });
      if (st.wander_rate + st.flee_rate + st.charge_rate <= 0) out.push('Les trois tempéraments ont un poids de 0 : tous les Pokémon se promèneront.');
      return out;
    },
    render(S) {
      const st = S.config.settings;
      S.ui.ow = S.ui.ow || { tab: 'spawn' };
      const ui = S.ui.ow;
      const content = h('div', { class: 'pjr-content' });
      const tabs = [['spawn', 'Apparition'], ['behavior', 'Comportement'], ['shiny', 'Chromatiques et massives'], ['excl', `Exclusions (${st.excluded_maps.length + st.excluded_species.length})`], ['commands', 'Commandes']];
      content.appendChild(owTabs(ui, tabs));
      const page = h('div', { class: 'pjr-two' });
      if (ui.tab === 'behavior') {
        const total = () => st.wander_rate + st.flee_rate + st.charge_rate;
        const pct = h('div', { class: 'pjr-summary' });
        const showPct = () => { const t = total(); pct.textContent = t > 0 ? `${Math.round(100 * st.wander_rate / t)} % se promènent · ${Math.round(100 * st.flee_rate / t)} % fuient · ${Math.round(100 * st.charge_rate / t)} % foncent sur le joueur` : 'Poids nuls : tous se promènent.'; };
        showPct();
        page.appendChild(block('Tempéraments', null,
          pct,
          h('div', { class: 'pjr-grid3' },
            labeled('Se promène', numInput(st, 'wander_rate', { min: 0, max: 100, cls: 'tiny', onChange: showPct })),
            labeled('Fuit', numInput(st, 'flee_rate', { min: 0, max: 100, cls: 'tiny', onChange: showPct })),
            labeled('Fonce', numInput(st, 'charge_rate', { min: 0, max: 100, cls: 'tiny', onChange: showPct }))),
          hint('Poids relatifs, pas des pourcentages exacts. Le contact lance le combat. Un Pokémon qui fuit s’éloigne ; un Pokémon qui fonce déclenche le combat dès qu’il arrive au contact.')));
        page.appendChild(block('Réactions et déplacements', null,
          labeled('Distance à laquelle il remarque le joueur (tuiles)', numInput(st, 'notice_distance', { min: 0, max: 20, cls: 'tiny' })),
          check(st, 'cry', 'Le Pokémon crie quand il remarque le joueur'),
          owSub('Déplacements'),
          h('div', { class: 'pjr-grid2' },
            labeled('Vitesse (1 à 6)', numInput(st, 'move_speed', { min: 1, max: 6, cls: 'tiny' })),
            labeled('Fréquence (1 à 5)', numInput(st, 'move_frequency', { min: 1, max: 5, cls: 'tiny' }))),
          hint('Le sprite est celui du Pokémon suiveur (graphics/characters : 0025.png, 0025s.png chromatique…).')));
      } else if (ui.tab === 'shiny') {
        page.appendChild(block('Chromatiques', null,
          labeled('Son à l’apparition', soundPicker(st, 'shiny_se')),
          check(st, 'shiny_persist', 'Un chromatique reste sur sa carte (et dans la sauvegarde) tant qu’on ne l’a pas affronté'),
          labeled('Chance de chromatique : 1 sur…', numInput(st, 'shiny_rate', { min: 0, cls: 'tiny' }), '0 : la chance normale du jeu'),
          hint('Un chromatique disparaît dès que le combat commence, capturé ou non (fuite, K.O., etc.). Les autres Pokémon disparaissent quand on quitte la carte.')));
        page.appendChild(block('Apparitions massives', null,
          h('div', { class: 'pjr-grid2' },
            labeled('Chance à l’arrivée sur une carte (%)', numInput(st, 'outbreak_chance', { min: 0, max: 100, cls: 'tiny' }), '0 : jamais'),
            labeled('Pokémon rassemblés', numInput(st, 'outbreak_count', { min: 0, max: 40, cls: 'tiny' }))),
          h('div', { class: 'pjr-grid2' },
            labeled('Rayon (tuiles)', numInput(st, 'outbreak_radius', { min: 1, max: 20, cls: 'tiny' })),
            labeled('Chromatique : 1 sur…', numInput(st, 'outbreak_shiny_rate', { min: 0, cls: 'tiny' }), '0 : la chance normale')),
          labeled('Barons parmi eux (%)', numInput(st, 'outbreak_baron_rate', { min: 0, max: 100, cls: 'tiny' })),
          labeled('Son à l’arrivée', soundPicker(st, 'outbreak_se')),
          hint('Un groupe d’une même espèce, tirée dans la zone, se rassemble autour d’une tuile, en plus des Pokémon habituels. Les Barons et les Dominants se règlent dans Gimmicks > Barons et Dominants.')));
      } else if (ui.tab === 'excl') {
        const maps = S.ctx.maps || [];
        const mapRows = st.excluded_maps.map((id, i) => h('div', { class: 'pjr-trow lbmon' },
          combo({ value: String(id), items: () => maps.map((m) => ({ value: String(m.id), label: m.name, sub: `n° ${m.id}` })), placeholder: 'Carte…', onPick: (v) => redo(() => { st.excluded_maps[i] = int(v, -1); }) }), rowButtons(st.excluded_maps, i)));
        const speciesRows = st.excluded_species.map((sp, i) => h('div', { class: 'pjr-trow lbmon' },
          combo({ value: sp, items: L.creatures, placeholder: 'Pokémon…', onPick: (v) => redo(() => { st.excluded_species[i] = v; }) }), rowButtons(st.excluded_species, i)));
        const empty = (t) => h('div', { class: 'pjr-empty' }, t);
        page.appendChild(block(`Cartes sans Pokémon visibles (${st.excluded_maps.length})`, h('span', { class: 'pjr-actions' }, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { st.excluded_maps.push(-1); }) }, 'Ajouter')),
          mapRows.length ? h('div', { class: 'pjr-table' }, ...mapRows) : empty('Aucune carte exclue.'), hint('Villes, intérieurs… : aucun Pokémon ne s’y promène.')));
        page.appendChild(block(`Pokémon jamais visibles (${st.excluded_species.length})`, h('span', { class: 'pjr-actions' }, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { st.excluded_species.push(''); }) }, 'Ajouter')),
          speciesRows.length ? h('div', { class: 'pjr-table' }, ...speciesRows) : empty('Aucune espèce exclue.'), hint('Ils restent possibles dans l’herbe, comme avant.')));
      } else if (ui.tab === 'commands') {
        page.appendChild(commands([
          ['pokemon_visibles(false)', 'coupe les Pokémon visibles à partir de la prochaine carte (true : les remet)'],
          ['effacer_pokemon_visibles', 'retire tous les Pokémon visibles de la carte en cours'],
          ['nombre_pokemon_visibles', 'nombre de Pokémon visibles sur la carte'],
          ['apparition_massive(:pikachu, 12)', 'rassemble 12 Pikachu sur la carte (sans argument : espèce tirée dans la zone)'],
          ['combat_baron(:pikachu, 30)', 'combat contre un Pikachu Baron de niveau 30 (+ bonus)'],
          ['combat_dominant(:raichu, 30)', 'combat contre un Raichu Dominant'],
        ]));
      } else {
        const perMap = Math.min(st.max_per_map, Math.max(1, Math.floor(10000 / Math.max(1, st.tiles_per_pokemon))));
        page.appendChild(block('Apparition', null,
          owSummary(st.enabled ? `Une carte de 100 x 100 affiche environ ${perMap} Pokémon (au plus ${st.max_per_map}).` : 'Les Pokémon visibles sont coupés.'),
          check(st, 'enabled', 'Des Pokémon sauvages sont visibles sur les cartes'),
          h('div', { class: 'pjr-grid2' },
            labeled('Maximum par carte', numInput(st, 'max_per_map', { min: 0, max: 40, cls: 'tiny' })),
            labeled('Une tuile sur…', numInput(st, 'tiles_per_pokemon', { min: 1, cls: 'tiny' }), 'plus la valeur est basse, plus il y en a')),
          h('div', { class: 'pjr-grid2' },
            labeled('Distance minimale au joueur (tuiles)', numInput(st, 'min_distance', { min: 0, max: 40, cls: 'tiny' })),
            labeled('Interrupteur qui coupe l’apparition', numInput(st, 'disable_switch', { min: 0, cls: 'tiny' }), '0 : aucun'))));
        page.appendChild(block('Choix des Pokémon', null,
          labeled('Variation de niveau (+/-)', numInput(st, 'level_variation', { min: 0, max: 20, cls: 'tiny' })),
          hint('Les Pokémon sont tirés dans les groupes sauvages de la zone (herbes, sol…), pas dans ceux de l’eau ni de la pêche. L’heure, la météo et les conditions du groupe sont respectées. Ils changent à chaque arrivée sur la carte.')));
      }
      content.appendChild(page);
      return content;
    },
  };

  // Données > Gimmicks > Barons et Dominants (même fichier : overworld_pokemon.json)
  const rangsPage = {
    title: 'Barons, Monarques et Dominants',
    normalize: owNormalize,
    serialize: owSerialize,
    problems(S) {
      const st = S.config.settings;
      const out = [];
      if (st.monarch_rate + st.baron_rate + st.dominant_rate > 100) out.push('Monarque + Baron + Dominant dépassent 100 % : le Monarque est tiré en premier, puis le Baron.');
      if (!st.enabled) out.push('Les Pokémon visibles sont coupés (Zones > Pokémon visibles) : aucun Baron ni Dominant n’apparaîtra sur la carte.');
      return out;
    },
    render(S) {
      const st = S.config.settings;
      const content = h('div', { class: 'pjr-content' });
      content.appendChild(owSummary(`Monarque : ${st.monarch_rate} % · +${st.monarch_level_bonus} niveaux · ${st.monarch_perfect_ivs} IV parfaits.   Baron : ${st.baron_rate} % · +${st.baron_level_bonus} niveaux · ${st.baron_perfect_ivs} IV parfaits.   Dominant : ${st.dominant_rate} % · +${st.dominant_level_bonus} niveaux.   Apparitions massives : ${st.outbreak_baron_rate} % de Barons.`));
      const page = h('div', { class: 'pjr-two' });
      page.appendChild(block('Pokémon Barons (Légendes Arceus)', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Chance d’être Baron (%)', numInput(st, 'baron_rate', { min: 0, max: 100, cls: 'tiny' }), '0 : aucun Baron'),
          labeled('Niveaux en plus', numInput(st, 'baron_level_bonus', { min: 0, max: 99, cls: 'tiny' }))),
        h('div', { class: 'pjr-grid2' },
          labeled('Statistiques aux IV parfaits (0 à 6)', numInput(st, 'baron_perfect_ivs', { min: 0, max: 6, cls: 'tiny' })),
          labeled('Expérience gagnée (%)', numInput(st, 'baron_exp_percent', { min: 0, max: 1000, cls: 'tiny' }), '150 : une fois et demie')),
        owSub('Passif caché (à l’entrée au combat, aussi une fois capturé)'),
        h('div', { class: 'pjr-grid2' },
          labeled('Statistique', select(st, 'baron_boost', OW_STATS)),
          labeled('Crans gagnés', numInput(st, 'baron_boost_stages', { min: 0, max: 6, cls: 'tiny' }))),
        owSub('Apparence'),
        labeled('Marque en combat et dans le résumé', textInput(st, 'baron_battle_icon', { placeholder: 'rang_baron' }), 'graphics/interface : image de 16 px'),
        labeled('Icône sur la carte (facultatif)', textInput(st, 'baron_icon', { placeholder: 'vide : sprite normal' }), 'vide : sprite normal ; sinon graphics/characters (4 x 4 cases de 32 px)'),
        labeled('Son à l’apparition', soundPicker(st, 'baron_se')),
        hint('Face à un Baron sauvage, le jeu annonce « Pokémon Baron ». Le rang et le passif caché restent sur le Pokémon une fois capturé.')));
      page.appendChild(block('Pokémon Monarques (Légendes Arceus)', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Chance d’être Monarque (%)', numInput(st, 'monarch_rate', { min: 0, max: 100, cls: 'tiny' }), '0 : aucun Monarque ; tiré avant le Baron'),
          labeled('Niveaux en plus', numInput(st, 'monarch_level_bonus', { min: 0, max: 99, cls: 'tiny' }))),
        h('div', { class: 'pjr-grid2' },
          labeled('Statistiques aux IV parfaits (0 à 6)', numInput(st, 'monarch_perfect_ivs', { min: 0, max: 6, cls: 'tiny' })),
          labeled('Expérience gagnée (%)', numInput(st, 'monarch_exp_percent', { min: 0, max: 1000, cls: 'tiny' }), '175 : une fois trois quarts')),
        owSub('Passif caché (à l’entrée au combat, aussi une fois capturé)'),
        h('div', { class: 'pjr-grid2' },
          labeled('Statistique', select(st, 'monarch_boost', OW_STATS)),
          labeled('Crans gagnés', numInput(st, 'monarch_boost_stages', { min: 0, max: 6, cls: 'tiny' }))),
        owSub('Apparence'),
        check(st, 'monarch_glow', 'Lueur dorée autour du Monarque en combat'),
        labeled('Marque en combat et dans le résumé', textInput(st, 'monarch_battle_icon', { placeholder: 'rang_monarque' }), 'graphics/interface : image de 16 px'),
        labeled('Icône sur la carte (facultatif)', textInput(st, 'monarch_icon', { placeholder: 'vide : sprite normal' }), 'vide : sprite normal'),
        labeled('Son à l’apparition', soundPicker(st, 'monarch_se')),
        hint('Un Monarque est un Baron plus rare et un peu plus fort. Face à lui, le jeu annonce « Pokémon Monarque ». Le rang et le passif caché restent une fois capturé.')));
      page.appendChild(block('Pokémon Dominants (Soleil / Lune)', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Chance d’être Dominant (%)', numInput(st, 'dominant_rate', { min: 0, max: 100, cls: 'tiny' }), '0 : aucun Dominant'),
          labeled('Niveaux en plus', numInput(st, 'dominant_level_bonus', { min: 0, max: 99, cls: 'tiny' }))),
        h('div', { class: 'pjr-grid2' },
          h('div'),
          labeled('Expérience gagnée (%)', numInput(st, 'dominant_exp_percent', { min: 0, max: 1000, cls: 'tiny' }), '150 : une fois et demie')),
        owSub('Aura (passif caché à l’entrée au combat, aussi une fois capturé)'),
        h('div', { class: 'pjr-grid2' },
          labeled('Statistique', select(st, 'dominant_boost', OW_STATS)),
          labeled('Crans gagnés', numInput(st, 'dominant_boost_stages', { min: 0, max: 6, cls: 'tiny' }))),
        owSub('Apparence'),
        labeled('Marque en combat et dans le résumé', textInput(st, 'dominant_battle_icon', { placeholder: 'rang_dominant' }), 'graphics/interface : image de 16 px'),
        labeled('Icône sur la carte (facultatif)', textInput(st, 'dominant_icon', { placeholder: 'vide : sprite normal' }), 'ex. ow_dominant'),
        labeled('Son à l’apparition', soundPicker(st, 'dominant_se')),
        hint('Même marque que le Baron, en blanc. Un Pokémon est Baron en priorité s’il tombe sur les deux.')));
      page.appendChild(block('Marque en combat', null,
          check(st, 'battle_icon', 'Afficher la marque à côté de la barre de vie des Monarques, des Barons et des Dominants'),
          h('div', { class: 'pjr-grid3' },
            labeled('Décalage horizontal', numInput(st, 'battle_icon_x', { min: -200, max: 400, cls: 'tiny' }), 'px'),
            labeled('Décalage vertical', numInput(st, 'battle_icon_y', { min: -200, max: 400, cls: 'tiny' }), 'px'),
            labeled('Taille', numInput(st, 'battle_icon_zoom', { min: 10, max: 400, cls: 'tiny' }), '% (75 : 12 px)')),
          hint('La marque se place à droite de la barre de vie ; le décalage part de là (négatif : vers la gauche / le haut). Dans le résumé, elle suit la marque chromatique.')));
      content.appendChild(page);
      content.appendChild(h('div', { class: 'pjr-two' },
        commands([
          ['combat_baron(:pikachu, 30)', 'combat contre un Pikachu Baron de niveau 30 (+ bonus)'],
          ['combat_monarque(:pikachu, 30)', 'combat contre un Pikachu Monarque'],
          ['combat_dominant(:raichu, 30)', 'combat contre un Raichu Dominant'],
          ['apparition_massive(:pikachu, 12)', 'rassemble 12 Pikachu sur la carte'],
        ])));
      return content;
    },
  };

  // ===========================================================================
  // Données > Gimmicks > Modes de jeu (modes_jeu.json) : Difficile, Extrême, Nuzlocke, Randomizer
  // ===========================================================================
  const MJ_DEFAULTS = {
    level_caps: [14, 19, 24, 29, 34, 39, 44, 49, 100], cap_block_exp: true, trainer_bonus: 2, extreme_trainer_bonus: 2, extreme_block_wild: false,
    nuzlocke_first_encounter: true, nuzlocke_shiny_clause: true, nuzlocke_dupes_clause: true, nuzlocke_nickname: true, nuzlocke_permadeath: true,
    nuzlocke_wipe: 'revive_last', nuzlocke_revive_item: 'nuzlocke_revive', nuzlocke_nicknames: ['Ombre', 'Cendre', 'Rune', 'Brume', 'Écho', 'Glas'],
    randomizer_wild: true, randomizer_trainers: true, randomizer_gifts: true, randomizer_exclude: [], seed: 0, lock_choice: true,
    overkill_enabled: true, overkill_threshold: 50, overkill_exp_percent: 25, overkill_loyalty: 1, overkill_message: true,
  };
  const modesJeuPage = {
    title: 'Modes de jeu',
    normalize(c) {
      c.klass = 'ModesJeuConfig';
      c.settings = Object.assign(clone(MJ_DEFAULTS), isObj(c.settings) ? c.settings : {});
      const st = c.settings;
      ['cap_block_exp', 'nuzlocke_first_encounter', 'nuzlocke_shiny_clause', 'nuzlocke_dupes_clause', 'nuzlocke_nickname', 'nuzlocke_permadeath', 'randomizer_wild', 'randomizer_trainers', 'randomizer_gifts', 'lock_choice', 'overkill_enabled', 'overkill_message']
        .forEach((k) => { st[k] = st[k] !== false; });
      st.extreme_block_wild = st.extreme_block_wild === true;
      st.caps = (Array.isArray(st.level_caps) && st.level_caps.length ? st.level_caps : MJ_DEFAULTS.level_caps).map((n) => ({ level: int(n, 100) }));
      st.nicks = (Array.isArray(st.nuzlocke_nicknames) ? st.nuzlocke_nicknames : []).map((n) => ({ name: String(n) }));
      st.randomizer_exclude = (Array.isArray(st.randomizer_exclude) ? st.randomizer_exclude : []).map((x) => String(x));
      return c;
    },
    serialize(c) {
      const st = c.settings;
      st.level_caps = st.caps.map((x) => Math.min(100, Math.max(1, int(x.level, 100))));
      if (!st.level_caps.length) st.level_caps = MJ_DEFAULTS.level_caps.slice();
      st.nuzlocke_nicknames = st.nicks.map((x) => String(x.name || '').trim()).filter(Boolean);
      delete st.caps; delete st.nicks;
      st.trainer_bonus = Math.min(50, Math.max(0, int(st.trainer_bonus, 2)));
      st.extreme_trainer_bonus = Math.min(50, Math.max(0, int(st.extreme_trainer_bonus, 2)));
      st.overkill_threshold = Math.min(1000, Math.max(1, int(st.overkill_threshold, 50)));
      st.overkill_exp_percent = Math.min(1000, Math.max(0, int(st.overkill_exp_percent, 25)));
      st.overkill_loyalty = Math.min(255, Math.max(0, int(st.overkill_loyalty, 1)));
      st.seed = Math.min(2000000000, Math.max(0, int(st.seed, 0)));
      if (!['revive_last', 'none'].includes(st.nuzlocke_wipe)) st.nuzlocke_wipe = 'revive_last';
      st.nuzlocke_revive_item = String(st.nuzlocke_revive_item || '').trim();
      st.randomizer_exclude = [...new Set(st.randomizer_exclude.filter(Boolean))];
      return c;
    },
    problems(S) {
      const out = [];
      const known = new Set((S.ctx.creatures || []).map((x) => x.db));
      S.config.settings.randomizer_exclude.forEach((sp) => { if (sp && !known.has(sp)) out.push(`Pokémon « ${sp} » introuvable.`); });
      const caps = S.config.settings.caps.map((x) => int(x.level, 100));
      for (let i = 1; i < caps.length; i++) if (caps[i] < caps[i - 1]) out.push(`Plafond du palier ${i + 1} inférieur au précédent.`);
      return out;
    },
    render(S) {
      const st = S.config.settings;
      S.ui.mj = S.ui.mj || { tab: 'hard' };
      const ui = S.ui.mj;
      const content = h('div', { class: 'pjr-content' });
      const tabs = [['hard', 'Difficile / Extrême'], ['over', 'Overkill'], ['nuz', 'Nuzlocke'], ['rand', 'Randomizer'], ['commands', 'Commandes']];
      content.appendChild(h('div', { class: 'pjr-actions pjr-tabs' }, ...tabs.map(([key, label]) =>
        h('button', { class: 'pjs-btn small' + (ui.tab === key ? ' active' : ''), onclick: () => redo(() => { ui.tab = key; }) }, label))));
      const grid = h('div', { class: 'mtgrid' });
      if (ui.tab === 'hard') {
        const rows = st.caps.map((x, i) => h('div', { class: 'pjr-trow' },
          h('span', null, i === 0 ? 'Aucun badge' : `${i} badge${i > 1 ? 's' : ''}${i === st.caps.length - 1 ? ' et plus' : ''}`),
          numInput(x, 'level', { min: 1, max: 100, cls: 'tiny' }), rowButtons(st.caps, i)));
        grid.appendChild(block('Plafond de niveau selon les badges', h('span', { class: 'pjr-actions' },
          h('button', { class: 'pjs-btn small', onclick: () => redo(() => { st.caps.push({ level: Math.min(100, (st.caps.length ? st.caps[st.caps.length - 1].level : 10) + 5) }); }) }, 'Ajouter'),
          h('button', { class: 'pjs-btn small', onclick: () => { if (confirm('Remettre les plafonds par défaut ?')) redo(() => { st.caps = MJ_DEFAULTS.level_caps.map((n) => ({ level: n })); }); } }, 'Par défaut')),
          h('div', { class: 'pjr-table' }, ...rows),
          check(st, 'cap_block_exp', 'Un Pokémon au plafond ne gagne plus d’expérience (et ne peut pas le dépasser)'),
          hint('Seuls les modes Difficile et Extrême ont un plafond. Il s’affiche dans l’Étui à badges. Le dernier palier vaut pour les badges suivants.')));
        grid.appendChild(block('Dresseurs et combats', null,
          h('div', { class: 'pjr-grid2' },
            labeled('Niveaux en plus (Difficile)', numInput(st, 'trainer_bonus', { min: 0, max: 50, cls: 'tiny' })),
            labeled('Niveaux en plus (Extrême, en plus)', numInput(st, 'extreme_trainer_bonus', { min: 0, max: 50, cls: 'tiny' }))),
          check(st, 'extreme_block_wild', 'Extrême : objets aussi interdits dans les combats sauvages (Poké Balls comprises)'),
          check(st, 'lock_choice', 'Les modes ne peuvent plus être changés une fois choisis'),
          hint('Difficile force aussi le style de combat « Set » (pas de changement offert après un K.O.). Extrême = Difficile + aucun objet du sac contre les dresseurs.')));
      } else if (ui.tab === 'over') {
        grid.appendChild(block('Bonus d’overkill', null,
          check(st, 'overkill_enabled', 'Activer le bonus (tous les modes, coups du joueur seulement)'),
          check(st, 'overkill_message', 'Afficher « Overkill ! » en combat'),
          h('div', { class: 'pjr-grid2' },
            labeled('Excédent requis (% des PV max de la cible)', numInput(st, 'overkill_threshold', { min: 1, max: 1000, cls: 'tiny' })),
            labeled('Expérience en plus (%)', numInput(st, 'overkill_exp_percent', { min: 0, max: 1000, cls: 'tiny' })),
            labeled('Bonheur en plus', numInput(st, 'overkill_loyalty', { min: 0, max: 255, cls: 'tiny' }))),
          hint('Un coup qui dépasse les PV restants d’au moins ce pourcentage des PV max de la cible rapporte le bonus d’expérience au Pokémon qui l’a porté.')));
      } else if (ui.tab === 'nuz') {
        grid.appendChild(block('Règles', null,
          check(st, 'nuzlocke_first_encounter', 'Seule la première rencontre de chaque zone peut être capturée'),
          check(st, 'nuzlocke_shiny_clause', 'Clause chromatique : un chromatique est toujours capturable'),
          check(st, 'nuzlocke_dupes_clause', 'Clause doublons : une espèce déjà obtenue ne compte pas comme rencontre'),
          check(st, 'nuzlocke_nickname', 'Surnom obligatoire à la capture'),
          check(st, 'nuzlocke_permadeath', 'Mort définitive : un Pokémon K.O. part au cimetière'),
          labeled('Si toute l’équipe tombe', select(st, 'nuzlocke_wipe', [['revive_last', 'Le dernier est ranimé (1 PV)'], ['none', 'Rien de spécial']]))));
        const nicks = h('div', { class: 'pjr-table' }, ...st.nicks.map((x, i) => h('div', { class: 'pjr-trow' }, textInput(x, 'name'), rowButtons(st.nicks, i))));
        grid.appendChild(block('Surnoms de secours', h('span', { class: 'pjr-actions' },
          h('button', { class: 'pjs-btn small', onclick: () => redo(() => { st.nicks.push({ name: '' }); }) }, 'Ajouter')),
          nicks, hint('Donnés au hasard si le joueur n’a pas choisi de surnom après plusieurs essais.'),
          labeled('Objet de résurrection (db_symbol)', textInput(st, 'nuzlocke_revive_item')),
          hint('L’objet « nuzlocke_revive » est un objet à évènement : crée dans RPG Maker un évènement commun avec la commande Script nuzlocke_ressusciter, puis mets son numéro dans l’objet (Données > Objets).')));
      } else if (ui.tab === 'rand') {
        grid.appendChild(block('Ce qui est mélangé', null,
          check(st, 'randomizer_gifts', 'Starters et Pokémon offerts par les évènements'),
          check(st, 'randomizer_wild', 'Rencontres sauvages'),
          check(st, 'randomizer_trainers', 'Équipes des dresseurs (niveaux conservés)'),
          labeled('Graine imposée (0 : au hasard au choix des modes)', numInput(st, 'seed', { min: 0, max: 2000000000, cls: 'tiny' })),
          hint('Talents et capacités ne sont pas touchés. Une même espèce donne toujours la même espèce de remplacement.')));
        const ex = h('div', { class: 'pjr-table' }, ...st.randomizer_exclude.map((sp, i) => h('div', { class: 'pjr-trow' },
          combo({ value: sp, items: L.creatures, placeholder: 'Pokémon…', onPick: (v) => redo(() => { st.randomizer_exclude[i] = v; }) }), rowButtons(st.randomizer_exclude, i))));
        grid.appendChild(block('Jamais tirés', h('span', { class: 'pjr-actions' },
          h('button', { class: 'pjs-btn small', onclick: () => redo(() => { st.randomizer_exclude.push(''); }) }, 'Ajouter')), ex));
      } else {
        grid.appendChild(commands([
          ['choisir_modes', 'menu de début de partie : difficulté, Nuzlocke, Randomizer'],
          ['mode_difficile?  mode_extreme?', 'true / false'],
          ['mode_nuzlocke?  mode_randomizer?', 'true / false'],
          ['plafond_niveau', 'plafond de niveau actuel (nil hors Difficile)'],
          ['resume_modes', 'texte des modes choisis'],
          ['ouvrir_cimetiere', 'liste des Pokémon tombés'],
          ['nuzlocke_ressusciter', 'choisir un Pokémon du cimetière et le ranimer'],
        ]));
      }
      content.appendChild(grid);
      return content;
    },
  };

  // ===========================================================================
  // Données > Interface > Base secrète (base_secrete.json)
  // ===========================================================================
  const BS_DEFAULT_THEMES = [
    { id: 'bois', name: { fr: 'Cabane en bois', en: 'Wooden hut' }, image: 'fond_bois' },
    { id: 'grotte', name: { fr: 'Grotte', en: 'Cave' }, image: 'fond_grotte' },
    { id: 'jardin', name: { fr: 'Jardin', en: 'Garden' }, image: 'fond_jardin' },
  ];
  const baseSecretePage = {
    title: 'Base secrète',
    normalize(c) {
      c.klass = 'BaseSecreteConfig';
      c.settings = Object.assign({ decor_prefix: 'deco_', trophies_achievements: true, trophies_contests: true, max_items: 0 }, isObj(c.settings) ? c.settings : {});
      c.settings.trophies_achievements = c.settings.trophies_achievements !== false;
      c.settings.trophies_contests = c.settings.trophies_contests !== false;
      const lang = (n) => ({ fr: String((isObj(n) && n.fr) || ''), en: String((isObj(n) && n.en) || '') });
      c.themes = (Array.isArray(c.themes) && c.themes.length ? c.themes : clone(BS_DEFAULT_THEMES)).filter(isObj)
        .map((t) => ({ id: String(t.id || ''), name: lang(t.name), image: String(t.image || '') }));
      c.decor = (Array.isArray(c.decor) ? c.decor : []).filter(isObj).map((d) => ({ item: String(d.item || ''), name: lang(d.name) }));
      return c;
    },
    serialize(c) {
      const st = c.settings;
      st.decor_prefix = String(st.decor_prefix || '').trim();
      st.max_items = Math.min(70, Math.max(0, int(st.max_items, 0)));
      c.themes = c.themes.filter((t) => t.id && t.image).map((t) => ({ id: t.id.trim(), name: t.name, image: t.image.trim() }));
      if (!c.themes.length) c.themes = clone(BS_DEFAULT_THEMES);
      c.decor = c.decor.filter((d) => d.item).map((d) => ({ item: d.item, name: d.name }));
      return c;
    },
    problems(S) {
      const out = [];
      const ids = new Set();
      S.config.themes.forEach((t) => {
        if (t.id && ids.has(t.id)) out.push(`Fond « ${t.id} » en double.`);
        ids.add(t.id);
        if (!t.id) out.push('Un fond n’a pas d’identifiant.');
        if (!t.image) out.push(`Le fond « ${t.id || '?'} » n’a pas d’image.`);
      });
      const items = new Set((S.ctx.items || []).map((x) => x.db));
      if (items.size) S.config.decor.forEach((d) => { if (d.item && !items.has(d.item)) out.push(`Objet « ${d.item} » introuvable.`); });
      return out;
    },
    render(S) {
      const c = S.config;
      const st = c.settings;
      const content = h('div', { class: 'pjr-content' });
      const grid = h('div', { class: 'mtgrid' });
      grid.appendChild(block('Réglages', null,
        h('div', { class: 'pjr-grid2' },
          labeled('Préfixe des objets décoratifs', textInput(st, 'decor_prefix', { placeholder: 'deco_' }), 'Tout objet dont le db_symbol commence ainsi peut être posé.'),
          labeled('Objets posés au plus (0 : sans limite)', numInput(st, 'max_items', { min: 0, max: 70, cls: 'tiny' }))),
        check(st, 'trophies_achievements', 'Un trophée par Succès obtenu'),
        check(st, 'trophies_contests', 'Un trophée par Concours remporté par le joueur'),
        hint('La pièce est une grille de 10 × 7 cases. Les objets posés quittent le sac et y reviennent quand on les range ; les trophées restent au joueur.')));
      const themes = h('div', { class: 'pjr-table' });
      c.themes.forEach((t, i) => themes.appendChild(h('div', { class: 'pjr-trow' },
        textInput(t, 'id', { placeholder: 'id' }), langInputs(t, 'name'), textInput(t, 'image', { placeholder: 'fond_bois' }), rowButtons(c.themes, i))));
      grid.appendChild(block(`Fonds de la pièce (${c.themes.length})`, h('span', { class: 'pjr-actions' },
        h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.themes.push({ id: '', name: { fr: '', en: '' }, image: '' }); }) }, 'Ajouter'),
        h('button', { class: 'pjs-btn small', onclick: () => { if (confirm('Remettre les fonds par défaut ?')) redo(() => { c.themes = clone(BS_DEFAULT_THEMES); }); } }, 'Par défaut')),
        themes, hint('Images de 320 × 240 dans graphics/interface/base_secrete/ (sans l’extension). Le joueur change de fond avec X dans la pièce.')));
      const decor = h('div', { class: 'pjr-table' });
      c.decor.forEach((d, i) => decor.appendChild(h('div', { class: 'pjr-trow' },
        combo({ value: d.item, items: L.items, allowEmpty: true, emptyLabel: '(objet)', onPick: (v) => redo(() => { d.item = v; }) }), langInputs(d, 'name'), rowButtons(c.decor, i))));
      grid.appendChild(block(`Autres objets décoratifs (${c.decor.length})`, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.decor.push({ item: '', name: { fr: '', en: '' } }); }) }, 'Ajouter'),
        decor, hint('En plus du préfixe. Le nom ne sert que dans la pièce (vide : nom de l’objet). Vendez ces objets dans un magasin (Boutique) comme les autres.')));
      grid.appendChild(commands([
        ['base_secrete', 'ouvre la pièce pour la décorer'],
        ['base_secrete_objets', 'nombre de décorations posées'],
        ['base_secrete_trophees', 'nombre de trophées disponibles (succès + concours)'],
        ['base_secrete_theme(:grotte)', 'change le fond de la pièce'],
        ['base_secrete_vider', 'range tout (les objets reviennent dans le sac)'],
      ]));
      content.appendChild(grid);
      return content;
    },
  };

  // ===========================================================================
  // Données > Zones > Météo et saisons (meteo_saisons.json)
  // ===========================================================================
  const MS_SEASONS = [['spring', 'Printemps'], ['summer', 'Été'], ['autumn', 'Automne'], ['winter', 'Hiver']];
  const MS_WEATHERS = [['none', 'Ciel dégagé'], ['rain', 'Pluie'], ['sunny', 'Soleil'], ['sandstorm', 'Tempête de sable'], ['hail', 'Grêle'], ['fog', 'Brouillard'],
    ['hardsun', 'Soleil ardent'], ['hardrain', 'Pluie battante'], ['strong_winds', 'Vents forts'], ['snow', 'Neige'], ['shadow_sky', 'Ciel Obscur']];
  const MS_DEFAULT_FORECAST = [['spring', 'none', 40], ['spring', 'rain', 35], ['spring', 'sunny', 15], ['spring', 'fog', 10], ['summer', 'sunny', 45], ['summer', 'none', 30],
    ['summer', 'rain', 15], ['summer', 'hardsun', 10], ['autumn', 'none', 30], ['autumn', 'rain', 30], ['autumn', 'fog', 25], ['autumn', 'strong_winds', 15],
    ['winter', 'snow', 35], ['winter', 'none', 35], ['winter', 'hail', 10], ['winter', 'fog', 20]].map(([season, weather, weight]) => ({ zone: '', season, weather, weight }));
  const MS_DEFAULT_TYPES = [['weather', 'rain', 'water', 200], ['weather', 'rain', 'electric', 150], ['weather', 'rain', 'bug', 120], ['weather', 'rain', 'fire', 60],
    ['weather', 'hardrain', 'water', 250], ['weather', 'sunny', 'fire', 200], ['weather', 'sunny', 'grass', 150], ['weather', 'hardsun', 'fire', 250],
    ['weather', 'sandstorm', 'rock', 200], ['weather', 'sandstorm', 'ground', 200], ['weather', 'sandstorm', 'steel', 150], ['weather', 'hail', 'ice', 250],
    ['weather', 'snow', 'ice', 250], ['weather', 'fog', 'ghost', 200], ['weather', 'fog', 'fairy', 150], ['weather', 'fog', 'psychic', 150],
    ['weather', 'strong_winds', 'flying', 200], ['weather', 'shadow_sky', 'dark', 250], ['weather', 'shadow_sky', 'ghost', 200],
    ['season', 'spring', 'grass', 150], ['season', 'spring', 'bug', 150], ['season', 'spring', 'fairy', 130], ['season', 'summer', 'fire', 150],
    ['season', 'summer', 'water', 130], ['season', 'summer', 'bug', 130], ['season', 'autumn', 'grass', 120], ['season', 'autumn', 'dark', 130],
    ['season', 'autumn', 'ghost', 130], ['season', 'winter', 'ice', 200], ['season', 'winter', 'bug', 50], ['season', 'winter', 'grass', 60]]
    .map(([on, key, type, percent]) => ({ on, key, type, percent }));
  const MS_DEFAULTS = { season_mode: 'calendar', season_variable: 0, southern: false, season_days: 7, change_hours: 6, all_zones: false, respect_forced: true,
    notify: true, spawn_effects: true, berry_effects: true, berry_in_season: 80, berry_out_season: 120, season_growth: { spring: 100, summer: 100, autumn: 100, winter: 120 }, excluded_maps: [] };
  const meteoSaisonsPage = {
    title: 'Météo et saisons',
    normalize(c) {
      c.klass = 'MeteoSaisonsConfig';
      c.settings = Object.assign(clone(MS_DEFAULTS), isObj(c.settings) ? c.settings : {});
      const st = c.settings;
      st.season_growth = Object.assign(clone(MS_DEFAULTS.season_growth), isObj(st.season_growth) ? st.season_growth : {});
      st.excluded_maps = (Array.isArray(st.excluded_maps) ? st.excluded_maps : []).map((n) => ({ id: int(n, 0) }));
      ['southern', 'all_zones', 'respect_forced', 'notify', 'spawn_effects', 'berry_effects'].forEach((k) => { st[k] = st[k] === true || (st[k] !== false && MS_DEFAULTS[k]); });
      c.forecast = (Array.isArray(c.forecast) && c.forecast.length ? c.forecast : clone(MS_DEFAULT_FORECAST)).filter(isObj)
        .map((r) => ({ zone: String(r.zone || ''), season: String(r.season || ''), weather: String(r.weather || 'none'), weight: int(r.weight, 10) }));
      c.type_weights = (Array.isArray(c.type_weights) && c.type_weights.length ? c.type_weights : clone(MS_DEFAULT_TYPES)).filter(isObj)
        .map((r) => ({ on: r.on === 'season' ? 'season' : 'weather', key: String(r.key || ''), type: String(r.type || ''), percent: int(r.percent, 100) }));
      c.species_weights = (Array.isArray(c.species_weights) ? c.species_weights : []).filter(isObj)
        .map((r) => ({ on: r.on === 'season' ? 'season' : 'weather', key: String(r.key || ''), species: String(r.species || ''), percent: int(r.percent, 100) }));
      c.berry_seasons = (Array.isArray(c.berry_seasons) ? c.berry_seasons : []).filter(isObj).map((r) => ({ berry: String(r.berry || ''), season: String(r.season || 'spring') }));
      return c;
    },
    serialize(c) {
      const st = c.settings;
      if (!['calendar', 'variable', 'manual', 'days'].includes(st.season_mode)) st.season_mode = 'calendar';
      st.season_variable = Math.max(0, int(st.season_variable, 0));
      st.season_days = Math.min(365, Math.max(1, int(st.season_days, 7)));
      st.change_hours = Math.min(168, Math.max(1, int(st.change_hours, 6)));
      st.berry_in_season = Math.min(500, Math.max(10, int(st.berry_in_season, 80)));
      st.berry_out_season = Math.min(500, Math.max(10, int(st.berry_out_season, 120)));
      MS_SEASONS.forEach(([k]) => { st.season_growth[k] = Math.min(500, Math.max(10, int(st.season_growth[k], 100))); });
      st.excluded_maps = [...new Set(st.excluded_maps.map((x) => int(x.id, 0)).filter((n) => n > 0))];
      c.forecast = c.forecast.filter((r) => r.weight > 0).map((r) => ({ zone: r.zone.trim(), season: r.season, weather: r.weather, weight: r.weight }));
      c.type_weights = c.type_weights.filter((r) => r.key && r.type).map((r) => ({ on: r.on, key: r.key, type: r.type, percent: Math.min(2000, Math.max(5, r.percent)) }));
      c.species_weights = c.species_weights.filter((r) => r.key && r.species).map((r) => ({ on: r.on, key: r.key, species: r.species, percent: Math.min(2000, Math.max(5, r.percent)) }));
      c.berry_seasons = c.berry_seasons.filter((r) => r.berry);
      return c;
    },
    problems(S) {
      const out = [];
      const c = S.config;
      if (c.forecast.some((r) => r.weight <= 0)) out.push('Une ligne de météo a un poids de 0 (ignorée).');
      const species = new Set((S.ctx.creatures || []).map((x) => x.db));
      if (species.size) c.species_weights.forEach((r) => { if (r.species && !species.has(r.species)) out.push(`Pokémon « ${r.species} » introuvable.`); });
      const types = new Set((S.ctx.types || []).map((x) => x.db));
      if (types.size) c.type_weights.forEach((r) => { if (r.type && !types.has(r.type)) out.push(`Type « ${r.type} » introuvable.`); });
      return out;
    },
    render(S) {
      const c = S.config;
      const st = c.settings;
      S.ui.ms = S.ui.ms || { tab: 'weather' };
      const ui = S.ui.ms;
      const content = h('div', { class: 'pjr-content' });
      const tabs = [['weather', 'Météo des zones'], ['seasons', 'Saisons'], ['spawn', 'Apparitions'], ['berries', 'Baies'], ['commands', 'Commandes']];
      content.appendChild(h('div', { class: 'pjr-actions pjr-tabs' }, ...tabs.map(([key, label]) =>
        h('button', { class: 'pjs-btn small' + (ui.tab === key ? ' active' : ''), onclick: () => redo(() => { ui.tab = key; }) }, label))));
      const grid = h('div', { class: 'mtgrid' });
      const seasonSel = (obj, key, allowAll) => select(obj, key, [...(allowAll ? [['', 'Toutes les saisons']] : []), ...MS_SEASONS]);
      if (ui.tab === 'weather') {
        grid.appendChild(block('Réglages', null,
          h('div', { class: 'pjr-grid2' }, labeled('Change toutes les (heures réelles)', numInput(st, 'change_hours', { min: 1, max: 168, cls: 'tiny' }))),
          check(st, 'all_zones', 'Toutes les zones ont une météo changeante (sinon : seulement celles citées ci-dessous)'),
          check(st, 'respect_forced', 'Respecter la météo imposée par la zone dans Studio'),
          check(st, 'notify', 'Bannière du téléphone quand la météo change'),
          hint('La météo est tirée à l’arrivée dans la zone puis à chaque période. Des cartes d’intérieur : listez-les dans « Cartes sans météo » (onglet Saisons).')));
        const rows = h('div', { class: 'pjr-table' });
        c.forecast.forEach((r, i) => rows.appendChild(h('div', { class: 'pjr-trow' },
          textInput(r, 'zone', { placeholder: 'zone (vide : toutes)' }), seasonSel(r, 'season', true), select(r, 'weather', MS_WEATHERS),
          numInput(r, 'weight', { min: 0, max: 1000, cls: 'tiny' }), rowButtons(c.forecast, i))));
        grid.appendChild(block(`Prévisions (${c.forecast.length})`, h('span', { class: 'pjr-actions' },
          h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.forecast.push({ zone: '', season: '', weather: 'rain', weight: 10 }); }) }, 'Ajouter'),
          h('button', { class: 'pjs-btn small', onclick: () => { if (confirm('Remettre les prévisions par défaut ?')) redo(() => { c.forecast = clone(MS_DEFAULT_FORECAST); }); } }, 'Par défaut')),
          rows, hint('Zone : db_symbol de la zone Studio (ex. route_1). Une zone qui a ses propres lignes n’utilise plus celles « toutes zones ». Le Ciel Obscur peut aussi tomber : le combat commence alors sous cette météo.')));
      } else if (ui.tab === 'seasons') {
        grid.appendChild(block('Saison', null,
          labeled('Comment connaître la saison', select(st, 'season_mode', [['calendar', 'Date de l’ordinateur (mars-mai : printemps…)'], ['days', 'Une saison tous les N jours réels'],
            ['variable', 'Variable du jeu (0 printemps … 3 hiver)'], ['manual', 'Fixée par évènement (saison_fixer)']])),
          h('div', { class: 'pjr-grid2' },
            labeled('Jours par saison (mode « jours »)', numInput(st, 'season_days', { min: 1, max: 365, cls: 'tiny' })),
            labeled('Variable (mode « variable »)', numInput(st, 'season_variable', { min: 0, max: 9999, cls: 'tiny' }))),
          check(st, 'southern', 'Hémisphère sud (saisons inversées)')));
        const ex = h('div', { class: 'pjr-table' }, ...st.excluded_maps.map((m, i) => h('div', { class: 'pjr-trow' },
          numInput(m, 'id', { min: 0, max: 9999, cls: 'tiny' }), rowButtons(st.excluded_maps, i))));
        grid.appendChild(block('Cartes sans météo changeante', h('button', { class: 'pjs-btn small', onclick: () => redo(() => { st.excluded_maps.push({ id: 0 }); }) }, 'Ajouter'),
          ex, hint('Numéros de cartes (intérieurs, grottes fermées…).')));
      } else if (ui.tab === 'spawn') {
        grid.appendChild(block('Pokémon visibles', null,
          check(st, 'spawn_effects', 'La météo et la saison changent les apparitions (plugin Pokémon visibles)'),
          hint('Chaque ligne multiplie la chance d’apparition des Pokémon du type (ou de l’espèce) : 200 % = deux fois plus, 50 % = deux fois moins. Les effets se cumulent.')));
        const types = h('div', { class: 'pjr-table' });
        c.type_weights.forEach((r, i) => types.appendChild(h('div', { class: 'pjr-trow' },
          select(r, 'on', [['weather', 'Météo'], ['season', 'Saison']]),
          r.on === 'season' ? seasonSel(r, 'key', false) : select(r, 'key', MS_WEATHERS),
          combo({ value: r.type, items: L.types, placeholder: 'Type…', onPick: (v) => redo(() => { r.type = v; }) }),
          numInput(r, 'percent', { min: 5, max: 2000, cls: 'tiny' }), rowButtons(c.type_weights, i))));
        grid.appendChild(block(`Par type (${c.type_weights.length})`, h('span', { class: 'pjr-actions' },
          h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.type_weights.push({ on: 'weather', key: 'rain', type: '', percent: 150 }); }) }, 'Ajouter'),
          h('button', { class: 'pjs-btn small', onclick: () => { if (confirm('Remettre les valeurs par défaut ?')) redo(() => { c.type_weights = clone(MS_DEFAULT_TYPES); }); } }, 'Par défaut')), types));
        const sp = h('div', { class: 'pjr-table' });
        c.species_weights.forEach((r, i) => sp.appendChild(h('div', { class: 'pjr-trow' },
          select(r, 'on', [['weather', 'Météo'], ['season', 'Saison']]),
          r.on === 'season' ? seasonSel(r, 'key', false) : select(r, 'key', MS_WEATHERS),
          combo({ value: r.species, items: L.creatures, placeholder: 'Pokémon…', onPick: (v) => redo(() => { r.species = v; }) }),
          numInput(r, 'percent', { min: 5, max: 2000, cls: 'tiny' }), rowButtons(c.species_weights, i))));
        grid.appendChild(block(`Par espèce (${c.species_weights.length})`, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.species_weights.push({ on: 'weather', key: 'rain', species: '', percent: 300 }); }) }, 'Ajouter'), sp));
      } else if (ui.tab === 'berries') {
        grid.appendChild(block('Pousse des baies (champs de baies)', null,
          check(st, 'berry_effects', 'La saison change la pousse'),
          h('div', { class: 'pjr-grid2' }, ...MS_SEASONS.map(([k, label]) => labeled(`Temps de pousse, ${label} (%)`, numInput(st.season_growth, k, { min: 10, max: 500, cls: 'tiny' }))),
            labeled('Baie dans sa saison : temps de pousse (%)', numInput(st, 'berry_in_season', { min: 10, max: 500, cls: 'tiny' })),
            labeled('Baie hors saison : temps de pousse (%)', numInput(st, 'berry_out_season', { min: 10, max: 500, cls: 'tiny' }))),
          hint('Une baie dans sa saison donne aussi 1 baie de plus à la récolte. Une baie qui n’est dans aucune ligne ci-dessous n’a pas de saison.')));
        const rows = h('div', { class: 'pjr-table' });
        c.berry_seasons.forEach((r, i) => rows.appendChild(h('div', { class: 'pjr-trow' },
          combo({ value: r.berry, items: L.berries, placeholder: 'Baie…', onPick: (v) => redo(() => { r.berry = v; }) }), seasonSel(r, 'season', false), rowButtons(c.berry_seasons, i))));
        grid.appendChild(block(`Saison de chaque baie (${c.berry_seasons.length})`, h('button', { class: 'pjs-btn small', onclick: () => redo(() => { c.berry_seasons.push({ berry: '', season: 'spring' }); }) }, 'Ajouter'), rows));
      } else {
        grid.appendChild(commands([
          ['saison', 'saison actuelle (:spring, :summer, :autumn, :winter)'],
          ['saison_fixer(:winter)', 'fixe la saison (mode « fixée par évènement »)'],
          ['meteo_zone_symbole', 'météo prévue pour la zone (nil : zone sans météo changeante)'],
          ['meteo_zone', 'message : « Printemps : Pluie »'],
          ['meteo_actualiser', 'applique tout de suite la météo prévue'],
        ]));
      }
      content.appendChild(grid);
      return content;
    },
  };

  // ===========================================================================
  // Données > Vérificateur de données (aucun fichier de réglages : lecture seule)
  // ===========================================================================
  const AUDIT_COLORS = { error: '#e5534b', warn: '#d9a21b', info: '#5b9bd5', ok: '#4caf50' };
  const AUDIT_LABELS = { error: 'À corriger', warn: 'À vérifier', info: 'Pour info', ok: 'Rien à signaler' };
  const verificateurPage = {
    title: 'Vérificateur de données',
    readonly: true,
    normalize() { return {}; },
    problems() { return []; },
    render(S) {
      const audit = S.ctx && S.ctx.audit;
      S.ui.audit = S.ui.audit || { open: {} };
      const ui = S.ui.audit;
      const content = h('div', { class: 'pjr-content' });
      if (!audit) { content.appendChild(hint('Vérification en cours…')); return content; }
      const bad = audit.sections.filter((x) => x.count > 0 && x.severity !== 'info');
      const total = bad.reduce((n, x) => n + x.count, 0);
      content.appendChild(block('Résumé', h('button', { class: 'pjs-btn small', onclick: () => loadProject(activeId, S.projectPath) }, 'Revérifier'),
        hint(total ? `${total} point(s) à regarder dans ${bad.length} catégorie(s). Corrige-les dans Studio (onglets Pokémon, Capacités, Objets, Dresseurs, textes…) puis relance la vérification.`
          : 'Tout est en ordre : aucun texte, icône, cri ou dresseur Obscur à corriger.')));
      audit.sections.forEach((sec) => {
        const empty = sec.count === 0;
        const level = empty ? 'ok' : sec.severity;
        const open = !!ui.open[sec.id];
        const head = h('div', { class: 'pjr-trow', style: `cursor:${empty ? 'default' : 'pointer'};` },
          h('span', { style: `display:inline-block;min-width:92px;color:${AUDIT_COLORS[level]};font-weight:600;` }, AUDIT_LABELS[level]),
          h('span', { style: 'flex:1;' }, sec.title),
          h('span', null, empty ? '0' : `${sec.count}${empty ? '' : (open ? ' ▾' : ' ▸')}`));
        if (!empty) head.addEventListener('click', () => redo(() => { ui.open[sec.id] = !open; }));
        const body = [head];
        if (sec.note && (open || empty)) body.push(hint(sec.note));
        if (open && !empty) {
          body.push(h('div', { class: 'pjr-table' }, ...sec.items.map((t) => h('div', { class: 'pjr-trow' }, h('span', null, t)))));
          if (sec.more) body.push(hint(`… et ${sec.more} autre(s) (non listés).`));
        }
        content.appendChild(h('div', { class: 'pjs-block' }, ...body));
      });
      return content;
    },
  };


  // ===========================================================================
  // Accueil des plugins (lecture seule) : version, dépendances, liens vers les réglages
  // ===========================================================================
  const PLUGIN_ROUTES = {
    'dex-tasks': ['/database/dex-tasks', 'Tâches du Pokédex'], 'champs-baies': ['/database/berries/champs', 'Champs de baies'],
    'styles-pla': ['/database/gimmicks/styles', 'Styles PLA'], 'sac-de-frappe': ['/database/minigames/sac-de-frappe', 'Sac de frappe'],
    'poke-recre': ['/database/minigames/poke-recre', 'Poké Récré'], 'raids': ['/database/gimmicks/raids', 'Raids'],
    'raids-cartes': ['/database/minigames/raids-cartes', 'Cartes d’aventure'], 'tournois': ['/database/trainers/tournois', 'Tournois'],
    'pokeblocs': ['/database/berries/pokeblocs', 'Pokéblocs'], 'concours': ['/database/minigames/concours', 'Concours'],
    'obscurs': ['/database/gimmicks/obscurs', 'Pokémon Obscurs'], 'montures': ['/database/interface/montures', 'Montures'],
    'pokeathlon': ['/database/minigames/pokeathlon', 'Pokéathlon'], 'dodrio': ['/database/minigames/dodrio', 'Cueillette Dodrio'],
    'lance_ball': ['/database/minigames/lance_ball', 'Lance-Ball'], 'overworld-pokemon': ['/database/zones/overworld-pokemon', 'Pokémon visibles'],
    'barons-dominants': ['/database/gimmicks/barons-dominants', 'Barons, Monarques et Dominants'], 'modes-jeu': ['/database/gimmicks/modes-jeu', 'Modes de jeu'],
    'meteo-saisons': ['/database/zones/meteo-saisons', 'Météo et saisons'], 'base-secrete': ['/database/interface/base-secrete', 'Base secrète'],
    'verificateur': ['/database/verificateur', 'Vérificateur'],
  };
  // pages de Studio propres à un plugin (sans réglages JSON passant par ces pages)
  const PLUGIN_EXTRA = {
    advanced_pokedex: [['/database/dex-size', 'Taille / Poids']], berrydex: [['/database/berries/berrydex', 'Berrydex']],
    pots_baies: [['/database/berries/pots', 'Pots à baies']], succes: [['/database/interface/succes', 'Succès']],
    etui_badges: [['/database/interface/badges', 'Étui à badges']], magasins: [['/database/shops', 'Boutique']],
    mementos: [['/database/mementos', 'Rubans et insignes']], quel_pokemon: [['/database/minigames/quel-pokemon', 'Quel est ce Pokémon']],
    triple_triad: [['/database/minigames/triple-triad', 'Triple Triad']], pokesmart: [['/database/interface/smartphone', 'Smartphone']],
    gimmicks: [['/database/gimmicks/mega', 'Méga-gemmes'], ['/database/gimmicks/zmove', 'Capacités Z'], ['/database/gimmicks/dynamax', 'Dynamax'], ['/database/gimmicks/tera', 'Téracristal']],
    animations_attaques: [['/database/move-animations', 'Animations']],
  };
  function goToRoute(route) {
    try {
      if (/^#\//.test(window.location.hash || '')) window.location.hash = '#' + route;
      else { window.history.pushState({}, '', route); window.dispatchEvent(new PopStateEvent('popstate')); }
    } catch (e) { toast('Navigation impossible : ouvre la page depuis le menu Données.', true); }
  }
  const pluginsPage = {
    title: 'Plugins',
    readonly: true,
    normalize() { return {}; },
    problems() { return []; },
    render(S) {
      const list = S.ctx && S.ctx.overview;
      const content = h('div', { class: 'pjr-content' });
      if (!list) { content.appendChild(hint('Lecture des plugins…')); return content; }
      const missing = list.filter((x) => x.missing.length);
      const stale = list.filter((x) => x.hasScripts && (!x.installed || x.outdated || x.stale));
      const unpacked = list.filter((x) => !x.packaged);
      content.appendChild(block('Résumé', h('button', { class: 'pjs-btn small', onclick: () => loadProject(activeId, S.projectPath) }, 'Actualiser'),
        hint(`${list.length} plugins. ${missing.length ? missing.length + ' avec une dépendance introuvable. ' : ''}${stale.length ? stale.length + ' dont la copie installée (scripts/00000 Plugins) n’est pas à jour : enregistre leur page de réglages ou lance construire_plugins.bat. ' : ''}${unpacked.length ? unpacked.length + ' sans paquet .psdkplug. ' : ''}${!missing.length && !stale.length && !unpacked.length ? 'Tout est cohérent.' : ''}`)));
      const search = h('input', { class: 'pjs-input', placeholder: 'Rechercher un plugin…', style: 'width:100%;margin:8px 0;' });
      const rows = list.map((x) => {
        const links = [];
        x.pages.forEach((id) => { const r = PLUGIN_ROUTES[id]; if (r) links.push(r); });
        (PLUGIN_EXTRA[x.name] || []).forEach((r) => { if (!links.some((l) => l[0] === r[0])) links.push(r); });
        const status = [];
        if (x.missing.length) status.push(h('span', { style: 'color:#e5534b;' }, 'Dépendance introuvable : ' + x.missing.join(', ')));
        if (x.hasScripts && !x.installed) status.push(h('span', { style: 'color:#d9a21b;' }, 'Pas de copie installée'));
        else if (x.hasScripts && (x.outdated || x.stale)) status.push(h('span', { style: 'color:#d9a21b;' }, `Copie installée à mettre à jour (${x.outdated + x.stale} fichier(s))`));
        if (!x.packaged) status.push(h('span', { style: 'color:#d9a21b;' }, 'Paquet .psdkplug absent'));
        const row = h('div', { class: 'pjs-block', 'data-name': x.name.toLowerCase() },
          h('div', { class: 'pjr-trow' },
            h('strong', { style: 'flex:1;' }, x.name),
            h('span', null, 'v' + (x.version || '?'))),
          h('div', { class: 'pjr-trow' }, h('span', { style: 'flex:1;color:var(--pjs-muted,#999);' }, x.deps.length ? 'Dépend de : ' + x.deps.join(', ') : 'Aucune dépendance'),
            x.requiredBy.length ? h('span', { style: 'color:var(--pjs-muted,#999);' }, 'Utilisé par : ' + x.requiredBy.join(', ')) : null),
          status.length ? h('div', { class: 'pjr-trow', style: 'gap:12px;' }, ...status) : null,
          h('div', { class: 'pjr-trow', style: 'gap:6px;flex-wrap:wrap;' },
            ...links.map(([route, label]) => h('button', { class: 'pjs-btn small', onclick: () => goToRoute(route) }, 'Réglages : ' + label)),
            !links.length ? h('span', { style: 'color:var(--pjs-muted,#999);' }, x.settings.length ? 'Réglages dans ' + x.settings.map((f) => 'Data/configs/plugins/' + f).join(', ') + ' (pas de page Studio)' : 'Aucun réglage') : null));
        return row;
      });
      search.addEventListener('input', () => {
        const q = search.value.trim().toLowerCase();
        rows.forEach((r) => { r.style.display = !q || r.getAttribute('data-name').includes(q) ? '' : 'none'; });
      });
      content.appendChild(search);
      rows.forEach((r) => content.appendChild(r));
      return content;
    },
  };


  // ===========================================================================
  // Données > Équilibrage des types (lecture seule)
  // ===========================================================================
  const equilibragePage = {
    title: 'Équilibrage des types',
    readonly: true,
    normalize() { return {}; },
    problems() { return []; },
    render(S) {
      const bal = S.ctx && S.ctx.balance;
      const content = h('div', { class: 'pjr-content' });
      if (!bal) { content.appendChild(hint('Lecture des types…')); return content; }
      S.ui.bal = S.ui.bal || { tab: 'usage' };
      const ui = S.ui.bal;
      const byDb = Object.fromEntries(bal.types.map((t) => [t.db, t]));
      const nm = (db) => (byDb[db] ? byDb[db].name : db);
      const noMove = bal.types.filter((t) => t.moves === 0);
      const noAttack = bal.types.filter((t) => t.moves > 0 && t.damaging === 0);
      const noMon = bal.types.filter((t) => t.species === 0);
      const dups = bal.defenseDuplicates;
      content.appendChild(block('Résumé', h('button', { class: 'pjs-btn small', onclick: () => loadProject(activeId, S.projectPath) }, 'Actualiser'),
        hint(`${bal.types.length} types. ${noMove.length} sans aucune capacité, ${noMon.length} sans Pokémon, ${dups.length} groupe(s) de doublons défensifs. Les types de service (Inconnu, Obscur…) sont souvent vides ou identiques à dessein : à toi de juger.`)));
      const tabs = [['usage', 'Usage'], ['dups', 'Doublons'], ['table', 'Table des types']];
      content.appendChild(h('div', { class: 'pjr-trow', style: 'gap:6px;' }, ...tabs.map(([id, label]) =>
        h('button', { class: 'pjs-btn small' + (ui.tab === id ? ' primary' : ''), onclick: () => redo(() => { ui.tab = id; }) }, label))));
      const chip = (t) => h('span', { style: `display:inline-block;padding:1px 8px;border-radius:10px;background:${t.color};color:#111;font-weight:600;margin-right:4px;` }, t.name);
      if (ui.tab === 'usage') {
        const head = h('div', { class: 'pjr-trow', style: 'font-weight:600;' },
          h('span', { style: 'flex:1.2;' }, 'Type'), h('span', { style: 'flex:1;' }, 'Capacités (offensives)'), h('span', { style: 'flex:1;' }, 'Pokémon (formes)'),
          h('span', { style: 'flex:1.3;' }, 'Faiblesses / résist. / immun.'), h('span', { style: 'flex:1.6;' }, 'À regarder'));
        const rows = bal.types.map((t) => {
          const flags = [];
          if (t.moves === 0) flags.push(['error', 'aucune capacité']);
          else if (t.damaging === 0) flags.push(['warn', 'aucune capacité offensive']);
          if (t.species === 0) flags.push(['warn', 'aucun Pokémon']);
          if (t.weak === 0 && t.species > 0) flags.push(['info', 'aucune faiblesse']);
          if (t.strong === 0 && t.damaging > 0) flags.push(['warn', 'super efficace sur rien']);
          return h('div', { class: 'pjr-trow' },
            h('span', { style: 'flex:1.2;' }, chip(t)),
            h('span', { style: 'flex:1;' }, `${t.moves} (${t.damaging})`),
            h('span', { style: 'flex:1;' }, `${t.species} (${t.forms})`),
            h('span', { style: 'flex:1.3;' }, `${t.weak} / ${t.resist} / ${t.immune}`),
            h('span', { style: 'flex:1.6;' }, ...flags.map(([lv, txt]) => h('span', { style: `color:${AUDIT_COLORS[lv]};margin-right:8px;` }, txt))));
        });
        content.appendChild(h('div', { class: 'pjs-block' }, head, ...rows));
      } else if (ui.tab === 'dups') {
        const groupView = (groups, title, note) => h('div', { class: 'pjs-block' }, h('div', { style: 'font-weight:600;margin-bottom:6px;' }, title), hint(note),
          ...(groups.length ? groups.map((g) => h('div', { class: 'pjr-trow' }, ...g.map((d) => chip(byDb[d] || { name: d, color: '#888' })))) : [hint('Aucun doublon.')]));
        content.appendChild(groupView(bal.defenseDuplicates, 'Doublons défensifs', 'Ces types reçoivent exactement les mêmes dégâts de tous les types attaquants : en défense, ils sont interchangeables.'));
        content.appendChild(groupView(bal.offenseDuplicates, 'Doublons offensifs', 'Ces types infligent exactement les mêmes dégâts à tous les types.'));
      } else {
        const cellStyle = (v) => {
          const base = 'text-align:center;min-width:26px;padding:2px 3px;font-size:11px;border:1px solid rgba(128,128,128,.25);';
          if (v === 0) return base + 'background:#222;color:#fff;';
          if (v >= 2) return base + 'background:#4caf50;color:#111;font-weight:700;';
          if (v > 1) return base + 'background:#9ccc65;color:#111;';
          if (v <= 0.25) return base + 'background:#e5534b;color:#111;';
          if (v < 1) return base + 'background:#f0a35e;color:#111;';
          return base;
        };
        const label = (v) => (v === 1 ? '' : v === 0 ? '0' : v === 0.5 ? '½' : v === 0.25 ? '¼' : String(v).replace(/^2$/, '2'));
        const table = h('table', { style: 'border-collapse:collapse;' });
        table.appendChild(h('tr', null, h('th', { style: 'font-size:11px;padding:2px 6px;text-align:left;' }, 'Attaque ↓  Défense →'),
          ...bal.order.map((d) => h('th', { style: `font-size:10px;padding:2px 2px;writing-mode:vertical-rl;background:${(byDb[d] || {}).color || '#888'};color:#111;` }, nm(d)))));
        bal.types.forEach((t) => {
          table.appendChild(h('tr', null, h('td', { style: `font-size:11px;padding:2px 6px;background:${t.color};color:#111;font-weight:600;white-space:nowrap;` }, t.name),
            ...t.offense.map((v) => h('td', { style: cellStyle(v) }, label(v)))));
        });
        content.appendChild(h('div', { class: 'pjs-block', style: 'overflow:auto;' }, table,
          hint('Vert : super efficace ; orange : peu efficace ; noir : aucun effet ; vide : normal (×1). Une case absente du fichier du type compte pour ×1.')));
      }
      return content;
    },
  };

  const PAGES = { 'equilibrage-types': equilibragePage, 'plugins': pluginsPage, 'verificateur': verificateurPage, 'meteo-saisons': meteoSaisonsPage, 'base-secrete': baseSecretePage, 'dex-tasks': dexTasks, 'champs-baies': champsBaies, 'styles-pla': stylesPla, 'sac-de-frappe': sacDeFrappe, 'poke-recre': pokeRecre, 'raids': raidsPage, 'raids-cartes': raidMapsPage, 'tournois': tournoisPage, 'pokeblocs': pokeblocsPage, 'concours': concoursPage, 'obscurs': obscursPage, 'montures': monturesPage, 'pokeathlon': pokeathlonPage, 'dodrio': dodrioPage, 'lance_ball': lanceBallPage, 'overworld-pokemon': overworldPage, 'barons-dominants': rangsPage, 'modes-jeu': modesJeuPage };

  // ---------------------------------------------------------------------------
  // Rendu commun
  // ---------------------------------------------------------------------------
  function render() {
    if (!root || !activeId) return;
    closeCombo();
    const S = cur();
    const page = PAGES[activeId];
    const prev = root.querySelector('.pjr-detail');
    const scroll = prev ? prev.scrollTop : 0;
    const lists = [...root.querySelectorAll('.pjr-list')].map((l) => l.scrollTop);
    // le champ actif garde la main (même place dans la page refaite)
    const fields = [...root.querySelectorAll('input, select')];
    const focusIndex = fields.indexOf(document.activeElement);
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [st, stc] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, page.title),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + stc }, st),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty(S) || confirm('Abandonner les modifications non enregistrées ?')) loadProject(activeId, S.projectPath); }, title: 'Relire les fichiers du projet' }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    if (S.error) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty err' }, S.error))); return; }
    if (!S.config) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty' }, 'Chargement…'))); return; }
    const detail = h('div', { class: 'pjr-detail' });
    root.appendChild(detail);
    const p = S.ctx.plugin;
    if (p && !p.source) detail.appendChild(h('div', { class: 'pjs-warn' }, `Le dossier scripts/${p.name} est introuvable : extrais le plugin à la racine du projet.`));
    else if (p && !p.installed) detail.appendChild(h('div', { class: 'pjs-warn' }, `Le plugin « ${p.name} » n'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul).`));
    detail.appendChild(page.render(S));
    detail.appendChild(h('div', { class: 'pjs-hint pjr-file' }, 'Fichier : ' + S.ctx.file));
    detail.scrollTop = scroll;
    root.querySelectorAll('.pjr-list').forEach((l, i) => { if (lists[i]) l.scrollTop = lists[i]; });
    if (focusIndex >= 0) {
      const el = root.querySelectorAll('input, select')[focusIndex];
      if (el) { el.focus(); if (el.select && el.type !== 'checkbox') try { el.select(); } catch (e) { /* rien */ } }
    }
  }

  // ---------------------------------------------------------------------------
  // Pages de Studio (zones pj-page-<id> ajoutées par tools/studio-plugins/patch_studio_pages.py)
  // ---------------------------------------------------------------------------
  function mount(id, hostEl) {
    root = h('div', { id: 'pjr-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    activeId = id;
    const S = STATES[id];
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S || !S.config || (latest && latest !== S.projectPath && !dirty(S))) loadProject(id, latest || null); else render();
  }
  function checkPage() {
    const id = Object.keys(PAGES).find((k) => document.getElementById('pj-page-' + k));
    const hostEl = id && document.getElementById('pj-page-' + id);
    if (root && hostEl && hostEl.contains(root) && activeId === id) return;
    if (root) { if (root.parentNode) root.remove(); root = null; activeId = null; closeCombo(); if (audio) audio.pause(); }
    if (hostEl) mount(id, hostEl);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);
  window.addEventListener('keydown', (e) => {
    if (!root || !activeId) return;
    if (e.ctrlKey && e.key.toLowerCase() === 's') { e.preventDefault(); e.stopPropagation(); save(); }
  }, true);
  setInterval(() => { if (root) updateStatus(); }, 1000);

  window.pjReglagesEditor = { states: STATES, pages: PAGES, render };
})();

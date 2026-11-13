/* eslint-disable */
// =============================================================================
// Triple Triad — éditeur du plugin « triple_triad » pour Pokémon Studio
// Ouvert par « Level design > Mini-jeux > Triple Triad » dans le menu de la base de données (ou Ctrl+Maj+T).
//   Cartes      : valeurs calculées (stats de base, évolutions plus fortes), valeurs / prix personnalisés, cartes retirées
//   Adversaires : nom, 5 cartes, règles → triple_triad_deck_duel(:id) dans un évent
//   Boutique    : cartes en vente par défaut, prix, revente
// Utilise le style de l'éditeur Smartphone (classes pjs-*), installé avant lui.
// =============================================================================
(() => {
  'use strict';
  if (window.__pjTriadLoaded) return;
  window.__pjTriadLoaded = true;

  // ---------------------------------------------------------------------------
  // Constantes (les mêmes que le plugin)
  // ---------------------------------------------------------------------------
  const DEFAULTS = { klass: 'TripleTriadConfig', cards: {}, decks: [], shop: [], price_factor: 1.0, sell_ratio: 0.5 };
  const STEPS = [[189, 10], [160, 9], [134, 8], [115, 7], [100, 6], [86, 5], [73, 4], [60, 3], [45, 2]];
  const MIN_PRICE = 100;
  const SIDES = ['Haut', 'Droite', 'Bas', 'Gauche'];
  const RULES = [
    ['open', 'Ouvert', 'La main de l\'adversaire est visible'],
    ['same', 'Pareil', '2 côtés égaux ou plus capturent (combo)'],
    ['samewall', 'Pareil mur', 'Les bords du plateau comptent comme des A pour Pareil'],
    ['plus', 'Plus', '2 sommes égales ou plus capturent (combo)'],
    ['elements', 'Éléments', 'Cases à type : +1 si la carte a ce type, -1 sinon'],
    ['random', 'Hasard', 'Le joueur joue 5 cartes tirées au hasard'],
    ['suddendeath', 'Mort subite', 'En cas d\'égalité, on rejoue avec les cartes possédées'],
  ];
  const TRADES = [['trade_one', 'Une carte (le gagnant choisit)'], ['trade_direct', 'Chacun garde les cartes capturées'], ['trade_all', 'Le gagnant prend tout'], ['trade_none', 'Aucun échange']];
  const ZOOM = 3;

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjTriad;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API Triple Triad n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const norm = (t) => String(t).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  let toastTimer = null;
  function toast(msg, err) {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.remove(), err ? 6000 : 2500);
  }
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = {
    open: false, projectPath: null, ctx: null, config: null, saved: null, error: null,
    tab: 'cards', query: '', sel: null, deckIndex: 0,
    images: new Map(), pluginBuilding: false, pluginError: null,
  };
  let root = null;
  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => S.config && S.saved !== snapshot();

  // ---------------------------------------------------------------------------
  // Cartes : valeurs (même calcul que TripleTriad::Card.auto_values)
  // ---------------------------------------------------------------------------
  const creatureOf = (db) => S.ctx && S.ctx.creatures.find((c) => c.dbSymbol === db);
  let preEvo = null;
  function preEvolution(db) {
    if (!preEvo) {
      preEvo = {};
      S.ctx.creatures.forEach((c) => c.evolutions.forEach((t) => { if (t !== c.dbSymbol && !preEvo[t]) preEvo[t] = c.dbSymbol; }));
    }
    return preEvo[db];
  }
  const baseValue = (stat) => { for (const [min, v] of STEPS) if (stat >= min) return v; return 1; };
  const autoCache = new Map();
  function autoValues(db, stack = new Set()) {
    if (autoCache.has(db)) return autoCache.get(db);
    const c = creatureOf(db);
    if (!c) return [1, 1, 1, 1];
    const s = c.stats;
    let values = [baseValue(s.atk + Math.floor(s.spd / 3)), baseValue(s.dfe + Math.floor(s.hp / 3)),
      baseValue(s.ats + Math.floor(s.spd / 3)), baseValue(s.dfs + Math.floor(s.hp / 3))];
    const parent = preEvolution(db);
    if (parent && parent !== db && !stack.has(parent)) {
      stack.add(db);
      const base = customValues(parent) || autoValues(parent, stack);
      values = values.map((v, i) => Math.max(v, base[i]));
      if (values.reduce((a, b) => a + b) <= base.reduce((a, b) => a + b)) {
        let weakest = -1;
        values.forEach((v, i) => { if (v < 10 && (weakest < 0 || v < values[weakest])) weakest = i; });
        if (weakest >= 0) values[weakest] += 1;
      }
    }
    autoCache.set(db, values);
    return values;
  }
  const settingOf = (db) => (S.config.cards || {})[db] || null;
  function customValues(db) {
    const st = settingOf(db);
    return st && Array.isArray(st.values) && st.values.length === 4 ? st.values.map((v) => Math.min(10, Math.max(1, v | 0))) : null;
  }
  const valuesOf = (db) => customValues(db) || autoValues(db);
  const levelOf = (values) => Math.min(9, Math.max(0, Math.floor((values.reduce((a, b) => a + b) - 4) / 3.6)));
  function priceOf(db) {
    const st = settingOf(db);
    if (st && (st.price | 0) > 0) return st.price | 0;
    const total = valuesOf(db).reduce((a, b) => a + b);
    return Math.max(Math.round((total ** 2) * 4 * (+S.config.price_factor || 1) / 10) * 10, MIN_PRICE);
  }
  const resetAuto = () => autoCache.clear();
  // nettoie le réglage d'une carte vide
  function cleanSetting(db) {
    const st = settingOf(db);
    if (!st) return;
    if (!st.values) delete st.values;
    if (!(st.price > 0)) delete st.price;
    if (!st.excluded) delete st.excluded;
    if (!Object.keys(st).length) delete S.config.cards[db];
  }
  function setting(db) {
    S.config.cards = S.config.cards || {};
    return (S.config.cards[db] = S.config.cards[db] || {});
  }

  // ---------------------------------------------------------------------------
  // Images et dessin d'une carte (comme UI::TripleTriad::CardSprite)
  // ---------------------------------------------------------------------------
  function decode(url) {
    return new Promise((resolve) => {
      if (!url) { resolve(null); return; }
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => resolve(null);
      img.src = url;
    });
  }
  function asset(name) {
    const key = 'a:' + name;
    if (!S.images.has(key)) S.images.set(key, decode(S.ctx.assets[name]));
    return S.images.get(key);
  }
  let iconQueue = null;
  function icon(name) {
    if (!name) return Promise.resolve(null);
    const key = 'i:' + name;
    if (!S.images.has(key)) {
      // regroupe les demandes d'icônes
      if (!iconQueue) {
        iconQueue = { names: new Set(), promise: null };
        iconQueue.promise = new Promise((resolve) => setTimeout(() => {
          const names = [...iconQueue.names];
          iconQueue = null;
          call('readIcons', { projectPath: S.projectPath, names }).then(resolve).catch(() => resolve({}));
        }, 0));
      }
      iconQueue.names.add(name);
      const p = iconQueue.promise;
      S.images.set(key, p.then((m) => decode(m[name])));
    }
    return S.images.get(key);
  }
  const DIGITS = [[8, 2], [14, 9], [8, 16], [2, 9]];
  // Dessine une carte dans un canvas (40x48 x zoom)
  async function drawCard(canvas, db, owner = 0, zoom = ZOOM) {
    canvas.width = 40 * zoom; canvas.height = 48 * zoom;
    const c = creatureOf(db);
    const [bg, nums, ic] = await Promise.all([asset(owner ? 'card_opponent' : 'card_player'), asset('numbers'), icon(c && c.icon)]);
    const g = canvas.getContext('2d');
    g.imageSmoothingEnabled = false;
    g.clearRect(0, 0, canvas.width, canvas.height);
    g.save(); g.scale(zoom, zoom);
    if (bg) g.drawImage(bg, 0, 0);
    if (ic) { const s = ic.height; g.drawImage(ic, 0, 0, s, s, Math.floor((40 - s) / 2) + 4, 48 - s - 1, s, s); }
    if (nums && c) valuesOf(db).forEach((v, i) => g.drawImage(nums, (v % 11) * 8, 0, 8, 8, DIGITS[i][0], DIGITS[i][1], 8, 8));
    g.restore();
  }
  const cardCanvas = (db, owner, zoom) => { const cv = h('canvas', { class: 'pjt-card' }); drawCard(cv, db, owner, zoom); return cv; };

  // ---------------------------------------------------------------------------
  // Chargement / enregistrement
  // ---------------------------------------------------------------------------
  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null; S.images = new Map(); preEvo = null; resetAuto();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      const c = Object.assign(clone(DEFAULTS), S.ctx.config || {});
      if (!c.cards || typeof c.cards !== 'object' || Array.isArray(c.cards)) c.cards = {};
      if (!Array.isArray(c.decks)) c.decks = [];
      if (!Array.isArray(c.shop)) c.shop = [];
      S.config = c;
      S.saved = S.ctx.config ? snapshot() : null;
      if (!S.sel || !creatureOf(S.sel)) { const first = S.ctx.creatures.find((x) => x.id > 0) || S.ctx.creatures[0]; S.sel = first && first.dbSymbol; }
    } catch (e) { S.error = e.message; }
    render();
  }

  async function save() {
    if (!S.config) return;
    try {
      Object.keys(S.config.cards).forEach(cleanSetting);
      const r = await call('save', { projectPath: S.projectPath, config: S.config });
      S.saved = snapshot();
      const p = r.plugin || {};
      if (p.source) S.ctx.plugin = { source: true, installed: p.installed, outdated: p.installed ? [] : ['?'], stale: [] };
      toast('Enregistré' + (p.source && !p.installed ? ' — plugin pas encore installé : lance construire_plugins.bat une fois' : ''));
      render();
      if (p.source) rebuildPlugin();
    } catch (e) { toast('Erreur de sauvegarde : ' + e.message, true); }
  }

  let buildQueued = false;
  async function rebuildPlugin() {
    if (S.pluginBuilding) { buildQueued = true; return; }
    S.pluginBuilding = true; S.pluginError = null; updateStatus();
    try {
      const r = await call('buildPlugin', { projectPath: S.projectPath });
      if (!r.built) S.pluginError = r.error || 'échec';
    } catch (e) { S.pluginError = e.message; }
    S.pluginBuilding = false; updateStatus();
    if (S.pluginError) toast("Enregistré, mais triple_triad.psdkplug n'a pas pu être reconstruit : " + S.pluginError, true);
    if (buildQueued) { buildQueued = false; rebuildPlugin(); }
  }
  function statusText() {
    if (!S.config) return ['', ''];
    if (dirty()) return ['Modifications non enregistrées', ' dirty'];
    if (S.pluginBuilding) return ['Mise à jour du plugin…', ''];
    const p = S.ctx && S.ctx.plugin;
    if (p && p.source && !p.installed) return ['Plugin pas installé : construire_plugins.bat', ' dirty'];
    if (p && p.source && (p.outdated.length || p.stale.length)) return ['Plugin installé pas à jour : Enregistrer', ' dirty'];
    if (S.pluginError) return ['Plugin : paquet non reconstruit', ' dirty'];
    return ['Tout est enregistré', ''];
  }
  function updateStatus() {
    const st = root && root.querySelector('.pjs-status');
    if (!st) return;
    const [t, cls] = statusText();
    st.className = 'pjs-status' + cls; st.textContent = t;
  }

  // ---------------------------------------------------------------------------
  // Liste déroulante avec recherche (même composant que l'Advanced Pokédex)
  // ---------------------------------------------------------------------------
  function combo({ value = '', placeholder = '', className = '', items, onPick, input = null, free = false }) {
    const field = input || h('input', { class: 'pjs-input', placeholder, value });
    field.setAttribute('autocomplete', 'off');
    const wrap = h('div', { class: 'pjt-combo ' + className });
    const pop = h('div', { class: 'pjt-pop' });
    wrap.append(field, pop);
    let shown = []; let active = -1; let typed = false; let opened = false; let last = field.value;
    const MAX = 300;
    const fill = () => {
      const q = typed ? norm(field.value.trim()) : '';
      const words = q.split(/\s+/).filter(Boolean);
      const all = items();
      shown = words.length ? all.filter((it) => words.every((w) => (it.search || norm(it.label)).includes(w))) : all;
      pop.textContent = '';
      shown.slice(0, MAX).forEach((it, i) => {
        const row = h('div', { class: 'pjt-opt' + (i === active ? ' active' : '') }, h('span', null, it.label), it.sub ? h('span', { class: 'pjt-sub' }, it.sub) : null);
        row.addEventListener('mousedown', (e) => { e.preventDefault(); pickItem(it); });
        pop.appendChild(row);
      });
      if (shown.length > MAX) pop.appendChild(h('div', { class: 'pjt-opt more' }, `… ${shown.length - MAX} autres : précise la recherche`));
      if (!shown.length) pop.appendChild(h('div', { class: 'pjt-opt more' }, 'Aucun résultat'));
    };
    const show = () => {
      opened = true; wrap.classList.add('open');
      active = typed ? 0 : items().findIndex((it) => it.label === field.value);
      fill();
      const el = pop.children[Math.max(active, 0)];
      if (el) el.scrollIntoView({ block: 'nearest' });
    };
    const hide = () => { opened = false; typed = false; wrap.classList.remove('open'); if (!free) field.value = last; };
    const pickItem = (it) => { field.value = last = it.label; hide(); field.blur(); onPick(it.value, it); };
    field.addEventListener('focus', () => { typed = false; field.select(); show(); });
    field.addEventListener('click', () => { if (!opened) show(); });
    field.addEventListener('input', () => { typed = true; active = 0; if (!opened) show(); else fill(); });
    field.addEventListener('blur', () => setTimeout(hide, 120));
    field.addEventListener('keydown', (e) => {
      if (!opened && (e.key === 'ArrowDown' || e.key === 'ArrowUp')) { show(); e.preventDefault(); return; }
      if (!opened) return;
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        active = Math.max(0, Math.min(Math.min(shown.length, MAX) - 1, active + (e.key === 'ArrowDown' ? 1 : -1)));
        [...pop.children].forEach((c, i) => c.classList.toggle('active', i === active));
        const el = pop.children[active]; if (el) el.scrollIntoView({ block: 'nearest' });
      } else if (e.key === 'Enter') {
        e.preventDefault();
        if (shown[active]) pickItem(shown[active]); else if (free) { hide(); field.blur(); }
      } else if (e.key === 'Escape') { e.preventDefault(); hide(); field.blur(); }
    });
    return wrap;
  }
  const label3 = (c) => `${String(c.id).padStart(3, '0')} ${c.name}`;
  const creatureItems = () => S.ctx.creatures.map((c) => ({ label: label3(c), sub: c.dbSymbol, value: c.dbSymbol, search: norm(`${c.id} ${label3(c)} ${c.dbSymbol}`) }));
  const creatureCombo = (db, onPick, placeholder = 'Pokémon (n°, nom ou symbole)') => {
    const c = db && creatureOf(db);
    return combo({ value: c ? label3(c) : '', placeholder, items: creatureItems, onPick });
  };

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [st, stc] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' },
        h('span', { class: 'pjs-top-title' }, 'Triple Triad'),
        h('div', { class: 'pjs-tabs' }, [['cards', 'Cartes'], ['decks', 'Adversaires'], ['shop', 'Boutique et prix']].map(([tab, l]) => h('button', {
          class: 'pjs-tab' + (S.tab === tab ? ' active' : ''), onclick: () => { S.tab = tab; render(); },
        }, l))),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + stc }, st),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Triple Triad : abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.config) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return; }
    const content = h('div', { class: 'pjs-content pjt-content' });
    page.appendChild(content);
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/triple_triad est introuvable : extrais le plugin à la racine du projet.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le plugin « triple_triad » n\'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul).'));
    if (S.tab === 'decks') renderDecks(content);
    else if (S.tab === 'shop') renderShop(content);
    else renderCards(content);
  }

  // --- Cartes -----------------------------------------------------------------
  function renderCards(content) {
    const row = h('div', { class: 'pjs-row pjt-row' });
    content.appendChild(row);
    // liste
    const listBlock = h('div', { class: 'pjs-block pjt-list-block' });
    const modified = Object.keys(S.config.cards).length;
    listBlock.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Cartes'), h('span', { class: 'pjs-count', title: 'Cartes modifiées' }, String(modified))));
    const search = h('input', { class: 'pjs-input', placeholder: 'n°, nom ou symbole', value: S.query });
    const onlyMod = h('label', { class: 'pjs-inline pjt-only' }, h('input', { type: 'checkbox', checked: S.onlyModified, onchange: (e) => { S.onlyModified = e.target.checked; fill(); } }), 'Cartes modifiées seulement');
    const list = h('div', { class: 'pjt-list' });
    listBlock.append(search, onlyMod, list);
    const fill = () => {
      list.textContent = '';
      const q = norm(S.query.trim());
      const items = S.ctx.creatures.filter((c) => (!S.onlyModified || settingOf(c.dbSymbol)) && (!q || String(c.id) === q.replace(/^0+/, '') || norm(c.name).includes(q) || c.dbSymbol.includes(q)));
      items.slice(0, 400).forEach((c) => {
        const v = valuesOf(c.dbSymbol);
        const st = settingOf(c.dbSymbol);
        list.appendChild(h('div', { class: 'pjs-item pjt-item' + (S.sel === c.dbSymbol ? ' active' : ''), onclick: () => { S.sel = c.dbSymbol; render(); } },
          h('span', { class: 'pjs-num pjt-num' }, String(c.id).padStart(3, '0')),
          h('span', { class: 'pjs-name' }, c.name),
          st && st.excluded ? h('span', { class: 'pjt-tag off' }, 'retirée') : (st ? h('span', { class: 'pjt-tag' }, 'modifiée') : null),
          h('span', { class: 'pjt-vals' }, v.map((x) => (x === 10 ? 'A' : x)).join(' '))));
      });
      if (items.length > 400) list.appendChild(h('div', { class: 'pjs-hint' }, `${items.length - 400} autres : affine la recherche.`));
    };
    search.addEventListener('input', () => { S.query = search.value; fill(); });
    fill();
    requestAnimationFrame(() => { const a = list.querySelector('.active'); if (a) a.scrollIntoView({ block: 'nearest' }); });
    row.appendChild(listBlock);
    // éditeur
    const block = h('div', { class: 'pjs-block pjt-editor' });
    row.appendChild(block);
    const c = creatureOf(S.sel);
    if (!c) { block.appendChild(h('div', { class: 'pjs-empty' }, 'Choisis un Pokémon.')); return; }
    const db = c.dbSymbol;
    const st = settingOf(db);
    const custom = customValues(db);
    const auto = autoValues(db);
    const parent = preEvolution(db);
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `${String(c.id).padStart(3, '0')} ${c.name}`),
      st ? h('button', { class: 'pjs-btn small', onclick: () => { delete S.config.cards[db]; resetAuto(); render(); } }, 'Tout remettre par défaut') : null));
    const cards = h('div', { class: 'pjt-preview' }, cardCanvas(db, 0), cardCanvas(db, 1));
    const values = valuesOf(db);
    const info = h('div', { class: 'pjt-info' },
      h('div', null, h('span', { class: 'pjs-label' }, 'Niveau '), `${levelOf(values) + 1} / 10`),
      h('div', null, h('span', { class: 'pjs-label' }, 'Total '), String(values.reduce((a, b) => a + b))),
      h('div', null, h('span', { class: 'pjs-label' }, 'Type '), c.type1 === 'normal' && c.type2 && c.type2 !== '__undef__' ? c.type2 : c.type1),
      h('div', null, h('span', { class: 'pjs-label' }, 'Prix '), `${priceOf(db)} $`),
      parent ? h('div', null, h('span', { class: 'pjs-label' }, 'Évolue de '), (creatureOf(parent) || { name: parent }).name, ' — au moins aussi forte') : null);
    block.appendChild(h('div', { class: 'pjt-top' }, cards, info));

    // valeurs
    const sec = h('div', { class: 'pjs-section' });
    sec.appendChild(h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: !!custom, onchange: (e) => {
      if (e.target.checked) setting(db).values = auto.slice(); else { delete setting(db).values; cleanSetting(db); }
      resetAuto(); render();
    } }), 'Valeurs personnalisées (sinon calculées depuis les stats de base)'));
    const grid = h('div', { class: 'pjt-values' });
    SIDES.forEach((side, i) => {
      const input = h('input', { class: 'pjs-input num', type: 'number', min: 1, max: 10, step: 1, value: values[i], disabled: !custom });
      input.addEventListener('input', () => {
        setting(db).values[i] = Math.min(10, Math.max(1, parseInt(input.value, 10) || 1));
        resetAuto(); updateStatus();
        block.querySelectorAll('.pjt-preview canvas').forEach((cv, k) => drawCard(cv, db, k));
      });
      input.addEventListener('change', () => render());
      grid.appendChild(h('label', null, h('span', { class: 'pjs-label' }, side), input, h('span', { class: 'pjs-hint inline' }, `auto : ${auto[i] === 10 ? 'A' : auto[i]}`)));
    });
    sec.appendChild(grid);
    sec.appendChild(h('div', { class: 'pjs-hint' }, 'Calcul : haut = Attaque + Vitesse / 3, droite = Défense + PV / 3, bas = Atq. Spé. + Vitesse / 3, gauche = Déf. Spé. + PV / 3 (de 1 à A = 10). Une évolution a toujours des valeurs au moins égales à celles du Pokémon dont elle évolue, et un total plus grand.'));
    block.appendChild(sec);
    // prix et retrait
    const sec2 = h('div', { class: 'pjs-section last' });
    const price = h('input', { class: 'pjs-input num', type: 'number', min: 0, step: 10, value: st && st.price ? st.price : '', placeholder: String(priceOf(db)) });
    price.addEventListener('input', () => { const v = parseInt(price.value, 10) || 0; if (v > 0) setting(db).price = v; else { delete setting(db).price; cleanSetting(db); } updateStatus(); });
    price.addEventListener('change', () => render());
    sec2.appendChild(h('label', { class: 'pjs-inline' }, 'Prix en boutique', price, h('span', { class: 'pjs-hint inline' }, 'vide : prix calculé')));
    sec2.appendChild(h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: !!(st && st.excluded), onchange: (e) => {
      if (e.target.checked) setting(db).excluded = true; else { delete setting(db).excluded; cleanSetting(db); } render();
    } }), 'Carte retirée (pas en boutique, jamais jouée par un adversaire au hasard)'));
    block.appendChild(sec2);
  }

  // --- Adversaires --------------------------------------------------------------
  function renderDecks(content) {
    const row = h('div', { class: 'pjs-row pjt-row' });
    content.appendChild(row);
    const decks = S.config.decks;
    const listBlock = h('div', { class: 'pjs-block pjt-list-block' });
    listBlock.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `Adversaires (${decks.length})`),
      h('button', { class: 'pjs-btn small', onclick: () => {
        let n = decks.length + 1; while (decks.some((d) => d.id === `adversaire_${n}`)) n++;
        decks.push({ id: `adversaire_${n}`, name: 'Adversaire', cards: [], rules: ['trade_one'], min_level: 0, max_level: 9 });
        S.deckIndex = decks.length - 1; render();
      } }, 'Ajouter')));
    const list = h('div', { class: 'pjt-list' });
    decks.forEach((d, i) => list.appendChild(h('div', { class: 'pjs-item pjt-item' + (i === S.deckIndex ? ' active' : ''), onclick: () => { S.deckIndex = i; render(); } },
      h('span', { class: 'pjs-name' }, d.name || d.id), h('span', { class: 'pjt-sub' }, d.id))));
    if (!decks.length) list.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun adversaire. « Ajouter » en crée un : nom, 5 cartes et règles, puis triple_triad_deck_duel(:id) dans un évent.'));
    listBlock.appendChild(list);
    row.appendChild(listBlock);
    const block = h('div', { class: 'pjs-block pjt-editor' });
    row.appendChild(block);
    const d = decks[S.deckIndex];
    if (!d) { block.appendChild(h('div', { class: 'pjs-empty' }, 'Choisis ou ajoute un adversaire.')); return; }
    d.cards = d.cards || []; d.rules = d.rules || [];
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, d.name || d.id),
      h('button', { class: 'pjs-btn small danger', onclick: () => { if (confirm(`Supprimer l'adversaire « ${d.name || d.id} » ?`)) { decks.splice(S.deckIndex, 1); S.deckIndex = 0; render(); } } }, 'Supprimer')));
    // identité
    const sec = h('div', { class: 'pjs-section pjt-form' });
    const idInput = h('input', { class: 'pjs-input', value: d.id });
    idInput.addEventListener('input', () => { d.id = idInput.value.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_'); cmd.textContent = command(d); updateStatus(); });
    idInput.addEventListener('change', () => { idInput.value = d.id; render(); });
    const nameInput = h('input', { class: 'pjs-input', value: d.name || '' });
    nameInput.addEventListener('input', () => { d.name = nameInput.value; updateStatus(); });
    nameInput.addEventListener('change', () => render());
    sec.appendChild(h('label', null, h('span', { class: 'pjs-label' }, 'Identifiant'), idInput));
    sec.appendChild(h('label', null, h('span', { class: 'pjs-label' }, 'Nom affiché'), nameInput));
    const cmd = h('code', { class: 'pjt-cmd', title: 'Cliquer pour copier' }, command(d));
    cmd.addEventListener('click', () => { navigator.clipboard && navigator.clipboard.writeText(cmd.textContent); toast('Commande copiée'); });
    sec.appendChild(h('label', { class: 'wide' }, h('span', { class: 'pjs-label' }, 'Commande d\'évent (Script)'), cmd));
    block.appendChild(sec);
    // cartes
    const sec2 = h('div', { class: 'pjs-section' });
    sec2.appendChild(h('div', { class: 'pjs-label' }, 'Cartes (vide : tirées au hasard selon les niveaux)'));
    const hand = h('div', { class: 'pjt-hand' });
    for (let i = 0; i < 5; i++) {
      const db = d.cards[i];
      hand.appendChild(h('div', { class: 'pjt-slot' },
        db && creatureOf(db) ? cardCanvas(db, 1, 2) : h('div', { class: 'pjt-empty-card' }, '?'),
        creatureCombo(db, (v) => { d.cards[i] = v; d.cards = d.cards.filter(Boolean); render(); }, 'Carte ' + (i + 1)),
        db ? h('button', { class: 'pjs-btn small', onclick: () => { d.cards.splice(i, 1); render(); } }, 'Retirer') : null));
    }
    sec2.appendChild(hand);
    const lv = (key, l) => {
      const input = h('input', { class: 'pjs-input num', type: 'number', min: 1, max: 10, value: (d[key] ?? (key === 'min_level' ? 0 : 9)) + 1 });
      input.addEventListener('input', () => { d[key] = Math.min(9, Math.max(0, (parseInt(input.value, 10) || 1) - 1)); updateStatus(); });
      return h('label', { class: 'pjs-inline' }, l, input);
    };
    sec2.appendChild(h('div', { class: 'pjs-inline pjt-levels' }, 'Cartes au hasard : niveau', lv('min_level', 'de'), lv('max_level', 'à'), h('span', { class: 'pjs-hint inline' }, 'sur 10 (complète les places vides)')));
    block.appendChild(sec2);
    // règles
    const sec3 = h('div', { class: 'pjs-section last' });
    sec3.appendChild(h('div', { class: 'pjs-label' }, 'Règles'));
    const rules = h('div', { class: 'pjt-rules' });
    RULES.forEach(([key, l, help]) => rules.appendChild(h('label', { class: 'pjs-inline', title: help }, h('input', { type: 'checkbox', checked: d.rules.includes(key), onchange: (e) => {
      d.rules = d.rules.filter((r) => r !== key); if (e.target.checked) d.rules.push(key); cmd.textContent = command(d); updateStatus();
    } }), l, h('span', { class: 'pjs-hint inline' }, help))));
    sec3.appendChild(rules);
    const trade = h('select', { class: 'pjs-select', onchange: (e) => { d.rules = d.rules.filter((r) => !r.startsWith('trade_')); d.rules.push(e.target.value); updateStatus(); } },
      TRADES.map(([k, l]) => h('option', { value: k, selected: (d.rules.find((r) => r.startsWith('trade_')) || 'trade_one') === k }, l)));
    sec3.appendChild(h('label', { class: 'pjs-inline' }, 'Échange à la fin', trade));
    block.appendChild(sec3);
  }
  const command = (d) => `triple_triad_deck_duel(:${d.id}, variable: 12)`;

  // --- Boutique et prix -----------------------------------------------------------
  function renderShop(content) {
    const row = h('div', { class: 'pjs-row' });
    content.appendChild(row);
    const block = h('div', { class: 'pjs-block pjs-block-half' });
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `Boutique par défaut (${S.config.shop.length})`)));
    block.appendChild(h('div', { class: 'pjs-hint inline' }, 'Cartes vendues par triple_triad_shop sans liste. Vide : les Pokémon vus dans le Pokédex (sauf les cartes retirées).'));
    block.appendChild(h('div', { class: 'pjt-add' }, creatureCombo(null, (v) => { if (!S.config.shop.includes(v)) S.config.shop.push(v); render(); }, 'Ajouter une carte…')));
    const chips = h('div', { class: 'pjt-chips' });
    S.config.shop.forEach((db, i) => {
      const c = creatureOf(db);
      chips.appendChild(h('div', { class: 'pjt-chip' }, cardCanvas(db, 0, 1), h('span', null, c ? c.name : db), h('span', { class: 'pjt-sub' }, `${priceOf(db)} $`),
        h('button', { class: 'pjt-x', title: 'Retirer', onclick: () => { S.config.shop.splice(i, 1); render(); } }, '×')));
    });
    block.appendChild(chips);
    row.appendChild(block);
    const prices = h('div', { class: 'pjs-block pjs-block-half' });
    prices.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Prix')));
    const examples = h('div', { class: 'pjt-examples' });
    const showExamples = () => {
      examples.textContent = '';
      ['bulbasaur', 'ivysaur', 'venusaur', 'pikachu', 'mewtwo'].filter(creatureOf).forEach((db) => examples.appendChild(h('div', null, creatureOf(db).name, h('span', null, `${priceOf(db)} $ — revente ${Math.floor(priceOf(db) * (+S.config.sell_ratio || 0.5))} $`))));
    };
    const slider = (key, l, min, max, step, fmt) => {
      const out = h('span', { class: 'pjt-val' }, fmt(+S.config[key]));
      const input = h('input', { type: 'range', class: 'pjt-range', min, max, step, value: S.config[key] });
      input.addEventListener('input', () => { S.config[key] = +input.value; out.textContent = fmt(+input.value); showExamples(); updateStatus(); });
      return h('div', { class: 'pjt-slider' }, h('span', { class: 'pjs-label' }, l), input, out);
    };
    prices.appendChild(h('div', { class: 'pjs-section' },
      slider('price_factor', 'Prix des cartes', 0.25, 4, 0.25, (v) => `x${v}`),
      slider('sell_ratio', 'Revente', 0, 1, 0.05, (v) => `${Math.round(v * 100)} %`)));
    prices.appendChild(h('div', { class: 'pjs-hint inline' }, 'Prix calculé : total des 4 valeurs² x 4 x facteur (100 $ minimum). Un prix fixé dans l\'onglet Cartes passe avant.'));
    prices.appendChild(examples);
    showExamples();
    row.appendChild(prices);
  }
  // ---------------------------------------------------------------------------
  // Page « Triple Triad » : Level design > Mini-jeux > Triple Triad (vraie page de Studio : /database/minigames/triple-triad)
  // (menu et routes ajoutés à Studio par tools/studio-plugins/patch_studio_pages.py)
  // ---------------------------------------------------------------------------
  const PAGE_ID = 'triple-triad';

  // raccourci clavier (Ctrl+Maj+T) : va sur la page
  function open() {
    if (window.pjNavigate) window.pjNavigate('/database/minigames/triple-triad');
    else toast('Ouvre un projet pour accéder au Triple Triad (Level design > Mini-jeux)', true);
  }

  function mount(hostEl) {
    root = h('div', { id: 'pjt-root' });
    // les touches tapées dans la page ne remontent pas jusqu'aux raccourcis de Studio
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = true;
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.config || (latest && latest !== S.projectPath && !dirty())) loadProject(latest || null); else render();
  }

  // page ouverte / quittée (les modifications non enregistrées restent gardées jusqu'au retour sur la page)
  function checkPage() {
    const hostEl = document.getElementById('pj-page-' + PAGE_ID);
    if (root && hostEl && hostEl.contains(root)) return;
    if (root) { root = null; S.open = false; }
    if (hostEl) mount(hostEl);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('keydown', (e) => {
    const k = e.key.toLowerCase();
    const typing = e.target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName);
    if (e.ctrlKey && e.shiftKey && k === 't' && !typing) { e.preventDefault(); open(); return; }
    if (!S.open) return;
    if (e.ctrlKey && k === 's') { e.preventDefault(); e.stopPropagation(); save(); }
  }, true);

  setInterval(() => { if (S.open) updateStatus(); }, 1000);

  window.pjTriadEditor = { open, state: S };
})();

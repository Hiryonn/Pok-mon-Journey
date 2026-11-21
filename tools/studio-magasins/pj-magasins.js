/* eslint-disable */
// =============================================================================
// Magasins — page « Level design > Interface > Boutique » de Pokémon Studio Extra (plugin « magasins »)
//   Magasins : comptoirs (liste par catégorie) et étalages (rayons + panier payé à la caisse) ; articles (objets,
//   Pokémon), prix, stocks et réassort, remises / majorations, objets offerts ; vendeurs (phrases au hasard) ;
//   monnaies (argent, jetons, variables).
// Enregistre Data/configs/plugins/magasins.json. Inspiré de « Arcky's Poke Market » (Essentials).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjMagasinsLoaded) return;
  window.__pjMagasinsLoaded = true;

  const PAGE_ID = 'magasins';
  const DEFAULTS = { klass: 'MagasinsConfig', money_speed: 12, currencies: [], sellers: [], shops: [] };
  const KINDS = [['list', 'Comptoir'], ['shelf', 'Étalage']];
  const RESTOCK = [['never', 'Jamais'], ['daily', 'Chaque jour'], ['hours', 'Toutes les N heures']];
  const CURRENCY_KINDS = [['money', 'Argent du joueur'], ['coins', 'Jetons du casino'], ['variable', 'Variable du jeu']];
  // Phrases des vendeurs : clé, libellé, valeurs utilisables, phrase par défaut
  const LINES = [
    ['welcome', 'Bienvenue', '{player}', 'Bienvenue ! Que puis-je pour toi ?'],
    ['ask_quantity', 'Demande la quantité', '{item} {price} {currency}', '{item} ? Combien en veux-tu ?'],
    ['confirm', 'Confirmation', '{item} {qty} {total} {currency}', "{qty} {item}, ça fera {total} {currency}. D'accord ?"],
    ['thanks', 'Merci (achat fait)', '{item} {qty} {total} {currency} {player}', 'Merci beaucoup !'],
    ['bonus', 'Objet offert', '{bonus}', 'En cadeau, voici aussi {bonus} !'],
    ['no_money', "Pas assez d'argent", '{item}', "Tu n'as pas assez d'argent."],
    ['out_of_stock', 'Rupture de stock', '{item}', "Désolé, il n'y a plus de {item} en stock."],
    ['bag_full', 'Sac plein', '{item}', 'Tu ne peux pas en porter plus.'],
    ['sell', 'Vente au vendeur', '', 'Que veux-tu me vendre ?'],
    ['goodbye', 'Au revoir', '{player}', 'À bientôt !'],
  ];
  const POCKETS = [[1, 'Objets'], [6, 'Soins'], [2, 'Poké Balls'], [3, 'CT & CS'], [4, 'Baies'], [8, 'Objets de combat'], [7, 'Lettres'], [5, 'Objets rares']];
  const POCKET_ICON = { 1: 0, 2: 2, 3: 3, 4: 4, 5: 7, 6: 1, 7: 5, 8: 6 };

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjMagasins;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API des Magasins n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const slug = (t) => plain(t).replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 40) || 'magasin';
  const txt = (v, lang = 'fr') => (v && typeof v === 'object' && !Array.isArray(v) ? (v[lang] || v.fr || v.en || '') : String(v || ''));
  const num = (v) => (v === '' || v === null || v === undefined || Number.isNaN(+v) ? null : Math.round(+v));
  const fmt = (n) => String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  let toastTimer = null;
  function toast(msg, err) {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.remove(), err ? 6000 : 2500);
  }
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  const imageCache = new Map();
  function loadImage(rel) {
    if (!imageCache.has(rel)) {
      imageCache.set(rel, call('readImage', { projectPath: S.projectPath, file: rel }).then((url) => new Promise((ok) => {
        if (!url) { ok(null); return; }
        const im = new Image(); im.onload = () => ok(im); im.onerror = () => ok(null); im.src = url;
      })).catch(() => null));
    }
    return imageCache.get(rel);
  }
  function copy(t) { try { navigator.clipboard.writeText(t); toast('Copié'); } catch (e) { /* rien */ } }

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = { open: false, projectPath: null, ctx: null, config: null, saved: null, error: null, building: false, tab: 'shops', shop: null, seller: null, search: '', cursor: 0 };
  let root = null;
  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => S.config && S.saved !== snapshot();
  const itemOf = (db) => S.ctx.items.find((i) => i.db === db);
  const creatureOf = (db) => S.ctx.creatures.find((c) => c.db === db);
  const shops = () => S.config.shops;
  const currentShop = () => shops().find((s) => s.id === S.shop);
  const currentSeller = () => S.config.sellers.find((s) => s.id === S.seller);
  const currencyOf = (id) => S.config.currencies.find((c) => c.id === id) || { id: 'money', kind: 'money', symbol: 'P', name: { fr: 'Argent', en: 'Money' } };
  const autoIds = new Set();

  function uniqueId(list, base, except) {
    let id = slug(base); let n = 2;
    while (list.some((x) => x !== except && x.id === id)) id = `${slug(base)}_${n++}`;
    return id;
  }
  function normalize(c) {
    if (!Array.isArray(c.currencies)) c.currencies = [];
    if (!c.currencies.some((x) => x.id === 'money')) c.currencies.unshift({ id: 'money', kind: 'money', symbol: 'P', name: { fr: 'Argent', en: 'Money' } });
    c.currencies.forEach((x) => { x.name = Object.assign({ fr: '', en: '' }, typeof x.name === 'object' ? x.name : { fr: x.name || '' }); });
    if (!Array.isArray(c.sellers)) c.sellers = [];
    c.sellers.forEach((s) => {
      s.name = Object.assign({ fr: '', en: '' }, typeof s.name === 'object' ? s.name : { fr: s.name || '' });
      s.lines = s.lines || {};
      LINES.forEach(([k]) => { const l = s.lines[k] || {}; s.lines[k] = { fr: Array.isArray(l.fr) ? l.fr : [], en: Array.isArray(l.en) ? l.en : [] }; });
    });
    if (!Array.isArray(c.shops)) c.shops = [];
    c.shops.forEach((s) => {
      s.name = Object.assign({ fr: '', en: '' }, typeof s.name === 'object' ? s.name : { fr: s.name || '' });
      s.kind = s.kind === 'shelf' ? 'shelf' : 'list';
      s.currency = s.currency || 'money';
      s.restock = Object.assign({ mode: 'never', hours: 24 }, s.restock || {});
      if (!Array.isArray(s.entries)) s.entries = [];
      if (!Array.isArray(s.bonus)) s.bonus = [];
      s.modifier = s.modifier | 0;
      s.modifier_switch = s.modifier_switch | 0;
    });
    return c;
  }

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null;
    imageCache.clear();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      S.config = normalize(Object.assign(clone(DEFAULTS), S.ctx.config || {}));
      S.saved = S.ctx.config ? snapshot() : null;
      if (!currentShop()) S.shop = shops()[0] && shops()[0].id;
      if (!currentSeller()) S.seller = S.config.sellers[0] && S.config.sellers[0].id;
    } catch (e) { S.error = e.message; }
    render();
  }
  function problems() {
    const out = [];
    shops().forEach((s) => {
      if (!txt(s.name).trim()) out.push(`Le magasin « ${s.id} » n'a pas de nom.`);
      if (s.kind === 'shelf' && s.entries.filter((e) => e.type !== 'pokemon').length > 18) out.push(`« ${txt(s.name)} » : un étalage a au plus 18 objets (3 rayons de 6).`);
      s.entries.forEach((e) => { if (e.type === 'pokemon' ? !e.species : !e.item) out.push(`« ${txt(s.name)} » : un article n'est pas choisi.`); });
    });
    S.config.currencies.forEach((c) => { if (c.kind === 'variable' && !(c.variable > 0)) out.push(`La monnaie « ${txt(c.name) || c.id} » n'a pas de numéro de variable.`); });
    return out;
  }
  // Retire les champs vides avant d'enregistrer
  function cleaned() {
    const c = clone(S.config);
    c.shops.forEach((s) => {
      s.entries = s.entries.map((e) => {
        const o = {};
        Object.entries(e).forEach(([k, v]) => { if (v !== null && v !== '' && v !== undefined && !(k === 'shiny' && !v) && !(['badges', 'switch'].includes(k) && !v)) o[k] = v; });
        return o;
      });
    });
    c.sellers.forEach((s) => {
      Object.keys(s.lines).forEach((k) => {
        const l = s.lines[k];
        l.fr = l.fr.map((x) => x.trim()).filter(Boolean); l.en = l.en.map((x) => x.trim()).filter(Boolean);
        if (!l.fr.length && !l.en.length) delete s.lines[k];
      });
    });
    return c;
  }
  async function save() {
    if (!S.config) return;
    const p = problems();
    if (p.length) { toast('À corriger avant d\'enregistrer : ' + p[0], true); return; }
    try {
      const data = cleaned();
      const r = await call('save', { projectPath: S.projectPath, config: data });
      S.saved = snapshot();
      const pl = r.plugin || {};
      if (pl.source) S.ctx.plugin = { source: true, installed: pl.installed };
      toast('Enregistré' + (pl.source && !pl.installed ? ' — plugin pas encore installé : lance construire_plugins.bat une fois' : ''));
      render();
      if (pl.source && pl.installed) rebuildPlugin();
    } catch (e) { toast('Erreur de sauvegarde : ' + e.message, true); }
  }
  async function rebuildPlugin() {
    if (S.building) return;
    S.building = true; updateStatus();
    try { const r = await call('buildPlugin', { projectPath: S.projectPath }); if (!r.built) toast('Plugin non reconstruit : ' + (r.error || '?'), true); } catch (e) { toast('Plugin non reconstruit : ' + e.message, true); }
    S.building = false; updateStatus();
  }
  function statusText() {
    if (!S.config) return ['', ''];
    if (S.building) return ['Mise à jour du plugin…', ' busy'];
    if (dirty()) return ['Modifications non enregistrées', ' dirty'];
    return [S.saved ? 'Enregistré' : 'Pas encore enregistré', ''];
  }
  function updateStatus() {
    const el = root && root.querySelector('.pjs-status');
    if (!el) return;
    const [t, cls] = statusText();
    el.textContent = t; el.className = 'pjs-status' + cls;
  }
  const set = (fn) => { fn(); render(); };
  const soft = (fn) => { fn(); updateStatus(); const cv = root && root.querySelector('.pjmg-canvas'); if (cv) drawPreview(cv); };

  // ---------------------------------------------------------------------------
  // Prix (même calcul que le jeu)
  // ---------------------------------------------------------------------------
  const basePrice = (e) => (num(e.price) !== null ? num(e.price) : e.type === 'pokemon' ? 0 : ((itemOf(e.item) || {}).price | 0));
  const modOf = (s, e) => (num(e.modifier) !== null ? num(e.modifier) : (s.modifier | 0));
  function priceOf(s, e) {
    const b = basePrice(e); const m = modOf(s, e);
    return m === 0 ? b : Math.max(Math.round(b * (100 + m) / 100), b > 0 ? 1 : 0);
  }
  const nameOf = (e) => (e.type === 'pokemon' ? `${(creatureOf(e.species) || {}).name || e.species || '?'} N.${Math.max(e.level | 0, 1)}` : (itemOf(e.item) || {}).name || e.item || '?');
  const pocketOf = (e) => (e.type === 'pokemon' ? 0 : ((itemOf(e.item) || {}).socket | 0) || 1);
  const amountText = (s, v) => { const c = currencyOf(s.currency); return c.symbol ? `${fmt(v)} ${c.symbol}` : fmt(v); };

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    const prevList = root.querySelector('.pjmg-list');
    const listScroll = prevList ? prevList.scrollTop : 0;
    const prev = root.querySelector('.pjmg-detail');
    const scroll = prev ? prev.scrollTop : 0;
    const focused = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.focus : null;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Boutique'),
        h('div', { class: 'pjmg-tabs pjmg-maintabs' }, [['shops', 'Magasins'], ['sellers', 'Vendeurs'], ['currencies', 'Monnaies']].map(([k, l]) =>
          h('button', { class: 'pjs-btn small ' + (S.tab === k ? 'primary' : 'secondary'), onclick: () => set(() => { S.tab = k; }) }, l))),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    if (S.error) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty err' }, S.error))); return; }
    if (!S.config) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty' }, 'Chargement…'))); return; }
    const body = h('div', { class: 'pjmg-body' + (S.tab === 'currencies' ? ' single' : '') });
    root.appendChild(body);
    if (S.tab === 'shops') renderShopsTab(body);
    else if (S.tab === 'sellers') renderSellersTab(body);
    else renderCurrenciesTab(body);
    const detail = root.querySelector('.pjmg-detail');
    if (detail) detail.scrollTop = scroll;
    const l = root.querySelector('.pjmg-list');
    if (l) l.scrollTop = listScroll;
    if (focused) { const el = root.querySelector(`[data-focus="${focused}"]`); if (el) { el.focus(); if (el.setSelectionRange && typeof el.value === 'string' && el.type !== 'number') el.setSelectionRange(el.value.length, el.value.length); } }
  }

  const block = (title, extra, ...kids) => h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title), extra || null), kids);
  const field = (label, input, hint) => h('label', { class: 'pjmg-field' }, h('span', { class: 'pjs-label' }, label), input, hint ? h('span', { class: 'pjs-hint inline' }, hint) : null);
  const select = (options, value, onchange, focus) => { const s = h('select', { class: 'pjs-input', onchange: (e) => onchange(e.target.value), 'data-focus': focus }, options.map(([v, l]) => h('option', { value: v }, l))); s.value = value; return s; };
  const numInput = (value, onInput, attrs = {}) => h('input', Object.assign({ class: 'pjs-input', type: 'number', value: value === null || value === undefined ? '' : value, oninput: (e) => soft(() => onInput(e.target.value === '' ? null : +e.target.value)) }, attrs));
  function iconSpan(rel, cls = 'pjmg-ico', square) {
    const el = h('span', { class: cls });
    if (rel) loadImage(rel).then((im) => {
      if (!im) return;
      if (square && im.width > im.height) { const c = document.createElement('canvas'); c.width = c.height = im.height; c.getContext('2d').drawImage(im, 0, 0); el.style.backgroundImage = `url("${c.toDataURL()}")`; } else el.style.backgroundImage = `url("${im.src}")`;
    });
    return el;
  }
  const entryIcon = (e) => (e.type === 'pokemon' ? (creatureOf(e.species) ? iconSpan(`graphics/pokedex/pokeicon/${creatureOf(e.species).icon}`, 'pjmg-ico', true) : iconSpan(null)) : iconSpan(itemOf(e.item) && itemOf(e.item).icon ? `graphics/icons/${itemOf(e.item).icon}` : null));
  // Liste déroulante avec recherche (objets ou Pokémon)
  function picker(options, value, onPick, numbered) {
    const wrapEl = h('div', { class: 'pjmg-picker' });
    const sel = h('select', { class: 'pjs-input', onchange: (e) => onPick(e.target.value) });
    const fill = (q) => {
      sel.textContent = '';
      const qq = plain(q);
      let shown = options.filter((o) => !qq || plain(o.name).includes(qq) || o.db.includes(qq)).slice(0, 400);
      const cur = options.find((o) => o.db === value);
      if (cur && !shown.includes(cur)) shown = [cur].concat(shown);
      shown.forEach((o) => sel.appendChild(h('option', { value: o.db }, (numbered ? String(o.id).padStart(4, '0') + ' ' : '') + o.name)));
      if (!cur) sel.insertBefore(h('option', { value: '' }, '— choisir —'), sel.firstChild);
      sel.value = cur ? value : '';
    };
    wrapEl.appendChild(h('input', { class: 'pjs-input pjmg-psearch', placeholder: 'Filtrer…', oninput: (e) => fill(e.target.value) }));
    wrapEl.appendChild(sel);
    fill('');
    return wrapEl;
  }
  function warnings(content) {
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/magasins est introuvable.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, "Le plugin « magasins » n'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul)."));
  }

  // --- Onglet Magasins ------------------------------------------------------------------------------
  function renderShopsTab(body) {
    const side = h('div', { class: 'pjmg-side' });
    side.appendChild(h('div', { class: 'pjmg-addrow' },
      h('button', { class: 'pjs-btn primary', onclick: () => addShop('list') }, '+ Comptoir'),
      h('button', { class: 'pjs-btn primary', onclick: () => addShop('shelf') }, '+ Étalage')));
    side.appendChild(h('input', { class: 'pjs-input', placeholder: 'Rechercher…', value: S.search, 'data-focus': 'search', oninput: (e) => { S.search = e.target.value; render(); } }));
    const list = h('div', { class: 'pjmg-list' });
    side.appendChild(list);
    const q = plain(S.search);
    shops().forEach((s, i) => {
      if (q && !plain(txt(s.name)).includes(q) && !s.id.includes(q)) return;
      list.appendChild(h('div', { class: 'pjmg-entry' + (s.id === S.shop ? ' active' : ''), 'data-id': s.id, onclick: () => set(() => { S.shop = s.id; S.cursor = 0; }) },
        h('span', { class: 'pjmg-kind ' + s.kind }, s.kind === 'shelf' ? 'É' : 'C'),
        h('span', { class: 'pjmg-ename' }, h('span', { class: 'pjmg-name' }, txt(s.name) || s.id),
          h('span', { class: 'pjmg-sub' }, `${s.kind === 'shelf' ? 'Étalage' : 'Comptoir'} · ${s.entries.length} article${s.entries.length > 1 ? 's' : ''}${s.modifier ? ` · ${s.modifier > 0 ? '+' : ''}${s.modifier} %` : ''}`)),
        h('span', { class: 'pjmg-move' },
          h('button', { class: 'pjmg-x', title: 'Monter', disabled: i === 0, onclick: (e) => { e.stopPropagation(); set(() => { [shops()[i - 1], shops()[i]] = [shops()[i], shops()[i - 1]]; }); } }, '▲'),
          h('button', { class: 'pjmg-x', title: 'Descendre', disabled: i === shops().length - 1, onclick: (e) => { e.stopPropagation(); set(() => { [shops()[i + 1], shops()[i]] = [shops()[i], shops()[i + 1]]; }); } }, '▼'))));
    });
    if (!shops().length) list.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun magasin.'));
    body.appendChild(side);
    const detail = h('div', { class: 'pjmg-detail' });
    body.appendChild(detail);
    const content = h('div', { class: 'pjmg-content' });
    detail.appendChild(content);
    warnings(content);
    const s = currentShop();
    if (!s) { content.appendChild(h('div', { class: 'pjs-empty' }, 'Crée un comptoir (liste par catégorie) ou un étalage (rayons et panier).')); content.appendChild(renderCommands(null)); return; }
    const row = h('div', { class: 'pjmg-row' });
    content.appendChild(row);
    row.appendChild(renderPreview(s));
    const right = h('div', { class: 'pjmg-right' });
    row.appendChild(right);
    right.appendChild(renderShopGeneral(s));
    right.appendChild(renderPrices(s));
    content.appendChild(renderEntries(s));
    content.appendChild(renderBonus(s));
    content.appendChild(renderCommands(s));
  }
  function addShop(kind) {
    const s = { id: '', name: { fr: kind === 'shelf' ? 'Nouvel étalage' : 'Nouveau comptoir', en: '' }, kind, currency: 'money', seller: kind === 'list' ? ((S.config.sellers[0] || {}).id || '') : '', modifier: 0, modifier_switch: 0, restock: { mode: 'never', hours: 24 }, entries: [], bonus: [] };
    s.id = uniqueId(shops(), txt(s.name));
    autoIds.add(s.id);
    shops().push(s);
    S.shop = s.id; S.cursor = 0;
    render();
    const el = root.querySelector('[data-focus="shop-name"]'); if (el) { el.focus(); el.select(); }
  }
  function followName(list, obj, key) {
    if (!autoIds.has(obj.id) || !txt(obj.name).trim()) return;
    const id = uniqueId(list, txt(obj.name), obj);
    if (id === obj.id) return;
    const old = obj.id;
    autoIds.delete(old); autoIds.add(id); obj.id = id; S[key] = id;
    const entry = root.querySelector(`.pjmg-entry[data-id="${CSS.escape(old)}"]`);
    if (entry) { entry.dataset.id = id; const n = entry.querySelector('.pjmg-name'); if (n) n.textContent = txt(obj.name); }
    const input = root.querySelector('[data-focus="id"]'); if (input) input.value = id;
  }

  function renderShopGeneral(s) {
    const box = block(s.kind === 'shelf' ? 'Étalage' : 'Comptoir', h('div', { class: 'pjmg-actions' },
      h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { const c = clone(s); c.id = uniqueId(shops(), c.id); c.name.fr += ' (copie)'; shops().splice(shops().indexOf(s) + 1, 0, c); S.shop = c.id; }) }, 'Dupliquer'),
      h('button', { class: 'pjs-btn small danger', onclick: () => { if (confirm(`Supprimer « ${txt(s.name)} » ?`)) set(() => { const i = shops().indexOf(s); shops().splice(i, 1); S.shop = (shops()[i] || shops()[i - 1] || {}).id; }); } }, 'Supprimer')));
    box.appendChild(h('div', { class: 'pjmg-grid2' },
      field('Nom (français)', h('input', { class: 'pjs-input', 'data-focus': 'shop-name', value: s.name.fr, oninput: (e) => soft(() => { s.name.fr = e.target.value; followName(shops(), s, 'shop'); const n = root.querySelector(`.pjmg-entry[data-id="${CSS.escape(s.id)}"] .pjmg-name`); if (n) n.textContent = s.name.fr || s.id; }) })),
      field('Nom (anglais)', h('input', { class: 'pjs-input', 'data-focus': 'shop-name-en', placeholder: s.name.fr, value: s.name.en, oninput: (e) => soft(() => { s.name.en = e.target.value; }) }))));
    const sellers = [['', 'Phrases par défaut']].concat(S.config.sellers.map((x) => [x.id, txt(x.name) || x.id]));
    box.appendChild(h('div', { class: 'pjmg-grid4' },
      field('Type', select(KINDS, s.kind, (v) => set(() => { s.kind = v; if (v === 'shelf') s.entries = s.entries.filter((e) => e.type !== 'pokemon'); }))),
      field('Monnaie', select(S.config.currencies.map((c) => [c.id, txt(c.name) || c.id]), s.currency, (v) => set(() => { s.currency = v; }))),
      s.kind === 'list' ? field('Vendeur', select(sellers, s.seller || '', (v) => set(() => { s.seller = v; }))) : h('div', { class: 'pjmg-field' }, h('span', { class: 'pjs-label' }, 'Vendeur'), h('span', { class: 'pjs-hint inline' }, 'à la caisse : magasin_caisse(:vendeur)')),
      field('Identifiant', h('input', { class: 'pjs-input pjmg-mono', 'data-focus': 'id', value: s.id, onchange: (e) => set(() => { const id = uniqueId(shops(), e.target.value || txt(s.name), s); autoIds.delete(s.id); s.id = id; S.shop = id; }) }), 'pour les commandes')));
    box.appendChild(h('div', { class: 'pjs-hint' }, s.kind === 'shelf'
      ? 'Étalage : les objets sont posés sur 3 rayons de 6. Le joueur les met dans son panier, puis paye à la caisse (évènement avec magasin_caisse).'
      : 'Comptoir : le vendeur propose Acheter / Vendre / Quitter ; les articles sont rangés par catégorie (poches du sac, puis Pokémon).'));
    return box;
  }

  function renderPrices(s) {
    const box = block('Prix et stock');
    box.appendChild(h('div', { class: 'pjmg-grid4' },
      field('Remise / majoration', numInput(s.modifier || 0, (v) => { s.modifier = v || 0; }, { 'data-focus': 'mod', min: -99, max: 900 }), '% (-20 = 20 % moins cher)'),
      field('Seulement si l\'interrupteur', numInput(s.modifier_switch || '', (v) => { s.modifier_switch = v || 0; }, { 'data-focus': 'modsw', min: 0, placeholder: 'toujours' }), 'n° (vide = toujours)'),
      field('Réassort des stocks', select(RESTOCK, s.restock.mode, (v) => set(() => { s.restock.mode = v; }))),
      s.restock.mode === 'hours' ? field('Toutes les', numInput(s.restock.hours, (v) => { s.restock.hours = Math.max(1, v | 0); }, { 'data-focus': 'hours', min: 1 }), 'heures') : h('div')));
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Les stocks se règlent article par article (vide = illimité). Le réassort remet les stocks au complet (heure de l\'ordinateur).'));
    return box;
  }

  function renderEntries(s) {
    const shelf = s.kind === 'shelf';
    const box = block(shelf ? `Objets de l'étalage (${s.entries.length} / 18)` : 'Articles', h('div', { class: 'pjmg-actions' },
      h('button', { class: 'pjs-btn small secondary', disabled: shelf && s.entries.length >= 18, onclick: () => set(() => { s.entries.push({ type: 'item', item: 'potion' }); S.cursor = s.entries.length - 1; }) }, '+ Objet'),
      shelf ? null : h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { s.entries.push({ type: 'pokemon', species: (S.ctx.creatures[0] || {}).db, level: 5, form: 0, price: 1000, stock: 1 }); }) }, '+ Pokémon')));
    if (!s.entries.length) box.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun article.'));
    const table = h('div', { class: 'pjmg-table' });
    table.appendChild(h('div', { class: 'pjmg-thead' }, h('span'), h('span', null, 'Article'), h('span', null, 'Prix'), h('span', null, 'Stock'), h('span', null, 'Badges'), h('span', null, 'Interr.'), h('span', null, 'Remise %'), h('span')));
    s.entries.forEach((e, i) => {
      const item = itemOf(e.item);
      const pk = e.type === 'pokemon';
      const def = pk ? '' : String((item || {}).price | 0);
      const rowEl = h('div', { class: 'pjmg-trow' + (i === S.cursor ? ' sel' : ''), onclick: (ev) => { if (ev.target.closest('input,select,button')) return; set(() => { S.cursor = i; }); } },
        entryIcon(e),
        h('div', { class: 'pjmg-cell-item' },
          pk ? picker(S.ctx.creatures, e.species, (v) => set(() => { e.species = v; }), true) : picker(S.ctx.items, e.item, (v) => set(() => { e.item = v; })),
          pk ? h('div', { class: 'pjmg-pkopts' },
            h('label', null, 'N.', numInput(e.level, (v) => { e.level = Math.min(100, Math.max(1, v | 0)); }, { 'data-focus': `lv-${i}`, min: 1, max: 100 })),
            h('label', null, 'Forme', numInput(e.form || 0, (v) => { e.form = Math.max(0, v | 0); }, { 'data-focus': `fo-${i}`, min: 0 })),
            h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: !!e.shiny, onchange: (ev) => set(() => { e.shiny = ev.target.checked; }) }), 'Chromatique')) : null),
        numInput(e.price, (v) => { e.price = v; }, { 'data-focus': `pr-${i}`, min: 0, placeholder: def || 'prix' }),
        numInput(e.stock, (v) => { e.stock = v === null ? null : Math.max(0, v | 0); }, { 'data-focus': `st-${i}`, min: 0, placeholder: '∞' }),
        numInput(e.badges || '', (v) => { e.badges = v || 0; }, { 'data-focus': `ba-${i}`, min: 0, max: 99, placeholder: '0' }),
        numInput(e.switch || '', (v) => { e.switch = v || 0; }, { 'data-focus': `sw-${i}`, min: 0, placeholder: '—' }),
        numInput(e.modifier, (v) => { e.modifier = v; }, { 'data-focus': `mo-${i}`, min: -99, max: 900, placeholder: String(s.modifier || 0) }),
        h('span', { class: 'pjmg-move' },
          h('button', { class: 'pjmg-x', title: 'Monter', disabled: i === 0, onclick: () => set(() => { [s.entries[i - 1], s.entries[i]] = [s.entries[i], s.entries[i - 1]]; S.cursor = i - 1; }) }, '▲'),
          h('button', { class: 'pjmg-x', title: 'Descendre', disabled: i === s.entries.length - 1, onclick: () => set(() => { [s.entries[i + 1], s.entries[i]] = [s.entries[i], s.entries[i + 1]]; S.cursor = i + 1; }) }, '▼'),
          h('button', { class: 'pjmg-x', title: 'Retirer', onclick: () => set(() => { s.entries.splice(i, 1); S.cursor = Math.max(0, Math.min(S.cursor, s.entries.length - 1)); }) }, '✕')));
      table.appendChild(rowEl);
    });
    box.appendChild(table);
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Prix vide : prix de l\'objet (Données > Objets). Badges : nombre de badges pour que l\'article apparaisse. Interr. : visible seulement si l\'interrupteur est activé. Remise % vide : celle du magasin.'));
    return box;
  }

  function renderBonus(s) {
    const box = block('Objets offerts', h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { s.bonus.push({ buy: 'poke_ball', count: 10, give: 'premier_ball', amount: 1, repeat: true }); }) }, '+ Offre'));
    if (!s.bonus.length) box.appendChild(h('div', { class: 'pjs-hint' }, 'Exemple : pour 10 Poké Balls achetées, une Honor Ball offerte.'));
    s.bonus.forEach((b, i) => {
      box.appendChild(h('div', { class: 'pjmg-bonus' },
        h('span', { class: 'pjs-hint inline' }, 'Pour'),
        numInput(b.count, (v) => { b.count = Math.max(1, v | 0); }, { 'data-focus': `bc-${i}`, min: 1, class: 'pjs-input pjmg-small' }),
        iconSpan(itemOf(b.buy) && itemOf(b.buy).icon ? `graphics/icons/${itemOf(b.buy).icon}` : null),
        picker(S.ctx.items, b.buy, (v) => set(() => { b.buy = v; })),
        h('span', { class: 'pjs-hint inline' }, 'achetés :'),
        numInput(b.amount, (v) => { b.amount = Math.max(1, v | 0); }, { 'data-focus': `ba2-${i}`, min: 1, class: 'pjs-input pjmg-small' }),
        iconSpan(itemOf(b.give) && itemOf(b.give).icon ? `graphics/icons/${itemOf(b.give).icon}` : null),
        picker(S.ctx.items, b.give, (v) => set(() => { b.give = v; })),
        h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: b.repeat !== false, onchange: (ev) => set(() => { b.repeat = ev.target.checked; }) }), 'à chaque fois'),
        h('button', { class: 'pjmg-x', title: 'Retirer', onclick: () => set(() => { s.bonus.splice(i, 1); }) }, '✕')));
    });
    box.appendChild(h('div', { class: 'pjs-hint' }, '« à chaque fois » : 20 achetés = 2 offerts. Au comptoir l\'offre compte par achat ; à l\'étalage, par passage en caisse.'));
    return box;
  }

  function renderCommands(s) {
    const id = s ? s.id : 'boutique';
    const seller = (S.config.sellers[0] || {}).id;
    const cmds = [
      [`magasin(:${id})`, s && s.kind === 'shelf' ? "ouvre l'étalage (évènement posé sur le rayon)" : 'ouvre le magasin (évènement du vendeur)'],
      ['magasin_caisse' + (seller ? `(:${seller})` : ''), 'passage en caisse : paye le panier des étalages (true si payé)'],
      ['magasin_panier_vide?', 'true si le panier est vide (pour bloquer la sortie du magasin)'],
      ['magasin_vider_panier', 'repose tout (vide le panier)'],
      ['magasin_total', 'total du panier en argent'],
      [`magasin_reassort(:${id})`, 'remet le stock du magasin au complet'],
    ];
    return block('Commandes d\'évènement (Script)', null, h('div', { class: 'pjmg-cmds' }, cmds.map(([c, hint]) => h('div', { class: 'pjmg-cmdrow' },
      h('code', { class: 'pjmg-cmd', title: 'Cliquer pour copier', onclick: () => copy(c) }, c), h('span', { class: 'pjs-hint inline' }, hint)))));
  }

  // --- Aperçu (écran du jeu, 320 x 240) ----------------------------------------------------------------
  function renderPreview(s) {
    const box = h('div', { class: 'pjs-block pjmg-preview' });
    box.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Aperçu en jeu')));
    const cv = h('canvas', { class: 'pjmg-canvas', width: 320, height: 240 });
    box.appendChild(cv);
    drawPreview(cv);
    box.appendChild(h('div', { class: 'pjs-hint' }, s.kind === 'shelf'
      ? 'Le curseur rouge montre le prix ; A met l\'objet dans le panier (le total défile). La carte du jeu reste visible à gauche.'
      : 'Gauche / droite changent de catégorie ; A demande la quantité puis confirme. L\'argent défile doucement après l\'achat.'));
    return box;
  }
  let drawToken = 0;
  async function drawPreview(cv) {
    const token = ++drawToken;
    const s = currentShop();
    if (!s) return;
    const img = (n) => loadImage('graphics/interface/' + n);
    const names = ['horizon/team/fond', 'magasins/window', 'magasins/list', 'magasins/cursor', 'magasins/shelf', 'magasins/shelf_cursor', 'magasins/tag_discount', 'magasins/tag_overcharge', 'bag_horizon/info', 'bag_horizon/pockets'];
    const I = {};
    (await Promise.all(names.map(img))).forEach((im, i) => { I[names[i].split('/').pop()] = im; });
    const entries = s.entries.filter((e) => (e.type === 'pokemon' ? e.species : e.item));
    const icons = await Promise.all(entries.map((e) => (e.type === 'pokemon' ? (creatureOf(e.species) ? loadImage(`graphics/pokedex/pokeicon/${creatureOf(e.species).icon}`) : null) : (itemOf(e.item) && itemOf(e.item).icon ? loadImage(`graphics/icons/${itemOf(e.item).icon}`) : null))));
    if (token !== drawToken) return;
    const c = cv.getContext('2d');
    c.imageSmoothingEnabled = false;
    const draw = (im, x, y) => { if (im) c.drawImage(im, x, y); };
    const text = (str, x, y, o = {}) => { c.font = `${o.small ? 9 : 11}px "Avenir Next", sans-serif`; c.fillStyle = o.color || '#282828'; c.textBaseline = 'top'; c.textAlign = o.align || 'left'; c.globalAlpha = o.alpha || 1; c.fillText(str, x, y); c.globalAlpha = 1; };
    const icon = (im, x, y, poke) => { if (!im) return; const w = poke && im.width > im.height ? im.height : im.width; c.drawImage(im, 0, 0, w, im.height, x + Math.floor((32 - w) / 2), y + Math.floor((32 - im.height) / 2), w, im.height); };
    c.fillStyle = '#e5f3fa'; c.fillRect(0, 0, 320, 240);
    draw(I.fond, 0, 0);
    // la carte derrière (aperçu)
    c.fillStyle = 'rgba(214,170,110,.55)'; c.fillRect(0, 0, 118, 192);
    const cur = currencyOf(s.currency);
    const shelf = s.kind === 'shelf';
    draw(I.window, 4, 4); text(shelf ? 'Total' : (txt(cur.name) || 'Argent'), 10, 7, { small: true }); text(shelf ? amountText(s, 0) : amountText(s, 3000), 110, 21, { align: 'right' });
    draw(I.window, 4, 150); text(shelf ? 'Panier' : 'Dans le sac', 10, 153, { small: true }); text('0', 110, 167, { align: 'right' });
    draw(I.info, 0, 193);
    const sel = Math.min(S.cursor, Math.max(entries.length - 1, 0));
    const e0 = entries[sel];
    if (shelf) {
      draw(I.shelf, 120, 4);
      entries.slice(0, 18).forEach((e, i) => {
        const x = 125 + (i % 6) * 31; const y = 4 + Math.floor(i / 6) * 58 + 14;
        icon(icons[i], x, y, false);
        if (i === sel) { draw(I.shelf_cursor, x - 1, y - 4); text(fmt(priceOf(s, e)), x + 16, y + 35, { small: true, color: '#fff', align: 'center' }); }
      });
    } else {
      draw(I.list, 120, 4);
      const groups = POCKETS.map(([p, n]) => [p, n]).concat([[0, 'Pokémon']]).filter(([p]) => entries.some((e) => pocketOf(e) === p));
      const g = groups.find(([p]) => e0 && pocketOf(e0) === p) || groups[0];
      if (g) {
        if (I.pockets && POCKET_ICON[g[0]] !== undefined) c.drawImage(I.pockets, POCKET_ICON[g[0]] * 14, 14, 14, 14, 124, 6, 14, 14);
        text(g[1], 142, 7, { color: '#fff' });
        text(`Page ${groups.indexOf(g) + 1}/${groups.length}`, 310, 9, { small: true, color: '#fff', align: 'right' });
        const rows = entries.map((e, i) => [e, i]).filter(([e]) => pocketOf(e) === g[0]).slice(0, 10);
        rows.forEach(([e, i], r) => {
          const y = 24 + r * 16;
          if (i === sel) draw(I.cursor, 122, y - 1);
          const mod = modOf(s, e);
          text(nameOf(e), 126, y + 2, { color: '#fff' });
          if (mod) { draw(mod < 0 ? I.tag_discount : I.tag_overcharge, 242, y + 3); text(`${mod > 0 ? '+' : ''}${mod}%`, 255, y + 4, { small: true, color: '#fff', align: 'center' }); }
          text(amountText(s, priceOf(s, e)), 310, y + 4, { small: true, color: '#fff', align: 'right' });
        });
      }
    }
    if (e0) {
      icon(icons[sel], 12, 205, e0.type === 'pokemon');
      const d = e0.type === 'pokemon' ? `${nameOf(e0)} — ${amountText(s, priceOf(s, e0))}` : ((itemOf(e0.item) || {}).descr || '').replace(/[’‘]/g, "'");
      wrap(c, d, 46, 199, 264, 13, text);
    } else text('Aucun article.', 46, 199, { small: true, color: '#fff' });
  }
  function wrap(c, str, x, y, w, lh, text) {
    c.font = '9px "Avenir Next", sans-serif';
    let line = ''; let yy = y; let n = 0;
    String(str).split(/\s+/).forEach((word) => {
      const t = line ? line + ' ' + word : word;
      if (c.measureText(t).width > w && line) { if (n < 2) text(line, x, yy, { small: true, color: '#fff' }); line = word; yy += lh; n++; } else line = t;
    });
    if (line && n < 3) text(line, x, yy, { small: true, color: '#fff' });
  }

  // --- Onglet Vendeurs ----------------------------------------------------------------------------------
  function renderSellersTab(body) {
    const side = h('div', { class: 'pjmg-side' });
    side.appendChild(h('button', { class: 'pjs-btn primary', onclick: () => {
      const s = { id: '', name: { fr: 'Nouveau vendeur', en: '' }, lines: {} };
      LINES.forEach(([k]) => { s.lines[k] = { fr: [], en: [] }; });
      s.id = uniqueId(S.config.sellers, 'vendeur'); autoIds.add(s.id);
      S.config.sellers.push(s); S.seller = s.id; render();
    } }, '+ Vendeur'));
    const list = h('div', { class: 'pjmg-list' });
    S.config.sellers.forEach((s) => {
      const used = shops().filter((x) => x.seller === s.id).length;
      list.appendChild(h('div', { class: 'pjmg-entry' + (s.id === S.seller ? ' active' : ''), 'data-id': s.id, onclick: () => set(() => { S.seller = s.id; }) },
        h('span', { class: 'pjmg-kind seller' }, '☺'),
        h('span', { class: 'pjmg-ename' }, h('span', { class: 'pjmg-name' }, txt(s.name) || s.id), h('span', { class: 'pjmg-sub' }, `${used} magasin${used > 1 ? 's' : ''}`))));
    });
    if (!S.config.sellers.length) list.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun vendeur : les phrases par défaut sont utilisées.'));
    side.appendChild(list);
    body.appendChild(side);
    const detail = h('div', { class: 'pjmg-detail' });
    body.appendChild(detail);
    const content = h('div', { class: 'pjmg-content' });
    detail.appendChild(content);
    warnings(content);
    const s = currentSeller();
    if (!s) { content.appendChild(h('div', { class: 'pjs-empty' }, 'Les vendeurs donnent leurs phrases aux comptoirs (une phrase tirée au hasard à chaque fois), pour des marchands plus vivants.')); return; }
    const box = block('Vendeur', h('div', { class: 'pjmg-actions' },
      h('button', { class: 'pjs-btn small danger', onclick: () => { if (confirm(`Supprimer « ${txt(s.name)} » ?`)) set(() => { const i = S.config.sellers.indexOf(s); S.config.sellers.splice(i, 1); shops().forEach((x) => { if (x.seller === s.id) x.seller = ''; }); S.seller = (S.config.sellers[i] || S.config.sellers[i - 1] || {}).id; }); } }, 'Supprimer')));
    box.appendChild(h('div', { class: 'pjmg-grid3' },
      field('Nom (français)', h('input', { class: 'pjs-input', 'data-focus': 'seller-name', value: s.name.fr, oninput: (e) => soft(() => { s.name.fr = e.target.value; followName(S.config.sellers, s, 'seller'); }) })),
      field('Nom (anglais)', h('input', { class: 'pjs-input', 'data-focus': 'seller-name-en', placeholder: s.name.fr, value: s.name.en, oninput: (e) => soft(() => { s.name.en = e.target.value; }) })),
      field('Identifiant', h('input', { class: 'pjs-input pjmg-mono', 'data-focus': 'id', value: s.id, onchange: (e) => set(() => { const old = s.id; const id = uniqueId(S.config.sellers, e.target.value || txt(s.name), s); autoIds.delete(old); s.id = id; S.seller = id; shops().forEach((x) => { if (x.seller === old) x.seller = id; }); }) }), 'magasin_caisse(:' + s.id + ')')));
    content.appendChild(box);
    const lines = block('Phrases', null, h('div', { class: 'pjs-hint' }, 'Une phrase par ligne ; le vendeur en dit une au hasard. Vide : la phrase par défaut. Les {valeurs} sont remplacées en jeu.'));
    LINES.forEach(([key, label, vars, def]) => {
      const l = s.lines[key];
      const area = (lang) => h('textarea', { class: 'pjs-input pjmg-area', rows: Math.max(2, l[lang].length + 1), 'data-focus': `${key}-${lang}`, placeholder: lang === 'fr' ? def : 'Same as French if empty',
        value: l[lang].join('\n'), oninput: (e) => soft(() => { l[lang] = e.target.value.split('\n'); }) });
      lines.appendChild(h('div', { class: 'pjmg-line' },
        h('div', { class: 'pjmg-linehead' }, h('span', { class: 'pjs-label' }, label), vars ? h('span', { class: 'pjs-hint inline' }, vars) : null),
        h('div', { class: 'pjmg-grid2' }, area('fr'), area('en'))));
    });
    content.appendChild(lines);
  }

  // --- Onglet Monnaies ----------------------------------------------------------------------------------
  function renderCurrenciesTab(body) {
    const detail = h('div', { class: 'pjmg-detail' });
    body.appendChild(detail);
    const content = h('div', { class: 'pjmg-content narrow' });
    detail.appendChild(content);
    warnings(content);
    const box = block('Monnaies', h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => {
      S.config.currencies.push({ id: uniqueId(S.config.currencies, 'points'), kind: 'variable', variable: 0, symbol: 'PC', name: { fr: 'Points', en: 'Points' } });
    }) }, '+ Monnaie'));
    box.appendChild(h('div', { class: 'pjmg-ctable' }, h('div', { class: 'pjmg-chead' }, h('span', null, 'Nom'), h('span', null, 'English'), h('span', null, 'Symbole'), h('span', null, 'Type'), h('span', null, 'Variable'), h('span', null, 'Identifiant'), h('span')),
      S.config.currencies.map((c, i) => {
        const builtin = c.id === 'money';
        const used = shops().filter((s) => s.currency === c.id).length;
        return h('div', { class: 'pjmg-crow' },
          h('input', { class: 'pjs-input', 'data-focus': `cn-${i}`, value: c.name.fr, oninput: (e) => soft(() => { c.name.fr = e.target.value; }) }),
          h('input', { class: 'pjs-input', 'data-focus': `ce-${i}`, value: c.name.en, placeholder: c.name.fr, oninput: (e) => soft(() => { c.name.en = e.target.value; }) }),
          h('input', { class: 'pjs-input', 'data-focus': `cs-${i}`, value: c.symbol || '', oninput: (e) => soft(() => { c.symbol = e.target.value; }) }),
          builtin ? h('span', { class: 'pjs-hint inline' }, 'Argent du joueur') : select(CURRENCY_KINDS.filter(([k]) => k !== 'money'), c.kind, (v) => set(() => { c.kind = v; })),
          c.kind === 'variable' ? numInput(c.variable || '', (v) => { c.variable = v || 0; }, { 'data-focus': `cv-${i}`, min: 1 }) : h('span', { class: 'pjs-hint inline' }, c.kind === 'coins' ? 'boîte à jetons' : '—'),
          h('input', { class: 'pjs-input pjmg-mono', 'data-focus': `ci-${i}`, value: c.id, disabled: builtin, onchange: (e) => set(() => { const old = c.id; c.id = uniqueId(S.config.currencies, e.target.value || txt(c.name), c); shops().forEach((s) => { if (s.currency === old) s.currency = c.id; }); }) }),
          builtin ? h('span') : h('button', { class: 'pjmg-x', title: used ? `utilisée par ${used} magasin(s)` : 'Retirer', onclick: () => { if (!used || confirm(`${used} magasin(s) utilisent cette monnaie : ils passeront à l'argent.`)) set(() => { S.config.currencies.splice(i, 1); shops().forEach((s) => { if (s.currency === c.id) s.currency = 'money'; }); }); } }, '✕'));
      })));
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Jetons du casino : la boîte à jetons de PSDK. Variable du jeu : par exemple des Points Combat gagnés à la Tour de Combat (la variable est diminuée à l\'achat).'));
    content.appendChild(box);
    const opts = block('Affichage');
    opts.appendChild(h('div', { class: 'pjmg-grid3' }, field('Défilement de l\'argent', numInput(S.config.money_speed, (v) => { S.config.money_speed = Math.max(1, v | 0); }, { 'data-focus': 'speed', min: 1, max: 120 }), 'images (plus grand = plus lent)')));
    content.appendChild(opts);
  }

  // ---------------------------------------------------------------------------
  // Page : Level design > Magasins (/database/shops)
  // ---------------------------------------------------------------------------
  function mount(hostEl) {
    root = h('div', { id: 'pjmg-root' });
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

  window.pjMagasinsEditor = { state: S, render };
})();

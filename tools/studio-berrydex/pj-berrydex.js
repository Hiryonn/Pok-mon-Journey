/* eslint-disable */
// =============================================================================
// Berrydex — page « Données > Baies > Berrydex » de Pokémon Studio
//   Liste des baies (objets « baie » de Studio), aperçu de l'écran du jeu (liste, FICHE, CULTURE, COMBAT),
//   météo et lieux favorables, effet en combat, baies cachées, ordre du Berrydex.
// Enregistre Data/configs/plugins/berrydex.json (plugin « berrydex »).
// Taille, fermeté, saveurs, pousse, récolte, Don Naturel… se règlent dans Données > Objets (fiche de la baie).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjBerrydexLoaded) return;
  window.__pjBerrydexLoaded = true;

  const PAGE_ID = 'berrydex';
  const DEFAULTS = { klass: 'BerrydexConfig', show_unknown: true, numbering: 'id', order: [], berries: {} };
  const WEATHER_NAMES = { sun: 'Soleil', rain: 'Pluie', heavyrain: 'Forte pluie', storm: 'Orage', snow: 'Neige', blizzard: 'Blizzard', sandstorm: 'Tempête de sable', fog: 'Brouillard', field: 'Prairie', city: 'Ville', desert: 'Désert' };
  const FIRMNESS = { very_soft: 'Très tendre', soft: 'Tendre', hard: 'Dure', very_hard: 'Très dure', super_hard: 'Super dure' };
  const FLAVORS = [['spicy', 'spicyFlavor', 'Épicé', '#f08030'], ['dry', 'dryFlavor', 'Sec', '#6890f0'], ['sweet', 'sweetFlavor', 'Sucré', '#f85888'], ['bitter', 'bitterFlavor', 'Amer', '#78c850'], ['sour', 'sourFlavor', 'Acide', '#f8d030']];
  const PAGES = ['Liste', 'FICHE', 'CULTURE', 'COMBAT'];

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjBerrydex;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API du Berrydex n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const decimal = (v) => String(Math.round((+v || 0) * 10) / 10).replace('.', ',');

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = { open: false, projectPath: null, ctx: null, config: null, saved: null, error: null, building: false, selected: null, page: 1, search: '' };
  let root = null;
  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => S.config && S.saved !== snapshot();
  const berryOf = (db) => S.ctx.berries.find((b) => b.db === db);
  const settings = (db) => (S.config.berries[db] = S.config.berries[db] || {});
  const peek = (db) => S.config.berries[db] || {};
  // Nettoie les réglages vides avant d'enregistrer
  function cleaned() {
    const c = clone(S.config);
    for (const [db, s] of Object.entries(c.berries)) {
      if (s.effect && !(s.effect.fr || '').trim() && !(s.effect.en || '').trim()) delete s.effect;
      ['weathers', 'zones', 'unpref_zones'].forEach((k) => { if (Array.isArray(s[k]) && !s[k].length) delete s[k]; });
      if (s.hidden === false) delete s.hidden;
      if (!Object.keys(s).length) delete c.berries[db];
    }
    return c;
  }
  // Ordre des baies dans le Berrydex (même calcul que le jeu)
  function ordered(includeHidden) {
    let list = S.ctx.berries.map((b) => b.db);
    if (S.config.numbering === 'order' && S.config.order.length) {
      const first = S.config.order.filter((db) => list.includes(db));
      list = first.concat(list.filter((db) => !first.includes(db)));
    }
    return includeHidden ? list : list.filter((db) => !peek(db).hidden);
  }
  const numberOf = (db) => ordered(false).indexOf(db) + 1;

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null;
    imageCache.clear();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      S.config = Object.assign(clone(DEFAULTS), S.ctx.config || {});
      if (!S.config.berries || typeof S.config.berries !== 'object') S.config.berries = {};
      if (!Array.isArray(S.config.order)) S.config.order = [];
      S.saved = S.ctx.config ? snapshot() : null;
      if (!S.selected || !berryOf(S.selected)) S.selected = S.ctx.berries[0] && S.ctx.berries[0].db;
    } catch (e) { S.error = e.message; }
    render();
  }
  async function save() {
    if (!S.config) return;
    try {
      S.config = cleaned();
      const r = await call('save', { projectPath: S.projectPath, config: S.config });
      S.saved = snapshot();
      const p = r.plugin || {};
      if (p.source) S.ctx.plugin = { source: true, installed: p.installed };
      toast('Enregistré' + (p.source && !p.installed ? ' — plugin pas encore installé : lance construire_plugins.bat une fois' : ''));
      render();
      if (p.source && p.installed) rebuildPlugin();
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
    return [S.saved ? 'Enregistré' : 'Réglages par défaut (pas encore enregistrés)', ''];
  }
  function updateStatus() {
    const el = root && root.querySelector('.pjs-status');
    if (!el) return;
    const [txt, cls] = statusText();
    el.textContent = txt; el.className = 'pjs-status' + cls;
  }
  const set = (fn) => { fn(); render(); };

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    const prevList = root.querySelector('.pjb-list');
    const listScroll = prevList ? prevList.scrollTop : 0;
    const prev = root.querySelector('.pjb-detail');
    const scroll = prev ? prev.scrollTop : 0;
    const focused = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.focus : null;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Berrydex'),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    if (S.error) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty err' }, S.error))); return; }
    if (!S.config) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty' }, 'Chargement…'))); return; }
    const body = h('div', { class: 'pjb-body' });
    root.appendChild(body);
    body.appendChild(renderSidebar());
    const detail = h('div', { class: 'pjb-detail' });
    body.appendChild(detail);
    const content = h('div', { class: 'pjb-content' });
    detail.appendChild(content);
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/berrydex est introuvable.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, "Le plugin « berrydex » n'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul)."));
    if (!S.ctx.assets.ui) content.appendChild(h('div', { class: 'pjs-warn' }, 'Images manquantes dans graphics/interface/berrydex/ (tools/berrydex/build_berrydex_assets.py).'));
    if (!S.ctx.berries.length) { content.appendChild(h('div', { class: 'pjs-empty' }, "Aucune baie : coche « Baie » sur des objets dans Données > Objets.")); return; }
    const row = h('div', { class: 'pjb-row' });
    content.appendChild(row);
    row.appendChild(renderPreview());
    const right = h('div', { class: 'pjb-right' });
    row.appendChild(right);
    right.appendChild(renderBerry());
    right.appendChild(renderGrowth());
    right.appendChild(renderEffect());
    content.appendChild(renderGlobal());
    detail.scrollTop = scroll;
    const list = root.querySelector('.pjb-list');
    if (list) list.scrollTop = listScroll;
    if (focused) { const el = root.querySelector(`[data-focus="${focused}"]`); if (el) { el.focus(); if (el.setSelectionRange && el.value) el.setSelectionRange(el.value.length, el.value.length); } }
  }

  const block = (title, ...kids) => h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title)), kids);
  const field = (label, input, hint) => h('label', { class: 'pjb-field' }, h('span', { class: 'pjs-label' }, label), input, hint ? h('span', { class: 'pjs-hint inline' }, hint) : null);

  // --- Liste des baies ------------------------------------------------------------------------
  function renderSidebar() {
    const side = h('div', { class: 'pjb-side' });
    side.appendChild(h('input', { class: 'pjs-input pjb-search', placeholder: 'Rechercher une baie…', value: S.search, 'data-focus': 'search', oninput: (e) => { S.search = e.target.value; render(); } }));
    const list = h('div', { class: 'pjb-list' });
    side.appendChild(list);
    const q = plain(S.search);
    const order = ordered(true);
    const reorder = S.config.numbering === 'order';
    order.forEach((db, i) => {
      const b = berryOf(db);
      if (q && !plain(b.name).includes(q) && !b.db.includes(q)) return;
      const hidden = !!peek(db).hidden;
      const icon = h('span', { class: 'pjb-ico' });
      if (b.icon) loadImage(`graphics/icons/${b.icon}`).then((im) => { if (im) icon.style.backgroundImage = `url("${im.src}")`; });
      const configured = (peek(db).weathers || []).length || (peek(db).zones || []).length || (peek(db).unpref_zones || []).length || (peek(db).effect && (peek(db).effect.fr || peek(db).effect.en));
      list.appendChild(h('div', { class: 'pjb-entry' + (db === S.selected ? ' active' : '') + (hidden ? ' hidden' : ''), onclick: () => set(() => { S.selected = db; }) },
        h('span', { class: 'pjb-num' }, hidden ? '—' : String(numberOf(db)).padStart(3, '0')), icon,
        h('span', { class: 'pjb-name' }, b.name),
        configured ? h('span', { class: 'pjb-dot', title: 'Réglages du Berrydex renseignés' }) : null,
        reorder && !q ? h('span', { class: 'pjb-move' },
          h('button', { class: 'pjb-x', title: 'Monter', disabled: i === 0, onclick: (e) => { e.stopPropagation(); move(db, -1); } }, '▲'),
          h('button', { class: 'pjb-x', title: 'Descendre', disabled: i === order.length - 1, onclick: (e) => { e.stopPropagation(); move(db, 1); } }, '▼')) : null));
    });
    const shown = ordered(false).length;
    side.appendChild(h('div', { class: 'pjs-hint pjb-count' }, `${shown} baie${shown > 1 ? 's' : ''} dans le Berrydex` + (shown < S.ctx.berries.length ? ` (${S.ctx.berries.length - shown} cachée${S.ctx.berries.length - shown > 1 ? 's' : ''})` : '')));
    return side;
  }
  function move(db, delta) {
    set(() => {
      const order = ordered(true);
      const i = order.indexOf(db); const j = i + delta;
      if (j < 0 || j >= order.length) return;
      [order[i], order[j]] = [order[j], order[i]];
      S.config.order = order;
    });
  }

  // --- Aperçu (écran du jeu, 320 x 240) ----------------------------------------------------------
  function renderPreview() {
    const box = h('div', { class: 'pjs-block pjb-preview' });
    box.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Aperçu en jeu'),
      h('div', { class: 'pjb-tabs' }, PAGES.map((p, i) => h('button', { class: 'pjs-btn small ' + (S.page === i ? 'primary' : 'secondary'), onclick: () => set(() => { S.page = i; }) }, i ? p.charAt(0) + p.slice(1).toLowerCase() : p)))));
    const cv = h('canvas', { class: 'pjb-canvas', width: 320, height: 240 });
    box.appendChild(cv);
    drawPreview(cv);
    box.appendChild(h('div', { class: 'pjs-hint' }, S.page === 0
      ? 'En jeu : haut / bas pour choisir, gauche / droite pour avancer de 10, A pour ouvrir la fiche (baie trouvée), B pour quitter. Les baies pas encore trouvées s’affichent en « ????? ».'
      : 'Dans la fiche : gauche / droite changent de page, haut / bas passent à la baie trouvée suivante.'));
    return box;
  }
  const COL = { light: '#e5f3fa', dark: '#282828', white: '#fff', sky: '#91c9f7', steel: '#45677f' };
  async function drawPreview(cv) {
    const c = cv.getContext('2d');
    c.imageSmoothingEnabled = false;
    const b = berryOf(S.selected);
    const img = (n) => loadImage('graphics/interface/' + n);
    const [bg, header, footer, card, list, info, cursor, found, unknown, arrowL, arrowR] = await Promise.all(
      ['horizon/team/fond', 'horizon/header', 'horizon/tcard/button_background', 'berrydex/card', 'berrydex/list', 'berrydex/info', 'berrydex/cursor', 'berrydex/found', 'berrydex/unknown', 'horizon/quest/arrow_frame_l', 'horizon/quest/arrow_frame_r'].map(img));
    const tag = b && b.tag ? await img(`berrydex/tags/${b.db}`) : null;
    const flavorImgs = await Promise.all(FLAVORS.map((f) => img(`berrydex/flavor_${f[0]}`)));
    c.fillStyle = COL.light; c.fillRect(0, 0, 320, 240);
    if (bg) c.drawImage(bg, 0, 0);
    if (header) c.drawImage(header, 0, 0);
    if (footer) c.drawImage(footer, 0, 214);
    const text = (s, x, y, o = {}) => {
      c.font = `${o.small ? 9 : 11}px "Avenir Next", sans-serif`;
      c.fillStyle = o.color || COL.dark; c.textBaseline = 'top';
      c.textAlign = o.align || 'left';
      c.fillText(s, x, y);
    };
    const detail = S.page > 0;
    text(detail ? PAGES[S.page] : 'BERRYDEX', 160, 7, { align: 'center', color: COL.white });
    if (detail) { if (arrowL) c.drawImage(arrowL, 84, 6); if (arrowR) c.drawImage(arrowR, 228, 6); }
    const total = ordered(false).length;
    text(detail ? `Page ${S.page} / 3` : `${total} / ${total}`, 314, 9, { align: 'right', color: COL.white, small: true });
    text(detail ? '< > : Page   Haut / Bas : Baie   B : Retour' : 'A : Fiche   < > : 10 baies   B : Quitter', 160, 222, { align: 'center', color: COL.white, small: true });
    if (!b) return;
    // carte
    if (card) c.drawImage(card, 6, 32);
    if (tag) c.drawImage(tag, 35, 40);
    else if (unknown) c.drawImage(unknown, 55, 60);
    const num = numberOf(b.db);
    text(num ? `N° ${String(num).padStart(3, '0')}` : 'Cachée', 67, 112, { align: 'center' });
    text(b.name, 67, 128, { align: 'center' });
    text('Trouvée', 67, 147, { align: 'center', small: true });
    text(FIRMNESS[b.berry.firmness] || '', 67, 163, { align: 'center', small: true });
    const best = FLAVORS.reduce((m, f) => ((b.cooking[f[1]] | 0) > (m ? b.cooking[m[1]] | 0 : 0) ? f : m), null);
    if (best) { const i = FLAVORS.indexOf(best); if (flavorImgs[i]) c.drawImage(flavorImgs[i], 41, 182); text(best[2], 67, 184, { align: 'center', small: true, color: COL.white }); }
    const X = 136; const Y = 32;
    if (!detail) {
      if (list) c.drawImage(list, X, Y);
      const order = ordered(false);
      let index = Math.max(0, order.indexOf(b.db));
      const top = Math.max(0, Math.min(index - 4, order.length - 10));
      if (cursor && order.includes(b.db)) c.drawImage(cursor, X, Y + 3 + (index - top) * 16);
      order.slice(top, top + 10).forEach((db, i) => {
        const y = Y + 4 + i * 16;
        const known = db === b.db || i % 3 !== 1; // aperçu : quelques baies « pas encore trouvées »
        if (known && found) c.drawImage(found, X + 6, y + 1);
        text(String(top + i + 1).padStart(3, '0'), X + 24, y + 2, { color: COL.white });
        text(known ? berryOf(db).name : '?????', X + 58, y + 2, { color: COL.white });
      });
      return;
    }
    if (info) c.drawImage(info, X, Y);
    const L = (s, y, o) => text(s, X + 6, Y + y + 2, o);
    const s = peek(b.db);
    if (S.page === 1) {
      L(`Taille : ${decimal(b.berry.size)} cm`, 4);
      L(`Fermeté : ${FIRMNESS[b.berry.firmness] || '-'}`, 20);
      L('Saveurs', 38);
      FLAVORS.forEach((f, i) => {
        const x = X + 6 + (i % 2) * 86; const y = Y + 56 + Math.floor(i / 2) * 16;
        if (flavorImgs[i]) c.drawImage(flavorImgs[i], x, y);
        text(f[2], x + 26, y + 2, { align: 'center', small: true, color: COL.white });
        text(String(b.cooking[f[1]] | 0), x + 56, y + 2, { small: true });
      });
      L(`Douceur : ${b.cooking.smoothness | 0}`, 106);
      wrap(c, (b.descr || '').replace(/[’‘]/g, "'"), X + 6, Y + 128, 166, 13, text);
    } else if (S.page === 2) {
      L(`Pousse : ${b.berry.growth | 0} h`, 4);
      L(`Récolte : ${b.berry.minYield | 0} - ${b.berry.maxYield | 0} baies`, 20);
      L(`Assèchement : ${b.berry.drainRate | 0}`, 36);
      L('Météo favorable', 56);
      const weathers = (s.weathers || []).filter((w) => S.ctx.weathers.includes(w));
      const icons = await Promise.all(weathers.map((w) => img(`berrydex/weather/${w}`)));
      icons.forEach((im, i) => { if (im) c.drawImage(im, X + 6 + i * 28, Y + 74); });
      text(weathers.length ? weathers.map((w) => WEATHER_NAMES[w]).join(', ') : 'Inconnu', X + 6, Y + (weathers.length ? 100 : 76), { small: true });
      text('Lieux', X + 6, Y + 120, { small: true });
      const zones = zonesOf(s);
      const zIcons = await Promise.all(zones.map(([z, pref]) => img(`berrydex/weather/${z}${pref ? '' : '_unpref'}`)));
      zIcons.forEach((im, i) => { if (im) c.drawImage(im, X + 6 + i * 28, Y + 134); });
      text(zones.length ? zones.map(([z, pref]) => WEATHER_NAMES[z] + (pref ? '' : ' (à éviter)')).join(', ') : 'Inconnu', X + 6, Y + (zones.length ? 162 : 136), { small: true });
    } else {
      L('Don Naturel', 4);
      const type = S.ctx.types[b.berry.naturalGiftType];
      if (type) {
        c.fillStyle = type.color || '#888'; roundRect(c, X + 6, Y + 23, 32, 14, 3);
        text(type.name.slice(0, 6), X + 22, Y + 25, { align: 'center', small: true, color: COL.white });
      }
      text(`Puissance ${b.berry.naturalGiftPower | 0}`, X + 44, Y + 22);
      L(`Dégommage : ${b.fling}`, 40);
      L('Effet', 60);
      const effect = (s.effect && (s.effect.fr || '').trim()) || b.descr || '';
      wrap(c, effect.replace(/[’‘]/g, "'"), X + 6, Y + 80, 166, 13, text);
    }
  }
  function roundRect(c, x, y, w, hh, r) { c.beginPath(); c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + hh, r); c.arcTo(x + w, y + hh, x, y + hh, r); c.arcTo(x, y + hh, x, y, r); c.arcTo(x, y, x + w, y, r); c.fill(); }
  function wrap(c, str, x, y, w, lh, text) {
    c.font = '9px "Avenir Next", sans-serif';
    let line = ''; let yy = y;
    String(str).split(/\s+/).forEach((word) => {
      const t = line ? line + ' ' + word : word;
      if (c.measureText(t).width > w && line) { text(line, x, yy, { small: true }); line = word; yy += lh; } else line = t;
    });
    if (line) text(line, x, yy, { small: true });
  }
  const zonesOf = (s) => {
    const pref = (s.zones || []).filter((z) => S.ctx.zones.includes(z));
    const unpref = (s.unpref_zones || []).filter((z) => S.ctx.zones.includes(z) && !pref.includes(z));
    return pref.map((z) => [z, true]).concat(unpref.map((z) => [z, false]));
  };

  // --- Baie choisie : données de Studio --------------------------------------------------------
  function renderBerry() {
    const b = berryOf(S.selected);
    const s = peek(b.db);
    const box = block(b.name);
    const stat = (label, value) => h('div', { class: 'pjb-stat' }, h('span', { class: 'pjs-label' }, label), h('span', null, value));
    const type = S.ctx.types[b.berry.naturalGiftType];
    box.appendChild(h('div', { class: 'pjb-stats' },
      stat('Taille', `${decimal(b.berry.size)} cm`), stat('Fermeté', FIRMNESS[b.berry.firmness] || '-'),
      stat('Pousse', `${b.berry.growth | 0} h`), stat('Récolte', `${b.berry.minYield | 0} à ${b.berry.maxYield | 0}`),
      stat('Assèchement', String(b.berry.drainRate | 0)), stat('Douceur', String(b.cooking.smoothness | 0)),
      stat('Don Naturel', `${type ? type.name : '-'} ${b.berry.naturalGiftPower | 0}`), stat('Dégommage', String(b.fling))));
    box.appendChild(h('div', { class: 'pjb-flavors' }, FLAVORS.map((f) => h('span', { class: 'pjb-flavor', style: { background: f[3] } }, `${f[2]} ${b.cooking[f[1]] | 0}`))));
    box.appendChild(h('div', { class: 'pjs-hint' }, `Ces valeurs viennent de la fiche de l'objet (Données > Objets > ${b.name}, « ${b.db} »). L’étiquette vient de graphics/interface/berrydex/tags/${b.db}.png` + (b.tag ? '.' : ' (absente : l’icône de l’objet est affichée).')));
    box.appendChild(h('label', { class: 'pjs-inline pjb-mt' }, h('input', { type: 'checkbox', checked: !!s.hidden, onchange: (e) => set(() => { settings(b.db).hidden = e.target.checked; }) }),
      'Cacher cette baie du Berrydex (elle ne compte pas dans le total)'));
    return box;
  }

  // --- Culture : météo et lieux --------------------------------------------------------------------
  function renderGrowth() {
    const b = berryOf(S.selected);
    const s = peek(b.db);
    const box = block('Culture');
    box.appendChild(h('div', { class: 'pjs-label' }, 'Météo favorable'));
    const grid = h('div', { class: 'pjb-icons' });
    S.ctx.weathers.forEach((w) => {
      const on = (s.weathers || []).includes(w);
      const icon = h('span', { class: 'pjb-wicon' });
      loadImage(`graphics/interface/berrydex/weather/${w}`).then((im) => { if (im) icon.style.backgroundImage = `url("${im.src}")`; });
      grid.appendChild(h('button', { class: 'pjb-toggle' + (on ? ' on' : ''), onclick: () => set(() => {
        const st = settings(b.db); const list = st.weathers || [];
        st.weathers = on ? list.filter((x) => x !== w) : S.ctx.weathers.filter((x) => x === w || list.includes(x));
      }) }, icon, WEATHER_NAMES[w]));
    });
    box.appendChild(grid);
    box.appendChild(h('div', { class: 'pjs-label pjb-mt' }, 'Lieux'));
    const zones = h('div', { class: 'pjb-zones' });
    S.ctx.zones.forEach((z) => {
      const state = (s.zones || []).includes(z) ? 'pref' : (s.unpref_zones || []).includes(z) ? 'unpref' : 'none';
      const icon = h('span', { class: 'pjb-wicon' });
      loadImage(`graphics/interface/berrydex/weather/${z}${state === 'unpref' ? '_unpref' : ''}`).then((im) => { if (im) icon.style.backgroundImage = `url("${im.src}")`; });
      const sel = h('select', { class: 'pjs-input', onchange: (e) => set(() => {
        const st = settings(b.db);
        st.zones = (st.zones || []).filter((x) => x !== z); st.unpref_zones = (st.unpref_zones || []).filter((x) => x !== z);
        if (e.target.value === 'pref') st.zones = S.ctx.zones.filter((x) => x === z || st.zones.includes(x));
        if (e.target.value === 'unpref') st.unpref_zones = S.ctx.zones.filter((x) => x === z || st.unpref_zones.includes(x));
      }) }, h('option', { value: 'none' }, 'Non indiqué'), h('option', { value: 'pref' }, 'Préféré'), h('option', { value: 'unpref' }, 'À éviter'));
      sel.value = state;
      zones.appendChild(h('div', { class: 'pjb-zone' }, icon, h('span', null, WEATHER_NAMES[z]), sel));
    });
    box.appendChild(zones);
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Affiché à la page CULTURE (informations pour le joueur ; la pousse elle-même n’en dépend pas).'));
    return box;
  }

  // --- Combat : effet ----------------------------------------------------------------------------
  function renderEffect() {
    const b = berryOf(S.selected);
    const s = peek(b.db);
    const box = block('Effet en combat');
    const area = (lang, label) => field(label, h('textarea', { class: 'pjs-input pjb-area', rows: 3, 'data-focus': 'effect-' + lang, placeholder: lang === 'fr' ? b.descr : 'Same as French text if empty', value: (s.effect && s.effect[lang]) || '',
      oninput: (e) => { const st = settings(b.db); st.effect = Object.assign({}, st.effect, { [lang]: e.target.value }); updateStatus(); },
      onchange: () => render() }));
    box.appendChild(area('fr', 'Français'));
    box.appendChild(area('en', 'Anglais'));
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Affiché à la page COMBAT. Vide : la description de l’objet est utilisée.'));
    return box;
  }

  // --- Réglages généraux et commandes -------------------------------------------------------------
  function renderGlobal() {
    const c = S.config;
    const box = block('Berrydex');
    box.appendChild(h('div', { class: 'pjb-grid2' },
      field('Numérotation', (() => {
        const sel = h('select', { class: 'pjs-input', onchange: (e) => set(() => { c.numbering = e.target.value; if (c.numbering === 'order' && !c.order.length) c.order = S.ctx.berries.map((x) => x.db); }) },
          h('option', { value: 'id' }, 'Ordre des objets (Données > Objets)'), h('option', { value: 'order' }, 'Ordre choisi (flèches dans la liste)'));
        sel.value = c.numbering === 'order' ? 'order' : 'id';
        return sel;
      })(), c.numbering === 'order' ? 'les flèches ▲ ▼ de la liste à gauche changent l’ordre' : null),
      h('div', { class: 'pjb-field pjb-end' }, h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: c.show_unknown !== false, onchange: (e) => set(() => { c.show_unknown = e.target.checked; }) }),
        'Montrer les baies pas encore trouvées (« ????? »)'))));
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Une baie est « trouvée » dès qu’elle entre dans le sac du joueur (les baies déjà dans le sac comptent aussi).'));
    box.appendChild(h('div', { class: 'pjs-label pjb-mt' }, 'Commandes d’évènement (Script)'));
    const cmds = [['berrydex', 'ouvre le Berrydex'], ['berrydex(:' + (S.selected || 'oran_berry') + ')', 'ouvre le Berrydex sur cette baie'],
      ['berrydex_enregistrer(:' + (S.selected || 'oran_berry') + ')', 'marque des baies comme trouvées'], ['berrydex_tout_enregistrer', 'toutes les baies trouvées'],
      ['berrydex_trouvees', 'nombre de baies trouvées (conditions)'], ['berrydex_trouvee?(:' + (S.selected || 'oran_berry') + ')', 'true si la baie est trouvée']];
    box.appendChild(h('div', { class: 'pjb-cmds' }, cmds.map(([cmd, hint]) => h('div', { class: 'pjb-cmdrow' },
      h('code', { class: 'pjb-cmd', title: 'Cliquer pour copier', onclick: () => { try { navigator.clipboard.writeText(cmd); toast('Copié'); } catch (e) { /* rien */ } } }, cmd),
      h('span', { class: 'pjs-hint inline' }, hint)))));
    return box;
  }

  // ---------------------------------------------------------------------------
  // Page : Données > Baies > Berrydex (/database/berries/berrydex)
  // ---------------------------------------------------------------------------
  function mount(hostEl) {
    root = h('div', { id: 'pjb-root' });
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

  window.pjBerrydexEditor = { state: S, render };
})();

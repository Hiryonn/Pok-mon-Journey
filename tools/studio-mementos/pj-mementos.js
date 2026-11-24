/* eslint-disable */
// =============================================================================
// Rubans et insignes — page « Données > Pokémon > Rubans et insignes » de Pokémon Studio (plugin « mementos »)
//   Apparition des insignes (chances, Charme Insigne, taille), titres (couleur en combat, icône, titre automatique),
//   catalogue des 167 souvenirs avec leurs textes (nom, description, titre, en français et en anglais),
//   titres des Pokémon des dresseurs, aperçu de la page Souvenirs du résumé.
// Enregistre Data/configs/plugins/mementos.json.
// =============================================================================
(() => {
  'use strict';
  if (window.__pjMementosLoaded) return;
  window.__pjMementosLoaded = true;

  const PAGE_ID = 'mementos';
  const DEFAULT_SETTINGS = {
    title_color: 2, auto_title: true, mark_ratio: 50, size_marks: true, collapse_ranks: true,
    battle_titles: true, battle_icon: true, partner_steps: 10000, wild_marks: true,
  };
  const DEFAULTS = { klass: 'MementosConfig', settings: DEFAULT_SETTINGS, trainers: [], texts: {} };
  const MARK_CATEGORIES = ['time', 'weather', 'encounter', 'rarity', 'personality', 'size', 'party', 'boss'];
  const CATEGORY_NAMES = {
    contest: 'Concours', league: 'Ligue', frontier: 'Combat', memorial: 'Mémorial', gift: 'Spécial', time: 'Heure', weather: 'Météo',
    encounter: 'Rencontre', rarity: 'Rareté', personality: 'Humeur', size: 'Taille', party: 'Équipe', boss: 'Puissance',
  };
  const FILTERS = [['all', 'Tous'], ['ribbon', 'Rubans'], ['mark', 'Insignes'], ['title', 'Avec titre'], ['custom', 'Textes changés']]
    .concat(Object.entries(CATEGORY_NAMES));
  // Comment chaque insigne s'obtient (00103 Insignes.rb)
  const HOW = {
    time: 'Pokémon sauvage, selon le moment de la journée (matin : Aube, journée : Appétit, soir : Crépuscule, nuit : Minuit).',
    weather: 'Pokémon sauvage, selon la météo de la carte (pluie, orage, soleil, tempête de sable, grêle, neige, brouillard, vent).',
    personality: 'Pokémon sauvage : une humeur au hasard.',
    rarity: 'Pokémon sauvage : Rareté (très rare) ou Sociabilité.',
    size: 'Pokémon sauvage de taille 0 (Mini) ou 255 (Colosse), si « Mini et Colosse » est coché.',
    boss: 'Pas donné automatiquement : commande donner_souvenir (Pokémon Baron, Dominant, le plus fort…).',
  };
  const HOW_MARK = {
    fishing_mark: 'Pokémon sauvage pêché.', curry_mark: 'Pokémon sauvage attiré par le Miel, Doux Parfum ou un arbre à miel.',
    destiny_mark: 'Pokémon sauvage rencontré le jour de l’anniversaire du joueur (choisir_anniversaire).',
    partner_mark: 'Pokémon de l’équipe très attaché (200+), tous les N pas.', itemfinder_mark: 'Premier Pokémon de l’équipe quand on ramasse un objet.',
    gourmand_mark: 'Pokémon de l’équipe quand on cueille ou achète des baies.',
  };

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjMementos;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API des souvenirs n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const bgBox = (promise, cls) => {
    const el = h('span', { class: cls });
    promise.then((im) => { if (im) el.style.backgroundImage = `url("${im.src}")`; });
    return el;
  };
  const ribbonIcon = (m) => loadImage(`graphics/interface/ribbons/${m.symbol}_ribbon`);
  const pokeIcon = (id) => loadImage(`graphics/pokedex/pokeicon/${String(id).padStart(4, '0')}`);

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = { open: false, projectPath: null, ctx: null, config: null, saved: null, error: null, building: false,
    filter: 'all', search: '', selected: 'rainy_mark', palette: null };
  let root = null;
  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => S.config && S.saved !== snapshot();
  const st = () => S.config.settings;
  const isMark = (m) => MARK_CATEGORIES.includes(m.category);
  const memento = (sym) => S.ctx.mementos.find((m) => m.symbol === sym);
  const custom = (sym) => S.config.texts[sym] || null;
  // Texte en jeu : changé dans Studio, sinon celui du plugin ou de PSDK ; lang 0 = français, 1 = anglais
  function text(m, key, lang = 0) {
    const c = custom(m.symbol);
    if (c && Array.isArray(c[key]) && c[key][lang]) return c[key][lang];
    const base = m[key];
    return base ? base[lang] || '' : '';
  }
  const givesTitle = (m) => text(m, 'title') !== '';
  function fullTitle(m, name = 'Pikachu', owner = 'Sacha') {
    const t = text(m, 'title');
    if (!t) return '';
    const r = t.replace(/\{owner\}/g, owner).replace(/\{player\}/g, 'Sacha');
    return r.includes('{name}') ? r.replace(/\{name\}/g, name) : `${name} ${r}`;
  }

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null;
    imageCache.clear();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      S.config = Object.assign(clone(DEFAULTS), S.ctx.config || {});
      S.config.settings = Object.assign(clone(DEFAULT_SETTINGS), S.config.settings || {});
      if (!Array.isArray(S.config.trainers)) S.config.trainers = [];
      if (!S.config.texts || typeof S.config.texts !== 'object' || Array.isArray(S.config.texts)) S.config.texts = {};
      S.saved = S.ctx.config ? snapshot() : null;
      if (!memento(S.selected) && S.ctx.mementos.length) S.selected = S.ctx.mementos[0].symbol;
      loadPalette();
    } catch (e) { S.error = e.message; }
    render();
  }
  // Couleurs des textes du jeu (graphics/windowskins/_colors.png, 2e ligne)
  async function loadPalette() {
    const im = await loadImage('graphics/windowskins/_colors');
    if (!im) return;
    const cv = document.createElement('canvas'); cv.width = im.width; cv.height = im.height;
    const c = cv.getContext('2d'); c.drawImage(im, 0, 0);
    const d = c.getImageData(0, 1, im.width, 1).data;
    S.palette = [];
    for (let i = 0; i < im.width; i++) S.palette.push(`rgb(${d[i * 4]},${d[i * 4 + 1]},${d[i * 4 + 2]})`);
    render();
  }
  function problems() {
    const out = [];
    S.config.trainers.forEach((t, i) => {
      if (!t.trainer || !t.memento) out.push(`Titre de dresseur n° ${i + 1} incomplet (dresseur et souvenir).`);
      const m = t.memento && memento(t.memento);
      if (m && !givesTitle(m)) out.push(`« ${text(m, 'name')} » ne donne pas de titre (dresseur n° ${i + 1}).`);
    });
    return out;
  }
  // Retire les textes vides avant d'enregistrer
  function cleanTexts() {
    for (const [sym, t] of Object.entries(S.config.texts)) {
      for (const k of Object.keys(t)) if (!Array.isArray(t[k]) || (!t[k][0] && !t[k][1])) delete t[k];
      if (!Object.keys(t).length) delete S.config.texts[sym];
    }
  }
  async function save() {
    if (!S.config) return;
    const p = problems();
    if (p.length) { toast('À corriger avant d’enregistrer : ' + p[0], true); return; }
    cleanTexts();
    try {
      const r = await call('save', { projectPath: S.projectPath, config: S.config });
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

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    const prev = root.querySelector('.pjmm-detail');
    const scroll = prev ? prev.scrollTop : 0;
    const prevList = root.querySelector('.pjmm-list');
    const listScroll = prevList ? prevList.scrollTop : 0;
    const focused = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.focus : null;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Rubans et insignes'),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    if (S.error) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty err' }, S.error))); return; }
    if (!S.config) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty' }, 'Chargement…'))); return; }
    const detail = h('div', { class: 'pjmm-detail' });
    root.appendChild(detail);
    const content = h('div', { class: 'pjmm-content' });
    detail.appendChild(content);
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/mementos est introuvable.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, "Le plugin « mementos » n'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul)."));
    if (!S.ctx.mementos.length) content.appendChild(h('div', { class: 'pjs-warn' }, 'Liste des souvenirs introuvable (scripts/mementos/scripts/00101 Donnees.rb).'));
    const row = h('div', { class: 'pjmm-row' });
    content.appendChild(row);
    row.appendChild(renderPreview());
    const right = h('div', { class: 'pjmm-right' });
    row.appendChild(right);
    right.appendChild(renderMarks());
    right.appendChild(renderTitles());
    content.appendChild(renderCatalog());
    content.appendChild(renderTrainers());
    content.appendChild(renderCommands());
    detail.scrollTop = scroll;
    const list = root.querySelector('.pjmm-list');
    if (list) list.scrollTop = listScroll;
    if (focused) { const el = root.querySelector(`[data-focus="${focused}"]`); if (el) { el.focus(); if (el.setSelectionRange && el.type === 'text') el.setSelectionRange(el.value.length, el.value.length); } }
  }

  const block = (title, extra, ...kids) => h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title), extra || null), kids);
  const field = (label, input, hint) => h('label', { class: 'pjmm-field' }, h('span', { class: 'pjs-label' }, label), input, hint ? h('span', { class: 'pjs-hint inline' }, hint) : null);
  const num = (value, min, max, onset, focus) => h('input', { class: 'pjs-input pjmm-num', type: 'number', min, max, value, 'data-focus': focus,
    onchange: (e) => set(() => onset(Math.min(max, Math.max(min, Math.round(Number(e.target.value) || 0))))) });
  const check = (key, label) => h('label', { class: 'pjs-inline pjmm-check' },
    h('input', { type: 'checkbox', checked: !!st()[key], onchange: (e) => set(() => { st()[key] = e.target.checked; }) }), label);

  // --- Aperçu : page Souvenirs du résumé (320 x 240) ----------------------------------------------
  function renderPreview() {
    const m = memento(S.selected);
    const box = block('Aperçu en jeu', m ? h('span', { class: 'pjs-hint inline' }, text(m, 'name')) : null);
    const cv = h('canvas', { class: 'pjmm-canvas', width: 320, height: 240 });
    box.appendChild(cv);
    drawPreview(cv);
    box.appendChild(renderBattleLine(m));
    box.appendChild(h('div', { class: 'pjs-hint' },
      'Page Souvenirs du résumé avec le souvenir choisi dans la liste. En jeu : A sur un souvenir ouvre le menu (titre, déplacer, trier).'));
    return box;
  }
  // Message d'envoi en combat avec la couleur du titre
  function renderBattleLine(m) {
    const line = h('div', { class: 'pjmm-battle' });
    const full = m && st().battle_titles ? fullTitle(m) : '';
    const color = st().title_color;
    line.appendChild(document.createTextNode('Vas-y, '));
    const name = h('span', { class: 'pjmm-battle-name' }, full || 'Pikachu');
    if (full && color >= 0 && S.palette && S.palette[color]) name.style.color = S.palette[color];
    line.appendChild(name);
    line.appendChild(document.createTextNode(' !'));
    if (m && st().battle_titles && st().battle_icon && full) line.appendChild(bgBox(ribbonIcon(m), 'pjmm-ico pjmm-battle-ico'));
    return line;
  }
  let drawToken = 0;
  function wrap(c, str, width) {
    const lines = [];
    String(str).split('\n').forEach((para) => {
      let cur = '';
      para.split(' ').forEach((w) => {
        const cand = cur ? `${cur} ${w}` : w;
        if (c.measureText(cand).width > width && cur) { lines.push(cur); cur = w; } else cur = cand;
      });
      lines.push(cur);
    });
    return lines;
  }
  async function drawPreview(cv) {
    const token = ++drawToken;
    const m = memento(S.selected);
    const list = m ? [m].concat(filtered().filter((x) => x !== m)).slice(0, 8) : [];
    const names = ['grid', 'header', 'footer', 'page_mementos', 'ribbon_selector', 'ribbon_title', 'memento_star', 'memento_star_off', 'memento_arrow_down'];
    const I = {};
    (await Promise.all(names.map((n) => loadImage('graphics/interface/summary_pe/' + n)))).forEach((im, i) => { I[names[i]] = im; });
    const icons = await Promise.all(list.map((x) => ribbonIcon(x)));
    if (token !== drawToken) return;
    const c = cv.getContext('2d');
    c.imageSmoothingEnabled = false;
    const draw = (im, x, y) => { if (im) c.drawImage(im, x, y); };
    const font = (small, bold) => { c.font = `${bold ? 'bold ' : ''}${small ? 9 : 11}px "Avenir Next", sans-serif`; };
    const txt = (s, x, y, o = {}) => {
      font(o.small, o.bold);
      c.fillStyle = o.color || '#282828'; c.textBaseline = 'top'; c.textAlign = o.align || 'left';
      c.fillText(s, x, y);
    };
    c.fillStyle = '#e5f3fa'; c.fillRect(0, 0, 320, 240);
    draw(I.grid, 0, -12); draw(I.header, 0, 4); draw(I.footer, 0, 216);
    draw(I.page_mementos, 0, 0);
    txt('Pikachu', 18, 8, { color: '#fff' });
    const filterName = S.filter === 'all' || !CATEGORY_NAMES[S.filter] ? 'Souvenirs' : CATEGORY_NAMES[S.filter];
    txt(filterName, 146, 66, { color: '#fff' });
    if (m) txt(`1/${filtered().length}`, 312, 66, { color: '#fff', align: 'right' });
    list.forEach((x, i) => {
      const gx = 140 + (i % 4) * 45; const gy = 84 + Math.floor(i / 4) * 39;
      draw(icons[i], gx, gy);
      if (i === 0 && givesTitle(x)) draw(I.ribbon_title, gx, gy);
      if (i === 0) draw(I.ribbon_selector, gx, gy);
    });
    if (filtered().length > 8) draw(I.memento_arrow_down, 224, 166);
    if (!m) return;
    // Cadre gris : nom, catégorie, rang, description, titre
    let y = 54;
    font(false, true);
    wrap(c, text(m, 'name'), 100).forEach((l) => { txt(l, 10, y, { bold: true }); y += 16; });
    y += 1;
    font(true);
    txt(`${isMark(m) ? 'Insigne' : 'Ruban'} · ${CATEGORY_NAMES[m.category] || ''}`, 10, y, { small: true }); y += 12;
    const max = m.ranks.length + 1;
    if (max > 1 && max <= 5) {
      for (let i = 0; i < max; i++) draw(i < max ? I.memento_star : I.memento_star_off, 10 + i * 10, y + 1);
      y += 11;
    } else if (max > 5) { txt(`Rang ${max}/${max}`, 10, y, { small: true }); y += 12; }
    y += 2;
    font(true);
    wrap(c, text(m, 'description'), 100).forEach((l) => { txt(l, 10, y, { small: true }); y += 12; });
    y += 4;
    font(true);
    wrap(c, `Titre : ${givesTitle(m) ? fullTitle(m) : 'aucun'}`, 100).forEach((l) => { txt(l, 10, y, { small: true }); y += 12; });
  }

  // --- Apparition des insignes -------------------------------------------------------------------
  const odds = (n) => (n <= 1 ? '1/1' : `1/${Math.round(n)}`);
  function renderMarks() {
    const s = st();
    const r = Math.max(2, s.mark_ratio | 0);
    const box = block('Apparition des insignes');
    box.appendChild(h('div', { class: 'pjmm-grid3' },
      field('Chance de base (1/x)', num(s.mark_ratio, 2, 10000, (v) => { s.mark_ratio = v; }, 'ratio'), 'Essentials : 50'),
      field('Pas pour l’insigne Partenaire', num(s.partner_steps, 100, 1000000, (v) => { s.partner_steps = v; }, 'steps'), 'tous les N pas'),
      h('div', { class: 'pjmm-checks' }, check('wild_marks', 'Insignes des Pokémon sauvages'), check('size_marks', 'Mini et Colosse (taille 0 et 255)'))));
    const rows = [
      ['Rareté', r * 20], ['Humeur (une au hasard)', r * 2], ['Sociabilité', r], ['Météo de la carte', r], ['Moment de la journée', r],
      ['Pêche (en pêchant)', r / 2], ['Curry (Miel, Doux Parfum)', r / 2], ['Destin (anniversaire du joueur)', r / 2],
    ];
    const three = (n) => { const p = 1 / Math.max(1, n); return 1 / (1 - Math.pow(1 - p, 3)); };
    box.appendChild(h('div', { class: 'pjmm-odds' },
      h('span', { class: 'pjmm-oh' }, 'Pokémon sauvage'), h('span', { class: 'pjmm-oh' }, 'Chance'), h('span', { class: 'pjmm-oh' }, 'Avec le Charme Insigne'),
      rows.map(([label, n]) => [h('span', null, label), h('span', null, odds(n)), h('span', null, '≈ ' + odds(three(n)))]),
      h('span', { class: 'pjmm-oh' }, 'En route'), h('span', null, ''), h('span', null, ''),
      h('span', null, `Partenaire (tous les ${s.partner_steps} pas)`), h('span', null, odds(r * 2)), h('span', null, odds(r)),
      h('span', null, 'Trouvaille (objet ramassé)'), h('span', null, odds(r * 2)), h('span', null, odds(r)),
      h('span', null, 'Gourmet (baies)'), h('span', null, odds(r / 2)), h('span', null, odds(r / 4))));
    box.appendChild(h('div', { class: 'pjs-hint' },
      'Pour un Pokémon sauvage, un seul insigne est tiré, dans l’ordre du tableau (trois essais avec le Charme Insigne). Les Pokémon errants n’en reçoivent pas.'
      + (S.ctx.charm ? '' : ' L’objet « mark_charm » (Charme Insigne) n’existe pas dans Données > Objets.')));
    return box;
  }

  // --- Titres ------------------------------------------------------------------------------------
  function renderTitles() {
    const s = st();
    const sel = h('select', { class: 'pjs-input', onchange: (e) => set(() => { s.title_color = Number(e.target.value); }) },
      h('option', { value: '-1' }, 'Sans couleur'),
      (S.palette || Array.from({ length: 29 }, () => '')).map((col, i) => (i === 0 ? null : h('option', { value: String(i), style: col ? { color: col } : null }, `Couleur n° ${i}`))));
    sel.value = String(s.title_color);
    const swatch = h('span', { class: 'pjmm-swatch', style: { background: s.title_color >= 0 && S.palette ? S.palette[s.title_color] || 'transparent' : 'transparent' } });
    return block('Titres', null,
      h('div', { class: 'pjmm-grid3' },
        h('div', { class: 'pjmm-field' }, h('span', { class: 'pjs-label' }, 'Couleur des titres en combat'), h('div', { class: 'pjmm-inline' }, sel, swatch)),
        h('div', { class: 'pjmm-checks', style: { gridColumn: 'span 2' } },
          check('auto_title', 'Le premier souvenir à titre devient le titre'),
          check('battle_titles', 'Titres dans les messages de combat'),
          check('battle_icon', 'Icône du souvenir au-dessus du Pokémon qui sort'),
          check('collapse_ranks', 'Résumé : rangs regroupés par défaut'))),
      h('div', { class: 'pjs-hint' }, 'Couleurs du jeu (graphics/windowskins/_colors.png). Le joueur choisit le titre dans la page Souvenirs du résumé.'));
  }

  // --- Catalogue ---------------------------------------------------------------------------------
  function filtered() {
    const q = plain(S.search);
    return S.ctx.mementos.filter((m) => {
      if (q && !plain(text(m, 'name')).includes(q) && !m.symbol.includes(q) && !plain(text(m, 'title')).includes(q)) return false;
      switch (S.filter) {
        case 'all': return true;
        case 'ribbon': return !isMark(m);
        case 'mark': return isMark(m);
        case 'title': return givesTitle(m);
        case 'custom': return !!custom(m.symbol);
        default: return m.category === S.filter;
      }
    });
  }
  function renderCatalog() {
    const shown = filtered();
    const head = h('div', { class: 'pjmm-actions' },
      h('input', { class: 'pjs-input pjmm-search', placeholder: 'Rechercher…', value: S.search, 'data-focus': 'search', type: 'text', oninput: (e) => { S.search = e.target.value; render(); } }),
      h('select', { class: 'pjs-input pjmm-filter', onchange: (e) => set(() => { S.filter = e.target.value; }) },
        FILTERS.map(([k, label]) => h('option', { value: k, selected: S.filter === k }, label))));
    const marks = S.ctx.mementos.filter(isMark).length;
    const box = block(`Rubans et insignes (${S.ctx.mementos.length - marks} rubans, ${marks} insignes)`, head);
    const wrapEl = h('div', { class: 'pjmm-catalog' });
    const list = h('div', { class: 'pjmm-list' });
    shown.forEach((m) => {
      list.appendChild(h('div', { class: 'pjmm-item' + (m.symbol === S.selected ? ' sel' : '') + (custom(m.symbol) ? ' custom' : ''), title: m.symbol,
        onclick: () => set(() => { S.selected = m.symbol; }) },
        bgBox(ribbonIcon(m), 'pjmm-ico'),
        h('span', { class: 'pjmm-iname' }, h('span', null, text(m, 'name')),
          h('span', { class: 'pjs-hint inline' }, `${CATEGORY_NAMES[m.category] || ''}${givesTitle(m) ? ' · ' + fullTitle(m) : ''}`))));
    });
    if (!shown.length) list.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun souvenir.'));
    wrapEl.appendChild(list);
    wrapEl.appendChild(renderEditor());
    box.appendChild(wrapEl);
    return box;
  }
  function renderEditor() {
    const m = memento(S.selected);
    const panel = h('div', { class: 'pjmm-editor' });
    if (!m) return panel;
    const c = custom(m.symbol);
    const input = (key, lang, area) => {
      const val = c && Array.isArray(c[key]) ? c[key][lang] || '' : '';
      const ph = m[key] ? m[key][lang] || '' : '';
      const attrs = { class: 'pjs-input', value: val, placeholder: ph || (key === 'title' ? 'pas de titre' : ''), 'data-focus': `${key}-${lang}`,
        onchange: (e) => set(() => {
          const t = S.config.texts[m.symbol] || (S.config.texts[m.symbol] = {});
          const pair = Array.isArray(t[key]) ? t[key] : ['', ''];
          pair[lang] = e.target.value.trim();
          t[key] = pair;
          cleanTexts();
        }) };
      return area ? h('textarea', Object.assign(attrs, { rows: 3 })) : h('input', Object.assign(attrs, { type: 'text' }));
    };
    const how = isMark(m) ? (HOW_MARK[m.symbol] || HOW[m.category] || '') : '';
    panel.appendChild(h('div', { class: 'pjmm-ehead' }, bgBox(ribbonIcon(m), 'pjmm-big'),
      h('div', { class: 'pjmm-grow' }, h('div', { class: 'pjmm-ename' }, text(m, 'name')),
        h('div', { class: 'pjs-hint inline' }, `${isMark(m) ? 'Insigne' : 'Ruban'} · ${CATEGORY_NAMES[m.category] || m.category} · ${m.symbol}${m.psdk ? ' (PSDK)' : ''}`),
        how ? h('div', { class: 'pjs-hint inline' }, how) : null),
      c ? h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { delete S.config.texts[m.symbol]; }) }, 'Textes d’origine') : null));
    panel.appendChild(h('div', { class: 'pjmm-grid2' },
      field('Nom (français)', input('name', 0)), field('Nom (anglais)', input('name', 1)),
      field('Description (français)', input('description', 0, true)), field('Description (anglais)', input('description', 1, true)),
      field('Titre (français)', input('title', 0), 'ex. « l’Affamé », « {name} de {owner} »'), field('Titre (anglais)', input('title', 1))));
    if (m.ranks.length) {
      panel.appendChild(h('div', { class: 'pjs-label' }, `Rangs précédents (${m.ranks.length}) : regroupés sous ce ruban dans le résumé`));
      panel.appendChild(h('div', { class: 'pjmm-ranks' }, m.ranks.map((sym) => {
        const r = memento(sym);
        return r ? h('span', { class: 'pjmm-rank', title: text(r, 'name'), onclick: () => set(() => { S.selected = sym; }) }, bgBox(ribbonIcon(r), 'pjmm-ico')) : null;
      })));
    }
    panel.appendChild(h('div', { class: 'pjs-hint' },
      'Les champs vides gardent le texte d’origine (en gris). Titre : ajouté après le nom, ou à la place de {name} ; {owner} = dresseur d’origine, {player} = joueur.'));
    return panel;
  }

  // --- Titres des Pokémon des dresseurs ----------------------------------------------------------
  function renderTrainers() {
    const rows = S.config.trainers;
    const box = block('Titres des Pokémon des dresseurs',
      h('button', { class: 'pjs-btn small secondary', disabled: !S.ctx.trainers.length,
        onclick: () => set(() => { rows.push({ trainer: S.ctx.trainers[0].db, slot: 0, memento: 'champion' }); }) }, '+ Titre'));
    if (!rows.length) box.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun : les Pokémon des dresseurs n’ont pas de titre.'));
    const titled = S.ctx.mementos.filter(givesTitle);
    rows.forEach((row, i) => {
      const tr = S.ctx.trainers.find((t) => t.db === row.trainer);
      const tSel = h('select', { class: 'pjs-input', onchange: (e) => set(() => { row.trainer = e.target.value; row.slot = 0; }) },
        S.ctx.trainers.map((t) => h('option', { value: t.db }, `${t.name} (${t.db})`)));
      tSel.value = row.trainer;
      if (!tr) tSel.appendChild(h('option', { value: row.trainer, selected: true }, `${row.trainer} (introuvable)`));
      const party = tr ? tr.party : [];
      const pSel = h('select', { class: 'pjs-input', onchange: (e) => set(() => { row.slot = Number(e.target.value); }) },
        (party.length ? party : [{ name: 'Pokémon n° 1' }]).map((p, j) => h('option', { value: String(j) }, `${j + 1}. ${p.name}${p.level ? ' (N. ' + p.level + ')' : ''}`)));
      pSel.value = String(row.slot || 0);
      const mSel = h('select', { class: 'pjs-input', onchange: (e) => set(() => { row.memento = e.target.value; }) },
        titled.map((m) => h('option', { value: m.symbol }, `${text(m, 'name')} — ${text(m, 'title')}`)));
      mSel.value = row.memento;
      const mon = party[row.slot || 0];
      const m = memento(row.memento);
      box.appendChild(h('div', { class: 'pjmm-trow' },
        mon && mon.id !== null ? bgBox(pokeIcon(mon.id), 'pjmm-ico pjmm-poke') : h('span', { class: 'pjmm-ico' }),
        tSel, pSel, mSel,
        h('span', { class: 'pjmm-tprev' }, m && mon ? fullTitle(m, mon.name, tr ? tr.name : '') : ''),
        h('button', { class: 'pjs-btn small danger', onclick: () => set(() => { rows.splice(i, 1); }) }, '✕')));
    });
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Le Pokémon reçoit le souvenir au début du combat et le porte comme titre (« Vas-y, Migalos le Maître ! »).'));
    return box;
  }

  // --- Commandes ---------------------------------------------------------------------------------
  function copy(t) { try { navigator.clipboard.writeText(t); toast('Copié'); } catch (e) { /* rien */ } }
  function renderCommands() {
    const sym = S.selected || 'rainy_mark';
    const cmds = [
      [`donner_souvenir(0, :${sym})`, 'donne le souvenir au Pokémon n° 0 de l’équipe'],
      [`retirer_souvenir(0, :${sym})`, 'le retire'],
      [`souvenir?(0, :${sym})`, 'condition : le Pokémon l’a-t-il ?'],
      [`donner_titre(0, :${sym})`, 'en fait le titre du Pokémon (donner_titre(0, nil) le retire)'],
      ['titre_pokemon(0)', 'nom avec titre (« Pikachu l’Affamé »)'],
      ['taille_pokemon(0)', 'taille de 0 à 255 (taille_pokemon(0, 255) la change)'],
      ['insigne_sauvage(0)', 'tirage d’un insigne comme pour un Pokémon sauvage'],
      ['choisir_anniversaire', 'le joueur choisit la date de son anniversaire (insigne Destin)'],
      ['definir_anniversaire(14, 2)', 'anniversaire réglé par l’évènement (jour, mois)'],
      ['debug_souvenirs', 'menu de test'],
    ];
    return block('Commandes d’évènement (Script)', null, h('div', { class: 'pjmm-cmds' }, cmds.map(([cmd, hint]) => h('div', { class: 'pjmm-cmdrow' },
      h('code', { class: 'pjmm-cmd', title: 'Cliquer pour copier', onclick: () => copy(cmd) }, cmd), h('span', { class: 'pjs-hint inline' }, hint)))));
  }

  // ---------------------------------------------------------------------------
  // Page : Données > Pokémon > Rubans et insignes (/database/mementos)
  // ---------------------------------------------------------------------------
  function mount(hostEl) {
    root = h('div', { id: 'pjmm-root' });
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

  window.pjMementosEditor = { state: S, render };
})();

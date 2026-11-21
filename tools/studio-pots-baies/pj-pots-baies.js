/* eslint-disable */
// =============================================================================
// Pots à baies — page « Données > Baies > Pots à baies » de Pokémon Studio
//   Réglages des pots (nombre, vitesse de pousse, récolte), arrosoirs reconnus, engrais et leurs effets,
//   baies qui poussent en pot, sons ; aperçu de l'écran du jeu.
// Enregistre Data/configs/plugins/pots_baies.json (plugin « berrydex », objet « Pots à Baies »).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjPotsBaiesLoaded) return;
  window.__pjPotsBaiesLoaded = true;

  const PAGE_ID = 'pots-baies';
  const GFX = 'graphics/interface/pots_baies';
  const DEFAULT_SETTINGS = {
    initial_pots: 4, max_pots: 10, growth_speed: 100, water_for_max: 4, need_can: true, mulch_enabled: true, show_time: true,
    harvest_me: 'audio/me/obtained a berry!', water_se: 'audio/se/se_gui_berrypots_water', plant_se: 'audio/se/se_gui_berrypots_plant',
  };
  const DEFAULT_CANS = [
    { item: 'wailmer_pail', image: 'wailmer_pail' }, { item: 'sprinklotad', image: 'sprinklotad' },
    { item: 'squirt_bottle', image: 'squirt_bottle' }, { item: 'sprayduck', image: 'sprayduck' },
  ];
  const DEFAULT_MULCHES = {
    growth_mulch: { growth: 75, water: 75, bonus: 0 }, damp_mulch: { growth: 150, water: 150, bonus: 0 }, rich_mulch: { growth: 100, water: 100, bonus: 2 },
  };
  const DEFAULTS = { klass: 'PotsBaiesConfig', settings: DEFAULT_SETTINGS, cans: DEFAULT_CANS, mulches: DEFAULT_MULCHES, excluded: [] };
  const STAGES = ['Graine', 'Germe', 'Pousse', 'En fleur', 'Prête !'];

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjPotsBaies;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API des pots à baies n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const itemIcon = (it) => loadImage(`graphics/icons/${it && it.icon ? it.icon : '000'}`);
  const hours = (minutes) => (minutes < 60 ? `${Math.max(1, Math.round(minutes))} min` : `${Math.round(minutes / 6) / 10} h`.replace('.', ','));

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = { open: false, projectPath: null, ctx: null, config: null, saved: null, error: null, building: false, search: '', onlyPots: false };
  let root = null;
  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => S.config && S.saved !== snapshot();
  const st = () => S.config.settings;
  const itemOf = (db) => S.ctx.items.find((i) => i.db === db);
  const berries = () => S.ctx.items.filter((i) => i.berry);
  const plantable = (b) => !S.config.excluded.includes(b.db);

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null;
    imageCache.clear();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      S.config = Object.assign(clone(DEFAULTS), S.ctx.config || {});
      S.config.settings = Object.assign(clone(DEFAULT_SETTINGS), S.config.settings || {});
      if (!Array.isArray(S.config.cans)) S.config.cans = clone(DEFAULT_CANS);
      if (!S.config.mulches || typeof S.config.mulches !== 'object' || Array.isArray(S.config.mulches)) S.config.mulches = clone(DEFAULT_MULCHES);
      if (!Array.isArray(S.config.excluded)) S.config.excluded = [];
      S.saved = S.ctx.config ? snapshot() : null;
    } catch (e) { S.error = e.message; }
    render();
  }
  function problems() {
    const out = [];
    const s = st();
    if (s.initial_pots > s.max_pots) out.push('Le joueur commence avec plus de pots que le maximum.');
    S.config.cans.forEach((c, i) => { if (!c.item) out.push(`L’arrosoir n° ${i + 1} n’a pas d’objet.`); });
    const seen = new Set();
    S.config.cans.forEach((c) => { if (c.item && seen.has(c.item)) out.push(`Arrosoir en double : ${c.item}`); seen.add(c.item); });
    return out;
  }
  async function save() {
    if (!S.config) return;
    const p = problems();
    if (p.length) { toast('À corriger avant d’enregistrer : ' + p[0], true); return; }
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
  const soft = (fn) => { fn(); updateStatus(); const cv = root && root.querySelector('.pjpb-canvas'); if (cv) drawPreview(cv); };

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    const prev = root.querySelector('.pjpb-detail');
    const scroll = prev ? prev.scrollTop : 0;
    const focused = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.focus : null;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Pots à baies'),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    if (S.error) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty err' }, S.error))); return; }
    if (!S.config) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty' }, 'Chargement…'))); return; }
    const detail = h('div', { class: 'pjpb-detail' });
    root.appendChild(detail);
    const content = h('div', { class: 'pjpb-content' });
    detail.appendChild(content);
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/pots_baies est introuvable.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, "Le plugin « berrydex » n'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul)."));
    if (!itemOf('berry_pots')) content.appendChild(h('div', { class: 'pjs-warn' }, "L'objet « berry_pots » (Pots à Baies) n'existe pas dans Données > Objets : les pots ne s'ouvriront qu'avec la commande pots_a_baies."));
    const row = h('div', { class: 'pjpb-row' });
    content.appendChild(row);
    row.appendChild(renderPreview());
    const right = h('div', { class: 'pjpb-right' });
    row.appendChild(right);
    right.appendChild(renderSettings());
    right.appendChild(renderSounds());
    const row2 = h('div', { class: 'pjpb-row2' });
    content.appendChild(row2);
    row2.appendChild(renderCans());
    row2.appendChild(renderMulches());
    content.appendChild(renderBerries());
    content.appendChild(renderCommands());
    detail.scrollTop = scroll;
    if (focused) { const el = root.querySelector(`[data-focus="${focused}"]`); if (el) { el.focus(); if (el.setSelectionRange && el.type === 'text') el.setSelectionRange(el.value.length, el.value.length); } }
  }

  const block = (title, extra, ...kids) => h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title), extra || null), kids);
  const field = (label, input, hint) => h('label', { class: 'pjpb-field' }, h('span', { class: 'pjs-label' }, label), input, hint ? h('span', { class: 'pjs-hint inline' }, hint) : null);
  const num = (value, min, max, onset, focus) => h('input', { class: 'pjs-input pjpb-num', type: 'number', min, max, value, 'data-focus': focus,
    onchange: (e) => set(() => onset(Math.min(max, Math.max(min, Math.round(Number(e.target.value) || 0))))) });
  function itemSelect(value, filter, onset, emptyLabel) {
    const sel = h('select', { class: 'pjs-input', onchange: (e) => set(() => onset(e.target.value)) },
      emptyLabel ? h('option', { value: '' }, emptyLabel) : null,
      S.ctx.items.filter(filter).map((i) => h('option', { value: i.db }, `${i.name} (${i.db})`)));
    sel.value = value || '';
    if (value && !S.ctx.items.some((i) => i.db === value)) sel.appendChild(h('option', { value, selected: true }, `${value} (introuvable)`));
    sel.value = value || '';
    return sel;
  }

  // --- Aperçu (écran du jeu, 320 x 240) ---------------------------------------------------------
  function renderPreview() {
    const box = block('Aperçu en jeu');
    const cv = h('canvas', { class: 'pjpb-canvas', width: 320, height: 240 });
    box.appendChild(cv);
    drawPreview(cv);
    box.appendChild(h('div', { class: 'pjs-hint' },
      'Exemple avec le nombre de pots de départ et des baies à différents stades. En jeu : flèches pour choisir un pot, A pour planter, mettre de l’engrais, arroser ou cueillir ; l’arrosoir se change à droite.'));
    return box;
  }
  let drawToken = 0;
  async function drawPreview(cv) {
    const token = ++drawToken;
    const n = Math.max(1, Math.min(10, st().initial_pots | 0, st().max_pots | 0));
    const rows = n > 5 ? 2 : 1;
    const sample = berries().filter(plantable).slice(0, n);
    const names = ['horizon/team/fond', 'horizon/header', 'horizon/tcard/button_background', 'pots_baies/side', `pots_baies/shelf_${rows}`,
      'pots_baies/pot_dry', 'pots_baies/pot_damp', 'pots_baies/pot_wet', 'pots_baies/cursor', 'pots_baies/quit', 'pots_baies/info', 'pots_baies/drop'];
    const I = {};
    (await Promise.all(names.map((nm) => loadImage('graphics/interface/' + nm)))).forEach((im, i) => { I[names[i].split('/').pop()] = im; });
    const firstCan = S.config.cans.find((c) => c.item) || null;
    const canIm = firstCan ? await loadImage(`${GFX}/cans/${firstCan.image || firstCan.item}`) : null;
    const plants = await Promise.all(sample.map((b, i) => loadImage(`graphics/characters/${i % 5 === 0 ? 'z_bp' : 'z_b' + b.id}`)));
    if (token !== drawToken) return;
    const c = cv.getContext('2d');
    c.imageSmoothingEnabled = false;
    const draw = (im, x, y) => { if (im) c.drawImage(im, x, y); };
    const text = (s, x, y, o = {}) => {
      c.font = `${o.small ? 9 : 11}px "Avenir Next", sans-serif`;
      c.fillStyle = o.color || '#282828'; c.textBaseline = 'top'; c.textAlign = o.align || 'left';
      c.fillText(s, x, y);
    };
    c.fillStyle = '#e5f3fa'; c.fillRect(0, 0, 320, 240);
    draw(I.fond, 0, 0); draw(I.header, 0, 0); draw(I.button_background, 0, 214);
    text('POTS À BAIES', 160, 7, { align: 'center', color: '#fff' });
    text(`Pots : ${n}`, 6, 9, { small: true, color: '#fff' });
    draw(I[`shelf_${rows}`], 6, 32);
    draw(I.side, 256, 32);
    if (canIm) c.drawImage(canIm, 0, 0, 44, 40, 262, 45, 44, 40);
    text('Arrosoir', 285, 131, { small: true, color: '#fff', align: 'center' });
    if (I.quit) c.drawImage(I.quit, 0, 0, 50, 18, 260, 164, 50, 18);
    text('Quitter', 285, 168, { small: true, align: 'center' });
    const planks = rows === 1 ? [156] : [109, 181];
    const stageOf = (i) => [0, 1, 2, 3, 4][i % 5];
    const moist = (i) => ['pot_wet', 'pot_damp', 'pot_dry', 'pot_damp', 'pot_dry'][i % 5];
    for (let i = 0; i < n; i++) {
      const row = Math.floor(i / 5);
      const inRow = rows === 1 ? n : 5;
      const x0 = 6 + Math.floor((246 - inRow * 48) / 2);
      const x = x0 + (i % 5) * 48;
      const plank = planks[row];
      draw(I[i < sample.length ? moist(i) : 'pot_dry'], x + 4, plank - 27);
      const im = plants[i];
      if (im && i < sample.length) {
        const w = im.width / 4; const hh = im.height / 4;
        const stage = stageOf(i);
        const r = stage === 0 ? 3 : stage - 1;
        c.drawImage(im, 0, r * hh, w, hh, x + 24 - w / 2, plank - 16 - hh, w, hh);
      }
      if (i === 1 && I.cursor) c.drawImage(I.cursor, 0, 0, 48, 78, x, plank - 76, 48, 78);
    }
    draw(I.info, 6, 192);
    const sel = sample[1] || sample[0];
    if (sel) {
      text(`${sel.name} - ${STAGES[stageOf(sample.indexOf(sel))]}`, 16, 195);
      if (I.drop) c.drawImage(I.drop, 18, 0, 18, 8, 220, 198, 18, 8);
      if (st().show_time) text(`≈ ${Math.max(1, Math.round(sel.growth * 0.75 * 100 / Math.max(1, st().growth_speed)))} h`, 308, 197, { small: true, align: 'right' });
    } else text('Aucune baie ne pousse en pot.', 16, 195);
    text('A : S’occuper du pot   B : Quitter', 160, 222, { small: true, color: '#fff', align: 'center' });
  }

  // --- Réglages --------------------------------------------------------------------------------
  function renderSettings() {
    const s = st();
    const box = block('Réglages des pots');
    box.appendChild(h('div', { class: 'pjpb-grid3' },
      field('Pots au départ', num(s.initial_pots, 0, 10, (v) => { s.initial_pots = v; }, 'initial'), 'avant ajouter_pots'),
      field('Pots au maximum', num(s.max_pots, 1, 10, (v) => { s.max_pots = v; }, 'max'), '10 au plus'),
      field('Vitesse de pousse (%)', num(s.growth_speed, 10, 1000, (v) => { s.growth_speed = v; }, 'speed'), '200 = deux fois plus vite')));
    box.appendChild(h('div', { class: 'pjpb-grid3' },
      field('Arrosages pour la récolte max.', num(s.water_for_max, 1, 10, (v) => { s.water_for_max = v; }, 'water'), 'comme PSDK : 4'),
      h('div', { class: 'pjpb-checks' },
        h('label', { class: 'pjs-inline pjpb-check' }, h('input', { type: 'checkbox', checked: !!s.need_can, onchange: (e) => set(() => { s.need_can = e.target.checked; }) }), 'Arrosoir obligatoire pour arroser'),
        h('label', { class: 'pjs-inline pjpb-check' }, h('input', { type: 'checkbox', checked: !!s.mulch_enabled, onchange: (e) => set(() => { s.mulch_enabled = e.target.checked; }) }), 'Engrais possible'),
        h('label', { class: 'pjs-inline pjpb-check' }, h('input', { type: 'checkbox', checked: !!s.show_time, onchange: (e) => set(() => { s.show_time = e.target.checked; }) }), 'Montrer le temps restant'))));
    box.appendChild(h('div', { class: 'pjs-hint' },
      'Les pots poussent avec le temps du jeu, comme les baies plantées sur la carte (même durée, réglée dans la fiche de chaque baie). La récolte va du minimum au maximum de la baie selon le nombre d’arrosages.'));
    return box;
  }

  let audio = null;
  function soundRow(label, key, list) {
    const s = st();
    const sel = h('select', { class: 'pjs-input', onchange: (e) => set(() => { s[key] = e.target.value; }) }, h('option', { value: '' }, 'Aucun'),
      list.map((m) => h('option', { value: m }, m.replace(/^audio\/(me|se)\//, ''))));
    if (s[key] && !list.includes(s[key])) sel.appendChild(h('option', { value: s[key] }, s[key] + ' (introuvable)'));
    sel.value = s[key] || '';
    return h('div', { class: 'pjpb-sound' }, field(label, sel),
      h('button', { class: 'pjs-btn small secondary', disabled: !s[key], onclick: async () => {
        try { if (audio) audio.pause(); const url = await call('readSound', { projectPath: S.projectPath, file: s[key] }); if (url) { audio = new Audio(url); audio.volume = 0.6; audio.play(); } else toast('Son introuvable', true); } catch (e) { toast(e.message, true); }
      } }, '▶'));
  }
  function renderSounds() {
    return block('Sons', null,
      soundRow('Récolte (audio/me)', 'harvest_me', S.ctx.mes),
      soundRow('Arrosage (audio/se)', 'water_se', S.ctx.ses),
      soundRow('Plantation (audio/se)', 'plant_se', S.ctx.ses));
  }

  // --- Arrosoirs -------------------------------------------------------------------------------
  async function importCan(name) {
    try {
      const r = await call('importImage', { projectPath: S.projectPath, name });
      if (!r) return null;
      imageCache.clear();
      S.ctx = Object.assign(S.ctx, await call('getContext', { projectPath: S.projectPath }), { config: S.ctx.config });
      toast('Image importée');
      return r;
    } catch (e) { toast('Import impossible : ' + e.message, true); return null; }
  }
  function renderCans() {
    const cans = S.config.cans;
    const box = block('Arrosoirs', h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { cans.push({ item: '', image: '' }); }) }, '+ Arrosoir'));
    if (!cans.length) box.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun arrosoir : on ne pourra arroser que si « Arrosoir obligatoire » est décoché.'));
    cans.forEach((cn, i) => {
      const image = cn.image || cn.item;
      const hasAnim = S.ctx.animImages.includes(image + '_anim');
      const imgSel = h('select', { class: 'pjs-input', onchange: (e) => set(() => { cn.image = e.target.value; }) },
        h('option', { value: '' }, 'Même nom que l’objet'), S.ctx.canImages.map((n) => h('option', { value: n }, n)));
      imgSel.value = cn.image && S.ctx.canImages.includes(cn.image) ? cn.image : '';
      box.appendChild(h('div', { class: 'pjpb-can' },
        bgBox(loadImage(`${GFX}/cans/${image}`), 'pjpb-canimg'),
        h('div', { class: 'pjpb-grow' },
          h('div', { class: 'pjpb-grid2' },
            field('Objet', itemSelect(cn.item, (it) => it.map && !it.berry, (v) => { cn.item = v; }, '— choisir —')),
            field('Image', imgSel, hasAnim ? 'avec animation' : 'pas d’animation (_anim)')),
          h('div', { class: 'pjpb-actions' },
            h('button', { class: 'pjs-btn small secondary', onclick: async () => { const n = await importCan(image || cn.item); if (n) set(() => { cn.image = n; }); } }, 'Importer l’image…'),
            h('button', { class: 'pjs-btn small secondary', title: 'Deux images côte à côte (88 x 62)', onclick: async () => { if (await importCan((image || cn.item) + '_anim')) render(); } }, 'Importer l’animation…'),
            h('button', { class: 'pjs-btn small secondary', disabled: i === 0, onclick: () => set(() => { cans.splice(i - 1, 0, cans.splice(i, 1)[0]); }) }, '▲'),
            h('button', { class: 'pjs-btn small secondary', disabled: i === cans.length - 1, onclick: () => set(() => { cans.splice(i + 1, 0, cans.splice(i, 1)[0]); }) }, '▼'),
            h('button', { class: 'pjs-btn small danger', onclick: () => set(() => { cans.splice(i, 1); }) }, 'Retirer')))));
    });
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Le joueur choisit parmi ceux qu’il a dans son sac. Images : graphics/interface/pots_baies/cans (44 x 62, et 88 x 62 pour l’animation).'));
    return box;
  }

  // --- Engrais ---------------------------------------------------------------------------------
  function renderMulches() {
    const m = S.config.mulches;
    const free = S.ctx.items.filter((i) => /mulch/.test(i.db) && !(i.db in m));
    const add = h('select', { class: 'pjs-input pjpb-addsel', onchange: (e) => set(() => { if (e.target.value) m[e.target.value] = { growth: 100, water: 100, bonus: 0 }; }) },
      h('option', { value: '' }, '+ Engrais…'), free.map((i) => h('option', { value: i.db }, i.name)));
    const box = block('Engrais', add);
    const keys = Object.keys(m);
    if (!keys.length) box.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun engrais reconnu.'));
    else {
      box.appendChild(h('div', { class: 'pjpb-mhead' }, h('span', null, 'Engrais'), h('span', null, 'Pousse (%)'), h('span', null, 'Humidité (%)'), h('span', null, 'Baies en +'), h('span', null, '')));
      keys.forEach((k) => {
        const e = m[k];
        const it = itemOf(k);
        box.appendChild(h('div', { class: 'pjpb-mrow' },
          h('span', { class: 'pjpb-mname' }, bgBox(itemIcon(it), 'pjpb-ico'), it ? it.name : `${k} (introuvable)`),
          num(e.growth, 10, 400, (v) => { e.growth = v; }, 'g-' + k),
          num(e.water, 10, 400, (v) => { e.water = v; }, 'w-' + k),
          num(e.bonus, 0, 10, (v) => { e.bonus = v; }, 'b-' + k),
          h('button', { class: 'pjs-btn small danger', onclick: () => set(() => { delete m[k]; }) }, '✕')));
      });
    }
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Mis dans un pot vide avant de planter. Pousse : durée de chaque stade (75 = plus rapide). Humidité : durée pendant laquelle la terre reste mouillée. Baies en + : ajoutées à la récolte.'));
    if (!st().mulch_enabled) box.appendChild(h('div', { class: 'pjs-hint' }, 'L’engrais est désactivé dans les réglages.'));
    return box;
  }

  // --- Baies -----------------------------------------------------------------------------------
  function renderBerries() {
    const all = berries();
    const q = plain(S.search);
    const shown = all.filter((b) => (!q || plain(b.name).includes(q) || b.db.includes(q)) && (!S.onlyPots || !plantable(b)));
    const speed = Math.max(1, st().growth_speed);
    const head = h('div', { class: 'pjpb-actions' },
      h('input', { class: 'pjs-input pjpb-search', placeholder: 'Rechercher une baie…', value: S.search, 'data-focus': 'search', type: 'text', oninput: (e) => { S.search = e.target.value; render(); } }),
      h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: S.onlyPots, onchange: (e) => set(() => { S.onlyPots = e.target.checked; }) }), 'Seulement celles qui ne poussent pas'),
      h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { S.config.excluded = []; }) }, 'Toutes en pot'));
    const box = block(`Baies (${all.filter(plantable).length} / ${all.length} poussent en pot)`, head);
    const grid = h('div', { class: 'pjpb-berries' });
    shown.forEach((b) => {
      const ok = plantable(b);
      const total = b.growth * 60 * 100 / speed; // minutes de la graine à la baie mûre
      grid.appendChild(h('label', { class: 'pjpb-berry' + (ok ? '' : ' off'), title: b.db },
        h('input', { type: 'checkbox', checked: ok, onchange: (e) => set(() => {
          S.config.excluded = S.config.excluded.filter((x) => x !== b.db);
          if (!e.target.checked) S.config.excluded.push(b.db);
        }) }),
        bgBox(itemIcon(b), 'pjpb-ico'),
        h('span', { class: 'pjpb-bname' }, h('span', null, b.name), h('span', { class: 'pjs-hint inline' }, `${hours(total)} · ${b.min}-${b.max} baies`))));
    });
    if (!shown.length) grid.appendChild(h('div', { class: 'pjs-hint' }, 'Aucune baie.'));
    box.appendChild(grid);
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Temps de la graine à la baie mûre (temps du jeu, avec la vitesse de pousse) et récolte minimum-maximum. Une baie décochée ne peut pas être plantée en pot.'));
    return box;
  }

  // --- Commandes -------------------------------------------------------------------------------
  function copy(t) { try { navigator.clipboard.writeText(t); toast('Copié'); } catch (e) { /* rien */ } }
  function renderCommands() {
    const cmds = [
      ['pots_a_baies', 'ouvre les pots (comme l’objet « Pots à Baies » du sac)'],
      ['ajouter_pots', 'donne un pot de plus (ajouter_pots(2) : deux) ; false si le maximum est atteint'],
      ['nombre_pots', 'nombre de pots du joueur'],
      ['pots_prets', 'nombre de pots dont les baies sont mûres (condition : pots_prets > 0)'],
    ];
    return block('Commandes d’évènement (Script)', null, h('div', { class: 'pjpb-cmds' }, cmds.map(([cmd, hint]) => h('div', { class: 'pjpb-cmdrow' },
      h('code', { class: 'pjpb-cmd', title: 'Cliquer pour copier', onclick: () => copy(cmd) }, cmd), h('span', { class: 'pjs-hint inline' }, hint)))));
  }

  // ---------------------------------------------------------------------------
  // Page : Données > Baies > Pots à baies (/database/berries/pots)
  // ---------------------------------------------------------------------------
  function mount(hostEl) {
    root = h('div', { id: 'pjpb-root' });
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
    if (root) { root = null; S.open = false; if (audio) audio.pause(); }
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

  window.pjPotsBaiesEditor = { state: S, render };
})();

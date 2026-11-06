/* eslint-disable */
// =============================================================================
// Variantes — éditeur des Pokémon Argentés, Dorés et Radiants (plugin « variantes ») pour Pokémon Studio
// Ouvert par « Plugins > Variantes » dans le menu de la base de données (ou Ctrl+Maj+V).
//   Onglet « Radiant »  : recolore les sprites existants (palette, teinte, saturation, luminosité)
//                         et enregistre graphics/pokedex/poke*radiant/<sprite normal>.png
//   Onglet « Réglages » : taux d'apparition, dégradés Argenté / Doré (recoloration faite en jeu)
// Utilise le style de l'éditeur Smartphone (classes pjs-*), installé avant lui.
// =============================================================================
(() => {
  'use strict';
  if (window.__pjVariantesLoaded) return;
  window.__pjVariantesLoaded = true;

  // ---------------------------------------------------------------------------
  // Données par défaut (les mêmes que dans le plugin)
  // ---------------------------------------------------------------------------
  const DEFAULTS = {
    klass: 'VariantesConfig',
    silver_rate: 8192,
    gold_rate: 8192,
    radiant_rate: 4096,
    count_as_shiny: true,
    silver_colors: ['#22242f', '#6a7082', '#b7bdcc', '#f6f8ff'],
    gold_colors: ['#3c2204', '#a2680e', '#e6b232', '#fff4a6'],
    radiant: [],
  };
  // Sprites d'une forme : sorte (dossier), clé du sprite normal, clé du sprite chromatique
  const KINDS = [
    { dir: 'front', normal: 'front', shiny: 'frontShiny', label: 'Face' },
    { dir: 'front', normal: 'frontF', shiny: 'frontShinyF', label: 'Face ♀', female: true },
    { dir: 'back', normal: 'back', shiny: 'backShiny', label: 'Dos' },
    { dir: 'back', normal: 'backF', shiny: 'backShinyF', label: 'Dos ♀', female: true },
    { dir: 'icon', normal: 'icon', shiny: 'iconShiny', label: 'Icône' },
    { dir: 'icon', normal: 'iconF', shiny: 'iconShinyF', label: 'Icône ♀', female: true },
  ];
  const PALETTE_MAX = 96;
  const SCALE = 2;

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjVariantes;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API Variantes n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  let toastTimer = null;
  function toast(msg, err) {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.remove(), err ? 6000 : 2500);
  }
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  function projectUrl(rel, type) {
    const u = new URL(rel.split('/').map(encodeURIComponent).join('/'), window.__pjEventsProjectBase || 'project://--/');
    u.searchParams.append('projectPath', S.projectPath);
    if (type) u.searchParams.append('type', type);
    return u.toString();
  }

  // couleurs
  const hex2 = (n) => n.toString(16).padStart(2, '0');
  const rgbToHex = (r, g, b) => '#' + hex2(r) + hex2(g) + hex2(b);
  const hexToRgb = (hex) => {
    const m = /^#?([0-9a-f]{6})$/i.exec(String(hex || '').trim());
    if (!m) return null;
    const v = parseInt(m[1], 16);
    return [(v >> 16) & 255, (v >> 8) & 255, v & 255];
  };
  function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b); const min = Math.min(r, g, b);
    let hue = 0; let sat = 0; const l = (max + min) / 2;
    if (max !== min) {
      const d = max - min;
      sat = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      if (max === r) hue = (g - b) / d + (g < b ? 6 : 0);
      else if (max === g) hue = (b - r) / d + 2;
      else hue = (r - g) / d + 4;
      hue *= 60;
    }
    return [hue, sat, l];
  }
  function hslToRgb(hue, sat, l) {
    hue = ((hue % 360) + 360) % 360 / 360;
    if (sat === 0) { const v = Math.round(l * 255); return [v, v, v]; }
    const q = l < 0.5 ? l * (1 + sat) : l + sat - l * sat;
    const p = 2 * l - q;
    const f = (t) => {
      if (t < 0) t += 1; if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    };
    return [Math.round(f(hue + 1 / 3) * 255), Math.round(f(hue) * 255), Math.round(f(hue - 1 / 3) * 255)];
  }
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = {
    open: false,
    projectPath: null,
    ctx: null,
    config: null,
    saved: null,
    savedEntries: {},  // clé du Radiant -> JSON enregistré (pour ne refaire que les images modifiées)
    removals: [],      // images Radiantes à supprimer à l'enregistrement
    tab: 'radiant',
    query: '',
    sel: null,         // { db, form }
    images: new Map(), // chemin -> Promise<ImageData|null>
    loaded: null,      // { key, set, imgs } pour la sélection
    error: null,
    pluginBuilding: false,
    pluginError: null,
  };
  let root = null;
  let refs = null; // éléments de l'éditeur mis à jour sans tout redessiner

  const snapshot = () => JSON.stringify([S.config, S.removals]);
  const dirty = () => S.config && S.saved !== snapshot();
  const entryKey = (e) => `${e.creature}/${e.form | 0}`;

  // ---------------------------------------------------------------------------
  // Données
  // ---------------------------------------------------------------------------
  const creatureOf = (db) => S.ctx && S.ctx.creatures.find((c) => c.dbSymbol === db);
  const formOf = (creature, form) => creature && (creature.forms.find((f) => (f.form | 0) === (form | 0)) || creature.forms[0]);
  const entryOf = (db, form) => S.config.radiant.find((e) => e.creature === db && (e.form | 0) === (form | 0));

  // Sprites d'une forme (sans doublon de fichier)
  function spriteSet(creature, form) {
    const fm = formOf(creature, form);
    if (!fm) return [];
    const res = fm.resources || {};
    const dirs = S.ctx.dirs;
    const seen = new Set();
    const out = [];
    KINDS.forEach((k) => {
      if (k.female && !res.hasFemale) return;
      const name = res[k.normal];
      if (!name || seen.has(k.dir + '/' + name)) return;
      seen.add(k.dir + '/' + name);
      const shiny = res[k.shiny];
      out.push({
        kind: k.dir, label: k.label, filename: name,
        normalRel: `${dirs[k.dir][0]}/${name}.png`,
        shinyRel: shiny ? `${dirs[k.dir][1]}/${shiny}.png` : null,
        radiantRel: `${dirs[k.dir][2]}/${name}.png`,
      });
    });
    return out;
  }

  // Le Radiant a-t-il déjà des images ?
  const hasRadiantFiles = (creature, form) => {
    const fm = formOf(creature, form);
    const name = fm && fm.resources && fm.resources.front;
    return !!(name && S.ctx.radiant.front.includes(name));
  };

  function decode(url) {
    return new Promise((resolve) => {
      if (!url) { resolve(null); return; }
      const img = new Image();
      img.onload = () => {
        const c = document.createElement('canvas');
        c.width = img.width; c.height = img.height;
        const g = c.getContext('2d');
        g.drawImage(img, 0, 0);
        try { resolve(g.getImageData(0, 0, img.width, img.height)); } catch (e) { resolve(null); }
      };
      img.onerror = () => resolve(null);
      img.src = url;
    });
  }

  async function loadImages(rels) {
    const need = [...new Set(rels.filter((r) => r && !S.images.has(r)))];
    if (need.length) {
      const pending = call('readImages', { projectPath: S.projectPath, files: need });
      need.forEach((r) => S.images.set(r, pending.then((m) => decode(m[r])).catch(() => null)));
    }
    const out = {};
    for (const r of rels) if (r) out[r] = await S.images.get(r);
    return out;
  }

  // Image de base d'un sprite pour un Radiant (chromatique si demandé et présent, sinon normal)
  const baseImage = (item, imgs, entry) => (entry && entry.base === 'shiny' && item.shinyRel && imgs[item.shinyRel]) || imgs[item.normalRel] || null;

  // ---------------------------------------------------------------------------
  // Recoloration Radiant
  // ---------------------------------------------------------------------------
  function radiantColor(hex, entry, cache) {
    if (cache && cache.has(hex)) return cache.get(hex);
    let rgb;
    const forced = entry.colors && entry.colors[hex];
    if (forced && hexToRgb(forced)) rgb = hexToRgb(forced);
    else {
      const [r, g, b] = hexToRgb(hex);
      const [hu, sa, li] = rgbToHsl(r, g, b);
      rgb = hslToRgb(hu + (entry.hue || 0), clamp(sa + (entry.saturation || 0) / 100, 0, 1), clamp(li + (entry.lightness || 0) / 100, 0, 1));
    }
    if (cache) cache.set(hex, rgb);
    return rgb;
  }

  function recolor(data, entry) {
    const out = new ImageData(new Uint8ClampedArray(data.data), data.width, data.height);
    const d = out.data;
    const cache = new Map();
    for (let i = 0; i < d.length; i += 4) {
      if (d[i + 3] === 0) continue;
      const [r, g, b] = radiantColor(rgbToHex(d[i], d[i + 1], d[i + 2]), entry, cache);
      d[i] = r; d[i + 1] = g; d[i + 2] = b;
    }
    return out;
  }

  // Palette des sprites de base : [{ hex, count }] (les plus présentes d'abord)
  function palette(set, imgs, entry) {
    const counts = new Map();
    set.forEach((item) => {
      const img = baseImage(item, imgs, entry);
      if (!img) return;
      const d = img.data;
      for (let i = 0; i < d.length; i += 4) {
        if (d[i + 3] === 0) continue;
        const hex = rgbToHex(d[i], d[i + 1], d[i + 2]);
        counts.set(hex, (counts.get(hex) || 0) + 1);
      }
    });
    return [...counts.entries()].map(([hex, count]) => ({ hex, count }))
      .sort((a, b) => b.count - a.count).slice(0, PALETTE_MAX)
      .sort((a, b) => rgbToHsl(...hexToRgb(a.hex))[0] - rgbToHsl(...hexToRgb(b.hex))[0] || rgbToHsl(...hexToRgb(a.hex))[2] - rgbToHsl(...hexToRgb(b.hex))[2]);
  }

  // ---------------------------------------------------------------------------
  // Recoloration Argenté / Doré (la même qu'en jeu, pour l'aperçu)
  // ---------------------------------------------------------------------------
  function tint(data, colors) {
    const stops = colors.map(hexToRgb).filter(Boolean);
    const out = new ImageData(new Uint8ClampedArray(data.data), data.width, data.height);
    const d = out.data;
    const lum = (i) => d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114;
    const lums = [];
    for (let i = 0; i < d.length; i += 4) if (d[i + 3] > 0) lums.push(lum(i));
    if (!lums.length || stops.length < 2) return out;
    lums.sort((a, b) => a - b);
    const low = lums[Math.floor(lums.length * 0.02)];
    let high = lums[Math.min(Math.ceil(lums.length * 0.98), lums.length - 1)];
    if (high <= low) high = low + 1;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i + 3] === 0) continue;
      const t = clamp((lum(i) - low) / (high - low), 0, 1);
      const pos = t * (stops.length - 1);
      const k = Math.min(Math.floor(pos), stops.length - 2);
      const f = pos - k;
      for (let c = 0; c < 3; c++) d[i + c] = clamp(Math.round(stops[k][c] + (stops[k + 1][c] - stops[k][c]) * f), 0, 255);
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Chargement / enregistrement
  // ---------------------------------------------------------------------------
  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null; S.loaded = null; S.images = new Map(); S.removals = [];
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      const cfg = Object.assign(clone(DEFAULTS), S.ctx.config || {});
      if (!Array.isArray(cfg.radiant)) cfg.radiant = [];
      cfg.radiant.forEach((e) => { e.form = e.form | 0; e.colors = e.colors || {}; e.base = e.base === 'shiny' ? 'shiny' : 'normal'; });
      S.config = cfg;
      S.savedEntries = Object.fromEntries(cfg.radiant.map((e) => [entryKey(e), JSON.stringify(e)]));
      S.saved = S.ctx.config ? snapshot() : null;
      if (!S.sel || !creatureOf(S.sel.db)) {
        const first = S.ctx.creatures.find((c) => c.id > 0) || S.ctx.creatures[0];
        S.sel = first ? { db: first.dbSymbol, form: first.forms[0] ? first.forms[0].form | 0 : 0 } : null;
      }
    } catch (e) { S.error = e.message; }
    render();
  }

  // Images d'un Radiant à écrire
  async function radiantImages(entry) {
    const creature = creatureOf(entry.creature);
    if (!creature) return [];
    const set = spriteSet(creature, entry.form);
    const imgs = await loadImages(set.flatMap((i) => [i.normalRel, i.shinyRel]));
    const out = [];
    set.forEach((item) => {
      const base = baseImage(item, imgs, entry);
      if (!base) return;
      const c = document.createElement('canvas');
      c.width = base.width; c.height = base.height;
      c.getContext('2d').putImageData(recolor(base, entry), 0, 0);
      out.push({ kind: item.kind, filename: item.filename, dataUrl: c.toDataURL('image/png') });
    });
    return out;
  }

  async function save() {
    if (!S.config) return;
    try {
      const write = [];
      for (const entry of S.config.radiant) {
        if (S.savedEntries[entryKey(entry)] === JSON.stringify(entry) && hasRadiantFiles(creatureOf(entry.creature), entry.form)) continue;
        write.push(...(await radiantImages(entry)));
      }
      const r = await call('save', { projectPath: S.projectPath, config: S.config, write, remove: S.removals });
      // fichiers Radiants connus
      S.removals.forEach(({ kind, filename }) => { S.ctx.radiant[kind] = S.ctx.radiant[kind].filter((n) => n !== filename); });
      write.forEach(({ kind, filename }) => { if (!S.ctx.radiant[kind].includes(filename)) S.ctx.radiant[kind].push(filename); });
      S.removals = [];
      S.savedEntries = Object.fromEntries(S.config.radiant.map((e) => [entryKey(e), JSON.stringify(e)]));
      S.saved = snapshot();
      const p = r.plugin || {};
      if (p.source) S.ctx.plugin = { source: true, installed: p.installed, outdated: p.installed ? [] : ['?'], stale: [] };
      toast(`Enregistré${write.length ? ` : ${write.length} image${write.length > 1 ? 's' : ''} Radiante${write.length > 1 ? 's' : ''}` : ''}`
        + (p.source && !p.installed ? ' — plugin pas encore installé : lance construire_plugin_variantes.bat une fois' : ''));
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
    if (S.pluginError) toast("Enregistré, mais variantes.psdkplug n'a pas pu être reconstruit : " + S.pluginError, true);
    if (buildQueued) { buildQueued = false; rebuildPlugin(); }
  }

  function statusText() {
    if (!S.config) return ['', ''];
    if (dirty()) return ['Modifications non enregistrées', ' dirty'];
    if (S.pluginBuilding) return ['Mise à jour du plugin…', ''];
    const p = S.ctx && S.ctx.plugin;
    if (p && p.source && !p.installed) return ['Plugin pas installé : construire_plugin_variantes.bat', ' dirty'];
    if (p && p.source && (p.outdated.length || p.stale.length)) return ['Plugin installé pas à jour : Enregistrer', ' dirty'];
    if (S.pluginError) return ['Plugin : paquet non reconstruit', ' dirty'];
    return ['Tout est enregistré', ''];
  }
  function updateStatus() {
    const st = root && root.querySelector('.pjs-status');
    if (!st) return;
    const [text, cls] = statusText();
    st.className = 'pjs-status' + cls; st.textContent = text;
  }

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function spriteCanvas(data, extraClass, box) {
    const c = h('canvas', { class: 'pjv-sprite' + (extraClass ? ' ' + extraClass : '') });
    drawInto(c, data, box);
    return c;
  }
  // Zone utile d'un sprite (sans les bords transparents), gardée par taille d'image pour que
  // les aperçus d'un même sprite (normal, chromatique, radiant) restent alignés
  function opaqueBox(data) {
    const d = data.data;
    let x0 = data.width; let y0 = data.height; let x1 = -1; let y1 = -1;
    for (let y = 0; y < data.height; y++) {
      for (let x = 0; x < data.width; x++) {
        if (d[(y * data.width + x) * 4 + 3] === 0) continue;
        if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
      }
    }
    if (x1 < 0) return { x: 0, y: 0, w: data.width, h: data.height };
    const pad = 2;
    x0 = Math.max(0, x0 - pad); y0 = Math.max(0, y0 - pad);
    x1 = Math.min(data.width - 1, x1 + pad); y1 = Math.min(data.height - 1, y1 + pad);
    return { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 };
  }
  function drawInto(c, data, box) {
    if (!data) { c.width = 1; c.height = 1; c.style.width = c.style.height = '0px'; return; }
    box = box || c._box || opaqueBox(data);
    c._box = box;
    c.width = box.w; c.height = box.h;
    c.style.width = box.w * SCALE + 'px'; c.style.height = box.h * SCALE + 'px';
    c.getContext('2d').putImageData(data, -box.x, -box.y, box.x, box.y, box.w, box.h);
  }

  function render() {
    if (!root) return;
    root.textContent = '';
    refs = null;
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' },
        h('span', { class: 'pjs-top-title' }, 'Variantes'),
        h('div', { class: 'pjs-tabs' },
          [['radiant', 'Radiant'], ['settings', 'Argenté, Doré & taux']].map(([tab, label]) => h('button', {
            class: 'pjs-tab' + (S.tab === tab ? ' active' : ''), onclick: () => { S.tab = tab; render(); },
          }, label))),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Variantes : abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); }, title: 'Relire les fichiers du projet' }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.config) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return; }
    const content = h('div', { class: 'pjs-content pjv-content' });
    page.appendChild(content);
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/variantes est introuvable : extrais le plugin à la racine du projet.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le plugin « variantes » n\'est pas encore installé : lance construire_plugin_variantes.bat une fois (ensuite, Enregistrer le met à jour tout seul).'));
    if (S.tab === 'settings') renderSettings(content); else renderRadiant(content);
  }

  // --- Onglet Radiant ---------------------------------------------------------
  function renderRadiant(content) {
    const row = h('div', { class: 'pjs-row pjv-row' });
    content.appendChild(row);
    row.appendChild(renderCreatureList());
    const editor = h('div', { class: 'pjs-block pjv-editor' });
    row.appendChild(editor);
    renderEditor(editor);
  }

  function renderCreatureList() {
    const block = h('div', { class: 'pjs-block pjv-list-block' });
    const count = S.config.radiant.length;
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Pokémon'), h('span', { class: 'pjs-count', title: 'Pokémon avec un Radiant' }, String(count))));
    const list = h('div', { class: 'pjv-list' });
    const search = h('input', { class: 'pjs-input', placeholder: 'n°, nom ou symbole', value: S.query });
    const only = h('label', { class: 'pjs-inline pjv-only' }, h('input', { type: 'checkbox', checked: S.onlyRadiant, onchange: (e) => { S.onlyRadiant = e.target.checked; fill(); } }), 'Radiants seulement');
    search.addEventListener('input', () => { S.query = search.value; fill(); });
    block.appendChild(search);
    block.appendChild(only);
    block.appendChild(list);
    function fill() {
      list.textContent = '';
      const q = S.query.trim().toLowerCase();
      const items = S.ctx.creatures.filter((c) => {
        const has = S.config.radiant.some((e) => e.creature === c.dbSymbol) || c.forms.some((f) => hasRadiantFiles(c, f.form));
        if (S.onlyRadiant && !has) return false;
        if (!q) return true;
        return String(c.id) === q.replace(/^0+/, '') || c.name.toLowerCase().includes(q) || c.dbSymbol.toLowerCase().includes(q);
      });
      items.slice(0, 400).forEach((c) => {
        const entries = S.config.radiant.filter((e) => e.creature === c.dbSymbol).length;
        const files = c.forms.some((f) => hasRadiantFiles(c, f.form));
        const icon = c.forms[0] && c.forms[0].resources.icon;
        const active = S.sel && S.sel.db === c.dbSymbol;
        list.appendChild(h('div', {
          class: 'pjs-item pjv-item' + (active ? ' active' : ''),
          onclick: () => { S.sel = { db: c.dbSymbol, form: (entryForm(c) ?? (c.forms[0] ? c.forms[0].form | 0 : 0)) }; render(); },
        },
        h('span', { class: 'pjv-mini', style: icon ? { backgroundImage: `url("${projectUrl(`${S.ctx.dirs.icon[0]}/${icon}.png`, 'image')}")` } : null }),
        h('span', { class: 'pjs-num pjv-num' }, String(c.id).padStart(3, '0')),
        h('span', { class: 'pjs-name' }, c.name),
        entries ? h('span', { class: 'pjv-tag' }, 'Radiant') : (files ? h('span', { class: 'pjv-tag files', title: 'Images Radiantes sans réglages (faites à la main ?)' }, 'Images') : null)));
      });
      if (items.length > 400) list.appendChild(h('div', { class: 'pjs-hint' }, `${items.length - 400} autres : affine la recherche.`));
      if (!items.length) list.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun Pokémon.'));
    }
    fill();
    requestAnimationFrame(() => { const a = list.querySelector('.active'); if (a) a.scrollIntoView({ block: 'nearest' }); });
    return block;
  }
  // forme déjà radiante de préférence
  const entryForm = (c) => { const e = S.config.radiant.find((x) => x.creature === c.dbSymbol); return e ? e.form : undefined; };

  function renderEditor(block) {
    const creature = S.sel && creatureOf(S.sel.db);
    if (!creature) { block.appendChild(h('div', { class: 'pjs-empty' }, 'Choisis un Pokémon.')); return; }
    const set = spriteSet(creature, S.sel.form);
    const key = `${creature.dbSymbol}/${S.sel.form}`;
    const entry = entryOf(creature.dbSymbol, S.sel.form);

    // en-tête : nom, forme, base, actions
    const head = h('div', { class: 'pjs-block-head' },
      h('h2', null, `${String(creature.id).padStart(3, '0')} ${creature.name}`),
      h('div', { class: 'pjs-inline' },
        creature.forms.length > 1 ? h('select', {
          class: 'pjs-select', onchange: (e) => { S.sel = { db: creature.dbSymbol, form: parseInt(e.target.value, 10) || 0 }; render(); },
        }, creature.forms.map((f) => h('option', { value: f.form, selected: (f.form | 0) === S.sel.form }, `Forme ${f.form}${entryOf(creature.dbSymbol, f.form) ? ' ✦' : ''}`))) : null,
        entry ? h('button', { class: 'pjs-btn danger', onclick: () => removeEntry(creature, entry) }, 'Supprimer le Radiant') : null));
    block.appendChild(head);

    if (!set.length) { block.appendChild(h('div', { class: 'pjs-hint' }, "Cette forme n'a aucun sprite dans Studio.")); return; }

    if (!entry) {
      block.appendChild(h('div', { class: 'pjv-create' },
        h('div', { class: 'pjs-hint inline' }, hasRadiantFiles(creature, S.sel.form)
          ? 'Des images Radiantes existent déjà pour cette forme (faites hors de cet éditeur). En créer un ici les remplacera à l\'enregistrement.'
          : 'Pas encore de Radiant pour cette forme. Il part du sprite normal (ou chromatique) : change la teinte ou chaque couleur de la palette.'),
        h('button', { class: 'pjs-btn primary', onclick: () => createEntry(creature, 'normal') }, 'Créer depuis le normal'),
        h('button', { class: 'pjs-btn secondary', onclick: () => createEntry(creature, 'shiny') }, 'Créer depuis le chromatique')));
    }

    // images (chargées une fois par forme)
    if (!S.loaded || S.loaded.key !== key) {
      const holder = h('div', { class: 'pjs-empty' }, 'Chargement des sprites…');
      block.appendChild(holder);
      const wanted = key;
      loadImages(set.flatMap((i) => [i.normalRel, i.shinyRel])).then((imgs) => {
        if (!S.sel || `${S.sel.db}/${S.sel.form}` !== wanted) return;
        S.loaded = { key: wanted, set, imgs };
        render();
      });
      return;
    }
    const { imgs } = S.loaded;

    // aperçus : Normal | Chromatique | Radiant
    const grid = h('div', { class: 'pjv-preview' });
    grid.appendChild(h('div', { class: 'pjv-col-head' }));
    ['Normal', 'Chromatique', entry ? 'Radiant' : 'Radiant (pas encore)'].forEach((t) => grid.appendChild(h('div', { class: 'pjv-col-head' }, t)));
    const radiantCanvases = [];
    set.forEach((item) => {
      grid.appendChild(h('div', { class: 'pjv-row-head' }, item.label));
      const normal = imgs[item.normalRel];
      const shiny = item.shinyRel ? imgs[item.shinyRel] : null;
      const sameSize = (img) => img && normal && img.width === normal.width && img.height === normal.height;
      const box = normal ? opaqueBox(normal) : null;
      const cellN = h('div', { class: 'pjv-cell' }, normal ? spriteCanvas(normal, 'pick', box) : h('span', { class: 'pjs-hint inline' }, 'absent du projet'));
      const cellS = h('div', { class: 'pjv-cell' }, shiny ? spriteCanvas(shiny, 'pick', sameSize(shiny) ? box : null) : h('span', { class: 'pjs-hint inline' }, '—'));
      const cellR = h('div', { class: 'pjv-cell radiant' });
      const base = baseImage(item, imgs, entry);
      if (entry && base) {
        const c = spriteCanvas(recolor(base, entry), 'pick', sameSize(base) ? box : null);
        radiantCanvases.push({ canvas: c, item });
        cellR.appendChild(c);
      } else if (!entry && hasRadiantFiles(creature, S.sel.form)) {
        cellR.appendChild(h('img', { class: 'pjv-sprite', src: projectUrl(item.radiantRel, 'image'), onload: (e) => { e.target.style.width = e.target.naturalWidth * SCALE + 'px'; } }));
      } else cellR.appendChild(h('span', { class: 'pjs-hint inline' }, '—'));
      // pipette : un clic sur un sprite montre sa couleur dans la palette
      [[cellN, normal], [cellS, shiny], [cellR, base]].forEach(([cell, img]) => {
        const c = cell.querySelector('canvas');
        if (!c || !img || !entry) return;
        c.title = 'Clic : retrouver cette couleur dans la palette';
        c.addEventListener('click', (ev) => {
          const src = cell === cellR ? base : (entry.base === 'shiny' ? (shiny || normal) : normal);
          const b = c._box || { x: 0, y: 0 };
          const x = Math.floor(ev.offsetX / SCALE) + b.x; const y = Math.floor(ev.offsetY / SCALE) + b.y;
          if (!src || x < 0 || y < 0 || x >= src.width || y >= src.height) return;
          const i = (y * src.width + x) * 4;
          if (src.data[i + 3] === 0) return;
          focusSwatch(rgbToHex(src.data[i], src.data[i + 1], src.data[i + 2]));
        });
      });
      grid.append(cellN, cellS, cellR);
    });
    block.appendChild(grid);
    if (!entry) return;

    // base + réglages globaux
    const tools = h('div', { class: 'pjs-section pjv-tools' });
    tools.appendChild(h('div', { class: 'pjs-label' }, 'Base'));
    tools.appendChild(h('div', { class: 'pjs-variants' }, [['normal', 'Sprite normal'], ['shiny', 'Sprite chromatique']].map(([v, label]) => h('button', {
      class: 'pjs-variant' + (entry.base === v ? ' active' : ''),
      onclick: () => { if (entry.base !== v) { entry.base = v; entry.colors = {}; render(); } },
      title: 'Changer de base remet la palette à zéro',
    }, label))));
    const sliders = [['hue', 'Teinte', -180, 180, '°'], ['saturation', 'Saturation', -100, 100, ''], ['lightness', 'Luminosité', -50, 50, '']];
    const sliderRefs = {};
    sliders.forEach(([k, label, min, max, unit]) => {
      const out = h('span', { class: 'pjv-val' }, `${entry[k] || 0}${unit}`);
      const input = h('input', { type: 'range', class: 'pjv-range', min, max, step: 1, value: entry[k] || 0 });
      input.addEventListener('input', () => { entry[k] = parseInt(input.value, 10) || 0; out.textContent = `${entry[k]}${unit}`; updatePreview(); });
      input.addEventListener('dblclick', () => { input.value = 0; input.dispatchEvent(new Event('input')); });
      sliderRefs[k] = input;
      tools.appendChild(h('div', { class: 'pjv-slider' }, h('span', { class: 'pjs-label' }, label), input, out));
    });
    tools.appendChild(h('div', { class: 'pjs-hint inline' }, 'Les réglages s\'appliquent aux couleurs que tu n\'as pas choisies à la main. Double-clic sur un curseur : 0.'));
    block.appendChild(tools);

    // palette
    const pal = palette(set, imgs, entry);
    const swatches = new Map();
    const palSection = h('div', { class: 'pjs-section last' },
      h('div', { class: 'pjv-pal-head' },
        h('span', { class: 'pjs-label' }, `Palette (${pal.length} couleurs)`),
        h('button', { class: 'pjs-btn small', onclick: () => { entry.colors = {}; render(); }, title: 'Oublie les couleurs choisies à la main' }, 'Réinitialiser les couleurs'),
        h('button', { class: 'pjs-btn small', onclick: () => { entry.colors = {}; entry.hue = 0; entry.saturation = 0; entry.lightness = 0; render(); } }, 'Tout remettre à zéro')));
    const palGrid = h('div', { class: 'pjv-palette' });
    pal.forEach(({ hex, count }) => {
      const input = h('input', { type: 'color', class: 'pjv-color', value: rgbToHex(...radiantColor(hex, entry)) });
      const reset = h('button', { class: 'pjv-reset', title: 'Revenir à la couleur calculée', onclick: () => { delete entry.colors[hex]; updatePreview(); } }, '×');
      const sw = h('div', { class: 'pjv-swatch' + (entry.colors[hex] ? ' set' : ''), title: `${hex} — ${count} pixels` },
        h('span', { class: 'pjv-orig', style: { backgroundColor: hex } }), h('span', { class: 'pjv-arrow' }, '→'), input, reset);
      input.addEventListener('input', () => { entry.colors[hex] = input.value; sw.classList.add('set'); updatePreview(true); });
      swatches.set(hex, { sw, input });
      palGrid.appendChild(sw);
    });
    palSection.appendChild(palGrid);
    palSection.appendChild(h('div', { class: 'pjs-hint' }, 'Clique sur un sprite pour retrouver une couleur. À l\'enregistrement, les sprites Radiants (face, dos, icône) sont écrits dans graphics/pokedex/poke…radiant/.'));
    block.appendChild(palSection);
    refs = { entry, radiantCanvases, swatches, imgs };
  }

  // Met à jour les aperçus Radiants et la palette sans tout redessiner
  function updatePreview(keepInputs) {
    if (!refs) return;
    const { entry, radiantCanvases, swatches, imgs } = refs;
    radiantCanvases.forEach(({ canvas, item }) => { const base = baseImage(item, imgs, entry); if (base) drawInto(canvas, recolor(base, entry)); });
    swatches.forEach(({ sw, input }, hex) => {
      sw.classList.toggle('set', !!entry.colors[hex]);
      if (!keepInputs || !entry.colors[hex]) input.value = rgbToHex(...radiantColor(hex, entry));
    });
    updateStatus();
  }

  function focusSwatch(hex) {
    if (!refs) return;
    const s = refs.swatches.get(hex);
    if (!s) { toast(`${hex} : couleur peu présente, pas dans la palette affichée`); return; }
    s.sw.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    s.sw.classList.remove('flash'); void s.sw.offsetWidth; s.sw.classList.add('flash');
  }

  function createEntry(creature, base) {
    // un Radiant supprimé puis refait : ses images ne sont plus à supprimer
    const form = S.sel.form;
    const files = spriteSet(creature, form).map((i) => i.kind + '/' + i.filename);
    S.removals = S.removals.filter((r) => !files.includes(r.kind + '/' + r.filename));
    S.config.radiant.push({ creature: creature.dbSymbol, form, base, hue: 150, saturation: 0, lightness: 0, colors: {} });
    render();
  }

  function removeEntry(creature, entry) {
    if (!confirm(`Supprimer le Radiant de ${creature.name} (forme ${entry.form}) ? Ses images seront effacées à l'enregistrement.`)) return;
    S.config.radiant = S.config.radiant.filter((e) => e !== entry);
    spriteSet(creature, entry.form).forEach((i) => {
      if (S.ctx.radiant[i.kind].includes(i.filename)) S.removals.push({ kind: i.kind, filename: i.filename });
    });
    render();
  }

  // --- Onglet Réglages --------------------------------------------------------
  function renderSettings(content) {
    const row = h('div', { class: 'pjs-row' });
    content.appendChild(row);
    const rates = h('div', { class: 'pjs-block pjs-block-half' });
    rates.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, "Taux d'apparition")));
    [['radiant_rate', 'Radiant'], ['gold_rate', 'Doré'], ['silver_rate', 'Argenté']].forEach(([k, label]) => {
      const input = h('input', { class: 'pjs-input num', type: 'number', min: 0, step: 1, value: S.config[k] });
      const info = h('span', { class: 'pjs-hint inline' });
      const show = () => { const n = S.config[k]; info.textContent = n > 0 ? `≈ ${(100 / n).toFixed(n > 1000 ? 3 : 2)} %` : 'jamais'; };
      input.addEventListener('input', () => { S.config[k] = Math.max(0, parseInt(input.value, 10) || 0); show(); updateStatus(); });
      show();
      rates.appendChild(h('div', { class: 'pjs-section row' + (k === 'radiant_rate' ? ' first' : '') },
        h('span', { class: 'pjs-label' }, label), h('span', { class: 'pjs-inline' }, '1 chance sur', input, info)));
    });
    rates.appendChild(h('div', { class: 'pjs-section row last' },
      h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: S.config.count_as_shiny !== false, onchange: (e) => { S.config.count_as_shiny = e.target.checked; updateStatus(); } }),
        'Une variante compte aussi comme chromatique (étoile, scintillement en combat)')));
    rates.appendChild(h('div', { class: 'pjs-hint' }, 'Tirage à chaque nouveau Pokémon (sauvage, œuf, don…), Radiant d\'abord, puis Doré, puis Argenté. 0 = jamais. Un Pokémon sans sprite Radiant ne peut pas être Radiant. Commandes : add_pokemon_variant(:pikachu, 10, :gold), set_pokemon_variant(0, :silver).'));
    row.appendChild(rates);

    // dégradés
    const sample = sampleImage();
    [['silver_colors', 'Argenté'], ['gold_colors', 'Doré']].forEach(([k, label]) => {
      const block = h('div', { class: 'pjs-block pjs-block-half' });
      block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, label),
        h('button', { class: 'pjs-btn small', onclick: () => { S.config[k] = DEFAULTS[k].slice(); render(); } }, 'Couleurs de base')));
      const previews = h('div', { class: 'pjv-tints' });
      const bar = h('div', { class: 'pjv-gradient' });
      const draw = () => {
        bar.style.background = `linear-gradient(90deg, ${S.config[k].join(', ')})`;
        previews.textContent = '';
        sample.then((imgs) => imgs.forEach((img) => { if (img) previews.appendChild(spriteCanvas(tint(img, S.config[k]))); }));
      };
      const stops = h('div', { class: 'pjv-stops' }, S.config[k].map((c, i) => {
        const input = h('input', { type: 'color', class: 'pjv-color', value: c });
        input.addEventListener('input', () => { S.config[k][i] = input.value; bar.style.background = `linear-gradient(90deg, ${S.config[k].join(', ')})`; updateStatus(); });
        input.addEventListener('change', draw);
        return h('div', { class: 'pjv-stop' }, input, h('span', { class: 'pjs-hint inline' }, ['Ombres', 'Sombre', 'Clair', 'Reflets'][i] || ''));
      }));
      block.appendChild(previews);
      block.appendChild(bar);
      block.appendChild(stops);
      block.appendChild(h('div', { class: 'pjs-hint' }, `Le jeu recolore chaque sprite selon sa luminosité : les zones sombres prennent la 1re couleur, les plus claires la dernière. Aperçu sur ${S.sel && creatureOf(S.sel.db) ? creatureOf(S.sel.db).name : 'le Pokémon choisi'} (choisis-en un autre dans l'onglet Radiant).`));
      draw();
      row.appendChild(block);
    });
  }

  // sprites de face et de dos du Pokémon choisi (pour l'aperçu Argenté / Doré)
  function sampleImage() {
    const c = S.sel && creatureOf(S.sel.db);
    if (!c) return Promise.resolve([]);
    const set = spriteSet(c, S.sel.form).filter((i) => i.kind !== 'icon').slice(0, 2);
    return loadImages(set.map((i) => i.normalRel)).then((imgs) => set.map((i) => imgs[i.normalRel]));
  }

  // ---------------------------------------------------------------------------
  // Page « Variantes » : à droite du menu de la base de données, comme Smartphone
  // ---------------------------------------------------------------------------
  let host = null;
  let hidden = [];
  let pendingOpen = false;
  const findMenu = () => {
    const quests = document.querySelector('a[href$="/database/quests"]');
    return quests && quests.parentElement && quests.parentElement.parentElement;
  };
  const entryEl = () => document.querySelector('[data-pjv-entry]');

  function open() {
    const menu = findMenu();
    if (!menu || !menu.parentElement) {
      const link = document.querySelector('a[href$="/database/pokemon"], a[href*="/database"]');
      if (link) { pendingOpen = true; link.click(); } else toast('Ouvre un projet pour accéder aux variantes', true);
      return;
    }
    if (S.open && root && document.body.contains(root)) return;
    if (window.pjSmartphoneEditor && window.pjSmartphoneEditor.state && window.pjSmartphoneEditor.state.open) window.pjSmartphoneEditor.close();
    host = menu.parentElement;
    hidden = [...host.children].filter((el) => el !== menu && el.id !== 'pjv-root');
    hidden.forEach((el) => { el.dataset.pjvDisplay = el.style.display || ''; el.style.display = 'none'; });
    root = h('div', { id: 'pjv-root' });
    host.appendChild(root);
    S.open = true;
    menu.setAttribute('data-pjv-open', '1');
    const entry = entryEl(); if (entry) entry.classList.add('pjv-active');
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.config || (latest && latest !== S.projectPath && !dirty())) loadProject(latest || null); else render();
  }

  function close() {
    if (root) root.remove();
    root = null; refs = null;
    hidden.forEach((el) => { el.style.display = el.dataset.pjvDisplay || ''; delete el.dataset.pjvDisplay; });
    hidden = [];
    S.open = false;
    const menu = findMenu(); if (menu) menu.removeAttribute('data-pjv-open');
    const entry = entryEl(); if (entry) entry.classList.remove('pjv-active');
  }

  // Entrée « Variantes » dans la section « Plugins » (créée par l'éditeur Smartphone)
  function updateLauncher() {
    if (S.open && root && !document.body.contains(root)) { root = null; hidden = []; S.open = false; }
    const quests = document.querySelector('a[href$="/database/quests"]');
    const section = quests && quests.parentElement;
    const menu = section && section.parentElement;
    if (!menu) return;
    let plugins = menu.querySelector('[data-pjs="plugins"]');
    if (!plugins) {
      if (window.__pjSmartphoneLoaded) return; // l'éditeur Smartphone va créer la section
      const title = section.querySelector('span.title');
      plugins = section.cloneNode(false);
      plugins.setAttribute('data-pjs', 'plugins');
      const head = title ? title.cloneNode(false) : document.createElement('span');
      head.className = title ? title.className : 'title';
      head.textContent = 'Plugins';
      plugins.appendChild(head);
      menu.appendChild(plugins);
    }
    if (!plugins.querySelector('[data-pjv-entry]')) {
      const entry = quests.cloneNode(true);
      entry.removeAttribute('href');
      entry.removeAttribute('aria-current');
      entry.classList.remove('active');
      entry.removeAttribute('data-active-forced');
      entry.removeAttribute('data-pjs-entry');
      entry.setAttribute('role', 'button');
      entry.setAttribute('data-pjv-entry', '1');
      entry.title = 'Pokémon Argentés, Dorés et Radiants (Ctrl+Maj+V)';
      const label = entry.firstElementChild || entry;
      label.textContent = 'Variantes';
      entry.addEventListener('click', (e) => { e.preventDefault(); e.stopPropagation(); open(); });
      plugins.appendChild(entry);
      // l'entrée Smartphone ou un lien du menu referme la page
      menu.addEventListener('click', (e) => {
        if (!S.open) return;
        const target = e.target.closest('a[href], [data-pjs-entry]');
        if (!target) return;
        if (dirty() && !confirm('Variantes : des modifications ne sont pas enregistrées. Quitter quand même ? (elles restent gardées)')) { e.preventDefault(); e.stopPropagation(); return; }
        close();
      }, true);
    }
    if (S.open) { const entry = entryEl(); if (entry) entry.classList.add('pjv-active'); menu.setAttribute('data-pjv-open', '1'); }
    if (pendingOpen) { pendingOpen = false; open(); }
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; updateLauncher(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); updateLauncher(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('keydown', (e) => {
    const k = e.key.toLowerCase();
    const typing = e.target && ['INPUT', 'TEXTAREA'].includes(e.target.tagName);
    if (e.ctrlKey && e.shiftKey && k === 'v' && !typing) { e.preventDefault(); open(); return; }
    if (!S.open) return;
    if (e.ctrlKey && k === 's') { e.preventDefault(); e.stopPropagation(); save(); }
  }, true);

  setInterval(() => { if (S.open) updateStatus(); }, 1000);

  window.pjVariantesEditor = { open, close, state: S };
})();

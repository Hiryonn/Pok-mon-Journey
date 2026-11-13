/* eslint-disable */
// =============================================================================
// Variantes — éditeur des Pokémon Cuivrés, Argentés, Dorés, Prismatiques et Radiants (plugin « variantes ») pour Pokémon Studio
// Ouvert par « Plugins > Variantes » dans le menu de la base de données (ou Ctrl+Maj+V).
//   Onglet « Radiant »  : recolore les sprites existants (palette, teinte, saturation, luminosité)
//                         et enregistre graphics/pokedex/poke*radiant/<sprite normal>.png
//   Onglet « Réglages » : taux d'apparition, dégradés Cuivré / Argenté / Doré (recoloration faite en jeu)
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
    copper_rate: 4096,
    silver_rate: 8192,
    gold_rate: 8192,
    prismatic_rate: 16384,
    radiant_rate: 4096,
    shiny_rate: 4096,
    count_as_shiny: true,
    copper_colors: ['#2e1206', '#8a3f1c', '#c8743e', '#f6c9a0'],
    silver_colors: ['#22242f', '#6a7082', '#b7bdcc', '#f6f8ff'],
    gold_colors: ['#3c2204', '#a2680e', '#e6b232', '#fff4a6'],
    radiant: [],
    shiny: [],
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
    kind: 'shiny',     // shiny | radiant (page Shiny / Radiant)
    page: null,        // shiny | metals
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
  const entryKey = (e, kind = S.kind) => `${kind}:${e.creature}/${e.form | 0}`;
  // Radiant : graphics/pokedex/poke…radiant/<sprite normal>.png ; Chromatique : poke…shiny/<sprite chromatique de Studio> (ou <normal>s)
  const KINDINFO = {
    radiant: { label: 'Radiant', plural: 'Radiants', the: 'le Radiant', a: 'un Radiant', dirIndex: 2 },
    shiny: { label: 'Chromatique', plural: 'Chromatiques', the: 'le Chromatique', a: 'un Chromatique', dirIndex: 1 },
  };
  const KI = () => KINDINFO[S.kind];

  // ---------------------------------------------------------------------------
  // Données
  // ---------------------------------------------------------------------------
  const creatureOf = (db) => S.ctx && S.ctx.creatures.find((c) => c.dbSymbol === db);
  const formOf = (creature, form) => creature && (creature.forms.find((f) => (f.form | 0) === (form | 0)) || creature.forms[0]);
  const entryOf = (db, form, kind = S.kind) => S.config[kind].find((e) => e.creature === db && (e.form | 0) === (form | 0));

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
        out: {
          radiant: { filename: name, rel: `${dirs[k.dir][2]}/${name}.png` },
          shiny: { filename: shiny || name + 's', rel: `${dirs[k.dir][1]}/${shiny || name + 's'}.png` },
        },
      });
    });
    return out;
  }

  // La variante (Radiant ou Chromatique) a-t-elle déjà des images ?
  const hasFiles = (creature, form, kind = S.kind) => {
    const fm = formOf(creature, form);
    const res = (fm && fm.resources) || {};
    const name = kind === 'shiny' ? (res.frontShiny || (res.front ? res.front + 's' : '')) : res.front;
    return !!(name && S.ctx.files[kind].front.includes(name));
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
  // Réglages utilisés pour un sprite : l'icône a les siens quand « Couleurs propres à l'icône » est coché
  // (entry.icon = { hue, saturation, lightness, colors }), sinon elle suit Face et dos
  const settingsFor = (item, entry) => (item.kind === 'icon' && entry && entry.icon ? entry.icon : entry);

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

  // Prismatique (la même qu'en jeu) : arc-en-ciel en diagonale, halo et éclats de cristal
  function prismHsl(h, s, l) {
    if (s <= 0) return [0, 0, 0].map(() => Math.round(l * 255));
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    return [h + 1 / 3, h, h - 1 / 3].map((t) => {
      if (t < 0) t += 1; if (t > 1) t -= 1;
      const v = t < 1 / 6 ? p + (q - p) * 6 * t : t < 0.5 ? q : t < 2 / 3 ? p + (q - p) * (2 / 3 - t) * 6 : p;
      return clamp(Math.round(v * 255), 0, 255);
    });
  }
  function prism(data, key) {
    const out = new ImageData(new Uint8ClampedArray(data.data), data.width, data.height);
    const d = out.data; const W = data.width; const H = data.height;
    const src = data.data;
    const lum = (i) => src[i] * 0.299 + src[i + 1] * 0.587 + src[i + 2] * 0.114;
    const opaque = (x, y) => src[(y * W + x) * 4 + 3] > 0;
    const pts = [];
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (opaque(x, y)) pts.push([x, y]);
    if (!pts.length) return out;
    const x0 = Math.min(...pts.map((q) => q[0])); const y0 = Math.min(...pts.map((q) => q[1]));
    const bw = Math.max(Math.max(...pts.map((q) => q[0])) - x0, 1); const bh = Math.max(Math.max(...pts.map((q) => q[1])) - y0, 1);
    const lums = pts.map(([x, y]) => lum((y * W + x) * 4)).sort((a, b) => a - b);
    const low = lums[Math.floor(lums.length * 0.02)];
    let high = lums[Math.min(Math.ceil(lums.length * 0.98), lums.length - 1)];
    if (high <= low) high = low + 1;
    const hues = new Float32Array(W * H);
    pts.forEach(([x, y]) => {
      const i = (y * W + x) * 4; const l = lum(i);
      const t = clamp((l - low) / (high - low), 0, 1);
      const hue = (((x - x0) / bw * 0.55 + (y - y0) / bh * 0.45) * 1.6 + t * 0.1 + 0.92) % 1;
      hues[y * W + x] = hue;
      if (l < 40) return;
      const [r, g, b] = prismHsl(hue, 1 - 0.2 * t, 0.36 + 0.5 * t);
      d[i] = r; d[i + 1] = g; d[i + 2] = b;
    });
    const icon = H <= 32; const rad = icon ? 1 : 2;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (opaque(x, y)) continue;
      let best = null;
      for (let dy = -rad; dy <= rad; dy++) for (let dx = -rad; dx <= rad; dx++) {
        const xx = x + dx; const yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= W || yy >= H || !opaque(xx, yy)) continue;
        const dist = Math.max(Math.abs(dx), Math.abs(dy));
        if (!best || dist < best[0]) best = [dist, hues[yy * W + xx]];
      }
      if (!best) continue;
      const i = (y * W + x) * 4; const [r, g, b] = prismHsl(best[1], 1, 0.82);
      d[i] = r; d[i + 1] = g; d[i + 2] = b; d[i + 3] = best[0] === 1 ? 150 : 60;
    }
    if (!icon && W >= 16 && H >= 16) {
      let seed = [...String(key || '')].reduce((a, c) => (a * 31 + c.charCodeAt(0)) % 2147483647, 7) || 1;
      const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
      const near = (x, y, a, b, c, e) => { for (let xx = clamp(x + a, 0, W - 1); xx <= clamp(x + b, 0, W - 1); xx++) for (let yy = clamp(y + c, 0, H - 1); yy <= clamp(y + e, 0, H - 1); yy++) if (opaque(xx, yy)) return true; return false; };
      const SHARD = [[1, 0], [0, 1], [1, 1], [2, 1], [0, 2], [1, 2], [2, 2], [0, 3], [1, 3], [2, 3], [1, 4]];
      let count = 0;
      for (let k = 0; k < 400 && count < 4; k++) {
        const x = 2 + Math.floor(rnd() * (W - 6)); const y = 2 + Math.floor(rnd() * (H - 8));
        if (!near(x, y, -6, 8, -6, 10) || near(x, y, -3, 5, -3, 7)) continue;
        if (SHARD.some(([dx, dy]) => d[((y + dy) * W + x + dx) * 4 + 3] > 0)) continue;
        const start = rnd();
        SHARD.forEach(([dx, dy]) => { const i = ((y + dy) * W + x + dx) * 4; const [r, g, b] = prismHsl((start + dy * 0.08) % 1, 1, dx === 0 ? 0.9 : 0.7); d[i] = r; d[i + 1] = g; d[i + 2] = b; d[i + 3] = 220; });
        count++;
      }
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
      ['radiant', 'shiny'].forEach((kind) => {
        if (!Array.isArray(cfg[kind])) cfg[kind] = [];
        cfg[kind].forEach((e) => { e.form = e.form | 0; e.colors = e.colors || {}; e.base = kind === 'radiant' && e.base === 'shiny' ? 'shiny' : 'normal'; });
      });
      if (!S.ctx.files) S.ctx.files = { radiant: S.ctx.radiant, shiny: { front: [], back: [], icon: [] } };
      S.config = cfg;
      S.savedEntries = savedMap();
      S.saved = S.ctx.config ? snapshot() : null;
      if (!S.sel || !creatureOf(S.sel.db)) {
        const first = S.ctx.creatures.find((c) => c.id > 0) || S.ctx.creatures[0];
        S.sel = first ? { db: first.dbSymbol, form: first.forms[0] ? first.forms[0].form | 0 : 0 } : null;
      }
    } catch (e) { S.error = e.message; }
    render();
  }

  const savedMap = () => Object.fromEntries(['radiant', 'shiny'].flatMap((kind) => S.config[kind].map((e) => [entryKey(e, kind), JSON.stringify(e)])));
  // Images d'un Radiant (ou d'un Chromatique) à écrire
  async function radiantImages(entry, kind = S.kind) {
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
      c.getContext('2d').putImageData(recolor(base, settingsFor(item, entry)), 0, 0);
      out.push({ kind: item.kind, filename: item.out[kind].filename, target: kind, dataUrl: c.toDataURL('image/png') });
    });
    return out;
  }

  async function save() {
    if (!S.config) return;
    try {
      const write = [];
      for (const kind of ['radiant', 'shiny']) {
        for (const entry of S.config[kind]) {
          if (S.savedEntries[entryKey(entry, kind)] === JSON.stringify(entry) && hasFiles(creatureOf(entry.creature), entry.form, kind)) continue;
          write.push(...(await radiantImages(entry, kind)));
        }
      }
      const r = await call('save', { projectPath: S.projectPath, config: S.config, write, remove: S.removals });
      // fichiers Radiants connus
      // fichiers connus (un Chromatique supprimé retrouve l'image d'origine si elle existait)
      (r.removed || []).forEach(({ kind, filename, target, restored }) => { const l = S.ctx.files[target || 'radiant'][kind]; if (!restored) S.ctx.files[target || 'radiant'][kind] = l.filter((n) => n !== filename); });
      write.forEach(({ kind, filename, target }) => { const l = S.ctx.files[target][kind]; if (!l.includes(filename)) l.push(filename); });
      S.removals = [];
      S.savedEntries = savedMap();
      S.saved = snapshot();
      const p = r.plugin || {};
      if (p.source) S.ctx.plugin = { source: true, installed: p.installed, outdated: p.installed ? [] : ['?'], stale: [] };
      toast(`Enregistré${write.length ? ` : ${write.length} image${write.length > 1 ? 's' : ''}` : ''}`
        + (p.source && !p.installed ? ' — plugin pas encore installé : lance construire_plugin_variantes.bat une fois' : ''));
      render();
      if (p.source) rebuildPlugin();
    } catch (e) { toast('Erreur de sauvegarde : ' + e.message, true); }
  }

  // Radiant au hasard (teinte, saturation, luminosité) pour chaque forme qui n'en a pas, enregistré au fur et à mesure
  async function randomizeAll() {
    if (S.progress) return;
    const kind = S.kind; const K = KINDINFO[kind];
    const todo = [];
    S.ctx.creatures.forEach((c) => c.forms.forEach((f) => {
      const form = f.form | 0;
      if (entryOf(c.dbSymbol, form, kind) || hasFiles(c, form, kind) || !spriteSet(c, form).length) return;
      todo.push({ c, form });
    }));
    if (!todo.length) { toast(`Tous les Pokémon ont déjà ${K.a}`); return; }
    if (!confirm(`Créer ${K.a} au hasard pour ${todo.length} forme${todo.length > 1 ? 's' : ''} de Pokémon qui n'en ont pas ?\n`
      + 'Teinte, saturation et luminosité tirées au hasard (à partir du sprite normal). Les images sont écrites tout de suite ; '
      + `tu pourras retoucher ou supprimer chacun ensuite. Les ${K.plural} existants ne sont pas touchés.`)) return;
    const rnd = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
    let done = 0; let images = 0;
    try {
      for (let i = 0; i < todo.length; i += 20) {
        const write = []; const made = [];
        for (const { c, form } of todo.slice(i, i + 20)) {
          const entry = { creature: c.dbSymbol, form, base: 'normal', hue: rnd(40, 180) * (Math.random() < 0.5 ? -1 : 1), saturation: rnd(-10, 25), lightness: rnd(-6, 6), colors: {} };
          S.config[kind].push(entry); made.push(entry);
          write.push(...(await radiantImages(entry, kind)));
        }
        await call('save', { projectPath: S.projectPath, config: S.config, write, remove: [] });
        write.forEach((w) => { const l = S.ctx.files[w.target][w.kind]; if (!l.includes(w.filename)) l.push(w.filename); });
        made.forEach((e) => { S.savedEntries[entryKey(e, kind)] = JSON.stringify(e); });
        done += made.length; images += write.length;
        // libère les sprites déjà traités (sauf ceux du Pokémon affiché)
        const keep = new Set(S.loaded ? S.loaded.set.flatMap((it) => [it.normalRel, it.shinyRel]) : []);
        [...S.images.keys()].forEach((k) => { if (!keep.has(k)) S.images.delete(k); });
        S.progress = `${K.plural} au hasard : ${done} / ${todo.length}…`; updateStatus();
      }
    } catch (e) { toast(`${K.plural} au hasard : erreur (` + e.message + ')', true); }
    S.progress = null;
    toast(`${done} ${K.label}${done > 1 ? 's' : ''} créé${done > 1 ? 's' : ''} au hasard (${images} images)`);
    await save();
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
    if (S.progress) return [S.progress, ' dirty'];
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
        h('span', { class: 'pjs-top-title' }, S.page === 'metals' ? 'Métaux' : 'Shiny / Radiant'),
        S.page === 'metals' ? null : h('div', { class: 'pjs-tabs' },
          [['shiny', 'Chromatique (shiny)'], ['radiant', 'Radiant']].map(([kind, label]) => h('button', {
            class: 'pjs-tab' + (S.kind === kind ? ' active' : ''), onclick: () => { S.kind = kind; render(); },
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
    if (S.page === 'metals') renderSettings(content); else renderRadiant(content);
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
    const count = S.config[S.kind].length;
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Pokémon'), h('span', { class: 'pjs-count', title: `Pokémon avec ${KI().a} fait ici` }, String(count))));
    block.appendChild(h('button', { class: 'pjs-btn small secondary pjv-random', onclick: randomizeAll, title: `Teinte, saturation et luminosité au hasard pour chaque forme sans ${KI().label} (les ${KI().plural} existants ne sont pas touchés)` }, `${KI().label} au hasard`));
    const list = h('div', { class: 'pjv-list' });
    const search = h('input', { class: 'pjs-input', placeholder: 'n°, nom ou symbole', value: S.query });
    const only = h('label', { class: 'pjs-inline pjv-only' }, h('input', { type: 'checkbox', checked: S.onlyRadiant, onchange: (e) => { S.onlyRadiant = e.target.checked; fill(); } }), `${KI().plural} seulement`);
    search.addEventListener('input', () => { S.query = search.value; fill(); });
    block.appendChild(search);
    block.appendChild(only);
    block.appendChild(list);
    function fill() {
      list.textContent = '';
      const q = S.query.trim().toLowerCase();
      const items = S.ctx.creatures.filter((c) => {
        const has = S.config[S.kind].some((e) => e.creature === c.dbSymbol) || c.forms.some((f) => hasFiles(c, f.form));
        if (S.onlyRadiant && !has) return false;
        if (!q) return true;
        return String(c.id) === q.replace(/^0+/, '') || String(c.name || '').toLowerCase().includes(q) || String(c.dbSymbol || '').toLowerCase().includes(q);
      });
      items.slice(0, 400).forEach((c) => {
        const entries = S.config[S.kind].filter((e) => e.creature === c.dbSymbol).length;
        const files = c.forms.some((f) => hasFiles(c, f.form));
        const icon = c.forms[0] && c.forms[0].resources.icon;
        const active = S.sel && S.sel.db === c.dbSymbol;
        list.appendChild(h('div', {
          class: 'pjs-item pjv-item' + (active ? ' active' : ''),
          onclick: () => { S.sel = { db: c.dbSymbol, form: (entryForm(c) ?? (c.forms[0] ? c.forms[0].form | 0 : 0)) }; render(); },
        },
        h('span', { class: 'pjv-mini', style: icon ? { backgroundImage: `url("${projectUrl(`${S.ctx.dirs.icon[0]}/${icon}.png`, 'image')}")` } : null }),
        h('span', { class: 'pjs-num pjv-num' }, String(c.id).padStart(3, '0')),
        h('span', { class: 'pjs-name' }, c.name),
        entries ? h('span', { class: 'pjv-tag' }, S.kind === 'shiny' ? 'Refait' : 'Radiant') : (files && S.kind === 'radiant' ? h('span', { class: 'pjv-tag files', title: 'Images Radiantes sans réglages (faites à la main ?)' }, 'Images') : (!files && S.kind === 'shiny' ? h('span', { class: 'pjv-tag files', title: 'Pas de sprite chromatique dans le projet' }, 'Aucun') : null))));
      });
      if (items.length > 400) list.appendChild(h('div', { class: 'pjs-hint' }, `${items.length - 400} autres : affine la recherche.`));
      if (!items.length) list.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun Pokémon.'));
    }
    fill();
    requestAnimationFrame(() => { const a = list.querySelector('.active'); if (a) a.scrollIntoView({ block: 'nearest' }); });
    return block;
  }
  // forme déjà radiante de préférence
  const entryForm = (c) => { const e = S.config[S.kind].find((x) => x.creature === c.dbSymbol); return e ? e.form : undefined; };

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
        entry ? h('button', { class: 'pjs-btn danger', onclick: () => removeEntry(creature, entry) }, S.kind === 'shiny' ? 'Annuler ce Chromatique' : 'Supprimer le Radiant') : null));
    block.appendChild(head);

    if (!set.length) { block.appendChild(h('div', { class: 'pjs-hint' }, "Cette forme n'a aucun sprite dans Studio.")); return; }

    if (!entry) {
      block.appendChild(h('div', { class: 'pjv-create' },
        h('div', { class: 'pjs-hint inline' }, S.kind === 'shiny'
          ? (hasFiles(creature, S.sel.form)
            ? 'Ce Pokémon a déjà un sprite chromatique. En refaire un ici le remplace à l\'enregistrement (l\'original est gardé de côté : « Annuler ce Chromatique » le remet).'
            : 'Pas de sprite chromatique pour cette forme. Il part du sprite normal : change la teinte ou chaque couleur de la palette, comme pour un Radiant.')
          : (hasFiles(creature, S.sel.form)
            ? 'Des images Radiantes existent déjà pour cette forme (faites hors de cet éditeur). En créer un ici les remplacera à l\'enregistrement.'
            : 'Pas encore de Radiant pour cette forme. Il part du sprite normal (ou chromatique) : change la teinte ou chaque couleur de la palette.')),
        h('button', { class: 'pjs-btn primary', onclick: () => createEntry(creature, 'normal') }, S.kind === 'shiny' ? (hasFiles(creature, S.sel.form) ? 'Refaire le chromatique' : 'Créer le chromatique') : 'Créer depuis le normal'),
        S.kind === 'radiant' ? h('button', { class: 'pjs-btn secondary', onclick: () => createEntry(creature, 'shiny') }, 'Créer depuis le chromatique') : null));
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
    (S.kind === 'shiny' ? ['Normal', 'Chromatique actuel', entry ? 'Nouveau chromatique' : 'Nouveau chromatique (pas encore)'] : ['Normal', 'Chromatique', entry ? 'Radiant' : 'Radiant (pas encore)']).forEach((t) => grid.appendChild(h('div', { class: 'pjv-col-head' }, t)));
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
        const c = spriteCanvas(recolor(base, settingsFor(item, entry)), 'pick', sameSize(base) ? box : null);
        radiantCanvases.push({ canvas: c, item });
        cellR.appendChild(c);
      } else if (!entry && hasFiles(creature, S.sel.form) && S.kind === 'radiant') {
        cellR.appendChild(h('img', { class: 'pjv-sprite', src: projectUrl(item.out[S.kind].rel, 'image'), onload: (e) => { e.target.style.width = e.target.naturalWidth * SCALE + 'px'; } }));
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
    if (S.kind === 'radiant') tools.appendChild(h('div', { class: 'pjs-label' }, 'Base'));
    if (S.kind === 'radiant') tools.appendChild(h('div', { class: 'pjs-variants' }, [['normal', 'Sprite normal'], ['shiny', 'Sprite chromatique']].map(([v, label]) => h('button', {
      class: 'pjs-variant' + (entry.base === v ? ' active' : ''),
      onclick: () => { if (entry.base !== v) { entry.base = v; entry.colors = {}; if (entry.icon) entry.icon.colors = {}; render(); } },
      title: 'Changer de base remet la palette à zéro',
    }, label))));
    // réglages de Face et dos, ou de l'icône (qui a parfois d'autres dégradés)
    const hasIcon = set.some((i) => i.kind === 'icon');
    if (!hasIcon) S.radiantScope = 'main';
    const scope = S.radiantScope === 'icon' ? 'icon' : 'main';
    if (hasIcon) {
      tools.appendChild(h('div', { class: 'pjs-label' }, 'Réglages pour'));
      tools.appendChild(h('div', { class: 'pjs-variants' }, [['main', 'Face et dos'], ['icon', entry.icon ? 'Icône ✦' : 'Icône']].map(([v, label]) => h('button', {
        class: 'pjs-variant' + (scope === v ? ' active' : ''), onclick: () => { S.radiantScope = v; render(); },
      }, label))));
    }
    if (scope === 'icon') {
      tools.appendChild(h('label', { class: 'pjs-inline pjv-own-icon' }, h('input', {
        type: 'checkbox', checked: !!entry.icon,
        onchange: (e) => {
          if (e.target.checked) entry.icon = { hue: entry.hue || 0, saturation: entry.saturation || 0, lightness: entry.lightness || 0, colors: { ...(entry.colors || {}) } };
          else delete entry.icon;
          render();
        },
      }), 'Couleurs propres à l\'icône'));
      if (!entry.icon) {
        tools.appendChild(h('div', { class: 'pjs-hint inline' }, 'L\'icône suit les réglages de Face et dos. Coche la case pour lui donner sa propre teinte et sa propre palette (elle part des réglages actuels).'));
        block.appendChild(tools);
        refs = { entry, target: entry, radiantCanvases, swatches: new Map(), imgs };
        return;
      }
    }
    const target = scope === 'icon' ? entry.icon : entry;
    if (!target.colors) target.colors = {};
    const sliders = [['hue', 'Teinte', -180, 180, '°'], ['saturation', 'Saturation', -100, 100, ''], ['lightness', 'Luminosité', -50, 50, '']];
    const sliderRefs = {};
    sliders.forEach(([k, label, min, max, unit]) => {
      const out = h('span', { class: 'pjv-val' }, `${target[k] || 0}${unit}`);
      const input = h('input', { type: 'range', class: 'pjv-range', min, max, step: 1, value: target[k] || 0 });
      input.addEventListener('input', () => { target[k] = parseInt(input.value, 10) || 0; out.textContent = `${target[k]}${unit}`; updatePreview(); });
      input.addEventListener('dblclick', () => { input.value = 0; input.dispatchEvent(new Event('input')); });
      sliderRefs[k] = input;
      tools.appendChild(h('div', { class: 'pjv-slider' }, h('span', { class: 'pjs-label' }, label), input, out));
    });
    tools.appendChild(h('div', { class: 'pjs-hint inline' }, 'Les réglages s\'appliquent aux couleurs que tu n\'as pas choisies à la main. Double-clic sur un curseur : 0.'));
    block.appendChild(tools);

    // palette
    const palSet = set.filter((i) => (scope === 'icon' ? i.kind === 'icon' : !(entry.icon && i.kind === 'icon')));
    const pal = palette(palSet, imgs, entry);
    const swatches = new Map();
    const palSection = h('div', { class: 'pjs-section last' },
      h('div', { class: 'pjv-pal-head' },
        h('span', { class: 'pjs-label' }, `Palette ${scope === 'icon' ? 'de l\'icône' : (entry.icon ? 'de Face et dos' : '')} (${pal.length} couleurs)`),
        h('button', { class: 'pjs-btn small', onclick: () => { target.colors = {}; render(); }, title: 'Oublie les couleurs choisies à la main' }, 'Réinitialiser les couleurs'),
        h('button', { class: 'pjs-btn small', onclick: () => { target.colors = {}; target.hue = 0; target.saturation = 0; target.lightness = 0; render(); } }, 'Tout remettre à zéro')));
    const palGrid = h('div', { class: 'pjv-palette' });
    pal.forEach(({ hex, count }) => {
      const input = h('input', { type: 'color', class: 'pjv-color', value: rgbToHex(...radiantColor(hex, target)) });
      const reset = h('button', { class: 'pjv-reset', title: 'Revenir à la couleur calculée', onclick: () => { delete target.colors[hex]; updatePreview(); } }, '×');
      const sw = h('div', { class: 'pjv-swatch' + (target.colors[hex] ? ' set' : ''), title: `${hex} — ${count} pixels` },
        h('span', { class: 'pjv-orig', style: { backgroundColor: hex } }), h('span', { class: 'pjv-arrow' }, '→'), input, reset);
      input.addEventListener('input', () => { target.colors[hex] = input.value; sw.classList.add('set'); updatePreview(true); });
      swatches.set(hex, { sw, input });
      palGrid.appendChild(sw);
    });
    palSection.appendChild(palGrid);
    palSection.appendChild(h('div', { class: 'pjs-hint' }, S.kind === 'shiny' ? 'Clique sur un sprite pour retrouver une couleur. À l\'enregistrement, les sprites chromatiques (face, dos, icône) sont écrits dans graphics/pokedex/poke…shiny/ (l\'ancien est gardé de côté).' : 'Clique sur un sprite pour retrouver une couleur. À l\'enregistrement, les sprites Radiants (face, dos, icône) sont écrits dans graphics/pokedex/poke…radiant/.'));
    block.appendChild(palSection);
    refs = { entry, target, radiantCanvases, swatches, imgs };
  }

  // Met à jour les aperçus Radiants et la palette sans tout redessiner
  function updatePreview(keepInputs) {
    if (!refs) return;
    const { entry, radiantCanvases, swatches, imgs } = refs;
    radiantCanvases.forEach(({ canvas, item }) => { const base = baseImage(item, imgs, entry); if (base) drawInto(canvas, recolor(base, settingsFor(item, entry))); });
    const target = refs.target || entry;
    swatches.forEach(({ sw, input }, hex) => {
      sw.classList.toggle('set', !!target.colors[hex]);
      if (!keepInputs || !target.colors[hex]) input.value = rgbToHex(...radiantColor(hex, target));
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
    const files = spriteSet(creature, form).map((i) => S.kind + ':' + i.kind + '/' + i.out[S.kind].filename);
    S.removals = S.removals.filter((r) => !files.includes((r.target || 'radiant') + ':' + r.kind + '/' + r.filename));
    if (S.kind === 'shiny') base = 'normal';
    S.config[S.kind].push({ creature: creature.dbSymbol, form, base, hue: 150, saturation: 0, lightness: 0, colors: {} });
    render();
  }

  function removeEntry(creature, entry) {
    if (!confirm(S.kind === 'shiny'
      ? `Annuler le Chromatique refait de ${creature.name} (forme ${entry.form}) ? À l'enregistrement, l'ancien sprite chromatique est remis (ou effacé s'il n'y en avait pas).`
      : `Supprimer le Radiant de ${creature.name} (forme ${entry.form}) ? Ses images seront effacées à l'enregistrement.`)) return;
    S.config[S.kind] = S.config[S.kind].filter((e) => e !== entry);
    spriteSet(creature, entry.form).forEach((i) => {
      if (S.ctx.files[S.kind][i.kind].includes(i.out[S.kind].filename)) S.removals.push({ kind: i.kind, filename: i.out[S.kind].filename, target: S.kind });
    });
    render();
  }

  // --- Onglet Réglages --------------------------------------------------------
  function renderSettings(content) {
    const row = h('div', { class: 'pjs-row' });
    content.appendChild(row);
    const rates = h('div', { class: 'pjs-block pjs-block-half' });
    rates.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, "Taux d'apparition")));
    [['shiny_rate', 'Chromatique'], ['prismatic_rate', 'Prismatique'], ['radiant_rate', 'Radiant'], ['gold_rate', 'Doré'], ['silver_rate', 'Argenté'], ['copper_rate', 'Cuivré']].forEach(([k, label]) => {
      const input = h('input', { class: 'pjs-input num', type: 'number', min: 0, step: 1, value: S.config[k] });
      const info = h('span', { class: 'pjs-hint inline' });
      const show = () => { const n = S.config[k]; info.textContent = n > 0 ? `≈ ${(100 / n).toFixed(n > 1000 ? 3 : 2)} %` : 'jamais'; };
      input.addEventListener('input', () => { S.config[k] = Math.max(0, parseInt(input.value, 10) || 0); show(); updateStatus(); });
      show();
      rates.appendChild(h('div', { class: 'pjs-section row' + (k === 'shiny_rate' ? ' first' : '') },
        h('span', { class: 'pjs-label' }, label), h('span', { class: 'pjs-inline' }, '1 chance sur', input, info)));
    });
    rates.appendChild(h('div', { class: 'pjs-section row last' },
      h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: S.config.count_as_shiny !== false, onchange: (e) => { S.config.count_as_shiny = e.target.checked; updateStatus(); } }),
        'Une variante compte aussi comme chromatique (étoile, scintillement en combat)')));
    rates.appendChild(h('div', { class: 'pjs-hint' }, 'Chromatique : 4096 comme dans PSDK (le Charme Chroma et les chaînes de pêche donnent toujours plus de chances). Variantes : tirage à chaque nouveau Pokémon (sauvage, œuf, don…), Prismatique d\'abord, puis Radiant, Doré, Argenté et Cuivré. 0 = jamais. Un Pokémon sans sprite Radiant ne peut pas être Radiant. Commandes : add_pokemon_variant(:pikachu, 10, :gold), set_pokemon_variant(0, :silver).'));
    row.appendChild(rates);

    // dégradés
    const sample = sampleImage();
    [['copper_colors', 'Cuivré'], ['silver_colors', 'Argenté'], ['gold_colors', 'Doré']].forEach(([k, label]) => {
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
      block.appendChild(h('div', { class: 'pjs-hint' }, `Le jeu recolore chaque sprite selon sa luminosité : les zones sombres prennent la 1re couleur, les plus claires la dernière. Aperçu sur ${S.sel && creatureOf(S.sel.db) ? creatureOf(S.sel.db).name : 'le Pokémon choisi'} (choisis-en un autre dans la page Shiny / Radiant).`));
      draw();
      row.appendChild(block);
    });
    const pblock = h('div', { class: 'pjs-block pjs-block-half' });
    pblock.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Prismatique')));
    const ptints = h('div', { class: 'pjv-tints pjv-prism' });
    sample.then((imgs) => imgs.forEach((img, i) => { if (img) ptints.appendChild(spriteCanvas(prism(img, `${i ? 'back' : 'front'}/${S.sel ? S.sel.db : ''}`))); }));
    pblock.appendChild(ptints);
    pblock.appendChild(h('div', { class: 'pjs-hint' }, `Le jeu recolore le sprite en arc-en-ciel (le relief et les contours sont gardés), avec un halo lumineux et quelques éclats de cristal autour. Aperçu sur ${S.sel && creatureOf(S.sel.db) ? creatureOf(S.sel.db).name : 'le Pokémon choisi'}.`));
    row.appendChild(pblock);
  }

  // sprites de face et de dos du Pokémon choisi (pour l'aperçu Argenté / Doré)
  function sampleImage() {
    const c = S.sel && creatureOf(S.sel.db);
    if (!c) return Promise.resolve([]);
    const set = spriteSet(c, S.sel.form).filter((i) => i.kind !== 'icon').slice(0, 2);
    return loadImages(set.map((i) => i.normalRel)).then((imgs) => set.map((i) => imgs[i.normalRel]));
  }

  // ---------------------------------------------------------------------------
  // Pages « Données > Pokémon > Variantes » : Shiny / Radiant et Métaux
  // (menu et routes ajoutés à Studio par tools/studio-plugins/patch_studio_pages.py)
  // ---------------------------------------------------------------------------
  const PAGES = { 'variants-shiny': 'shiny', 'variants-metals': 'metals' };

  // raccourci clavier (Ctrl+Maj+V) : va sur la page
  function open() {
    if (window.pjNavigate) window.pjNavigate('/database/variants/shiny');
    else toast('Ouvre un projet pour accéder aux variantes (Données > Pokémon)', true);
  }

  function mount(hostEl, page) {
    root = h('div', { id: 'pjv-root' });
    // les touches tapées dans la page ne remontent pas jusqu'aux raccourcis de Studio
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = true;
    S.page = page;
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.config || (latest && latest !== S.projectPath && !dirty())) loadProject(latest || null); else render();
  }

  // page ouverte / quittée (les modifications non enregistrées restent gardées jusqu'au retour sur la page)
  function checkPage() {
    let found = null;
    for (const id of Object.keys(PAGES)) { const el = document.getElementById('pj-page-' + id); if (el) { found = [el, PAGES[id]]; break; } }
    if (root && found && found[0].contains(root) && found[1] === S.page) return;
    if (root && root.parentNode) root.remove();
    if (root) { root = null; refs = null; S.open = false; }
    if (found) mount(found[0], found[1]);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('keydown', (e) => {
    const k = e.key.toLowerCase();
    const typing = e.target && ['INPUT', 'TEXTAREA'].includes(e.target.tagName);
    if (e.ctrlKey && e.shiftKey && k === 'v' && !typing) { e.preventDefault(); open(); return; }
    if (!S.open) return;
    if (e.ctrlKey && k === 's') { e.preventDefault(); e.stopPropagation(); save(); }
  }, true);

  setInterval(() => { if (S.open) updateStatus(); }, 1000);

  window.pjVariantesEditor = { open, state: S };
})();

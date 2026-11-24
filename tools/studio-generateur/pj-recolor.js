/* eslint-disable */
// =============================================================================
// Recoloration — page « Données > Personnages > Recoloration » de Pokémon Studio
// Part d'un PNJ (graphics/characters/npc_*.png) ou d'un dresseur (graphics/battlers/Battlers DS/*.png),
// regroupe ses couleurs en zones (cheveux, habits…), et change chaque zone (teinte, saturation, luminosité).
// La nouvelle image est écrite à côté de l'originale, sous un autre nom.
// =============================================================================
(() => {
  // fait défiler seulement la liste qui contient l'élément (scrollIntoView ferait aussi défiler la fenêtre de Studio,
  // ce qui décale toute la page sous la barre du haut)
  function scrollInto(el, center) {
    let box = el.parentElement;
    while (box && box !== document.body && !/^pj\w*-root$/.test(box.id)) {
      const st = getComputedStyle(box);
      if (/(auto|scroll)/.test(st.overflowY + st.overflowX) && (box.scrollHeight > box.clientHeight || box.scrollWidth > box.clientWidth)) break;
      box = box.parentElement;
    }
    if (!box || box === document.body || /^pj\w*-root$/.test(box.id)) return;
    const b = box.getBoundingClientRect(); const r = el.getBoundingClientRect();
    if (center) box.scrollTop += (r.top - b.top) - (box.clientHeight - r.height) / 2;
    else if (r.top < b.top) box.scrollTop -= b.top - r.top;
    else if (r.bottom > b.bottom) box.scrollTop += r.bottom - b.bottom;
    if (r.left < b.left) box.scrollLeft -= b.left - r.left;
    else if (r.right > b.right) box.scrollLeft += r.right - b.right;
  }
  if (window.__pjRecolorLoaded) return;
  window.__pjRecolorLoaded = true;

  const PAGE_ID = 'recoloration';
  const SOURCES = {
    npc: { label: 'PNJ (overworld)', dir: 'graphics/characters', sheet: true },
    battlers: { label: 'Dresseurs DS', dir: 'graphics/battlers/Battlers DS', sheet: false },
  };
  const LIST_MAX = 150;

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjGenerateur;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API du générateur n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  let toastTimer = null;
  function toast(msg, err) {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.remove(), err ? 6000 : 2500);
  }
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const hex2 = (n) => n.toString(16).padStart(2, '0');
  const rgbToHex = (r, g, b) => '#' + hex2(r) + hex2(g) + hex2(b);
  function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b); const min = Math.min(r, g, b);
    let hue = 0; let sat = 0; const l = (max + min) / 2;
    if (max !== min) {
      const d = max - min;
      sat = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      if (max === r) hue = (g - b) / d + (g < b ? 6 : 0); else if (max === g) hue = (b - r) / d + 2; else hue = (r - g) / d + 4;
      hue *= 60;
    }
    return [hue, sat, l];
  }
  function hslToRgb(hue, sat, l) {
    hue = ((hue % 360) + 360) % 360 / 360;
    if (sat <= 0) { const v = Math.round(l * 255); return [v, v, v]; }
    const q = l < 0.5 ? l * (1 + sat) : l + sat - l * sat;
    const p = 2 * l - q;
    const f = (t) => {
      if (t < 0) t += 1; if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    };
    return [f(hue + 1 / 3), f(hue), f(hue - 1 / 3)].map((v) => clamp(Math.round(v * 255), 0, 255));
  }
  const decode = (url) => new Promise((resolve) => {
    if (!url) { resolve(null); return; }
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = url;
  });
  const imageData = (img) => {
    const c = document.createElement('canvas'); c.width = img.width; c.height = img.height;
    const g = c.getContext('2d'); g.drawImage(img, 0, 0);
    return g.getImageData(0, 0, img.width, img.height);
  };

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = {
    open: false, projectPath: null, lists: null, error: null,
    source: 'npc', query: '', sel: null, // nom de fichier
    data: null, zones: [], outName: '', images: new Map(), frame: 0,
  };
  let root = null;
  let refs = null;

  async function loadImg(rel) {
    if (!S.images.has(rel)) S.images.set(rel, call('readProjectImages', { projectPath: S.projectPath, files: [rel] }).then((m) => decode(m[rel])).catch(() => null));
    return S.images.get(rel);
  }
  async function loadImgs(rels) {
    const need = rels.filter((r) => !S.images.has(r));
    if (need.length) {
      const pending = call('readProjectImages', { projectPath: S.projectPath, files: need }).catch(() => ({}));
      need.forEach((r) => S.images.set(r, pending.then((m) => decode(m[r]))));
    }
  }
  const relOf = (name, source = S.source) => `${SOURCES[source].dir}/${name}`;

  // ---------------------------------------------------------------------------
  // Zones de couleurs
  // ---------------------------------------------------------------------------
  const HUE_NAMES = [[15, 'Rouge'], [40, 'Orange'], [65, 'Jaune'], [160, 'Vert'], [195, 'Cyan'], [255, 'Bleu'], [290, 'Violet'], [340, 'Rose'], [361, 'Rouge']];
  const hueName = (hue) => HUE_NAMES.find(([max]) => hue < max)[1];

  // couleurs de l'image regroupées en zones : contours, peau, gris, puis par teinte
  function buildZones(data) {
    const counts = new Map();
    const d = data.data;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i + 3] === 0) continue;
      const hex = rgbToHex(d[i], d[i + 1], d[i + 2]);
      counts.set(hex, (counts.get(hex) || 0) + 1);
    }
    const cols = [...counts.entries()].map(([hex, count]) => {
      const v = parseInt(hex.slice(1), 16);
      const [hu, sa, li] = rgbToHsl((v >> 16) & 255, (v >> 8) & 255, v & 255);
      return { hex, count, hu, sa, li };
    });
    const zones = [];
    const add = (id, label, list, locked) => { if (list.length) zones.push({ id, label, colors: list.map((c) => c.hex), count: list.reduce((a, c) => a + c.count, 0), hue: 0, sat: 0, light: 0, locked }); };
    const outline = cols.filter((c) => c.li < 0.14);
    const rest1 = cols.filter((c) => c.li >= 0.14);
    const skin = rest1.filter((c) => c.hu >= 8 && c.hu <= 42 && c.sa >= 0.2 && c.sa <= 0.85 && c.li >= 0.55 && c.li <= 0.92);
    const rest2 = rest1.filter((c) => !skin.includes(c));
    const grey = rest2.filter((c) => c.sa < 0.14 || c.li > 0.95);
    const hued = rest2.filter((c) => !grey.includes(c)).sort((a, b) => a.hu - b.hu);
    add('outline', 'Contours', outline, true);
    add('skin', 'Peau', skin, true);
    add('grey', 'Gris / blanc', grey, false);
    // teintes : coupées là où l'écart dépasse 28°
    const groups = [];
    hued.forEach((c) => {
      const last = groups[groups.length - 1];
      if (last && c.hu - last[last.length - 1].hu <= 28) last.push(c); else groups.push([c]);
    });
    if (groups.length > 1 && groups[0][0].hu + 360 - groups[groups.length - 1].slice(-1)[0].hu <= 28) groups[0] = groups.pop().concat(groups[0]);
    groups.forEach((g, i) => {
      const w = g.reduce((a, c) => a + c.count, 0);
      const mean = g.reduce((a, c) => a + c.hu * c.count, 0) / w;
      add('h' + i, hueName(mean), g, false);
    });
    // libellés uniques
    const seen = {};
    zones.forEach((z) => { seen[z.label] = (seen[z.label] || 0) + 1; if (seen[z.label] > 1) z.label += ' ' + seen[z.label]; });
    return zones;
  }

  function recolor(data) {
    const out = new ImageData(new Uint8ClampedArray(data.data), data.width, data.height);
    const d = out.data;
    const map = new Map();
    S.zones.forEach((z) => {
      if (!z.hue && !z.sat && !z.light) return;
      z.colors.forEach((hex) => {
        const v = parseInt(hex.slice(1), 16);
        const [hu, sa, li] = rgbToHsl((v >> 16) & 255, (v >> 8) & 255, v & 255);
        map.set(hex, hslToRgb(hu + z.hue, clamp(sa + z.sat / 100, 0, 1), clamp(li + z.light / 100, 0, 1)));
      });
    });
    if (!map.size) return out;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i + 3] === 0) continue;
      const rgb = map.get(rgbToHex(d[i], d[i + 1], d[i + 2]));
      if (rgb) { d[i] = rgb[0]; d[i + 1] = rgb[1]; d[i + 2] = rgb[2]; }
    }
    return out;
  }

  function randomize() {
    const rnd = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
    S.zones.forEach((z) => {
      if (z.locked) return;
      if (z.id === 'grey') { z.hue = 0; z.sat = 0; z.light = rnd(-12, 12); return; }
      z.hue = rnd(-180, 180); z.sat = rnd(-15, 20); z.light = rnd(-10, 10);
    });
  }

  function defaultOutName() {
    const base = (S.sel || '').replace(/\.png$/i, '');
    const names = new Set((S.lists[S.source] || []).map((n) => n.toLowerCase()));
    let i = 1;
    while (names.has(`${base}_recolor${i}.png`.toLowerCase())) i++;
    return `${base}_recolor${i}`;
  }

  async function select(name) {
    S.sel = name; S.data = null; S.zones = [];
    render();
    const img = await loadImg(relOf(name));
    if (S.sel !== name) return;
    if (!img) { toast('Image illisible : ' + name, true); return; }
    S.data = imageData(img);
    S.zones = buildZones(S.data);
    S.outName = defaultOutName();
    render();
  }

  async function save() {
    if (!S.data) return;
    const name = (S.outName || '').trim().replace(/\.png$/i, '');
    if (!name) { toast('Donne un nom à la nouvelle image', true); return; }
    const c = document.createElement('canvas'); c.width = S.data.width; c.height = S.data.height;
    c.getContext('2d').putImageData(recolor(S.data), 0, 0);
    const rel = relOf(name + '.png');
    try {
      let r = await call('saveProjectImage', { projectPath: S.projectPath, rel, dataUrl: c.toDataURL('image/png') });
      if (r.exists) {
        if (!confirm(`${rel} existe déjà. Le remplacer ?`)) return;
        r = await call('saveProjectImage', { projectPath: S.projectPath, rel, dataUrl: c.toDataURL('image/png'), overwrite: true });
      }
      const list = S.lists[S.source];
      if (!list.includes(name + '.png')) { list.push(name + '.png'); list.sort((a, b) => a.localeCompare(b, 'fr', { sensitivity: 'base' })); }
      S.images.delete(rel);
      toast(`Enregistré : ${rel}`);
      S.outName = defaultOutName();
      render();
    } catch (e) { toast('Erreur : ' + e.message, true); }
  }

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.lists = null; S.error = null; S.images = new Map(); S.sel = null; S.data = null;
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try { S.lists = await call('recolorList', { projectPath }); } catch (e) { S.error = e.message; }
    render();
  }

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    root.textContent = '';
    refs = null;
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' },
        h('span', { class: 'pjs-top-title' }, 'Recoloration'),
        h('div', { class: 'pjs-tabs' }, Object.entries(SOURCES).map(([id, src]) => h('button', {
          class: 'pjs-tab' + (S.source === id ? ' active' : ''), onclick: () => { if (S.source !== id) { S.source = id; S.query = ''; S.sel = null; S.data = null; S.zones = []; render(); } },
        }, src.label))),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('button', { class: 'pjs-btn secondary', disabled: !S.data, onclick: () => { randomize(); render(); }, title: 'Change au hasard les zones non verrouillées (Ctrl+R)' }, '🎲 Au hasard'),
        h('button', { class: 'pjs-btn primary', disabled: !S.data, onclick: save, title: 'Écrit la nouvelle image à côté de l\'originale (Ctrl+S)' }, 'Enregistrer'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.lists) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return; }
    const content = h('div', { class: 'pjs-content pjg-content' });
    page.appendChild(content);
    const row = h('div', { class: 'pjs-row pjg-row' });
    row.appendChild(renderList());
    row.appendChild(renderEditor());
    content.appendChild(row);
  }

  function renderList() {
    const block = h('div', { class: 'pjs-block pjr-list-block' });
    const list = S.lists[S.source] || [];
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, SOURCES[S.source].label), h('span', { class: 'pjs-count' }, String(list.length))));
    const search = h('input', { class: 'pjs-input', placeholder: 'Rechercher', value: S.query });
    const box = h('div', { class: 'pjr-list' + (SOURCES[S.source].sheet ? '' : ' big') });
    block.appendChild(search);
    block.appendChild(box);
    const fill = () => {
      box.textContent = '';
      const q = S.query.trim().toLowerCase();
      const items = list.filter((n) => !q || n.toLowerCase().includes(q));
      const shown = items.slice(0, LIST_MAX);
      loadImgs(shown.map((n) => relOf(n)));
      shown.forEach((n) => {
        const c = h('canvas', { class: 'pjr-thumb' });
        const it = h('div', { class: 'pjr-item' + (n === S.sel ? ' active' : ''), title: n, onclick: () => select(n) }, c, h('span', { class: 'pjr-name' }, n.replace(/\.png$/i, '')));
        box.appendChild(it);
        loadImg(relOf(n)).then((img) => {
          if (!img) return;
          const sheet = SOURCES[S.source].sheet;
          const fw = sheet ? img.width / 4 : img.width; const fh = sheet ? img.height / 4 : img.height;
          c.width = fw; c.height = fh;
          c.getContext('2d').drawImage(img, 0, 0, fw, fh, 0, 0, fw, fh);
        });
      });
      if (items.length > LIST_MAX) box.appendChild(h('div', { class: 'pjs-hint' }, `${items.length - LIST_MAX} autres : affine la recherche.`));
      if (!items.length) box.appendChild(h('div', { class: 'pjs-hint' }, 'Aucune image.'));
    };
    search.addEventListener('input', () => { S.query = search.value; fill(); });
    fill();
    requestAnimationFrame(() => { const a = box.querySelector('.active'); if (a) scrollInto(a); });
    return block;
  }

  function renderEditor() {
    const block = h('div', { class: 'pjs-block pjr-editor' });
    if (!S.sel) { block.appendChild(h('div', { class: 'pjs-empty' }, 'Choisis une image dans la liste.')); return block; }
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, S.sel.replace(/\.png$/i, ''))));
    if (!S.data) { block.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return block; }
    const sheet = SOURCES[S.source].sheet;
    const orig = h('canvas', { class: 'pjr-canvas' });
    const recol = h('canvas', { class: 'pjr-canvas' });
    block.appendChild(h('div', { class: 'pjr-previews' },
      h('div', { class: 'pjr-prev' }, h('span', { class: 'pjs-label' }, 'Original'), h('div', { class: 'pjg-stage' }, orig)),
      h('div', { class: 'pjr-prev' }, h('span', { class: 'pjs-label' }, 'Nouvelle version'), h('div', { class: 'pjg-stage' }, recol))));
    const name = h('input', { class: 'pjs-input', value: S.outName });
    name.addEventListener('input', () => { S.outName = name.value; });
    block.appendChild(h('div', { class: 'pjs-section pjg-line' }, h('span', { class: 'pjs-label' }, 'Nom'), name, h('span', { class: 'pjs-hint inline' }, '.png, dans ' + SOURCES[S.source].dir)));
    const zonesBox = h('div', { class: 'pjr-zones' });
    S.zones.forEach((z) => {
      const vals = {};
      const sliders = [['hue', 'Teinte', -180, 180, '°'], ['sat', 'Saturation', -100, 100, ''], ['light', 'Luminosité', -50, 50, '']].map(([k, label, min, max, unit]) => {
        const out = h('span', { class: 'pjv-val' }, `${z[k]}${unit}`);
        const input = h('input', { type: 'range', class: 'pjv-range', min, max, step: 1, value: z[k], disabled: z.locked });
        input.addEventListener('input', () => { z[k] = parseInt(input.value, 10) || 0; out.textContent = `${z[k]}${unit}`; updatePreview(); });
        input.addEventListener('dblclick', () => { input.value = 0; input.dispatchEvent(new Event('input')); });
        vals[k] = input;
        return h('div', { class: 'pjv-slider' }, h('span', { class: 'pjs-label' }, label), input, out);
      });
      const chips = h('div', { class: 'pjr-chips' }, z.colors.slice(0, 24).map((hex) => h('span', { class: 'pjr-chip', style: { backgroundColor: hex }, title: hex })));
      zonesBox.appendChild(h('div', { class: 'pjr-zone' + (z.locked ? ' locked' : '') },
        h('div', { class: 'pjg-line' }, h('span', { class: 'pjr-zone-name' }, z.label), chips,
          h('button', { class: 'pjg-lock' + (z.locked ? ' on' : ''), title: z.locked ? 'Verrouillée : gardée telle quelle' : 'Verrouiller', onclick: () => { z.locked = !z.locked; if (z.locked) { z.hue = 0; z.sat = 0; z.light = 0; } render(); } }, z.locked ? '🔒' : '🔓')),
        z.locked ? null : sliders));
    });
    block.appendChild(h('div', { class: 'pjs-section' }, h('span', { class: 'pjs-label' }, 'Zones de couleurs'), zonesBox,
      h('div', { class: 'pjs-hint' }, 'Les couleurs de l\'image sont regroupées par teinte. Contours et peau sont verrouillés au départ. Double-clic sur un curseur : 0.')));
    refs = { orig, recol, sheet };
    updatePreview();
    return block;
  }

  let recolored = null;
  function updatePreview() {
    if (!refs || !S.data) return;
    recolored = recolor(S.data);
    paint();
  }
  function paint() {
    if (!refs) return;
    const { orig, recol, sheet } = refs;
    [[orig, S.data], [recol, recolored]].forEach(([c, data]) => {
      if (!data) return;
      const src = document.createElement('canvas'); src.width = data.width; src.height = data.height;
      src.getContext('2d').putImageData(data, 0, 0);
      if (sheet) {
        const fw = data.width / 4; const fh = data.height / 4;
        c.width = fw * 4; c.height = fh;
        const g = c.getContext('2d'); g.clearRect(0, 0, c.width, c.height);
        for (let row = 0; row < 4; row++) g.drawImage(src, (S.frame % 4) * fw, row * fh, fw, fh, row * fw, 0, fw, fh);
      } else {
        c.width = data.width; c.height = data.height;
        c.getContext('2d').drawImage(src, 0, 0);
      }
      // agrandi en pixels nets, sans dépasser la zone d'aperçu
      const box = c.parentElement ? c.parentElement.clientWidth - 16 : 360;
      const scale = Math.max(1, Math.min(sheet ? 3 : 2, Math.floor(box / c.width) || 1));
      c.style.width = c.width * scale + 'px'; c.style.height = c.height * scale + 'px';
    });
  }
  setInterval(() => { if (S.open && refs && refs.sheet) { S.frame++; paint(); } }, 220);

  // ---------------------------------------------------------------------------
  // Page « Données > Personnages > Recoloration »
  // ---------------------------------------------------------------------------
  if (!(window.pjPluginPages = window.pjPluginPages || []).some((p) => p.id === PAGE_ID)) window.pjPluginPages.push({ id: PAGE_ID, label: 'Recoloration', place: 'generator' });
  window.dispatchEvent(new Event('pj-plugin-pages'));

  function mount(hostEl) {
    root = h('div', { id: 'pjr-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = true;
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.lists || (latest && latest !== S.projectPath)) loadProject(latest || null); else render();
  }
  function checkPage() {
    const hostEl = document.getElementById('pj-page-' + PAGE_ID);
    if (root && hostEl && hostEl.contains(root)) return;
    if (root) { root = null; refs = null; S.open = false; }
    if (hostEl) mount(hostEl);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('keydown', (e) => {
    if (!S.open || !S.data) return;
    const k = e.key.toLowerCase();
    const typing = e.target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName);
    if (e.ctrlKey && k === 'r' && !typing) { e.preventDefault(); e.stopPropagation(); randomize(); render(); }
    if (e.ctrlKey && k === 's') { e.preventDefault(); e.stopPropagation(); save(); }
  }, true);

  window.pjRecolorEditor = { state: S };
})();

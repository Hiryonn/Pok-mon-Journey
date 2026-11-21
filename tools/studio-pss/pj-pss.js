/* eslint-disable */
// =============================================================================
// Générateur d'icônes PSS — page « Générateurs > Icônes PSS » de Pokémon Studio
// Crée la photo de profil (icône de 40x40) du mode en ligne. Indépendant du générateur de personnages.
// Les pièces viennent de graphics/icones_pss/pieces (tools/pss-icones/decouper_planches.py) ;
// l'icône est écrite dans graphics/icones_pss/icones/<nom>.png. Règles d'assemblage : pj-pss-logic.js
// =============================================================================
(() => {
  if (window.__pjPssLoaded) return;
  window.__pjPssLoaded = true;

  const PAGE_ID = 'icones-pss';
  const L = window.pjPssLogic;
  const SIZE = 40;
  const SLOTS = [
    ['serie', 'Série'], ['peau', 'Peau'], ['yeux', 'Yeux'], ['haut', 'Haut'], ['coiffure', 'Coiffure'],
    ['couleur_cheveux', 'Cheveux'], ['frange', 'Frange'], ['accessoire', 'Accessoire'], ['chapeau', 'Chapeau'],
  ];

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjPss;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API du générateur d'icônes n'est pas disponible : relance installer_pss.bat puis redémarre Studio.");
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
  const fileName = (s) => String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9_]+/g, '_').replace(/^_+|_+$/g, '');
  const loadImage = (url) => new Promise((resolve) => {
    if (!url) { resolve(null); return; }
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = url;
  });

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = { open: false, projectPath: null, ctx: null, error: null, images: new Map(), spec: null, locks: {}, name: 'mon_icone' };
  let root = null;

  const catalog = () => S.ctx && S.ctx.catalog;
  const serie = (spec) => L.serieOf(catalog(), (spec || S.spec).serie);

  // dessine une icône (réglage `spec`) sur un canevas de 40x40
  function draw(canvas, spec) {
    canvas.width = SIZE; canvas.height = SIZE;
    const g = canvas.getContext('2d');
    g.imageSmoothingEnabled = false;
    g.clearRect(0, 0, SIZE, SIZE);
    L.layers(catalog(), spec).forEach((f) => { const img = S.images.get(f); if (img) g.drawImage(img, 0, 0); });
  }
  const iconCanvas = (spec, cls) => { const c = h('canvas', { class: cls || 'pjp-icon' }); draw(c, spec); return c; };
  const withChange = (change) => L.fixSpec(catalog(), Object.assign(clone(S.spec), change));

  // ---------------------------------------------------------------------------
  // Chargement
  // ---------------------------------------------------------------------------
  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.error = null; S.images = new Map();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      if (S.ctx.catalog) {
        const urls = await call('readPieces', { projectPath });
        await Promise.all(Object.entries(urls).map(async ([f, url]) => S.images.set(f, await loadImage(url))));
        if (!S.spec || !S.ctx.catalog.series.some((s) => s.id === S.spec.serie)) S.spec = L.randomSpec(S.ctx.catalog);
        else S.spec = L.fixSpec(S.ctx.catalog, S.spec);
      }
    } catch (e) { S.error = e.message; }
    render();
  }

  async function saveIcon(overwrite) {
    const name = fileName(S.name);
    if (!name) { toast('Donne un nom à l\'icône.', true); return; }
    const c = h('canvas'); draw(c, S.spec);
    try {
      const r = await call('saveIcon', { projectPath: S.projectPath, name, spec: S.spec, dataUrl: c.toDataURL('image/png'), overwrite: !!overwrite });
      if (r.exists) {
        if (window.confirm(`graphics/icones_pss/icones/${name}.png existe déjà. Le remplacer ?`)) return saveIcon(true);
        return;
      }
      toast('Icône écrite : ' + r.written);
      S.ctx = await call('getContext', { projectPath: S.projectPath });
      render();
    } catch (e) { toast(e.message, true); }
  }

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const ready = !!(S.ctx && catalog() && S.spec);
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' },
        h('span', { class: 'pjs-top-title' }, 'Icônes PSS'),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('button', { class: 'pjs-btn secondary', disabled: !ready, title: 'Tire au hasard les réglages qui ne sont pas verrouillés (Ctrl+R)', onclick: randomize }, '🎲 Au hasard'),
        h('button', { class: 'pjs-btn primary', disabled: !ready, title: 'Écrit l\'icône (40x40) dans graphics/icones_pss/icones', onclick: () => saveIcon(false) }, 'Enregistrer l\'icône'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.ctx) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement des pièces…')); return; }
    if (!catalog()) {
      page.appendChild(h('div', { class: 'pjs-warn' }, 'Les pièces ne sont pas préparées. Lance « python tools/pss-icones/decouper_planches.py » à la racine du projet, puis rouvre cette page.'));
      return;
    }
    const content = h('div', { class: 'pjs-content pjp-content' });
    page.appendChild(content);
    const row = h('div', { class: 'pjs-row pjp-row' });
    row.appendChild(renderControls());
    row.appendChild(renderPreview());
    content.appendChild(row);
    content.appendChild(renderSaved());
  }

  function randomize() {
    if (!S.spec) return;
    S.spec = L.randomSpec(catalog(), S.spec, S.locks);
    render();
  }

  function lockBtn(id) {
    return h('button', {
      class: 'pjp-lock' + (S.locks[id] ? ' on' : ''), title: S.locks[id] ? 'Verrouillé : « Au hasard » le garde' : 'Verrouiller pour « Au hasard »',
      onclick: () => { S.locks[id] = !S.locks[id]; render(); },
    }, S.locks[id] ? '🔒' : '🔓');
  }

  function swatches(hexes, labels, current, key, none) {
    const btn = (value, title, hex, text) => h('button', {
      class: 'pjp-swatch' + (value === current ? ' active' : '') + (hex ? '' : ' text'), title,
      style: hex ? { backgroundColor: hex } : null, onclick: () => { S.spec = withChange({ [key]: value }); render(); },
    }, hex ? '' : text);
    return h('div', { class: 'pjp-swatches' }, [none ? btn(-1, 'Aucun', null, 'Aucun') : null, hexes.map((hex, i) => btn(i, labels[i] || String(i + 1), hex))]);
  }

  // grille de choix : chaque case montre l'icône obtenue avec ce choix
  function grid(count, current, key, titleOf, none) {
    const cell = (value, title) => h('button', {
      class: 'pjp-cell' + (value === current ? ' active' : ''), title, onclick: () => { S.spec = withChange({ [key]: value }); render(); },
    }, iconCanvas(withChange({ [key]: value }), 'pjp-thumb'));
    const cells = [];
    if (none) cells.push(h('button', {
      class: 'pjp-cell none' + (current === -1 ? ' active' : ''), title: 'Aucun', onclick: () => { S.spec = withChange({ [key]: -1 }); render(); },
    }, h('span', null, 'Aucun')));
    for (let i = 0; i < count; i++) cells.push(cell(i, titleOf(i)));
    return h('div', { class: 'pjp-grid' }, cells);
  }

  function line(id, label, control) {
    return h('div', { class: 'pjs-section pjp-line' }, h('span', { class: 'pjs-label' }, label), control, id ? lockBtn(id) : null);
  }

  function renderControls() {
    const spec = S.spec;
    const s = serie();
    const cat = catalog();
    const block = h('div', { class: 'pjs-block pjp-controls' });
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Icône')));
    block.appendChild(line('serie', 'Série', h('div', { class: 'pjs-variants' }, cat.series.map((x) => h('button', {
      class: 'pjs-variant' + (spec.serie === x.id ? ' active' : ''), onclick: () => { S.spec = L.fixSpec(cat, Object.assign(clone(spec), { serie: x.id })); render(); },
    }, x.label)))));
    block.appendChild(line('peau', 'Peau', grid(s.peau.length, spec.peau, 'peau', (i) => 'Peau ' + (i + 1), false)));
    block.appendChild(line('yeux', 'Yeux', grid(s.yeux.length, spec.yeux, 'yeux', (i) => 'Yeux ' + (i + 1), false)));
    block.appendChild(line('haut', 'Haut', swatches(s.hauts_hex, cat.couleurs_hauts, spec.haut, 'haut', false)));
    block.appendChild(line('coiffure', 'Coiffure', grid(s.cheveux.length, spec.coiffure, 'coiffure', (i) => s.cheveux[i].label, true)));
    block.appendChild(line('couleur_cheveux', 'Cheveux', swatches(cat.couleurs_cheveux.map((c) => c.hex), cat.couleurs_cheveux.map((c) => c.label), spec.couleur_cheveux, 'couleur_cheveux', false)));
    if (s.frange.length) block.appendChild(line('frange', 'Frange', grid(s.frange.length, spec.frange, 'frange', (i) => 'Frange ' + cat.couleurs_cheveux[i].label, true)));
    const accs = L.accessories(s);
    block.appendChild(line('accessoire', 'Accessoire', grid(accs.length, spec.accessoire, 'accessoire', (i) => accs[i].label + ' ' + (i + 1), true)));
    block.appendChild(line('chapeau', 'Chapeau', grid(s.chapeaux.length, spec.chapeau, 'chapeau', (i) => 'Chapeau ' + (i + 1), true)));
    return block;
  }

  function renderPreview() {
    const block = h('div', { class: 'pjs-block pjp-preview' });
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Aperçu')));
    block.appendChild(h('div', { class: 'pjp-stage' }, iconCanvas(S.spec, 'pjp-big')));
    block.appendChild(h('div', { class: 'pjp-sizes' }, iconCanvas(S.spec, 'pjp-s1'), iconCanvas(S.spec, 'pjp-s2'),
      h('span', { class: 'pjs-hint' }, 'Taille réelle (40x40) et ×2')));
    const name = h('input', { class: 'pjs-input', value: S.name, placeholder: 'mon_icone' });
    name.addEventListener('input', () => { S.name = name.value; hint.textContent = target(); });
    const target = () => `graphics/icones_pss/icones/${fileName(S.name) || '…'}.png`;
    const hint = h('div', { class: 'pjp-target' }, target());
    block.appendChild(h('div', { class: 'pjs-section pjp-line' }, h('span', { class: 'pjs-label' }, 'Nom'), name));
    block.appendChild(hint);
    return block;
  }

  function renderSaved() {
    const saved = S.ctx.saved || [];
    const block = h('div', { class: 'pjs-block pjp-saved' });
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Icônes enregistrées')));
    if (!saved.length) { block.appendChild(h('div', { class: 'pjs-hint' }, 'Aucune pour l\'instant : crée une icône puis « Enregistrer l\'icône ».')); return block; }
    block.appendChild(h('div', { class: 'pjp-saved-list' }, saved.map((it) => {
      let spec;
      try { spec = L.fixSpec(catalog(), clone(it.spec)); } catch (e) { return null; }
      return h('div', { class: 'pjp-saved-item' + (fileName(S.name) === it.name ? ' active' : '') },
        h('button', { class: 'pjp-saved-btn', title: 'Reprendre cette icône', onclick: () => { S.spec = spec; S.name = it.name; render(); } },
          iconCanvas(spec, 'pjp-thumb'), h('span', null, it.name)),
        h('button', {
          class: 'pjs-btn small', title: 'Retire l\'icône de la liste (le fichier .png reste dans le projet)',
          onclick: async () => { try { await call('forgetIcon', { projectPath: S.projectPath, name: it.name }); S.ctx = await call('getContext', { projectPath: S.projectPath }); render(); } catch (e) { toast(e.message, true); } },
        }, 'Oublier'));
    })));
    return block;
  }

  // ---------------------------------------------------------------------------
  // Page « Générateurs > Icônes PSS » (vraie page de Studio : /generators/icones-pss)
  // ---------------------------------------------------------------------------
  if (!(window.pjPluginPages = window.pjPluginPages || []).some((p) => p.id === PAGE_ID)) window.pjPluginPages.push({ id: PAGE_ID, label: 'Icônes PSS', place: 'generator' });
  window.dispatchEvent(new Event('pj-plugin-pages'));

  function mount(hostEl) {
    root = h('div', { id: 'pjp-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = true;
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.ctx || (latest && latest !== S.projectPath)) loadProject(latest || null); else render();
  }

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
    if (!S.open) return;
    const typing = e.target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName);
    if (e.ctrlKey && e.key.toLowerCase() === 'r' && !typing && S.spec) { e.preventDefault(); e.stopPropagation(); randomize(); }
  }, true);

  window.pjPssEditor = { state: S, randomize };
})();

/* eslint-disable */
// =============================================================================
// Aseprite — section « Aseprite » de la barre de gauche de Pokémon Studio Extra
//   À gauche : les graphismes du projet (dossier graphics), seuls fichiers qu'Aseprite peut ouvrir ici
//   À droite : Aseprite lui-même, intégré dans la fenêtre de Studio
// Style de l'éditeur Smartphone (classes pjs-*).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjAsepriteLoaded) return;
  window.__pjAsepriteLoaded = true;

  const api = window.pjAseprite;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API Aseprite n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  const currentProject = () => (projectList()[0] && projectList()[0].projectPath) || null;

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = {
    projectPath: null, ctx: null, search: '', open: new Set(['']), selected: null, preview: null,
    status: '', error: '', starting: false, running: false,
  };
  let root = null;
  let stage = null;
  let lastBounds = '';

  function setStatus(text, error) {
    S.status = text || '';
    S.error = error || '';
    const el = root && root.querySelector('.pja-status');
    if (el) { el.textContent = S.error || S.status; el.classList.toggle('error', !!S.error); }
    renderStage();
  }

  async function load() {
    S.projectPath = currentProject();
    try {
      S.ctx = await call('getContext', { projectPath: S.projectPath });
    } catch (e) { S.ctx = null; setStatus('', e.message); }
    render();
    start();
  }

  // ---------------------------------------------------------------------------
  // Fenêtre d'Aseprite : suit la zone de droite de la page
  // ---------------------------------------------------------------------------
  function bounds() {
    if (!stage || !stage.isConnected) return null;
    const r = stage.getBoundingClientRect();
    const k = window.devicePixelRatio || 1;
    return { x: r.left * k, y: r.top * k, w: r.width * k, h: r.height * k };
  }
  async function start() {
    if (!S.ctx || !S.ctx.found || !S.ctx.rootExists || S.starting) return;
    if (S.ctx.platform !== 'win32') { setStatus('', 'Aseprite intégré : Windows uniquement.'); return; }
    S.starting = true;
    setStatus('Démarrage d’Aseprite…');
    try {
      await call('start', { projectPath: S.projectPath, bounds: bounds(), visible: !!(root && root.isConnected) });
      S.running = true;
      setStatus('Aseprite est prêt.');
      layout(true);
    } catch (e) {
      S.running = false;
      setStatus('', e.message);
    } finally { S.starting = false; }
  }
  async function restart() {
    S.running = false;
    S.starting = true;
    setStatus('Redémarrage d’Aseprite…');
    try {
      await call('restart', { projectPath: S.projectPath, bounds: bounds() });
      S.running = true;
      setStatus('Aseprite est prêt.');
      layout(true);
    } catch (e) { setStatus('', e.message); } finally { S.starting = false; }
  }
  function layout(force) {
    if (!api) return;
    const visible = !!(root && root.isConnected && stage && stage.isConnected && S.running);
    const b = visible ? bounds() : null;
    const key = visible && b ? `${Math.round(b.x)},${Math.round(b.y)},${Math.round(b.w)},${Math.round(b.h)}` : 'hidden';
    if (!force && key === lastBounds) return;
    lastBounds = key;
    call('layout', { bounds: b || undefined, visible }).catch(() => {});
  }

  // ---------------------------------------------------------------------------
  // Graphismes du projet
  // ---------------------------------------------------------------------------
  const ICONS = { '.aseprite': 'ASE', '.ase': 'ASE', '.gif': 'GIF', '.png': 'PNG' };
  const extOf = (name) => (name.match(/\.[^.]+$/) || [''])[0].toLowerCase();
  function matches(node, q) {
    if (!q) return true;
    if (node.dir) return node.children.some((c) => matches(c, q));
    return node.path.toLowerCase().includes(q);
  }
  function treeView(nodes, depth) {
    const q = S.search.trim().toLowerCase();
    const out = [];
    for (const n of nodes) {
      if (!matches(n, q)) continue;
      if (n.dir) {
        const opened = q || S.open.has(n.path);
        out.push(h('div', { class: 'pja-row dir', style: { paddingLeft: 8 + depth * 14 + 'px' },
          onclick: () => { if (S.open.has(n.path)) S.open.delete(n.path); else S.open.add(n.path); renderTree(); } },
        h('span', { class: 'pja-caret' + (opened ? ' open' : '') }, '▸'), h('span', { class: 'pja-name' }, n.name)));
        if (opened) out.push(...treeView(n.children, depth + 1));
      } else {
        out.push(h('div', { class: 'pja-row file' + (S.selected === n.path ? ' sel' : ''), style: { paddingLeft: 22 + depth * 14 + 'px' }, title: 'graphics/' + n.path,
          onclick: () => select(n.path), ondblclick: () => openFile(n.path) },
        h('span', { class: 'pja-ext' }, ICONS[extOf(n.name)] || extOf(n.name).slice(1).toUpperCase()), h('span', { class: 'pja-name' }, n.name)));
      }
    }
    return out;
  }
  async function select(file) {
    S.selected = file;
    S.preview = null;
    renderTree();
    renderPreview();
    try { S.preview = await call('preview', { projectPath: S.projectPath, file }); } catch (e) { S.preview = null; }
    if (S.selected === file) renderPreview();
  }
  async function openFile(file) {
    S.selected = file;
    renderTree();
    if (!S.running) await start();
    try { await call('open', { projectPath: S.projectPath, file }); setStatus('Ouvert : graphics/' + file); } catch (e) { setStatus('', e.message); }
  }
  async function refresh() {
    try { S.ctx = await call('getContext', { projectPath: S.projectPath }); } catch (e) { setStatus('', e.message); }
    renderTree();
  }

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function renderTree() {
    const list = root && root.querySelector('.pja-tree');
    if (!list) return;
    const top = list.scrollTop;
    list.innerHTML = '';
    const nodes = (S.ctx && S.ctx.tree) || [];
    const rows = treeView(nodes, 0);
    if (!rows.length) list.appendChild(h('div', { class: 'pjs-hint pja-empty' }, S.search ? 'Aucun graphisme trouvé.' : 'Aucun graphisme dans graphics.'));
    rows.forEach((r) => list.appendChild(r));
    list.scrollTop = top;
  }
  function renderPreview() {
    const box = root && root.querySelector('.pja-preview');
    if (!box) return;
    box.innerHTML = '';
    if (!S.selected) { box.appendChild(h('div', { class: 'pjs-hint' }, 'Double-clic sur un graphisme pour l’ouvrir dans Aseprite.')); return; }
    if (S.preview && S.preview.url) box.appendChild(h('div', { class: 'pja-img' }, h('img', { src: S.preview.url })));
    box.appendChild(h('div', { class: 'pja-file' }, 'graphics/' + S.selected));
    box.appendChild(h('button', { class: 'pjs-btn primary small', onclick: () => openFile(S.selected) }, 'Ouvrir dans Aseprite'));
  }
  function renderStage() {
    if (!stage) return;
    stage.innerHTML = '';
    if (S.running && !S.error) return;
    const ctx = S.ctx;
    let msg;
    if (S.error) msg = [h('div', { class: 'pja-msg-title' }, 'Aseprite n’a pas pu démarrer'), h('div', { class: 'pjs-hint' }, S.error)];
    else if (ctx && !ctx.found) msg = [h('div', { class: 'pja-msg-title' }, 'Aseprite introuvable'), h('div', { class: 'pjs-hint' }, 'Indique où se trouve Aseprite.exe.')];
    else if (ctx && !ctx.rootExists) msg = [h('div', { class: 'pja-msg-title' }, 'Pas de dossier graphics'), h('div', { class: 'pjs-hint' }, 'Ouvre un projet dans Studio.')];
    else msg = [h('div', { class: 'pja-msg-title' }, S.status || 'Démarrage d’Aseprite…')];
    stage.appendChild(h('div', { class: 'pja-msg' }, msg,
      ctx && !ctx.found ? h('button', { class: 'pjs-btn primary', onclick: pickExe }, 'Choisir Aseprite.exe') : null,
      S.error ? h('button', { class: 'pjs-btn primary', onclick: restart }, 'Réessayer') : null));
  }
  async function pickExe() {
    try {
      const exe = await call('pickExe', {});
      if (exe) { S.error = ''; await load(); }
    } catch (e) { setStatus('', e.message); }
  }
  function render() {
    if (!root) return;
    root.innerHTML = '';
    const ctx = S.ctx;
    stage = h('div', { class: 'pja-stage', onmousedown: () => call('focus', {}).catch(() => {}) });
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Aseprite'),
        h('span', { class: 'pjs-top-sub' }, ctx && ctx.root ? ctx.root : 'Aucun projet ouvert')),
      h('div', { class: 'pjs-topbar-right' }, h('span', { class: 'pjs-status pja-status' }, S.error || S.status),
        h('button', { class: 'pjs-btn small', onclick: refresh, title: 'Relire le dossier graphics' }, 'Actualiser'),
        h('button', { class: 'pjs-btn small', onclick: pickExe, title: ctx && ctx.exe ? ctx.exe : '' }, 'Aseprite.exe…'),
        h('button', { class: 'pjs-btn small', onclick: restart }, 'Redémarrer'))));
    root.appendChild(h('div', { class: 'pja-body' },
      h('div', { class: 'pja-side' },
        h('input', { class: 'pjs-input pja-search', placeholder: 'Rechercher un graphisme…', value: S.search,
          oninput: (e) => { S.search = e.target.value; renderTree(); } }),
        h('div', { class: 'pja-tree' }),
        h('div', { class: 'pja-preview' })),
      stage));
    renderTree();
    renderPreview();
    renderStage();
    layout(true);
  }

  // ---------------------------------------------------------------------------
  // Page « Aseprite » (/aseprite)
  // ---------------------------------------------------------------------------
  const PAGE_ID = 'aseprite';
  if (!(window.pjPluginPages = window.pjPluginPages || []).some((p) => p.id === PAGE_ID)) window.pjPluginPages.push({ id: PAGE_ID, label: 'Aseprite', place: 'aseprite' });
  window.dispatchEvent(new Event('pj-plugin-pages'));

  function mount(hostEl) {
    root = h('div', { id: 'pja-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    const latest = currentProject();
    if (!S.ctx || latest !== S.projectPath) load(); else { render(); if (!S.running) start(); }
  }
  function checkPage() {
    const hostEl = document.getElementById('pj-page-' + PAGE_ID);
    if (root && hostEl && hostEl.contains(root)) { layout(); return; }
    if (root) { root = null; stage = null; layout(true); }
    if (hostEl) mount(hostEl);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const begin = () => { observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['style', 'class'] }); checkPage(); };
  if (document.body) begin(); else document.addEventListener('DOMContentLoaded', begin);
  window.addEventListener('resize', () => layout());
  setInterval(() => { if (root) layout(); }, 400);

  window.pjAsepriteEditor = { state: S, render };
})();

/* eslint-disable */
// =============================================================================
// Code — éditeur de code de Pokémon Studio Extra (section « Code » de la barre de gauche), façon Visual Studio Code
//   Fichiers du projet ouvert : explorateur (créer, renommer, supprimer vers la corbeille), onglets, enregistrement
//   (encodage et fins de ligne conservés), Ctrl+P (ouvrir un fichier), Ctrl+Maj+F (rechercher / remplacer dans le
//   projet), aperçu des images, fichier modifié ailleurs (rechargé ou signalé).
//   Le moteur d'édition est Monaco (celui de VS Code), chargé à la première ouverture (pj-code/monaco.js).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjCodeLoaded) return;
  window.__pjCodeLoaded = true;

  const PAGE_ID = 'code';
  const api = window.pjCode;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API de l'éditeur de code n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const svg = (d, size = 16) => {
    const s = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    s.setAttribute('viewBox', '0 0 24 24'); s.setAttribute('width', size); s.setAttribute('height', size); s.setAttribute('fill', 'currentColor');
    const p = document.createElementNS('http://www.w3.org/2000/svg', 'path'); p.setAttribute('d', d); s.appendChild(p);
    return s;
  };
  const ICONS = {
    files: 'M15 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V7zm3 18H6V4h8v4h4zM8 12h8v2H8zm0 4h8v2H8z',
    search: 'M15.5 14h-.79l-.28-.27A6.47 6.47 0 0016 9.5 6.5 6.5 0 109.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14',
    newFile: 'M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8zm2 14h-3v3h-2v-3H8v-2h3v-3h2v3h3zm-3-7V3.5L18.5 9z',
    newDir: 'M20 6h-8l-2-2H4c-1.11 0-2 .89-2 2v12c0 1.1.89 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2m-1 8h-3v3h-2v-3h-3v-2h3V9h2v3h3z',
    refresh: 'M17.65 6.35A7.96 7.96 0 0012 4a8 8 0 108 8h-2a6 6 0 11-1.76-4.24L13 11h7V4z',
    collapse: 'M7.41 18.59L8.83 20 12 16.83 15.17 20l1.41-1.41L12 14zm9.18-13.18L15.17 4 12 7.17 8.83 4 7.41 5.41 12 10z',
    save: 'M17 3H5a2 2 0 00-2 2v14a2 2 0 002 2h14c1.1 0 2-.9 2-2V7zm-5 16c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3m3-10H5V5h10z',
    close: 'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z',
    caret: 'M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z',
    replaceAll: 'M11 6c1.38 0 2.63.56 3.54 1.46L12 10h6V4l-2.05 2.05A6.98 6.98 0 0011 4c-3.53 0-6.43 2.61-6.92 6H6.1A5 5 0 0111 6m5.64 9.14A6.95 6.95 0 0017.92 12H15.9a5 5 0 01-4.9 4c-1.38 0-2.63-.56-3.54-1.46L10 12H4v6l2.05-2.05A6.98 6.98 0 0011 18c1.55 0 2.98-.51 4.14-1.36L20 21.49 21.49 20z',
  };
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  const currentProject = () => (projectList()[0] && projectList()[0].projectPath) || null;
  const store = {
    get(key, def) { try { const v = localStorage.getItem('pjCode.' + key); return v === null ? def : JSON.parse(v); } catch (e) { return def; } },
    set(key, v) { try { localStorage.setItem('pjCode.' + key, JSON.stringify(v)); } catch (e) { /* rien */ } },
  };
  const baseName = (p) => String(p).split('/').pop();
  const dirOf = (p) => { const i = String(p).lastIndexOf('/'); return i < 0 ? '' : p.slice(0, i); };
  const extOf = (p) => { const b = baseName(p).toLowerCase(); const i = b.lastIndexOf('.'); return i <= 0 ? '' : b.slice(i + 1); };

  // ---------------------------------------------------------------------------
  // Langages et icônes de fichiers
  // ---------------------------------------------------------------------------
  const LANG = {
    rb: 'ruby', rbw: 'ruby', rake: 'ruby', gemspec: 'ruby', js: 'javascript', mjs: 'javascript', cjs: 'javascript', ts: 'typescript', json: 'json',
    'tiled-project': 'json', 'tiled-session': 'json', css: 'css', scss: 'scss', html: 'html', htm: 'html', xml: 'xml', tmx: 'xml', tsx: 'xml', tx: 'xml',
    svg: 'xml', yml: 'yaml', yaml: 'yaml', md: 'markdown', ini: 'ini', cfg: 'ini', conf: 'ini', bat: 'bat', cmd: 'bat', ps1: 'powershell', psm1: 'powershell',
    py: 'python', sh: 'shell', sql: 'sql', glsl: 'cpp', frag: 'cpp', vert: 'cpp', c: 'cpp', cpp: 'cpp', h: 'cpp',
  };
  const NAMES = { gemfile: 'ruby', rakefile: 'ruby', '.gitignore': 'ini', '.gitattributes': 'ini' };
  const LANG_LABEL = { ruby: 'Ruby', javascript: 'JavaScript', typescript: 'TypeScript', json: 'JSON', css: 'CSS', scss: 'SCSS', html: 'HTML', xml: 'XML',
    yaml: 'YAML', markdown: 'Markdown', ini: 'Ini', bat: 'Batch', powershell: 'PowerShell', python: 'Python', shell: 'Shell', sql: 'SQL', cpp: 'C / GLSL', plaintext: 'Texte brut' };
  const langOf = (p) => NAMES[baseName(p).toLowerCase()] || LANG[extOf(p)] || 'plaintext';
  const BADGES = {
    ruby: ['RB', '#e0464e'], javascript: ['JS', '#e8c547'], typescript: ['TS', '#3c8fe0'], json: ['{}', '#d8b24a'], css: ['#', '#4aa3df'], scss: ['#', '#d06aa5'],
    html: ['<>', '#e3793b'], xml: ['<>', '#e3793b'], yaml: ['Y', '#b46ad8'], markdown: ['M↓', '#5fa8d3'], ini: ['⚙', '#9a9aa8'], bat: ['>_', '#7fbf6a'],
    powershell: ['PS', '#4f8fd6'], python: ['PY', '#4f8fd6'], shell: ['$', '#7fbf6a'], sql: ['DB', '#d0a24f'], cpp: ['C', '#6f8fd6'],
  };
  const IMG_EXT = new Set(['png', 'gif', 'bmp', 'jpg', 'jpeg', 'webp', 'ico', 'svg']);
  function badge(p, dir) {
    if (dir) return h('span', { class: 'pjk-icon dir' }, svg('M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8z', 15));
    const e = extOf(p);
    if (IMG_EXT.has(e) && e !== 'svg') return h('span', { class: 'pjk-icon', style: { color: '#4fb39a' } }, svg('M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2M8.5 13.5l2.5 3.01L14.5 12l4.5 6H5z', 14));
    const b = BADGES[langOf(p)];
    if (e === 'rxdata' || e === 'dat') return h('span', { class: 'pjk-icon', style: { color: '#8b8b99' } }, svg('M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8zM6 20V4h7v5h5v11z', 14));
    return b ? h('span', { class: 'pjk-badge', style: { color: b[1] } }, b[0]) : h('span', { class: 'pjk-icon', style: { color: '#8b8b99' } }, svg(ICONS.files, 14));
  }

  // ---------------------------------------------------------------------------
  // État (gardé quand on change de page : onglets et modifications non enregistrées restent)
  // ---------------------------------------------------------------------------
  const S = {
    projectPath: null, ctx: null, view: store.get('view', 'files'), dirs: new Map(), openDirs: new Set(), sel: null,
    tabs: [], active: -1, index: null, search: { query: '', replace: '', regex: false, caseSensitive: false, word: false, include: '', exclude: '', result: null, busy: false, collapsed: new Set() },
    sideW: store.get('sideW', 260), restored: false,
  };
  let root = null; let editor = null; let monaco = null; let editorHost = null; let editorDisposables = [];

  function flash(msg, error) {
    const el = root && root.querySelector('.pjk-flash');
    if (!el) return;
    el.textContent = msg; el.className = 'pjk-flash show' + (error ? ' error' : '');
    clearTimeout(flash.t); flash.t = setTimeout(() => { el.className = 'pjk-flash'; }, error ? 5000 : 2500);
  }
  function modal(title, body, buttons) {
    return new Promise((resolve) => {
      const close = (v) => { ov.remove(); document.removeEventListener('keydown', onKey, true); resolve(v); };
      const onKey = (e) => { if (e.key === 'Escape') { e.stopPropagation(); close(null); } else if (e.key === 'Enter' && !(e.target && e.target.tagName === 'TEXTAREA')) { const p = buttons.find((b) => b[2]); if (p) { e.preventDefault(); e.stopPropagation(); close(typeof p[0] === 'function' ? p[0]() : p[0]); } } };
      const ov = h('div', { class: 'pjk-overlay', onmousedown: (e) => { if (e.target === ov) close(null); } },
        h('div', { class: 'pjk-modal' }, h('h3', null, title), body,
          h('div', { class: 'pjk-modal-actions' }, buttons.map(([v, label, primary]) => h('button', { class: 'pjs-btn small' + (primary ? ' primary' : ''), onclick: () => close(typeof v === 'function' ? v() : v) }, label)))));
      document.addEventListener('keydown', onKey, true);
      (root || document.body).appendChild(ov);
      const f = ov.querySelector('input, textarea');
      if (f) { f.focus(); f.select && f.select(); }
    });
  }
  async function ask(title, label, value, selectEnd) {
    const input = h('input', { class: 'pjs-input', value: value || '' });
    const p = modal(title, h('div', { class: 'pjk-form' }, h('label', null, label, input)), [[null, 'Annuler'], [() => input.value.trim(), 'OK', true]]);
    if (selectEnd !== undefined) setTimeout(() => input.setSelectionRange(0, selectEnd), 0);
    return p;
  }
  function contextMenu(e, items) {
    e.preventDefault(); e.stopPropagation();
    document.querySelectorAll('.pjk-menu').forEach((m) => m.remove());
    const menu = h('div', { class: 'pjk-menu', style: { left: e.clientX + 'px', top: e.clientY + 'px' } },
      items.filter(Boolean).map((it) => it === '-' ? h('div', { class: 'pjk-menu-sep' }) : h('div', { class: 'pjk-menu-item', onmousedown: (ev) => { ev.stopPropagation(); menu.remove(); it[1](); } }, h('span', null, it[0]), it[2] ? h('span', { class: 'pjk-key' }, it[2]) : null)));
    document.body.appendChild(menu);
    const r = menu.getBoundingClientRect();
    if (r.right > innerWidth) menu.style.left = Math.max(0, innerWidth - r.width - 4) + 'px';
    if (r.bottom > innerHeight) menu.style.top = Math.max(0, innerHeight - r.height - 4) + 'px';
    const off = () => { menu.remove(); document.removeEventListener('mousedown', off); };
    setTimeout(() => document.addEventListener('mousedown', off), 0);
  }

  // ---------------------------------------------------------------------------
  // Monaco (chargé à la demande)
  // ---------------------------------------------------------------------------
  let monacoPromise = null;
  function loadMonaco() {
    if (window.pjMonaco) return Promise.resolve(window.pjMonaco);
    if (monacoPromise) return monacoPromise;
    monacoPromise = new Promise((resolve, reject) => {
      const base = (document.querySelector('script[src*="pj-code/pj-code.js"]') || {}).src || './pj-code/pj-code.js';
      const dir = base.replace(/pj-code\.js(\?.*)?$/, '');
      if (!document.querySelector('link[data-pj-monaco]')) document.head.appendChild(h('link', { rel: 'stylesheet', href: dir + 'monaco.css', 'data-pj-monaco': '1' }));
      window.addEventListener('pj-monaco-ready', () => resolve(window.pjMonaco), { once: true });
      const sc = h('script', { src: dir + 'monaco.js' });
      sc.onerror = () => { monacoPromise = null; reject(new Error('monaco.js introuvable (relance l’installateur de l’éditeur de code).')); };
      document.head.appendChild(sc);
    }).then((m) => { defineTheme(m); return m; });
    return monacoPromise;
  }
  function defineTheme(m) {
    m.editor.defineTheme('pj-dark', {
      base: 'vs-dark', inherit: true,
      rules: [
        { token: 'comment', foreground: '6f7b74', fontStyle: 'italic' },
        { token: 'keyword', foreground: 'ff7a85' }, { token: 'string', foreground: 'a5d6a7' }, { token: 'number', foreground: 'f4b26a' },
        { token: 'constant', foreground: '82b1ff' }, { token: 'type', foreground: '82b1ff' }, { token: 'variable', foreground: 'e6c07b' },
        { token: 'regexp', foreground: 'f48fb1' }, { token: 'tag', foreground: 'ff8a80' }, { token: 'attribute.name', foreground: 'f4b26a' },
        { token: 'key', foreground: '9ecbff' }, { token: 'string.key.json', foreground: '9ecbff' }, { token: 'string.value.json', foreground: 'a5d6a7' },
      ],
      colors: {
        'editor.background': '#1d1c22', 'editor.foreground': '#e4e4e7', 'editorLineNumber.foreground': '#4a4957', 'editorLineNumber.activeForeground': '#c9c9d1',
        'editor.lineHighlightBackground': '#26252c', 'editor.lineHighlightBorder': '#00000000', 'editorCursor.foreground': '#ff5a62',
        'editor.selectionBackground': '#b81d2455', 'editor.inactiveSelectionBackground': '#b81d2430', 'editor.selectionHighlightBackground': '#b81d2426',
        'editor.findMatchBackground': '#f5ab3d66', 'editor.findMatchHighlightBackground': '#f5ab3d33', 'editor.wordHighlightBackground': '#ffffff14',
        'editorWidget.background': '#26252c', 'editorWidget.border': '#3a3843', 'editorSuggestWidget.background': '#26252c', 'editorSuggestWidget.selectedBackground': '#b81d2440',
        'editorIndentGuide.background1': '#2d2c35', 'editorIndentGuide.activeBackground1': '#4a4957', 'editorBracketMatch.background': '#b81d2433', 'editorBracketMatch.border': '#b81d24',
        'minimap.background': '#1d1c22', 'minimapSlider.background': '#ffffff10', 'scrollbarSlider.background': '#3a384360', 'scrollbarSlider.hoverBackground': '#3a3843a0',
        'focusBorder': '#b81d24', 'input.background': '#1d1c22', 'inputOption.activeBorder': '#b81d24', 'inputOption.activeBackground': '#b81d2440',
        'list.activeSelectionBackground': '#b81d2440', 'list.hoverBackground': '#2b2a32', 'list.highlightForeground': '#ff6b73', 'quickInput.background': '#26252c',
        'editorGutter.modifiedBackground': '#f5ab3d', 'editorGutter.addedBackground': '#5fbf74', 'editorOverviewRuler.border': '#00000000',
      },
    });
  }
  const EDITOR_OPTIONS = () => ({
    theme: 'pj-dark', automaticLayout: true, fontFamily: "'Cascadia Code', 'Cascadia Mono', Consolas, 'Courier New', monospace", fontSize: store.get('fontSize', 14),
    fontLigatures: true, minimap: { enabled: store.get('minimap', true), renderCharacters: false, scale: 1 }, smoothScrolling: true, cursorBlinking: 'smooth',
    cursorSmoothCaretAnimation: 'on', mouseWheelZoom: true, renderWhitespace: 'selection', bracketPairColorization: { enabled: true }, guides: { bracketPairs: 'active', indentation: true },
    stickyScroll: { enabled: true }, wordWrap: store.get('wordWrap', 'off'), scrollBeyondLastLine: false, padding: { top: 8 }, fixedOverflowWidgets: true, tabSize: 2, insertSpaces: true,
    detectIndentation: true, renderLineHighlight: 'all', occurrencesHighlight: 'singleFile', links: false, contextmenu: true, quickSuggestions: { other: true, comments: false, strings: false },
  });

  // ---------------------------------------------------------------------------
  // Explorateur
  // ---------------------------------------------------------------------------
  async function loadDir(dir) {
    const list = await call('list', { projectPath: S.projectPath, dir });
    S.dirs.set(dir, list);
    return list;
  }
  async function toggleDir(dir, open) {
    const want = open === undefined ? !S.openDirs.has(dir) : open;
    if (want) { S.openDirs.add(dir); if (!S.dirs.has(dir)) { try { await loadDir(dir); } catch (e) { flash(e.message, true); } } } else S.openDirs.delete(dir);
    saveSession(); renderTree();
  }
  async function refreshTree() {
    const dirs = ['', ...S.openDirs];
    S.dirs.clear();
    for (const d of dirs) { try { await loadDir(d); } catch (e) { S.openDirs.delete(d); } }
    S.index = null;
    renderTree();
  }
  async function revealInTree(file) {
    const parts = file.split('/'); let acc = '';
    for (let i = 0; i < parts.length - 1; i++) { acc = acc ? acc + '/' + parts[i] : parts[i]; S.openDirs.add(acc); if (!S.dirs.has(acc)) { try { await loadDir(acc); } catch (e) { return; } } }
    S.sel = file; renderTree();
    const row = root && root.querySelector(`.pjk-row[data-path="${CSS.escape(file)}"]`);
    if (row) row.scrollIntoView({ block: 'nearest' });
  }
  function renderTree() {
    const box = root && root.querySelector('.pjk-tree');
    if (!box) return;
    const scroll = box.scrollTop;
    box.innerHTML = '';
    const rows = [];
    const walk = (dir, depth) => {
      const list = S.dirs.get(dir);
      if (!list) return;
      for (const e of list) {
        const open = e.dir && S.openDirs.has(e.path);
        const tab = S.tabs[S.active];
        rows.push(h('div', {
          class: 'pjk-row' + (S.sel === e.path ? ' sel' : '') + (tab && tab.path === e.path ? ' active' : '') + (e.dir ? ' dir' : '') + (S.tabs.some((t) => t.path === e.path && isDirty(t)) ? ' dirty' : ''),
          'data-path': e.path, style: { paddingLeft: 8 + depth * 12 + 'px' }, title: e.path,
          onclick: () => { S.sel = e.path; if (e.dir) toggleDir(e.path); else openFile(e.path, { preview: true }); renderTree(); },
          ondblclick: () => { if (!e.dir) openFile(e.path, { pin: true }); },
          oncontextmenu: (ev) => { S.sel = e.path; renderTree(); fileMenu(ev, e); },
        }, h('span', { class: 'pjk-caret' + (open ? ' open' : '') + (e.dir ? '' : ' none') }, e.dir ? svg(ICONS.caret, 14) : null), badge(e.path, e.dir), h('span', { class: 'pjk-name' }, e.name)));
        if (open) walk(e.path, depth + 1);
      }
    };
    walk('', 0);
    if (!rows.length) rows.push(h('div', { class: 'pjs-hint pjk-empty' }, S.projectPath ? 'Dossier vide.' : 'Aucun projet ouvert.'));
    rows.forEach((r) => box.appendChild(r));
    box.scrollTop = scroll;
  }
  function fileMenu(e, entry) {
    const dir = entry ? (entry.dir ? entry.path : dirOf(entry.path)) : '';
    contextMenu(e, [
      ['Nouveau fichier…', () => newEntry(dir, false)], ['Nouveau dossier…', () => newEntry(dir, true)], '-',
      entry && !entry.dir ? ['Ouvrir', () => openFile(entry.path, { pin: true })] : null,
      entry ? ['Renommer…', () => renameEntry(entry), 'F2'] : null,
      entry ? ['Supprimer (corbeille)', () => deleteEntry(entry), 'Suppr'] : null, entry ? '-' : null,
      ['Copier le chemin', () => navigator.clipboard.writeText(S.ctx.root + (entry ? '\\' + entry.path.replace(/\//g, '\\') : ''))],
      entry ? ['Copier le chemin relatif', () => navigator.clipboard.writeText(entry.path)] : null,
      ['Afficher dans l’Explorateur Windows', () => call('reveal', { projectPath: S.projectPath, file: entry ? entry.path : '' }).catch((err) => flash(err.message, true))],
      dir || !entry ? ['Rechercher dans ce dossier…', () => { S.view = 'search'; S.search.include = (dir ? dir + '/**' : ''); renderSide(); }] : null,
    ]);
  }
  const validName = (n) => n && !/[\\:*?"<>|]/.test(n) && !n.split('/').some((p) => p === '..' || p === '.' || !p);
  async function newEntry(dir, isDir) {
    const name = await ask(isDir ? 'Nouveau dossier' : 'Nouveau fichier', 'Nom (dans ' + (dir || S.ctx.name) + ')', '');
    if (!name) return;
    if (!validName(name)) { flash('Nom invalide.', true); return; }
    const p = dir ? dir + '/' + name : name;
    try {
      await call('create', isDir ? { projectPath: S.projectPath, dir: p } : { projectPath: S.projectPath, file: p });
      if (dir) S.openDirs.add(dir);
      await refreshTree();
      if (!isDir) { await openFile(p, { pin: true }); revealInTree(p); }
    } catch (err) { flash(err.message, true); }
  }
  async function renameEntry(entry) {
    const dot = entry.dir ? -1 : entry.name.lastIndexOf('.');
    const name = await ask('Renommer', 'Nouveau nom', entry.name, dot > 0 ? dot : undefined);
    if (!name || name === entry.name) return;
    if (!validName(name)) { flash('Nom invalide.', true); return; }
    const to = (dirOf(entry.path) ? dirOf(entry.path) + '/' : '') + name;
    try {
      await call('rename', { projectPath: S.projectPath, from: entry.path, to });
      // onglets ouverts dans ce fichier / dossier
      for (const t of S.tabs) {
        if (t.path === entry.path || t.path.startsWith(entry.path + '/')) {
          const np = to + t.path.slice(entry.path.length);
          t.path = np;
          if (t.model) { const m = monaco.editor.createModel(t.model.getValue(), langOf(np), uriOf(np)); m.setEOL(t.model.getEOL() === '\r\n' ? 1 : 0); const wasDirty = isDirty(t); t.model.dispose(); t.model = m; t.savedAlt = wasDirty ? -1 : m.getAlternativeVersionId(); }
        }
      }
      if (entry.dir) { for (const d of [...S.openDirs]) if (d === entry.path || d.startsWith(entry.path + '/')) { S.openDirs.delete(d); S.openDirs.add(to + d.slice(entry.path.length)); } }
      await refreshTree(); renderTabs(); showActive();
    } catch (err) { flash(err.message, true); }
  }
  async function deleteEntry(entry) {
    const r = await modal('Supprimer', h('p', { class: 'pjk-text' }, `« ${entry.path} » ${entry.dir ? 'et tout son contenu ' : ''}part dans la corbeille de Windows (récupérable).`), [[null, 'Annuler'], ['ok', 'Supprimer', true]]);
    if (r !== 'ok') return;
    try {
      await call('trash', { projectPath: S.projectPath, file: entry.path });
      for (let i = S.tabs.length - 1; i >= 0; i--) if (S.tabs[i].path === entry.path || S.tabs[i].path.startsWith(entry.path + '/')) closeTab(i, true);
      await refreshTree();
      flash('Envoyé à la corbeille : ' + entry.name);
    } catch (err) { flash(err.message, true); }
  }

  // ---------------------------------------------------------------------------
  // Onglets
  // ---------------------------------------------------------------------------
  const uriOf = (p) => monaco.Uri.from({ scheme: 'pj', path: '/' + p });
  const isDirty = (t) => !!(t && t.model && t.model.getAlternativeVersionId() !== t.savedAlt);
  function saveSession() {
    if (!S.projectPath) return;
    store.set('session.' + S.projectPath, { tabs: S.tabs.filter((t) => !t.preview || t === S.tabs[S.active]).map((t) => t.path), active: S.tabs[S.active] ? S.tabs[S.active].path : null, dirs: [...S.openDirs] });
  }
  const opening = new Map();
  async function openFile(path, opts = {}) {
    // deux clics rapides sur le même fichier : on attend la première ouverture
    if (opening.has(path)) { try { await opening.get(path); } catch (e) { /* rien */ } }
    if (S.tabs.some((t) => t.path === path)) return openFileInner(path, opts);
    const p = openFileInner(path, opts);
    opening.set(path, p);
    try { return await p; } finally { opening.delete(path); }
  }
  async function openFileInner(path, opts) {
    let i = S.tabs.findIndex((t) => t.path === path);
    if (i >= 0) {
      if (opts.pin) S.tabs[i].preview = false;
      activate(i);
      if (opts.line) revealPos(opts);
      return;
    }
    let info;
    try { info = await call('read', { projectPath: S.projectPath, file: path }); } catch (e) { flash(e.message, true); return; }
    const tab = { path, kind: info.kind, mtime: info.mtime, size: info.size, encoding: info.encoding, preview: !!opts.preview && !opts.pin };
    if (info.kind === 'text') {
      await loadMonaco(); monaco = window.pjMonaco;
      const old = monaco.editor.getModel(uriOf(path));
      if (old && !S.tabs.some((t) => t.model === old)) old.dispose();
      if (S.tabs.some((t) => t.path === path)) return openFileInner(path, opts);
      tab.model = monaco.editor.createModel(info.text, langOf(path), uriOf(path));
      tab.model.setEOL(/\r\n/.test(info.text.slice(0, 20000)) ? 1 : 0);
      tab.savedAlt = tab.model.getAlternativeVersionId();
      tab.model.onDidChangeContent(() => { if (tab.preview) { tab.preview = false; } updateDirty(tab); });
    } else if (info.kind === 'image') tab.dataUrl = info.dataUrl;
    else tab.reason = info.reason;
    // un seul onglet d'aperçu (italique) : remplacé par le prochain fichier ouvert d'un simple clic
    const prev = S.tabs.findIndex((t) => t.preview && !isDirty(t));
    if (tab.preview && prev >= 0) { disposeTab(S.tabs[prev]); S.tabs[prev] = tab; i = prev; } else { S.tabs.splice(S.active + 1, 0, tab); i = S.active + 1; }
    activate(i);
    if (opts.line) revealPos(opts);
  }
  function revealPos({ line, col, len }) {
    if (!editor) return;
    const sel = new monaco.Selection(line, col || 1, line, (col || 1) + (len || 0));
    editor.setSelection(sel); editor.revealRangeInCenterIfOutsideViewport(sel); editor.focus();
  }
  function disposeTab(t) { if (!t.model) return; if (editor && editor.getModel() === t.model) editor.setModel(null); t.model.dispose(); }
  function activate(i) {
    if (S.tabs[i]) addRecent(S.tabs[i].path);
    const cur = S.tabs[S.active];
    if (cur && cur.model && editor && editor.getModel() === cur.model) cur.view = editor.saveViewState();
    S.active = i;
    renderTabs(); showActive(); renderTree(); saveSession();
  }
  function updateDirty(t) {
    const was = t.wasDirty; const now = isDirty(t);
    if (was !== now) { t.wasDirty = now; renderTabs(); renderTree(); }
  }
  async function closeTab(i, force) {
    const t = S.tabs[i];
    if (!t) return;
    if (!force && isDirty(t)) {
      const r = await modal('Modifications non enregistrées', h('p', { class: 'pjk-text' }, `Enregistrer les modifications de « ${baseName(t.path)} » ?`), [[null, 'Annuler'], ['no', 'Ne pas enregistrer'], ['yes', 'Enregistrer', true]]);
      if (!r) return;
      if (r === 'yes' && !(await saveTab(t))) return;
      i = S.tabs.indexOf(t);
      if (i < 0) return;
    }
    if (editor && editor.getModel() === t.model) editor.setModel(null);
    disposeTab(t);
    S.tabs.splice(i, 1);
    if (S.active >= S.tabs.length || S.active > i) S.active--;
    if (S.active < 0 && S.tabs.length) S.active = 0;
    renderTabs(); showActive(); renderTree(); saveSession();
  }
  function renderTabs() {
    const bar = root && root.querySelector('.pjk-tabs');
    if (!bar) return;
    bar.innerHTML = '';
    S.tabs.forEach((t, i) => {
      const dirty = isDirty(t);
      const same = S.tabs.filter((o) => baseName(o.path) === baseName(t.path)).length > 1;
      bar.appendChild(h('div', {
        class: 'pjk-tab' + (i === S.active ? ' on' : '') + (t.preview ? ' preview' : '') + (dirty ? ' dirty' : ''), title: t.path, draggable: 'true',
        onmousedown: (e) => { if (e.button === 1) { e.preventDefault(); closeTab(i); } else if (e.button === 0) activate(i); },
        ondblclick: () => { t.preview = false; renderTabs(); saveSession(); },
        oncontextmenu: (e) => contextMenu(e, [['Fermer', () => closeTab(i), 'Ctrl+W'], ['Fermer les autres', () => closeOthers(t)], ['Fermer tout', () => closeAll()], '-',
          ['Afficher dans l’explorateur', () => { S.view = 'files'; renderSide(); revealInTree(t.path); }], ['Copier le chemin relatif', () => navigator.clipboard.writeText(t.path)]]),
        ondragstart: (e) => { e.dataTransfer.setData('text/pj-tab', String(i)); },
        ondragover: (e) => { if ([...e.dataTransfer.types].includes('text/pj-tab')) e.preventDefault(); },
        ondrop: (e) => { const from = Number(e.dataTransfer.getData('text/pj-tab')); if (isNaN(from) || from === i) return; const act = S.tabs[S.active]; const [m] = S.tabs.splice(from, 1); S.tabs.splice(i, 0, m); S.active = S.tabs.indexOf(act); renderTabs(); saveSession(); },
      }, badge(t.path), h('span', { class: 'pjk-tabname' }, baseName(t.path)), same ? h('span', { class: 'pjk-tabdir' }, dirOf(t.path).split('/').pop()) : null,
      h('span', { class: 'pjk-tabclose', title: 'Fermer (Ctrl+W)', onmousedown: (e) => { e.stopPropagation(); if (e.button === 0) closeTab(i); } }, h('span', { class: 'dot' }), svg(ICONS.close, 14))));
    });
    const on = bar.querySelector('.pjk-tab.on');
    if (on) on.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  }
  async function closeOthers(keep) { for (let i = S.tabs.length - 1; i >= 0; i--) if (S.tabs[i] !== keep) await closeTab(i); }
  async function closeAll() { for (let i = S.tabs.length - 1; i >= 0; i--) await closeTab(i); }
  function showActive() {
    if (!root) return;
    const t = S.tabs[S.active];
    const crumbs = root.querySelector('.pjk-crumbs');
    const other = root.querySelector('.pjk-other');
    crumbs.innerHTML = '';
    if (t) t.path.split('/').forEach((p, i, a) => { if (i) crumbs.appendChild(h('span', { class: 'sep' }, svg(ICONS.caret, 12))); crumbs.appendChild(h('span', { class: i === a.length - 1 ? 'last' : '' }, p)); });
    other.innerHTML = '';
    const banner = root.querySelector('.pjk-banner');
    banner.innerHTML = ''; banner.style.display = 'none';
    if (t && t.changedOnDisk) {
      banner.style.display = '';
      banner.append(h('span', null, 'Ce fichier a été modifié en dehors de l’éditeur.'),
        h('button', { class: 'pjs-btn small', onclick: () => reloadTab(t, true) }, 'Recharger (perdre mes modifications)'),
        h('button', { class: 'pjs-btn small', onclick: () => { t.changedOnDisk = false; t.forceSave = true; showActive(); } }, 'Garder ma version'));
    }
    if (t && t.kind === 'text') {
      editorHost.style.display = '';
      other.style.display = 'none';
      if (editor && editor.getModel() !== t.model) { editor.setModel(t.model); if (t.view) editor.restoreViewState(t.view); }
      if (editor) editor.focus();
    } else {
      editorHost.style.display = 'none';
      other.style.display = '';
      if (editor) editor.setModel(null);
      if (!t) other.appendChild(welcome());
      else if (t.kind === 'image') other.appendChild(imageView(t));
      else other.appendChild(h('div', { class: 'pjk-msg' }, h('div', { class: 'big' }, baseName(t.path)), h('div', { class: 'pjs-hint' }, t.reason || 'Ce fichier ne peut pas être affiché.'), h('div', { class: 'pjs-hint' }, fmtSize(t.size))));
    }
    renderStatus();
  }
  const fmtSize = (n) => n < 1024 ? n + ' o' : n < 1048576 ? (n / 1024).toFixed(1) + ' Ko' : (n / 1048576).toFixed(1) + ' Mo';
  function imageView(t) {
    let zoom = t.zoom || 0;
    const img = h('img', { src: t.dataUrl, draggable: 'false' });
    const wrap = h('div', { class: 'pjk-imgwrap' }, img);
    const box = h('div', { class: 'pjk-image', onwheel: (e) => { e.preventDefault(); zoom = Math.max(0.25, Math.min(32, (zoom || fitZoom()) * (e.deltaY < 0 ? 1.25 : 0.8))); t.zoom = zoom; apply(); } }, wrap);
    const fitZoom = () => { const r = box.getBoundingClientRect(); return Math.max(0.25, Math.min(8, Math.floor(Math.min((r.width - 40) / img.naturalWidth, (r.height - 40) / img.naturalHeight) * 4) / 4 || 1)); };
    const apply = () => { const z = zoom || fitZoom(); img.style.width = img.naturalWidth * z + 'px'; img.style.height = img.naturalHeight * z + 'px'; t.imgInfo = `${img.naturalWidth} × ${img.naturalHeight} px · ${Math.round(z * 100)} %`; renderStatus(); };
    img.onload = () => requestAnimationFrame(apply);
    box.addEventListener('dblclick', () => { zoom = 0; t.zoom = 0; apply(); });
    return box;
  }
  function welcome() {
    const key = (k) => h('span', { class: 'pjk-kbd' }, k);
    return h('div', { class: 'pjk-welcome' },
      h('div', { class: 'logo' }, '{ }'),
      h('div', { class: 'big' }, 'Éditeur de code'),
      h('div', { class: 'pjs-hint' }, S.ctx ? S.ctx.root : 'Aucun projet ouvert.'),
      h('div', { class: 'pjk-keys' },
        h('div', null, 'Ouvrir un fichier'), h('div', null, key('Ctrl'), key('P')),
        h('div', null, 'Rechercher dans le projet'), h('div', null, key('Ctrl'), key('Maj'), key('F')),
        h('div', null, 'Toutes les commandes'), h('div', null, key('F1')),
        h('div', null, 'Enregistrer'), h('div', null, key('Ctrl'), key('S')),
        h('div', null, 'Aller à la ligne'), h('div', null, key('Ctrl'), key('G'))));
  }

  // ---------------------------------------------------------------------------
  // Enregistrement, fichiers modifiés ailleurs
  // ---------------------------------------------------------------------------
  async function saveTab(t) {
    if (!t || !t.model) return true;
    try {
      const r = await call('write', { projectPath: S.projectPath, file: t.path, text: t.model.getValue(), encoding: t.encoding, expectedMtime: t.mtime, force: !!t.forceSave });
      if (r.conflict) {
        const c = await modal('Fichier modifié ailleurs', h('p', { class: 'pjk-text' }, `« ${baseName(t.path)} » a changé sur le disque depuis son ouverture. Écraser avec ta version ?`), [[null, 'Annuler'], ['reload', 'Recharger le disque'], ['force', 'Écraser', true]]);
        if (c === 'reload') { await reloadTab(t, true); return false; }
        if (c !== 'force') return false;
        t.forceSave = true;
        return saveTab(t);
      }
      t.mtime = r.mtime; t.forceSave = false; t.changedOnDisk = false;
      t.savedAlt = t.model.getAlternativeVersionId(); t.preview = false;
      updateDirty(t); renderTabs(); showActive();
      flash('Enregistré : ' + baseName(t.path));
      return true;
    } catch (e) { flash(e.message, true); return false; }
  }
  async function saveAll() { for (const t of S.tabs) if (isDirty(t)) await saveTab(t); }
  async function reloadTab(t, force) {
    try {
      const info = await call('read', { projectPath: S.projectPath, file: t.path });
      t.mtime = info.mtime; t.changedOnDisk = false;
      if (info.kind === 'text' && t.model) {
        if (t.model.getValue() !== info.text) t.model.pushEditOperations([], [{ range: t.model.getFullModelRange(), text: info.text }], () => null);
        t.encoding = info.encoding; t.savedAlt = t.model.getAlternativeVersionId(); updateDirty(t);
      } else if (info.kind === 'image') t.dataUrl = info.dataUrl;
      if (force) flash('Rechargé : ' + baseName(t.path));
      showActive();
    } catch (e) { flash(e.message, true); }
  }
  let checking = false;
  async function checkDisk() {
    if (checking || !root || !S.projectPath) return;
    checking = true;
    try {
      for (const t of [...S.tabs]) {
        let st;
        try { st = await call('stat', { projectPath: S.projectPath, file: t.path }); } catch (e) { continue; }
        if (!st) { if (!t.missing) { t.missing = true; flash(`« ${baseName(t.path)} » n’existe plus sur le disque.`, true); } continue; }
        t.missing = false;
        if (Math.abs(st.mtime - t.mtime) <= 1) continue;
        if (!isDirty(t)) await reloadTab(t); else if (!t.changedOnDisk && !t.forceSave) { t.changedOnDisk = true; if (t === S.tabs[S.active]) showActive(); }
      }
    } finally { checking = false; }
  }
  window.addEventListener('focus', () => checkDisk());

  // ---------------------------------------------------------------------------
  // Barre d'état
  // ---------------------------------------------------------------------------
  function renderStatus() {
    const bar = root && root.querySelector('.pjk-status');
    if (!bar) return;
    bar.innerHTML = '';
    const t = S.tabs[S.active];
    const left = h('div', { class: 'l' }, h('span', { class: 'item strong' }, '{ } ' + (S.ctx ? S.ctx.name : '—')));
    const dirtyCount = S.tabs.filter(isDirty).length;
    if (dirtyCount) left.appendChild(h('span', { class: 'item click', title: 'Tout enregistrer (Ctrl+Alt+S)', onclick: saveAll }, `● ${dirtyCount} non enregistré${dirtyCount > 1 ? 's' : ''}`));
    const right = h('div', { class: 'r' });
    if (t && t.kind === 'text' && editor && editor.getModel() === t.model) {
      const pos = editor.getPosition() || { lineNumber: 1, column: 1 };
      const sel = editor.getSelection();
      const selLen = sel && !sel.isEmpty() ? t.model.getValueInRange(sel).length : 0;
      const o = t.model.getOptions();
      right.append(
        h('span', { class: 'item click', title: 'Aller à la ligne (Ctrl+G)', onclick: () => { editor.focus(); editor.trigger('pj', 'editor.action.gotoLine'); } }, `Ln ${pos.lineNumber}, Col ${pos.column}` + (selLen ? ` (${selLen} sélectionné${selLen > 1 ? 's' : ''})` : '')),
        h('span', { class: 'item click', title: 'Indentation', onclick: (e) => contextMenu(e, [[o.insertSpaces ? '✓ Espaces' : 'Espaces', () => { t.model.updateOptions({ insertSpaces: true }); renderStatus(); }], [!o.insertSpaces ? '✓ Tabulations' : 'Tabulations', () => { t.model.updateOptions({ insertSpaces: false }); renderStatus(); }], '-', ...[2, 4, 8].map((n) => [(o.tabSize === n ? '✓ ' : '') + 'Taille ' + n, () => { t.model.updateOptions({ tabSize: n }); renderStatus(); }])]) }, (o.insertSpaces ? 'Espaces : ' : 'Tabulations : ') + o.tabSize),
        h('span', { class: 'item click', title: 'Encodage à l’enregistrement', onclick: (e) => contextMenu(e, [['UTF-8', () => { t.encoding = 'utf8'; t.savedAlt = -1; updateDirty(t); renderStatus(); }], ['UTF-8 avec BOM', () => { t.encoding = 'utf8bom'; t.savedAlt = -1; updateDirty(t); renderStatus(); }]]) }, t.encoding === 'utf8bom' ? 'UTF-8 avec BOM' : t.encoding === 'utf16le' ? 'UTF-16 LE' : 'UTF-8'),
        h('span', { class: 'item click', title: 'Fins de ligne', onclick: () => { t.model.pushEOL(t.model.getEOL() === '\r\n' ? 0 : 1); updateDirty(t); renderStatus(); } }, t.model.getEOL() === '\r\n' ? 'CRLF' : 'LF'),
        h('span', { class: 'item click', title: 'Langage', onclick: (e) => contextMenu(e, Object.entries(LANG_LABEL).map(([id, label]) => [(t.model.getLanguageId() === id ? '✓ ' : '') + label, () => { monaco.editor.setModelLanguage(t.model, id); renderStatus(); }])) }, LANG_LABEL[t.model.getLanguageId()] || t.model.getLanguageId()),
      );
    } else if (t && t.kind === 'image') right.append(h('span', { class: 'item' }, t.imgInfo || ''), h('span', { class: 'item' }, fmtSize(t.size)));
    right.appendChild(h('span', { class: 'item click', title: 'Retour à la ligne automatique (Alt+Z)', onclick: toggleWrap }, store.get('wordWrap', 'off') === 'on' ? 'Retour à la ligne ✓' : 'Retour à la ligne'));
    right.appendChild(h('span', { class: 'item click', title: 'Minicarte', onclick: toggleMinimap }, store.get('minimap', true) ? 'Minicarte ✓' : 'Minicarte'));
    bar.append(left, right);
  }
  function toggleWrap() { const v = store.get('wordWrap', 'off') === 'on' ? 'off' : 'on'; store.set('wordWrap', v); if (editor) editor.updateOptions({ wordWrap: v }); renderStatus(); }
  function toggleMinimap() { const v = !store.get('minimap', true); store.set('minimap', v); if (editor) editor.updateOptions({ minimap: { enabled: v } }); renderStatus(); }

  // ---------------------------------------------------------------------------
  // Ouvrir un fichier (Ctrl+P)
  // ---------------------------------------------------------------------------
  function fuzzy(q, s) {
    // sous-séquence ; score : texte tel quel, lettres consécutives, début de mot, nom de fichier
    const ql = q.toLowerCase().replace(/\s+/g, ''); const sl = s.toLowerCase();
    const nameStart = sl.lastIndexOf('/') + 1;
    const exact = sl.lastIndexOf(ql);
    if (exact >= 0) return { score: 1000 + (exact >= nameStart ? 500 : 0) + (exact === nameStart ? 200 : 0) - s.length, hits: [...Array(ql.length)].map((_, k) => exact + k) };
    // d'abord dans le nom du fichier seul
    const inName = fuzzyFrom(ql, sl, nameStart, nameStart);
    if (inName) { inName.score += 300; return inName; }
    return fuzzyFrom(ql, sl, 0, nameStart);
  }
  function fuzzyFrom(ql, sl, from, nameStart) {
    let si = from; let score = 0; let prev = -2; const hits = [];
    for (const c of ql) {
      if (c === ' ') continue;
      const j = sl.indexOf(c, si);
      if (j < 0) return null;
      score += j === prev + 1 ? 5 : 1;
      if (j === nameStart || '/_-. '.includes(sl[j - 1] || '/')) score += 3;
      if (j >= nameStart) score += 2;
      hits.push(j); prev = j; si = j + 1;
    }
    return { score: score - sl.length * 0.01, hits };
  }
  function hl(text, hits, offset = 0) {
    const frag = document.createDocumentFragment();
    let last = 0;
    const set = new Set(hits.map((x) => x - offset).filter((x) => x >= 0 && x < text.length));
    for (let i = 0; i < text.length; i++) if (set.has(i)) { if (i > last) frag.append(text.slice(last, i)); frag.append(h('b', null, text[i])); last = i + 1; }
    if (last < text.length) frag.append(text.slice(last));
    return frag;
  }
  async function quickOpen(prefix = '') {
    if (!S.projectPath || root.querySelector('.pjk-quick')) return;
    const input = h('input', { class: 'pjk-qinput', placeholder: 'Nom du fichier · « : » ligne · « > » commandes', value: prefix });
    const list = h('div', { class: 'pjk-qlist' });
    const box = h('div', { class: 'pjk-quick' }, input, list);
    const close = () => { box.remove(); document.removeEventListener('mousedown', outside, true); if (editor && S.tabs[S.active] && S.tabs[S.active].kind === 'text') editor.focus(); };
    const outside = (e) => { if (!box.contains(e.target)) close(); };
    root.querySelector('.pjk-main').appendChild(box);
    document.addEventListener('mousedown', outside, true);
    input.focus(); input.setSelectionRange(input.value.length, input.value.length);
    if (!S.index) { list.appendChild(h('div', { class: 'pjs-hint pjk-qempty' }, 'Lecture des fichiers…')); try { S.index = await call('index', { projectPath: S.projectPath }); } catch (e) { S.index = []; flash(e.message, true); } }
    let items = []; let cur = 0;
    const recent = store.get('recent.' + S.projectPath, []);
    const pick = (i) => { const it = items[i]; if (!it) return; close(); it.run(); };
    const update = () => {
      const q = input.value;
      list.innerHTML = '';
      items = [];
      if (q.startsWith('>')) {
        close();
        if (editor) { editor.focus(); editor.trigger('pj', 'editor.action.quickCommand'); }
        return;
      }
      if (q.startsWith(':')) {
        const n = parseInt(q.slice(1), 10);
        items.push({ label: isNaN(n) ? 'Tape un numéro de ligne' : 'Aller à la ligne ' + n, run: () => { if (!isNaN(n) && editor && editor.getModel()) revealPos({ line: Math.max(1, Math.min(n, editor.getModel().getLineCount())), col: 1 }); } });
      } else if (!q.trim()) {
        const seen = new Set();
        [...recent, ...S.tabs.map((t) => t.path)].forEach((p) => { if (!seen.has(p) && S.index.includes(p)) { seen.add(p); items.push({ path: p, hits: [], run: () => openFile(p, { pin: true }) }); } });
        if (!items.length) S.index.slice(0, 50).forEach((p) => items.push({ path: p, hits: [], run: () => openFile(p, { pin: true }) }));
      } else {
        const scored = [];
        for (const p of S.index) { const r = fuzzy(q, p); if (r) scored.push([r.score, p, r.hits]); }
        scored.sort((a, b) => b[0] - a[0]);
        scored.slice(0, 60).forEach(([, p, hits]) => items.push({ path: p, hits, run: () => openFile(p, { pin: true }) }));
      }
      cur = Math.min(cur, Math.max(0, items.length - 1));
      items.forEach((it, i) => {
        const nameStart = it.path ? it.path.lastIndexOf('/') + 1 : 0;
        list.appendChild(h('div', { class: 'pjk-qitem' + (i === cur ? ' on' : ''), onmousedown: (e) => { e.preventDefault(); pick(i); }, onmousemove: () => { if (cur !== i) { cur = i; update(); } } },
          it.path ? [badge(it.path), h('span', { class: 'n' }, hl(it.path.slice(nameStart), it.hits, nameStart)), h('span', { class: 'd' }, hl(dirOf(it.path), it.hits, 0))] : h('span', { class: 'n' }, it.label)));
      });
      if (!items.length) list.appendChild(h('div', { class: 'pjs-hint pjk-qempty' }, 'Aucun fichier.'));
      const on = list.querySelector('.on'); if (on) on.scrollIntoView({ block: 'nearest' });
    };
    input.addEventListener('input', () => { cur = 0; update(); });
    input.addEventListener('keydown', (e) => {
      e.stopPropagation();
      if (e.key === 'Escape') close();
      else if (e.key === 'ArrowDown') { e.preventDefault(); cur = Math.min(items.length - 1, cur + 1); update(); } else if (e.key === 'ArrowUp') { e.preventDefault(); cur = Math.max(0, cur - 1); update(); } else if (e.key === 'Enter') { e.preventDefault(); pick(cur); }
    });
    update();
  }
  function addRecent(p) {
    const k = 'recent.' + S.projectPath;
    store.set(k, [p, ...store.get(k, []).filter((x) => x !== p)].slice(0, 20));
  }

  // ---------------------------------------------------------------------------
  // Recherche dans le projet (Ctrl+Maj+F)
  // ---------------------------------------------------------------------------
  async function runSearch() {
    const q = S.search;
    if (!q.query) { q.result = null; renderSearchResults(); return; }
    if (q.regex) { try { new RegExp(q.query); } catch (e) { q.result = { error: 'Expression invalide : ' + e.message }; renderSearchResults(); return; } }
    q.busy = true; renderSearchResults();
    const token = (runSearch.token = (runSearch.token || 0) + 1);
    try {
      const r = await call('search', { projectPath: S.projectPath, query: q.query, regex: q.regex, caseSensitive: q.caseSensitive, word: q.word, include: q.include, exclude: q.exclude });
      if (token !== runSearch.token) return;
      // fichiers ouverts et modifiés : leurs lignes viennent de l'éditeur
      q.result = r;
    } catch (e) { q.result = { error: e.message }; } finally { if (token === runSearch.token) { q.busy = false; renderSearchResults(); } }
  }
  function searchRegex() {
    const q = S.search;
    let src = q.regex ? q.query : q.query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    if (q.word) src = '\\b' + src + '\\b';
    return new RegExp(src, q.caseSensitive ? 'g' : 'gi');
  }
  async function replaceAll(onlyFile) {
    const q = S.search;
    if (!q.result || !q.result.results) return;
    const files = q.result.results.filter((r) => !onlyFile || r.file === onlyFile);
    const n = files.reduce((a, f) => a + f.hits.length, 0);
    if (!n) return;
    const ok = await modal('Remplacer', h('p', { class: 'pjk-text' }, `Remplacer ${n} occurrence${n > 1 ? 's' : ''} dans ${files.length} fichier${files.length > 1 ? 's' : ''} par « ${q.replace} » ? Les fichiers ouverts restent à enregistrer (Ctrl+Z possible) ; les autres sont enregistrés tout de suite.`), [[null, 'Annuler'], ['ok', 'Remplacer', true]]);
    if (ok !== 'ok') return;
    const re = searchRegex(); let done = 0;
    for (const f of files) {
      const t = S.tabs.find((x) => x.path === f.file && x.model);
      try {
        if (t) {
          const matches = t.model.findMatches(q.regex ? q.query : q.query, false, q.regex, q.caseSensitive, q.word ? '`~!@#$%^&*()-=+[{]}\\|;:\'",.<>/?' : null, true);
          t.model.pushEditOperations([], matches.map((m) => ({ range: m.range, text: q.regex ? (m.matches ? m.matches[0].replace(new RegExp(re.source, re.flags.replace('g', '')), q.replace) : q.replace) : q.replace })), () => null);
          done += matches.length;
        } else {
          const info = await call('read', { projectPath: S.projectPath, file: f.file });
          if (info.kind !== 'text') continue;
          const text = info.text.replace(re, q.replace);
          if (text !== info.text) { await call('write', { projectPath: S.projectPath, file: f.file, text, encoding: info.encoding, expectedMtime: info.mtime }); done += f.hits.length; }
        }
      } catch (e) { flash(f.file + ' : ' + e.message, true); }
    }
    flash(`${done} remplacement${done > 1 ? 's' : ''}.`);
    runSearch();
  }
  function renderSearchResults() {
    const box = root && root.querySelector('.pjk-sresults');
    if (!box) return;
    box.innerHTML = '';
    const q = S.search; const r = q.result;
    if (q.busy) box.appendChild(h('div', { class: 'pjs-hint pjk-empty' }, 'Recherche…'));
    if (!r) return;
    if (r.error) { box.appendChild(h('div', { class: 'pjk-empty error' }, r.error)); return; }
    if (!q.busy) box.appendChild(h('div', { class: 'pjs-hint pjk-scount' }, r.count ? `${r.count} résultat${r.count > 1 ? 's' : ''} dans ${r.results.length} fichier${r.results.length > 1 ? 's' : ''}` + (r.truncated ? ' (limite atteinte, affine la recherche)' : '') : 'Aucun résultat.'));
    for (const f of r.results) {
      const closed = q.collapsed.has(f.file);
      box.appendChild(h('div', { class: 'pjk-row sfile', title: f.file, onclick: () => { if (closed) q.collapsed.delete(f.file); else q.collapsed.add(f.file); renderSearchResults(); } },
        h('span', { class: 'pjk-caret' + (closed ? '' : ' open') }, svg(ICONS.caret, 14)), badge(f.file), h('span', { class: 'pjk-name' }, baseName(f.file)), h('span', { class: 'pjk-sdir' }, dirOf(f.file)),
        q.replace !== '' || q.showReplace ? h('span', { class: 'pjk-sbtn', title: 'Remplacer dans ce fichier', onclick: (e) => { e.stopPropagation(); replaceAll(f.file); } }, svg(ICONS.replaceAll, 14)) : null,
        h('span', { class: 'pjk-count' }, f.hits.length)));
      if (closed) continue;
      for (const m of f.hits) {
        const s = m.col - 1 - m.off; const text = m.text;
        const lead = Math.max(0, s - 40);
        const pre = (lead ? '…' : '') + text.slice(lead, s).replace(/^\s+/, '');
        const showRep = S.search.showReplace;
        box.appendChild(h('div', { class: 'pjk-row shit', title: `${f.file}:${m.line}`, onclick: () => openFile(f.file, { pin: false, preview: true, line: m.line, col: m.col, len: m.len }), ondblclick: () => openFile(f.file, { pin: true, line: m.line, col: m.col, len: m.len }) },
          h('span', { class: 'pjk-sline' }, pre, h('mark', { class: showRep ? 'del' : '' }, text.slice(s, s + m.len)), showRep ? h('mark', { class: 'ins' }, q.replace) : null, text.slice(s + m.len, s + m.len + 200)),
          h('span', { class: 'pjk-lnum' }, m.line)));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Mise en page
  // ---------------------------------------------------------------------------
  function renderSide() {
    const side = root && root.querySelector('.pjk-side');
    if (!side) return;
    store.set('view', S.view);
    root.querySelectorAll('.pjk-act').forEach((b) => b.classList.toggle('on', b.dataset.view === S.view));
    side.innerHTML = '';
    if (S.view === 'files') {
      side.append(h('div', { class: 'pjk-sidehead' }, h('span', null, 'Explorateur'),
        h('div', { class: 'pjk-sidebtns' },
          h('button', { class: 'pjk-ibtn', title: 'Nouveau fichier', onclick: () => newEntry(selDir(), false) }, svg(ICONS.newFile)),
          h('button', { class: 'pjk-ibtn', title: 'Nouveau dossier', onclick: () => newEntry(selDir(), true) }, svg(ICONS.newDir)),
          h('button', { class: 'pjk-ibtn', title: 'Actualiser', onclick: () => refreshTree() }, svg(ICONS.refresh)),
          h('button', { class: 'pjk-ibtn', title: 'Tout replier', onclick: () => { S.openDirs.clear(); saveSession(); renderTree(); } }, svg(ICONS.collapse)))),
      h('div', { class: 'pjk-project' }, S.ctx ? S.ctx.name : '—'),
      h('div', { class: 'pjk-tree', tabindex: '0', oncontextmenu: (e) => { if (e.target.classList.contains('pjk-tree')) fileMenu(e, null); }, onkeydown: treeKey }));
      renderTree();
    } else {
      const q = S.search;
      const opt = (key, label, title) => h('button', { class: 'pjk-opt' + (q[key] ? ' on' : ''), title, onclick: (e) => { q[key] = !q[key]; e.currentTarget.classList.toggle('on', q[key]); runSearch(); } }, label);
      let timer = null;
      const later = () => { clearTimeout(timer); timer = setTimeout(runSearch, 300); };
      const input = h('input', { class: 'pjs-input pjk-sinput', placeholder: 'Rechercher', value: q.query, oninput: (e) => { q.query = e.target.value; later(); }, onkeydown: (e) => { if (e.key === 'Enter') runSearch(); } });
      const rep = h('input', { class: 'pjs-input pjk-sinput', placeholder: 'Remplacer', value: q.replace, oninput: (e) => { q.replace = e.target.value; renderSearchResults(); }, onkeydown: (e) => { if (e.key === 'Enter' && e.ctrlKey && e.altKey) replaceAll(); } });
      side.append(h('div', { class: 'pjk-sidehead' }, h('span', null, 'Rechercher'),
        h('div', { class: 'pjk-sidebtns' }, h('button', { class: 'pjk-ibtn', title: 'Relancer', onclick: runSearch }, svg(ICONS.refresh)))),
      h('div', { class: 'pjk-sform' },
        h('div', { class: 'pjk-srow' }, h('button', { class: 'pjk-toggle-rep' + (q.showReplace ? ' open' : ''), title: 'Remplacer', onclick: () => { q.showReplace = !q.showReplace; renderSide(); } }, svg(ICONS.caret, 14)),
          h('div', { class: 'pjk-sfield' }, input, h('div', { class: 'pjk-opts' }, opt('caseSensitive', 'Aa', 'Respecter la casse'), opt('word', 'ab', 'Mot entier'), opt('regex', '.*', 'Expression régulière')))),
        q.showReplace ? h('div', { class: 'pjk-srow' }, h('span', { class: 'pjk-spacer' }), h('div', { class: 'pjk-sfield' }, rep, h('div', { class: 'pjk-opts' }, h('button', { class: 'pjk-opt', title: 'Tout remplacer (Ctrl+Alt+Entrée)', onclick: () => replaceAll() }, svg(ICONS.replaceAll, 14))))) : null,
        h('label', { class: 'pjk-slabel' }, 'Fichiers à inclure', h('input', { class: 'pjs-input', placeholder: 'ex. scripts/**, *.rb', value: q.include, oninput: (e) => { q.include = e.target.value; later(); } })),
        h('label', { class: 'pjk-slabel' }, 'Fichiers à exclure', h('input', { class: 'pjs-input', placeholder: 'ex. Data/**, *.json', value: q.exclude, oninput: (e) => { q.exclude = e.target.value; later(); } }))),
      h('div', { class: 'pjk-sresults' }));
      renderSearchResults();
      setTimeout(() => { input.focus(); input.select(); }, 0);
    }
  }
  function selDir() {
    if (!S.sel) return '';
    const isDir = [...S.dirs.values()].some((l) => l.some((e) => e.path === S.sel && e.dir));
    return isDir ? S.sel : dirOf(S.sel);
  }
  function treeKey(e) {
    if (!S.sel) return;
    const entry = [...S.dirs.values()].flat().find((x) => x.path === S.sel);
    if (!entry) return;
    if (e.key === 'F2') { e.preventDefault(); renameEntry(entry); } else if (e.key === 'Delete') { e.preventDefault(); deleteEntry(entry); } else if (e.key === 'Enter') { e.preventDefault(); if (entry.dir) toggleDir(entry.path); else openFile(entry.path, { pin: true }); }
  }
  function onKey(e) {
    const ctrl = e.ctrlKey || e.metaKey; const k = e.key.toLowerCase();
    if (ctrl && !e.shiftKey && k === 'p') { e.preventDefault(); quickOpen(); } else if (ctrl && k === 's' && e.altKey) { e.preventDefault(); saveAll(); } else if (ctrl && !e.shiftKey && k === 's') { e.preventDefault(); saveTab(S.tabs[S.active]); } else if (ctrl && e.shiftKey && k === 'f') { e.preventDefault(); S.view = 'search'; renderSide(); } else if (ctrl && e.shiftKey && k === 'e') { e.preventDefault(); S.view = 'files'; renderSide(); if (S.tabs[S.active]) revealInTree(S.tabs[S.active].path); } else if (ctrl && k === 'w') { e.preventDefault(); if (S.active >= 0) closeTab(S.active); } else if (ctrl && k === 'tab') { e.preventDefault(); if (S.tabs.length) activate((S.active + (e.shiftKey ? S.tabs.length - 1 : 1)) % S.tabs.length); } else if (e.altKey && k === 'z') { e.preventDefault(); toggleWrap(); } else if (ctrl && k === 'b') { e.preventDefault(); root.classList.toggle('noside'); } else if (ctrl && k === 'g' && !(S.tabs[S.active] && S.tabs[S.active].kind === 'text')) { e.preventDefault(); } else if (k === 'f1' && editor && editor.getModel()) { e.preventDefault(); editor.focus(); editor.trigger('pj', 'editor.action.quickCommand'); }
  }
  function render() {
    root.innerHTML = '';
    editorHost = h('div', { class: 'pjk-editor' });
    const splitter = h('div', { class: 'pjk-split', onmousedown: (e) => {
      e.preventDefault();
      const start = e.clientX; const w0 = S.sideW;
      const move = (ev) => { S.sideW = Math.max(170, Math.min(600, w0 + ev.clientX - start)); root.style.setProperty('--pjk-side', S.sideW + 'px'); };
      const up = () => { document.removeEventListener('mousemove', move); document.removeEventListener('mouseup', up); store.set('sideW', S.sideW); };
      document.addEventListener('mousemove', move); document.addEventListener('mouseup', up);
    } });
    root.style.setProperty('--pjk-side', S.sideW + 'px');
    root.append(
      h('div', { class: 'pjk-body' },
        h('div', { class: 'pjk-activity' },
          h('button', { class: 'pjk-act', 'data-view': 'files', title: 'Explorateur (Ctrl+Maj+E)', onclick: () => { if (S.view === 'files' && !root.classList.contains('noside')) root.classList.add('noside'); else { root.classList.remove('noside'); S.view = 'files'; renderSide(); } } }, svg(ICONS.files, 22)),
          h('button', { class: 'pjk-act', 'data-view': 'search', title: 'Rechercher (Ctrl+Maj+F)', onclick: () => { if (S.view === 'search' && !root.classList.contains('noside')) root.classList.add('noside'); else { root.classList.remove('noside'); S.view = 'search'; renderSide(); } } }, svg(ICONS.search, 22))),
        h('div', { class: 'pjk-side' }), splitter,
        h('div', { class: 'pjk-main' },
          h('div', { class: 'pjk-tabbar' }, h('div', { class: 'pjk-tabs', onwheel: (e) => { e.currentTarget.scrollLeft += e.deltaY; } }),
            h('div', { class: 'pjk-tabtools' },
              h('button', { class: 'pjk-ibtn', title: 'Ouvrir un fichier (Ctrl+P)', onclick: () => quickOpen() }, svg(ICONS.search)),
              h('button', { class: 'pjk-ibtn', title: 'Enregistrer (Ctrl+S)', onclick: () => saveTab(S.tabs[S.active]) }, svg(ICONS.save)))),
          h('div', { class: 'pjk-crumbs' }), h('div', { class: 'pjk-banner' }),
          h('div', { class: 'pjk-content' }, editorHost, h('div', { class: 'pjk-other' })))),
      h('div', { class: 'pjk-status' }), h('div', { class: 'pjk-flash' }));
    renderSide(); renderTabs(); showActive();
  }
  function createEditor() {
    if (!monaco || !editorHost) return;
    editorDisposables.forEach((d) => d.dispose()); editorDisposables = [];
    if (editor) { editor.dispose(); editor = null; }
    editor = monaco.editor.create(editorHost, { ...EDITOR_OPTIONS(), model: null });
    editorDisposables.push(
      editor.onDidChangeCursorSelection(() => renderStatusSoon()),
      editor.onDidChangeModel(() => renderStatusSoon()),
      editor.onDidChangeConfiguration(() => { const fs = editor.getOption(monaco.editor.EditorOption.fontSize); if (fs && fs !== store.get('fontSize', 14)) store.set('fontSize', fs); }),
    );
    // raccourcis pris par l'éditeur avant ceux de Monaco
    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyS, () => saveTab(S.tabs[S.active]));
    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyP, () => quickOpen());
    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyMod.Shift | monaco.KeyCode.KeyF, () => { const sel = editor.getModel() && editor.getModel().getValueInRange(editor.getSelection()); if (sel && !sel.includes('\n')) S.search.query = sel; S.view = 'search'; root.classList.remove('noside'); renderSide(); if (sel) runSearch(); });
    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyW, () => { if (S.active >= 0) closeTab(S.active); });
    editor.addCommand(monaco.KeyMod.Alt | monaco.KeyCode.KeyZ, toggleWrap);
    showActive();
  }
  let statusPending = false;
  const renderStatusSoon = () => { if (statusPending) return; statusPending = true; requestAnimationFrame(() => { statusPending = false; renderStatus(); }); };

  async function restoreSession() {
    const sess = store.get('session.' + S.projectPath, null);
    if (!sess) return;
    (sess.dirs || []).forEach((d) => S.openDirs.add(d));
    for (const d of S.openDirs) { try { await loadDir(d); } catch (e) { S.openDirs.delete(d); } }
    renderTree();
    for (const p of sess.tabs || []) { try { await openFile(p, { pin: true }); } catch (e) { /* fichier disparu */ } }
    const i = S.tabs.findIndex((t) => t.path === sess.active);
    if (i >= 0) activate(i);
  }
  async function mount(hostEl) {
    root = h('div', { id: 'pjk-root' });
    root.addEventListener('keydown', (e) => { if (!e.defaultPrevented) onKey(e); e.stopPropagation(); });
    ['keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    const proj = currentProject();
    if (proj !== S.projectPath) {
      // autre projet : on repart de zéro
      S.tabs.forEach(disposeTab); S.tabs = []; S.active = -1; S.dirs.clear(); S.openDirs.clear(); S.index = null; S.sel = null; S.restored = false;
      S.projectPath = proj;
      try { S.ctx = proj ? await call('getContext', { projectPath: proj }) : null; } catch (e) { S.ctx = null; }
    }
    render();
    if (S.projectPath && !S.dirs.has('')) { try { await loadDir(''); } catch (e) { flash(e.message, true); } renderTree(); }
    try { monaco = await loadMonaco(); } catch (e) { flash(e.message, true); return; }
    if (!root) return;
    createEditor();
    if (!S.restored && S.projectPath) { S.restored = true; await restoreSession(); }
    checkDisk();
  }

  function checkPage() {
    const hostEl = document.getElementById('pj-page-' + PAGE_ID);
    if (root && hostEl && hostEl.contains(root)) return;
    if (root) {
      const cur = S.tabs[S.active];
      if (cur && editor && cur.model && editor.getModel() === cur.model) cur.view = editor.saveViewState();
      editorDisposables.forEach((d) => d.dispose()); editorDisposables = [];
      if (editor) { editor.setModel(null); editor.dispose(); editor = null; }
      root = null; editorHost = null;
    }
    if (hostEl) mount(hostEl);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const begin = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) begin(); else document.addEventListener('DOMContentLoaded', begin);
  setInterval(() => { if (root && document.hasFocus()) checkDisk(); }, 4000);
  // raccourcis quand rien n'a le focus dans la page (Ctrl+P, Ctrl+Maj+F…)
  document.addEventListener('keydown', (e) => {
    if (!root || !root.isConnected || root.contains(e.target) || document.querySelector('.pjk-overlay')) return;
    if (e.target && e.target !== document.body && e.target.closest && !e.target.closest('#pj-page-code')) return;
    onKey(e);
    if (e.defaultPrevented) e.stopPropagation();
  }, true);

  // Monaco annule ses tâches en cours quand on change de fichier : ce n'est pas une erreur
  window.addEventListener('unhandledrejection', (e) => { if (e.reason && (e.reason.name === 'Canceled' || e.reason.message === 'Canceled')) e.preventDefault(); });
  window.pjCodeEditor = { state: S, openFile: (p, o) => openFile(p, o), saveAll };
})();

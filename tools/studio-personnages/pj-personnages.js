/* eslint-disable */
// =============================================================================
// Personnages — pages « Données > Personnages > Héros / Alliés » de Pokémon Studio Extra (plugin « personnages »)
//   Héros  : nom par défaut, garçon / fille, personnage de la carte, dresseur de dos, image de l'écran de choix,
//            héros du début de partie, demander le nom au joueur
//   Alliés : dresseur de Studio dont l'équipe combat au côté du héros (combat double), personnage qui suit le héros
// Enregistre Data/configs/plugins/personnages.json. Style de l'éditeur Smartphone (classes pjs-*).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjPersonnagesLoaded) return;
  window.__pjPersonnagesLoaded = true;

  const PAGES = { heros: 'Héros', allies: 'Alliés' };
  const DEFAULTS = () => ({ klass: 'PersonnagesConfig', heroes: [], default_hero: null, ask_name: true, name_max_length: 12, allies: [] });
  const GENERATOR = '__generator__';

  const api = window.pjPersonnages;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API Personnages n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  const currentProject = () => (projectList()[0] && projectList()[0].projectPath) || null;

  const S = { projectPath: null, ctx: null, config: null, saved: null, error: null, open: null };
  let root = null;
  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => !!S.config && snapshot() !== S.saved;

  function toast(msg, err) {
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    setTimeout(() => t.remove(), err ? 5000 : 2500);
  }

  // ---------------------------------------------------------------------------
  // Images (graphics/characters, graphics/battlers)
  // ---------------------------------------------------------------------------
  const images = new Map();
  function image(file) {
    if (!images.has(file)) images.set(file, call('readImage', { projectPath: S.projectPath, file }).catch(() => null));
    return images.get(file);
  }
  // première image d'un charset 4 × 4 (vers le bas), agrandie
  function charsetPreview(file, scale = 2) {
    const c = h('canvas', { class: 'pjp-charset', width: 1, height: 1 });
    if (!file) { c.classList.add('none'); return c; }
    image('graphics/characters/' + file).then((url) => {
      if (!url) { c.classList.add('none'); c.title = 'Image introuvable : graphics/characters/' + file + '.png'; return; }
      const img = new Image();
      img.onload = () => {
        const fw = Math.floor(img.width / 4); const fh = Math.floor(img.height / 4);
        c.width = fw * scale; c.height = fh * scale;
        const g = c.getContext('2d'); g.imageSmoothingEnabled = false;
        g.drawImage(img, 0, 0, fw, fh, 0, 0, fw * scale, fh * scale);
      };
      img.src = url;
    });
    return c;
  }
  function battlerPreview(file, label) {
    const box = h('div', { class: 'pjp-battler' + (file ? '' : ' none') }, h('span', { class: 'pjp-cap' }, label));
    if (!file) return box;
    image('graphics/battlers/' + file).then((url) => {
      if (!url) { box.classList.add('none'); box.title = 'Image introuvable : graphics/battlers/' + file + '.png'; return; }
      const img = h('img', { src: url, draggable: 'false' });
      // dresseurs de dos de PSDK : plusieurs images les unes sous les autres
      img.onload = () => { if (img.naturalHeight > img.naturalWidth * 1.5) { const n = Math.round(img.naturalHeight / img.naturalWidth); box.style.setProperty('--frames', n); box.classList.add('strip'); } };
      box.prepend(img);
    });
    return box;
  }


  // ---------------------------------------------------------------------------
  // Sélecteur d'image (fenêtre avec vignettes, recherche, dossiers)
  // ---------------------------------------------------------------------------
  const KINDS = {
    battlers: { dir: 'graphics/battlers', title: 'Image de graphics/battlers', list: () => S.ctx.battlers,
      cats: [['all', 'Toutes'], ['big', 'Grandes (_big)', (f) => /_big$/i.test(f)], ['sma', 'Petites (_sma)', (f) => /_sma$/i.test(f)], ['other', 'Autres', (f) => !/_(big|sma)$/i.test(f)]] },
    characters: { dir: 'graphics/characters', title: 'Personnage de graphics/characters', list: () => S.ctx.characters,
      cats: [['people', 'Personnages', (f) => !/^\d/.test(f.split('/').pop())], ['pokemon', 'Pokémon', (f) => /^\d/.test(f.split('/').pop())], ['all', 'Tous']] },
  };
  // vignette : 1re image d'un charset (4 × 4) ou d'une bande de dresseur de dos, sinon l'image entière
  function thumb(kind, file, size) {
    const c = h('canvas', { class: 'pjp-thumb', width: size, height: size });
    if (!file) return c;
    image(KINDS[kind].dir + '/' + file).then((url) => {
      if (!url) { c.classList.add('missing'); c.title = 'Image introuvable'; return; }
      const img = new Image();
      img.onload = () => {
        let sw = img.width; let sh = img.height;
        if (kind === 'characters') { sw = Math.floor(img.width / 4); sh = Math.floor(img.height / 4); } else if (img.height > img.width * 1.5) sh = img.width;
        const z = Math.min(size / sw, size / sh); const k = z >= 1 ? Math.floor(z) : z;
        const w = sw * k; const hh = sh * k;
        const g = c.getContext('2d'); g.imageSmoothingEnabled = k < 1;
        g.clearRect(0, 0, size, size);
        g.drawImage(img, 0, 0, sw, sh, (size - w) / 2, size - hh, w, hh);
      };
      img.src = url;
    });
    return c;
  }
  function openPicker(kind, current, emptyLabel, onPick) {
    const K = KINDS[kind];
    const all = K.list();
    const folders = ['', ...new Set(all.filter((f) => f.includes('/')).map((f) => f.slice(0, f.lastIndexOf('/'))))];
    const isPokemonName = (f) => /^\d/.test(String(f || '').split('/').pop());
    const st = { cat: kind === 'characters' && current && isPokemonName(current) ? 'pokemon' : K.cats[0][0], q: '', folder: (current && current.includes('/')) ? current.slice(0, current.lastIndexOf('/')) : '', shown: 0, items: [] };
    const close = (v) => { ov.remove(); document.removeEventListener('keydown', onKey, true); if (v !== undefined) onPick(v); };
    const onKey = (e) => { if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); close(); } else if (e.key === 'Enter' && st.items[0] !== undefined && document.activeElement === search) { e.preventDefault(); e.stopPropagation(); close(st.items[0]); } };
    const grid = h('div', { class: 'pjp-pgrid' });
    const count = h('span', { class: 'pjs-hint' });
    const io = new IntersectionObserver((entries) => entries.forEach((en) => { if (en.isIntersecting) { io.unobserve(en.target); en.target.replaceWith(thumb(kind, en.target.dataset.file, 88)); } }), { root: grid, rootMargin: '200px' });
    const tile = (file) => {
      const ph = h('div', { class: 'pjp-thumb ph', 'data-file': file });
      const t = h('button', { class: 'pjp-tile' + (file === current ? ' on' : ''), title: file, onclick: () => close(file) }, ph, h('span', { class: 'n' }, file.split('/').pop()));
      io.observe(ph);
      return t;
    };
    const more = () => {
      const next = st.items.slice(st.shown, st.shown + 120);
      next.forEach((f) => grid.insertBefore(tile(f), sentinel));
      st.shown += next.length;
      sentinel.style.display = st.shown < st.items.length ? '' : 'none';
    };
    const sentinel = h('div', { class: 'pjp-more' }, 'Afficher plus…');
    new IntersectionObserver((en) => { if (en[0].isIntersecting) more(); }, { root: grid, rootMargin: '300px' }).observe(sentinel);
    const update = () => {
      const words = st.q.toLowerCase().split(/\s+/).filter(Boolean);
      const cat = (K.cats.find((c) => c[0] === st.cat) || [])[2];
      st.items = all.filter((f) => {
        if (cat && !cat(f)) return false;
        const dir = f.includes('/') ? f.slice(0, f.lastIndexOf('/')) : '';
        if (st.folder !== '*' && dir !== st.folder && !(st.q && st.folder === '')) return false;
        const lf = f.toLowerCase();
        return words.every((w) => lf.includes(w));
      });
      grid.textContent = '';
      if (emptyLabel && !st.q) grid.appendChild(h('button', { class: 'pjp-tile none' + (!current ? ' on' : ''), onclick: () => close('') }, h('div', { class: 'pjp-thumb ph' }, '∅'), h('span', { class: 'n' }, emptyLabel)));
      grid.appendChild(sentinel);
      st.shown = 0; more();
      count.textContent = `${st.items.length} image${st.items.length > 1 ? 's' : ''}`;
      folderRow.querySelectorAll('.pjp-chip').forEach((b) => b.classList.toggle('on', b.dataset.f === st.folder));
      catRow.querySelectorAll('.pjp-chip').forEach((b) => b.classList.toggle('on', b.dataset.c === st.cat));
    };
    const search = h('input', { class: 'pjs-input', placeholder: 'Rechercher (ex. blue big)…', oninput: (e) => { st.q = e.target.value.trim(); update(); } });
    const catRow = h('div', { class: 'pjp-folders' }, K.cats.map(([id, label]) => h('button', { class: 'pjp-chip', 'data-c': id, onclick: () => { st.cat = id; update(); } }, label)));
    const folderRow = h('div', { class: 'pjp-folders' }, folders.length > 1 ? folders.map((f) => h('button', { class: 'pjp-chip', 'data-f': f, onclick: () => { st.folder = f; update(); } }, f || 'Dossier principal')) : null);
    const ov = h('div', { class: 'pjp-overlay', onmousedown: (e) => { if (e.target === ov) close(); } },
      h('div', { class: 'pjp-picker' },
        h('div', { class: 'pjp-phead' }, h('h3', null, K.title), count, h('button', { class: 'pjp-mini', title: 'Fermer (Échap)', onclick: () => close() }, '✕')),
        search, h('div', { class: 'pjp-filters' }, catRow, folderRow), grid));
    ['keydown', 'keypress', 'keyup'].forEach((t) => ov.addEventListener(t, (e) => e.stopPropagation()));
    document.addEventListener('keydown', onKey, true);
    document.body.appendChild(ov);
    update();
    search.focus();
    setTimeout(() => { const on = grid.querySelector('.pjp-tile.on'); if (on) on.scrollIntoView({ block: 'center' }); }, 50);
  }
  // champ « image » : vignette + nom, ouvre le sélecteur
  function imageField(kind, value, emptyLabel, onPick) {
    const btn = h('button', { class: 'pjp-pick', title: value || emptyLabel, onclick: () => openPicker(kind, value, emptyLabel, (v) => onPick(v, btn)) },
      thumb(kind, value, 40), h('span', { class: 'n' + (value ? '' : ' empty') }, value || emptyLabel), h('span', { class: 'arrow' }, '▾'));
    return btn;
  }

  // ---------------------------------------------------------------------------
  // Chargement / enregistrement
  // ---------------------------------------------------------------------------
  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null; images.clear();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      S.config = { ...DEFAULTS(), ...S.ctx.config };
      if (S.config.__error) { S.error = S.config.__error; }
      delete S.config.__error;
      S.config.heroes = (S.config.heroes || []).map((x) => ({ ...x }));
      S.config.allies = (S.config.allies || []).map((x) => ({ ...x }));
      S.saved = S.ctx.config && S.ctx.config.heroes ? snapshot() : null;
    } catch (e) { S.error = e.message; }
    render();
  }
  async function save() {
    if (!S.config) return;
    const ids = new Set();
    for (const list of [S.config.heroes, S.config.allies]) for (const x of list) {
      if (!x.id) { toast('Chaque personnage doit avoir un identifiant.', true); return; }
      if (ids.has(x.id)) { toast(`Identifiant en double : ${x.id}`, true); return; }
      ids.add(x.id);
    }
    try {
      await call('save', { projectPath: S.projectPath, config: S.config });
      S.saved = snapshot();
      toast('Enregistré');
      render();
    } catch (e) { toast('Erreur de sauvegarde : ' + e.message, true); }
  }
  function statusText() {
    if (!S.config) return ['', ''];
    if (dirty()) return ['Modifications non enregistrées', ' dirty'];
    return [S.saved ? 'Enregistré' : 'Pas encore enregistré', ''];
  }
  function updateStatus() {
    const el = root && root.querySelector('.pjs-status');
    if (!el) return;
    const [txt, cls] = statusText();
    el.textContent = txt; el.className = 'pjs-status' + cls;
  }
  const change = (fn) => (e) => { fn(e); updateStatus(); };
  const newId = (prefix, list) => { let n = list.length + 1; while (list.some((x) => x.id === prefix + n)) n++; return prefix + n; };
  const slug = (s) => String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9_]+/g, '_').replace(/^_+|_+$/g, '');

  // ---------------------------------------------------------------------------
  // Rendu commun
  // ---------------------------------------------------------------------------
  const block = (title, ...kids) => h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title)), kids);
  const field = (label, input, hint) => h('label', { class: 'pjp-field' }, h('span', { class: 'pjp-label' }, label), input, hint ? h('span', { class: 'pjs-hint' }, hint) : null);
  const check = (value, onchange, label, title) => h('label', { class: 'pjs-inline pjp-check', title }, h('input', { type: 'checkbox', checked: value, onchange: change((e) => onchange(e.target.checked)) }), label);
  const code = (txt) => h('code', { class: 'pjp-code' }, txt);

  function render() {
    if (!root) return;
    const page = S.open;
    const scroll = root.querySelector('.pjs-page') ? root.querySelector('.pjs-page').scrollTop : 0;
    root.textContent = '';
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, PAGES[page] || 'Personnages'),
        h('span', { class: 'pjs-top-sub' }, page === 'heros' ? 'Personnages jouables' : 'Personnages qui combattent au côté du héros')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', title: 'Relire les fichiers du projet', onclick: () => { if (!dirty() || confirm('Personnages : abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    const body = h('div', { class: 'pjs-page' });
    root.appendChild(body);
    if (S.error) body.appendChild(h('div', { class: 'pjs-warn' }, S.error));
    if (!S.config) { body.appendChild(h('div', { class: 'pjs-empty' }, S.error ? '' : 'Chargement…')); return; }
    const content = h('div', { class: 'pjs-content pjp-content' });
    body.appendChild(content);
    if (!S.ctx.pluginReady) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/personnages est introuvable : les réglages sont enregistrés mais le jeu ne les utilisera pas.'));
    if (page === 'allies') renderAllies(content); else renderHeroes(content);
    body.scrollTop = scroll;
  }

  // ---------------------------------------------------------------------------
  // Héros
  // ---------------------------------------------------------------------------
  function renderHeroes(content) {
    const c = S.config;
    const heroes = c.heroes;
    if (!c.default_hero && heroes[0]) c.default_hero = heroes[0].id;
    content.appendChild(block('Début de partie',
      h('div', { class: 'pjp-row' },
        field('Héros par défaut', h('select', { class: 'pjs-input pjp-default', disabled: !heroes.length, onchange: change((e) => { c.default_hero = e.target.value; }) },
          heroes.length ? heroes.map((x) => h('option', { value: x.id, selected: x.id === c.default_hero }, x.name || x.id)) : h('option', null, 'Aucun héros')),
        'Le joueur commence la partie avec ce héros (nom, apparence).'),
        field('Longueur du nom', h('input', { class: 'pjs-input pjp-num', type: 'number', min: 1, max: 24, value: c.name_max_length, onchange: change((e) => { c.name_max_length = Math.max(1, Math.min(24, Math.round(+e.target.value || 12))); }) }), 'Caractères au plus.')),
      check(c.ask_name, (v) => { c.ask_name = v; }, 'Demander le nom au joueur après le choix du héros', "Écran du nom de PSDK, le nom par défaut du héros est proposé"),
      h('div', { class: 'pjs-hint pjp-help' },
        'Commandes d’évènement (Script) : ', code('choisir_heros'), ' écran de choix (s’il y a plusieurs héros) puis le nom · ',
        code("changer_heros('" + ((heroes[1] || heroes[0] || {}).id || 'hero_2') + "')"), ' sans écran · ', code('demander_nom_heros'), ' · condition ',
        code("heros_actuel == '" + ((heroes[0] || {}).id || 'hero_1') + "'"))));

    const list = h('div', { class: 'pjp-cards' });
    heroes.forEach((x, i) => list.appendChild(heroCard(x, i)));
    list.appendChild(h('button', { class: 'pjp-add', onclick: () => {
      const base = (S.ctx.bases[0] || {}).base || '';
      const gender = heroes.length % 2 ? 'f' : 'm';
      heroes.push({ id: newId('hero_', heroes), name: '', gender, charset: base, battler: '', picture: '', description: '', generator: false });
      if (!c.default_hero) c.default_hero = heroes[0].id;
      render();
    } }, h('span', { class: 'plus' }, '+'), 'Nouveau héros'));
    content.appendChild(block(`Héros (${heroes.length})`, heroes.length ? null : h('div', { class: 'pjs-hint' }, 'Aucun héros : le joueur garde l’apparence et le nom de PSDK.'), list));
  }
  function heroCard(x, i) {
    const c = S.config; const heroes = c.heroes;
    const gender = x.gender === 'f' ? 'f' : 'm';
    const bases = S.ctx.bases;
    const known = bases.find((b) => b.base === x.charset);
    const look = x.generator ? GENERATOR : x.charset || '';
    const isDefault = c.default_hero === x.id;
    const lookSelect = h('select', { class: 'pjs-input', onchange: change((e) => { const v = e.target.value; x.generator = v === GENERATOR; if (!x.generator) x.charset = v; render(); }) },
      h('option', { value: '', selected: !look }, '— aucune (celle de PSDK) —'),
      bases.map((b) => h('option', { value: b.base, selected: look === b.base, disabled: !b[gender] }, b.base + (b[gender] ? '' : gender === 'f' ? ' (pas de version fille)' : ' (pas de version garçon)'))),
      x.charset && !known && !x.generator ? h('option', { value: x.charset, selected: true }, x.charset + ' (introuvable)') : null,
      h('option', { value: GENERATOR, selected: look === GENERATOR }, 'Générateur de personnages' + (S.ctx.generator ? '' : ' (pièces pas préparées)')));
    const previews = () => h('div', { class: 'pjp-previews' },
      x.generator ? h('div', { class: 'pjp-gen' }, 'Générateur') : charsetPreview(x.charset ? `${x.charset}_${x.gender === 'f' ? 'f' : 'm'}_walk` : null, 2),
      battlerPreview(x.battler, 'Dos'), battlerPreview(x.picture, 'Choix'));
    const move = (d) => { const j = i + d; if (j < 0 || j >= heroes.length) return; [heroes[i], heroes[j]] = [heroes[j], heroes[i]]; render(); };
    return h('div', { class: 'pjp-card' + (isDefault ? ' on' : '') },
      h('div', { class: 'pjp-card-head' },
        previews(),
        h('div', { class: 'pjp-card-tools' },
          isDefault ? h('span', { class: 'pjg-tag pjp-tag' }, 'Début de partie') : h('button', { class: 'pjp-mini', title: 'Héros du début de partie', onclick: () => { c.default_hero = x.id; render(); } }, '★'),
          h('button', { class: 'pjp-mini', title: 'Monter', disabled: i === 0, onclick: () => move(-1) }, '▲'),
          h('button', { class: 'pjp-mini', title: 'Descendre', disabled: i === heroes.length - 1, onclick: () => move(1) }, '▼'),
          h('button', { class: 'pjp-mini danger', title: 'Supprimer', onclick: () => { if (!confirm(`Supprimer le héros « ${x.name || x.id} » ?`)) return; heroes.splice(i, 1); if (c.default_hero === x.id) c.default_hero = heroes[0] ? heroes[0].id : null; render(); } }, '✕'))),
      h('div', { class: 'pjp-grid' },
        field('Nom par défaut', h('input', { class: 'pjs-input', value: x.name || '', maxlength: c.name_max_length, placeholder: 'ex. Red', oninput: change((e) => { x.name = e.target.value; const o = root.querySelector(`.pjp-default option[value="${CSS.escape(x.id)}"]`); if (o) o.textContent = x.name || x.id; }) })),
        field('Identifiant', h('input', { class: 'pjs-input', value: x.id, oninput: change((e) => { const old = x.id; x.id = slug(e.target.value) || old; if (c.default_hero === old) c.default_hero = x.id; const o = root.querySelector(`.pjp-default option[value="${CSS.escape(old)}"]`); if (o) o.value = x.id; }) }), 'Pour les commandes.'),
        field('Garçon / fille', h('select', { class: 'pjs-input', onchange: change((e) => { x.gender = e.target.value; render(); }) },
          h('option', { value: 'm', selected: gender === 'm' }, 'Garçon'), h('option', { value: 'f', selected: gender === 'f' }, 'Fille')), 'Interrupteur « fille » de PSDK.'),
        field('Personnage de la carte', lookSelect, x.generator ? 'Le joueur crée son apparence (écran du générateur après le choix).' : 'graphics/characters/<nom>_' + gender + '_walk, _run…'),
        field('Dresseur de dos', imageField('battlers', x.battler, 'celui de PSDK', (v) => { x.battler = v; render(); }), 'graphics/battlers (en combat).'),
        field('Image de l’écran de choix', imageField('battlers', x.picture, 'le personnage de la carte', (v) => { x.picture = v; render(); }), 'graphics/battlers.')),
      field('Description', h('input', { class: 'pjs-input', value: x.description || '', placeholder: 'affichée sous le nom dans l’écran de choix', oninput: change((e) => { x.description = e.target.value; }) })));
  }

  // ---------------------------------------------------------------------------
  // Alliés
  // ---------------------------------------------------------------------------
  const trainerOf = (sym) => S.ctx.trainers.find((t) => t.dbSymbol === sym || String(t.id) === String(sym));
  function renderAllies(content) {
    const allies = S.config.allies;
    content.appendChild(block('Combat au côté du héros',
      h('div', { class: 'pjs-hint pjp-help' },
        'Un allié est lié à un dresseur de ', h('b', null, 'Données > Dresseurs'), ' : son équipe (soignée à chaque combat) se bat avec celle du héros en combat double. ',
        'Le sprite de dos du dresseur (Ressources > sprite) est celui de l’allié en combat.'),
      h('div', { class: 'pjs-hint pjp-help' }, 'Commandes d’évènement (Script) : ', code("allie_rejoint('" + ((allies[0] || {}).id || 'ally_1') + "')"), ' · ', code('allie_quitte'), ' · condition ', code('allie_present?'),
        ' · les combats lancés avec un allié précis (« avec un ami ») gardent le leur.')));
    const list = h('div', { class: 'pjp-cards' });
    allies.forEach((x, i) => list.appendChild(allyCard(x, i)));
    list.appendChild(h('button', { class: 'pjp-add', onclick: () => {
      const t = S.ctx.trainers[0];
      allies.push({ id: newId('ally_', allies), name: t ? t.name : '', trainer: t ? t.dbSymbol : '', charset: t ? t.character : '', follow: true, trainer_battles: true, wild_battles: false });
      render();
    } }, h('span', { class: 'plus' }, '+'), 'Nouvel allié'));
    content.appendChild(block(`Alliés (${allies.length})`, allies.length ? null : h('div', { class: 'pjs-hint' }, 'Aucun allié.'), list));
  }
  function allyCard(x, i) {
    const allies = S.config.allies;
    const t = trainerOf(x.trainer);
    const trainerSelect = h('select', { class: 'pjs-input', onchange: change((e) => {
      const nt = trainerOf(e.target.value); const old = trainerOf(x.trainer);
      if (nt) { if (!x.name || (old && x.name === old.name)) x.name = nt.name; if (!x.charset || (old && x.charset === old.character)) x.charset = nt.character; }
      x.trainer = e.target.value; render();
    }) },
    h('option', { value: '', selected: !x.trainer }, '— choisir un dresseur —'),
    S.ctx.trainers.map((tr) => h('option', { value: tr.dbSymbol, selected: t === tr }, `#${String(tr.id).padStart(3, '0')} ${tr.className ? tr.className + ' ' : ''}${tr.name}`)),
    x.trainer && !t ? h('option', { value: x.trainer, selected: true }, x.trainer + ' (introuvable)') : null);
    const previews = () => h('div', { class: 'pjp-previews' }, charsetPreview(x.charset, 2), battlerPreview(t && t.sprite, 'Dos'), battlerPreview(t && t.artwork, 'Face'));
    return h('div', { class: 'pjp-card' },
      h('div', { class: 'pjp-card-head' },
        previews(),
        h('div', { class: 'pjp-card-tools' },
          h('button', { class: 'pjp-mini danger', title: 'Supprimer', onclick: () => { if (!confirm(`Supprimer l’allié « ${x.name || x.id} » ?`)) return; allies.splice(i, 1); render(); } }, '✕'))),
      h('div', { class: 'pjp-grid' },
        field('Nom', h('input', { class: 'pjs-input', value: x.name || '', placeholder: t ? t.name : '', oninput: change((e) => { x.name = e.target.value; }) }), 'Affiché en combat.'),
        field('Identifiant', h('input', { class: 'pjs-input', value: x.id, oninput: change((e) => { x.id = slug(e.target.value) || x.id; }) }), 'Pour les commandes.'),
        h('div', { class: 'pjp-span2' }, field('Dresseur (équipe)', trainerSelect,
          t ? (t.party.length ? null : 'Équipe vide : ajoute des Pokémon dans Données > Dresseurs.') : 'Le dresseur donne l’équipe et le sprite de dos.')),
        t && t.party.length ? h('div', { class: 'pjp-span2 pjg-chips' }, t.party.map((p) => h('span', { class: 'pjg-chip' }, p.name + (p.level ? ' N.' + p.level : '')))) : null,
        t && !t.sprite ? h('div', { class: 'pjp-span2 pjs-hint pjp-warn' }, 'Ce dresseur n’a pas de sprite de dos (Données > Dresseurs > Ressources) : PSDK le montrera sans image.') : null,
        field('Personnage de la carte', imageField('characters', x.charset, 'aucun', (v) => { x.charset = v; render(); }), 'Quand il suit le héros.'),
        h('div', { class: 'pjp-checks' },
          check(x.follow, (v) => { x.follow = v; }, 'Suit le héros sur la carte'),
          check(x.trainer_battles !== false, (v) => { x.trainer_battles = v; }, 'Combats contre les dresseurs'),
          check(!!x.wild_battles, (v) => { x.wild_battles = v; }, 'Combats sauvages'))));
  }

  // ---------------------------------------------------------------------------
  // Pages de Studio (Données > Personnages > Héros / Alliés)
  // ---------------------------------------------------------------------------
  function mount(hostEl, page) {
    root = h('div', { id: 'pjp-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = page;
    const latest = currentProject();
    if (!S.config || (latest && latest !== S.projectPath && !dirty())) loadProject(latest || null); else render();
  }
  function checkPage() {
    let found = null;
    for (const id of Object.keys(PAGES)) { const el = document.getElementById('pj-page-' + id); if (el) { found = [el, id]; break; } }
    // même zone de page mais autre sous-page (Héros <-> Alliés) : on refait la page
    if (root && found && found[0].contains(root) && found[1] === S.open) return;
    if (root && root.parentNode) root.remove();
    if (root) { root = null; S.open = null; }
    if (found) mount(found[0], found[1]);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('keydown', (e) => {
    if (!S.open) return;
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') { e.preventDefault(); e.stopPropagation(); save(); }
  }, true);

  window.pjPersonnagesEditor = { state: S, render, save };
})();

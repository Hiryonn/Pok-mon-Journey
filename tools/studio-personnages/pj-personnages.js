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
  function openPicker(kind, current, emptyLabel, onPick, opts = {}) {
    const K = KINDS[kind];
    const all = K.list();
    const folders = ['', ...new Set(all.filter((f) => f.includes('/')).map((f) => f.slice(0, f.lastIndexOf('/'))))];
    const isPokemonName = (f) => /^\d/.test(String(f || '').split('/').pop());
    const st = { cat: kind === 'characters' && current && isPokemonName(current) ? 'pokemon' : K.cats[0][0], q: '', folder: (current && current.includes('/')) ? current.slice(0, current.lastIndexOf('/')) : '', shown: 0, items: [] };
    if (opts.query) { st.q = opts.query; st.folder = '*'; }
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
      if (emptyLabel) grid.appendChild(h('button', { class: 'pjp-tile none' + (!current ? ' on' : ''), onclick: () => close('') }, h('div', { class: 'pjp-thumb ph' }, '∅'), h('span', { class: 'n' }, emptyLabel)));
      grid.appendChild(sentinel);
      st.shown = 0; more();
      count.textContent = `${st.items.length} image${st.items.length > 1 ? 's' : ''}`;
      folderRow.querySelectorAll('.pjp-chip').forEach((b) => b.classList.toggle('on', b.dataset.f === st.folder));
      catRow.querySelectorAll('.pjp-chip').forEach((b) => b.classList.toggle('on', b.dataset.c === st.cat));
    };
    const search = h('input', { class: 'pjs-input', value: st.q, placeholder: 'Rechercher (ex. blue big)…', oninput: (e) => { st.q = e.target.value.trim(); update(); } });
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
    setTimeout(() => { const on = grid.querySelector('.pjp-tile.on'); if (on) scrollInto(on, true); }, 50);
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
  // Rendu commun : liste des personnages à gauche, onglets Personnage / Ressources (comme la page Pokémon)
  // ---------------------------------------------------------------------------
  const block = (title, ...kids) => h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title)), kids);
  const field = (label, input, hint) => h('label', { class: 'pjp-field' }, h('span', { class: 'pjp-label' }, label), input, hint ? h('span', { class: 'pjs-hint' }, hint) : null);
  const check = (value, onchange, label, title) => h('label', { class: 'pjs-inline pjp-check', title }, h('input', { type: 'checkbox', checked: value, onchange: change((e) => onchange(e.target.checked)) }), label);
  const code = (txt) => h('code', { class: 'pjp-code' }, txt);
  const listOf = () => (S.open === 'allies' ? S.config.allies : S.config.heroes);
  const UI = { sel: { heros: null, allies: null }, tab: { heros: 'main', allies: 'main' } };
  const selected = () => { const list = listOf(); let x = list.find((e) => e.id === UI.sel[S.open]); if (!x && list[0]) { x = list[0]; UI.sel[S.open] = x.id; } return x || null; };

  // états du personnage du joueur (suffixes des charsets de PSDK)
  const STATES = [
    ['walk', 'Marche'], ['run', 'Course'], ['cycle_roll', 'Vélo'], ['cycle_stop', 'Vélo (arrêt)'], ['cycle_wheel', 'Vélo (cabré)'],
    ['cycle_roll_to_wheel', 'Vélo (se cabre)'], ['surf', 'Surf'], ['fish', 'Pêche'], ['surf_fish', 'Pêche (surf)'], ['pokecenter', 'Soin / sauvegarde'],
    ['rockclimb_up', 'Escalade (montée)'], ['rockclimb_down', 'Escalade (descente)'], ['swamp', 'Marais'], ['swamp_run', 'Marais (course)'],
    ['deep_swamp_sinking', 'Enlisement'], ['misc2', 'Arrosage'],
  ];
  // autres sprites que PSDK sait utiliser (ajoutables avec « + Nouvelle apparence »)
  const EXTRA_STATES = [['surf_hm', 'Surf (capacité)'], ['surf_vs', 'Surf (face au combat)'], ['ladder', 'Échelle'], ['shake', 'Secousse'], ['snow', 'Neige'],
    ['snow_misc', 'Neige (divers)'], ['snow_deep', 'Neige profonde'], ['snow_deep_misc', 'Neige profonde (divers)'], ['swamp_deep', 'Marais profond']];
  const characterSet = () => (S._chars && S._chars.src === S.ctx.characters ? S._chars.set : (S._chars = { src: S.ctx.characters, set: new Set(S.ctx.characters) }).set);
  // fichier d'un état : choisi dans Ressources, sinon <base>_<m|f>_<état> s'il existe
  function heroSprite(x, state) {
    const own = x.sprites && x.sprites[state];
    if (own) return { file: own, own: true };
    if (x.charset) { const f = `${x.charset}_${x.gender === 'f' ? 'f' : 'm'}_${state}`; if (characterSet().has(f)) return { file: f, own: false }; }
    return { file: null, own: false };
  }
  const mapSprite = (x) => (S.open === 'allies' ? x.charset : heroSprite(x, 'walk').file);

  // charset animé (marche vers le bas) ; un seul minuteur pour toute la page
  function animSprite(file, scale) {
    const c = h('canvas', { class: 'pjp-anim', width: 32 * scale, height: 32 * scale });
    c._scale = scale;
    if (!file) { c.classList.add('none'); return c; }
    image('graphics/characters/' + file).then((url) => {
      if (!url) { c.classList.add('missing'); c.title = 'Image introuvable : graphics/characters/' + file + '.png'; return; }
      const img = new Image();
      img.onload = () => { c._img = img; c.width = Math.floor(img.width / 4) * scale; c.height = Math.floor(img.height / 4) * scale; drawFrame(c, 0); };
      img.src = url;
    });
    return c;
  }
  function drawFrame(c, frame) {
    const img = c._img; if (!img) return;
    const fw = Math.floor(img.width / 4); const fh = Math.floor(img.height / 4);
    const g = c.getContext('2d'); g.imageSmoothingEnabled = false;
    g.clearRect(0, 0, c.width, c.height);
    g.drawImage(img, (frame % 4) * fw, 0, fw, fh, 0, 0, fw * c._scale, fh * c._scale);
  }
  let animTick = 0;
  setInterval(() => { if (!root) return; animTick++; root.querySelectorAll('canvas.pjp-anim.play, .pjp-res:hover canvas.pjp-anim').forEach((c) => drawFrame(c, animTick)); }, 160);

  function render() {
    if (!root) return;
    const page = S.open;
    const keep = {};
    root.querySelectorAll('[data-scroll]').forEach((el) => { keep[el.dataset.scroll] = el.scrollTop; });
    root.textContent = '';
    const [statusTxt, statusCls] = statusText();
    const x = S.config ? selected() : null;
    const tab = UI.tab[page];
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, PAGES[page] || 'Personnages'),
        h('div', { class: 'pjs-tabs' }, [['main', 'Personnage'], ['res', 'Ressources']].map(([id, label]) => h('button', {
          class: 'pjs-tab' + (tab === id ? ' active' : ''), disabled: !x, onclick: () => { UI.tab[page] = id; render(); } }, label)))),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', title: 'Relire les fichiers du projet', onclick: () => { if (!dirty() || confirm('Personnages : abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    if (!S.config) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: S.error ? 'pjs-warn' : 'pjs-empty' }, S.error || 'Chargement…'))); return; }
    const body = h('div', { class: 'pjp-body' });
    root.appendChild(body);
    body.appendChild(renderList());
    const main = h('div', { class: 'pjs-page pjp-main', 'data-scroll': page + tab + (x ? x.id : '') });
    body.appendChild(main);
    const content = h('div', { class: 'pjs-content pjp-content' });
    main.appendChild(content);
    if (S.error) content.appendChild(h('div', { class: 'pjs-warn' }, S.error));
    if (!S.ctx.pluginReady) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/personnages est introuvable : les réglages sont enregistrés mais le jeu ne les utilisera pas.'));
    if (!x) content.appendChild(h('div', { class: 'pjp-empty' }, h('div', { class: 'big' }, page === 'allies' ? 'Aucun allié' : 'Aucun héros'),
      h('div', { class: 'pjs-hint' }, page === 'allies' ? 'Un allié combat au côté du héros (combat double) avec l’équipe d’un dresseur de Studio.' : 'Sans héros, le joueur garde l’apparence et le nom de PSDK.'),
      h('button', { class: 'pjs-btn primary', onclick: addEntry }, page === 'allies' ? '+ Nouvel allié' : '+ Nouveau héros')));
    else if (page === 'allies') { if (tab === 'res') allyResources(content, x); else allyMain(content, x); } else if (tab === 'res') heroResources(content, x); else heroMain(content, x);
    root.querySelectorAll('[data-scroll]').forEach((el) => { if (keep[el.dataset.scroll]) el.scrollTop = keep[el.dataset.scroll]; });
  }
  function addEntry() {
    const list = listOf();
    let x;
    if (S.open === 'allies') {
      const t = S.ctx.trainers[0];
      x = { id: newId('ally_', list), name: t ? t.name : '', trainer: t ? t.dbSymbol : '', charset: t ? t.character : '', battler: '', follow: true, trainer_battles: true, wild_battles: false };
    } else {
      const base = (S.ctx.bases[0] || {}).base || '';
      x = { id: newId('hero_', list), name: '', gender: list.length % 2 ? 'f' : 'm', charset: base, sprites: {}, battler: '', picture: '', description: '', generator: false };
      if (!S.config.default_hero) S.config.default_hero = x.id;
    }
    list.push(x);
    UI.sel[S.open] = x.id; UI.tab[S.open] = 'main';
    render();
  }
  function renderList() {
    const list = listOf();
    const box = h('div', { class: 'pjp-list', 'data-scroll': 'list-' + S.open });
    box.appendChild(h('button', { class: 'pjs-btn primary pjp-new', onclick: addEntry }, S.open === 'allies' ? '+ Nouvel allié' : '+ Nouveau héros'));
    list.forEach((e, i) => {
      const on = e.id === UI.sel[S.open];
      const sub = S.open === 'allies' ? (trainerOf(e.trainer) ? trainerOf(e.trainer).className + ' · ' + e.id : e.id) : (e.gender === 'f' ? 'Fille' : 'Garçon') + ' · ' + e.id;
      box.appendChild(h('div', { class: 'pjp-item' + (on ? ' on' : ''), onclick: () => { UI.sel[S.open] = e.id; render(); } },
        h('div', { class: 'pjp-item-sprite' }, S.open !== 'allies' && e.generator ? h('span', { class: 'gen' }, 'Gén.') : animSprite(mapSprite(e), 1)),
        h('div', { class: 'pjp-item-txt' }, h('span', { class: 'n' }, e.name || 'Sans nom'), h('span', { class: 's' }, sub)),
        S.open !== 'allies' && S.config.default_hero === e.id ? h('span', { class: 'pjp-star', title: 'Héros du début de partie' }, '★') : null,
        h('div', { class: 'pjp-item-tools' },
          h('button', { class: 'pjp-mini', title: 'Monter', disabled: i === 0, onclick: (ev) => { ev.stopPropagation(); [list[i - 1], list[i]] = [list[i], list[i - 1]]; render(); } }, '▲'),
          h('button', { class: 'pjp-mini', title: 'Descendre', disabled: i === list.length - 1, onclick: (ev) => { ev.stopPropagation(); [list[i + 1], list[i]] = [list[i], list[i + 1]]; render(); } }, '▼'))));
    });
    return box;
  }
  function removeEntry(x) {
    const list = listOf();
    if (!confirm(`Supprimer « ${x.name || x.id} » ?`)) return;
    list.splice(list.indexOf(x), 1);
    if (S.open !== 'allies' && S.config.default_hero === x.id) S.config.default_hero = list[0] ? list[0].id : null;
    UI.sel[S.open] = list[0] ? list[0].id : null;
    render();
  }
  // en-tête façon fiche Pokémon : grande image, nom, n°, étiquettes, description
  function header(x, imgEl, tags, desc) {
    return h('div', { class: 'pjs-block pjp-head' },
      h('div', { class: 'pjp-head-img' }, imgEl),
      h('div', { class: 'pjp-head-txt' },
        h('div', { class: 'pjp-head-title' }, h('span', { class: 'n' }, x.name || 'Sans nom'), h('span', { class: 'id' }, '#' + x.id)),
        h('div', { class: 'pjp-tags' }, tags.filter(Boolean).map(([t, cls]) => h('span', { class: 'pjp-tagx ' + (cls || '') }, t))),
        desc ? h('div', { class: 'pjp-head-desc' }, desc) : null),
      h('button', { class: 'pjp-mini danger pjp-del', title: 'Supprimer', onclick: () => removeEntry(x) }, '✕'));
  }
  const bigPicture = (kind, file, fallbackChar) => {
    if (file) { const b = battlerPreview(file, ''); b.classList.add('big'); return b; }
    const a = animSprite(fallbackChar, 3); a.classList.add('play'); return a;
  };

  // ---------------------------------------------------------------------------
  // Héros
  // ---------------------------------------------------------------------------
  function heroMain(content, x) {
    const c = S.config;
    const g = x.gender === 'f' ? 'f' : 'm';
    content.appendChild(header(x, x.generator ? h('div', { class: 'pjp-gen big' }, 'Générateur de personnages') : bigPicture('battlers', x.picture, heroSprite(x, 'walk').file),
      [[g === 'f' ? 'Fille' : 'Garçon', g], c.default_hero === x.id ? ['Début de partie', 'red'] : null, x.generator ? ['Générateur', ''] : null], x.description));
    content.appendChild(h('div', { class: 'pjp-cards2' },
      block('Identité',
        field('Nom par défaut', h('input', { class: 'pjs-input', value: x.name || '', maxlength: c.name_max_length, placeholder: 'ex. Red', oninput: change((e) => { x.name = e.target.value; const it = root.querySelector('.pjp-item.on .n'); if (it) it.textContent = x.name || 'Sans nom'; const t = root.querySelector('.pjp-head-title .n'); if (t) t.textContent = x.name || 'Sans nom'; }) })),
        field('Identifiant', h('input', { class: 'pjs-input', value: x.id, oninput: change((e) => { const old = x.id; x.id = slug(e.target.value) || old; if (c.default_hero === old) c.default_hero = x.id; UI.sel.heros = x.id; }) }), 'Pour les commandes d’évènement.'),
        field('Garçon / fille', h('select', { class: 'pjs-input', onchange: change((e) => { x.gender = e.target.value; render(); }) },
          h('option', { value: 'm', selected: g === 'm' }, 'Garçon'), h('option', { value: 'f', selected: g === 'f' }, 'Fille')), 'Interrupteur « fille » de PSDK.'),
        field('Description', h('input', { class: 'pjs-input', value: x.description || '', placeholder: 'affichée sous le nom dans l’écran de choix', oninput: change((e) => { x.description = e.target.value; }) }))),
      block('Début de partie',
        c.default_hero === x.id ? h('div', { class: 'pjp-note' }, '★ Le joueur commence la partie avec ce héros.')
          : h('button', { class: 'pjs-btn secondary', onclick: () => { c.default_hero = x.id; render(); } }, '★ Commencer la partie avec ce héros'),
        h('div', { class: 'pjp-sep' }),
        h('div', { class: 'pjs-hint' }, 'Réglages communs à tous les héros :'),
        check(c.ask_name, (v) => { c.ask_name = v; }, 'Demander le nom au joueur après le choix du héros'),
        field('Longueur du nom', h('input', { class: 'pjs-input pjp-num', type: 'number', min: 1, max: 24, value: c.name_max_length, onchange: change((e) => { c.name_max_length = Math.max(1, Math.min(24, Math.round(+e.target.value || 12))); }) }), 'Caractères au plus.')),
      block('Apparence',
        h('div', { class: 'pjp-mini-sprites' }, ['walk', 'run', 'cycle_roll', 'surf'].map((s) => { const sp = heroSprite(x, s); const a = animSprite(x.generator ? null : sp.file, 2); a.classList.add('play'); return h('div', { class: 'pjp-ms' }, a, h('span', null, STATES.find((t) => t[0] === s)[1])); })),
        h('button', { class: 'pjs-btn secondary', onclick: () => { UI.tab.heros = 'res'; render(); } }, 'Choisir les sprites (Ressources)')),
      block('Commandes',
        h('div', { class: 'pjs-hint pjp-help' }, code('choisir_heros'), ' écran de choix (s’il y a plusieurs héros) puis le nom'),
        h('div', { class: 'pjs-hint pjp-help' }, code(`changer_heros('${x.id}')`), ' prend ce héros sans écran'),
        h('div', { class: 'pjs-hint pjp-help' }, code(`heros_actuel == '${x.id}'`), ' condition'),
        h('div', { class: 'pjs-hint pjp-help' }, code('demander_nom_heros'), ' écran du nom'))));
  }
  function stateTile(x, state, label, removable) {
    const g = x.gender === 'f' ? 'f' : 'm';
    const sp = heroSprite(x, state);
    return h('button', { class: 'pjp-res' + (sp.own ? ' own' : '') + (sp.file ? '' : ' empty'), title: (sp.file ? sp.file : 'Aucun sprite') + (removable ? ` · apparence « ${state} »` : ''),
      onclick: () => openPicker('characters', sp.own ? sp.file : '', x.charset ? `auto (${x.charset}_${g}_${state})` : 'aucun', (v) => { x.sprites = x.sprites || {}; if (v) x.sprites[state] = v; else delete x.sprites[state]; render(); }, { query: state.replace(/_/g, ' ') }) },
    removable ? h('span', { class: 'pjp-res-del', title: 'Retirer cette apparence', onclick: (e) => { e.stopPropagation(); x.looks = x.looks.filter((l) => l.key !== state); if (x.sprites) delete x.sprites[state]; render(); } }, '✕') : null,
    h('div', { class: 'pjp-res-img' }, animSprite(sp.file, 2)),
    h('span', { class: 'n' }, label), h('span', { class: 's' }, sp.file ? (sp.own ? sp.file : 'auto') : '—'));
  }
  // nouvelle apparence : un sprite de PSDK pas encore listé, ou une apparence à soi (nage, tenue…)
  function addLook(x) {
    const used = new Set([...STATES.map((t) => t[0]), ...(x.looks || []).map((l) => l.key)]);
    const free = EXTRA_STATES.filter(([k]) => !used.has(k));
    const name = h('input', { class: 'pjs-input', placeholder: 'ex. Nage, Tenue de soirée…' });
    const close = () => ov.remove();
    const add = (key, label) => {
      if (!key) return;
      if (used.has(key)) { toast('Cette apparence existe déjà.', true); return; }
      x.looks = x.looks || []; x.looks.push({ key, label: label || key });
      close(); render();
      const sp = heroSprite(x, key);
      if (!sp.file) openPicker('characters', '', 'aucun', (v) => { if (v) { x.sprites = x.sprites || {}; x.sprites[key] = v; } render(); }, { query: key.replace(/_/g, ' ') });
    };
    const ov = h('div', { class: 'pjp-overlay', onmousedown: (e) => { if (e.target === ov) close(); } },
      h('div', { class: 'pjp-picker pjp-small' },
        h('div', { class: 'pjp-phead' }, h('h3', null, 'Nouvelle apparence'), h('button', { class: 'pjp-mini', onclick: close }, '✕')),
        h('div', { class: 'pjp-label' }, 'Apparence à soi'),
        h('div', { class: 'pjp-row' }, name, h('button', { class: 'pjs-btn primary', onclick: () => add(slug(name.value), name.value.trim()) }, 'Ajouter')),
        h('div', { class: 'pjs-hint' }, 'Elle se met en jeu avec la commande apparence_heros(\'<nom>\') (ex. pour nager dans une cinématique) et s’enlève avec apparence_heros.'),
        free.length ? h('div', { class: 'pjp-label' }, 'Sprites que PSDK utilise tout seul') : null,
        free.length ? h('div', { class: 'pjp-suggest' }, free.map(([k, l]) => h('button', { class: 'pjp-chip', onclick: () => add(k, l) }, `${l} (_${k})`))) : null));
    ['keydown', 'keypress', 'keyup'].forEach((t) => ov.addEventListener(t, (e) => { e.stopPropagation(); if (t === 'keydown' && e.key === 'Escape') close(); if (t === 'keydown' && e.key === 'Enter' && document.activeElement === name) add(slug(name.value), name.value.trim()); }));
    document.body.appendChild(ov);
    name.focus();
  }
  function heroResources(content, x) {
    const g = x.gender === 'f' ? 'f' : 'm';
    const bases = S.ctx.bases;
    const mode = x.generator ? 'generator' : 'set';
    content.appendChild(block('Personnage de la carte',
      h('div', { class: 'pjp-row' },
        field('Sprites', h('select', { class: 'pjs-input', onchange: change((e) => { const v = e.target.value; x.generator = v === GENERATOR; if (!x.generator) x.charset = v; render(); }) },
          h('option', { value: '', selected: mode === 'set' && !x.charset }, '— choisis chaque sprite ci-dessous —'),
          bases.map((b) => h('option', { value: b.base, selected: mode === 'set' && x.charset === b.base }, `Jeu « ${b.base} » (${b.base}_${g}_walk, _run…)` + (b[g] ? '' : ' — pas de version ' + (g === 'f' ? 'fille' : 'garçon')))),
          x.charset && !bases.some((b) => b.base === x.charset) ? h('option', { value: x.charset, selected: mode === 'set' }, x.charset + ' (introuvable)') : null,
          h('option', { value: GENERATOR, selected: mode === 'generator' }, 'Générateur de personnages' + (S.ctx.generator ? '' : ' (pièces pas préparées)'))),
        x.generator ? 'Le joueur crée son apparence dans l’écran du générateur (après le choix du héros).' : 'Un jeu de sprites remplit tous les états ; chaque sprite peut ensuite être changé un par un.')),
      x.generator ? null : h('div', { class: 'pjp-res-grid' },
        STATES.map(([state, label]) => stateTile(x, state, label, false)),
        (x.looks || []).map((l) => stateTile(x, l.key, l.label, true)),
        h('button', { class: 'pjp-res pjp-res-add', onclick: () => addLook(x) }, h('div', { class: 'pjp-res-img' }, h('span', { class: 'plus' }, '+')), h('span', { class: 'n' }, 'Nouvelle apparence'), h('span', { class: 's' }, 'nage, neige, tenue…'))),
      x.generator || !(x.looks || []).length ? null : h('div', { class: 'pjs-hint pjp-help' }, 'Apparences ajoutées : PSDK utilise tout seul celles qu’il connaît (surf capacité, neige, échelle…). Les autres se mettent avec la commande ',
        code(`apparence_heros('${(x.looks.find((l) => !EXTRA_STATES.some((t) => t[0] === l.key)) || { key: 'nage' }).key}')`), ', et ', code('apparence_heros'), ' revient à l’apparence normale.')));
    content.appendChild(h('div', { class: 'pjp-cards2' },
      block('Combat', field('Dresseur de dos', imageField('battlers', x.battler, 'celui de PSDK', (v) => { x.battler = v; render(); }), 'graphics/battlers. Vide : celui de PSDK.'),
        h('div', { class: 'pjp-res-big' }, battlerPreview(x.battler, 'Dos'))),
      block('Écran de choix', field('Image du héros', imageField('battlers', x.picture, 'le personnage de la carte', (v) => { x.picture = v; render(); }), 'graphics/battlers. Vide : le personnage de la carte agrandi.'),
        h('div', { class: 'pjp-res-big' }, x.picture ? battlerPreview(x.picture, 'Choix') : (() => { const a = animSprite(heroSprite(x, 'walk').file, 3); a.classList.add('play'); return a; })()))));
  }

  // ---------------------------------------------------------------------------
  // Alliés
  // ---------------------------------------------------------------------------
  const trainerOf = (sym) => S.ctx.trainers.find((t) => t.dbSymbol === sym || String(t.id) === String(sym));
  function allyMain(content, x) {
    const t = trainerOf(x.trainer);
    content.appendChild(header(x, bigPicture('battlers', (t && t.artwork) || '', x.charset),
      [[t ? t.className || 'Dresseur' : 'Sans dresseur', t ? '' : 'red'], x.follow ? ['Suit le héros', ''] : null], t ? `Équipe du dresseur #${String(t.id).padStart(3, '0')} ${t.name}` : 'Choisis le dresseur dont l’équipe combat avec le héros.'));
    const trainerSelect = h('select', { class: 'pjs-input', onchange: change((e) => {
      const nt = trainerOf(e.target.value); const old = trainerOf(x.trainer);
      if (nt) { if (!x.name || (old && x.name === old.name)) x.name = nt.name; if (!x.charset || (old && x.charset === old.character)) x.charset = nt.character; }
      x.trainer = e.target.value; render();
    }) },
    h('option', { value: '', selected: !x.trainer }, '— choisir un dresseur —'),
    S.ctx.trainers.map((tr) => h('option', { value: tr.dbSymbol, selected: t === tr }, `#${String(tr.id).padStart(3, '0')} ${tr.className ? tr.className + ' ' : ''}${tr.name}`)),
    x.trainer && !t ? h('option', { value: x.trainer, selected: true }, x.trainer + ' (introuvable)') : null);
    content.appendChild(h('div', { class: 'pjp-cards2' },
      block('Identité',
        field('Nom', h('input', { class: 'pjs-input', value: x.name || '', placeholder: t ? t.name : '', oninput: change((e) => { x.name = e.target.value; const it = root.querySelector('.pjp-item.on .n'); if (it) it.textContent = x.name || 'Sans nom'; const tt = root.querySelector('.pjp-head-title .n'); if (tt) tt.textContent = x.name || 'Sans nom'; }) }), 'Affiché en combat.'),
        field('Identifiant', h('input', { class: 'pjs-input', value: x.id, oninput: change((e) => { x.id = slug(e.target.value) || x.id; UI.sel.allies = x.id; }) }), 'Pour les commandes d’évènement.')),
      block('Équipe', field('Dresseur', trainerSelect, 'Données > Dresseurs : son équipe (soignée à chaque combat) se bat avec celle du héros.'),
        t && t.party.length ? h('div', { class: 'pjg-chips' }, t.party.map((p) => h('span', { class: 'pjg-chip' }, p.name + (p.level ? ' N.' + p.level : '')))) : h('div', { class: 'pjs-hint pjp-warn' }, t ? 'Équipe vide : ajoute des Pokémon dans Données > Dresseurs.' : 'Aucun dresseur choisi.')),
      block('Combats et carte',
        check(x.trainer_battles !== false, (v) => { x.trainer_battles = v; }, 'Combats contre les dresseurs (combat double)'),
        check(!!x.wild_battles, (v) => { x.wild_battles = v; }, 'Combats sauvages'),
        check(x.follow, (v) => { x.follow = v; render(); }, 'Suit le héros sur la carte'),
        h('div', { class: 'pjs-hint' }, 'Un combat lancé avec un allié précis (« avec un ami ») garde le sien.')),
      block('Commandes',
        h('div', { class: 'pjs-hint pjp-help' }, code(`allie_rejoint('${x.id}')`), ' l’allié accompagne le héros'),
        h('div', { class: 'pjs-hint pjp-help' }, code('allie_quitte'), ' il s’en va'),
        h('div', { class: 'pjs-hint pjp-help' }, code(`allie_actuel == '${x.id}'`), ' · ', code('allie_present?'), ' conditions'))));
  }
  function allyResources(content, x) {
    const t = trainerOf(x.trainer);
    content.appendChild(h('div', { class: 'pjp-cards2' },
      block('Personnage de la carte', field('Sprite', imageField('characters', x.charset, 'aucun', (v) => { x.charset = v; render(); }), 'Quand il suit le héros (graphics/characters).'),
        h('div', { class: 'pjp-res-big' }, (() => { const a = animSprite(x.charset, 3); a.classList.add('play'); return a; })())),
      block('Combat', field('Dresseur de dos', imageField('battlers', x.battler, t && t.sprite ? `celui du dresseur (${t.sprite})` : 'celui du dresseur', (v) => { x.battler = v; render(); }), 'graphics/battlers. Vide : le sprite du dresseur (Données > Dresseurs > Ressources).'),
        h('div', { class: 'pjp-res-big' }, battlerPreview(x.battler || (t && t.sprite), 'Dos')),
        t && !t.sprite && !x.battler ? h('div', { class: 'pjs-hint pjp-warn' }, 'Ni l’allié ni son dresseur n’ont de sprite de dos : PSDK le montrera sans image.') : null),
      block('Image de face', h('div', { class: 'pjs-hint' }, 'Celle du dresseur (Données > Dresseurs > Ressources).'), h('div', { class: 'pjp-res-big' }, battlerPreview(t && t.artwork, 'Face')))));
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

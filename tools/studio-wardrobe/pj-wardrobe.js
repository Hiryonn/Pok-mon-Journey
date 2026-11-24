/* eslint-disable */
// =============================================================================
// Tenues (wardrobe) — page « Générateurs > Tenues » de Pokémon Studio
// Liste les tenues du héros (objets du sac qui changent son apparence) et écrit Data/configs/plugins/wardrobe.json,
// lu par le plugin wardrobe en jeu. Une tenue = des sprites tout faits (charset + image de face) et / ou des pièces du
// générateur de personnages. Peut créer l'objet Studio (Data/Studio/items, icône = première case du charset, textes).
// =============================================================================
(() => {
  if (window.__pjWardrobeLoaded) return;
  window.__pjWardrobeLoaded = true;

  const PAGE_ID = 'tenues';
  const CATS = [['hair', 'Coiffure', false], ['top', 'Haut', false], ['bottom', 'Bas', false], ['hat', 'Chapeau', true], ['bag', 'Sac', true]];
  const NONE = '__none__';
  // états du personnage du joueur (suffixes des charsets de PSDK) : les mêmes que la page Personnages > Héros > Ressources
  const STATES = [
    ['walk', 'Marche'], ['run', 'Course'], ['cycle_roll', 'Vélo'], ['cycle_stop', 'Vélo (arrêt)'], ['cycle_wheel', 'Vélo (cabré)'],
    ['cycle_roll_to_wheel', 'Vélo (se cabre)'], ['surf', 'Surf'], ['fish', 'Pêche'], ['surf_fish', 'Pêche (surf)'], ['pokecenter', 'Soin / sauvegarde'],
    ['rockclimb_up', 'Escalade (montée)'], ['rockclimb_down', 'Escalade (descente)'], ['swamp', 'Marais'], ['swamp_run', 'Marais (course)'],
    ['deep_swamp_sinking', 'Enlisement'], ['misc2', 'Arrosage'],
  ];
  const EXTRA_STATES = [['surf_hm', 'Surf (capacité)'], ['surf_vs', 'Surf (face au combat)'], ['ladder', 'Échelle'], ['shake', 'Secousse'], ['snow', 'Neige'],
    ['snow_misc', 'Neige (divers)'], ['snow_deep', 'Neige profonde'], ['snow_deep_misc', 'Neige profonde (divers)'], ['swamp_deep', 'Marais profond']];
  // images qui ne sont pas des charsets
  const OTHER = [['front', 'Face (menus)', 'graphics/pictures', 'pictures'], ['back', 'Dos (combat)', 'graphics/battlers', 'battlers']];

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjWardrobe;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API des tenues n'est pas disponible : relance installer_wardrobe.bat puis redémarre Studio.");
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
    toastTimer = setTimeout(() => t.remove(), err ? 7000 : 3000);
  }
  const projectList = () => { try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; } };
  const isSymbol = (s) => /^[a-z0-9_]{1,60}$/.test(String(s || ''));
  const symbolOf = (s) => String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9_]+/g, '_').replace(/^_+|_+$/g, '');

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = { open: false, projectPath: null, ctx: null, error: null, outfits: [], index: 0, dirty: false, images: new Map(), filters: {}, tab: 'main' };
  let root = null;
  let renderTimer = null;
  const later = () => { clearTimeout(renderTimer); renderTimer = setTimeout(render, 30); };

  // Image du projet (cache) : undefined = pas encore chargée, null = absente
  function imageOf(dir, name) {
    if (!name) return null;
    const key = dir + '/' + name;
    if (S.images.has(key)) return S.images.get(key);
    S.images.set(key, undefined);
    call('readImage', { projectPath: S.projectPath, dir, name }).then((url) => {
      if (!url) { S.images.set(key, null); later(); return; }
      const img = new Image();
      img.onload = () => { S.images.set(key, img); later(); };
      img.onerror = () => { S.images.set(key, null); later(); };
      img.src = url;
    }).catch(() => { S.images.set(key, null); });
    return undefined;
  }

  const cur = () => S.outfits[S.index] || null;
  const touch = () => { S.dirty = true; const b = document.getElementById('pjw-save'); if (b) b.disabled = false; };
  // sprite de marche (ancien nom : charset)
  const walkOf = (o) => (o && o.sprites && (o.sprites.walk || o.sprites.charset)) || '';
  const spritesOf = (o) => (o.sprites = o.sprites || {});
  const pair = (v) => (Array.isArray(v) ? [v[0] || '', v[1] || ''] : [v || '', v || '']);

  // première case du charset (32x32) sur un canevas, à l'échelle `scale`
  function charCanvas(outfit, scale, cls) {
    const c = h('canvas', { class: cls || 'pjw-icon' });
    const size = 32;
    c.width = size; c.height = size;
    c.style.width = size * scale + 'px'; c.style.height = size * scale + 'px';
    const img = outfit && walkOf(outfit) && imageOf('graphics/characters', walkOf(outfit));
    if (img) {
      const g = c.getContext('2d');
      g.imageSmoothingEnabled = false;
      const fw = img.width / 4, fh = img.height / 4;
      g.drawImage(img, 0, 0, fw, fh, 0, 0, size, size);
    }
    return c;
  }
  function imageCanvas(dir, name, scale, cls) {
    const img = imageOf(dir, name);
    const c = h('canvas', { class: cls || 'pjw-pic' });
    if (!img) { c.width = 8; c.height = 8; return c; }
    c.width = img.width; c.height = img.height;
    c.style.width = img.width * scale + 'px'; c.style.height = img.height * scale + 'px';
    const g = c.getContext('2d'); g.imageSmoothingEnabled = false; g.drawImage(img, 0, 0);
    return c;
  }

  // ---------------------------------------------------------------------------
  // Chargement / enregistrement
  // ---------------------------------------------------------------------------
  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.error = null; S.images = new Map(); S.dirty = false;
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      S.outfits = clone(S.ctx.outfits || []);
      S.outfits.forEach((o) => { if (o.sprites && o.sprites.charset) { o.sprites.walk = o.sprites.walk || o.sprites.charset; delete o.sprites.charset; } });
      S.index = 0;
    } catch (e) { S.error = e.message; }
    render();
  }

  async function save() {
    for (const o of S.outfits) {
      if (!isSymbol(o.item)) { toast(`Objet invalide : « ${o.item || ''} » (minuscules, chiffres et _).`, true); return; }
      if (!Object.values(o.sprites || {}).some(Boolean) && !(o.pieces && Object.keys(o.pieces).length)) { toast(`La tenue « ${o.item} » n'a ni sprites ni pièces.`, true); return; }
    }
    try {
      const r = await call('saveOutfits', { projectPath: S.projectPath, outfits: S.outfits });
      S.dirty = false;
      toast(`${r.count} tenue(s) enregistrée(s) : ${r.written}`);
      render();
    } catch (e) { toast(e.message, true); }
  }

  async function createItem() {
    const o = cur();
    if (!o) return;
    let iconDataUrl = null;
    const canvas = charCanvas(o, 1);
    if (walkOf(o) && imageOf('graphics/characters', walkOf(o))) iconDataUrl = canvas.toDataURL('image/png');
    try {
      const r = await call('createItem', { projectPath: S.projectPath, symbol: o.item, name: pair(o.name), description: pair(o.description), iconDataUrl });
      S.ctx.items = [...S.ctx.items, r.symbol].sort();
      toast(`Objet créé (id ${r.id}). Redémarre Studio pour le voir.` + (r.warnings.length ? ' ' + r.warnings.join(' ') : ''), r.warnings.length > 0);
      render();
    } catch (e) { toast(e.message, true); }
  }

  function addOutfit() {
    let n = S.outfits.length + 1;
    while (S.outfits.some((o) => o.item === 'tenue_' + n)) n++;
    S.outfits.push({ item: 'tenue_' + n, name: ['Nouvelle tenue', 'New outfit'], description: ['', ''] });
    S.index = S.outfits.length - 1;
    touch(); render();
  }
  function removeOutfit() {
    const o = cur();
    if (!o || !window.confirm(`Retirer la tenue « ${o.item} » de la liste ? (L'objet Studio n'est pas supprimé.)`)) return;
    S.outfits.splice(S.index, 1);
    S.index = Math.max(0, Math.min(S.index, S.outfits.length - 1));
    touch(); render();
  }

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    const scroll = root.querySelector('.pjw-main');
    const scrollTop = scroll ? scroll.scrollTop : 0;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const ready = !!S.ctx;
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' },
        h('span', { class: 'pjs-top-title' }, 'Tenues'),
        h('div', { class: 'pjs-tabs' }, [['main', 'Tenue'], ['res', 'Ressources']].map(([id, label]) => h('button', {
          class: 'pjs-tab' + (S.tab === id ? ' active' : ''), disabled: !cur(), onclick: () => { S.tab = id; render(); } }, label)))),
      h('div', { class: 'pjs-topbar-right' },
        h('button', { id: 'pjw-save', class: 'pjs-btn primary', disabled: !ready || !S.dirty, title: 'Écrit Data/configs/plugins/wardrobe.json', onclick: save }, 'Enregistrer'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.ctx) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return; }
    const body = h('div', { class: 'pjw-body' });
    root.removeChild(page);
    body.appendChild(renderList());
    const main = h('div', { class: 'pjs-page pjw-main' });
    main.appendChild(h('div', { class: 'pjs-content pjw-content' }, renderEditor()));
    body.appendChild(main);
    root.appendChild(body);
    const scroller = root.querySelector('.pjw-main');
    if (scroller) scroller.scrollTop = scrollTop;
  }

  function renderList() {
    const block = h('div', { class: 'pjw-list' });
    block.appendChild(h('button', { class: 'pjs-btn primary pjw-new', onclick: addOutfit }, '+ Nouvelle tenue'));
    if (!S.outfits.length) block.appendChild(h('div', { class: 'pjs-hint' }, 'Aucune tenue. « + Nouvelle » en crée une.'));
    S.outfits.forEach((o, i) => {
      block.appendChild(h('button', { class: 'pjw-item' + (i === S.index ? ' active' : ''), onclick: () => { S.index = i; render(); } },
        charCanvas(o, 1, 'pjw-thumb'),
        h('span', { class: 'pjw-item-text' }, h('b', null, pair(o.name)[0] || o.item), h('small', null, o.item + (o.gender ? (o.gender === 'm' ? ' · garçon' : ' · fille') : '')))));
    });
    return block;
  }

  function field(label, control, hint) {
    return h('div', { class: 'pjs-section pjw-line' }, h('span', { class: 'pjs-label' }, label), h('div', { class: 'pjw-control' }, control, hint ? h('div', { class: 'pjs-hint' }, hint) : null));
  }
  function textInput(value, onInput, placeholder, list) {
    const input = h('input', { class: 'pjs-input', value, placeholder, list });
    input.addEventListener('input', () => onInput(input.value));
    return input;
  }

  function renderEditor() {
    const block = h('div', { class: 'pjs-block pjw-editor' });
    const o = cur();
    if (!o) { block.appendChild(h('div', { class: 'pjs-hint' }, 'Choisis ou crée une tenue.')); return block; }
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, pair(o.name)[0] || o.item),
      h('button', { class: 'pjs-btn small', onclick: removeOutfit }, 'Retirer la tenue')));

    if (S.tab === 'res') { block.appendChild(renderResources(o)); return block; }
    // objet : l'état (existe / à créer) se met à jour pendant la frappe, sans refaire la page
    const status = h('span', { class: 'pjw-status' });
    const hint = h('div', { class: 'pjs-hint' });
    const refreshItem = () => {
      const there = S.ctx.items.includes(o.item);
      status.textContent = '';
      if (there) status.appendChild(h('span', { class: 'pjw-ok' }, '✔ existe dans Studio'));
      else status.appendChild(h('button', { class: 'pjs-btn small primary', disabled: !isSymbol(o.item), onclick: createItem, title: 'Crée Data/Studio/items/<objet>.json, son icône et ses textes' }, 'Créer l\'objet'));
      hint.textContent = there ? 'dbSymbol de l\'objet du sac : le donner au joueur lui donne la tenue.'
        : 'Cet objet n\'existe pas : « Créer l\'objet » l\'ajoute (objets rares, icône = première case du charset, textes ci-dessous). Redémarre Studio ensuite.';
    };
    const itemInput = textInput(o.item, (v) => { o.item = symbolOf(v); touch(); refreshItem(); }, 'tenue_sport', 'pjw-items');
    refreshItem();
    block.appendChild(h('div', { class: 'pjs-section pjw-line' }, h('span', { class: 'pjs-label' }, 'Objet'),
      h('div', { class: 'pjw-control' },
        h('div', { class: 'pjw-item-line' }, itemInput, h('datalist', { id: 'pjw-items' }, S.ctx.items.map((s) => h('option', { value: s }))), status), hint)));

    // textes
    const name = pair(o.name), desc = pair(o.description);
    block.appendChild(field('Nom', h('div', { class: 'pjw-two' },
      textInput(name[0], (v) => { name[0] = v; o.name = [name[0], name[1]]; touch(); }, 'Français'),
      textInput(name[1], (v) => { name[1] = v; o.name = [name[0], name[1]]; touch(); }, 'English'))));
    block.appendChild(field('Description', h('div', { class: 'pjw-two' },
      textInput(desc[0], (v) => { desc[0] = v; o.description = [desc[0], desc[1]]; touch(); }, 'Français'),
      textInput(desc[1], (v) => { desc[1] = v; o.description = [desc[0], desc[1]]; touch(); }, 'English'))));
    const gender = h('select', { class: 'pjs-input' }, [['', 'Garçons et filles'], ['m', 'Garçons'], ['f', 'Filles']].map(([v, t]) => h('option', { value: v, selected: (o.gender || '') === v }, t)));
    gender.addEventListener('change', () => { if (gender.value) o.gender = gender.value; else delete o.gender; touch(); render(); });
    block.appendChild(field('Pour', gender, 'La tenue n\'est proposée qu\'aux héros de ce genre.'));

    block.appendChild(renderPieces(o));
    block.appendChild(h('div', { class: 'pjs-hint pjw-tip' }, 'Les sprites tout faits (marche, course, vélo, face, dos…) se choisissent dans l\'onglet « Ressources ».'));
    return block;
  }

  // ---------------------------------------------------------------------------
  // Ressources : un sprite par état du héros (comme Personnages > Héros > Ressources), l'image de face et celle de dos
  // ---------------------------------------------------------------------------
  const loading = new Map();
  // image du projet sans refaire la page : promesse d'une <img> (ou null)
  function getImage(dir, name) {
    const key = dir + '/' + name;
    if (!loading.has(key)) {
      loading.set(key, call('readImage', { projectPath: S.projectPath, dir, name }).then((url) => (url ? new Promise((ok) => {
        const img = new Image(); img.onload = () => ok(img); img.onerror = () => ok(null); img.src = url;
      }) : null)).catch(() => null));
    }
    return loading.get(key);
  }
  // vignette : première case d'un charset (4x4) ou image entière, tenant dans max x max pixels
  function thumb(dir, name, max, charset) {
    const c = h('canvas', { class: 'pjw-pic' });
    c.width = 1; c.height = 1;
    if (!name) { c.classList.add('none'); return c; }
    getImage(dir, name).then((img) => {
      if (!img) { c.classList.add('missing'); c.title = `Image introuvable : ${dir}/${name}.png`; return; }
      const fw = charset ? Math.floor(img.width / 4) : img.width; const fh = charset ? Math.floor(img.height / 4) : img.height;
      const k = Math.max(1, Math.floor(max / Math.max(fw, fh) * 2) / 2);
      c.width = fw; c.height = fh;
      c.style.width = Math.round(fw * Math.min(k, max / Math.max(fw, fh))) + 'px'; c.style.height = Math.round(fh * Math.min(k, max / Math.max(fw, fh))) + 'px';
      const g = c.getContext('2d'); g.imageSmoothingEnabled = false;
      g.drawImage(img, 0, 0, fw, fh, 0, 0, fw, fh);
      c._img = img; c._fw = fw; c._fh = fh;
    });
    return c;
  }
  // fait défiler la marche de la tuile survolée (4 images vers le bas)
  let tick = 0;
  setInterval(() => {
    if (!root) return; tick++;
    root.querySelectorAll('.pjw-res:hover canvas.pjw-pic[data-anim]').forEach((c) => {
      if (!c._img) return;
      const g = c.getContext('2d'); g.clearRect(0, 0, c.width, c.height);
      g.drawImage(c._img, (tick % 4) * c._fw, 0, c._fw, c._fh, 0, 0, c._fw, c._fh);
    });
  }, 160);

  // sélecteur plein écran : grille de vignettes avec recherche
  function openPicker(title, dir, names, current, emptyLabel, charset, onPick, query) {
    const st = { q: query || '', shown: 0, items: [] };
    const grid = h('div', { class: 'pjw-grid' });
    const count = h('span', { class: 'pjs-hint' });
    const sentinel = h('div', { class: 'pjw-sentinel' });
    const close = (value) => { document.removeEventListener('keydown', onKey, true); ov.remove(); if (value !== undefined) onPick(value); };
    const onKey = (e) => { if (e.key === 'Escape') { e.stopPropagation(); close(); } };
    const tile = (name, label) => h('button', { class: 'pjw-tile' + ((name || '') === (current || '') ? ' on' : ''), title: label || name, onclick: () => close(name) },
      name ? thumb(dir, name, 88, charset) : h('div', { class: 'pjw-ph' }, '∅'), h('span', { class: 'n' }, label || name));
    const more = () => {
      st.items.slice(st.shown, st.shown + 60).forEach((n) => grid.insertBefore(tile(n), sentinel));
      st.shown = Math.min(st.items.length, st.shown + 60);
    };
    const update = () => {
      const words = st.q.toLowerCase().split(/\s+/).filter(Boolean);
      st.items = names.filter((n) => { const l = n.toLowerCase(); return words.every((w) => l.includes(w)); });
      grid.textContent = '';
      if (emptyLabel) grid.appendChild(tile('', emptyLabel));
      grid.appendChild(sentinel);
      st.shown = 0; more();
      count.textContent = `${st.items.length} image${st.items.length > 1 ? 's' : ''}`;
    };
    new IntersectionObserver((entries) => { if (entries.some((e) => e.isIntersecting) && st.shown < st.items.length) more(); }, { root: grid, rootMargin: '200px' }).observe(sentinel);
    const search = textInput(st.q, (v) => { st.q = v.trim(); update(); }, 'Rechercher…');
    const ov = h('div', { class: 'pjw-overlay', onmousedown: (e) => { if (e.target === ov) close(); } },
      h('div', { class: 'pjw-picker' },
        h('div', { class: 'pjw-phead' }, h('h3', null, title), count, h('button', { class: 'pjs-btn small', title: 'Fermer (Échap)', onclick: () => close() }, '✕')),
        search, grid));
    ['keydown', 'keypress', 'keyup'].forEach((t) => ov.addEventListener(t, (e) => e.stopPropagation()));
    document.addEventListener('keydown', onKey, true);
    document.body.appendChild(ov);
    update();
    search.focus();
  }

  function resTile(o, key, label, dir, list, charset, fallback) {
    const sp = o.sprites || {};
    const own = key === 'walk' ? walkOf(o) : sp[key];
    const shown = own || (charset && key !== 'walk' ? walkOf(o) : '');
    const auto = charset ? (key === 'walk' ? 'auto (pièces)' : 'auto (marche)') : 'auto (pièces)';
    const pic = thumb(dir, shown, charset ? 64 : 88, charset);
    if (charset) pic.dataset.anim = '1';
    return h('button', { class: 'pjw-res' + (own ? ' own' : '') + (shown ? '' : ' empty'), title: own || auto,
      onclick: () => openPicker(label, dir, list, own, auto, charset, (v) => {
        const sprites = spritesOf(o); delete sprites.charset;
        if (v) sprites[key] = v; else delete sprites[key];
        if (!Object.keys(sprites).length) delete o.sprites;
        touch(); render();
      }, charset && key !== 'walk' ? key.replace(/_/g, ' ') : '') },
    h('div', { class: 'pjw-res-img' }, pic), h('span', { class: 'n' }, label), h('span', { class: 's' }, own || auto));
  }

  function renderResources(o) {
    const block = h('div', { class: 'pjw-resblock' });
    block.appendChild(h('div', { class: 'pjs-hint pjw-tip' }, 'Choisis un sprite pour chaque état du héros avec cette tenue. Sans choix, l\'état reprend la marche, et la marche les pièces du générateur. Survole une case pour la voir marcher.'));
    const chars = S.ctx.characters || [];
    block.appendChild(h('h3', null, 'Personnage sur la carte'));
    block.appendChild(h('div', { class: 'pjw-res-grid' }, STATES.map(([k, l]) => resTile(o, k, l, 'graphics/characters', chars, true))));
    block.appendChild(h('h3', null, 'Autres sprites de PSDK'));
    block.appendChild(h('div', { class: 'pjw-res-grid' }, EXTRA_STATES.map(([k, l]) => resTile(o, k, l, 'graphics/characters', chars, true))));
    block.appendChild(h('h3', null, 'Menus et combat'));
    block.appendChild(h('div', { class: 'pjw-res-grid' }, OTHER.map(([k, l, dir, list]) => resTile(o, k, l, dir, S.ctx[list] || [], false))));
    if (Object.values(o.sprites || {}).some(Boolean)) block.appendChild(h('button', { class: 'pjs-btn small', onclick: () => { delete o.sprites; touch(); render(); } }, 'Retirer tous les sprites tout faits'));
    return block;
  }

  function renderPieces(o) {
    const block = h('div', { class: 'pjw-sub' });
    block.appendChild(h('h3', null, 'Pièces du générateur'));
    const cat = S.ctx.catalog;
    if (!cat) { block.appendChild(h('div', { class: 'pjs-warn' }, 'Les pièces du générateur ne sont pas préparées (Studio : Générateurs > Personnages > Préparer pour le jeu).')); return block; }
    block.appendChild(h('div', { class: 'pjs-hint' }, 'Chaque pièce choisie remplace celle du héros ; « inchangé » la laisse comme elle est. Les sprites tout faits, s\'il y en a, passent avant.'));
    const label = (k) => cat.labels[k] || k;
    const colorLabel = (c) => (c ? cat.colorLabels[c] || c : 'unique');
    CATS.forEach(([id, title, optional]) => {
      const pieces = o.pieces || {};
      const value = id in pieces ? pieces[id] : undefined; // undefined : inchangé, null : aucun
      const keys = (cat.cats[id] || []).filter((p) => !o.gender || p.genders.includes('') || p.genders.includes(o.gender));
      const keySel = h('select', { class: 'pjs-input' },
        h('option', { value: '', selected: value === undefined }, '(inchangé)'),
        optional ? h('option', { value: NONE, selected: value === null }, 'Aucun') : null,
        keys.map((p) => h('option', { value: p.key, selected: !!value && value.key === p.key }, label(p.key))));
      const piece = value ? keys.find((p) => p.key === value.key) : null;
      const colorSel = piece ? h('select', { class: 'pjs-input pjw-color' },
        piece.colors.map((c) => h('option', { value: c, selected: value.color === c }, colorLabel(c)))) : null;
      keySel.addEventListener('change', () => {
        o.pieces = Object.assign({}, o.pieces);
        if (keySel.value === '') delete o.pieces[id];
        else if (keySel.value === NONE) o.pieces[id] = null;
        else { const p = keys.find((x) => x.key === keySel.value); o.pieces[id] = { key: p.key, color: p.colors[0] || '' }; }
        if (!Object.keys(o.pieces).length) delete o.pieces;
        touch(); render();
      });
      if (colorSel) colorSel.addEventListener('change', () => { o.pieces[id].color = colorSel.value; touch(); });
      block.appendChild(field(title, h('div', { class: 'pjw-two' }, keySel, colorSel)));
    });
    return block;
  }

  // ---------------------------------------------------------------------------
  // Page « Plugins > Tenues »
  // ---------------------------------------------------------------------------
  if (!(window.pjPluginPages = window.pjPluginPages || []).some((p) => p.id === PAGE_ID)) window.pjPluginPages.push({ id: PAGE_ID, label: 'Tenues', place: 'generator' });
  window.dispatchEvent(new Event('pj-plugin-pages'));

  function mount(hostEl) {
    root = h('div', { id: 'pjw-root' });
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

  window.pjWardrobeEditor = { state: S, render, save };
})();

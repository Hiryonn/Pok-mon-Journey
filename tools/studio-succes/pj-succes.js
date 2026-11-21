/* eslint-disable */
// =============================================================================
// Succès — page « Level design > Interface > Succès » de Pokémon Studio
//   Création des succès du jeu : nom, description, catégorie, points, secret, icône (trophée, objet, Pokémon),
//   condition pour le débloquer, récompenses ; catégories ; bandeau « Succès obtenu ! » ; aperçu de l'écran du jeu.
// Enregistre Data/configs/plugins/succes.json (plugin « succes », appli « Succès » du téléphone).
// =============================================================================
(() => {
  'use strict';
  if (window.__pjSuccesLoaded) return;
  window.__pjSuccesLoaded = true;

  const PAGE_ID = 'succes';
  const DEFAULTS = { klass: 'SuccesConfig', notify: true, notify_me: 'audio/me/rosa_keyitemobtained', check_every: 30, categories: [], achievements: [] };
  const METALS = [['bronze', 'Bronze'], ['silver', 'Argent'], ['gold', 'Or'], ['platinum', 'Platine']];
  // Conditions : [type, libellé, champs (target / value), aide, objectif affiché en jeu]
  const CONDITIONS = [
    ['manual', 'Par commande seulement', [], 'Débloqué par la commande succes_debloquer(:id) dans un évènement.'],
    ['switch', 'Interrupteur activé', ['switch'], "Débloqué dès que l'interrupteur est activé."],
    ['variable', 'Variable ≥ valeur', ['variable', 'value'], 'Débloqué quand la variable atteint la valeur (barre de progression en jeu).', 'Progression'],
    ['counter', 'Compteur ≥ valeur', ['counter', 'value'], 'Compteur propre aux succès : succes_compteur(:nom, 1) dans un évènement ajoute 1 (par ex. après chaque combat gagné).', 'Progression'],
    ['dex_seen', 'Pokémon vus', ['value'], 'Nombre de Pokémon vus dans le Pokédex.', 'Voir %n Pokémon'],
    ['dex_caught', 'Pokémon capturés', ['value'], 'Nombre de Pokémon capturés dans le Pokédex.', 'Capturer %n Pokémon'],
    ['species', 'Capturer un Pokémon précis', ['species'], 'Débloqué quand ce Pokémon est marqué capturé dans le Pokédex.', 'Capturer %t'],
    ['badges', 'Badges', ['value'], "Nombre de badges d'arène.", 'Obtenir %n badge(s)'],
    ['money', 'Argent', ['value'], "Argent du joueur à un moment donné.", 'Avoir %n P'],
    ['item', 'Avoir un objet', ['item', 'value'], 'Nombre d’exemplaires de l’objet dans le sac.', 'Avoir %t x%n'],
    ['level', 'Niveau d’un Pokémon', ['value'], "Un Pokémon de l'équipe atteint ce niveau.", 'Un Pokémon au niveau %n'],
    ['steps', 'Pas', ['value'], 'Nombre de pas faits dans le jeu.', 'Faire %n pas'],
    ['play_time', 'Temps de jeu (heures)', ['value'], 'Heures de jeu.', 'Jouer %n heure(s)'],
    ['quests', 'Quêtes terminées', ['value'], 'Nombre de quêtes terminées (Données > Quêtes).', 'Terminer %n quête(s)'],
    ['berries', 'Baies du Berrydex', ['value'], 'Nombre de baies trouvées dans le Berrydex.', 'Trouver %n baie(s)'],
    ['achievements', 'Autres succès obtenus', ['value'], 'Nombre d’autres succès obtenus (pour un succès « Platine », par exemple).', 'Obtenir %n autre(s) succès'],
  ];
  const condInfo = (type) => CONDITIONS.find((c) => c[0] === type) || CONDITIONS[0];

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjSucces;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API des Succès n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const plain = (t) => String(t || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  const slug = (t) => plain(t).replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 40) || 'succes';
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
  const txt = (v, lang = 'fr') => (v && typeof v === 'object' ? (v[lang] || v.fr || v.en || '') : String(v || ''));

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  // Identifiants faits automatiquement (suivent le nom tant qu'on ne les change pas à la main)
  const autoIds = new Set();
  const S = { open: false, projectPath: null, ctx: null, config: null, saved: null, error: null, building: false, selected: null, view: 0, search: '', filter: '' };
  let root = null;
  const snapshot = () => JSON.stringify(S.config);
  const dirty = () => S.config && S.saved !== snapshot();
  const list = () => S.config.achievements;
  const current = () => list().find((a) => a.id === S.selected);
  const itemOf = (db) => S.ctx.items.find((i) => i.db === db);
  const creatureOf = (db) => S.ctx.creatures.find((c) => c.db === db);
  const categoryName = (id) => { const c = S.config.categories.find((x) => x.id === id); return c ? txt(c.name) : ''; };

  // Remet un succès dans la forme attendue par le jeu
  function normalize(a) {
    a.name = Object.assign({ fr: '', en: '' }, typeof a.name === 'object' ? a.name : { fr: a.name || '' });
    a.descr = Object.assign({ fr: '', en: '' }, typeof a.descr === 'object' ? a.descr : { fr: a.descr || '' });
    a.icon = Object.assign({ kind: 'trophy', value: 'gold' }, a.icon || {});
    a.condition = Object.assign({ type: 'manual' }, a.condition || {});
    a.rewards = Object.assign({ money: 0, items: [] }, a.rewards || {});
    if (!Array.isArray(a.rewards.items)) a.rewards.items = [];
    a.points = a.points | 0;
    a.secret = !!a.secret;
    a.category = a.category || '';
    return a;
  }
  function uniqueId(base, except) {
    let id = slug(base); let n = 2;
    const taken = (x) => list().some((a) => a !== except && a.id === x);
    while (taken(id)) id = `${slug(base)}_${n++}`;
    return id;
  }

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.error = null;
    imageCache.clear();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      S.config = Object.assign(clone(DEFAULTS), S.ctx.config || {});
      if (!Array.isArray(S.config.categories)) S.config.categories = [];
      if (!Array.isArray(S.config.achievements)) S.config.achievements = [];
      S.config.achievements = S.config.achievements.filter((a) => a && a.id).map(normalize);
      S.saved = S.ctx.config ? snapshot() : null;
      if (!current()) S.selected = list()[0] && list()[0].id;
    } catch (e) { S.error = e.message; }
    render();
  }
  function problems() {
    const out = [];
    const ids = new Set();
    for (const a of list()) {
      if (!a.id) out.push('Un succès n’a pas d’identifiant.');
      else if (ids.has(a.id)) out.push(`Identifiant en double : ${a.id}`);
      ids.add(a.id);
      if (!txt(a.name).trim()) out.push(`« ${a.id} » n’a pas de nom.`);
      const t = a.condition.type;
      if (t === 'species' && !a.condition.target) out.push(`« ${txt(a.name) || a.id} » : choisis le Pokémon à capturer.`);
      if (t === 'item' && !a.condition.target) out.push(`« ${txt(a.name) || a.id} » : choisis l’objet.`);
      if ((t === 'switch' || t === 'variable') && !(a.condition.target > 0)) out.push(`« ${txt(a.name) || a.id} » : indique le numéro ${t === 'switch' ? 'de l’interrupteur' : 'de la variable'}.`);
      if (t === 'counter' && !String(a.condition.target || '').trim()) out.push(`« ${txt(a.name) || a.id} » : donne un nom au compteur.`);
    }
    return out;
  }
  async function save() {
    if (!S.config) return;
    const p = problems();
    if (p.length) { toast('À corriger avant d’enregistrer : ' + p[0], true); return; }
    try {
      for (const a of list()) {
        a.rewards.items = a.rewards.items.filter((r) => r.item);
        const t = a.condition.type; const info = condInfo(t)[2];
        a.condition = { type: t, ...(info.some((f) => f !== 'value') && a.condition.target !== undefined ? { target: a.condition.target } : {}), ...(info.includes('value') ? { value: Math.max(1, a.condition.value | 0) } : {}) };
      }
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
  // Modification sans tout redessiner (champs texte) : aperçu et liste mis à jour
  const soft = (fn) => { fn(); updateStatus(); refreshLive(); };

  // ---------------------------------------------------------------------------
  // Actions sur la liste
  // ---------------------------------------------------------------------------
  function addAchievement(base) {
    const a = normalize(base ? clone(base) : { name: { fr: 'Nouveau succès', en: '' }, descr: { fr: '', en: '' }, points: 10, category: S.filter || (S.config.categories[0] && S.config.categories[0].id) || '' });
    a.id = uniqueId(base ? a.id : txt(a.name), null);
    autoIds.add(a.id);
    if (base) a.name.fr = txt(a.name) + ' (copie)';
    const i = base ? list().indexOf(base) + 1 : list().length;
    list().splice(i, 0, a);
    S.selected = a.id;
    render();
    const el = root.querySelector('[data-focus="name-fr"]');
    if (el) { el.focus(); el.select(); }
  }
  function removeAchievement(a) {
    if (!confirm(`Supprimer le succès « ${txt(a.name)} » ?`)) return;
    const i = list().indexOf(a);
    list().splice(i, 1);
    S.selected = (list()[i] || list()[i - 1] || {}).id;
    render();
  }
  function moveAchievement(a, delta) {
    const i = list().indexOf(a); const j = i + delta;
    if (j < 0 || j >= list().length) return;
    [list()[i], list()[j]] = [list()[j], list()[i]];
    render();
  }

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    const prevList = root.querySelector('.pjsc-list');
    const listScroll = prevList ? prevList.scrollTop : 0;
    const prev = root.querySelector('.pjsc-detail');
    const scroll = prev ? prev.scrollTop : 0;
    const focused = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.focus : null;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    const [statusTxt, statusCls] = statusText();
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' }, h('span', { class: 'pjs-top-title' }, 'Succès'),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusCls }, statusTxt),
        h('button', { class: 'pjs-btn secondary', onclick: () => { if (!dirty() || confirm('Abandonner les modifications non enregistrées ?')) loadProject(S.projectPath); } }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    if (S.error) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty err' }, S.error))); return; }
    if (!S.config) { root.appendChild(h('div', { class: 'pjs-page' }, h('div', { class: 'pjs-empty' }, 'Chargement…'))); return; }
    const body = h('div', { class: 'pjsc-body' });
    root.appendChild(body);
    body.appendChild(renderSidebar());
    const detail = h('div', { class: 'pjsc-detail' });
    body.appendChild(detail);
    const content = h('div', { class: 'pjsc-content' });
    detail.appendChild(content);
    const p = S.ctx.plugin;
    if (p && !p.source) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le dossier scripts/succes est introuvable.'));
    else if (p && !p.installed) content.appendChild(h('div', { class: 'pjs-warn' }, "Le plugin « succes » n'est pas encore installé : lance construire_plugins.bat une fois (ensuite, Enregistrer le met à jour tout seul)."));
    const a = current();
    if (!a) {
      content.appendChild(h('div', { class: 'pjs-empty' }, h('div', null, 'Aucun succès pour l’instant.'),
        h('button', { class: 'pjs-btn primary pjsc-mt', onclick: () => addAchievement() }, '+ Créer un succès')));
    } else {
      const row = h('div', { class: 'pjsc-row' });
      content.appendChild(row);
      row.appendChild(renderPreview());
      const right = h('div', { class: 'pjsc-right' });
      row.appendChild(right);
      right.appendChild(renderGeneral(a));
      right.appendChild(renderIcon(a));
      right.appendChild(renderCondition(a));
      right.appendChild(renderRewards(a));
    }
    const row2 = h('div', { class: 'pjsc-row2' });
    content.appendChild(row2);
    row2.appendChild(renderCategories());
    row2.appendChild(renderSettings());
    content.appendChild(renderCommands());
    detail.scrollTop = scroll;
    const l = root.querySelector('.pjsc-list');
    if (l) l.scrollTop = listScroll;
    if (focused) { const el = root.querySelector(`[data-focus="${focused}"]`); if (el) { el.focus(); if (el.setSelectionRange && typeof el.value === 'string' && el.type !== 'number') el.setSelectionRange(el.value.length, el.value.length); } }
  }

  const block = (title, extra, ...kids) => h('div', { class: 'pjs-block' }, h('div', { class: 'pjs-block-head' }, h('h2', null, title), extra || null), kids);
  const field = (label, input, hint) => h('label', { class: 'pjsc-field' }, h('span', { class: 'pjs-label' }, label), input, hint ? h('span', { class: 'pjs-hint inline' }, hint) : null);
  const iconBox = (a, cls = 'pjsc-ico') => {
    const el = h('span', { class: cls });
    iconUrl(a).then((u) => { if (u) el.style.backgroundImage = `url("${u}")`; });
    return el;
  };
  async function iconImage(a) {
    const ic = a.icon || {};
    if (ic.kind === 'item') { const it = itemOf(ic.value); return it && it.icon ? loadImage(`graphics/icons/${it.icon}`) : null; }
    if (ic.kind === 'pokemon') { const c = creatureOf(ic.value); return c && c.icon ? loadImage(`graphics/pokedex/pokeicon/${c.icon}`) : null; }
    return loadImage(`graphics/interface/succes/trophy_${METALS.some((m) => m[0] === ic.value) ? ic.value : 'gold'}`);
  }
  async function iconUrl(a) {
    const im = await iconImage(a);
    if (!im) return null;
    if (a.icon.kind !== 'pokemon' || im.width <= im.height) return im.src;
    const c = document.createElement('canvas'); c.width = im.height; c.height = im.height;
    c.getContext('2d').drawImage(im, 0, 0);
    return c.toDataURL();
  }

  // --- Liste des succès ---------------------------------------------------------------------
  function renderSidebar() {
    const side = h('div', { class: 'pjsc-side' });
    side.appendChild(h('button', { class: 'pjs-btn primary pjsc-add', onclick: () => addAchievement() }, '+ Nouveau succès'));
    side.appendChild(h('input', { class: 'pjs-input', placeholder: 'Rechercher…', value: S.search, 'data-focus': 'search', oninput: (e) => { S.search = e.target.value; render(); } }));
    const filter = h('select', { class: 'pjs-input', onchange: (e) => set(() => { S.filter = e.target.value; }) },
      h('option', { value: '' }, 'Toutes les catégories'), S.config.categories.map((c) => h('option', { value: c.id }, txt(c.name) || c.id)));
    filter.value = S.filter;
    side.appendChild(filter);
    const box = h('div', { class: 'pjsc-list' });
    side.appendChild(box);
    const q = plain(S.search);
    const all = list();
    all.forEach((a, i) => {
      if (S.filter && a.category !== S.filter) return;
      if (q && !plain(txt(a.name)).includes(q) && !a.id.includes(q)) return;
      box.appendChild(h('div', { class: 'pjsc-entry' + (a.id === S.selected ? ' active' : ''), 'data-id': a.id, onclick: () => set(() => { S.selected = a.id; }) },
        iconBox(a),
        h('span', { class: 'pjsc-ename' }, h('span', { class: 'pjsc-name' }, txt(a.name) || a.id),
          h('span', { class: 'pjsc-sub' }, [categoryName(a.category), condInfo(a.condition.type)[1]].filter(Boolean).join(' · '))),
        a.secret ? h('span', { class: 'pjsc-tag', title: 'Secret' }, '🔒') : null,
        a.points ? h('span', { class: 'pjsc-pts' }, a.points) : null,
        !q && !S.filter ? h('span', { class: 'pjsc-move' },
          h('button', { class: 'pjsc-x', title: 'Monter', disabled: i === 0, onclick: (e) => { e.stopPropagation(); moveAchievement(a, -1); } }, '▲'),
          h('button', { class: 'pjsc-x', title: 'Descendre', disabled: i === all.length - 1, onclick: (e) => { e.stopPropagation(); moveAchievement(a, 1); } }, '▼')) : null));
    });
    const pts = all.reduce((s, a) => s + (a.points | 0), 0);
    side.appendChild(h('div', { class: 'pjs-hint pjsc-count' }, `${all.length} succès · ${pts} points en tout`));
    return side;
  }
  // Met à jour la ligne de la liste et l'aperçu après une saisie
  function refreshLive() {
    const a = current();
    if (!a || !root) return;
    const entry = root.querySelector(`.pjsc-entry[data-id="${CSS.escape(a.id)}"] .pjsc-name`);
    if (entry) entry.textContent = txt(a.name) || a.id;
    const cv = root.querySelector('.pjsc-canvas');
    if (cv) drawPreview(cv);
  }

  // --- Aperçu (écran du jeu, 320 x 240) --------------------------------------------------------
  const VIEWS = ['Liste', 'Fiche', 'Bandeau'];
  function renderPreview() {
    const box = h('div', { class: 'pjs-block pjsc-preview' });
    box.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Aperçu en jeu'),
      h('div', { class: 'pjsc-tabs' }, VIEWS.map((v, i) => h('button', { class: 'pjs-btn small ' + (S.view === i ? 'primary' : 'secondary'), onclick: () => set(() => { S.view = i; }) }, v)))));
    const cv = h('canvas', { class: 'pjsc-canvas', width: 320, height: 240 });
    box.appendChild(cv);
    drawPreview(cv);
    box.appendChild(h('div', { class: 'pjs-hint' }, [
      'Liste : succès obtenus (coche verte, date) et en cours (barre de progression) ; les succès secrets restent cachés jusqu’à leur obtention.',
      'Fiche : ouverte avec A depuis la liste ; montre l’objectif, la progression, la récompense et la date.',
      'Bandeau : affiché en haut de la carte quand un succès est obtenu (désactivable plus bas).'][S.view]));
    return box;
  }
  const COL = { light: '#e5f3fa', dark: '#282828', white: '#fff' };
  let drawToken = 0;
  async function drawPreview(cv) {
    const token = ++drawToken;
    const img = (n) => loadImage('graphics/interface/' + n);
    const names = ['horizon/team/fond', 'horizon/header', 'horizon/tcard/button_background', 'succes/row', 'succes/row_selected', 'succes/row_done', 'succes/frame', 'succes/lock', 'succes/check', 'succes/points', 'succes/bar', 'succes/bar_fill', 'succes/card', 'succes/bar_big', 'succes/bar_big_fill', 'succes/toast', 'horizon/quest/arrow_frame_l', 'horizon/quest/arrow_frame_r'];
    const I = {};
    (await Promise.all(names.map(img))).forEach((im, i) => { I[names[i].split('/').pop()] = im; });
    const a = current();
    const shown = list().slice(0, 5);
    if (a && !shown.includes(a)) shown[4] = a;
    const icons = await Promise.all(shown.map((x) => iconImage(x)));
    const aIcon = a ? await iconImage(a) : null;
    if (token !== drawToken) return;
    const c = cv.getContext('2d');
    c.imageSmoothingEnabled = false;
    const draw = (im, x, y) => { if (im) c.drawImage(im, x, y); };
    const text = (s, x, y, o = {}) => {
      c.font = `${o.small ? 9 : 11}px "Avenir Next", sans-serif`;
      c.fillStyle = o.color || COL.dark; c.textBaseline = 'top'; c.textAlign = o.align || 'left';
      c.fillText(s, x, y);
    };
    const icon = (x, im, ax, ay, kind) => {
      if (!im) return;
      const w = kind === 'pokemon' && im.width > im.height ? im.height : im.width;
      c.drawImage(im, 0, 0, w, im.height, ax + Math.floor((32 - w) / 2), ay + Math.floor((32 - im.height) / 2), w, im.height);
    };
    c.fillStyle = COL.light; c.fillRect(0, 0, 320, 240);
    if (S.view === 2) {
      // bandeau sur une carte (fond neutre)
      c.fillStyle = '#7fb069'; c.fillRect(0, 0, 320, 240);
      c.fillStyle = '#9ccc80'; for (let y = 0; y < 240; y += 16) for (let x = (y / 16) % 2 ? 0 : 16; x < 320; x += 32) c.fillRect(x, y, 16, 16);
      if (!a) return;
      draw(I.toast, 56, 4);
      icon(0, aIcon, 56, 4, a.icon.kind);
      text('Succès obtenu !', 92, 7, { small: true });
      if (a.points) text(`${a.points} pts`, 260, 7, { small: true, align: 'right' });
      text(txt(a.name), 92, 19);
      return;
    }
    draw(I.fond, 0, 0); draw(I.header, 0, 0); draw(I.button_background, 0, 214);
    const pts = list().slice(0, 2).reduce((s, x) => s + (x.points | 0), 0);
    text(`${pts} pts`, 6, 9, { small: true, color: COL.white });
    text(`2 / ${list().length}`, 314, 9, { small: true, color: COL.white, align: 'right' });
    if (S.view === 0) {
      text('SUCCÈS', 160, 7, { align: 'center', color: COL.white });
      if (S.config.categories.length) { draw(I.arrow_frame_l, 84, 6); draw(I.arrow_frame_r, 228, 6); }
      text(S.config.categories.length ? 'A : Détails   < > : Catégorie   B : Quitter' : 'A : Détails   B : Quitter', 160, 222, { small: true, color: COL.white, align: 'center' });
      shown.forEach((x, i) => {
        const y = 30 + i * 36;
        const done = i < 2 && x !== a; // aperçu : les deux premiers « obtenus »
        const secret = x.secret && !done && x !== a;
        draw(x === a ? I.row_selected : done ? I.row_done : I.row, 6, y);
        draw(I.frame, 8, y + 1);
        if (secret) draw(I.lock, 12, y + 5);
        else { c.globalAlpha = done ? 1 : 0.45; icon(0, icons[i], 8, y + 1, x.icon.kind); c.globalAlpha = 1; }
        text(secret ? 'Succès secret' : txt(x.name), 46, y + 4);
        const d = secret ? '???' : txt(x.descr).replace(/[’‘]/g, "'");
        text(d.length > 36 ? d.slice(0, 33).trimEnd() + '...' : d, 46, y + 21, { small: true });
        if (x.points) { draw(I.points, 278, y + 3); text(String(x.points), 293, y + 5, { small: true, color: COL.white, align: 'center' }); }
        if (done) { draw(I.check, 260, y + 3); text('16/11/2026', 308, y + 21, { small: true, align: 'right' }); }
        else if (!secret && condInfo(x.condition.type)[2].includes('value')) {
          const goal = Math.max(1, x.condition.value | 0);
          text(`0/${goal}`, 242, y + 5, { small: true });
          draw(I.bar, 242, y + 22);
        }
      });
      return;
    }
    // fiche
    if (!a) return;
    text(categoryName(a.category) || 'SUCCÈS', 160, 7, { align: 'center', color: COL.white });
    text('Haut / Bas : Succès   B : Retour', 160, 222, { small: true, color: COL.white, align: 'center' });
    draw(I.card, 6, 32);
    draw(I.frame, 16, 42);
    icon(0, aIcon, 16, 42, a.icon.kind);
    text(txt(a.name), 56, 42);
    text(categoryName(a.category), 56, 60, { small: true });
    if (a.points) { draw(I.points, 274, 42); text(String(a.points), 289, 44, { small: true, color: COL.white, align: 'center' }); }
    wrap(c, txt(a.descr).replace(/[’‘]/g, "'"), 16, 84, 288, 13, text);
    const info = condInfo(a.condition.type);
    if (info[4]) {
      const goalTxt = info[4].replace('%n', Math.max(1, a.condition.value | 0)).replace('%t', targetName(a));
      text(goalTxt, 16, 152, { small: true });
    }
    if (info[2].includes('value')) {
      text(`0 / ${Math.max(1, a.condition.value | 0)}`, 304, 152, { small: true, align: 'right' });
      draw(I.bar_big, 12, 164);
    }
    const reward = rewardText(a);
    if (reward) text(`Récompense : ${reward}`, 16, 178, { small: true });
    text('Pas encore obtenu', 16, 194, { small: true });
  }
  function wrap(c, str, x, y, w, lh, text) {
    c.font = '9px "Avenir Next", sans-serif';
    let line = ''; let yy = y;
    String(str).split(/\s+/).forEach((word) => {
      const t = line ? line + ' ' + word : word;
      if (c.measureText(t).width > w && line) { text(line, x, yy, { small: true }); line = word; yy += lh; } else line = t;
    });
    if (line) text(line, x, yy, { small: true });
  }
  function targetName(a) {
    const t = a.condition.target;
    if (a.condition.type === 'species') { const cr = creatureOf(t); return cr ? cr.name : t || '?'; }
    if (a.condition.type === 'item') { const it = itemOf(t); return it ? it.name : t || '?'; }
    return t || '';
  }
  function rewardText(a) {
    const parts = [];
    if ((a.rewards.money | 0) > 0) parts.push(`${a.rewards.money} P`);
    a.rewards.items.forEach((r) => { const it = itemOf(r.item); if (it) parts.push((r.quantity | 0) > 1 ? `${it.name} x${r.quantity}` : it.name); });
    return parts.join(', ');
  }

  // --- Général ------------------------------------------------------------------------------
  function renderGeneral(a) {
    const box = block('Succès', h('div', { class: 'pjsc-actions' },
      h('button', { class: 'pjs-btn small secondary', onclick: () => addAchievement(a) }, 'Dupliquer'),
      h('button', { class: 'pjs-btn small danger', onclick: () => removeAchievement(a) }, 'Supprimer')));
    box.appendChild(h('div', { class: 'pjsc-grid2' },
      field('Nom (français)', h('input', { class: 'pjs-input', 'data-focus': 'name-fr', value: a.name.fr, oninput: (e) => soft(() => { a.name.fr = e.target.value; followName(a); }) })),
      field('Nom (anglais)', h('input', { class: 'pjs-input', 'data-focus': 'name-en', placeholder: a.name.fr, value: a.name.en, oninput: (e) => soft(() => { a.name.en = e.target.value; }) }))));
    box.appendChild(h('div', { class: 'pjsc-grid2' },
      field('Description (français)', h('textarea', { class: 'pjs-input pjsc-area', rows: 2, 'data-focus': 'descr-fr', value: a.descr.fr, oninput: (e) => soft(() => { a.descr.fr = e.target.value; }) })),
      field('Description (anglais)', h('textarea', { class: 'pjs-input pjsc-area', rows: 2, 'data-focus': 'descr-en', placeholder: a.descr.fr, value: a.descr.en, oninput: (e) => soft(() => { a.descr.en = e.target.value; }) }))));
    const cat = h('select', { class: 'pjs-input', onchange: (e) => set(() => { a.category = e.target.value; }) },
      h('option', { value: '' }, 'Aucune (seulement dans « Tous »)'), S.config.categories.map((c) => h('option', { value: c.id }, txt(c.name) || c.id)));
    cat.value = a.category;
    box.appendChild(h('div', { class: 'pjsc-grid4' },
      field('Catégorie', cat),
      field('Points', h('input', { class: 'pjs-input', type: 'number', min: 0, max: 9999, 'data-focus': 'points', value: a.points, oninput: (e) => soft(() => { a.points = Math.max(0, e.target.value | 0); }) })),
      field('Identifiant', h('input', { class: 'pjs-input pjsc-mono', 'data-focus': 'id', value: a.id,
        onchange: (e) => set(() => { const id = uniqueId(e.target.value || txt(a.name), a); autoIds.delete(a.id); a.id = id; S.selected = id; }) }), 'pour les commandes'),
      h('div', { class: 'pjsc-field pjsc-end' }, h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: a.secret, onchange: (e) => set(() => { a.secret = e.target.checked; }) }), 'Secret'),
        h('span', { class: 'pjs-hint inline' }, 'caché (« ??? ») avant d’être obtenu'))));
    return box;
  }

  // Nouvel identifiant d'après le nom (succès créé ici, identifiant pas encore choisi à la main)
  function followName(a) {
    if (!autoIds.has(a.id) || !txt(a.name).trim()) return;
    const old = a.id;
    const id = uniqueId(txt(a.name), a);
    if (id === old) return;
    autoIds.delete(old); autoIds.add(id);
    a.id = id; S.selected = id;
    const entry = root.querySelector(`.pjsc-entry[data-id="${CSS.escape(old)}"]`);
    if (entry) entry.dataset.id = id;
    const input = root.querySelector('[data-focus="id"]');
    if (input) input.value = id;
  }

  // --- Icône ---------------------------------------------------------------------------------
  function renderIcon(a) {
    const box = block('Icône');
    const kinds = [['trophy', 'Trophée'], ['item', 'Objet'], ['pokemon', 'Pokémon']];
    box.appendChild(h('div', { class: 'pjsc-seg' }, kinds.map(([k, label]) => h('button', { class: 'pjs-btn small ' + (a.icon.kind === k ? 'primary' : 'secondary'),
      onclick: () => set(() => { a.icon = { kind: k, value: k === 'trophy' ? 'gold' : k === 'item' ? 'poke_ball' : (S.ctx.creatures[0] || {}).db }; }) }, label))));
    if (a.icon.kind === 'trophy') {
      box.appendChild(h('div', { class: 'pjsc-metals' }, METALS.map(([m, label]) => {
        const ic = h('span', { class: 'pjsc-bigico' });
        loadImage(`graphics/interface/succes/trophy_${m}`).then((im) => { if (im) ic.style.backgroundImage = `url("${im.src}")`; });
        return h('button', { class: 'pjsc-metal' + (a.icon.value === m ? ' on' : ''), onclick: () => set(() => { a.icon.value = m; }) }, ic, label);
      })));
    } else {
      const options = a.icon.kind === 'item' ? S.ctx.items : S.ctx.creatures;
      box.appendChild(h('div', { class: 'pjsc-pick' }, iconBox(a, 'pjsc-bigico'), picker(options, a.icon.value, (v) => set(() => { a.icon.value = v; }), a.icon.kind === 'pokemon')));
    }
    return box;
  }
  // Liste déroulante avec recherche (objets ou Pokémon)
  function picker(options, value, onPick, numbered) {
    const wrapEl = h('div', { class: 'pjsc-picker' });
    const sel = h('select', { class: 'pjs-input', onchange: (e) => onPick(e.target.value) });
    const fill = (q) => {
      sel.textContent = '';
      const qq = plain(q);
      let shown = options.filter((o) => !qq || plain(o.name).includes(qq) || o.db.includes(qq)).slice(0, 400);
      const cur = options.find((o) => o.db === value);
      if (cur && !shown.includes(cur)) shown = [cur].concat(shown);
      shown.forEach((o) => sel.appendChild(h('option', { value: o.db }, (numbered ? String(o.id).padStart(4, '0') + ' ' : '') + o.name)));
      if (!cur) sel.insertBefore(h('option', { value: '' }, '— choisir —'), sel.firstChild);
      sel.value = cur ? value : '';
    };
    const search = h('input', { class: 'pjs-input pjsc-psearch', placeholder: 'Filtrer…', oninput: (e) => fill(e.target.value) });
    fill('');
    wrapEl.appendChild(search); wrapEl.appendChild(sel);
    return wrapEl;
  }

  // --- Condition ---------------------------------------------------------------------------
  function renderCondition(a) {
    const box = block('Condition pour l’obtenir');
    const cond = a.condition;
    const info = condInfo(cond.type);
    const type = h('select', { class: 'pjs-input', onchange: (e) => set(() => {
      const t = e.target.value; const keep = cond.value;
      a.condition = { type: t };
      if (condInfo(t)[2].includes('value')) a.condition.value = keep > 0 ? keep : 1;
    }) }, CONDITIONS.filter((c) => c[0] !== 'berries' || S.ctx.berrydex || cond.type === 'berries').map((c) => h('option', { value: c[0] }, c[1])));
    type.value = cond.type;
    const fields = [field('Type', type)];
    info[2].forEach((f) => {
      if (f === 'value') fields.push(field(cond.type === 'level' ? 'Niveau' : cond.type === 'play_time' ? 'Heures' : cond.type === 'item' ? 'Quantité' : 'Valeur à atteindre',
        h('input', { class: 'pjs-input', type: 'number', min: 1, max: cond.type === 'level' ? 100 : 99999999, 'data-focus': 'cond-value', value: cond.value || 1, oninput: (e) => soft(() => { cond.value = Math.max(1, e.target.value | 0); }) })));
      if (f === 'switch' || f === 'variable') fields.push(field(f === 'switch' ? 'N° de l’interrupteur' : 'N° de la variable',
        h('input', { class: 'pjs-input', type: 'number', min: 1, 'data-focus': 'cond-target', value: cond.target || '', oninput: (e) => soft(() => { cond.target = Math.max(0, e.target.value | 0); }) })));
      if (f === 'counter') fields.push(field('Nom du compteur', h('input', { class: 'pjs-input pjsc-mono', 'data-focus': 'cond-target', placeholder: 'combats_gagnes', value: cond.target || '',
        oninput: (e) => soft(() => { cond.target = slug(e.target.value).replace(/^succes$/, ''); }), onchange: () => render() })));
      if (f === 'species') fields.push(field('Pokémon', picker(S.ctx.creatures, cond.target, (v) => set(() => { cond.target = v; }), true)));
      if (f === 'item') fields.push(field('Objet', picker(S.ctx.items, cond.target, (v) => set(() => { cond.target = v; }))));
    });
    box.appendChild(h('div', { class: 'pjsc-grid3' }, fields));
    box.appendChild(h('div', { class: 'pjs-hint' }, info[3]));
    if (cond.type === 'counter' && cond.target) box.appendChild(h('div', { class: 'pjsc-cmdrow' }, h('code', { class: 'pjsc-cmd', title: 'Cliquer pour copier', onclick: () => copy(`succes_compteur(:${cond.target}, 1)`) }, `succes_compteur(:${cond.target}, 1)`), h('span', { class: 'pjs-hint inline' }, 'à mettre dans l’évènement qui fait avancer le compteur')));
    if (cond.type === 'manual') box.appendChild(h('div', { class: 'pjsc-cmdrow' }, h('code', { class: 'pjsc-cmd', title: 'Cliquer pour copier', onclick: () => copy(`succes_debloquer(:${a.id})`) }, `succes_debloquer(:${a.id})`), h('span', { class: 'pjs-hint inline' }, 'commande Script de l’évènement qui donne le succès')));
    if (cond.type === 'quests' && !S.ctx.quests) box.appendChild(h('div', { class: 'pjs-hint' }, 'Le projet n’a pas encore de quête.'));
    return box;
  }
  function copy(t) { try { navigator.clipboard.writeText(t); toast('Copié'); } catch (e) { /* rien */ } }

  // --- Récompenses -------------------------------------------------------------------------
  function renderRewards(a) {
    const box = block('Récompense', h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => { a.rewards.items.push({ item: 'potion', quantity: 1 }); }) }, '+ Objet'));
    box.appendChild(h('div', { class: 'pjsc-grid4' }, field('Argent', h('input', { class: 'pjs-input', type: 'number', min: 0, 'data-focus': 'money', value: a.rewards.money || 0, oninput: (e) => soft(() => { a.rewards.money = Math.max(0, e.target.value | 0); }) }), 'P')));
    a.rewards.items.forEach((r, i) => {
      const ic = h('span', { class: 'pjsc-ico' });
      const it = itemOf(r.item);
      if (it && it.icon) loadImage(`graphics/icons/${it.icon}`).then((im) => { if (im) ic.style.backgroundImage = `url("${im.src}")`; });
      box.appendChild(h('div', { class: 'pjsc-reward' }, ic, picker(S.ctx.items, r.item, (v) => set(() => { r.item = v; })),
        h('input', { class: 'pjs-input pjsc-qty', type: 'number', min: 1, max: 999, 'data-focus': 'qty-' + i, value: r.quantity || 1, oninput: (e) => soft(() => { r.quantity = Math.max(1, e.target.value | 0); }) }),
        h('button', { class: 'pjsc-x', title: 'Retirer', onclick: () => set(() => { a.rewards.items.splice(i, 1); }) }, '✕')));
    });
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Donnée automatiquement au joueur quand il obtient le succès.'));
    return box;
  }

  // --- Catégories --------------------------------------------------------------------------
  function renderCategories() {
    const cats = S.config.categories;
    const box = block('Catégories', h('button', { class: 'pjs-btn small secondary', onclick: () => set(() => {
      let id = 'categorie'; let n = 2; while (cats.some((c) => c.id === id)) id = `categorie_${n++}`;
      cats.push({ id, name: { fr: 'Nouvelle catégorie', en: 'New category' } });
    }) }, '+ Catégorie'));
    if (!cats.length) box.appendChild(h('div', { class: 'pjs-hint' }, 'Sans catégorie, tous les succès sont dans une seule liste.'));
    cats.forEach((c, i) => {
      const count = list().filter((a) => a.category === c.id).length;
      box.appendChild(h('div', { class: 'pjsc-cat' },
        h('input', { class: 'pjs-input', 'data-focus': 'cat-fr-' + i, value: txt(c.name, 'fr'), placeholder: 'Nom', oninput: (e) => soft(() => { c.name = Object.assign({}, c.name, { fr: e.target.value }); }), onchange: () => render() }),
        h('input', { class: 'pjs-input', 'data-focus': 'cat-en-' + i, value: (c.name && c.name.en) || '', placeholder: 'English', oninput: (e) => soft(() => { c.name = Object.assign({}, c.name, { en: e.target.value }); }) }),
        h('span', { class: 'pjs-hint inline pjsc-catn' }, `${count} succès`),
        h('button', { class: 'pjsc-x', title: 'Monter', disabled: i === 0, onclick: () => set(() => { [cats[i - 1], cats[i]] = [cats[i], cats[i - 1]]; }) }, '▲'),
        h('button', { class: 'pjsc-x', title: 'Supprimer', onclick: () => { if (!count || confirm(`${count} succès sont dans cette catégorie : ils n’auront plus de catégorie.`)) set(() => { cats.splice(i, 1); list().forEach((a) => { if (a.category === c.id) a.category = ''; }); if (S.filter === c.id) S.filter = ''; }); } }, '✕')));
    });
    box.appendChild(h('div', { class: 'pjs-hint' }, 'En jeu : gauche / droite changent de catégorie (« Tous » en premier). Les catégories vides ne s’affichent pas.'));
    return box;
  }

  // --- Réglages ----------------------------------------------------------------------------
  let audio = null;
  function renderSettings() {
    const c = S.config;
    const box = block('Bandeau « Succès obtenu ! »');
    box.appendChild(h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: c.notify !== false, onchange: (e) => set(() => { c.notify = e.target.checked; }) }), 'Afficher le bandeau quand un succès est obtenu'));
    const me = h('select', { class: 'pjs-input', onchange: (e) => set(() => { c.notify_me = e.target.value; }) }, h('option', { value: '' }, 'Aucune musique'),
      S.ctx.mes.map((m) => h('option', { value: m }, m.replace('audio/me/', ''))));
    me.value = c.notify_me || '';
    box.appendChild(h('div', { class: 'pjsc-pick pjsc-mt' }, field('Jingle (audio/me)', me),
      h('button', { class: 'pjs-btn small secondary pjsc-play', disabled: !c.notify_me, onclick: async () => {
        try { if (audio) audio.pause(); const url = await call('readSound', { projectPath: S.projectPath, file: c.notify_me }); if (url) { audio = new Audio(url); audio.volume = 0.6; audio.play(); } } catch (e) { toast(e.message, true); }
      } }, '▶ Écouter')));
    box.appendChild(h('div', { class: 'pjsc-grid2' }, field('Vérification (images)', h('input', { class: 'pjs-input', type: 'number', min: 1, max: 600, 'data-focus': 'check', value: c.check_every || 30,
      oninput: (e) => soft(() => { c.check_every = Math.max(1, e.target.value | 0); }) }), 'sur la carte, toutes les N images (60 = 1 seconde)')));
    return box;
  }

  // --- Commandes ---------------------------------------------------------------------------
  function renderCommands() {
    const id = S.selected || 'premier_badge';
    const cmds = [
      ['succes', 'ouvre la liste des succès (aussi : appli « Succès » du téléphone)'],
      [`succes_debloquer(:${id})`, 'débloque un succès (récompense + bandeau)'],
      [`succes_obtenu?(:${id})`, 'true si le succès est obtenu (conditions)'],
      ['succes_compteur(:combats_gagnes, 1)', 'ajoute 1 à un compteur (conditions « Compteur »)'],
      ['succes_compteur_fixer(:combats_gagnes, 0)', 'met un compteur à une valeur'],
      ['succes_nombre', 'nombre de succès obtenus'],
      ['succes_points', 'total des points obtenus'],
      [`succes_retirer(:${id})`, 'retire un succès (pour tester)'],
    ];
    return block('Commandes d’évènement (Script)', null, h('div', { class: 'pjsc-cmds' }, cmds.map(([cmd, hint]) => h('div', { class: 'pjsc-cmdrow' },
      h('code', { class: 'pjsc-cmd', title: 'Cliquer pour copier', onclick: () => copy(cmd) }, cmd), h('span', { class: 'pjs-hint inline' }, hint)))),
      h('div', { class: 'pjs-hint' }, 'Les conditions automatiques sont vérifiées régulièrement sur la carte et à l’ouverture de l’appli. L’appli « Succès » du téléphone apparaît dès qu’il existe au moins un succès.'));
  }

  // ---------------------------------------------------------------------------
  // Page : Level design > Interface > Succès (/database/interface/succes)
  // ---------------------------------------------------------------------------
  function mount(hostEl) {
    root = h('div', { id: 'pjsc-root' });
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

  window.pjSuccesEditor = { state: S, render };
})();

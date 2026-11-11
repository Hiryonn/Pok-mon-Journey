/* eslint-disable */
// =============================================================================
// Smartphone — éditeur du téléphone (plugin PokeSmart) pour Pokémon Studio
// Ouvert par « Plugins > Smartphone » dans le menu de la base de données (ou Ctrl+Maj+M) :
// la page s'affiche à droite du menu, comme les pages de Studio.
// Écrit Data/configs/plugins/pokesmart_config.json et Data/Text/Dialogs/<id>.csv,
// lus en jeu par « scripts/pokesmart/scripts/00137 Reglages Studio.rb ».
// =============================================================================
(() => {
  'use strict';
  if (window.__pjSmartphoneLoaded) return;
  window.__pjSmartphoneLoaded = true;

  // ---------------------------------------------------------------------------
  // Données par défaut (les mêmes que dans le plugin)
  // ---------------------------------------------------------------------------
  const CASES = {
    pokesmart: {
      name: 'PokeSmart', dir: '', phone: [99, 8], screen: [6, 34, 104, 148], wallpaper: true,
      network: [9, 26], wifi: [18, 26], battery: [95, 26], clock: [30, 23, 56, 1], title: [6, 36, 104, 1], color: 9,
      grid: [13, 54], cell: [32, 30], radar: [6, 34], home: [[50, 66], [182, 194]], pages: 143, separator: 150, dock: 154,
    },
    motismart: {
      name: 'Motismart', dir: 'motismart/', phone: [99, 8], screen: [7, 25, 102, 173], wallpaper: false,
      network: [10, 17], wifi: [21, 17], battery: [94, 17], clock: [30, 14, 64, 1], clock_color: 9,
      title: [12, 27, 92, 0], color: 0, grid: [12, 46], cell: [33, 30], radar: [6, 25], home: [[50, 64], [198, 209]], pages: 137, separator: 146, dock: 151,
    },
  };
  const COLORS = { 0: '#212121', 9: '#ffffff' };
  const COLUMNS = 3;
  // petit cadenas (applis débloquées par une commande)
  const LOCK_SVG = () => {
    const span = document.createElement('span');
    span.innerHTML = '<svg viewBox="0 0 10 12" width="10" height="12"><rect x="1" y="5" width="8" height="6" rx="1" fill="currentColor"/><path d="M3 5V3.5a2 2 0 0 1 4 0V5" fill="none" stroke="currentColor" stroke-width="1.4"/></svg>';
    return span.firstChild;
  };
  const APPS_PER_PAGE = 9; // applis par page de l'écran d'accueil (comme dans le plugin)
  const DOCK_APPS = 3; // dernières applis, dans la barre du bas (sur toutes les pages)
  // positions de l'écran d'accueil (comme UI::PokeSmart.home_layout)
  const homeLayout = (theme) => {
    const dock = theme.dock ?? (theme.grid[1] + Math.floor(APPS_PER_PAGE / COLUMNS) * theme.cell[1] + 10);
    return { dock, separator: theme.separator ?? dock - 4, pages: theme.pages ?? dock - 11 };
  };
  const APP_ICONS = {
    open_dex: 'icon_pokedex', open_party: 'icon_party', open_bag: 'icon_bag', open_map: 'icon_map', open_pc: 'icon_pc',
    open_quest: 'icon_book', open_tcard: 'icon_trainercard', open_friends: 'icon_friendlist', open_save: 'icon_save',
    open_option: 'icon_option', open_customization: 'icon_custom', open_mystery_gift: 'icon_mysterygift',
    open_mount: 'icon_mount', open_pokenav: 'icon_pokemon', open_card_game: 'icon_card', open_daycare: 'icon_egg',
    open_camera: 'icon_camera', open_fishing: 'icon_fishing', open_debug: 'icon_debug',
  };
  const DEFAULT_ICON = 'icon_debug';
  // Noms des applis du plugin (français, anglais)
  const APP_NAMES = {
    open_map: ['Carte', 'Map'], open_pc: ['PC', 'PC'], open_quest: ['Journal', 'Quest log'], open_friends: ['Amis', 'Friends'],
    open_customization: ['Personnaliser', 'Customize'], open_mystery_gift: ['Cadeau Mystère', 'Mystery Gift'],
    open_mount: ['Monture', 'Mount'], open_pokenav: ['Pokénav', 'PokéNav'], open_card_game: ['Jeu de cartes', 'Card game'],
    open_daycare: ['Pension', 'Daycare'], open_camera: ['Appareil photo', 'Camera'], open_fishing: ['Pêche', 'Fishing'], open_debug: ['Debug', 'Debug'],
  };
  // Applis de PSDK : ligne du fichier de textes 14 (Data/Text/Dialogs/100014.csv)
  const PSDK_TEXT_ROWS = { open_party: 0, open_dex: 1, open_bag: 2, open_tcard: 3, open_save: 4, open_option: 5 };
  // Applis présentes sans rien coder (PSDK + plugin), dans l'ordre du jeu
  const DEFAULT_ORDER = ['open_dex', 'open_party', 'open_bag', 'open_map', 'open_pc', 'open_quest', 'open_tcard', 'open_friends', 'open_customization', 'open_pokenav', 'open_camera', 'open_save', 'open_option'];
  const LABEL = (action) => action.replace(/^open_/, '').replace(/_/g, ' ');

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjSmartphone;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API Smartphone n'est pas disponible : relance l'installateur puis redémarre Studio.");
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

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = {
    open: false,
    projectPath: null,
    ctx: null,
    config: null,    // contenu de pokesmart_config.json
    csv: null,       // [[en, fr, …], [ligne 0], …]
    saved: null,     // copie pour savoir s'il y a des modifications
    selected: null,  // action sélectionnée
    previewCase: null,
    error: null,
  };
  const snapshot = () => JSON.stringify([S.config, S.csv, S.friends, S.fcsv, S.debug, S.dcsv]);
  const dirty = () => S.config && S.saved !== snapshot();

  function projectUrl(rel, type) {
    const u = new URL(rel.split('/').map(encodeURIComponent).join('/'), window.__pjEventsProjectBase || 'project://--/');
    u.searchParams.append('projectPath', S.projectPath);
    if (type) u.searchParams.append('type', type);
    return u.toString();
  }
  const gfx = (name) => projectUrl(`graphics/interface/pokesmart/${name}.png`, 'image');

  // ---------------------------------------------------------------------------
  // Modèle
  // ---------------------------------------------------------------------------
  const cases = () => {
    const list = clone(CASES);
    Object.entries((S.config && S.config.cases) || {}).forEach(([id, data]) => { list[id] = Object.assign({}, list[id] || CASES.pokesmart, data); });
    return list;
  };
  const caseId = () => {
    const all = cases();
    if (S.previewCase && all[S.previewCase]) return S.previewCase;
    return all[S.config.default_case] ? S.config.default_case : 'pokesmart';
  };
  // Image de la coque : dossier de la coque s'il la contient, sinon dossier commun
  function caseFile(theme, name) {
    const files = (S.ctx.caseFiles || {})[theme.dir || ''] || [];
    return files.includes(name) ? gfx((theme.dir || '') + name) : gfx(name);
  }
  const baseIcon = (action) => {
    const name = APP_ICONS[action] || DEFAULT_ICON;
    return S.ctx.icons.includes(name) ? name : DEFAULT_ICON;
  };
  const iconVariants = (action) => {
    const base = baseIcon(action);
    const re = new RegExp('^' + base + '_(\\d{2})$');
    return [''].concat(S.ctx.icons.map((n) => (n.match(re) || [])[1]).filter(Boolean).sort());
  };
  const defaultVariant = (action) => {
    const v = ((S.config.default_icons || {})[action] || '').toString();
    return iconVariants(action).includes(v) ? v : '';
  };
  const iconName = (action, variant = defaultVariant(action)) => (variant ? `${baseIcon(action)}_${variant}` : baseIcon(action));
  // Nom d'une variante d'icône : celui du CSV (variant_texts) s'il existe, sinon « Classique » / « Variante N »
  const variantKey = (action, v) => iconName(action, v);
  const defaultVariantName = (v, lang) => (lang === 'fr' ? (v ? `Variante ${parseInt(v, 10)}` : 'Classique') : (v ? `Variant ${parseInt(v, 10)}` : 'Classic'));
  function variantRaw(action, v, lang) {
    const row = S.config.variant_texts[variantKey(action, v)];
    const line = Number.isInteger(row) ? S.csv[row + 1] : null;
    const col = langIndex(lang);
    return (line && col >= 0 && line[col]) || '';
  }
  const variantLabel = (action, v) => variantRaw(action, v, mainLang()) || defaultVariantName(v, mainLang());
  function setVariantText(action, v, lang, value) {
    const key = variantKey(action, v);
    let row = S.config.variant_texts[key];
    if (!Number.isInteger(row) || !S.csv[row + 1]) {
      S.csv.push(langs().map((l) => defaultVariantName(v, l)));
      row = S.config.variant_texts[key] = S.csv.length - 2;
    }
    const line = S.csv[row + 1];
    while (line.length < langs().length) line.push('');
    line[langIndex(lang)] = value;
  }

  const langs = () => S.csv[0];
  const langIndex = (code) => langs().indexOf(code);
  const mainLang = () => (langIndex('fr') >= 0 ? 'fr' : langs()[0]);
  function appText(action, lang = mainLang()) {
    const row = S.config.app_texts[action];
    const col = langIndex(lang);
    const line = Number.isInteger(row) ? S.csv[row + 1] : null;
    const text = (line && col >= 0 && line[col]) || LABEL(action);
    return text.replace(/\[VAR TRNAME\(\d+\)\]/g, 'Dresseur');
  }
  function setAppText(action, lang, value) {
    ensureTextRow(action);
    const line = S.csv[S.config.app_texts[action] + 1];
    const col = langIndex(lang);
    while (line.length < langs().length) line.push('');
    line[col] = value;
  }
  // Ligne de texte d'une appli (créée avec les noms par défaut si besoin)
  function ensureTextRow(action) {
    const texts = S.config.app_texts;
    if (Number.isInteger(texts[action]) && S.csv[texts[action] + 1]) return;
    const header = langs();
    const line = header.map(() => '');
    const psdk = S.ctx.psdkMenuTexts;
    if (psdk && PSDK_TEXT_ROWS[action] !== undefined && psdk[PSDK_TEXT_ROWS[action] + 1]) {
      const src = psdk[PSDK_TEXT_ROWS[action] + 1];
      header.forEach((lang, i) => { const j = psdk[0].indexOf(lang); line[i] = j >= 0 ? (src[j] || '') : ''; });
    } else {
      const [fr, en] = APP_NAMES[action] || [LABEL(action), LABEL(action)];
      header.forEach((lang, i) => { line[i] = lang === 'fr' ? fr : en; });
    }
    S.csv.push(line);
    texts[action] = S.csv.length - 2;
  }

  function buildModel(ctx) {
    const config = ctx.config ? clone(ctx.config) : {};
    const model = {
      klass: 'PokeSmartConfig',
      text_file_id: config.text_file_id || ctx.textFileId || 9100,
      app_texts: config.app_texts || {},
      app_order: (config.app_order && config.app_order.length ? config.app_order : DEFAULT_ORDER).slice(),
      hidden_apps: config.hidden_apps || [],
      locked_apps: config.locked_apps || [],
      default_case: config.default_case || 'pokesmart',
      default_wallpaper: config.default_wallpaper || '',
      default_icons: config.default_icons || {},
      variant_texts: config.variant_texts || {},
      cases: config.cases || {},
    };
    const header = (ctx.psdkMenuTexts && ctx.psdkMenuTexts[0]) || ['en', 'fr'];
    // applis du plugin ajoutées depuis le dernier enregistrement : placées avant Sauvegarde / Options
    DEFAULT_ORDER.forEach((action) => {
      if (model.app_order.includes(action)) return;
      const last = ['open_save', 'open_option'].map((a) => model.app_order.indexOf(a)).filter((i) => i >= 0);
      model.app_order.splice(last.length ? Math.min(...last) : model.app_order.length, 0, action);
    });
    S.config = model;
    S.csv = ctx.csv && ctx.csv.length ? ctx.csv.map((r) => r.slice()) : [header.slice()];
    model.app_order.forEach(ensureTextRow);
  }

  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.config = null; S.csv = null; S.error = null; S.selected = null; S.previewCase = null;
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      buildModel(S.ctx);
      buildFriends(S.ctx);
      buildDebug(S.ctx);
      S.saved = S.ctx.configExists && S.ctx.csv && S.ctx.debug ? snapshot() : null;
      S.selected = S.config.app_order[0] || null;
      loadFonts();
    } catch (e) { S.error = e.message; }
    render();
  }

  async function save() {
    if (!S.config) return;
    try {
      const r = await call('save', { projectPath: S.projectPath, config: S.config, csv: S.csv, friends: S.friends, friendsCsv: S.fcsv, debug: S.debug, debugCsv: S.dcsv });
      S.saved = snapshot();
      const p = r.plugin || {};
      if (S.ctx && p.source) S.ctx.plugin = { source: true, installed: p.installed, outdated: p.installed ? [] : ['?'], stale: [] };
      const changed = (p.copied || []).length + (p.removed || []).length;
      toast(p.source && p.installed
        ? `Enregistré dans le plugin${changed ? ` (${changed} script${changed > 1 ? 's' : ''} du plugin installé mis à jour)` : ''}`
        : (p.source ? 'Enregistré — plugin pas encore installé : lance construire_plugin_pokesmart.bat une fois' : `Enregistré : ${r.configFile} et ${r.csvFile}`));
      render();
      if (p.source) rebuildPlugin();
    } catch (e) { toast('Erreur de sauvegarde : ' + e.message, true); }
  }

  // Reconstruit scripts/pokesmart.psdkplug en arrière-plan après chaque enregistrement
  let buildQueued = false;
  async function rebuildPlugin() {
    if (S.pluginBuilding) { buildQueued = true; return; }
    S.pluginBuilding = true; S.pluginError = null; updateStatus();
    try {
      const r = await call('buildPlugin', { projectPath: S.projectPath });
      if (!r.built) S.pluginError = r.error || 'échec';
    } catch (e) { S.pluginError = e.message; }
    S.pluginBuilding = false; updateStatus();
    if (S.pluginError) toast('Plugin enregistré, mais pokesmart.psdkplug n\'a pas pu être reconstruit : ' + S.pluginError, true);
    if (buildQueued) { buildQueued = false; rebuildPlugin(); }
  }

  // Texte d'état en haut à droite
  function statusText() {
    if (!S.config) return ['', ''];
    if (dirty()) return ['Modifications non enregistrées', ' dirty'];
    if (S.pluginBuilding) return ['Mise à jour du plugin…', ''];
    const p = S.ctx && S.ctx.plugin;
    if (p && p.source && (!p.installed || p.outdated.length || p.stale.length)) return ['Plugin installé pas à jour : Enregistrer', ' dirty'];
    if (S.pluginError) return ['Plugin : paquet non reconstruit', ' dirty'];
    return ['Tout est enregistré (plugin à jour)', ''];
  }
  function updateStatus() {
    const st = root && root.querySelector('.pjs-status');
    if (!st) return;
    const [text, cls] = statusText();
    st.className = 'pjs-status' + cls; st.textContent = text;
  }

  let fontsLoaded = null;
  function loadFonts() {
    if (fontsLoaded === S.projectPath || !window.FontFace) return;
    fontsLoaded = S.projectPath;
    [['PJSPokemonDS', 'Fonts/PokemonDS.ttf'], ['PJSPowerGreen', 'Fonts/PowerGreenSmall.ttf']].forEach(([family, file]) => {
      const f = new FontFace(family, `url("${projectUrl(file)}")`);
      f.load().then((ff) => { document.fonts.add(ff); renderPreview(); }).catch(() => {});
    });
  }

  // ---------------------------------------------------------------------------
  // Actions sur les applis
  // ---------------------------------------------------------------------------
  const isHidden = (action) => S.config.hidden_apps.includes(action);
  function toggleHidden(action) {
    const list = S.config.hidden_apps;
    if (isHidden(action)) list.splice(list.indexOf(action), 1); else list.push(action);
    render();
  }
  // déblocage : dès le début (par défaut) ou par la commande smartphone_unlock(:open_x)
  const isLocked = (action) => S.config.locked_apps.includes(action);
  function setLocked(action, locked) {
    S.config.locked_apps = S.config.locked_apps.filter((a) => a !== action);
    if (locked) S.config.locked_apps.push(action);
    render();
  }
  function copyText(text) {
    try { navigator.clipboard.writeText(text); toast('Copié : ' + text); } catch (e) { toast(text); }
  }
  function moveApp(action, toIndex) {
    const order = S.config.app_order;
    const from = order.indexOf(action);
    if (from < 0) return;
    order.splice(from, 1);
    order.splice(Math.max(0, Math.min(order.length, toIndex)), 0, action);
    render();
  }
  function addApp(action) {
    action = String(action || '').trim();
    if (!action) return;
    if (!/^[a-z_][a-z0-9_]*$/.test(action)) return toast('Nom d\'action invalide (ex. open_map)', true);
    if (S.config.app_order.includes(action)) return toast('Cette appli est déjà dans la liste', true);
    const order = S.config.app_order;
    const before = ['open_save', 'open_option'].map((a) => order.indexOf(a)).filter((i) => i >= 0);
    order.splice(before.length ? Math.min(...before) : order.length, 0, action);
    ensureTextRow(action);
    S.selected = action;
    render();
  }
  function removeApp(action) {
    const order = S.config.app_order;
    order.splice(order.indexOf(action), 1);
    S.config.hidden_apps = S.config.hidden_apps.filter((a) => a !== action);
    S.config.locked_apps = S.config.locked_apps.filter((a) => a !== action);
    delete S.config.default_icons[action];
    if (S.selected === action) S.selected = order[0] || null;
    render();
  }

  // ---------------------------------------------------------------------------
  // Amis (réseau social) : contacts, messages — pokesmart_friends.json + 9101.csv
  // ---------------------------------------------------------------------------
  const FRIEND_DEFAULTS = { start_affinity: 0, battle_affinity: 40, battle_cooldown_days: 1 };

  function buildFriends(ctx) {
    const data = ctx.friends ? clone(ctx.friends) : {};
    S.friends = { klass: 'PokeSmartFriendsConfig', text_file_id: data.text_file_id || 9101, contacts: data.contacts || [] };
    const header = (ctx.psdkMenuTexts && ctx.psdkMenuTexts[0]) || ['en', 'fr'];
    S.fcsv = ctx.friendsCsv && ctx.friendsCsv.length ? ctx.friendsCsv.map((r) => r.slice()) : [header.slice()];
    S.friendSel = S.friends.contacts[0] ? S.friends.contacts[0].id : null;
  }
  const fLangs = () => S.fcsv[0];
  const fMainLang = () => (fLangs().includes('fr') ? 'fr' : fLangs()[0]);
  function fText(row, lang = fMainLang()) {
    const line = Number.isInteger(row) ? S.fcsv[row + 1] : null;
    const col = fLangs().indexOf(lang);
    return (line && col >= 0 && line[col]) || '';
  }
  // Crée une ligne de texte et renvoie son numéro
  function fNewRow(values) {
    S.fcsv.push(fLangs().map((lang) => (values && (values[lang] ?? values.en)) || ''));
    return S.fcsv.length - 2;
  }
  function fSetText(row, lang, value) {
    const line = S.fcsv[row + 1];
    while (line.length < fLangs().length) line.push('');
    line[fLangs().indexOf(lang)] = value;
  }
  const currentFriend = () => S.friends.contacts.find((c) => c.id === S.friendSel) || null;
  const friendName = (c) => fText(c.name_row) || c.id;

  function addFriend(id) {
    id = String(id || '').trim();
    if (!/^[a-z_][a-z0-9_]*$/.test(id)) return toast('Identifiant invalide : lettres minuscules, chiffres et _ (ex. lea)', true);
    if (S.friends.contacts.some((c) => c.id === id)) return toast('Ce contact existe déjà', true);
    const name = id.charAt(0).toUpperCase() + id.slice(1);
    S.friends.contacts.push(Object.assign({ id, name_row: fNewRow({ fr: name, en: name }), character: '', trainer: '', messages: [] }, FRIEND_DEFAULTS));
    S.friendSel = id;
    render();
  }
  function removeFriend(c) {
    if (!confirm(`Supprimer le contact « ${friendName(c)} » et ses messages ?`)) return;
    S.friends.contacts = S.friends.contacts.filter((x) => x !== c);
    S.friendSel = S.friends.contacts[0] ? S.friends.contacts[0].id : null;
    render();
  }
  function addMessage(c) {
    let n = c.messages.length + 1;
    while (c.messages.some((m) => m.id === `message_${n}`)) n++;
    c.messages.push({ id: `message_${n}`, text_row: fNewRow({ fr: '', en: '' }), auto: true, affinity: 0, switch: 0, quest: '', affinity_gain: 0 });
    render();
  }

  // Apparence du contact : première image (en haut à gauche) de son personnage, dans un canvas
  function drawFace(canvas, character, scale) {
    const ctx = canvas.getContext('2d');
    canvas.width = 32 * scale; canvas.height = 32 * scale;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    if (!character) return;
    const img = new Image();
    img.onload = () => {
      const fw = Math.floor(img.width / 4), fh = Math.floor(img.height / 4);
      const zoom = Math.min(scale, (32 * scale) / Math.max(fw, fh));
      const w = Math.round(fw * zoom), hgt = Math.round(fh * zoom);
      ctx.imageSmoothingEnabled = false;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, 0, 0, fw, fh, Math.floor((canvas.width - w) / 2), Math.floor((canvas.height - hgt) / 2), w, hgt);
    };
    img.src = projectUrl(`${S.ctx.charDir}/${character}.png`, 'image');
  }

  function numberField(label, value, onChange, hint) {
    const input = h('input', { class: 'pjs-input num', type: 'number', value: String(value ?? 0) });
    input.addEventListener('input', () => { onChange(parseInt(input.value, 10) || 0); refreshStatus(); });
    return h('label', { class: 'pjs-field' }, h('span', null, label), input, hint ? h('span', { class: 'pjs-hint inline' }, hint) : null);
  }

  function renderFriends(content) {
    const contactsBlock = h('div', { class: 'pjs-block pjs-block-contacts' });
    const detailBlock = h('div', { class: 'pjs-block pjs-block-list' });
    content.appendChild(h('div', { class: 'pjs-row' }, contactsBlock, detailBlock));
    // contacts
    contactsBlock.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `Contacts (${S.friends.contacts.length})`)));
    const list = h('div', { class: 'pjs-list' });
    S.friends.contacts.forEach((c) => {
      const face = h('canvas', { class: 'pjs-face small' });
      drawFace(face, c.character, 1);
      list.appendChild(h('div', { class: 'pjs-item' + (c.id === S.friendSel ? ' active' : ''), onclick: () => { S.friendSel = c.id; S.pickOpen = false; render(); } },
        face, h('span', { class: 'pjs-name' }, friendName(c)), h('span', { class: 'pjs-code' }, c.id)));
    });
    if (!S.friends.contacts.length) list.appendChild(h('div', { class: 'pjs-hint' }, 'Aucun contact pour l\'instant.'));
    contactsBlock.appendChild(list);
    const newId = h('input', { class: 'pjs-input', placeholder: 'identifiant (ex. lea)' });
    newId.addEventListener('keydown', (e) => { if (e.key === 'Enter') addFriend(newId.value); });
    contactsBlock.appendChild(h('div', { class: 'pjs-add' }, newId, h('button', { class: 'pjs-btn secondary', onclick: () => addFriend(newId.value) }, 'Ajouter')));
    contactsBlock.appendChild(h('div', { class: 'pjs-hint' }, 'Commandes d\'évent : ', h('span', { class: 'pjs-code' }, 'friend_meet(:lea)'), ' ajoute le contact dans le téléphone, ',
      h('span', { class: 'pjs-code' }, 'friend_add_affinity(:lea, 10)'), ' change l\'affinité, ', h('span', { class: 'pjs-code' }, 'friend_message(:lea, :message_1)'), ' envoie un message.'));

    const c = currentFriend();
    if (!c) { detailBlock.appendChild(h('div', { class: 'pjs-hint' }, 'Ajoute un contact pour le configurer.')); return; }
    // fiche du contact
    const face = h('canvas', { class: 'pjs-face big' });
    drawFace(face, c.character, 2);
    detailBlock.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, friendName(c)), h('span', { class: 'pjs-code' }, `:${c.id}`)));
    const top = h('div', { class: 'pjs-friend-top' }, h('div', { class: 'pjs-drop', title: 'Glisse une image PNG ici' }, face, h('span', { class: 'pjs-drop-hint' }, 'Dépose un PNG')));
    makeDropZone(top, c, face);
    const fields = h('div', { class: 'pjs-friend-fields' });
    fields.appendChild(characterField(c, face));
    const trainerSel = h('select', { class: 'pjs-select' }, h('option', { value: '' }, 'Pas de combat'),
      S.ctx.trainers.map((t) => h('option', { value: t.dbSymbol, selected: c.trainer === t.dbSymbol }, `${t.name || t.dbSymbol} (${t.dbSymbol})`)));
    trainerSel.addEventListener('change', () => { c.trainer = trainerSel.value; render(); });
    fields.appendChild(h('label', { class: 'pjs-field' }, h('span', null, 'Dresseur (pour les défis)'), trainerSel));
    top.appendChild(fields);
    detailBlock.appendChild(top);
    const nameSec = h('div', { class: 'pjs-section' }, h('div', { class: 'pjs-label' }, `Nom (Data/Text/Dialogs/${S.friends.text_file_id}.csv)`));
    fLangs().forEach((lang) => {
      const input = h('input', { class: 'pjs-input', value: fText(c.name_row, lang) });
      input.addEventListener('input', () => { fSetText(c.name_row, lang, input.value); refreshStatus(); });
      nameSec.appendChild(h('label', { class: 'pjs-lang' }, h('span', null, lang), input));
    });
    detailBlock.appendChild(nameSec);
    const nums = h('div', { class: 'pjs-section pjs-nums' },
      numberField('Affinité de départ', c.start_affinity, (v) => { c.start_affinity = v; }, '0 à 100 (20 = 1 cœur)'),
      c.trainer ? numberField('Affinité pour défier', c.battle_affinity, (v) => { c.battle_affinity = v; }) : null,
      c.trainer ? numberField('Jours entre deux défis', c.battle_cooldown_days, (v) => { c.battle_cooldown_days = v; }) : null);
    detailBlock.appendChild(nums);
    detailBlock.appendChild(h('div', { class: 'pjs-section row last' }, h('span', null), h('button', { class: 'pjs-btn small danger', onclick: () => removeFriend(c) }, 'Supprimer le contact')));

    // messages
    const msgBlock = h('div', { class: 'pjs-block pjs-block-full' });
    content.appendChild(msgBlock);
    msgBlock.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `Messages de ${friendName(c)} (${c.messages.length})`),
      h('button', { class: 'pjs-btn secondary', onclick: () => addMessage(c) }, 'Ajouter un message')));
    if (!c.messages.length) msgBlock.appendChild(h('div', { class: 'pjs-hint' }, 'Un message automatique arrive dans le téléphone dès que ses conditions sont remplies (affinité, interrupteur).'));
    c.messages.forEach((m, i) => {
      const card = h('div', { class: 'pjs-message' });
      const idInput = h('input', { class: 'pjs-input code', value: m.id });
      idInput.addEventListener('change', () => {
        const v = idInput.value.trim();
        if (!/^[a-z_][a-z0-9_]*$/.test(v) || c.messages.some((x) => x !== m && x.id === v)) { idInput.value = m.id; return toast('Identifiant invalide ou déjà pris', true); }
        m.id = v; refreshStatus();
      });
      card.appendChild(h('div', { class: 'pjs-message-head' }, h('span', { class: 'pjs-num' }, i + 1), idInput,
        h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: !!m.auto, onchange: (e) => { m.auto = e.target.checked; refreshStatus(); } }), 'Envoi automatique'),
        h('span', { class: 'pjs-spacer' }),
        h('button', { class: 'pjs-btn small', title: 'Monter', disabled: i === 0, onclick: () => { c.messages.splice(i - 1, 0, c.messages.splice(i, 1)[0]); render(); } }, '▲'),
        h('button', { class: 'pjs-btn small', title: 'Descendre', disabled: i === c.messages.length - 1, onclick: () => { c.messages.splice(i + 1, 0, c.messages.splice(i, 1)[0]); render(); } }, '▼'),
        h('button', { class: 'pjs-btn small danger', onclick: () => { c.messages.splice(i, 1); render(); } }, 'Supprimer')));
      const texts = h('div', { class: 'pjs-message-texts' });
      fLangs().forEach((lang) => {
        const area = h('textarea', { class: 'pjs-input pjs-textarea', rows: '2', placeholder: lang === fMainLang() ? 'Texte du message…' : '' });
        area.value = fText(m.text_row, lang);
        area.addEventListener('input', () => { fSetText(m.text_row, lang, area.value); refreshStatus(); });
        texts.appendChild(h('label', { class: 'pjs-lang top' }, h('span', null, lang), area));
      });
      card.appendChild(texts);
      const questSel = h('select', { class: 'pjs-select' }, h('option', { value: '' }, 'Aucune'),
        S.ctx.quests.map((q) => h('option', { value: q.dbSymbol, selected: m.quest === q.dbSymbol }, `${q.name || q.dbSymbol} (${q.dbSymbol})`)));
      questSel.addEventListener('change', () => { m.quest = questSel.value; refreshStatus(); });
      card.appendChild(h('div', { class: 'pjs-message-conds' },
        numberField('Affinité minimum', m.affinity, (v) => { m.affinity = v; }),
        numberField('Interrupteur (0 = aucun)', m.switch, (v) => { m.switch = v; }),
        numberField('Affinité gagnée à la lecture', m.affinity_gain, (v) => { m.affinity_gain = v; }),
        h('label', { class: 'pjs-field' }, h('span', null, 'Quête proposée'), questSel)));
      msgBlock.appendChild(card);
    });
  }

  // ---------------------------------------------------------------------------
  // Choix du personnage d'un contact : recherche avec aperçus + glisser-déposer d'un PNG
  // ---------------------------------------------------------------------------
  const PICK_PAGE = 60;
  const norm = (t) => String(t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

  // personnages correspondant à la recherche : tous les mots doivent apparaître,
  // ceux dont le nom de fichier commence par la recherche passent en premier
  function searchCharacters(query) {
    const all = S.ctx.characters || [];
    const words = norm(query).split(/[\s/_-]+/).filter(Boolean);
    if (!words.length) return all.slice();
    const scored = [];
    all.forEach((name) => {
      const n = norm(name);
      if (!words.every((w) => n.includes(w))) return;
      const base = n.slice(n.lastIndexOf('/') + 1);
      const score = base === words.join('_') ? 0 : base.startsWith(words[0]) ? 1 : n.startsWith(words[0]) ? 2 : 3;
      scored.push([score, name]);
    });
    scored.sort((a, b) => a[0] - b[0] || a[1].localeCompare(b[1]));
    return scored.map((x) => x[1]);
  }

  // change le personnage du contact
  function setCharacter(c, name, face) {
    c.character = name || '';
    S.pickOpen = false;
    if (face) drawFace(face, c.character, 2);
    render();
  }

  // copie (si besoin) un PNG déposé dans graphics/characters et le choisit
  async function importCharacterFile(c, file, face) {
    if (!file || !/\.png$/i.test(file.name)) return toast('Dépose une image PNG (planche de personnage 4×4)', true);
    let sourcePath = '';
    try { sourcePath = (window.api && window.api.getPathForFile && window.api.getPathForFile(file)) || file.path || ''; } catch (e) { sourcePath = file.path || ''; }
    if (!sourcePath) return toast('Impossible de lire le chemin du fichier déposé', true);
    try {
      const r = await call('importCharacter', { projectPath: S.projectPath, sourcePath });
      if (!S.ctx.characters.includes(r.name)) { S.ctx.characters.push(r.name); S.ctx.characters.sort((a, b) => a.localeCompare(b)); }
      toast(r.copied ? `Image copiée dans ${S.ctx.charDir}/${r.name}.png` : `Personnage choisi : ${r.name}`);
      setCharacter(c, r.name, face);
    } catch (e) { toast('Import impossible : ' + e.message, true); }
  }

  // rend une zone (la fiche du contact) sensible au glisser-déposer d'un PNG ; l'aperçu s'illumine
  function makeDropZone(zone, c, face) {
    const mark = (on) => (zone.querySelector('.pjs-drop') || zone).classList.toggle('pjs-dragging', on);
    let depth = 0;
    const hasFile = (e) => [...(e.dataTransfer && e.dataTransfer.types || [])].includes('Files');
    zone.addEventListener('dragenter', (e) => { if (!hasFile(e)) return; e.preventDefault(); depth++; mark(true); });
    zone.addEventListener('dragover', (e) => { if (!hasFile(e)) return; e.preventDefault(); e.dataTransfer.dropEffect = 'copy'; });
    zone.addEventListener('dragleave', () => { depth = Math.max(0, depth - 1); if (!depth) mark(false); });
    zone.addEventListener('drop', (e) => {
      e.preventDefault(); e.stopPropagation();
      depth = 0; mark(false);
      importCharacterFile(c, e.dataTransfer.files[0], face);
    });
  }

  // champ « Personnage » : bouton avec le nom actuel + panneau de recherche avec aperçus
  function characterField(c, face) {
    const wrap = h('div', { class: 'pjs-field pjs-char-field' }, h('span', null, 'Personnage'));
    const current = h('button', { class: 'pjs-char-current' + (S.pickOpen ? ' open' : ''), onclick: () => { S.pickOpen = !S.pickOpen; S.pickQuery = ''; render(); } },
      h('span', { class: c.character ? 'pjs-char-name' : 'pjs-char-name empty' }, c.character || 'Aucun personnage'),
      h('span', { class: 'pjs-char-action' }, S.pickOpen ? 'Fermer' : 'Choisir…'));
    wrap.appendChild(current);
    wrap.appendChild(h('span', { class: 'pjs-hint inline' }, `Image de ${S.ctx.charDir} : choisis-la ou glisse un PNG sur l'aperçu.`));
    if (!S.pickOpen) return wrap;

    const panel = h('div', { class: 'pjs-picker' });
    const search = h('input', { class: 'pjs-input', placeholder: 'Rechercher (ex. girl, npc 01, dresseur…)', value: S.pickQuery || '' });
    const count = h('span', { class: 'pjs-picker-count' });
    const grid = h('div', { class: 'pjs-picker-grid' });
    panel.appendChild(h('div', { class: 'pjs-picker-head' }, search, count,
      h('button', { class: 'pjs-btn small secondary', onclick: () => setCharacter(c, '', face) }, 'Aucun')));
    panel.appendChild(grid);
    let results = [];
    let shown = 0;
    let sel = 0;
    // aperçus chargés seulement quand ils deviennent visibles
    const io = new IntersectionObserver((entries) => entries.forEach((en) => {
      if (!en.isIntersecting) return;
      io.unobserve(en.target);
      drawFace(en.target, en.target.dataset.name, 1);
    }), { root: grid });
    const tiles = () => [...grid.querySelectorAll('.pjs-picker-tile')];
    const highlight = () => tiles().forEach((t, i) => {
      t.classList.toggle('sel', i === sel);
      if (i === sel) t.scrollIntoView({ block: 'nearest' });
    });
    const more = () => {
      grid.querySelector('.pjs-picker-more')?.remove();
      results.slice(shown, shown + PICK_PAGE).forEach((name) => {
        const canvas = h('canvas', { class: 'pjs-face', 'data-name': name });
        canvas.width = canvas.height = 32;
        const base = name.slice(name.lastIndexOf('/') + 1);
        const dir = name.includes('/') ? name.slice(0, name.lastIndexOf('/') + 1) : '';
        grid.appendChild(h('div', { class: 'pjs-picker-tile' + (name === c.character ? ' current' : ''), title: name, onclick: () => setCharacter(c, name, face) },
          canvas, h('span', { class: 'pjs-picker-name' }, dir ? h('small', null, dir) : null, base)));
        io.observe(canvas);
      });
      shown = Math.min(results.length, shown + PICK_PAGE);
      if (shown < results.length) grid.appendChild(h('button', { class: 'pjs-btn small secondary pjs-picker-more', onclick: more }, `Afficher plus (${results.length - shown} restants)`));
    };
    const update = () => {
      S.pickQuery = search.value;
      results = searchCharacters(search.value);
      grid.textContent = ''; shown = 0; sel = 0;
      count.textContent = `${results.length} / ${(S.ctx.characters || []).length}`;
      if (!results.length) grid.appendChild(h('div', { class: 'pjs-hint' }, 'Aucune image ne correspond.'));
      more(); highlight();
    };
    search.addEventListener('input', update);
    search.addEventListener('keydown', (e) => {
      const n = tiles().length;
      const cols = Math.max(1, Math.round(grid.clientWidth / 84)) || 1;
      const moves = { ArrowRight: 1, ArrowLeft: -1, ArrowDown: cols, ArrowUp: -cols };
      if (e.key in moves && n) {
        e.preventDefault();
        sel = Math.min(n - 1, Math.max(0, sel + moves[e.key]));
        if (sel >= n - 1 && shown < results.length) more();
        highlight();
      } else if (e.key === 'Enter' && results[sel]) { e.preventDefault(); setCharacter(c, results[sel], face); }
      else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); S.pickOpen = false; render(); }
    });
    wrap.appendChild(panel);
    update();
    requestAnimationFrame(() => { search.focus(); search.setSelectionRange(search.value.length, search.value.length); });
    return wrap;
  }

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  let root = null;
  const parts = {};

  // ---------------------------------------------------------------------------
  // Écran Debug (mode debug du jeu) : catégories, commandes — pokesmart_debug.json + 9102.csv
  // ---------------------------------------------------------------------------
  const DEBUG_BUILTIN = [
    ['team', 'Équipe', 'Team', 'A : valider   Droite : niveau +1', 'icon_party'],
    ['pokemon', 'Pokémon', 'Pokémon', 'A : recevoir / écrire   X : chromatique', 'icon_pokedex'],
    ['items', 'Objets', 'Items', 'A : recevoir / écrire', 'icon_bag'],
    ['player', 'Joueur', 'Player', 'A : valider / écrire   Gauche / droite : régler', 'icon_trainercard'],
    ['map', 'Carte', 'Map', 'A : écrire / se téléporter   Gauche / droite : régler', 'icon_map'],
    ['switches', 'Interrupteurs', 'Switches', 'A : allumer / éteindre', 'icon_option'],
    ['variables', 'Variables', 'Variables', 'Gauche / droite : -1 / +1   A : écrire   X : 0', 'icon_pc'],
    ['phone', 'Téléphone', 'Phone', 'A : valider   Gauche / droite : régler', 'icon_debug'],
  ];
  const DEBUG_KINDS = [
    ['script', 'Script Ruby'], ['switch', 'Interrupteur'], ['variable', 'Variable'], ['common_event', 'Évent commun'],
    ['pokemon', 'Donner un Pokémon'], ['item', 'Donner un objet'], ['warp', 'Téléportation'],
  ];
  const DEBUG_KIND_FIELDS = { switch: { switch: 1 }, variable: { variable: 1 }, common_event: { common_event: 1 }, pokemon: { pokemon: '', level: 0 }, item: { item: '', count: 0 }, warp: { map: 1, x: 0, y: 0 }, script: { script: '', value_script: '' } };

  function buildDebug(ctx) {
    const data = ctx.debug ? clone(ctx.debug) : {};
    const header = (ctx.psdkMenuTexts && ctx.psdkMenuTexts[0]) || ['en', 'fr'];
    S.dcsv = ctx.debugCsv && ctx.debugCsv.length ? ctx.debugCsv.map((r) => r.slice()) : [header.slice()];
    S.debug = {
      klass: 'PokeSmartDebugConfig', text_file_id: data.text_file_id || 9102,
      pokemon_level: data.pokemon_level ?? 50, item_count: data.item_count ?? 10, badges: data.badges ?? 8,
      categories: data.categories || [], commands: data.commands || [],
    };
    // catégories de base absentes : ajoutées avec leurs textes par défaut
    DEBUG_BUILTIN.forEach(([id, fr, en, help, icon]) => {
      if (S.debug.categories.some((c) => c.id === id)) return;
      S.debug.categories.push({ id, builtin: true, visible: true, icon, name_row: dNewRow({ fr, en }), help_row: dNewRow({ fr: help, en: help }) });
    });
    S.debugSel = S.debug.categories[0] ? S.debug.categories[0].id : null;
  }
  const dLangs = () => S.dcsv[0];
  const dMainLang = () => (dLangs().includes('fr') ? 'fr' : dLangs()[0]);
  function dText(row, lang = dMainLang()) {
    const line = Number.isInteger(row) ? S.dcsv[row + 1] : null;
    const col = dLangs().indexOf(lang);
    return (line && col >= 0 && line[col]) || '';
  }
  function dNewRow(values) {
    S.dcsv.push(dLangs().map((lang) => (values && (values[lang] ?? values.en ?? values.fr)) || ''));
    return S.dcsv.length - 2;
  }
  function dSetText(row, lang, value) {
    const line = S.dcsv[row + 1];
    while (line.length < dLangs().length) line.push('');
    line[dLangs().indexOf(lang)] = value;
  }
  const debugCategory = () => S.debug.categories.find((c) => c.id === S.debugSel) || null;
  const debugBuiltin = (id) => DEBUG_BUILTIN.find((b) => b[0] === id);
  const debugName = (c) => dText(c.name_row) || (debugBuiltin(c.id) || [])[1] || c.id;
  const iconUrl = (name) => gfx(name || 'icon_debug');

  // champs texte « une ligne par langue »
  function dTextFields(row, placeholder, onInput) {
    const box = h('div', { class: 'pjs-variant-fields' });
    dLangs().forEach((lang) => {
      const input = h('input', { class: 'pjs-input', value: dText(row, lang), placeholder: placeholder || '' });
      input.addEventListener('input', () => { dSetText(row, lang, input.value); if (onInput) onInput(); refreshStatus(); });
      box.appendChild(h('label', { class: 'pjs-lang' }, h('span', null, lang), input));
    });
    return box;
  }

  function addDebugCategory(id) {
    id = String(id || '').trim();
    if (!/^[a-z_][a-z0-9_]*$/.test(id)) return toast('Identifiant invalide : lettres minuscules, chiffres et _ (ex. tests)', true);
    if (S.debug.categories.some((c) => c.id === id)) return toast('Cette catégorie existe déjà', true);
    const name = id.charAt(0).toUpperCase() + id.slice(1).replace(/_/g, ' ');
    S.debug.categories.push({ id, builtin: false, visible: true, icon: 'icon_debug', name_row: dNewRow({ fr: name, en: name }), help_row: dNewRow({ fr: 'A : valider', en: 'A: confirm' }) });
    S.debugSel = id;
    render();
  }
  function removeDebugCategory(c) {
    const count = S.debug.commands.filter((m) => m.category === c.id).length;
    if (!confirm(`Supprimer la catégorie « ${debugName(c)} »${count ? ` et ses ${count} commande(s)` : ''} ?`)) return;
    S.debug.categories = S.debug.categories.filter((x) => x !== c);
    S.debug.commands = S.debug.commands.filter((m) => m.category !== c.id);
    S.debugSel = S.debug.categories[0] ? S.debug.categories[0].id : null;
    render();
  }
  function moveDebugCategory(c, delta) {
    const list = S.debug.categories;
    const i = list.indexOf(c);
    const j = i + delta;
    if (j < 0 || j >= list.length) return;
    list.splice(i, 1); list.splice(j, 0, c);
    render();
  }
  function addDebugCommand(category) {
    let n = S.debug.commands.length + 1;
    while (S.debug.commands.some((m) => m.id === `cmd_${n}`)) n++;
    S.debug.commands.push(Object.assign({ id: `cmd_${n}`, category, kind: 'script', label_row: dNewRow({ fr: 'Nouvelle commande', en: 'New command' }) }, clone(DEBUG_KIND_FIELDS.script)));
    render();
  }
  function moveDebugCommand(cmd, delta) {
    const list = S.debug.commands;
    const same = list.filter((m) => m.category === cmd.category);
    const k = same.indexOf(cmd) + delta;
    if (k < 0 || k >= same.length) return;
    const other = same[k];
    const i = list.indexOf(cmd); const j = list.indexOf(other);
    list[i] = other; list[j] = cmd;
    render();
  }
  function setCommandKind(cmd, kind) {
    Object.keys(DEBUG_KIND_FIELDS).forEach((k) => Object.keys(DEBUG_KIND_FIELDS[k]).forEach((f) => { if (!(kind === k)) delete cmd[f]; }));
    Object.entries(DEBUG_KIND_FIELDS[kind] || {}).forEach(([f, v]) => { if (cmd[f] === undefined) cmd[f] = v; });
    cmd.kind = kind;
    render();
  }

  // liste de choix avec recherche (Pokémon, objets, cartes) : <input list>
  function dataList(id, entries) {
    let list = document.getElementById(id);
    if (!list) { list = h('datalist', { id }); document.body.appendChild(list); }
    if (list.dataset.project !== S.projectPath) {
      list.textContent = '';
      entries.forEach(([value, label]) => list.appendChild(h('option', { value }, label)));
      list.dataset.project = S.projectPath;
    }
    return id;
  }
  function textField(label, value, onChange, attrs) {
    const input = h('input', Object.assign({ class: 'pjs-input', value: value ?? '' }, attrs || {}));
    input.addEventListener('input', () => { onChange(input.value); refreshStatus(); });
    return h('label', { class: 'pjs-field' }, h('span', null, label), input);
  }

  function commandFields(cmd) {
    const box = h('div', { class: 'pjs-cmd-fields' });
    const num = (label, key, hint) => numberField(label, cmd[key], (v) => { cmd[key] = v; }, hint);
    switch (cmd.kind) {
      case 'switch': box.appendChild(num('N° de l\'interrupteur', 'switch')); break;
      case 'variable': box.appendChild(num('N° de la variable', 'variable')); break;
      case 'common_event': box.appendChild(num('N° de l\'évent commun', 'common_event', 'lancé sur la carte, le menu se ferme')); break;
      case 'pokemon':
        box.appendChild(textField('Pokémon (symbole)', cmd.pokemon, (v) => { cmd.pokemon = v.trim(); },
          { list: dataList('pjs-dbg-creatures', (S.ctx.creatures || []).map((c) => [c.dbSymbol, `${String(c.id).padStart(3, '0')} ${c.name}`])), placeholder: 'ex. pikachu' }));
        box.appendChild(num('Niveau', 'level', '0 = niveau réglé dans l\'écran'));
        break;
      case 'item':
        box.appendChild(textField('Objet (symbole)', cmd.item, (v) => { cmd.item = v.trim(); },
          { list: dataList('pjs-dbg-items', (S.ctx.items || []).map((c) => [c.dbSymbol, c.name])), placeholder: 'ex. potion' }));
        box.appendChild(num('Quantité', 'count', '0 = quantité réglée dans l\'écran'));
        break;
      case 'warp': {
        const maps = S.ctx.maps || [];
        const sel = h('select', { class: 'pjs-select' }, maps.length ? null : h('option', { value: cmd.map }, `Carte ${cmd.map}`),
          maps.map((m) => h('option', { value: m.id, selected: m.id === cmd.map }, `${String(m.id).padStart(3, '0')} ${m.name} (${m.width}×${m.height})`)));
        sel.addEventListener('change', () => { cmd.map = parseInt(sel.value, 10) || 1; refreshStatus(); });
        box.appendChild(h('label', { class: 'pjs-field' }, h('span', null, 'Carte'), sel));
        box.appendChild(num('X', 'x'));
        box.appendChild(num('Y', 'y'));
        break;
      }
      default: {
        const script = h('textarea', { class: 'pjs-input pjs-textarea pjs-code-area', rows: 4, spellcheck: 'false', placeholder: 'add_pokemon(:pikachu, 5)\n$game_switches[12] = true\n"Texte affiché en bas"' });
        script.value = cmd.script || '';
        script.addEventListener('input', () => { cmd.script = script.value; refreshStatus(); });
        box.appendChild(h('label', { class: 'pjs-field wide' }, h('span', null, 'Script (A)'), script));
        box.appendChild(textField('Valeur affichée (script, facultatif)', cmd.value_script, (v) => { cmd.value_script = v; }, { placeholder: 'ex. $game_variables[5]', class: 'pjs-input pjs-code-area' }));
        box.appendChild(h('div', { class: 'pjs-hint' }, 'Le script est lancé comme la commande « Script » d\'un évent (add_pokemon, add_item, $game_switches…). Un texte renvoyé s\'affiche en bas de l\'écran Debug. Les messages et choix ne marchent pas ici : utilise un évent commun pour eux.'));
      }
    }
    return box;
  }

  function renderDebug(content) {
    const catBlock = h('div', { class: 'pjs-block pjs-block-contacts' });
    const detailBlock = h('div', { class: 'pjs-block pjs-block-list' });
    content.appendChild(h('div', { class: 'pjs-row' }, catBlock, detailBlock));
    // catégories
    catBlock.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `Catégories (${S.debug.categories.length})`)));
    const list = h('div', { class: 'pjs-list' });
    S.debug.categories.forEach((c, i) => {
      const count = S.debug.commands.filter((m) => m.category === c.id).length;
      list.appendChild(h('div', { class: 'pjs-item' + (c.id === S.debugSel ? ' active' : '') + (c.visible === false ? ' hidden' : ''), onclick: () => { S.debugSel = c.id; render(); } },
        h('span', { class: 'pjs-mini-icon', style: { backgroundImage: `url("${iconUrl(c.icon)}")` } }),
        h('span', { class: 'pjs-name', title: c.id }, debugName(c)),
        count ? h('span', { class: 'pjs-count', title: `${count} commande(s)` }, String(count)) : null,
        h('button', { class: 'pjs-btn small', title: 'Monter', disabled: i === 0, onclick: (e) => { e.stopPropagation(); moveDebugCategory(c, -1); } }, '▲'),
        h('button', { class: 'pjs-btn small', title: 'Descendre', disabled: i === S.debug.categories.length - 1, onclick: (e) => { e.stopPropagation(); moveDebugCategory(c, 1); } }, '▼'),
        h('input', { type: 'checkbox', checked: c.visible !== false, title: 'Affichée dans l\'écran Debug', onclick: (e) => e.stopPropagation(), onchange: (e) => { c.visible = e.target.checked; render(); } })));
    });
    catBlock.appendChild(list);
    const newId = h('input', { class: 'pjs-input', placeholder: 'nouvelle catégorie (ex. tests)' });
    newId.addEventListener('keydown', (e) => { if (e.key === 'Enter') addDebugCategory(newId.value); });
    catBlock.appendChild(h('div', { class: 'pjs-add' }, newId, h('button', { class: 'pjs-btn secondary', onclick: () => addDebugCategory(newId.value) }, 'Ajouter')));
    catBlock.appendChild(h('div', { class: 'pjs-hint' }, 'L\'écran Debug s\'ouvre avec l\'appli Debug du téléphone, seulement quand le jeu est lancé en mode debug. L / R changent de catégorie en jeu.'));
    // valeurs par défaut
    const defaults = h('div', { class: 'pjs-section pjs-nums' }, h('div', { class: 'pjs-label' }, 'Valeurs de départ'),
      numberField('Niveau des Pokémon donnés', S.debug.pokemon_level, (v) => { S.debug.pokemon_level = v; }),
      numberField('Quantité des objets donnés', S.debug.item_count, (v) => { S.debug.item_count = v; }),
      numberField('Badges (région 1)', S.debug.badges, (v) => { S.debug.badges = v; }));
    catBlock.appendChild(defaults);

    // catégorie choisie
    const c = debugCategory();
    if (!c) { detailBlock.appendChild(h('div', { class: 'pjs-hint' }, 'Ajoute une catégorie.')); return; }
    const builtin = debugBuiltin(c.id);
    detailBlock.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, debugName(c)), h('span', { class: 'pjs-code' }, builtin ? `${c.id} (de base)` : c.id)));
    const nameSec = h('div', { class: 'pjs-section first' }, h('div', { class: 'pjs-label' }, `Nom (Data/Text/Dialogs/${S.debug.text_file_id}.csv, ligne ${c.name_row + 2})`),
      dTextFields(c.name_row, builtin ? builtin[1] : c.id, () => { const t = detailBlock.querySelector('.pjs-block-head h2'); if (t) t.textContent = debugName(c); }));
    detailBlock.appendChild(nameSec);
    detailBlock.appendChild(h('div', { class: 'pjs-section' }, h('div', { class: 'pjs-label' }, 'Aide affichée en bas de l\'écran'), dTextFields(c.help_row, builtin ? builtin[3] : 'A : valider')));
    // icône
    const icons = h('div', { class: 'pjs-variants' });
    (S.ctx.icons || []).forEach((name) => {
      icons.appendChild(h('button', { class: 'pjs-variant small' + ((c.icon || 'icon_debug') === name ? ' active' : ''), title: name + '.png', onclick: () => { c.icon = name; render(); } },
        h('span', { class: 'pjs-mini-icon', style: { backgroundImage: `url("${iconUrl(name)}")` } })));
    });
    detailBlock.appendChild(h('div', { class: 'pjs-section' }, h('div', { class: 'pjs-label' }, 'Icône (images du smartphone)'), icons));
    detailBlock.appendChild(h('div', { class: 'pjs-section row last' },
      h('span', { class: 'pjs-hint' }, builtin ? 'Catégorie de base : ses lignes habituelles restent sous tes commandes.' : 'Catégorie ajoutée : elle ne contient que tes commandes.'),
      builtin ? null : h('button', { class: 'pjs-btn small danger', onclick: () => removeDebugCategory(c) }, 'Supprimer la catégorie')));

    // commandes
    const cmdBlock = h('div', { class: 'pjs-block pjs-block-full' });
    content.appendChild(h('div', { class: 'pjs-row' }, cmdBlock));
    const cmds = S.debug.commands.filter((m) => m.category === c.id);
    cmdBlock.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `Commandes de « ${debugName(c)} » (${cmds.length})`),
      h('button', { class: 'pjs-btn secondary small', onclick: () => addDebugCommand(c.id) }, 'Ajouter une commande')));
    if (!cmds.length) cmdBlock.appendChild(h('div', { class: 'pjs-hint' }, 'Aucune commande. Elles s\'affichent en haut de la catégorie, dans l\'ordre de cette liste.'));
    cmds.forEach((cmd, i) => {
      const kindSel = h('select', { class: 'pjs-select' }, DEBUG_KINDS.map(([k, label]) => h('option', { value: k, selected: cmd.kind === k }, label)));
      kindSel.addEventListener('change', () => setCommandKind(cmd, kindSel.value));
      const catSel = h('select', { class: 'pjs-select' }, S.debug.categories.map((x) => h('option', { value: x.id, selected: x.id === cmd.category }, debugName(x))));
      catSel.addEventListener('change', () => { cmd.category = catSel.value; render(); });
      const card = h('div', { class: 'pjs-message' },
        h('div', { class: 'pjs-message-head' },
          h('span', { class: 'pjs-code' }, cmd.id),
          h('label', { class: 'pjs-inline' }, 'Type', kindSel),
          h('label', { class: 'pjs-inline' }, 'Catégorie', catSel),
          h('span', { class: 'pjs-spacer' }),
          h('button', { class: 'pjs-btn small', disabled: i === 0, title: 'Monter', onclick: () => moveDebugCommand(cmd, -1) }, '▲'),
          h('button', { class: 'pjs-btn small', disabled: i === cmds.length - 1, title: 'Descendre', onclick: () => moveDebugCommand(cmd, 1) }, '▼'),
          h('button', { class: 'pjs-btn small danger', onclick: () => { S.debug.commands = S.debug.commands.filter((m) => m !== cmd); render(); } }, 'Supprimer')),
        h('div', { class: 'pjs-label' }, 'Nom affiché'), dTextFields(cmd.label_row, 'Nom de la commande'),
        commandFields(cmd));
      cmdBlock.appendChild(card);
    });
  }

  function render() {
    if (!root) return;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' },
        h('span', { class: 'pjs-top-title' }, 'Smartphone'),
        h('div', { class: 'pjs-tabs' },
          [['phone', 'Téléphone'], ['friends', 'Amis'], ['debug', 'Debug']].map(([tab, label]) => h('button', {
            class: 'pjs-tab' + ((S.tab || 'phone') === tab ? ' active' : ''), onclick: () => { S.tab = tab; render(); },
          }, label))),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + statusText()[1] }, statusText()[0]),
        h('button', { class: 'pjs-btn secondary', onclick: () => loadProject(S.projectPath), title: 'Relire les fichiers du projet' }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.config) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return; }
    const content = h('div', { class: 'pjs-content' });
    page.appendChild(content);
    if (!S.ctx.hasPlugin) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le plugin pokesmart n\'est pas trouvé dans ce projet (scripts/pokesmart) : les réglages seront enregistrés, mais rien ne changera en jeu sans le plugin.'));
    if (S.tab === 'friends') { renderFriends(content); return; }
    if (S.tab === 'debug') { renderDebug(content); return; }
    parts.preview = h('div', { class: 'pjs-block pjs-block-preview' });
    parts.list = h('div', { class: 'pjs-block pjs-block-list' });
    parts.details = h('div', { class: 'pjs-block pjs-block-half' });
    parts.defaults = h('div', { class: 'pjs-block pjs-block-half' });
    content.appendChild(h('div', { class: 'pjs-row' }, parts.preview, parts.list));
    content.appendChild(h('div', { class: 'pjs-row' }, parts.details, parts.defaults));
    renderPreview();
    renderList();
    renderDetails();
  }

  // Aperçu du téléphone (applis visibles, dans l'ordre) ; glisser une appli pour la déplacer
  function renderPreview() {
    const box = parts.preview;
    if (!box || !S.config) return;
    box.textContent = '';
    const all = cases();
    const id = caseId();
    const theme = all[id];
    const scale = 2;
    const phone = h('div', { class: 'pjs-phone', style: { width: '122px', height: '223px', transform: `scale(${scale})` } });
    const holder = h('div', { class: 'pjs-phone-holder', style: { width: 122 * scale + 'px', height: 223 * scale + 'px' } }, phone);
    const at = (el, x, y) => { el.style.left = x + 'px'; el.style.top = y + 'px'; return el; };
    phone.appendChild(at(h('img', { class: 'pjs-px', src: caseFile(theme, 'phone') }), 0, 0));
    // fond d'écran (calé en bas à droite de l'écran)
    const [sx, sy, sw, sh] = theme.screen;
    let wall = S.config.default_wallpaper || (theme.wallpaper ? 'auto' : 'none');
    let wallNote = '';
    if (wall === 'auto') { wall = S.ctx.wallpapers.includes('025_wallpaper') ? '025_wallpaper' : S.ctx.wallpapers[0]; wallNote = 'Fond selon le Pokémon de tête (exemple : Pikachu)'; }
    if (wall && wall !== 'none') {
      const screen = at(h('div', { class: 'pjs-screen', style: { width: sw + 'px', height: sh + 'px' } }), sx, sy);
      screen.appendChild(h('img', { class: 'pjs-px pjs-wall', src: gfx('wallpapers/' + wall) }));
      phone.appendChild(screen);
    }
    // barre d'état
    phone.appendChild(at(h('img', { class: 'pjs-px', src: caseFile(theme, 'reseau_mobile_4') }), ...theme.network));
    phone.appendChild(at(h('img', { class: 'pjs-px', src: caseFile(theme, 'wifi_3') }), ...theme.wifi));
    phone.appendChild(at(h('img', { class: 'pjs-px', src: caseFile(theme, 'battery_80') }), ...theme.battery));
    const [cx, cy, cw, calign] = theme.clock;
    phone.appendChild(at(h('div', { class: 'pjs-text pjs-clock', style: { width: cw + 'px', textAlign: calign ? 'center' : 'left', color: COLORS[theme.clock_color ?? theme.color] || '#fff' } }, '12:00'), cx, cy + 1));
    const visible = S.config.app_order.filter((a) => !isHidden(a));
    const [tx, ty, tw, talign] = theme.title;
    const textColor = COLORS[theme.color] || '#fff';

    // applis : APPS_PER_PAGE par page (la page de l'appli choisie, sinon celle affichée),
    // puis les DOCK_APPS dernières dans la barre du bas, sous le séparateur (sur toutes les pages)
    const [gx, gy] = theme.grid;
    const [cellX, cellY] = theme.cell;
    const layout = homeLayout(theme);
    const dockCount = Math.max(0, Math.min(DOCK_APPS, COLUMNS, visible.length - 1));
    const pageApps = visible.slice(0, visible.length - dockCount);
    const dockApps = visible.slice(visible.length - dockCount);
    const pages = Math.max(1, Math.ceil(pageApps.length / APPS_PER_PAGE));
    const selIndex = pageApps.indexOf(S.selected);
    if (selIndex >= 0 && S.previewSelected !== S.selected) S.previewPage = Math.floor(selIndex / APPS_PER_PAGE);
    S.previewSelected = S.selected;
    const page = Math.min(Math.max(0, S.previewPage || 0), pages - 1);
    S.previewPage = page;
    const onPage = pageApps.slice(page * APPS_PER_PAGE, (page + 1) * APPS_PER_PAGE);
    const addTile = (action, x, y) => {
      const sel = action === S.selected;
      const tile = at(h('div', {
        class: 'pjs-tile' + (sel ? ' sel' : ''), draggable: 'true', title: `${appText(action)} (${action})`,
        onclick: () => { S.selected = action; renderPreview(); renderList(); renderDetails(); },
      }), x, y);
      tile.appendChild(h('img', { class: 'pjs-px', src: caseFile(theme, sel ? 'tile_selected' : 'tile'), draggable: 'false' }));
      tile.appendChild(h('div', { class: 'pjs-icon', style: { backgroundImage: `url("${gfx(iconName(action))}")`, backgroundPosition: sel ? '-22px 50%' : '0 50%' } }));
      if (isLocked(action)) { tile.classList.add('locked'); tile.title += ' — débloquée par une commande'; tile.appendChild(h('div', { class: 'pjs-lock' }, LOCK_SVG())); }
      tile.addEventListener('dragstart', (e) => { e.dataTransfer.setData('text/pjs-app', action); e.dataTransfer.effectAllowed = 'move'; });
      tile.addEventListener('dragover', (e) => { e.preventDefault(); tile.classList.add('drop'); });
      tile.addEventListener('dragleave', () => tile.classList.remove('drop'));
      tile.addEventListener('drop', (e) => {
        e.preventDefault();
        const dragged = e.dataTransfer.getData('text/pjs-app');
        if (dragged && dragged !== action) moveApp(dragged, S.config.app_order.indexOf(action));
      });
      phone.appendChild(tile);
    };
    onPage.forEach((action, i) => addTile(action, gx + (i % COLUMNS) * cellX, gy + Math.floor(i / COLUMNS) * cellY));
    if (dockApps.length && pageApps.length) {
      const sep = h('img', { class: 'pjs-px', src: caseFile(theme, 'dock_separator'), draggable: 'false' });
      sep.addEventListener('load', () => { sep.style.left = (sx + Math.floor((sw - sep.naturalWidth) / 2)) + 'px'; });
      phone.appendChild(at(sep, sx + Math.floor((sw - 90) / 2), layout.separator));
    }
    const dockShift = Math.floor((COLUMNS - dockApps.length) / 2);
    dockApps.forEach((action, i) => addTile(action, gx + (i + dockShift) * cellX, layout.dock));
    const shownApps = onPage.concat(dockApps);
    const title = shownApps.includes(S.selected) ? appText(S.selected) : (shownApps[0] ? appText(shownApps[0]) : '');
    phone.appendChild(at(h('div', { class: 'pjs-text pjs-title-txt', style: { width: tw + 'px', textAlign: talign ? 'center' : 'left', color: textColor } }, title), tx, ty));
    // points des pages : clic = changer de page, glisser une appli dessus = l'envoyer sur cette page
    if (pages > 1) {
      const left = sx + Math.floor((sw - pages * 8 + 2) / 2);
      for (let p = 0; p < pages; p++) {
        const dot = at(h('div', { class: 'pjs-page-dot', title: `Page ${p + 1}`, onclick: () => { S.previewPage = p; renderPreview(); } },
          h('img', { class: 'pjs-px', src: caseFile(theme, p === page ? 'page_dot_selected' : 'page_dot'), draggable: 'false' })), left + p * 8 - 2, layout.pages - 2);
        dot.addEventListener('dragover', (e) => { e.preventDefault(); dot.classList.add('drop'); });
        dot.addEventListener('dragleave', () => dot.classList.remove('drop'));
        dot.addEventListener('drop', (e) => {
          e.preventDefault();
          const dragged = e.dataTransfer.getData('text/pjs-app');
          if (!dragged) return;
          const first = pageApps.filter((a) => a !== dragged)[p * APPS_PER_PAGE];
          S.previewPage = p;
          moveApp(dragged, first ? S.config.app_order.filter((a) => a !== dragged).indexOf(first) : S.config.app_order.length);
        });
        phone.appendChild(dot);
      }
    }
    const caseSel = h('select', { class: 'pjs-select' }, Object.entries(all).map(([cid, c]) => h('option', { value: cid, selected: cid === id }, c.name || cid)));
    caseSel.addEventListener('change', () => { S.previewCase = caseSel.value; renderPreview(); });
    box.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Aperçu'), h('label', { class: 'pjs-inline' }, 'Coque', caseSel)));
    box.appendChild(holder);
    box.appendChild(h('div', { class: 'pjs-hint' }, wallNote ? wallNote + '. ' : '', `Clique sur une appli pour la modifier, glisse-la sur une autre pour changer sa place. ${APPS_PER_PAGE} applis par page`,
      dockCount ? ` + les ${dockCount} dernières dans la barre du bas, visibles sur toutes les pages` : '',
      pages > 1 ? ` ; clique sur un point pour changer de page (page ${page + 1}/${pages}), glisse une appli sur un point pour l'y envoyer.` : '.'));
  }

  function renderList() {
    const box = parts.list;
    if (!box || !S.config) return;
    box.textContent = '';
    const order = S.config.app_order;
    box.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `Applis (${order.length})`)));
    const list = h('div', { class: 'pjs-list' });
    let shown = 0;
    const visibleCount = order.filter((a) => !isHidden(a)).length;
    const dockFrom = visibleCount - Math.max(0, Math.min(DOCK_APPS, COLUMNS, visibleCount - 1));
    order.forEach((action, i) => {
      // début d'une nouvelle page du téléphone / de la barre du bas
      if (!isHidden(action)) {
        if (shown === dockFrom && shown > 0) list.appendChild(h('div', { class: 'pjs-page-sep dock' }, 'Barre du bas (toutes les pages)'));
        else if (shown > 0 && shown < dockFrom && shown % APPS_PER_PAGE === 0) list.appendChild(h('div', { class: 'pjs-page-sep' }, `Page ${shown / APPS_PER_PAGE + 1}`));
        shown++;
      }
      const item = h('div', {
        class: 'pjs-item' + (action === S.selected ? ' active' : '') + (isHidden(action) ? ' hidden' : ''), draggable: 'true',
        onclick: () => { S.selected = action; renderPreview(); renderList(); renderDetails(); },
      },
      h('span', { class: 'pjs-num' }, i + 1),
      h('span', { class: 'pjs-mini-icon', style: { backgroundImage: `url("${gfx(iconName(action))}")` } }),
      h('span', { class: 'pjs-name' }, appText(action)),
      isLocked(action) ? h('span', { class: 'pjs-lock-tag', title: `Débloquée par smartphone_unlock(:${action})` }, LOCK_SVG(), 'Commande') : null,
      h('span', { class: 'pjs-code' }, action),
      h('button', { class: 'pjs-btn small', title: 'Monter', disabled: i === 0, onclick: (e) => { e.stopPropagation(); moveApp(action, i - 1); } }, '▲'),
      h('button', { class: 'pjs-btn small', title: 'Descendre', disabled: i === order.length - 1, onclick: (e) => { e.stopPropagation(); moveApp(action, i + 1); } }, '▼'),
      h('button', { class: 'pjs-btn small', title: isHidden(action) ? 'Afficher dans le téléphone' : 'Cacher du téléphone', onclick: (e) => { e.stopPropagation(); toggleHidden(action); } }, isHidden(action) ? 'Cachée' : 'Visible'));
      item.addEventListener('dragstart', (e) => { e.dataTransfer.setData('text/pjs-app', action); });
      item.addEventListener('dragover', (e) => { e.preventDefault(); item.classList.add('drop'); });
      item.addEventListener('dragleave', () => item.classList.remove('drop'));
      item.addEventListener('drop', (e) => { e.preventDefault(); const d = e.dataTransfer.getData('text/pjs-app'); if (d && d !== action) moveApp(d, order.indexOf(action)); });
      list.appendChild(item);
    });
    box.appendChild(list);
    // ajout d'une appli
    const known = Object.keys(APP_ICONS).filter((a) => !order.includes(a));
    const sel = h('select', { class: 'pjs-select' }, h('option', { value: '' }, 'Ajouter une appli…'), known.map((a) => h('option', { value: a }, `${(APP_NAMES[a] || [LABEL(a)])[0]} (${a})`)), h('option', { value: '__other' }, 'Autre action…'));
    const other = h('input', { class: 'pjs-input', placeholder: 'open_ma_methode', style: { display: 'none' } });
    const otherBtn = h('button', { class: 'pjs-btn small', style: { display: 'none' }, onclick: () => addApp(other.value) }, 'Ajouter');
    other.addEventListener('keydown', (e) => { if (e.key === 'Enter') addApp(other.value); });
    sel.addEventListener('change', () => {
      const custom = sel.value === '__other';
      other.style.display = otherBtn.style.display = custom ? '' : 'none';
      if (custom) other.focus(); else if (sel.value) addApp(sel.value);
    });
    box.appendChild(h('div', { class: 'pjs-add' }, sel, other, otherBtn));
    box.appendChild(h('div', { class: 'pjs-hint' }, 'Une appli n\'apparaît en jeu que si sa méthode existe dans GamePlay::Menu (register_button). Les applis absentes de la liste se placent après.'));
  }

  // Détails de l'appli sélectionnée + réglages du téléphone
  function renderDetails() {
    const box = parts.details;
    if (!box || !S.config) return;
    box.textContent = '';
    const action = S.selected;
    if (action) {
      box.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, appText(action)), h('span', { class: 'pjs-code' }, action)));
      const sec = h('div', { class: 'pjs-section first' });
      sec.appendChild(h('div', { class: 'pjs-label' }, `Nom (Data/Text/Dialogs/${S.config.text_file_id}.csv, ligne ${S.config.app_texts[action] + 2})`));
      langs().forEach((lang) => {
        const input = h('input', { class: 'pjs-input', value: rawText(action, lang), placeholder: LABEL(action) });
        input.addEventListener('input', () => { setAppText(action, lang, input.value); renderPreview(); refreshListNames(); refreshStatus(); });
        sec.appendChild(h('label', { class: 'pjs-lang' }, h('span', null, lang), input));
      });
      box.appendChild(sec);
      // icône par défaut
      const variants = iconVariants(action);
      const iconSec = h('div', { class: 'pjs-section' }, h('div', { class: 'pjs-label' }, `Icône par défaut (${baseIcon(action)}${variants.length > 1 ? '_NN' : ''}.png)`));
      const grid = h('div', { class: 'pjs-variants' });
      variants.forEach((v) => {
        const active = defaultVariant(action) === v;
        grid.appendChild(h('button', {
          class: 'pjs-variant' + (active ? ' active' : ''), title: iconName(action, v) + '.png',
          onclick: () => { if (v) S.config.default_icons[action] = v; else delete S.config.default_icons[action]; render(); },
        }, h('span', { class: 'pjs-mini-icon big', style: { backgroundImage: `url("${gfx(iconName(action, v))}")` } }), h('span', { class: 'pjs-variant-name' }, variantLabel(action, v))));
      });
      iconSec.appendChild(grid);
      if (variants.length > 1) {
        // noms des variantes (affichés en jeu dans Personnaliser > Icônes)
        const names = h('div', { class: 'pjs-variant-names' }, h('div', { class: 'pjs-label' }, 'Noms des variantes (Personnaliser > Icônes)'));
        variants.forEach((v) => {
          const group = h('div', { class: 'pjs-variant-row' },
            h('span', { class: 'pjs-mini-icon', style: { backgroundImage: `url("${gfx(iconName(action, v))}")` } }),
            h('span', { class: 'pjs-code' }, iconName(action, v)));
          const fields = h('div', { class: 'pjs-variant-fields' });
          langs().forEach((lang) => {
            const input = h('input', { class: 'pjs-input', value: variantRaw(action, v, lang), placeholder: defaultVariantName(v, lang) });
            input.addEventListener('input', () => {
              setVariantText(action, v, lang, input.value);
              const chip = grid.children[variants.indexOf(v)];
              const label = chip && chip.querySelector('.pjs-variant-name');
              if (label) label.textContent = variantLabel(action, v);
              refreshStatus();
            });
            fields.appendChild(h('label', { class: 'pjs-lang' }, h('span', null, lang), input));
          });
          names.appendChild(h('div', { class: 'pjs-variant-group' }, group, fields));
        });
        iconSec.appendChild(names);
      }
      if (variants.length < 2) iconSec.appendChild(h('div', { class: 'pjs-hint' }, `Ajoute ${baseIcon(action)}_01.png, _02.png… dans graphics/interface/pokesmart pour proposer d'autres icônes.`));
      box.appendChild(iconSec);
      // déblocage
      const cmd = `smartphone_unlock(:${action})`;
      const unlockSel = h('select', { class: 'pjs-select' },
        h('option', { value: 'start', selected: !isLocked(action) }, 'Dès le début du jeu'),
        h('option', { value: 'command', selected: isLocked(action) }, 'Par une commande d\'évent'));
      unlockSel.addEventListener('change', () => setLocked(action, unlockSel.value === 'command'));
      const unlockSec = h('div', { class: 'pjs-section' }, h('div', { class: 'pjs-label' }, 'Déblocage'), unlockSel);
      if (isLocked(action)) {
        unlockSec.appendChild(h('div', { class: 'pjs-cmd' }, h('span', { class: 'pjs-code' }, cmd),
          h('button', { class: 'pjs-btn small secondary', onclick: () => copyText(cmd) }, 'Copier')));
        unlockSec.appendChild(h('div', { class: 'pjs-hint' }, 'Absente du téléphone jusqu\'à cette commande (Script dans un évent). ',
          h('span', { class: 'pjs-code' }, `smartphone_unlocked?(:${action})`), ' sert de condition, ',
          h('span', { class: 'pjs-code' }, `smartphone_lock(:${action})`), ' la retire à nouveau.'));
        if (['open_save', 'open_option'].includes(action)) unlockSec.appendChild(h('div', { class: 'pjs-hint warn' }, 'Attention : le joueur ne pourra pas utiliser cette appli avant la commande.'));
      }
      box.appendChild(unlockSec);
      const actions = h('div', { class: 'pjs-section row last' },
        h('label', { class: 'pjs-inline' }, h('input', { type: 'checkbox', checked: !isHidden(action), onchange: () => toggleHidden(action) }), ' Visible dans le téléphone'),
        DEFAULT_ORDER.includes(action) ? null : h('button', { class: 'pjs-btn small danger', onclick: () => removeApp(action) }, 'Retirer de la liste'));
      box.appendChild(actions);
    }
    // réglages du téléphone
    const defaults = parts.defaults;
    defaults.textContent = '';
    defaults.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Téléphone par défaut')));
    const sec = h('div', { class: 'pjs-section first last' });
    const all = cases();
    const caseSel = h('select', { class: 'pjs-select' }, Object.entries(all).map(([cid, c]) => h('option', { value: cid, selected: cid === S.config.default_case }, `${c.name || cid}${c.dir ? ` (${c.dir})` : ''}`)));
    caseSel.addEventListener('change', () => { S.config.default_case = caseSel.value; S.previewCase = null; render(); });
    sec.appendChild(h('label', { class: 'pjs-field' }, h('span', null, 'Coque'), caseSel));
    const wallSel = h('select', { class: 'pjs-select' },
      h('option', { value: '', selected: !S.config.default_wallpaper }, 'Selon la coque'),
      h('option', { value: 'auto', selected: S.config.default_wallpaper === 'auto' }, 'Selon le Pokémon de tête'),
      h('option', { value: 'none', selected: S.config.default_wallpaper === 'none' }, 'Aucun'),
      S.ctx.wallpapers.map((w) => h('option', { value: w, selected: S.config.default_wallpaper === w }, w)));
    wallSel.addEventListener('change', () => { S.config.default_wallpaper = wallSel.value; render(); });
    sec.appendChild(h('label', { class: 'pjs-field' }, h('span', null, "Fond d'écran"), wallSel));
    sec.appendChild(h('div', { class: 'pjs-hint' }, "Valeurs de départ : le joueur peut toujours les changer dans l'appli Personnaliser. "
      + `${S.ctx.icons.length} icônes, ${S.ctx.wallpapers.length} fonds et ${Object.keys(all).length} coques trouvés.`));
    defaults.appendChild(sec);
  }

  function rawText(action, lang) {
    const row = S.config.app_texts[action];
    const line = Number.isInteger(row) ? S.csv[row + 1] : null;
    const col = langIndex(lang);
    return (line && col >= 0 && line[col]) || '';
  }
  function refreshListNames() {
    if (!parts.list) return;
    parts.list.querySelectorAll('.pjs-item').forEach((item, i) => { const n = item.querySelector('.pjs-name'); if (n) n.textContent = appText(S.config.app_order[i]); });
  }
  function refreshStatus() {
    updateStatus();
  }

  // ---------------------------------------------------------------------------
  // Page « Smartphone » : onglet Plugins de Studio (vraie page de Studio : /plugins/smartphone)
  // (onglet et routes ajoutés à Studio par tools/studio-plugins/patch_studio_pages.py)
  // ---------------------------------------------------------------------------
  const PAGE_ID = 'smartphone';
  if (!(window.pjPluginPages = window.pjPluginPages || []).some((p) => p.id === PAGE_ID)) window.pjPluginPages.push({ id: PAGE_ID, label: 'Smartphone' });
  window.dispatchEvent(new Event('pj-plugin-pages'));

  // raccourci clavier (Ctrl+Maj+M) : va sur la page
  function open() {
    if (window.pjNavigate) window.pjNavigate('/plugins/' + PAGE_ID);
    else toast('Ouvre un projet pour accéder au smartphone (onglet Plugins)', true);
  }

  function mount(hostEl) {
    root = h('div', { id: 'pjs-root' });
    // les touches tapées dans la page ne remontent pas jusqu'aux raccourcis de Studio
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = true;
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.config || (latest && latest !== S.projectPath && !dirty())) loadProject(latest || null); else render();
  }

  // page ouverte / quittée (les modifications non enregistrées restent gardées jusqu'au retour sur la page)
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
    const k = e.key.toLowerCase();
    if (e.ctrlKey && e.shiftKey && k === 'm') { e.preventDefault(); open(); return; }
    if (!S.open) return;
    if (e.ctrlKey && k === 's') { e.preventDefault(); e.stopPropagation(); save(); return; }
    if (k === 'escape') {
      const el = document.activeElement;
      if (el && ['INPUT', 'SELECT', 'TEXTAREA'].includes(el.tagName) && root && root.contains(el)) { e.preventDefault(); el.blur(); }
    }
  }, true);

  // un fichier lâché à côté de la zone de dépôt ne doit pas faire quitter Studio
  ['dragover', 'drop'].forEach((type) => window.addEventListener(type, (e) => {
    if (root && root.contains(e.target) && [...(e.dataTransfer && e.dataTransfer.types || [])].includes('Files')) e.preventDefault();
  }));

  // garde le statut à jour
  setInterval(() => { if (S.open) refreshStatus(); }, 1000);

  window.pjSmartphoneEditor = { open, state: S };
})();

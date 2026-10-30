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
      grid: [13, 54], cell: [32, 30], radar: [6, 34], home: [[50, 66], [182, 194]],
    },
    motismart: {
      name: 'Motismart', dir: 'motismart/', phone: [99, 8], screen: [7, 25, 102, 173], wallpaper: false,
      network: [10, 17], wifi: [21, 17], battery: [94, 17], clock: [30, 14, 64, 1], clock_color: 9,
      title: [12, 27, 92, 0], color: 0, grid: [12, 46], cell: [33, 30], radar: [6, 25], home: [[50, 64], [198, 209]],
    },
  };
  const COLORS = { 0: '#212121', 9: '#ffffff' };
  const COLUMNS = 3;
  const APP_ICONS = {
    open_dex: 'icon_pokedex', open_party: 'icon_party', open_bag: 'icon_bag', open_map: 'icon_map', open_pc: 'icon_pc',
    open_quest: 'icon_book', open_tcard: 'icon_trainercard', open_friends: 'icon_friendlist', open_save: 'icon_save',
    open_option: 'icon_option', open_customization: 'icon_custom', open_mystery_gift: 'icon_mysterygift',
    open_mount: 'icon_mount', open_pokenav: 'icon_pokemon', open_card_game: 'icon_card', open_daycare: 'icon_egg',
    open_camera: 'icon_camera', open_fishing: 'icon_fishing',
  };
  const DEFAULT_ICON = 'icon_debug';
  // Noms des applis du plugin (français, anglais)
  const APP_NAMES = {
    open_map: ['Carte', 'Map'], open_pc: ['PC', 'PC'], open_quest: ['Journal', 'Quest log'], open_friends: ['Amis', 'Friends'],
    open_customization: ['Personnaliser', 'Customize'], open_mystery_gift: ['Cadeau Mystère', 'Mystery Gift'],
    open_mount: ['Monture', 'Mount'], open_pokenav: ['Pokénav', 'PokéNav'], open_card_game: ['Jeu de cartes', 'Card game'],
    open_daycare: ['Pension', 'Daycare'], open_camera: ['Appareil photo', 'Camera'], open_fishing: ['Pêche', 'Fishing'],
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
  const snapshot = () => JSON.stringify([S.config, S.csv, S.friends, S.fcsv]);
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
      S.saved = S.ctx.configExists && S.ctx.csv ? snapshot() : null;
      S.selected = S.config.app_order[0] || null;
      loadFonts();
    } catch (e) { S.error = e.message; }
    render();
  }

  async function save() {
    if (!S.config) return;
    try {
      const r = await call('save', { projectPath: S.projectPath, config: S.config, csv: S.csv, friends: S.friends, friendsCsv: S.fcsv });
      S.saved = snapshot();
      toast(`Enregistré : ${r.configFile} et ${r.csvFile}`);
      render();
    } catch (e) { toast('Erreur de sauvegarde : ' + e.message, true); }
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

  // Tête du personnage (première image, vers le bas) dans un canvas
  function drawFace(canvas, character, scale) {
    const ctx = canvas.getContext('2d');
    canvas.width = 32 * scale; canvas.height = 32 * scale;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    if (!character) return;
    const img = new Image();
    img.onload = () => {
      const fw = Math.floor(img.width / 4), fh = Math.floor(img.height / 4);
      const top = Math.max(fh - 32, 0);
      ctx.imageSmoothingEnabled = false;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, Math.floor((fw - 32) / 2), top, 32, Math.min(32, fh), 0, 0, 32 * scale, Math.min(32, fh) * scale);
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
      list.appendChild(h('div', { class: 'pjs-item' + (c.id === S.friendSel ? ' active' : ''), onclick: () => { S.friendSel = c.id; render(); } },
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
    const top = h('div', { class: 'pjs-friend-top' }, face);
    const fields = h('div', { class: 'pjs-friend-fields' });
    const charInput = h('input', { class: 'pjs-input', value: c.character || '', list: 'pjs-characters', placeholder: 'image de graphics/characters' });
    charInput.addEventListener('change', () => { c.character = charInput.value.trim(); drawFace(face, c.character, 2); refreshStatus(); });
    fields.appendChild(h('label', { class: 'pjs-field' }, h('span', null, 'Personnage'), charInput));
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

  // liste des personnages pour le champ « Personnage » (recherche en tapant)
  function charactersDatalist() {
    let list = document.getElementById('pjs-characters');
    if (!list) { list = h('datalist', { id: 'pjs-characters' }); document.body.appendChild(list); }
    if (list.dataset.project !== S.projectPath) {
      list.textContent = '';
      (S.ctx.characters || []).forEach((n) => list.appendChild(h('option', { value: n })));
      list.dataset.project = S.projectPath;
    }
  }

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  let root = null;
  const parts = {};

  function render() {
    if (!root) return;
    root.textContent = '';
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' },
        h('span', { class: 'pjs-top-title' }, 'Smartphone'),
        h('div', { class: 'pjs-tabs' },
          [['phone', 'Téléphone'], ['friends', 'Amis']].map(([tab, label]) => h('button', {
            class: 'pjs-tab' + ((S.tab || 'phone') === tab ? ' active' : ''), onclick: () => { S.tab = tab; render(); },
          }, label))),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('span', { class: 'pjs-status' + (dirty() ? ' dirty' : '') }, S.config ? (dirty() ? 'Modifications non enregistrées' : 'Tout est enregistré') : ''),
        h('button', { class: 'pjs-btn secondary', onclick: () => loadProject(S.projectPath), title: 'Relire les fichiers du projet' }, 'Recharger'),
        h('button', { class: 'pjs-btn primary', onclick: save, disabled: !S.config, title: 'Ctrl+S' }, 'Enregistrer'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.config) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement…')); return; }
    const content = h('div', { class: 'pjs-content' });
    page.appendChild(content);
    if (!S.ctx.hasPlugin) content.appendChild(h('div', { class: 'pjs-warn' }, 'Le plugin pokesmart n\'est pas trouvé dans ce projet (scripts/pokesmart) : les réglages seront enregistrés, mais rien ne changera en jeu sans le plugin.'));
    if (S.tab === 'friends') { charactersDatalist(); renderFriends(content); return; }
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
    const title = S.selected && !isHidden(S.selected) ? appText(S.selected) : (visible[0] ? appText(visible[0]) : '');
    phone.appendChild(at(h('div', { class: 'pjs-text pjs-title-txt', style: { width: tw + 'px', textAlign: talign ? 'center' : 'left', color: textColor } }, title), tx, ty));
    // applis
    const [gx, gy] = theme.grid;
    const [cellX, cellY] = theme.cell;
    visible.forEach((action, i) => {
      const sel = action === S.selected;
      const tile = at(h('div', {
        class: 'pjs-tile' + (sel ? ' sel' : ''), draggable: 'true', title: `${appText(action)} (${action})`,
        onclick: () => { S.selected = action; renderPreview(); renderList(); renderDetails(); },
      }), gx + (i % COLUMNS) * cellX, gy + Math.floor(i / COLUMNS) * cellY);
      tile.appendChild(h('img', { class: 'pjs-px', src: caseFile(theme, sel ? 'tile_selected' : 'tile'), draggable: 'false' }));
      tile.appendChild(h('div', { class: 'pjs-icon', style: { backgroundImage: `url("${gfx(iconName(action))}")`, backgroundPosition: sel ? '-22px 50%' : '0 50%' } }));
      tile.addEventListener('dragstart', (e) => { e.dataTransfer.setData('text/pjs-app', action); e.dataTransfer.effectAllowed = 'move'; });
      tile.addEventListener('dragover', (e) => { e.preventDefault(); tile.classList.add('drop'); });
      tile.addEventListener('dragleave', () => tile.classList.remove('drop'));
      tile.addEventListener('drop', (e) => {
        e.preventDefault();
        const dragged = e.dataTransfer.getData('text/pjs-app');
        if (dragged && dragged !== action) moveApp(dragged, S.config.app_order.indexOf(action));
      });
      phone.appendChild(tile);
    });
    const caseSel = h('select', { class: 'pjs-select' }, Object.entries(all).map(([cid, c]) => h('option', { value: cid, selected: cid === id }, c.name || cid)));
    caseSel.addEventListener('change', () => { S.previewCase = caseSel.value; renderPreview(); });
    box.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Aperçu'), h('label', { class: 'pjs-inline' }, 'Coque', caseSel)));
    box.appendChild(holder);
    box.appendChild(h('div', { class: 'pjs-hint' }, wallNote ? wallNote + '. ' : '', 'Clique sur une appli pour la modifier, glisse-la sur une autre pour changer sa place.'));
  }

  // Liste ordonnée des applis
  function renderList() {
    const box = parts.list;
    if (!box || !S.config) return;
    box.textContent = '';
    const order = S.config.app_order;
    box.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, `Applis (${order.length})`)));
    const list = h('div', { class: 'pjs-list' });
    order.forEach((action, i) => {
      const item = h('div', {
        class: 'pjs-item' + (action === S.selected ? ' active' : '') + (isHidden(action) ? ' hidden' : ''), draggable: 'true',
        onclick: () => { S.selected = action; renderPreview(); renderList(); renderDetails(); },
      },
      h('span', { class: 'pjs-num' }, i + 1),
      h('span', { class: 'pjs-mini-icon', style: { backgroundImage: `url("${gfx(iconName(action))}")` } }),
      h('span', { class: 'pjs-name' }, appText(action)),
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
    const st = root && root.querySelector('.pjs-status');
    if (st) { st.className = 'pjs-status' + (dirty() ? ' dirty' : ''); st.textContent = dirty() ? 'Modifications non enregistrées' : 'Tout est enregistré'; }
  }

  // ---------------------------------------------------------------------------
  // Page « Smartphone » : affichée à la place de la page de Studio, à droite du menu
  // de la base de données (le menu reste visible ; une autre entrée du menu la ferme)
  // ---------------------------------------------------------------------------
  let host = null;      // zone (menu + page) de la base de données
  let hidden = [];      // éléments de Studio cachés pendant que la page est ouverte
  let pendingOpen = false;

  const findMenu = () => {
    const quests = document.querySelector('a[href$="/database/quests"]');
    return quests && quests.parentElement && quests.parentElement.parentElement;
  };
  const entryEl = () => document.querySelector('[data-pjs-entry]');

  function open() {
    const menu = findMenu();
    if (!menu || !menu.parentElement) {
      // pas sur la base de données : on y va, la page s'ouvrira dès que le menu sera là
      const link = document.querySelector('a[href$="/database/pokemon"], a[href*="/database"]');
      if (link) { pendingOpen = true; link.click(); } else toast('Ouvre un projet pour accéder au smartphone', true);
      return;
    }
    if (S.open && root && document.body.contains(root)) return;
    host = menu.parentElement;
    hidden = [...host.children].filter((el) => el !== menu && el.id !== 'pjs-root');
    hidden.forEach((el) => { el.dataset.pjsDisplay = el.style.display || ''; el.style.display = 'none'; });
    root = h('div', { id: 'pjs-root' });
    host.appendChild(root);
    S.open = true;
    menu.setAttribute('data-pjs-open', '1');
    const entry = entryEl(); if (entry) entry.classList.add('pjs-active');
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.config || (latest && latest !== S.projectPath && !dirty())) loadProject(latest || null); else render();
  }

  // Ferme la page (rend sa place à la page de Studio)
  function close() {
    if (root) root.remove();
    root = null;
    hidden.forEach((el) => { el.style.display = el.dataset.pjsDisplay || ''; delete el.dataset.pjsDisplay; });
    hidden = [];
    S.open = false;
    const menu = findMenu(); if (menu) menu.removeAttribute('data-pjs-open');
    const entry = entryEl(); if (entry) entry.classList.remove('pjs-active');
  }

  // Section « Plugins » ajoutée au menu de la base de données (sous Données / Level design),
  // faite en copiant les éléments de Studio pour garder le même style
  function updateLauncher() {
    // page retirée par Studio (changement de section) : on oublie la page, les données restent
    if (S.open && root && !document.body.contains(root)) { root = null; hidden = []; S.open = false; }
    const quests = document.querySelector('a[href$="/database/quests"]');
    const section = quests && quests.parentElement;
    const menu = section && section.parentElement;
    if (!menu) return;
    if (!menu.querySelector('[data-pjs="plugins"]')) {
      const title = section.querySelector('span.title');
      const plugins = section.cloneNode(false);
      plugins.setAttribute('data-pjs', 'plugins');
      const head = title ? title.cloneNode(false) : document.createElement('span');
      head.className = title ? title.className : 'title';
      head.textContent = 'Plugins';
      plugins.appendChild(head);
      const entry = quests.cloneNode(true);
      entry.removeAttribute('href');
      entry.removeAttribute('aria-current');
      entry.classList.remove('active');
      entry.removeAttribute('data-active-forced');
      entry.setAttribute('role', 'button');
      entry.setAttribute('data-pjs-entry', '1');
      entry.title = 'Éditeur du smartphone (Ctrl+Maj+M)';
      const label = entry.firstElementChild || entry;
      label.textContent = 'Smartphone';
      entry.addEventListener('click', (e) => { e.preventDefault(); e.stopPropagation(); open(); });
      plugins.appendChild(entry);
      menu.appendChild(plugins);
      // une autre entrée du menu referme la page
      menu.addEventListener('click', (e) => {
        const link = e.target.closest('a[href]');
        if (!link || !S.open) return;
        if (dirty() && !confirm('Smartphone : des modifications ne sont pas enregistrées. Quitter quand même ? (elles restent gardées)')) { e.preventDefault(); e.stopPropagation(); return; }
        close();
      }, true);
    }
    if (S.open) { const entry = entryEl(); if (entry) entry.classList.add('pjs-active'); menu.setAttribute('data-pjs-open', '1'); }
    if (pendingOpen) { pendingOpen = false; open(); }
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; updateLauncher(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); updateLauncher(); };
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

  // garde le statut à jour
  setInterval(() => { if (S.open) refreshStatus(); }, 1000);

  window.pjSmartphoneEditor = { open, close, state: S };
})();

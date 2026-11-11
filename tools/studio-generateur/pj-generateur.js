/* eslint-disable */
// =============================================================================
// Générateur de personnages — page « Générateurs > Personnages » de Pokémon Studio
// Assemble un personnage à partir des pièces (base, cheveux, haut, bas, chapeau, sac) et écrit :
//   graphics/characters/<nom>_<m|f>_walk / _run / _cycle_roll / _swim / _misc2 (arrosage)
//   graphics/battlers/Battlers DS/<nom>_<m|f> (dresseur de face) et graphics/battlers/<nom>_<m|f>_back (dos)
// Les pièces sont lues dans les dossiers réglés en bas de la page (par défaut Documents\Pokémon\…).
// =============================================================================
(() => {
  if (window.__pjGenerateurLoaded) return;
  window.__pjGenerateurLoaded = true;

  const PAGE_ID = 'personnages';
  // sprites faits, dans l'ordre d'affichage
  const KINDS = [
    { id: 'walk', label: 'Marche', dir: 'graphics/characters', suffix: '_walk', sheet: true },
    { id: 'run', label: 'Course', dir: 'graphics/characters', suffix: '_run', sheet: true },
    { id: 'bike', label: 'Vélo', dir: 'graphics/characters', suffix: '_cycle_roll', sheet: true },
    { id: 'swim', label: 'Nage', dir: 'graphics/characters', suffix: '_swim', sheet: true },
    { id: 'water', label: 'Arrosage', dir: 'graphics/characters', suffix: '_misc2', sheet: true },
    { id: 'front', label: 'Dresseur (face)', dir: 'graphics/battlers/Battlers DS', suffix: '' },
    { id: 'back', label: 'Dresseur (dos)', dir: 'graphics/battlers', suffix: '_back', frames: 5 },
  ];
  // ordre des calques
  const LAYERS = ['base', 'bottom', 'top', 'bag', 'hair', 'hat'];
  const CATS = [
    { id: 'hair', label: 'Cheveux' },
    { id: 'top', label: 'Haut' },
    { id: 'bottom', label: 'Bas' },
    { id: 'hat', label: 'Chapeau', optional: true },
    { id: 'bag', label: 'Sac', optional: true },
  ];
  const SKINS = { pale: '#f8dcc4', light: '#f0c098', medium: '#c88850', dark: '#7a4a2a' };
  const SKIN_LABELS = { pale: 'Pâle', light: 'Claire', medium: 'Mate', dark: 'Foncée' };
  const COLOR_HEX = {
    black: '#2a2a32', blue: '#3a6ad8', green: '#3a9a48', red: '#d83a3a', white: '#f0f0f0', yellow: '#f0d040', purple: '#8a4ac8',
    pink: '#f08ac0', orange: '#f08a30', magenta: '#d03aa8', brown: '#8a5a30', grey: '#9090a0', navy: '#283a78', wine: '#7a2040',
    beige: '#d8c098', aqua: '#40c8c8', cyan: '#40d8f0', gold: '#e8b830', silver: '#c0c8d0', blonde: '#f0d080', ginger: '#e07a30',
    lavender: '#b8a0e8', 'light blue': '#88c0f0', 'light green': '#98e088', 'powder blue': '#a8d0f0', dark: '#3a3a48', light: '#d8d8e0',
  };
  const COLOR_FR = {
    black: 'noir', blue: 'bleu', green: 'vert', red: 'rouge', white: 'blanc', yellow: 'jaune', purple: 'violet', pink: 'rose', orange: 'orange',
    magenta: 'magenta', brown: 'marron', grey: 'gris', navy: 'marine', wine: 'bordeaux', beige: 'beige', aqua: 'turquoise', cyan: 'cyan',
    gold: 'or', silver: 'argent', blonde: 'blond', ginger: 'roux', lavender: 'lavande', 'light blue': 'bleu clair', 'light green': 'vert clair',
    'powder blue': 'bleu poudre', dark: 'foncé', light: 'clair',
  };
  const ITEM_FR = {
    't-shirt': 'T-shirt', 'tank top': 'Débardeur', hoodie: 'Sweat à capuche', 'v-neck': 'Col en V', turtleneck: 'Col roulé', vest: 'Gilet',
    trenchcoat: 'Trench', 'open jacket': 'Veste ouverte', 'scarf shirt': 'Chemise à foulard', 'shirt combo': 'Chemise + t-shirt',
    'collared shirt': 'Chemise à col', 'classy top': 'Haut chic', 'formal top': 'Haut habillé', 'beach top': 'Haut de plage',
    'jumpsuit top': 'Combinaison', 'jumpsuit alt top': 'Combinaison (variante)', 'lord suit': 'Costume de seigneur', 'school uniform': 'Uniforme scolaire',
    jeans: 'Jean', shorts: 'Short', capris: 'Pantacourt', 'pants and boots': 'Pantalon et bottes', 'long skirt': 'Jupe longue',
    'pencil skirt': 'Jupe crayon', 'ribbon skirt': 'Jupe à ruban', 'classy bottom': 'Bas chic', 'formal bottom': 'Bas habillé',
    'beach bottom': 'Bas de plage', 'jumpsuit pants': 'Pantalon de combinaison', 'jumpsuit pants alt': 'Pantalon de combinaison (variante)',
    'lord suit pants': 'Pantalon de seigneur', 'school uniform bottom': 'Bas d\'uniforme',
    beanie: 'Bonnet', beret: 'Béret', bonnet: 'Capeline', 'cat ears': 'Oreilles de chat', crown: 'Couronne', devil: 'Cornes de diable',
    'feather hat': 'Chapeau à plume', fedora: 'Fedora', flower: 'Fleur', glasses: 'Lunettes', 'hair band': 'Serre-tête', headband: 'Bandeau',
    miner: 'Casque de mineur', poop: 'Caca', ribbon: 'Ruban', 'straw hat': 'Chapeau de paille', 'sun hat': 'Chapeau de soleil',
    'youngster hat': 'Casquette de gamin', 'ball cap': 'Casquette', cap: 'Casquette (variante)', baguette: 'Baguette',
    bag: 'Sacoche', rucksack: 'Sac à dos', 'sporty backpack': 'Sac de sport',
  };
  const label = (key) => ITEM_FR[key] || (key.charAt(0).toUpperCase() + key.slice(1));
  const colorLabel = (c) => COLOR_FR[c] || c || 'unique';

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
  const pick = (list) => list[Math.floor(Math.random() * list.length)];
  const uniq = (list) => [...new Set(list)];
  const fileName = (s) => String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9_]+/g, '_').replace(/^_+|_+$/g, '');

  // ---------------------------------------------------------------------------
  // État
  // ---------------------------------------------------------------------------
  const S = {
    open: false, projectPath: null, ctx: null, error: null,
    spec: null, locks: {}, name: 'hero', outputs: Object.fromEntries(KINDS.map((k) => [k.id, true])),
    images: new Map(), // fichier -> Promise<HTMLImageElement|null>
    showSources: false, frame: 0,
  };
  let root = null;
  let previews = []; // { kind, canvas, sheet }

  // ---------------------------------------------------------------------------
  // Pièces
  // ---------------------------------------------------------------------------
  const entries = (kind) => (S.ctx && S.ctx.kinds[kind]) || [];
  const allEntries = () => KINDS.flatMap((k) => entries(k.id));
  const okGender = (e, g) => !e.gender || e.gender === g;

  // choix possibles pour un genre : { skins, hair: {style: [couleurs]}, top: {clé: [couleurs]}, … }
  function options(g) {
    const all = allEntries().filter((e) => okGender(e, g));
    const out = { skins: uniq(all.filter((e) => e.cat === 'base').map((e) => e.key)) };
    ['hair', 'top', 'bottom', 'hat', 'bag'].forEach((cat) => {
      const map = {};
      all.filter((e) => e.cat === cat).forEach((e) => { (map[e.key] = map[e.key] || new Set()).add(e.color); });
      out[cat] = Object.fromEntries(Object.entries(map).map(([k, set]) => [k, [...set].sort((a, b) => (COLOR_HEX[a] ? 0 : 1) - (COLOR_HEX[b] ? 0 : 1) || a.localeCompare(b))]));
    });
    const order = ['pale', 'light', 'medium', 'dark'];
    out.skins.sort((a, b) => order.indexOf(a) - order.indexOf(b));
    return out;
  }
  const keysOf = (map, cat) => Object.keys(map).sort((a, b) => (cat === 'hair' ? Number(a) - Number(b) : label(a).localeCompare(label(b))));

  // pièce d'un sprite pour un choix ({ key, color }) -> { file, exact } ou null
  function resolvePart(kind, cat, g, choice) {
    if (!choice) return null;
    const list = entries(kind).filter((e) => e.cat === cat && okGender(e, g));
    let same = list.filter((e) => e.key === choice.key);
    let exact = true;
    if (!same.length) {
      if (cat === 'hair' || cat === 'base') { same = list.filter((e) => e.key === list[0]?.key); exact = false; } else return null;
    }
    same.sort((a, b) => (b.gender === g) - (a.gender === g));
    const color = same.find((e) => e.color === choice.color) || same.find((e) => !e.color) || same[0];
    if (color && choice.color && color.color !== choice.color) exact = false;
    return color ? { file: color.file, exact } : null;
  }

  // calques d'un sprite
  function layersFor(kind, spec) {
    const g = spec.gender;
    const out = [];
    let approx = [];
    LAYERS.forEach((cat) => {
      if (kind === 'back' && cat === 'bottom') return; // le dos n'a qu'un vêtement (haut + bas)
      const choice = cat === 'base' ? { key: spec.skin, color: '' } : spec[cat];
      if (!choice) return;
      const part = resolvePart(kind, cat, g, choice);
      // une pièce absente n'est signalée que si ce sprite a ce genre de pièce (les dresseurs n'ont pas de sac…)
      if (!part) { if (cat !== 'base' && entries(kind).some((e) => e.cat === cat)) approx.push(cat); return; }
      if (!part.exact) approx.push(cat);
      out.push({ file: part.file, tint: cat === 'base' ? spec.skinTint || null : choice.tint || null });
    });
    return { layers: out, approx, hasBase: out.length > 0 && !!resolvePart(kind, 'base', g, { key: spec.skin }) };
  }

  // --- couleur libre : la pièce prend la teinte choisie, en gardant ses ombres et ses reflets (contours gardés) ---
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
    const f = (t) => { if (t < 0) t += 1; if (t > 1) t -= 1; return t < 1 / 6 ? p + (q - p) * 6 * t : t < 0.5 ? q : t < 2 / 3 ? p + (q - p) * (2 / 3 - t) * 6 : p; };
    return [f(hue + 1 / 3), f(hue), f(hue - 1 / 3)].map((v) => Math.max(0, Math.min(255, Math.round(v * 255))));
  }
  const OUTLINE_L = 0.15;
  function tintCanvas(img, hex) {
    const c = document.createElement('canvas'); c.width = img.width; c.height = img.height;
    const g = c.getContext('2d'); g.drawImage(img, 0, 0);
    const v = parseInt(String(hex).replace('#', ''), 16);
    if (Number.isNaN(v)) return c;
    const [th, ts, tl] = rgbToHsl((v >> 16) & 255, (v >> 8) & 255, v & 255);
    const data = g.getImageData(0, 0, c.width, c.height); const d = data.data;
    let n = 0; let ms = 0; let ml = 0;
    for (let i = 0; i < d.length; i += 4) {
      if (!d[i + 3]) continue;
      const [, s, l] = rgbToHsl(d[i], d[i + 1], d[i + 2]);
      if (l < OUTLINE_L) continue;
      n++; ms += s; ml += l;
    }
    if (!n) return c;
    ms /= n; ml /= n;
    const cache = new Map();
    for (let i = 0; i < d.length; i += 4) {
      if (!d[i + 3]) continue;
      const key = (d[i] << 16) | (d[i + 1] << 8) | d[i + 2];
      let rgb = cache.get(key);
      if (!rgb) {
        const [, s, l] = rgbToHsl(d[i], d[i + 1], d[i + 2]);
        rgb = l < OUTLINE_L ? [d[i], d[i + 1], d[i + 2]]
          : hslToRgb(th, ms > 0.04 ? Math.min(1, s * ts / ms) : ts, Math.max(0, Math.min(1, l + tl - ml)));
        cache.set(key, rgb);
      }
      d[i] = rgb[0]; d[i + 1] = rgb[1]; d[i + 2] = rgb[2];
    }
    g.putImageData(data, 0, 0);
    return c;
  }

  function loadImage(file) {
    if (!S.images.has(file)) {
      S.images.set(file, call('readImages', { files: [file] }).then((m) => new Promise((resolve) => {
        if (!m[file]) { resolve(null); return; }
        const img = new Image();
        img.onload = () => resolve(img);
        img.onerror = () => resolve(null);
        img.src = m[file];
      })).catch(() => null));
    }
    return S.images.get(file);
  }

  // image assemblée d'un sprite -> canvas
  async function compose(kind, spec) {
    const { layers } = layersFor(kind, spec);
    const imgs = await Promise.all(layers.map((l) => loadImage(l.file)));
    const base = imgs[0];
    if (!base) return null;
    const c = document.createElement('canvas');
    c.width = base.width; c.height = base.height;
    const g = c.getContext('2d');
    imgs.forEach((img, i) => { if (img) g.drawImage(layers[i].tint ? tintCanvas(img, layers[i].tint) : img, 0, 0); });
    return c;
  }

  // ---------------------------------------------------------------------------
  // Personnage
  // ---------------------------------------------------------------------------
  function randomChoice(opts, cat, keep) {
    const keys = Object.keys(opts[cat] || {});
    if (!keys.length) return null;
    const key = keep && opts[cat][keep.key] ? keep.key : pick(keys);
    return { key, color: pick(opts[cat][key]) };
  }

  function randomSpec(base) {
    const spec = base ? clone(base) : {};
    const L = base ? S.locks : {};
    if (!L.gender) spec.gender = pick(['m', 'f']);
    const opts = options(spec.gender);
    if (!L.skin || !opts.skins.includes(spec.skin)) { spec.skin = pick(opts.skins.length ? opts.skins : ['light']); delete spec.skinTint; }
    CATS.forEach(({ id, optional }) => {
      if (L[id] && (spec[id] === null || (spec[id] && opts[id][spec[id].key]))) return;
      if (optional && Math.random() < 0.5) { spec[id] = null; return; }
      spec[id] = randomChoice(opts, id);
    });
    return spec;
  }

  // garde les choix valables après un changement de genre
  function fixSpec(spec) {
    const opts = options(spec.gender);
    if (!opts.skins.includes(spec.skin)) spec.skin = opts.skins[0] || 'light';
    CATS.forEach(({ id, optional }) => {
      const cur = spec[id];
      if (cur === null && optional) return;
      if (cur && opts[id][cur.key]) { if (!opts[id][cur.key].includes(cur.color)) cur.color = opts[id][cur.key][0]; return; }
      spec[id] = optional ? null : randomChoice(opts, id);
    });
    return spec;
  }

  const outName = (kind) => `${fileName(S.name) || 'hero'}_${S.spec.gender}${kind.suffix}`;

  // ---------------------------------------------------------------------------
  // Chargement / enregistrement
  // ---------------------------------------------------------------------------
  async function loadProject(projectPath) {
    S.projectPath = projectPath; S.ctx = null; S.error = null; S.images = new Map();
    render();
    if (!projectPath) { S.error = 'Aucun projet ouvert.'; render(); return; }
    try {
      S.ctx = await call('getContext', { projectPath });
      if (!allEntries().length) S.showSources = true;
      if (!S.spec && allEntries().length) S.spec = randomSpec();
      else if (S.spec) fixSpec(S.spec);
    } catch (e) { S.error = e.message; }
    render();
  }

  async function saveConfig() {
    await call('saveConfig', { projectPath: S.projectPath, config: S.ctx.config });
  }

  async function exportSprites() {
    if (!S.spec) return;
    const kinds = KINDS.filter((k) => S.outputs[k.id] && layersFor(k.id, S.spec).hasBase);
    if (!kinds.length) { toast('Aucun sprite à créer : coche au moins un sprite disponible', true); return; }
    const files = [];
    for (const k of kinds) {
      let c = await compose(k.id, S.spec);
      if (c && k.frames) c = verticalStrip(c, k.frames);
      if (c) files.push({ dir: k.dir, name: outName(k), dataUrl: c.toDataURL('image/png') });
    }
    const replaced = files.filter((f) => (S.ctx.existing[f.dir] || []).includes(f.name));
    if (replaced.length && !confirm(`Remplacer ${replaced.length} image(s) existante(s) ?\n${replaced.map((f) => `${f.dir}/${f.name}.png`).join('\n')}`)) return;
    try {
      const r = await call('exportSprites', { projectPath: S.projectPath, files });
      r.written.forEach((rel) => {
        const dir = rel.split('/').slice(0, -1).join('/');
        const name = rel.split('/').pop().replace(/\.png$/, '');
        if (!(S.ctx.existing[dir] = S.ctx.existing[dir] || []).includes(name)) S.ctx.existing[dir].push(name);
      });
      toast(`${r.written.length} sprite(s) créé(s) dans graphics/characters et graphics/battlers`);
      render();
    } catch (e) { toast('Erreur : ' + e.message, true); }
  }

  // dresseur de dos : PSDK lit les images les unes sous les autres (une par ligne)
  function verticalStrip(src, frames) {
    const fw = Math.floor(src.width / frames);
    const c = document.createElement('canvas'); c.width = fw; c.height = src.height * frames;
    const g = c.getContext('2d');
    for (let i = 0; i < frames; i++) g.drawImage(src, i * fw, 0, fw, src.height, 0, i * src.height, fw, src.height);
    return c;
  }

  // copie les pièces dans le projet pour la personnalisation en jeu (commande personnaliser_joueur)
  async function exportPartsForGame() {
    try {
      const r = await call('exportParts', { projectPath: S.projectPath, labels: ITEM_FR, colorLabels: COLOR_FR, colorHex: COLOR_HEX, skinLabels: SKIN_LABELS, skinHex: SKINS });
      toast(`${r.count} pièces copiées dans graphics/generateur (personnalisation en jeu prête)`);
    } catch (e) { toast('Erreur : ' + e.message, true); }
  }

  async function saveCharacter() {
    const name = fileName(S.name) || 'hero';
    const list = S.ctx.config.characters;
    const i = list.findIndex((c) => c.name === name);
    const entry = { name, spec: clone(S.spec) };
    if (i >= 0) list[i] = entry; else list.push(entry);
    try { await saveConfig(); toast(`Personnage « ${name} » gardé`); render(); } catch (e) { toast('Erreur : ' + e.message, true); }
  }

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------
  function render() {
    if (!root) return;
    root.textContent = '';
    previews = [];
    const project = projectList().find((p) => p.projectPath === S.projectPath);
    root.appendChild(h('div', { class: 'pjs-topbar' },
      h('div', { class: 'pjs-topbar-left' },
        h('span', { class: 'pjs-top-title' }, 'Personnages'),
        h('span', { class: 'pjs-top-sub' }, project ? (project.projectTitle || project.title || '') : '')),
      h('div', { class: 'pjs-topbar-right' },
        h('button', { class: 'pjs-btn secondary', onclick: () => { S.spec = randomSpec(S.spec); render(); }, disabled: !S.spec, title: 'Tire au hasard les pièces qui ne sont pas verrouillées (Ctrl+R)' }, '🎲 Au hasard'),
        h('button', { class: 'pjs-btn primary', onclick: exportSprites, disabled: !S.spec, title: 'Écrit les sprites cochés dans le projet' }, 'Créer les sprites'))));
    const page = h('div', { class: 'pjs-page' });
    root.appendChild(page);
    if (S.error) { page.appendChild(h('div', { class: 'pjs-empty err' }, S.error)); return; }
    if (!S.ctx) { page.appendChild(h('div', { class: 'pjs-empty' }, 'Chargement des pièces…')); return; }
    const content = h('div', { class: 'pjs-content pjg-content' });
    page.appendChild(content);
    if (!allEntries().length) content.appendChild(h('div', { class: 'pjs-warn' }, 'Aucune pièce trouvée : règle les dossiers des pièces ci-dessous.'));
    if (S.spec) {
      const row = h('div', { class: 'pjs-row pjg-row' });
      row.appendChild(renderControls());
      row.appendChild(renderPreview());
      content.appendChild(row);
    }
    content.appendChild(renderSources());
    drawPreviews();
  }

  function lockBtn(id) {
    return h('button', {
      class: 'pjg-lock' + (S.locks[id] ? ' on' : ''), title: S.locks[id] ? 'Verrouillé : « Au hasard » le garde' : 'Verrouiller pour « Au hasard »',
      onclick: () => { S.locks[id] = !S.locks[id]; render(); },
    }, S.locks[id] ? '🔒' : '🔓');
  }

  function swatches(colors, current, onPick) {
    return h('div', { class: 'pjg-swatches' }, colors.map((c) => h('button', {
      class: 'pjg-swatch' + (c === current ? ' active' : '') + (COLOR_HEX[c] ? '' : ' text'), title: colorLabel(c),
      style: COLOR_HEX[c] ? { backgroundColor: COLOR_HEX[c] } : null, onclick: () => onPick(c),
    }, COLOR_HEX[c] ? '' : colorLabel(c))));
  }

  // couleurs en plus de celles de la pièce (teinte appliquée en gardant ombres et reflets) — mêmes listes que le jeu
  const EXTRA_COLORS = [
    ['#d83c3c', 'Rouge'], ['#8c2838', 'Bordeaux'], ['#f07860', 'Corail'], ['#f08c28', 'Orange'], ['#f0d23c', 'Jaune'],
    ['#c8a032', 'Moutarde'], ['#96d250', 'Vert clair'], ['#50a03c', 'Vert'], ['#788c46', 'Kaki'], ['#64d2aa', 'Menthe'],
    ['#3cb4b4', 'Turquoise'], ['#50c8f0', 'Cyan'], ['#78aaf0', 'Bleu ciel'], ['#3c6ed2', 'Bleu'], ['#283c82', 'Marine'],
    ['#b496e6', 'Lavande'], ['#7850d2', 'Violet'], ['#783c8c', 'Prune'], ['#f096be', 'Rose'], ['#d24696', 'Fuchsia'],
    ['#8c5a32', 'Marron'], ['#d2b48c', 'Beige'], ['#f0f0f0', 'Blanc'], ['#969696', 'Gris'], ['#3c3c46', 'Noir'],
  ];
  const EXTRA_SKINS = [
    ['#ffe0cc', 'Très claire'], ['#f5c9a6', 'Claire rosée'], ['#e0a878', 'Dorée'], ['#c68650', 'Hâlée'],
    ['#9a6238', 'Mate'], ['#6e4226', 'Foncée'], ['#4a2c1a', 'Très foncée'],
  ];

  function extraSwatches(list, current, onPick, skin) {
    return h('div', { class: 'pjg-swatches pjg-extra' }, list.map(([hex, name]) => h('button', {
      class: 'pjg-swatch' + (skin ? ' skin' : '') + (current === hex ? ' active' : ''), title: name, style: { backgroundColor: hex },
      onclick: () => onPick(hex),
    })));
  }

  function renderControls() {
    const spec = S.spec;
    const opts = options(spec.gender);
    const block = h('div', { class: 'pjs-block pjg-controls' });
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Personnage'),
      S.ctx.config.characters.length ? h('select', {
        class: 'pjs-select pjg-saved', title: 'Personnages gardés',
        onchange: (e) => { const c = S.ctx.config.characters.find((x) => x.name === e.target.value); if (c) { S.name = c.name; S.spec = fixSpec(clone(c.spec)); render(); } },
      }, h('option', { value: '' }, 'Personnages gardés…'), S.ctx.config.characters.map((c) => h('option', { value: c.name }, c.name))) : null));
    const name = h('input', { class: 'pjs-input', value: S.name, placeholder: 'hero' });
    name.addEventListener('input', () => { S.name = name.value; updateNames(); });
    block.appendChild(h('div', { class: 'pjs-section first pjg-line' }, h('span', { class: 'pjs-label' }, 'Nom'), name,
      h('button', { class: 'pjs-btn small', onclick: saveCharacter, title: 'Garde ce personnage dans la liste (pour le refaire plus tard)' }, 'Garder'),
      S.ctx.config.characters.some((c) => c.name === fileName(S.name)) ? h('button', {
        class: 'pjs-btn small', title: 'Retire ce personnage de la liste',
        onclick: async () => { S.ctx.config.characters = S.ctx.config.characters.filter((c) => c.name !== fileName(S.name)); await saveConfig(); render(); },
      }, 'Oublier') : null));
    block.appendChild(h('div', { class: 'pjs-section pjg-line' }, h('span', { class: 'pjs-label' }, 'Genre'),
      h('div', { class: 'pjs-variants' }, [['m', 'Garçon'], ['f', 'Fille']].map(([g, l]) => h('button', {
        class: 'pjs-variant' + (spec.gender === g ? ' active' : ''), onclick: () => { spec.gender = g; fixSpec(spec); render(); },
      }, l))), lockBtn('gender')));
    block.appendChild(h('div', { class: 'pjs-section pjg-line' }, h('span', { class: 'pjs-label' }, 'Peau'),
      h('div', { class: 'pjg-swatches' }, opts.skins.map((s) => h('button', {
        class: 'pjg-swatch skin' + (spec.skin === s && !spec.skinTint ? ' active' : ''), title: SKIN_LABELS[s] || s, style: { backgroundColor: SKINS[s] || '#ccc' },
        onclick: () => { spec.skin = s; delete spec.skinTint; render(); },
      }))), lockBtn('skin')));
    block.appendChild(extraSwatches(EXTRA_SKINS, spec.skinTint, (hex) => { spec.skinTint = hex; render(); }, true));
    CATS.forEach(({ id, label: catLabel, optional }) => {
      const map = opts[id] || {};
      const cur = spec[id];
      const sel = h('select', { class: 'pjs-select', onchange: (e) => {
        const v = e.target.value;
        spec[id] = v === '' ? null : { key: v, color: (cur && map[v].includes(cur.color)) ? cur.color : map[v][0] };
        render();
      } },
      optional ? h('option', { value: '', selected: !cur }, 'Aucun') : null,
      keysOf(map, id).map((k) => h('option', { value: k, selected: cur && cur.key === k }, id === 'hair' ? `Coiffure ${k}` : label(k))));
      const sec = h('div', { class: 'pjs-section pjg-part' },
        h('div', { class: 'pjg-line' }, h('span', { class: 'pjs-label' }, catLabel), sel, lockBtn(id)));
      if (cur && map[cur.key]) {
        const sw = (map[cur.key].length > 1 || map[cur.key][0]) ? swatches(map[cur.key], cur.tint ? null : cur.color, (c) => { cur.color = c; delete cur.tint; render(); }) : h('div', { class: 'pjg-swatches' });
        sec.appendChild(sw);
        sec.appendChild(extraSwatches(EXTRA_COLORS, cur.tint, (hex) => { cur.tint = hex; render(); }));
      }
      block.appendChild(sec);
    });
    block.appendChild(h('div', { class: 'pjs-hint' }, 'Les cadenas gardent une pièce quand tu tires un personnage au hasard. Une pièce absente d\'un sprite (ex. coiffure 5 seulement en nage / arrosage) y est remplacée par la plus proche.'));
    return block;
  }

  function renderPreview() {
    const block = h('div', { class: 'pjs-block pjg-preview' });
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Sprites')));
    const grid = h('div', { class: 'pjg-grid' });
    KINDS.forEach((k) => {
      const lay = layersFor(k.id, S.spec);
      const has = lay.hasBase;
      const canvas = h('canvas', { class: 'pjg-canvas' + (k.sheet ? ' sheet' : '') });
      const nameEl = h('code', { class: 'pjg-out' }, `${k.dir.slice(9)}/${outName(k)}.png`);
      const exists = (S.ctx.existing[k.dir] || []).includes(outName(k));
      const card = h('div', { class: 'pjg-card' + (has ? '' : ' off') },
        h('label', { class: 'pjg-card-head' },
          h('input', { type: 'checkbox', checked: has && S.outputs[k.id], disabled: !has, onchange: (e) => { S.outputs[k.id] = e.target.checked; } }),
          h('span', null, k.label),
          lay.approx.length && has ? h('span', { class: 'pjg-approx', title: 'Pièces absentes ou d\'une autre couleur pour ce sprite : ' + lay.approx.map((c) => (CATS.find((x) => x.id === c) || { label: c }).label).join(', ') }, '≈') : null),
        h('div', { class: 'pjg-stage' }, has ? canvas : h('span', { class: 'pjs-hint inline' }, 'pièces introuvables')),
        h('div', { class: 'pjg-out-line' + (exists ? ' exists' : ''), title: exists ? 'Ce fichier existe déjà : il sera remplacé' : '' }, nameEl));
      grid.appendChild(card);
      if (has) previews.push({ kind: k, canvas, nameEl, line: card.lastChild });
    });
    block.appendChild(grid);
    block.appendChild(h('div', { class: 'pjs-hint' }, 'Le joueur : $game_player.set_appearance_set("nom") utilise <nom>_m_walk / <nom>_f_walk, _run, _cycle_roll et _misc2 (arrosage des baies). Dresseur de face : graphics/battlers/Battlers DS ; de dos : graphics/battlers.'));
    return block;
  }

  function updateNames() {
    previews.forEach((p) => {
      p.nameEl.textContent = `${p.kind.dir.slice(9)}/${outName(p.kind)}.png`;
      const ex = (S.ctx.existing[p.kind.dir] || []).includes(outName(p.kind));
      p.line.classList.toggle('exists', ex);
      p.line.title = ex ? 'Ce fichier existe déjà : il sera remplacé' : '';
    });
  }

  // aperçus : les sprites composés, animés (une image par direction pour les feuilles 4 x 4)
  let drawToken = 0;
  async function drawPreviews() {
    const token = ++drawToken;
    for (const p of previews) {
      const c = await compose(p.kind.id, S.spec);
      if (token !== drawToken) return;
      p.sheet = c;
    }
    paintFrames();
  }
  function paintFrames() {
    previews.forEach((p) => {
      const src = p.sheet;
      if (!src) return;
      const c = p.canvas; const g = c.getContext('2d');
      if (p.kind.sheet) {
        const fw = src.width / 4; const fh = src.height / 4;
        if (c.width !== fw * 4) { c.width = fw * 4; c.height = fh; }
        g.clearRect(0, 0, c.width, c.height);
        const col = S.frame % 4;
        // bas, gauche, droite, haut
        for (let row = 0; row < 4; row++) g.drawImage(src, col * fw, row * fh, fw, fh, row * fw, 0, fw, fh);
      } else if (p.kind.frames) {
        const fw = src.width / p.kind.frames;
        if (c.width !== fw) { c.width = fw; c.height = src.height; }
        g.clearRect(0, 0, c.width, c.height);
        g.drawImage(src, (Math.floor(S.frame / 2) % p.kind.frames) * fw, 0, fw, src.height, 0, 0, fw, src.height);
      } else {
        if (c.width !== src.width) { c.width = src.width; c.height = src.height; }
        g.clearRect(0, 0, c.width, c.height);
        g.drawImage(src, 0, 0);
      }
    });
  }
  setInterval(() => { if (S.open && previews.length) { S.frame++; paintFrames(); } }, 220);

  function renderSources() {
    const cfg = S.ctx.config;
    const block = h('div', { class: 'pjs-block pjg-sources' });
    block.appendChild(h('div', { class: 'pjs-block-head' }, h('h2', null, 'Dossiers des pièces'),
      h('button', { class: 'pjs-btn small', onclick: () => { S.showSources = !S.showSources; render(); } }, S.showSources ? 'Masquer' : 'Afficher')));
    const counts = Object.fromEntries(KINDS.map((k) => [k.id, entries(k.id).length]));
    block.appendChild(h('div', { class: 'pjs-hint inline' }, KINDS.map((k) => `${k.label} : ${counts[k.id]}`).join(' · ')));
    if (!S.showSources) return block;
    cfg.sources.forEach((src, i) => {
      const rep = (S.ctx.report || [])[i];
      block.appendChild(h('div', { class: 'pjs-section pjg-line' },
        h('code', { class: 'pjg-path', title: src.path }, src.path),
        h('select', { class: 'pjs-select', onchange: async (e) => { src.kind = e.target.value; await saveConfig(); loadProject(S.projectPath); } },
          [['auto', 'Automatique (marche, course, vélo, dresseur)'], ['swim', 'Nage'], ['water', 'Arrosage']].map(([v, l]) => h('option', { value: v, selected: (src.kind || 'auto') === v }, l))),
        h('span', { class: 'pjs-hint inline' + (rep && !rep.ok ? ' err' : '') }, rep ? (rep.ok ? `${rep.count} pièces` : rep.error) : ''),
        h('button', { class: 'pjs-btn small', onclick: async () => { cfg.sources.splice(i, 1); await saveConfig(); loadProject(S.projectPath); } }, 'Retirer')));
    });
    block.appendChild(h('div', { class: 'pjs-section last pjg-line' },
      h('button', { class: 'pjs-btn secondary', onclick: async () => {
        try {
          const dir = await call('pickFolder', {});
          if (!dir) return;
          cfg.sources.push({ path: dir, kind: /swim/i.test(dir) ? 'swim' : /water/i.test(dir) ? 'water' : 'auto' });
          await saveConfig(); loadProject(S.projectPath);
        } catch (e) { toast(e.message, true); }
      } }, 'Ajouter un dossier'),
      h('button', { class: 'pjs-btn small', onclick: () => loadProject(S.projectPath) }, 'Relire les dossiers'),
      h('button', { class: 'pjs-btn small', onclick: exportPartsForGame, title: 'Copie toutes les pièces dans graphics/generateur pour que le joueur crée son personnage en jeu (commande personnaliser_joueur)' }, 'Préparer pour le jeu')));
    block.appendChild(h('div', { class: 'pjs-hint' }, 'Automatique : le dossier contient « overworld walk », « overworld run », « overworld bike », « trainer front male »… avec dedans base(s), hair, tops / clothing, bottoms, hats, carrying stuff. Nage / Arrosage : le dossier contient directement Base, Hair, Tops, Bottoms…'));
    return block;
  }

  // ---------------------------------------------------------------------------
  // Page « Générateurs > Personnages » (vraie page de Studio : /generators/personnages)
  // ---------------------------------------------------------------------------
  if (!(window.pjPluginPages = window.pjPluginPages || []).some((p) => p.id === PAGE_ID)) window.pjPluginPages.push({ id: PAGE_ID, label: 'Personnages', place: 'generator' });
  window.dispatchEvent(new Event('pj-plugin-pages'));

  function open() {
    if (window.pjNavigate) window.pjNavigate('/generators/' + PAGE_ID);
    else toast('Ouvre un projet pour accéder au générateur (onglet Générateurs)', true);
  }

  function mount(hostEl) {
    root = h('div', { id: 'pjg-root' });
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    hostEl.appendChild(root);
    S.open = true;
    const latest = projectList()[0] && projectList()[0].projectPath;
    if (!S.ctx || (latest && latest !== S.projectPath)) loadProject(latest || null); else render();
  }

  function checkPage() {
    const hostEl = document.getElementById('pj-page-' + PAGE_ID);
    if (root && hostEl && hostEl.contains(root)) return;
    if (root) { root = null; previews = []; S.open = false; }
    if (hostEl) mount(hostEl);
  }
  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; checkPage(); }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); checkPage(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  window.addEventListener('keydown', (e) => {
    if (!S.open) return;
    const k = e.key.toLowerCase();
    const typing = e.target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName);
    if (e.ctrlKey && k === 'r' && !typing && S.spec) { e.preventDefault(); e.stopPropagation(); S.spec = randomSpec(S.spec); render(); }
  }, true);

  window.pjGenerateurEditor = { open, state: S, layersFor, options };
})();

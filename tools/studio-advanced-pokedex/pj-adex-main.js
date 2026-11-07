/* eslint-disable */
// =============================================================================
// Advanced Pokédex (plugin « advanced_pokedex ») — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-adex:* ».
// Lit / écrit Data/configs/plugins/advanced_pokedex.json (personnages, mise en page, textes).
// À chaque enregistrement, le plugin installé (scripts/00000 Plugins/<n> advanced_pokedex) reçoit les scripts
// à jour et scripts/advanced_pokedex.psdkplug est reconstruit.
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const CONFIG_FILE = 'Data/configs/plugins/advanced_pokedex.json';
const INFOS_FILE = 'Data/configs/plugins/pokedex_infos.json';
const FLAGS_FILE = 'Data/configs/plugins/pokemon_flags.json';
const PLUGIN_NAME = 'advanced_pokedex';
const PLUGIN_SOURCE = 'scripts/advanced_pokedex';
const PLUGINS_INSTALLED = 'scripts/00000 Plugins';
const ASSETS = ['bg_height', 'bg_weight', 'title_height', 'title_weight', 'tab_height', 'tab_weight', 'scale'];

const join = (projectPath, rel) => path.join(projectPath, ...rel.split('/'));
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const norm = (b) => b.toString('utf8').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');
const dataUrl = async (file, mime) => (exists(file) ? `data:${mime};base64,` + (await fsp.readFile(file)).toString('base64') : null);

function parseCsv(text) {
  const rows = []; let row = []; let cur = ''; let q = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (q) {
      if (ch === '"') { if (text[i + 1] === '"') { cur += '"'; i++; } else q = false; } else cur += ch;
    } else if (ch === '"') q = true;
    else if (ch === ',') { row.push(cur); cur = ''; }
    else if (ch === '\n' || ch === '\r') { if (ch === '\r' && text[i + 1] === '\n') i++; row.push(cur); rows.push(row); row = []; cur = ''; }
    else cur += ch;
  }
  if (cur !== '' || row.length) { row.push(cur); rows.push(row); }
  return rows;
}

async function writeAtomic(file, content) {
  await fsp.mkdir(path.dirname(file), { recursive: true });
  if (exists(file) && !exists(file + '.bak')) await fsp.copyFile(file, file + '.bak');
  const tmp = file + '.tmp';
  await fsp.writeFile(tmp, content);
  await fsp.rename(tmp, file);
}

const safeName = (name) => String(name || '').replace(/[\\/:*?"<>|]/g, '').replace(/^\.+/, '');

// Pokémon de Studio : nom, taille, poids et sprite de face de chaque forme
async function creatures(projectPath) {
  const dir = join(projectPath, 'Data/Studio/pokemon');
  if (!exists(dir)) return [];
  const textFile = join(projectPath, 'Data/Text/Dialogs/100000.csv');
  const texts = exists(textFile) ? parseCsv(fs.readFileSync(textFile, 'utf8').replace(/^\uFEFF/, '')) : null;
  const col = texts ? Math.max(0, texts[0].indexOf('fr') >= 0 ? texts[0].indexOf('fr') : texts[0].indexOf('en')) : 0;
  const out = [];
  for (const f of (await fsp.readdir(dir)).filter((n) => n.endsWith('.json'))) {
    try {
      const d = JSON.parse(await fsp.readFile(path.join(dir, f), 'utf8'));
      if (!d.dbSymbol || d.dbSymbol === '__undef__') continue;
      const row = texts && texts[d.id + 1];
      out.push({
        id: d.id, dbSymbol: d.dbSymbol, name: (row && row[col]) || d.dbSymbol,
        forms: (d.forms || []).map((fm) => ({ form: fm.form, height: fm.height, weight: fm.weight, front: (fm.resources || {}).front || '', icon: (fm.resources || {}).icon || '' })),
      });
    } catch (e) { /* ignoré */ }
  }
  return out.sort((a, b) => a.id - b.id);
}

// n° -> db_symbol des Pokémon de Studio (gardé tant que le dossier ne change pas)
const indexCache = new Map();
async function creatureIndex(projectPath) {
  const dir = join(projectPath, 'Data/Studio/pokemon');
  if (!exists(dir)) return {};
  const files = (await fsp.readdir(dir)).filter((n) => n.endsWith('.json'));
  const stamp = files.length + ':' + (await fsp.stat(dir)).mtimeMs;
  const cached = indexCache.get(projectPath);
  if (cached && cached.stamp === stamp) return cached.index;
  const index = {};
  for (const f of files) {
    try {
      const text = await fsp.readFile(path.join(dir, f), 'utf8');
      const id = /"id"\s*:\s*(-?\d+)/.exec(text);
      const db = /"dbSymbol"\s*:\s*"([^"]+)"/.exec(text);
      if (id && db) index[id[1]] = db[1];
    } catch (e) { /* ignoré */ }
  }
  indexCache.set(projectPath, { stamp, index });
  return index;
}

// Images proposées pour les personnages (dossiers characters et battlers)
async function spriteList(projectPath) {
  const out = [];
  for (const folder of ['characters', 'battlers']) {
    const dir = join(projectPath, 'graphics/' + folder);
    if (!exists(dir)) continue;
    (await fsp.readdir(dir)).filter((n) => n.toLowerCase().endsWith('.png')).forEach((n) => out.push(`${folder}/${n.slice(0, -4)}`));
  }
  return out.sort();
}

// ---------------------------------------------------------------------------
// Plugin : scripts installés + paquet .psdkplug
// ---------------------------------------------------------------------------
async function listFilesDeep(dir, ext) {
  if (!exists(dir)) return [];
  const out = [];
  const walk = async (d, prefix) => {
    for (const ent of await fsp.readdir(d, { withFileTypes: true })) {
      if (ent.isDirectory()) await walk(path.join(d, ent.name), prefix + ent.name + '/');
      else if (ent.name.toLowerCase().endsWith(ext)) out.push(prefix + ent.name);
    }
  };
  await walk(dir, '');
  return out.sort();
}

function installedPluginDir(projectPath) {
  const base = join(projectPath, PLUGINS_INSTALLED);
  if (!exists(base)) return null;
  const name = fs.readdirSync(base).find((n) => new RegExp(`^\\d+ ${PLUGIN_NAME}$`).test(n));
  return name ? path.join(base, name) : null;
}

async function pluginStatus(projectPath) {
  const source = join(projectPath, `${PLUGIN_SOURCE}/scripts`);
  if (!exists(source)) return { source: false, installed: null, outdated: [], stale: [] };
  const dir = installedPluginDir(projectPath);
  const files = await listFilesDeep(source, '.rb');
  if (!dir) return { source: true, installed: null, outdated: files, stale: [] };
  const outdated = [];
  for (const rel of files) {
    const dest = path.join(dir, ...rel.split('/'));
    if (!exists(dest) || norm(await fsp.readFile(dest)) !== norm(await fsp.readFile(path.join(source, ...rel.split('/'))))) outdated.push(rel);
  }
  const stale = (await listFilesDeep(dir, '.rb')).filter((rel) => !files.includes(rel));
  return { source: true, installed: path.relative(projectPath, dir).split(path.sep).join('/'), outdated, stale };
}

async function syncInstalledPlugin(projectPath) {
  const st = await pluginStatus(projectPath);
  if (!st.source || !st.installed) return { ...st, copied: [], removed: [] };
  const source = join(projectPath, `${PLUGIN_SOURCE}/scripts`);
  const dir = join(projectPath, st.installed);
  for (const rel of st.outdated) {
    const dest = path.join(dir, ...rel.split('/'));
    await fsp.mkdir(path.dirname(dest), { recursive: true });
    await fsp.copyFile(path.join(source, ...rel.split('/')), dest);
  }
  for (const rel of st.stale) await fsp.unlink(path.join(dir, ...rel.split('/')));
  return { ...st, copied: st.outdated, removed: st.stale, outdated: [], stale: [] };
}

function buildPluginPackage(projectPath) {
  return new Promise((resolve) => {
    if (process.platform !== 'win32' || !exists(join(projectPath, 'psdk.bat'))) { resolve({ built: false, error: 'psdk.bat introuvable' }); return; }
    const { spawn } = require('child_process');
    let output = '';
    let done = false;
    const child = spawn('cmd.exe', ['/d', '/c', 'psdk.bat', '--util=plugin', 'build', PLUGIN_NAME], { cwd: projectPath, windowsHide: true });
    const finish = (r) => { if (!done) { done = true; clearTimeout(timer); resolve(r); } };
    const timer = setTimeout(() => { try { child.kill(); } catch (e) { /* rien */ } finish({ built: false, error: 'trop long (plus de 3 minutes)' }); }, 180000);
    child.stdout.on('data', (d) => { output += d; });
    child.stderr.on('data', (d) => { output += d; });
    child.on('error', (e) => finish({ built: false, error: e.message }));
    child.on('close', (code) => {
      const ok = code === 0 && /Done!/.test(output);
      finish(ok ? { built: true } : { built: false, error: (output.trim().split(/\r?\n/).pop() || `code ${code}`).slice(0, 200) });
    });
  });
}

const handlers = {
  async getContext({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    let config = null;
    const file = join(projectPath, CONFIG_FILE);
    if (exists(file)) {
      try { config = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')); } catch (e) { throw new Error('advanced_pokedex.json illisible : ' + e.message); }
    }
    const assets = {};
    for (const name of ASSETS) assets[name] = await dataUrl(join(projectPath, `graphics/pokedex/advanced/${name}.png`), 'image/png');
    // habillage du Pokédex PE (plugin interface_pe)
    for (const name of ['adv_height', 'adv_weight', 'ball_on', 'ball_off']) assets['pe_' + name] = await dataUrl(join(projectPath, `graphics/pokedex/pe/${name}.png`), 'image/png');
    let peEnabled = false;
    for (const dir of [`${PLUGINS_INSTALLED}`, 'scripts/interface_pe/scripts']) {
      const base = join(projectPath, dir);
      if (!exists(base)) continue;
      const files = await listFilesDeep(base, '.rb');
      const conf = files.find((f) => /(^|\/)(\d+ interface_pe\/)?00100 Pokedex\/001 Configuration\.rb$/.test(f));
      const adv = files.find((f) => /00100 Pokedex\/008 Advanced Pokedex\.rb$/.test(f));
      if (conf && adv) { peEnabled = /ENABLED\s*=\s*true/.test(await fsp.readFile(path.join(base, ...conf.split('/')), 'utf8')); break; }
    }
    const fonts = {};
    for (const [key, name] of [['main', 'PokemonDS'], ['small', 'PowerGreenSmall']]) fonts[key] = await dataUrl(join(projectPath, `Fonts/${name}.ttf`), 'font/ttf');
    return {
      config,
      creatures: await creatures(projectPath),
      sprites: await spriteList(projectPath),
      assets,
      fonts,
      peEnabled: peEnabled && !!assets.pe_adv_height,
      plugin: await pluginStatus(projectPath),
    };
  },

  // Images du projet (chemins relatifs à graphics/, sans extension) en data: URL
  async readImages({ projectPath, files }) {
    const out = {};
    for (const rel of files || []) {
      const clean = String(rel || '').replace(/\\/g, '/').replace(/^\/+|\.\.(\/|$)/g, '');
      out[rel] = clean ? await dataUrl(join(projectPath, `graphics/${clean}.png`), 'image/png') : null;
    }
    return out;
  },

  async save({ projectPath, config }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    await writeAtomic(join(projectPath, CONFIG_FILE), JSON.stringify(config, null, 2) + '\n');
    const sync = await syncInstalledPlugin(projectPath);
    return { plugin: { source: sync.source, installed: sync.installed, copied: sync.copied, removed: sync.removed } };
  },

  // Couleur, habitat et génération des Pokémon (bloc ajouté à la page Pokémon)
  // (renvoie aussi __index : n° du Pokémon -> db_symbol, pour retrouver le Pokémon affiché par Studio)
  async getInfos({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    const file = join(projectPath, INFOS_FILE);
    let data = { klass: 'PokedexInfosConfig', creatures: {} };
    if (exists(file)) {
      try { data = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')); } catch (e) { throw new Error('pokedex_infos.json illisible : ' + e.message); }
    }
    data.__index = await creatureIndex(projectPath);
    return data;
  },

  async saveInfos({ projectPath, data }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    if (!data || typeof data !== 'object') throw new Error('données invalides');
    data = Object.assign({}, data);
    delete data.__index;
    data.klass = 'PokedexInfosConfig';
    await writeAtomic(join(projectPath, INFOS_FILE), JSON.stringify(data, null, 2) + '\n');
    return { file: INFOS_FILE };
  },

  // Groupes (flags) des Pokémon : starter, légendaire, Ultra-Chimère… (bloc « Groupes » de la page Pokémon)
  async getFlags({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    const file = join(projectPath, FLAGS_FILE);
    let data = { klass: 'PokemonFlagsConfig', flags: [], creatures: {} };
    if (exists(file)) {
      try { data = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')); } catch (e) { throw new Error('pokemon_flags.json illisible : ' + e.message); }
    }
    if (!Array.isArray(data.flags)) data.flags = [];
    if (!data.creatures || typeof data.creatures !== 'object') data.creatures = {};
    data.__index = await creatureIndex(projectPath);
    return data;
  },

  async saveFlags({ projectPath, data }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    if (!data || typeof data !== 'object') throw new Error('données invalides');
    data = Object.assign({}, data);
    delete data.__index;
    data.klass = 'PokemonFlagsConfig';
    await writeAtomic(join(projectPath, FLAGS_FILE), JSON.stringify(data, null, 2) + '\n');
    return { file: FLAGS_FILE };
  },

  async buildPlugin({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, `${PLUGIN_SOURCE}/config.yml`))) return { built: false, error: 'plugin introuvable' };
    return buildPluginPackage(projectPath);
  },

  async pluginStatus({ projectPath }) {
    return pluginStatus(projectPath);
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-adex:' + name;
    try { ipcMain.removeHandler(channel); } catch (e) { /* rien */ }
    ipcMain.handle(channel, async (_event, payload) => {
      try { return { ok: true, value: await fn(payload || {}) }; } catch (e) { return { ok: false, error: String((e && e.message) || e) }; }
    });
  });
}

module.exports = { register, handlers };

try {
  const electron = require('electron');
  if (electron && electron.ipcMain) register(electron.ipcMain);
} catch (e) { /* hors Electron (tests) */ }

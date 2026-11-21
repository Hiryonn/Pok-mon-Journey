/* eslint-disable */
// =============================================================================
// Réglages des plugins récents — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-reglages:* ».
// Une page de Studio par fichier de réglages :
//   dex-tasks      Données > Pokédex > Tâches            pokedex_tasks.json  (plugin advanced_pokedex)
//   champs-baies   Données > Baies > Champs de baies     champs_baies.json   (plugin berrydex)
//   styles-pla     Données > Gimmicks > Styles PLA       styles_pla.json     (plugin gimmicks)
//   sac-de-frappe  Level design > Mini-jeux > Sac de frappe  sac_de_frappe.json (plugin sac_de_frappe)
//   poke-recre     Level design > Mini-jeux > Poké Récré     poke_recre.json    (plugin poke_recre)
//   raids          Données > Gimmicks > Raids                raids.json         (plugin raids)
//   raids-cartes   Level design > Carte de région > Cartes d'aventure  raids_cartes.json (plugin raids)
//   tournois       Level design > Dresseurs > Tournois   tournois.json      (plugin tournoi)
//   pokeblocs      Données > Baies > Pokéblocs           pokeblocs.json     (plugin pokeblocs)
//   concours       Level design > Mini-jeux > Concours   concours.json      (plugin concours)
//   pokeathlon     Level design > Mini-jeux > Pokéathlon pokeathlon.json    (plugin pokeathlon)
//   dodrio         Level design > Mini-jeux > Cueillette Dodrio dodrio.json (plugin dodrio)
//   lance_ball     Level design > Mini-jeux > Lance-Ball lance_ball.json     (plugin lance_ball)
// À chaque enregistrement, le plugin installé (scripts/00000 Plugins/<n> <plugin>) reçoit les scripts à jour, puis
// le paquet .psdkplug est reconstruit.
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const PAGES = {
  'dex-tasks': { file: 'pokedex_tasks', plugin: 'advanced_pokedex', klass: 'PokedexTasksConfig' },
  'champs-baies': { file: 'champs_baies', plugin: 'berrydex', klass: 'ChampsBaiesConfig' },
  'styles-pla': { file: 'styles_pla', plugin: 'gimmicks', klass: 'StylesPLAConfig' },
  'sac-de-frappe': { file: 'sac_de_frappe', plugin: 'sac_de_frappe', klass: 'SacDeFrappeConfig' },
  'poke-recre': { file: 'poke_recre', plugin: 'poke_recre', klass: 'PokeRecreConfig' },
  'raids': { file: 'raids', plugin: 'raids', klass: 'RaidsConfig' },
  'raids-cartes': { file: 'raids_cartes', plugin: 'raids', klass: 'RaidMapsConfig' },
  'tournois': { file: 'tournois', plugin: 'tournoi', klass: 'TournoisConfig' },
  'pokeblocs': { file: 'pokeblocs', plugin: 'pokeblocs', klass: 'PokeblocsConfig' },
  'concours': { file: 'concours', plugin: 'concours', klass: 'ConcoursConfig' },
  'obscurs': { file: 'obscurs', plugin: 'obscurs', klass: 'ObscursConfig' },
  'montures': { file: 'montures', plugin: 'montures', klass: 'MonturesConfig' },
  'pokeathlon': { file: 'pokeathlon', plugin: 'pokeathlon', klass: 'PokeathlonConfig' },
  'dodrio': { file: 'dodrio', plugin: 'dodrio', klass: 'DodrioConfig' },
  'lance_ball': { file: 'lance_ball', plugin: 'lance_ball', klass: 'LanceBallConfig' },
};
const PLUGINS_INSTALLED = 'scripts/00000 Plugins';
const join = (projectPath, rel) => path.join(projectPath, ...rel.split('/'));
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const norm = (b) => b.toString('utf8').replace(/^﻿/, '').replace(/\r\n/g, '\n');

function pageOf(id) {
  const page = PAGES[id];
  if (!page) throw new Error('Page inconnue : ' + id);
  return page;
}
function checkProject(projectPath) {
  if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
}

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

// Textes du projet (colonne française), gardés tant que le fichier ne change pas
const csvCache = new Map();
function texts(projectPath, id) {
  const file = join(projectPath, `Data/Text/Dialogs/${id}.csv`);
  if (!exists(file)) return () => '';
  const mtime = fs.statSync(file).mtimeMs;
  const cached = csvCache.get(file);
  if (cached && cached.mtime === mtime) return cached.get;
  const rows = parseCsv(fs.readFileSync(file, 'utf8').replace(/^﻿/, ''));
  const col = Math.max(0, rows[0].indexOf('fr') >= 0 ? rows[0].indexOf('fr') : rows[0].indexOf('en'));
  const get = (i) => (rows[i + 1] && rows[i + 1][col]) || '';
  csvCache.set(file, { mtime, get });
  return get;
}

// Fichiers JSON d'un dossier de Studio (gardés tant que le dossier ne change pas)
const dirCache = new Map();
async function readDir(projectPath, rel) {
  const dir = join(projectPath, rel);
  if (!exists(dir)) return [];
  const files = (await fsp.readdir(dir)).filter((n) => n.endsWith('.json'));
  const stamp = files.length + ':' + (await fsp.stat(dir)).mtimeMs;
  const cached = dirCache.get(dir);
  if (cached && cached.stamp === stamp) return cached.list;
  const list = [];
  for (const f of files) {
    try { list.push(JSON.parse((await fsp.readFile(path.join(dir, f), 'utf8')).replace(/^﻿/, ''))); } catch (e) { /* ignoré */ }
  }
  dirCache.set(dir, { stamp, list });
  return list;
}
const valid = (d) => d && d.dbSymbol && d.dbSymbol !== '__undef__';

// Images d'un dossier (sans extension), éventuellement filtrées
async function images(projectPath, rel, filter) {
  const dir = join(projectPath, rel);
  if (!exists(dir)) return [];
  return (await fsp.readdir(dir)).filter((n) => /\.png$/i.test(n) && (!filter || filter.test(n))).map((n) => n.replace(/\.png$/i, '')).sort();
}

async function sounds(projectPath, rel) {
  const dir = join(projectPath, rel);
  if (!exists(dir)) return [];
  return (await fsp.readdir(dir)).filter((n) => /\.(ogg|mp3|wav)$/i.test(n)).map((n) => rel + '/' + n.replace(/\.[^.]+$/, '')).sort();
}

// ---------------------------------------------------------------------------
// Listes de Studio dont les pages ont besoin
// ---------------------------------------------------------------------------
async function types(projectPath) {
  const name = texts(projectPath, 100003);
  return (await readDir(projectPath, 'Data/Studio/types')).filter(valid)
    .map((d) => ({ id: d.id, db: d.dbSymbol, name: name(d.textId) || d.dbSymbol, color: d.color || '#888',
      damage: Object.fromEntries((d.damageTo || []).map((x) => [x.defensiveType, x.factor])) }))
    .sort((a, b) => a.id - b.id);
}

async function moves(projectPath) {
  const name = texts(projectPath, 100006);
  return (await readDir(projectPath, 'Data/Studio/moves')).filter(valid)
    .map((d) => ({ id: d.id, db: d.dbSymbol, name: name(d.id) || d.dbSymbol, type: d.type, power: d.power || 0, category: d.category }))
    .sort((a, b) => a.id - b.id);
}

async function items(projectPath) {
  const name = texts(projectPath, 100012);
  return (await readDir(projectPath, 'Data/Studio/items')).filter(valid)
    .map((d) => ({ id: d.id, db: d.dbSymbol, name: name(d.id) || d.dbSymbol, icon: d.icon || '', berry: !!d.isBerry,
      color: (d.cookingData && d.cookingData.pokeblockColor) || '',
      growth: d.berryData ? d.berryData.growth : 0, drain: d.berryData ? d.berryData.drainRate : 0,
      min: d.berryData ? d.berryData.minYield : 0, max: d.berryData ? d.berryData.maxYield : 0 }))
    .sort((a, b) => a.id - b.id);
}

async function creatures(projectPath) {
  const name = texts(projectPath, 100000);
  return (await readDir(projectPath, 'Data/Studio/pokemon')).filter(valid).map((d) => {
    const f = (d.forms || []).find((x) => (x.form | 0) === 0) || (d.forms || [])[0] || {};
    return {
      id: d.id, db: d.dbSymbol, name: name(d.id) || d.dbSymbol, icon: (f.resources || {}).icon || '',
      forms: (d.forms || []).map((x) => x.form | 0),
      stats: [f.baseHp, f.baseAtk, f.baseDfe, f.baseSpd, f.baseAts, f.baseDfs].map((v) => v | 0),
      types: [f.type1, f.type2].filter((t) => t && t !== '__undef__'),
      // évolutions (hors méga-gemme), capacités apprises par niveau : pour l'aperçu des tâches automatiques
      evolves: (f.evolutions || []).some((e) => !(e.conditions || []).some((c) => c.type === 'gemme')),
      levelMoves: (f.moveSet || []).filter((m) => m.klass === 'LevelLearnableMove').map((m) => [m.move, m.level | 0]),
    };
  }).sort((a, b) => a.id - b.id);
}

async function maps(projectPath) {
  const file = join(projectPath, 'Data/Text/Studio/200002.csv');
  let name = () => '';
  if (exists(file)) {
    const rows = parseCsv(fs.readFileSync(file, 'utf8').replace(/^﻿/, ''));
    const col = Math.max(0, rows[0].indexOf('fr') >= 0 ? rows[0].indexOf('fr') : rows[0].indexOf('en'));
    name = (i) => (rows[i + 1] && rows[i + 1][col]) || '';
  }
  return (await readDir(projectPath, 'Data/Studio/maps')).filter(valid)
    .map((d) => ({ id: d.id, db: d.dbSymbol, name: name(d.id) || d.dbSymbol }))
    .sort((a, b) => a.id - b.id);
}

// héros (plugin personnages) et leurs sprites sur les montures : { monture => fichier }
async function heroRides(projectPath) {
  const file = join(projectPath, 'Data/configs/plugins/personnages.json');
  if (!exists(file)) return [];
  let heroes;
  try { heroes = JSON.parse(norm(await fsp.readFile(file))).heroes; } catch (e) { return []; }
  if (!Array.isArray(heroes)) return [];
  const chars = await images(projectPath, 'graphics/characters');
  return heroes.filter((x) => x && x.id).map((x) => {
    const rides = {};
    const g = x.gender === 'f' ? 'f' : 'm';
    if (x.charset) {
      const prefix = `${x.charset}_${g}_ride_`;
      chars.forEach((c) => { if (c.startsWith(prefix)) rides[c.slice(prefix.length)] = c; });
    }
    Object.entries(x.sprites || {}).forEach(([k, v]) => { if (k.startsWith('ride_') && v) rides[k.slice(5)] = v; });
    return { id: x.id, name: x.name || '', generator: !!x.generator, rides };
  });
}

async function trainers(projectPath) {
  const name = texts(projectPath, 100062);
  const klass = texts(projectPath, 100029);
  return (await readDir(projectPath, 'Data/Studio/trainers')).filter(valid).map((d) => {
    const levels = (d.party || []).map((p) => { const l = p.levelSetup || {}; return l.kind === 'fixed' ? (l.level | 0) : ((l.level && l.level.minimumLevel) | 0); });
    return { id: d.id, db: d.dbSymbol, name: name(d.id) || d.dbSymbol, klass: klass(d.id) || '', size: (d.party || []).length,
      levels, species: (d.party || []).map((p) => p.specie), vs: d.vsType | 0 };
  }).sort((a, b) => a.id - b.id);
}

// Ce dont chaque page a besoin
const NEEDS = {
  'dex-tasks': ['creatures', 'moves', 'types', 'items'],
  'champs-baies': ['creatures', 'items'],
  'styles-pla': ['moves', 'types'],
  'sac-de-frappe': ['ses'],
  'poke-recre': ['items', 'maps'],
  'raids': ['creatures', 'items', 'types', 'bgms', 'battlebacks', 'charsets'],
  'raids-cartes': ['mapImages', 'tileImages'],
  'tournois': ['trainers', 'creatures', 'items', 'bgms', 'battlebacks'],
  'pokeblocs': ['items', 'bgms'],
  'concours': ['creatures', 'items', 'bgms', 'npcCharsets', 'moves'],
  'obscurs': ['trainers', 'creatures', 'items', 'moves', 'mes'],
  'montures': ['creatures', 'items', 'bgms', 'heroRides'],
  'pokeathlon': ['creatures', 'items', 'bgms', 'mes'],
  'dodrio': ['creatures', 'items', 'bgms'],
  'lance_ball': ['creatures', 'items', 'bgms'],
};
const LISTS = {
  creatures, moves, types, items, maps, trainers, heroRides,
  ses: (projectPath) => sounds(projectPath, 'audio/se'),
  bgms: (projectPath) => sounds(projectPath, 'audio/bgm'),
  mes: (projectPath) => sounds(projectPath, 'audio/me'),
  battlebacks: (projectPath) => images(projectPath, 'graphics/battlebacks', /^back_/i),
  charsets: (projectPath) => images(projectPath, 'graphics/characters', /raid|den|antre/i),
  npcCharsets: (projectPath) => images(projectPath, 'graphics/characters', /^[a-z]/i),
  mapImages: (projectPath) => images(projectPath, 'graphics/interface/raids/adventure/maps'),
  tileImages: (projectPath) => images(projectPath, 'graphics/interface/raids/adventure/tiles'),
};

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

function installedPluginDir(projectPath, plugin) {
  const base = join(projectPath, PLUGINS_INSTALLED);
  if (!exists(base)) return null;
  const name = fs.readdirSync(base).find((n) => new RegExp(`^\\d+ ${plugin}$`).test(n));
  return name ? path.join(base, name) : null;
}

async function pluginStatus(projectPath, plugin) {
  const source = join(projectPath, `scripts/${plugin}/scripts`);
  if (!exists(source)) return { name: plugin, source: false, installed: null, outdated: [], stale: [] };
  const dir = installedPluginDir(projectPath, plugin);
  const files = await listFilesDeep(source, '.rb');
  if (!dir) return { name: plugin, source: true, installed: null, outdated: files, stale: [] };
  const outdated = [];
  for (const rel of files) {
    const dest = path.join(dir, ...rel.split('/'));
    if (!exists(dest) || norm(await fsp.readFile(dest)) !== norm(await fsp.readFile(path.join(source, ...rel.split('/'))))) outdated.push(rel);
  }
  const stale = (await listFilesDeep(dir, '.rb')).filter((rel) => !files.includes(rel));
  return { name: plugin, source: true, installed: path.relative(projectPath, dir).split(path.sep).join('/'), outdated, stale };
}

async function syncInstalledPlugin(projectPath, plugin) {
  const st = await pluginStatus(projectPath, plugin);
  if (!st.source || !st.installed) return st;
  const source = join(projectPath, `scripts/${plugin}/scripts`);
  const dir = join(projectPath, st.installed);
  for (const rel of st.outdated) {
    const dest = path.join(dir, ...rel.split('/'));
    await fsp.mkdir(path.dirname(dest), { recursive: true });
    await fsp.copyFile(path.join(source, ...rel.split('/')), dest);
  }
  for (const rel of st.stale) await fsp.unlink(path.join(dir, ...rel.split('/')));
  return { ...st, outdated: [], stale: [] };
}

const building = new Map();
function buildPluginPackage(projectPath, plugin) {
  const key = projectPath + '|' + plugin;
  if (building.has(key)) return building.get(key);
  const job = new Promise((resolve) => {
    if (process.platform !== 'win32' || !exists(join(projectPath, 'psdk.bat'))) { resolve({ built: false, error: 'psdk.bat introuvable' }); return; }
    const { spawn } = require('child_process');
    let output = '';
    let done = false;
    const child = spawn('cmd.exe', ['/d', '/c', 'psdk.bat', '--util=plugin', 'build', plugin], { cwd: projectPath, windowsHide: true });
    const finish = (r) => { if (!done) { done = true; clearTimeout(timer); resolve(r); } };
    const timer = setTimeout(() => { try { child.kill(); } catch (e) { /* rien */ } finish({ built: false, error: 'trop long (plus de 3 minutes)' }); }, 180000);
    child.stdout.on('data', (d) => { output += d; });
    child.stderr.on('data', (d) => { output += d; });
    child.on('error', (e) => finish({ built: false, error: e.message }));
    child.on('close', (code) => {
      const ok = code === 0 && /Done!/.test(output);
      finish(ok ? { built: true } : { built: false, error: (output.trim().split(/\r?\n/).pop() || `code ${code}`).slice(0, 200) });
    });
  }).finally(() => building.delete(key));
  building.set(key, job);
  return job;
}

// ---------------------------------------------------------------------------
// Canaux
// ---------------------------------------------------------------------------
const handlers = {
  async getContext({ projectPath, page: id }) {
    checkProject(projectPath);
    const page = pageOf(id);
    const file = join(projectPath, `Data/configs/plugins/${page.file}.json`);
    let config = null;
    if (exists(file)) {
      try { config = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, '')); } catch (e) { throw new Error(`${page.file}.json illisible : ${e.message}`); }
    }
    const out = { config, file: `Data/configs/plugins/${page.file}.json`, plugin: await pluginStatus(projectPath, page.plugin) };
    for (const need of NEEDS[id] || []) out[need] = await LISTS[need](projectPath);
    return out;
  },

  async save({ projectPath, page: id, config }) {
    checkProject(projectPath);
    const page = pageOf(id);
    if (!config || typeof config !== 'object' || Array.isArray(config)) throw new Error('réglages invalides');
    config = Object.assign({ klass: page.klass }, config, { klass: page.klass });
    await writeAtomic(join(projectPath, `Data/configs/plugins/${page.file}.json`), JSON.stringify(config, null, 2) + '\n');
    // réglages compilés par PSDK : refaits au prochain lancement
    for (const rx of [`Data/configs/plugins_${page.file}.rxdata`, `Data/configs/plugins/${page.file}.rxdata`]) {
      const full = join(projectPath, rx);
      if (exists(full)) { try { await fsp.unlink(full); } catch (e) { /* rien */ } }
    }
    const sync = await syncInstalledPlugin(projectPath, page.plugin);
    return { plugin: { name: page.plugin, source: sync.source, installed: sync.installed } };
  },

  async buildPlugin({ projectPath, page: id }) {
    const page = pageOf(id);
    if (!projectPath || !exists(join(projectPath, `scripts/${page.plugin}/config.yml`))) return { built: false, error: 'plugin introuvable' };
    return buildPluginPackage(projectPath, page.plugin);
  },

  // Images du projet (graphics/..., sans extension ou en .png) en data: URL
  async readImages({ projectPath, files }) {
    const out = {};
    for (const file of files || []) {
      const rel = String(file || '').replace(/\\/g, '/');
      if (!/^graphics\//.test(rel) || rel.split('/').includes('..')) { out[file] = null; continue; }
      let full = join(projectPath, rel.endsWith('.png') ? rel : rel + '.png');
      if (!exists(full)) {
        const dir = path.dirname(full);
        const want = path.basename(full).toLowerCase();
        const found = exists(dir) ? (await fsp.readdir(dir)).find((n) => n.toLowerCase() === want) : null;
        full = found ? path.join(dir, found) : null;
      }
      out[file] = full ? 'data:image/png;base64,' + (await fsp.readFile(full)).toString('base64') : null;
    }
    return out;
  },

  async readSound({ projectPath, file }) {
    const rel = String(file || '').replace(/\\/g, '/');
    if (!/^audio\//.test(rel) || rel.split('/').includes('..')) throw new Error('Son refusé');
    for (const ext of ['.ogg', '.mp3', '.wav']) {
      const full = join(projectPath, rel + ext);
      if (exists(full)) return `data:audio/${ext === '.mp3' ? 'mpeg' : ext.slice(1)};base64,` + (await fsp.readFile(full)).toString('base64');
    }
    return null;
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-reglages:' + name;
    try { ipcMain.removeHandler(channel); } catch (e) { /* rien */ }
    ipcMain.handle(channel, async (_event, payload) => {
      try { return { ok: true, value: await fn(payload || {}) }; } catch (e) { return { ok: false, error: String((e && e.message) || e) }; }
    });
  });
}

module.exports = { register, handlers, PAGES };

try {
  const electron = require('electron');
  if (electron && electron.ipcMain) register(electron.ipcMain);
} catch (e) { /* hors Electron (tests) */ }

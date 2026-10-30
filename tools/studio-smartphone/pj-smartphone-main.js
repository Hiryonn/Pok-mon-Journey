/* eslint-disable */
// =============================================================================
// Smartphone (plugin PokeSmart) — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-smartphone:* ».
// Lit / écrit :
//   Data/configs/plugins/pokesmart_config.json  (ordre, applis cachées, valeurs par défaut, coques)
//   Data/Text/Dialogs/<text_file_id>.csv         (noms des applis, une colonne par langue)
// et liste les images de graphics/interface/pokesmart/.
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const CONFIG_FILE = 'Data/configs/plugins/pokesmart_config.json';
const GRAPHICS_DIR = 'graphics/interface/pokesmart';
const DEFAULT_TEXT_FILE = 9100;
const FRIENDS_FILE = 'Data/configs/plugins/pokesmart_friends.json';
const DEFAULT_FRIENDS_TEXT_FILE = 9101;

const join = (projectPath, rel) => path.join(projectPath, ...rel.split('/'));
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };

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

const csvCell = (v) => { const s = v == null ? '' : String(v); return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
const toCsv = (rows) => rows.map((r) => r.map(csvCell).join(',')).join('\n') + '\n';

function readCsv(file) {
  if (!exists(file)) return null;
  return parseCsv(fs.readFileSync(file, 'utf8').replace(/^﻿/, ''));
}

async function backupOnce(file) {
  if (exists(file) && !exists(file + '.bak')) await fsp.copyFile(file, file + '.bak');
}

async function writeAtomic(file, content) {
  await fsp.mkdir(path.dirname(file), { recursive: true });
  await backupOnce(file);
  const tmp = file + '.tmp';
  await fsp.writeFile(tmp, content, 'utf8');
  await fsp.rename(tmp, file);
}

async function listPngDeep(dir) {
  if (!exists(dir)) return [];
  const out = [];
  const walk = async (d, prefix) => {
    for (const ent of await fsp.readdir(d, { withFileTypes: true })) {
      if (ent.isDirectory()) await walk(path.join(d, ent.name), prefix + ent.name + '/');
      else if (ent.name.toLowerCase().endsWith('.png')) out.push(prefix + ent.name.slice(0, -4));
    }
  };
  await walk(dir, '');
  return out.sort((a, b) => a.localeCompare(b));
}

// Liste de données Studio (id, dbSymbol, nom lu dans le fichier de textes donné)
async function studioList(projectPath, folder, textFile) {
  const dir = join(projectPath, `Data/Studio/${folder}`);
  if (!exists(dir)) return [];
  const texts = readCsv(join(projectPath, `Data/Text/Dialogs/${textFile}.csv`));
  const col = texts ? Math.max(0, texts[0].indexOf('fr') >= 0 ? texts[0].indexOf('fr') : texts[0].indexOf('en')) : 0;
  const out = [];
  for (const f of (await fsp.readdir(dir)).filter((n) => n.endsWith('.json'))) {
    try {
      const d = JSON.parse(await fsp.readFile(path.join(dir, f), 'utf8'));
      const row = texts && texts[d.id + 1];
      out.push({ id: d.id, dbSymbol: d.dbSymbol, name: (row && row[col]) || '' });
    } catch (e) { /* ignoré */ }
  }
  return out.sort((a, b) => a.id - b.id);
}

async function listPng(dir) {
  if (!exists(dir)) return [];
  return (await fsp.readdir(dir)).filter((f) => f.toLowerCase().endsWith('.png')).map((f) => f.slice(0, -4)).sort((a, b) => a.localeCompare(b));
}

const handlers = {
  // Tout ce qu'il faut à l'éditeur : réglages, noms des applis, images disponibles
  async getContext({ projectPath }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    const configFile = join(projectPath, CONFIG_FILE);
    let config = null;
    if (exists(configFile)) {
      try { config = JSON.parse(fs.readFileSync(configFile, 'utf8')); } catch (e) { throw new Error('pokesmart_config.json illisible : ' + e.message); }
    }
    const textFileId = (config && config.text_file_id) || DEFAULT_TEXT_FILE;
    const gfx = join(projectPath, GRAPHICS_DIR);
    const icons = (await listPng(gfx)).filter((n) => n.startsWith('icon_'));
    const wallpapers = await listPng(path.join(gfx, 'wallpapers'));
    const caseDirs = [];
    const caseFiles = { '': await listPng(gfx) };
    if (exists(gfx)) {
      for (const ent of await fsp.readdir(gfx, { withFileTypes: true })) {
        if (!ent.isDirectory() || ent.name === 'wallpapers') continue;
        caseDirs.push(ent.name);
        caseFiles[ent.name + '/'] = await listPng(path.join(gfx, ent.name));
      }
    }
    let friends = null;
    const friendsFile = join(projectPath, FRIENDS_FILE);
    if (exists(friendsFile)) {
      try { friends = JSON.parse(fs.readFileSync(friendsFile, 'utf8')); } catch (e) { throw new Error('pokesmart_friends.json illisible : ' + e.message); }
    }
    const friendsTextFile = (friends && friends.text_file_id) || DEFAULT_FRIENDS_TEXT_FILE;
    const charDir = exists(join(projectPath, 'graphics/characters')) ? 'graphics/characters' : 'Graphics/Characters';
    return {
      friends,
      friendsCsv: readCsv(join(projectPath, `Data/Text/Dialogs/${friendsTextFile}.csv`)),
      charDir,
      characters: await listPngDeep(join(projectPath, charDir)),
      trainers: await studioList(projectPath, 'trainers', 100062),
      quests: await studioList(projectPath, 'quests', 100045),
      config,
      configExists: !!config,
      textFileId,
      csv: readCsv(join(projectPath, `Data/Text/Dialogs/${textFileId}.csv`)),
      psdkMenuTexts: readCsv(join(projectPath, 'Data/Text/Dialogs/100014.csv')),
      icons,
      wallpapers,
      caseDirs,
      caseFiles,
      hasPlugin: exists(join(projectPath, 'scripts/pokesmart')) || exists(join(projectPath, 'scripts/pokesmart.psdkplug')),
    };
  },

  // Ajoute une image de personnage glissée dans Studio : déjà dans graphics/characters → son nom,
  // sinon copie dans graphics/characters (sans écraser un fichier existant)
  async importCharacter({ projectPath, sourcePath }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    if (!sourcePath || !/\.png$/i.test(sourcePath) || !exists(sourcePath)) throw new Error('Il faut une image PNG');
    const charDir = exists(join(projectPath, 'graphics/characters')) ? 'graphics/characters' : 'Graphics/Characters';
    const base = path.resolve(join(projectPath, charDir));
    const src = path.resolve(sourcePath);
    const rel = path.relative(base, src);
    if (rel && !rel.startsWith('..') && !path.isAbsolute(rel)) {
      return { name: rel.split(path.sep).join('/').replace(/\.png$/i, ''), copied: false };
    }
    const stem = path.basename(src).replace(/\.png$/i, '');
    const data = await fsp.readFile(src);
    let name = stem;
    let n = 2;
    while (exists(path.join(base, name + '.png'))) {
      // même image déjà importée : on la réutilise
      if ((await fsp.readFile(path.join(base, name + '.png'))).equals(data)) return { name, copied: false };
      name = `${stem}_${n++}`;
    }
    await fsp.mkdir(base, { recursive: true });
    await fsp.writeFile(path.join(base, name + '.png'), data);
    return { name, copied: true };
  },

  // Enregistre les réglages (JSON) et les noms des applis (CSV)
  async save({ projectPath, config, csv, friends, friendsCsv }) {
    if (!projectPath || !exists(join(projectPath, 'Data'))) throw new Error('Projet introuvable : ' + projectPath);
    const textFileId = (config && config.text_file_id) || DEFAULT_TEXT_FILE;
    await writeAtomic(join(projectPath, CONFIG_FILE), JSON.stringify(config, null, 2) + '\n');
    if (csv && csv.length) await writeAtomic(join(projectPath, `Data/Text/Dialogs/${textFileId}.csv`), toCsv(csv));
    if (friends) {
      const friendsTextFile = friends.text_file_id || DEFAULT_FRIENDS_TEXT_FILE;
      await writeAtomic(join(projectPath, FRIENDS_FILE), JSON.stringify(friends, null, 2) + '\n');
      if (friendsCsv && friendsCsv.length) await writeAtomic(join(projectPath, `Data/Text/Dialogs/${friendsTextFile}.csv`), toCsv(friendsCsv));
    }
    return { configFile: CONFIG_FILE, csvFile: `Data/Text/Dialogs/${textFileId}.csv` };
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-smartphone:' + name;
    try { ipcMain.removeHandler(channel); } catch (e) { /* rien */ }
    ipcMain.handle(channel, async (_event, payload) => {
      try { return { ok: true, value: await fn(payload || {}) }; } catch (e) { return { ok: false, error: String((e && e.message) || e) }; }
    });
  });
}

module.exports = { register, handlers, parseCsv, toCsv };

try {
  const electron = require('electron');
  if (electron && electron.ipcMain) register(electron.ipcMain);
} catch (e) { /* hors Electron (tests) */ }

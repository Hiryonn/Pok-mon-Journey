/* eslint-disable */
// =============================================================================
// Personnages (Données > Personnages : Héros, Alliés) — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Fournit les canaux IPC « pj-personnages:* ».
// Réglages : Data/configs/plugins/personnages.json (lu en jeu par le plugin scripts/personnages)
// =============================================================================
'use strict';
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');

const CONFIG_FILE = 'Data/configs/plugins/personnages.json';
const join = (projectPath, rel) => path.join(projectPath, ...rel.split('/'));
const exists = (p) => { try { return fs.existsSync(p); } catch (e) { return false; } };
const DEFAULT_CONFIG = () => ({ klass: 'PersonnagesConfig', heroes: [], default_hero: null, ask_name: true, name_max_length: 12, allies: [] });

// CSV de textes de Studio (guillemets compris)
function parseCsv(text) {
  const rows = []; let row = []; let cell = ''; let q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) {
      if (c === '"') { if (text[i + 1] === '"') { cell += '"'; i++; } else q = false; } else cell += c;
    } else if (c === '"') q = true;
    else if (c === ',') { row.push(cell); cell = ''; } else if (c === '\n') { row.push(cell.replace(/\r$/, '')); rows.push(row); row = []; cell = ''; } else cell += c;
  }
  if (cell || row.length) { row.push(cell.replace(/\r$/, '')); rows.push(row); }
  return rows;
}
async function readTexts(projectPath, fileId) {
  const file = join(projectPath, `Data/Text/Dialogs/${fileId}.csv`);
  if (!exists(file)) return [];
  const rows = parseCsv((await fsp.readFile(file, 'utf8')).replace(/^﻿/, ''));
  const head = rows.shift() || [];
  let col = head.indexOf('fr');
  if (col < 0) col = Math.max(0, head.indexOf('en'));
  return rows.map((r) => r[col] || r[0] || '');
}
// images d'un dossier de graphics (sous-dossiers compris), sans « .png »
async function listPngs(dir, rel = '') {
  let out = [];
  let list;
  try { list = await fsp.readdir(path.join(dir, rel), { withFileTypes: true }); } catch (e) { return out; }
  for (const d of list) {
    const r = rel ? rel + '/' + d.name : d.name;
    if (d.isDirectory()) out = out.concat(await listPngs(dir, r));
    else if (/\.png$/i.test(d.name)) out.push(r.replace(/\.png$/i, ''));
  }
  return out;
}
const sortFr = (a, b) => a.localeCompare(b, 'fr', { numeric: true, sensitivity: 'base' });

const handlers = {
  async getContext({ projectPath }) {
    if (!projectPath) return { projectPath: null };
    const file = join(projectPath, CONFIG_FILE);
    let config = DEFAULT_CONFIG();
    if (exists(file)) { try { config = { ...config, ...JSON.parse((await fsp.readFile(file, 'utf8')).replace(/^﻿/, '')) }; } catch (e) { config.__error = 'Réglages illisibles : ' + e.message; } }
    // personnages de la carte
    const characters = (await listPngs(join(projectPath, 'graphics/characters'))).sort(sortFr);
    // bases du joueur : <base>_m_walk / <base>_f_walk
    const bases = {};
    for (const c of characters) { const m = /^(.+)_(m|f)_walk$/i.exec(c); if (m) (bases[m[1]] = bases[m[1]] || { base: m[1], m: false, f: false })[m[2].toLowerCase()] = true; }
    const battlers = (await listPngs(join(projectPath, 'graphics/battlers'))).sort(sortFr);
    // dresseurs de Studio
    const trainerNames = await readTexts(projectPath, 100062);
    const trainerClasses = await readTexts(projectPath, 100029);
    const pokemonNames = await readTexts(projectPath, 100000);
    const speciesId = {};
    const pokeDir = join(projectPath, 'Data/Studio/pokemon');
    const trainers = [];
    const trainerDir = join(projectPath, 'Data/Studio/trainers');
    if (exists(trainerDir)) {
      for (const f of await fsp.readdir(trainerDir)) {
        if (!/\.json$/i.test(f)) continue;
        try {
          const t = JSON.parse(await fsp.readFile(path.join(trainerDir, f), 'utf8'));
          const party = [];
          for (const p of t.party || []) {
            if (!(p.specie in speciesId)) { try { speciesId[p.specie] = JSON.parse(await fsp.readFile(path.join(pokeDir, p.specie + '.json'), 'utf8')).id; } catch (e) { speciesId[p.specie] = null; } }
            const id = speciesId[p.specie];
            party.push({ specie: p.specie, name: (id !== null && pokemonNames[id]) || p.specie, level: p.levelSetup && (p.levelSetup.level || (p.levelSetup.levelRange && p.levelSetup.levelRange[0])) || null });
          }
          trainers.push({ id: t.id, dbSymbol: t.dbSymbol, name: trainerNames[t.id] || t.dbSymbol, className: trainerClasses[t.id] || '', sprite: (t.resources && t.resources.sprite) || '', character: (t.resources && t.resources.character) || '', artwork: (t.resources && t.resources.artworkSmall) || '', party });
        } catch (e) { /* dresseur illisible */ }
      }
    }
    trainers.sort((a, b) => a.id - b.id);
    return {
      projectPath, config, characters, bases: Object.values(bases).sort((a, b) => sortFr(a.base, b.base)), battlers, trainers,
      generator: exists(join(projectPath, 'Data/configs/plugins/generateur_pieces.json')),
      pluginReady: exists(join(projectPath, 'scripts/personnages/config.yml')),
    };
  },
  // image de graphics (aperçus)
  async readImage({ projectPath, file }) {
    const rel = String(file || '').replace(/\\/g, '/');
    if (!/^graphics\//.test(rel) || rel.split('/').includes('..')) throw new Error('Seules les images de graphics sont lues.');
    const full = join(projectPath, rel.endsWith('.png') ? rel : rel + '.png');
    if (!exists(full)) return null;
    return 'data:image/png;base64,' + (await fsp.readFile(full)).toString('base64');
  },
  async save({ projectPath, config }) {
    if (!projectPath) throw new Error('Aucun projet ouvert.');
    const file = join(projectPath, CONFIG_FILE);
    await fsp.mkdir(path.dirname(file), { recursive: true });
    const clean = { ...DEFAULT_CONFIG(), ...config, klass: 'PersonnagesConfig' };
    delete clean.__error;
    await fsp.writeFile(file, JSON.stringify(clean, null, 2) + '\n', 'utf8');
    return true;
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-personnages:' + name;
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

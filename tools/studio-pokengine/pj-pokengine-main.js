/* eslint-disable */
// Importer de Pokéngine — processus principal de Pokémon Studio.
// Choisit les fiches (PDF) et images (webp), les copie dans un dossier de travail, lance tools/pokengine/importer_pokengine.py.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const handlers = {
  async choisir() {
    const { dialog, BrowserWindow } = require('electron');
    const win = BrowserWindow.getFocusedWindow() || undefined;
    const r = await dialog.showOpenDialog(win, {
      title: 'Fiches PDF et images Pokéngine',
      properties: ['openFile', 'multiSelections'],
      filters: [{ name: 'Fiches et images Pokéngine', extensions: ['pdf', 'txt', 'webp', 'png'] }],
    });
    return r.canceled ? [] : r.filePaths;
  },

  async importer({ projectPath, files, mode }) {
    if (!projectPath) throw new Error('Aucun projet ouvert.');
    const script = path.join(projectPath, 'tools', 'pokengine', 'importer_pokengine.py');
    if (!fs.existsSync(script)) throw new Error("tools/pokengine/importer_pokengine.py est introuvable dans le projet.");
    const dossierSource = path.join(projectPath, 'tools', 'pokengine', 'telechargements');
    fs.mkdirSync(dossierSource, { recursive: true });
    for (const f of files || []) {
      const dest = path.join(dossierSource, path.basename(f));
      if (path.resolve(f) !== path.resolve(dest)) fs.copyFileSync(f, dest);
    }
    const args = [script, dossierSource, projectPath];
    if (mode === 'essai') args.push('--dry-run');
    if (mode === 'images') args.push('--images-seulement');
    if (mode === 'refaire') args.push('--force');
    const candidats = process.platform === 'win32' ? [['py', ['-3']], ['python', []]] : [['python3', []], ['python', []]];
    let derniereErreur = null;
    for (const [cmd, pre] of candidats) {
      try {
        return await new Promise((resolve, reject) => {
          const p = spawn(cmd, [...pre, '-X', 'utf8', ...args], { cwd: projectPath, windowsHide: true, env: { ...process.env, PYTHONIOENCODING: 'utf-8' } });
          let out = '';
          const timer = setTimeout(() => { p.kill(); reject(new Error('Délai dépassé (5 min).')); }, 300000);
          p.stdout.on('data', (d) => { out += d; });
          p.stderr.on('data', (d) => { out += d; });
          p.on('error', (e) => { clearTimeout(timer); reject(e); });
          p.on('close', (code) => { clearTimeout(timer); resolve({ code, sortie: out }); });
        });
      } catch (e) { derniereErreur = e; if (e && e.code !== 'ENOENT') throw e; }
    }
    throw new Error("Python 3 est introuvable (installe-le avec « Add python to PATH », puis Pillow et pypdf : pip install pillow pypdf). " + (derniereErreur ? derniereErreur.message : ''));
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([n, fn]) => {
    const channel = 'pj-pokengine:' + n;
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

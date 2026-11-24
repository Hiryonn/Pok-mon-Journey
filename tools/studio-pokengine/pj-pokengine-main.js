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

  // slots : { pdf, icon, front, back, follower } = { name, data } (octets lus par la page)
  async importer({ projectPath, slots, mode }) {
    if (!projectPath) throw new Error('Aucun projet ouvert.');
    slots = slots || {};
    for (const k of ['pdf', 'icon', 'front', 'back']) if (!slots[k] || !slots[k].data) throw new Error('Il manque : ' + k);
    const dossierPj = path.join(projectPath, 'tools', 'pokengine');
    const script = path.join(dossierPj, 'importer_pokengine.py');
    if (!fs.existsSync(script)) throw new Error('tools/pokengine/importer_pokengine.py est introuvable dans le projet.');
    const tmp = path.join(dossierPj, 'telechargements_studio');
    fs.mkdirSync(tmp, { recursive: true });
    const pdfTmp = path.join(tmp, '_fiche_' + Date.now() + path.extname(slots.pdf.name || '.pdf'));
    fs.writeFileSync(pdfTmp, Buffer.from(slots.pdf.data));
    let code;
    try {
      const r = await lancer(projectPath, [path.join(dossierPj, 'lire_code.py'), pdfTmp]);
      if (r.code !== 0) throw new Error((r.sortie || 'Fiche illisible.').trim());
      code = r.sortie.trim().split(/\s+/).pop();
    } finally { try { fs.unlinkSync(pdfTmp); } catch (e) { /* rien */ } }
    const dossier = path.join(tmp, code);
    fs.rmSync(dossier, { recursive: true, force: true });
    fs.mkdirSync(dossier, { recursive: true });
    fs.writeFileSync(path.join(dossier, 'fiche' + path.extname(slots.pdf.name || '.pdf')), Buffer.from(slots.pdf.data));
    const suffixes = { icon: '', front: '_1', back: '_2', follower: '_3' };
    for (const [k, suf] of Object.entries(suffixes)) {
      if (!slots[k] || !slots[k].data) continue;
      const ext = (path.extname(slots[k].name || '') || '.webp').toLowerCase();
      fs.writeFileSync(path.join(dossier, code + suf + ext), Buffer.from(slots[k].data));
    }
    const args = [script, dossier, projectPath];
    if (mode === 'essai') args.push('--dry-run');
    if (mode === 'refaire') args.push('--force');
    return lancer(projectPath, args);
  },
};

function lancer(cwd, args) {
  const candidats = process.platform === 'win32' ? [['py', ['-3']], ['python', []]] : [['python3', []], ['python', []]];
  const essayer = async (i) => {
    const [cmd, pre] = candidats[i];
    try {
      return await new Promise((resolve, reject) => {
        const p = spawn(cmd, [...pre, '-X', 'utf8', ...args], { cwd, windowsHide: true, env: { ...process.env, PYTHONIOENCODING: 'utf-8' } });
        let out = '';
        const timer = setTimeout(() => { p.kill(); reject(new Error('Délai dépassé (5 min).')); }, 300000);
        p.stdout.on('data', (d) => { out += d; });
        p.stderr.on('data', (d) => { out += d; });
        p.on('error', (e) => { clearTimeout(timer); reject(e); });
        p.on('close', (code) => { clearTimeout(timer); resolve({ code, sortie: out }); });
      });
    } catch (e) {
      if (e && e.code === 'ENOENT' && i + 1 < candidats.length) return essayer(i + 1);
      if (e && e.code === 'ENOENT') throw new Error('Python 3 est introuvable (installe-le avec « Add python to PATH », puis : pip install pillow pypdf).');
      throw e;
    }
  };
  return essayer(0);
}

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

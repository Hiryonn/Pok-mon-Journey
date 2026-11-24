/* eslint-disable */
// =============================================================================
// Traduction automatique — partie « processus principal » (Electron main)
// Chargé depuis .vite/build/index.js. Canal IPC « pj-traduction:translate » : { text, from, to } -> texte traduit.
// Point d'accès public de Google Traduction (sans clé), codes de texte de PSDK protégés (\c[1], \n, [VAR 1], {..}, <..>).
// =============================================================================
'use strict';

const PROTECT = /(\\[A-Za-z]+(?:\[[^\]]*\])?|\\\\|\[[A-Z_]+(?: ?\d+)?\]|\{[^{}]*\}|<[^<>]*>)/g;

async function http(url) {
  const f = typeof fetch === 'function' ? fetch : require('electron').net.fetch;
  let lastError;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const r = await f(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return await r.json();
    } catch (e) { lastError = e; await new Promise((ok) => setTimeout(ok, 1500 * (attempt + 1))); }
  }
  throw lastError;
}

async function translateLine(line, from, to) {
  if (!line.trim()) return line;
  const saved = [];
  const guarded = line.replace(PROTECT, (m) => { saved.push(m); return '⟦' + (saved.length - 1) + '⟧'; });
  if (!/[A-Za-zÀ-ÿ]/.test(line.replace(PROTECT, ''))) return line;           // rien à traduire (nombres, codes seuls)
  const url = 'https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&sl=' + encodeURIComponent(from)
    + '&tl=' + encodeURIComponent(to) + '&q=' + encodeURIComponent(guarded);
  const data = await http(url);
  let out = data[0].map((p) => (p && p[0]) || '').join('');
  saved.forEach((code, i) => { out = out.replace(new RegExp('⟦\\s*' + i + '\\s*⟧'), () => code); });
  if (saved.some((code) => !out.includes(code))) throw new Error('un code de texte a été perdu dans la traduction');
  return out;
}

const handlers = {
  async translate({ text, from, to }) {
    if (!text || !to) throw new Error('texte ou langue manquants');
    const lines = String(text).split('\n');                    // une ligne à la fois : les retours à la ligne sont gardés
    const out = [];
    for (const line of lines) out.push(await translateLine(line, from || 'auto', to));
    return out.join('\n');
  },
};

function register(ipcMain) {
  Object.entries(handlers).forEach(([name, fn]) => {
    const channel = 'pj-traduction:' + name;
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

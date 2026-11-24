/* eslint-disable */
// Importer de Pokéngine — ajoute un bouton dans le panneau « Création / Nouveau Pokémon » de Pokémon Studio.
(() => {
  'use strict';
  if (window.__pjPokengineLoaded) return;
  window.__pjPokengineLoaded = true;
  const api = window.pjPokengine;
  const call = async (n, payload) => {
    if (!api || !api[n]) throw new Error("L'API n'est pas disponible : relance installer_pokengine.bat puis redémarre Studio.");
    const r = await api[n](payload);
    if (!r || !r.ok) throw new Error((r && r.error) || 'Erreur inconnue');
    return r.value;
  };
  const projectPath = () => { try { const l = JSON.parse(localStorage.getItem('projectList') || '[]'); return l[0] && l[0].projectPath; } catch (e) { return null; } };
  function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (k === 'class') el.className = v;
      else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
      else if (v !== false && v != null) el.setAttribute(k, v);
    }
    kids.flat().forEach((c) => c != null && el.appendChild(c instanceof Node ? c : document.createTextNode(String(c))));
    return el;
  }

  const SLOTS = [
    { key: 'icon', label: 'Icône', hint: 'code.webp', accept: 'image/*', required: true },
    { key: 'front', label: 'Front', hint: 'code_1.webp', accept: 'image/*', required: true },
    { key: 'back', label: 'Back', hint: 'code_2.webp', accept: 'image/*', required: true },
    { key: 'follower', label: 'Follower', hint: 'code_3.webp (facultatif)', accept: 'image/*', required: false },
    { key: 'pdf', label: 'Fiche PDF', hint: 'fiche de pokengine.org', accept: '.pdf,.txt,application/pdf,text/plain', required: true, doc: true },
  ];

  function ouvrir() {
    const files = {};
    const cards = {};
    const log = h('div', { class: 'pjpg-log', style: 'display:none' });
    const mode = h('select', { class: 'pjpg-select' },
      h('option', { value: 'normal' }, 'Importer'),
      h('option', { value: 'essai' }, "Essai (n'écrit rien)"),
      h('option', { value: 'refaire' }, 'Refaire (écrase)'));
    const go = h('button', { class: 'pjpg-primary', disabled: true }, 'Importer le Pokémon');
    const back = h('div', { class: 'pjpg-back' });
    const close = () => { Object.values(files).forEach((f) => f.url && URL.revokeObjectURL(f.url)); back.remove(); };
    const refresh = () => { go.disabled = !SLOTS.every((d) => !d.required || files[d.key]); };

    function setFile(def, file) {
      if (!file) return;
      if (files[def.key] && files[def.key].url) URL.revokeObjectURL(files[def.key].url);
      files[def.key] = { file, url: def.doc ? null : URL.createObjectURL(file) };
      const c = cards[def.key];
      c.zone.textContent = '';
      c.zone.classList.add('filled');
      if (def.doc) c.zone.appendChild(h('div', { class: 'pjpg-doc' }, 'PDF', h('span', null, file.name)));
      else c.zone.appendChild(h('img', { src: files[def.key].url }));
      c.name.textContent = file.name;
      refresh();
    }

    SLOTS.forEach((def) => {
      const input = h('input', { type: 'file', accept: def.accept, style: 'display:none' });
      input.onchange = () => setFile(def, input.files[0]);
      const zone = h('div', { class: 'pjpg-zone' }, h('div', { class: 'pjpg-plus' }, '+'), h('div', { class: 'pjpg-drop' }, 'Déposer ou cliquer'));
      const name = h('div', { class: 'pjpg-fname' }, def.hint);
      const card = h('div', { class: 'pjpg-card', onclick: () => input.click() }, input, zone,
        h('div', { class: 'pjpg-cardlabel' }, def.label + (def.required ? ' *' : '')), name);
      card.addEventListener('dragover', (e) => { e.preventDefault(); card.classList.add('over'); });
      card.addEventListener('dragleave', () => card.classList.remove('over'));
      card.addEventListener('drop', (e) => { e.preventDefault(); card.classList.remove('over'); setFile(def, e.dataTransfer.files[0]); });
      cards[def.key] = { zone, name, card };
    });

    go.onclick = async () => {
      go.disabled = true; log.style.display = 'block'; log.className = 'pjpg-log'; log.textContent = 'Import en cours…';
      try {
        const slots = {};
        for (const d of SLOTS) if (files[d.key]) slots[d.key] = { name: files[d.key].file.name, data: new Uint8Array(await files[d.key].file.arrayBuffer()) };
        const r = await call('importer', { projectPath: projectPath(), slots, mode: mode.value });
        log.textContent = r.sortie || '(aucune sortie)';
        if (r.code !== 0) log.className = 'pjpg-log err';
        else if (mode.value !== 'essai') log.textContent += '\n\nTerminé. Ferme puis rouvre le projet pour voir le Pokémon.';
      } catch (e) { log.className = 'pjpg-log err'; log.textContent = e.message; }
      refresh();
    };

    back.appendChild(h('div', { class: 'pjpg-modal' },
      h('div', { class: 'pjpg-kicker' }, 'Création'),
      h('h2', null, 'Importer de Pokéngine'),
      h('div', { class: 'pjpg-sep' }),
      h('p', null, 'Dépose les fichiers téléchargés sur pokengine.org dans chaque case. Les crédits sont ajoutés à CREDITS_POKENGINE.md.'),
      h('div', { class: 'pjpg-grid' }, SLOTS.map((d) => cards[d.key].card)),
      h('div', { class: 'pjpg-row' }, mode, go, h('button', { class: 'pjpg-secondary', onclick: close }, 'Fermer')),
      log));
    back.addEventListener('mousedown', (e) => { if (e.target === back) close(); });
    document.body.appendChild(back);
  }

  const txt = (e) => (e.textContent || '').trim();
  const leaf = (re) => [...document.querySelectorAll('body *')].find((e) => e.children.length === 0 && re.test(txt(e)) && !e.closest('.pjpg-btn,.pjpg-back'));
  function inject() {
    const cur = document.querySelector('.pjpg-btn');
    const lAj = leaf(/^ajouter le pok[eé]mon$/i);
    const lAn = leaf(/^annuler$/i);
    if (!lAj || !lAn) { if (cur) cur.remove(); return; }
    // élément « Annuler » complet : on remonte tant que le parent ne contient pas aussi « Ajouter »
    let w = lAn;
    while (w.parentElement && !w.parentElement.contains(lAj) && w.parentElement !== document.body) w = w.parentElement;
    if (!w.parentElement || w === lAj || w.contains(lAj)) return;
    if (cur && cur.previousElementSibling === w) return;
    if (cur) cur.remove();
    const model = lAn.closest('button,[role="button"]') || w;
    const btn = h('button', { class: (model.className || '') + ' pjpg-btn', type: 'button', onclick: ouvrir }, 'Importer de Pokéngine');
    w.insertAdjacentElement('afterend', btn);
  }
  let pending = false;
  new MutationObserver(() => { if (pending) return; pending = true; setTimeout(() => { pending = false; try { inject(); } catch (e) { /* rien */ } }, 300); })
    .observe(document.documentElement, { childList: true, subtree: true });
})();

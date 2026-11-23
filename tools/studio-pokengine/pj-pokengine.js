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

  function ouvrir() {
    let files = [];
    const liste = h('div', { class: 'pjpg-files' }, 'Aucun fichier choisi.');
    const log = h('div', { class: 'pjpg-log', style: 'display:none' });
    const mode = h('select', null,
      h('option', { value: 'normal' }, 'Importer'),
      h('option', { value: 'essai' }, 'Essai (n\'écrit rien)'),
      h('option', { value: 'images' }, 'Refaire seulement les images'),
      h('option', { value: 'refaire' }, 'Tout refaire (écrase)'));
    const go = h('button', { class: 'primary', disabled: true }, 'Lancer l\'import');
    const close = () => back.remove();
    const choisir = h('button', null, 'Choisir les fichiers…');
    choisir.onclick = async () => {
      try {
        const f = await call('choisir', {});
        if (f.length) { files = f; liste.textContent = f.join('\n'); go.disabled = false; }
      } catch (e) { log.style.display = 'block'; log.className = 'pjpg-log err'; log.textContent = e.message; }
    };
    go.onclick = async () => {
      go.disabled = true; log.style.display = 'block'; log.className = 'pjpg-log'; log.textContent = 'Import en cours…';
      try {
        const r = await call('importer', { projectPath: projectPath(), files, mode: mode.value });
        log.textContent = r.sortie || '(aucune sortie)';
        if (r.code !== 0) log.className = 'pjpg-log err';
        else if (mode.value !== 'essai') log.textContent += '\n\nTerminé. Ferme puis rouvre le projet (ou recharge Studio) pour voir les nouveaux Pokémon.';
      } catch (e) { log.className = 'pjpg-log err'; log.textContent = e.message; }
      go.disabled = false;
    };
    const back = h('div', { class: 'pjpg-back', onclick: (e) => { if (e.target === back) close(); } },
      h('div', { class: 'pjpg-modal' },
        h('h2', null, 'Importer de Pokéngine'),
        h('p', null, 'Choisis, pour chaque créature, la fiche PDF et ses images téléchargées depuis pokengine.org (code.webp, code_1.webp, code_2.webp, et code_3.webp pour le follower). Elles sont copiées dans tools/pokengine/telechargements puis importées dans le projet.'),
        h('p', null, 'Les crédits sont ajoutés à CREDITS_POKENGINE.md. Python 3 avec Pillow et pypdf est requis.'),
        h('div', { class: 'pjpg-row' }, choisir, mode, go),
        liste, log,
        h('div', { class: 'pjpg-row' }, h('button', { onclick: close }, 'Fermer'))));
    document.body.appendChild(back);
  }

  const txt = (e) => (e.textContent || '').trim();
  function inject() {
    const cur = document.querySelector('.pjpg-btn');
    const annuler = [...document.querySelectorAll('button')].find((b) => /^annuler$/i.test(txt(b)) && b.parentElement &&
      [...b.parentElement.querySelectorAll('button')].some((x) => /^ajouter le pok[eé]mon$/i.test(txt(x))));
    if (!annuler) { if (cur) cur.remove(); return; }
    if (cur && cur.previousElementSibling === annuler) return;
    if (cur) cur.remove();
    // même apparence que le bouton « Annuler », placé juste en dessous
    const btn = h('button', { class: annuler.className + ' pjpg-btn', type: 'button', onclick: ouvrir }, 'Importer de Pokéngine');
    annuler.insertAdjacentElement('afterend', btn);
  }
  let pending = false;
  new MutationObserver(() => { if (pending) return; pending = true; setTimeout(() => { pending = false; try { inject(); } catch (e) { /* rien */ } }, 300); })
    .observe(document.documentElement, { childList: true, subtree: true });
})();

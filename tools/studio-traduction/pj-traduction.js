/* eslint-disable */
// =============================================================================
// Traduction automatique — bouton ajouté à l'onglet « Traduction » de la page Textes de Pokémon Studio.
// À côté de « Utiliser la phrase d'origine », « Traduire automatiquement » traduit le texte de la langue par défaut (carte de
// gauche) dans la langue de la carte de droite et le met dans la zone de saisie. Le texte reste à valider comme une saisie
// normale. Si la zone n'est pas reconnue, la traduction est copiée dans le presse-papiers.
// =============================================================================
(() => {
  'use strict';
  if (window.__pjTraductionLoaded) return;
  window.__pjTraductionLoaded = true;

  const LANGS = { 'français': 'fr', 'anglais': 'en', 'italien': 'it', 'allemand': 'de', 'espagnol': 'es', 'coréen': 'ko', 'japonais': 'ja',
    'french': 'fr', 'english': 'en', 'italian': 'it', 'german': 'de', 'spanish': 'es', 'korean': 'ko', 'japanese': 'ja' };
  const langOf = (text) => {
    const m = String(text || '').trim().toLowerCase().match(/^([a-zçéèêôû]+)/);
    return m && LANGS[m[1]] ? LANGS[m[1]] : null;
  };
  const isLeaf = (el) => el.children.length === 0;

  const api = window.pjTraduction;
  async function translate(text, from, to) {
    if (!api || !api.translate) throw new Error('API absente : relance installer_studio_extra.bat puis redémarre Studio.');
    const r = await api.translate({ text, from, to });
    if (!r || !r.ok) throw new Error((r && r.error) || 'Erreur inconnue');
    return r.value;
  }

  // Cartes : on remonte depuis le bouton « Utiliser la phrase d'origine » jusqu'à la carte qui contient un nom de langue
  function findCards(originButton) {
    let right = originButton.parentElement;
    const hasLabel = (el) => Array.from(el.querySelectorAll('*')).some((n) => isLeaf(n) && langOf(n.textContent));
    while (right && !hasLabel(right)) right = right.parentElement;
    if (!right) return null;
    const row = right.parentElement;
    const left = row && Array.from(row.children).find((c) => c !== right && hasLabel(c));
    return left ? { left, right } : null;
  }
  const cardLang = (card) => {
    const n = Array.from(card.querySelectorAll('*')).find((e) => isLeaf(e) && langOf(e.textContent));
    return n ? langOf(n.textContent) : null;
  };
  // Texte de la carte de gauche : la dernière feuille de texte qui n'est ni le nom de la langue ni « Langue par défaut »
  function cardText(card) {
    const leaves = Array.from(card.querySelectorAll('*')).filter((e) => isLeaf(e) && e.textContent.trim()
      && !langOf(e.textContent) && !/^langue par défaut$|^default language$/i.test(e.textContent.trim()));
    const box = leaves.filter((e) => !/\btextes? traduits?\b/i.test(e.textContent) && e.tagName !== 'BUTTON' && e.tagName !== 'SPAN' || e.tagName === 'SPAN' && e.textContent.length > 12);
    const el = (box.length ? box : leaves).slice(-1)[0];
    return el ? (el.value !== undefined && el.tagName === 'TEXTAREA' ? el.value : el.innerText || el.textContent) : '';
  }
  function setField(card, value) {
    const field = card.querySelector('textarea, input[type="text"], [contenteditable="true"]');
    if (!field) return false;
    field.focus();
    if (field.tagName === 'TEXTAREA' || field.tagName === 'INPUT') {
      const proto = field.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
      Object.getOwnPropertyDescriptor(proto, 'value').set.call(field, value);
      field.dispatchEvent(new Event('input', { bubbles: true }));
      field.dispatchEvent(new Event('change', { bubbles: true }));
    } else {
      document.execCommand('selectAll', false, null);
      document.execCommand('insertText', false, value);
    }
    return true;
  }

  function addButton(originButton) {
    if (originButton.parentElement.querySelector('[data-pj-traduction]')) return;
    const btn = originButton.cloneNode(false);
    btn.setAttribute('data-pj-traduction', '1');
    btn.type = 'button';
    btn.textContent = 'Traduire automatiquement';
    btn.style.marginRight = '8px';
    btn.addEventListener('click', async (e) => {
      e.preventDefault();
      e.stopPropagation();
      const cards = findCards(originButton);
      const idle = 'Traduire automatiquement';
      if (!cards) { btn.textContent = 'Cartes introuvables'; setTimeout(() => { btn.textContent = idle; }, 2500); return; }
      const from = cardLang(cards.left) || 'auto';
      const to = cardLang(cards.right);
      const text = cardText(cards.left);
      if (!to || !text) { btn.textContent = 'Rien à traduire'; setTimeout(() => { btn.textContent = idle; }, 2500); return; }
      btn.disabled = true;
      btn.textContent = 'Traduction…';
      try {
        const out = await translate(text, from, to);
        if (setField(cards.right, out)) btn.textContent = 'Traduit : à valider';
        else { await navigator.clipboard.writeText(out); btn.textContent = 'Copié dans le presse-papiers'; }
      } catch (err) {
        console.error('[pj-traduction]', err);
        btn.textContent = 'Échec : ' + String(err.message || err).slice(0, 40);
      }
      btn.disabled = false;
      setTimeout(() => { btn.textContent = idle; }, 3000);
    });
    originButton.parentElement.insertBefore(btn, originButton);
  }

  function update() {
    document.querySelectorAll('button').forEach((b) => {
      if (!b.hasAttribute('data-pj-traduction') && /phrase d.origine|use (the )?original/i.test(b.textContent)) addButton(b);
    });
  }
  let scheduled = false;
  const observer = new MutationObserver(() => {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(() => { scheduled = false; try { update(); } catch (e) { /* page en cours de rendu */ } });
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
  try { update(); } catch (e) { /* rien */ }
})();

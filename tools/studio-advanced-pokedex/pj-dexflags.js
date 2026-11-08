/* eslint-disable */
// =============================================================================
// Groupes (flags) — ajout à la page « Pokémon » de Pokémon Studio (plugin « advanced_pokedex »)
// Ajoute un bloc « Groupes » : starter, légendaire, fabuleux, Ultra-Chimère, paradoxe… (liste libre).
// Un clic ouvre une fenêtre : cocher les groupes du Pokémon, créer / renommer / supprimer des groupes.
// Valider écrit aussitôt Data/configs/plugins/pokemon_flags.json :
//   { "klass": "PokemonFlagsConfig",
//     "flags": [ { "id": "legendary", "name": "Légendaire", "color": "#e0b040" } ],
//     "creatures": { "mewtwo": { "flags": ["legendary"], "forms": { "1": { "flags": [...] } } } } }
// En jeu : pokemon.group?(:legendary), pokemon.groups, PokemonFlags.creatures(:legendary)…
// =============================================================================
(() => {
  'use strict';
  if (window.__pjDexFlagsLoaded) return;
  window.__pjDexFlagsLoaded = true;

  const PALETTE = ['#e0493e', '#f08a3c', '#efcf3a', '#4cb04c', '#3fb6a8', '#3f7fe0', '#6562f8', '#9a5bc4', '#f08cc0', '#9a6b3c', '#9a9aa4', '#303030'];
  const slug = (s) => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');

  const api = window.pjAdex;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API Advanced Pokédex n'est pas disponible : relance l'installateur puis redémarre Studio.");
    const r = await api[name](payload);
    if (!r || !r.ok) throw new Error((r && r.error) || 'Erreur inconnue');
    return r.value;
  };
  function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    if (attrs) {
      for (const [k, v] of Object.entries(attrs)) {
        if (v === undefined || v === null || v === false) continue;
        if (k === 'class') el.className = v;
        else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
        else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2).toLowerCase(), v);
        else if (k === 'value') el.value = v;
        else if (k === 'checked') el.checked = !!v;
        else if (k === 'selected') el.selected = !!v;
        else el.setAttribute(k, v === true ? '' : v);
      }
    }
    const add = (c) => {
      if (c === null || c === undefined || c === false) return;
      if (Array.isArray(c)) c.forEach(add);
      else el.appendChild(c instanceof Node ? c : document.createTextNode(String(c)));
    };
    kids.forEach(add);
    return el;
  }
  function toast(msg, err) {
    document.querySelectorAll('.pjs-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pjs-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    setTimeout(() => t.remove(), err ? 6000 : 2500);
  }
  const projectPath = () => { try { return (JSON.parse(localStorage.getItem('projectList') || '[]')[0] || {}).projectPath || null; } catch (e) { return null; } };

  // ---------------------------------------------------------------------------
  // Données : fichier pokedex_infos.json (chargé une fois par projet)
  // ---------------------------------------------------------------------------
  const S = { path: null, data: null, loading: null };
  // force : relit le fichier (il a pu changer hors de Studio)
  async function data(force) {
    const p = projectPath();
    if (!force && S.data && S.path === p) return S.data;
    if (force || !S.loading || S.path !== p) {
      S.path = p;
      S.loading = call('getFlags', { projectPath: p }).then((d) => {
        S.data = d && typeof d === 'object' ? d : {};
        if (!S.data.creatures || typeof S.data.creatures !== 'object') S.data.creatures = {};
        if (!Array.isArray(S.data.flags)) S.data.flags = [];
        S.data.klass = 'PokemonFlagsConfig';
        return S.data;
      }).catch((e) => { S.loading = null; throw e; });
    }
    return S.loading;
  }

  // ---------------------------------------------------------------------------
  // Pokémon affiché : état global de Studio (selectedDataIdentifier.pokemon), lu dans l'arbre React
  // ---------------------------------------------------------------------------
  function stateFromValue(value) {
    if (!value || typeof value !== 'object') return null;
    if (value.selectedDataIdentifier) return value;
    if (Array.isArray(value) && value[0] && value[0].selectedDataIdentifier) return value[0];
    for (const key of Reflect.ownKeys(value)) {
      let v;
      try { v = value[key]; } catch (e) { continue; }
      if (!v || typeof v !== 'object') continue;
      if (v.selectedDataIdentifier) return v;
      if (v.current && v.current.selectedDataIdentifier) return v.current;
      if (v.v && v.v.current && v.v.current.selectedDataIdentifier) return v.v.current;
    }
    return null;
  }
  function studioState(el) {
    const key = el && Object.keys(el).find((k) => k.startsWith('__reactFiber$'));
    let fiber = key && el[key];
    for (let i = 0; fiber && i < 400; i++, fiber = fiber.return) {
      const st = stateFromValue(fiber.memoizedProps && fiber.memoizedProps.value);
      if (st) return st;
      // état gardé par un hook (useState / useReducer) du composant qui fournit le contexte
      let hook = fiber.memoizedState;
      for (let j = 0; hook && typeof hook === 'object' && j < 30; j++, hook = hook.next) {
        const v = hook.memoizedState;
        const found = (v && v.selectedDataIdentifier && v) || stateFromValue(v);
        if (found) return found;
      }
    }
    return null;
  }
  // Pokémon affiché, lu sur la page : « #002 » du bloc d'en-tête et « (n°1) » du choix de forme en haut
  function selectedFromPage(block) {
    const index = S.data && S.data.__index;
    if (!index) return null;
    const menu = databaseMenu();
    const leaves = [...document.querySelectorAll('span, div, p, h1, h2, h3, h4, small')]
      .filter((el) => el.childElementCount === 0 && !(menu && menu.contains(el)) && !el.closest('[data-pjd-block], [data-pjf-block], .pjd-overlay, #pjs-root, #pjv-root, #pjx-root'));
    const num = leaves.find((el) => /^#\s?\d{1,5}$/.test(el.textContent.trim()));
    if (!num) return null;
    const id = parseInt(num.textContent.replace(/\D/g, ''), 10);
    const db = index[String(id)];
    if (!db) return null;
    const formLeaf = leaves.find((el) => /\(n°\s*\d+\)\s*$/.test(el.textContent.trim()));
    const form = formLeaf ? parseInt(/\(n°\s*(\d+)\)\s*$/.exec(formLeaf.textContent.trim())[1], 10) : 0;
    return { db, form, id };
  }

  function selected(el) {
    const fromPage = selectedFromPage(el);
    if (fromPage) return fromPage;
    const st = studioState(el);
    const sel = st && st.selectedDataIdentifier && st.selectedDataIdentifier.pokemon;
    if (!sel) return null;
    const creature = st.projectData && st.projectData.pokemon && st.projectData.pokemon[sel.specie];
    return { db: sel.specie, form: sel.form | 0, id: creature ? creature.id : 0 };
  }

  // ---------------------------------------------------------------------------
  // Bloc ajouté à la page Pokémon (copie du bloc « Pokédex » pour garder le style de Studio)
  // ---------------------------------------------------------------------------
  // Bloc « Pokédex » de la page Pokémon : enfant de la grille des blocs (Pokédex, Évolution, Talents, Expérience…),
  // titre « Pokédex », contient Taille (m) et Poids (kg). Le menu de gauche (lien « Pokédex ») est ignoré.
  function databaseMenu() {
    const quests = document.querySelector('a[href$="/database/quests"]');
    return quests && quests.parentElement && quests.parentElement.parentElement;
  }
  function findPokedexBlock() {
    const menu = databaseMenu();
    const titles = [...document.querySelectorAll('h1, h2, h3, h4, span, div, p')]
      .filter((el) => el.childElementCount === 0 && el.textContent.trim() === 'Pokédex'
        && !el.closest('a, #pjs-root, #pjv-root, #pjx-root, [data-pjd-block], [data-pjf-block], .pjd-overlay') && !(menu && menu.contains(el)));
    for (const title of titles) {
      let block = title;
      for (let up = 0; up < 6 && block.parentElement; up++) {
        const grid = block.parentElement;
        // la grille contient d'autres blocs (Évolution, Talents, Expérience…)
        if (grid.children.length >= 3 && /Talent|Évolution|Expérience/.test(grid.textContent)) {
          const text = block.textContent;
          const small = text.length < 200 && block.querySelectorAll('*').length < 60;
          if (small && / kg/.test(text) && /\d\s?m/.test(text)) return { block, title };
          break;
        }
        block = grid;
      }
    }
    return null;
  }

  // groupes d'une forme (la forme reprend ceux de l'espèce si elle n'a pas les siens)
  function flagsOf(d, db, form) {
    const base = (d.creatures && d.creatures[db]) || {};
    const own = form && base.forms && base.forms[String(form)];
    return { list: (own && Array.isArray(own.flags) ? own.flags : base.flags) || [], own: !!(own && Array.isArray(own.flags)) };
  }
  const flagName = (d, id) => { const f = d.flags.find((x) => x.id === id); return f ? f.name : id; };

  let current = null; // { db, form, id }
  let version = 0;
  function update() {
    const found = findPokedexBlock();
    if (!found) return;
    const { block, title } = found;
    let mine = block.parentElement.querySelector(':scope > [data-pjf-block]');
    if (!mine) {
      mine = block.cloneNode(true);
      mine.setAttribute('data-pjf-block', '1');
      mine.removeAttribute('data-pjd-block');
      mine.removeAttribute('id');
      const leaves = [...mine.querySelectorAll('*')].filter((el) => el.childElementCount === 0 && el.textContent.trim());
      const titleLeaf = leaves.find((el) => el.textContent.trim() === 'Pokédex');
      if (titleLeaf) titleLeaf.textContent = 'Groupes';
      const rows = leaves.filter((el) => el !== titleLeaf);
      mine._rows = [];
      for (let i = 0; i + 1 < rows.length && mine._rows.length < 3; i += 2) mine._rows.push([rows[i], rows[i + 1]]);
      ['Groupes', 'Nombre', 'Réglés pour'].forEach((l, i) => { if (mine._rows[i]) mine._rows[i][0].textContent = l; });
      if (mine._rows[0]) Object.assign(mine._rows[0][1].style, { overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', maxWidth: '190px' });
      mine.style.cursor = 'pointer';
      mine.title = 'Groupes du Pokémon : starter, légendaire, Ultra-Chimère… (plugin Advanced Pokédex)';
      mine.addEventListener('click', (e) => { e.preventDefault(); e.stopPropagation(); openDialog(); });
      // après le bloc « Couleur, habitat, génération » s'il existe, sinon à la fin
      block.parentElement.appendChild(mine);
    }
    if (!S.data) {
      if (!S.waiting) { S.waiting = true; data().then(() => { S.waiting = false; update(); }).catch(() => { S.waiting = false; }); }
      return;
    }
    const sel = selected(block) || selected(title);
    if (!sel) { setRows(mine, ['?', '?', '?']); return; }
    const key = `${sel.db}/${sel.form}`;
    if (mine._key === key && mine._version === version) return;
    mine._key = key; mine._version = version;
    current = sel;
    data(true).then((d) => {
      if (mine._key !== key) return;
      const f = flagsOf(d, sel.db, sel.form);
      const names = f.list.map((id) => flagName(d, id));
      setRows(mine, [names.length ? names.join(', ') : '—', String(names.length), f.own ? `Forme ${sel.form}` : 'Toute l\'espèce']);
      if (mine._rows[0]) mine._rows[0][1].title = names.join(', ');
    }).catch((e) => setRows(mine, ['!', '!', e.message.slice(0, 40)]));
  }
  function setRows(mine, values) {
    (mine._rows || []).forEach(([, value], i) => { if (value.textContent !== values[i]) value.textContent = values[i]; });
  }

  // ---------------------------------------------------------------------------
  // Fenêtre : groupes du Pokémon + gestion de la liste des groupes
  // ---------------------------------------------------------------------------
  async function openDialog() {
    const sel = current;
    if (!sel) { toast('Pokémon affiché introuvable', true); return; }
    let d;
    try { d = await data(true); } catch (e) { toast('Lecture impossible : ' + e.message, true); return; }
    const flags = JSON.parse(JSON.stringify(d.flags));       // liste modifiable (validée avec Valider)
    const entry = d.creatures[sel.db] || {};
    const target = { scope: sel.form && entry.forms && entry.forms[String(sel.form)] && Array.isArray(entry.forms[String(sel.form)].flags) ? 'form' : 'species' };
    let chosen = new Set();
    const read = () => {
      const src = target.scope === 'form' ? ((entry.forms || {})[String(sel.form)] || {}).flags || entry.flags : entry.flags;
      chosen = new Set(src || []);
    };

    const overlay = h('div', { class: 'pjd-overlay' });
    const close = () => overlay.remove();
    overlay.addEventListener('mousedown', (e) => { if (e.target === overlay) close(); });
    const chips = h('div', { class: 'pjf-chips' });
    const manage = h('div', { class: 'pjf-manage' });
    const count = (id) => Object.values(d.creatures).reduce((n, c) => n + ((c.flags || []).includes(id) ? 1 : 0)
      + Object.values(c.forms || {}).reduce((m, f) => m + ((f.flags || []).includes(id) ? 1 : 0), 0), 0);

    const fillChips = () => {
      chips.textContent = '';
      if (!flags.length) chips.appendChild(h('div', { class: 'pjs-hint inline' }, 'Aucun groupe : crée-en un ci-dessous.'));
      flags.forEach((f) => {
        const b = h('button', { class: 'pjf-chip' + (chosen.has(f.id) ? ' active' : ''), title: f.id,
          onclick: () => { chosen.has(f.id) ? chosen.delete(f.id) : chosen.add(f.id); b.classList.toggle('active'); } },
        h('span', { class: 'pjd-dot', style: { background: f.color || '#9a9aa4' } }), f.name);
        chips.appendChild(b);
      });
    };
    const fillManage = () => {
      manage.textContent = '';
      flags.forEach((f, i) => {
        const name = h('input', { class: 'pjs-input', value: f.name });
        name.addEventListener('input', () => { f.name = name.value; });
        name.addEventListener('change', fillChips);
        const color = h('input', { type: 'color', class: 'pjf-colorpick', value: f.color || '#9a9aa4' });
        color.addEventListener('input', () => { f.color = color.value; fillChips(); });
        const del = h('button', { class: 'pjs-btn small danger', title: 'Supprimer ce groupe (retiré de tous les Pokémon)', onclick: () => {
          const n = count(f.id);
          if (n && !confirm(`Supprimer le groupe « ${f.name} » ? Il sera retiré de ${n} Pokémon.`)) return;
          flags.splice(i, 1); chosen.delete(f.id); fillChips(); fillManage();
        } }, 'Supprimer');
        manage.appendChild(h('div', { class: 'pjf-row' }, color, name, h('span', { class: 'pjs-hint inline pjf-id' }, `:${f.id} — ${count(f.id)}`), del));
      });
      const newName = h('input', { class: 'pjs-input', placeholder: 'Nouveau groupe (ex. Pseudo-légendaire)' });
      const add = () => {
        const n = newName.value.trim();
        if (!n) return;
        let id = slug(n) || 'groupe';
        let k = 2; const base = id;
        while (flags.some((f) => f.id === id)) id = `${base}_${k++}`;
        flags.push({ id, name: n, color: PALETTE[flags.length % PALETTE.length] });
        chosen.add(id);
        fillChips(); fillManage();
      };
      newName.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); e.stopPropagation(); add(); } });
      manage.appendChild(h('div', { class: 'pjf-row' }, newName, h('button', { class: 'pjs-btn small', onclick: add }, 'Ajouter')));
    };

    const scope = sel.form !== 0 ? h('div', { class: 'pjs-variants' }, [['species', 'Toute l\'espèce'], ['form', `Forme ${sel.form} seulement`]].map(([k, l]) => {
      const b = h('button', { class: 'pjs-variant' + (target.scope === k ? ' active' : ''), onclick: () => { target.scope = k; [...b.parentElement.children].forEach((c) => c.classList.toggle('active', c === b)); read(); fillChips(); } }, l);
      return b;
    })) : null;

    const save = async () => {
      const ids = new Set(flags.map((f) => f.id));
      // groupes supprimés : retirés de tous les Pokémon
      Object.keys(d.creatures).forEach((db) => {
        const c = d.creatures[db];
        if (c.flags) c.flags = c.flags.filter((id) => ids.has(id));
        Object.values(c.forms || {}).forEach((f) => { if (f.flags) f.flags = f.flags.filter((id) => ids.has(id)); });
      });
      const list = flags.map((f) => f.id).filter((id) => chosen.has(id)); // ordre de la liste des groupes
      const e = d.creatures[sel.db] = d.creatures[sel.db] || {};
      if (target.scope === 'form') {
        e.forms = e.forms || {};
        e.forms[String(sel.form)] = Object.assign(e.forms[String(sel.form)] || {}, { flags: list });
      } else if (list.length) e.flags = list; else delete e.flags;
      // nettoyage
      Object.keys(d.creatures).forEach((db) => {
        const c = d.creatures[db];
        if (c.flags && !c.flags.length) delete c.flags;
        if (c.forms) { Object.keys(c.forms).forEach((f) => { if (!c.forms[f].flags || (!c.forms[f].flags.length && !(db === sel.db && f === String(sel.form) && target.scope === 'form'))) delete c.forms[f]; }); if (!Object.keys(c.forms).length) delete c.forms; }
        if (!Object.keys(c).length) delete d.creatures[db];
      });
      d.flags = flags;
      try {
        await call('saveFlags', { projectPath: S.path, data: d });
        version++;
        toast('Groupes enregistrés');
        close();
        update();
      } catch (err) { toast('Enregistrement impossible : ' + err.message, true); }
    };

    overlay.appendChild(h('div', { class: 'pjd-dialog pjf-dialog' },
      h('div', { class: 'pjd-head' }, h('h2', null, 'Groupes'), h('span', { class: 'pjs-hint inline' }, `${sel.db}${sel.form ? ` (forme ${sel.form})` : ''}`)),
      scope,
      h('div', { class: 'pjs-label' }, 'Groupes du Pokémon (clic pour cocher / décocher)'), chips,
      h('div', { class: 'pjs-label' }, 'Liste des groupes du projet'), manage,
      h('div', { class: 'pjs-hint' }, 'Enregistré dans Data/configs/plugins/pokemon_flags.json. En jeu : pokemon.group?(:legendary), pokemon.groups, PokemonFlags.creatures(:starter), pokemon_has_flag?(1, :paradox) dans un évent. Les groupes gen_1 à gen_9 (et gen_0) existent aussi d\'office, d\'après la génération du Pokémon.'),
      h('div', { class: 'pjd-actions' },
        h('button', { class: 'pjs-btn secondary', onclick: close }, 'Annuler'),
        h('button', { class: 'pjs-btn primary', onclick: save }, 'Valider'))));
    read(); fillChips(); fillManage();
    overlay.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });
    document.body.appendChild(overlay);
  }

  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; try { update(); } catch (e) { /* page en cours de rendu */ } }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true, characterData: true }); update(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  window.pjDexFlags = { update, data };
})();

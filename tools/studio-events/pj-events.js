/* eslint-disable */
// =============================================================================
// Studio Events — éditeur d'évents pour Pokémon Studio (sans RPG Maker)
// Format : Data/Studio/map_events/<mapDbSymbol>.json + Data/Studio/common_events.json
// Exécuté en jeu par le script PSDK « scripts/90000 StudioEvents.rb ».
// =============================================================================
(() => {
  'use strict';
  if (window.__pjEventsLoaded) return;
  window.__pjEventsLoaded = true;

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------
  const api = window.pjEvents;
  const call = async (name, payload) => {
    if (!api || !api[name]) throw new Error("L'API Studio Events n'est pas disponible : relance l'installateur puis redémarre Studio.");
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
  const clone = (o) => JSON.parse(JSON.stringify(o));
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const num = (v, d = 0) => { const n = parseInt(v, 10); return Number.isFinite(n) ? n : d; };
  const pad = (n, l = 4) => String(n).padStart(l, '0');
  const firstLine = (t, max = 60) => { const s = String(t || '').split('\n')[0]; return s.length > max ? s.slice(0, max) + '…' : s; };

  let toastTimer = null;
  function toast(msg, err) {
    document.querySelectorAll('.pje-toast').forEach((t) => t.remove());
    const t = h('div', { class: 'pje-toast' + (err ? ' err' : '') }, msg);
    document.body.appendChild(t);
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.remove(), err ? 6000 : 2500);
  }

  const S = {
    open: false,
    projectPath: null,
    ctx: null,
    tab: 'maps',
    mapId: null,
    docs: {},          // dbSymbol -> { data, rmxp, dirty, undo }
    common: null,      // { data, rmxp, dirty, undo }
    zoom: 2,
    treeOpen: {},      // dossiers de la liste des cartes ouverts / fermés
    selTile: null,
    selEventId: null,
    showRmxp: true,
    commonSel: null,
    mapFilter: '',
    error: null,
  };

  function projectUrl(rel, type = 'image') {
    const u = new URL(rel.split('/').map(encodeURIComponent).join('/'), window.__pjEventsProjectBase || 'project://--/');
    u.searchParams.append('projectPath', S.projectPath);
    u.searchParams.append('type', type);
    return u.toString();
  }

  const imageCache = new Map();
  function loadImage(rel) {
    if (!imageCache.has(rel)) {
      imageCache.set(rel, new Promise((res) => {
        const img = new Image();
        img.onload = () => res(img);
        img.onerror = () => res(null);
        img.src = projectUrl(rel);
      }));
    }
    return imageCache.get(rel);
  }

  // Dessine une frame de charset (4x4) dans un canvas
  async function drawCharacter(canvas, graphic, scale) {
    const ctx = canvas.getContext('2d');
    if (!graphic || !graphic.characterName) { canvas.width = 0; canvas.height = 0; return false; }
    const img = await loadImage(`Graphics/Characters/${graphic.characterName}.png`);
    if (!img) { canvas.width = 0; canvas.height = 0; return false; }
    const fw = Math.floor(img.width / 4), fh = Math.floor(img.height / 4);
    const row = { 2: 0, 4: 1, 6: 2, 8: 3 }[graphic.direction] ?? 0;
    const col = clamp(graphic.pattern || 0, 0, 3);
    canvas.width = Math.max(1, Math.round(fw * scale));
    canvas.height = Math.max(1, Math.round(fh * scale));
    ctx.imageSmoothingEnabled = false;
    ctx.globalAlpha = (graphic.opacity ?? 255) / 255;
    ctx.drawImage(img, col * fw, row * fh, fw, fh, 0, 0, canvas.width, canvas.height);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Modèle
  // ---------------------------------------------------------------------------
  const TRIGGERS = [['action', 'Touche action'], ['playerTouch', 'Contact du joueur'], ['eventTouch', "Contact de l'évent"], ['autorun', 'Automatique'], ['parallel', 'Processus parallèle']];
  const MOVE_TYPES = [['fixed', 'Fixe'], ['random', 'Aléatoire'], ['approach', 'Vers le joueur'], ['custom', 'Personnalisé (route)']];
  const SPEEDS = [[1, '1 : très lent'], [2, '2 : lent'], [3, '3 : normal'], [4, '4 : rapide'], [5, '5 : très rapide'], [6, '6 : ultra rapide']];
  const FREQS = [[1, '1 : très basse'], [2, '2 : basse'], [3, '3 : normale'], [4, '4 : haute'], [5, '5 : très haute'], [6, '6 : maximale']];
  const DIRS = [[2, 'Bas'], [4, 'Gauche'], [6, 'Droite'], [8, 'Haut']];
  const DIRS_KEEP = [[0, 'Garder'], ...DIRS];
  const SELF = [['A', 'A'], ['B', 'B'], ['C', 'C'], ['D', 'D']];
  const OPERATORS = [['==', '='], ['>=', '≥'], ['<=', '≤'], ['>', '>'], ['<', '<'], ['!=', '≠']];
  const VAR_OPS = [['set', '= (définir)'], ['add', '+= (ajouter)'], ['sub', '-= (retirer)'], ['mul', '×= (multiplier)'], ['div', '÷= (diviser)'], ['mod', '%= (modulo)']];
  const TROOPS = [[3, 'Dresseur'], [4, "Champion d'arène"], [5, 'Conseil 4'], [6, 'Maître']];
  const COMMON_TRIGGERS = [['none', 'Aucun (appelé par commande)'], ['autorun', 'Automatique'], ['parallel', 'Processus parallèle']];

  const newPage = () => ({
    conditions: { switch1: null, switch2: null, variable: null, selfSwitch: null },
    graphic: { characterName: '', tileId: 0, hue: 0, direction: 2, pattern: 0, opacity: 255, blendType: 0 },
    moveType: 'fixed', moveSpeed: 3, moveFrequency: 3,
    moveRoute: { repeat: true, skippable: false, commands: [] },
    walkAnime: true, stepAnime: false, directionFix: false, through: false, alwaysOnTop: false,
    trigger: 'action', commands: [],
  });
  const newEvent = (id, x, y) => ({ klass: 'MapEvent', id, name: `EV${pad(id, 3)}`, x, y, pages: [newPage()] });

  const switchName = (id) => (S.ctx && S.ctx.switches[id]) || '';
  const varName = (id) => (S.ctx && S.ctx.variables[id]) || '';
  const sw = (id) => `[${pad(id)}${switchName(id) ? ' : ' + switchName(id) : ''}]`;
  const vr = (id) => `[${pad(id)}${varName(id) ? ' : ' + varName(id) : ''}]`;
  const mapLabel = (id) => { const m = S.ctx && S.ctx.maps.find((x) => x.id === id); return m ? `${pad(id, 3)} : ${m.name}` : pad(id, 3); };
  const dirLabel = (d) => (DIRS_KEEP.find((x) => x[0] === d) || [0, '?'])[1];
  const targetLabel = (t) => (t === -1 ? 'Joueur' : t === 0 ? 'Cet évent' : `Évent #${t}`);
  const operandLabel = (o) => (!o ? '0' : o.type === 'variable' ? `Variable ${vr(o.id)}` : o.type === 'random' ? `Aléatoire (${o.min}..${o.max})` : String(o.value));
  const audioLabel = (a) => (a && a.name ? `${a.name} (${a.volume ?? 100}%, ${a.pitch ?? 100}%)` : '(aucun)');
  const nameOf = (list, sym) => { const x = (list || []).find((e) => e.dbSymbol === sym); return x ? x.name : sym; };

  function conditionLabel(c) {
    if (!c) return '?';
    switch (c.type) {
      case 'switch': return `Interrupteur ${sw(c.id)} est ${c.value ? 'ON' : 'OFF'}`;
      case 'variable': return `Variable ${vr(c.id)} ${(OPERATORS.find((o) => o[0] === c.operator) || ['', '='])[1]} ${operandLabel(c.operand)}`;
      case 'selfSwitch': return `Interrupteur local ${c.ch} est ${c.value ? 'ON' : 'OFF'}`;
      case 'facing': return `${targetLabel(c.target)} regarde vers ${dirLabel(c.direction)}`;
      default: return `Script : ${firstLine(c.code, 50)}`;
    }
  }

  // ---------------------------------------------------------------------------
  // Catalogue des commandes
  // ---------------------------------------------------------------------------
  const defaultAudio = () => ({ name: '', volume: 100, pitch: 100 });
  const CMDS = {
    ShowMessage: { cat: 'Messages', label: 'Afficher un message', kind: 'msg', make: () => ({ klass: 'ShowMessage', text: '' }),
      fields: [{ key: 'text', type: 'textarea', label: 'Texte', hint: 'Une ligne = une ligne de la boîte. Codes PSDK utilisables (\\c[n], \\v[n], [WAIT n]…).' }],
      describe: (c) => ['Message', firstLine(c.text)] },
    ShowChoices: { cat: 'Messages', label: 'Afficher des choix', kind: 'msg', make: () => ({ klass: 'ShowChoices', cancel: 'disallow', choices: [{ text: 'Oui', commands: [] }, { text: 'Non', commands: [] }], cancelCommands: [] }),
      fields: [{ key: 'choices', type: 'choices', label: 'Choix' }], describe: (c) => ['Choix', c.choices.map((x) => x.text).join(', ')] },
    Comment: { cat: 'Messages', label: 'Commentaire', kind: 'comment', make: () => ({ klass: 'Comment', text: '' }),
      fields: [{ key: 'text', type: 'textarea', label: 'Commentaire' }], describe: (c) => ['Commentaire', firstLine(c.text)] },

    ConditionalBranch: { cat: 'Déroulement', label: 'Condition', kind: 'flow', make: () => ({ klass: 'ConditionalBranch', condition: { type: 'switch', id: 1, value: true }, commands: [], elseCommands: [] }),
      fields: [{ key: 'condition', type: 'condition', label: 'Condition' }, { key: 'elseCommands', type: 'elseToggle', label: 'Branche « Sinon »' }],
      describe: (c) => ['Si', conditionLabel(c.condition)] },
    Loop: { cat: 'Déroulement', label: 'Boucle', kind: 'flow', make: () => ({ klass: 'Loop', commands: [] }), fields: [], describe: () => ['Boucle', ''] },
    BreakLoop: { cat: 'Déroulement', label: 'Sortir de la boucle', kind: 'flow', make: () => ({ klass: 'BreakLoop' }), fields: [], describe: () => ['Sortir de la boucle', ''] },
    ExitEvent: { cat: 'Déroulement', label: "Arrêter l'évent", kind: 'flow', make: () => ({ klass: 'ExitEvent' }), fields: [], describe: () => ["Arrêter l'évent", ''] },
    EraseEvent: { cat: 'Déroulement', label: "Effacer l'évent (temporaire)", kind: 'flow', make: () => ({ klass: 'EraseEvent' }), fields: [], describe: () => ["Effacer l'évent", ''] },
    CallCommonEvent: { cat: 'Déroulement', label: 'Appeler un évent commun', kind: 'flow', make: () => ({ klass: 'CallCommonEvent', id: 1 }),
      fields: [{ key: 'id', type: 'commonEvent', label: 'Évent commun' }], describe: (c) => ['Évent commun', commonLabel(c.id)] },
    Label: { cat: 'Déroulement', label: 'Étiquette', kind: 'flow', make: () => ({ klass: 'Label', name: '' }), fields: [{ key: 'name', type: 'text', label: 'Nom' }], describe: (c) => ['Étiquette', c.name] },
    JumpToLabel: { cat: 'Déroulement', label: "Aller à l'étiquette", kind: 'flow', make: () => ({ klass: 'JumpToLabel', name: '' }), fields: [{ key: 'name', type: 'text', label: 'Nom' }], describe: (c) => ["Aller à l'étiquette", c.name] },
    Wait: { cat: 'Déroulement', label: 'Attendre', kind: 'flow', make: () => ({ klass: 'Wait', frames: 20 }),
      fields: [{ key: 'frames', type: 'number', label: 'Frames', min: 1, max: 9999, hint: '60 frames = 1 seconde' }], describe: (c) => ['Attendre', `${c.frames} frame(s)`] },

    ControlSwitches: { cat: 'Données du jeu', label: 'Interrupteurs', kind: 'data', make: () => ({ klass: 'ControlSwitches', from: 1, to: 1, value: true }),
      fields: [{ key: 'from', type: 'switch', label: 'Interrupteur' }, { key: 'to', type: 'switch', label: "Jusqu'à (plage)", hint: 'Mets le même numéro pour un seul interrupteur.' }, { key: 'value', type: 'select', label: 'Valeur', options: [[true, 'ON'], [false, 'OFF']] }],
      describe: (c) => ['Interrupteur', `${c.from === c.to ? sw(c.from) : `[${pad(c.from)}..${pad(c.to)}]`} = ${c.value ? 'ON' : 'OFF'}`] },
    ControlVariables: { cat: 'Données du jeu', label: 'Variables', kind: 'data', make: () => ({ klass: 'ControlVariables', from: 1, to: 1, operation: 'set', operand: { type: 'constant', value: 0 } }),
      fields: [{ key: 'from', type: 'variable', label: 'Variable' }, { key: 'to', type: 'variable', label: "Jusqu'à (plage)" }, { key: 'operation', type: 'select', label: 'Opération', options: VAR_OPS }, { key: 'operand', type: 'operand', label: 'Valeur', random: true }],
      describe: (c) => ['Variable', `${c.from === c.to ? vr(c.from) : `[${pad(c.from)}..${pad(c.to)}]`} ${(VAR_OPS.find((o) => o[0] === c.operation) || ['', '='])[1].split(' ')[0]} ${operandLabel(c.operand)}`] },
    ControlSelfSwitch: { cat: 'Données du jeu', label: 'Interrupteur local', kind: 'data', make: () => ({ klass: 'ControlSelfSwitch', ch: 'A', value: true }),
      fields: [{ key: 'ch', type: 'select', label: 'Interrupteur', options: SELF }, { key: 'value', type: 'select', label: 'Valeur', options: [[true, 'ON'], [false, 'OFF']] }],
      describe: (c) => ['Interrupteur local', `${c.ch} = ${c.value ? 'ON' : 'OFF'}`] },

    TransferPlayer: { cat: 'Déplacements', label: 'Téléporter le joueur', kind: 'move', make: () => ({ klass: 'TransferPlayer', mapId: S.mapId || 1, x: 0, y: 0, direction: 0, fade: true }),
      fields: [{ key: '_pos', type: 'position', label: 'Destination' }, { key: 'direction', type: 'select', label: 'Direction', options: DIRS_KEEP }, { key: 'fade', type: 'checkbox', label: 'Fondu', text: 'Fondu au noir' }],
      describe: (c) => ['Téléporter', `${mapLabel(c.mapId)} (${c.x}, ${c.y})${c.direction ? ', ' + dirLabel(c.direction) : ''}`] },
    SetEventLocation: { cat: 'Déplacements', label: "Placer un évent", kind: 'move', make: () => ({ klass: 'SetEventLocation', target: 0, x: 0, y: 0, direction: 0 }),
      fields: [{ key: 'target', type: 'target', label: 'Évent', noPlayer: true }, { key: '_xy', type: 'xy', label: 'Position' }, { key: 'direction', type: 'select', label: 'Direction', options: DIRS_KEEP }],
      describe: (c) => ["Placer l'évent", `${targetLabel(c.target)} en (${c.x}, ${c.y})`] },
    SetMoveRoute: { cat: 'Déplacements', label: 'Définir une route', kind: 'move', make: () => ({ klass: 'SetMoveRoute', target: 0, route: { repeat: false, skippable: false, commands: [] } }),
      fields: [{ key: 'target', type: 'target', label: 'Personnage' }, { key: 'route', type: 'route', label: 'Route' }],
      describe: (c) => ['Route', `${targetLabel(c.target)} : ${routeSummary(c.route)}`] },
    WaitForMoveCompletion: { cat: 'Déplacements', label: 'Attendre la fin des déplacements', kind: 'move', make: () => ({ klass: 'WaitForMoveCompletion' }), fields: [], describe: () => ['Attendre la fin des déplacements', ''] },
    ChangeTransparency: { cat: 'Déplacements', label: 'Transparence du joueur', kind: 'move', make: () => ({ klass: 'ChangeTransparency', transparent: true }),
      fields: [{ key: 'transparent', type: 'select', label: 'Joueur', options: [[true, 'Invisible'], [false, 'Visible']] }], describe: (c) => ['Transparence', c.transparent ? 'Invisible' : 'Visible'] },

    PlayBGM: { cat: 'Audio', label: 'Jouer une musique (BGM)', kind: 'audio', make: () => ({ klass: 'PlayBGM', audio: defaultAudio() }), fields: [{ key: 'audio', type: 'audio', label: 'Musique', folder: 'bgm' }], describe: (c) => ['BGM', audioLabel(c.audio)] },
    FadeOutBGM: { cat: 'Audio', label: 'Fondu de la musique', kind: 'audio', make: () => ({ klass: 'FadeOutBGM', seconds: 1 }), fields: [{ key: 'seconds', type: 'number', label: 'Secondes', min: 0, max: 60 }], describe: (c) => ['Fondu BGM', `${c.seconds} s`] },
    PlayBGS: { cat: 'Audio', label: "Jouer un fond sonore (BGS)", kind: 'audio', make: () => ({ klass: 'PlayBGS', audio: defaultAudio() }), fields: [{ key: 'audio', type: 'audio', label: 'Fond sonore', folder: 'bgs' }], describe: (c) => ['BGS', audioLabel(c.audio)] },
    FadeOutBGS: { cat: 'Audio', label: 'Fondu du fond sonore', kind: 'audio', make: () => ({ klass: 'FadeOutBGS', seconds: 1 }), fields: [{ key: 'seconds', type: 'number', label: 'Secondes', min: 0, max: 60 }], describe: (c) => ['Fondu BGS', `${c.seconds} s`] },
    PlayME: { cat: 'Audio', label: 'Jouer un jingle (ME)', kind: 'audio', make: () => ({ klass: 'PlayME', audio: defaultAudio() }), fields: [{ key: 'audio', type: 'audio', label: 'Jingle', folder: 'me' }], describe: (c) => ['ME', audioLabel(c.audio)] },
    PlaySE: { cat: 'Audio', label: 'Jouer un son (SE)', kind: 'audio', make: () => ({ klass: 'PlaySE', audio: { name: '', volume: 80, pitch: 100 } }), fields: [{ key: 'audio', type: 'audio', label: 'Son', folder: 'se' }], describe: (c) => ['SE', audioLabel(c.audio)] },

    GivePokemon: { cat: 'Pokémon', label: 'Donner un Pokémon', kind: 'poke', make: () => ({ klass: 'GivePokemon', pokemon: '', level: 5, shiny: false }),
      fields: [{ key: 'pokemon', type: 'pokemon', label: 'Pokémon' }, { key: 'level', type: 'number', label: 'Niveau', min: 1, max: 100 }, { key: 'shiny', type: 'checkbox', label: 'Chromatique', text: 'Forcer chromatique' }],
      describe: (c) => ['Donner Pokémon', `${nameOf(S.ctx.pokemon, c.pokemon)} N.${c.level}${c.shiny ? ' ✦' : ''}`] },
    WildBattle: { cat: 'Pokémon', label: 'Combat contre un Pokémon sauvage', kind: 'poke', make: () => ({ klass: 'WildBattle', pokemon: '', level: 5 }),
      fields: [{ key: 'pokemon', type: 'pokemon', label: 'Pokémon' }, { key: 'level', type: 'number', label: 'Niveau', min: 1, max: 100 }],
      describe: (c) => ['Combat sauvage', `${nameOf(S.ctx.pokemon, c.pokemon)} N.${c.level}`] },
    TrainerBattle: { cat: 'Pokémon', label: 'Combat de dresseur', kind: 'poke', make: () => ({ klass: 'TrainerBattle', trainerId: 1, troopId: 3, bgm: '' }),
      fields: [{ key: 'trainerId', type: 'trainer', label: 'Dresseur' }, { key: 'troopId', type: 'select', label: 'Type', options: TROOPS }, { key: 'bgm', type: 'text', label: 'BGM (optionnel)', hint: "Nom d'une musique de Audio/BGM. Vide = musique par défaut." }],
      describe: (c) => ['Combat dresseur', `${trainerLabel(c.trainerId)}`], hint: "Victoire : active l'interrupteur local B. Défaite : désactive A (comportement PSDK de start_trainer_battle)." },
    GiveItem: { cat: 'Pokémon', label: 'Donner un objet', kind: 'poke', make: () => ({ klass: 'GiveItem', item: '', count: 1 }),
      fields: [{ key: 'item', type: 'item', label: 'Objet' }, { key: 'count', type: 'number', label: 'Quantité', min: 1, max: 999 }],
      describe: (c) => ['Donner objet', `${nameOf(S.ctx.items, c.item)} ×${c.count}`] },
    HealParty: { cat: 'Pokémon', label: "Soigner l'équipe", kind: 'poke', make: () => ({ klass: 'HealParty' }), fields: [], describe: () => ["Soigner l'équipe", ''] },
    OpenShop: { cat: 'Pokémon', label: 'Ouvrir une boutique', kind: 'poke', make: () => ({ klass: 'OpenShop', shop: '' }), fields: [{ key: 'shop', type: 'shop', label: 'Boutique' }], describe: (c) => ['Boutique', c.shop] },

    Script: { cat: 'Avancé', label: 'Script Ruby', kind: 'script', make: () => ({ klass: 'Script', code: '' }), fields: [{ key: 'code', type: 'code', label: 'Code' }], describe: (c) => ['Script', firstLine(c.code)] },
    Raw: { cat: null, label: 'Commande RPG Maker', kind: 'raw', make: () => ({ klass: 'Raw', commands: [] }), fields: [{ key: 'commands', type: 'json', label: 'Commandes brutes' }],
      describe: (c) => ['RPG Maker', (c.commands || []).filter((x) => x.indent === 0).map((x) => `#${x.code}`).join(' ') || '(vide)'] },
  };
  const CATS = ['Messages', 'Déroulement', 'Données du jeu', 'Déplacements', 'Audio', 'Pokémon', 'Avancé'];

  function commonLabel(id) {
    const ce = S.common && S.common.data && S.common.data.events.find((e) => e.id === id);
    const rm = S.common && S.common.rmxp && S.common.rmxp.find((e) => e.id === id);
    return `[${pad(id, 3)}${ce ? ' : ' + ce.name : rm ? ' : ' + rm.name : ''}]`;
  }
  function trainerLabel(id) { const t = S.ctx && S.ctx.trainers.find((x) => x.id === id); return t ? `#${id} ${t.name}` : `#${id}`; }

  // Codes de déplacement (routes)
  const MOVES = [
    [1, 'Descendre'], [2, 'Aller à gauche'], [3, 'Aller à droite'], [4, 'Monter'],
    [5, 'Bas-gauche'], [6, 'Bas-droite'], [7, 'Haut-gauche'], [8, 'Haut-droite'],
    [9, 'Pas au hasard'], [10, 'Vers le joueur'], [11, 'Fuir le joueur'], [12, 'Avancer'], [13, 'Reculer'],
    [14, 'Sauter', [['x', 'X', 0], ['y', 'Y', 0]]], [15, 'Attendre', [['n', 'Frames', 10]]],
    [16, 'Regarder en bas'], [17, 'Regarder à gauche'], [18, 'Regarder à droite'], [19, 'Regarder en haut'],
    [20, 'Tourner à droite 90°'], [21, 'Tourner à gauche 90°'], [22, 'Demi-tour'], [23, 'Tourner 90° au hasard'],
    [24, 'Direction au hasard'], [25, 'Regarder le joueur'], [26, 'Dos au joueur'],
    [27, 'Interrupteur ON', [['n', 'Interrupteur', 1]]], [28, 'Interrupteur OFF', [['n', 'Interrupteur', 1]]],
    [29, 'Vitesse', [['n', 'Vitesse (1-6)', 3]]], [30, 'Fréquence', [['n', 'Fréquence (1-6)', 3]]],
    [31, 'Anim. marche ON'], [32, 'Anim. marche OFF'], [33, 'Anim. sur place ON'], [34, 'Anim. sur place OFF'],
    [35, 'Direction fixe ON'], [36, 'Direction fixe OFF'], [37, 'Traverser ON'], [38, 'Traverser OFF'],
    [39, 'Au premier plan ON'], [40, 'Au premier plan OFF'],
    [41, 'Changer apparence', [['s', 'Charset', ''], ['n', 'Teinte', 0], ['n', 'Direction', 2], ['n', 'Motif', 0]]],
    [42, 'Opacité', [['n', 'Opacité (0-255)', 255]]], [43, 'Mode de fusion', [['n', 'Fusion (0-2)', 0]]],
    [44, 'Jouer un son', [['se', 'Son', '']]], [45, 'Script', [['s', 'Code', '']]],
  ];
  const moveInfo = (code) => MOVES.find((m) => m[0] === code) || [code, `Code ${code}`];
  function moveLabel(mc) {
    const info = moveInfo(mc.code);
    const p = mc.parameters || [];
    if (!info[2] || !p.length) return info[1];
    if (mc.code === 44) return `${info[1]} : ${(p[0] && p[0].name) || '?'}`;
    return `${info[1]} : ${p.map((v) => (typeof v === 'object' ? JSON.stringify(v) : v)).join(', ')}`;
  }
  function routeSummary(r) {
    const cmds = (r && r.commands) || [];
    if (!cmds.length) return '(vide)';
    const s = cmds.slice(0, 4).map(moveLabel).join(', ');
    return (cmds.length > 4 ? s + ', …' : s) + (r.repeat ? ' [boucle]' : '');
  }

  // ---------------------------------------------------------------------------
  // Modales
  // ---------------------------------------------------------------------------
  const modalStack = [];
  function openModal({ title, cls = '', body, foot, onClose, head }) {
    const box = h('div', { class: 'pje-modal ' + cls });
    const overlay = h('div', { class: 'pje-overlay' }, box);
    const m = {
      el: box,
      close: (result) => {
        overlay.remove();
        const i = modalStack.indexOf(m); if (i >= 0) modalStack.splice(i, 1);
        if (onClose) onClose(result);
      },
    };
    box.appendChild(h('div', { class: 'pje-modal-head' }, h('h2', null, title), head || null, h('div', { class: 'pje-spacer' }), h('button', { class: 'pje-btn small', onclick: () => m.close(null) }, '✕')));
    m.body = h('div', { class: 'pje-modal-body' }, body || null);
    box.appendChild(m.body);
    if (foot) { m.foot = h('div', { class: 'pje-modal-foot' }, foot); box.appendChild(m.foot); }
    overlay.addEventListener('mousedown', (e) => { if (e.target === overlay) m.close(null); });
    document.body.appendChild(overlay);
    modalStack.push(m);
    return m;
  }

  function confirmDialog(title, text, buttons) {
    return new Promise((resolve) => {
      let done = false;
      const m = openModal({ title, cls: '', body: h('div', { style: { maxWidth: '460px', lineHeight: '1.5', whiteSpace: 'pre-wrap' } }, text),
        foot: buttons.map(([value, label, kind]) => h('button', { class: 'pje-btn ' + (kind || ''), onclick: () => { done = true; m.close(value); } }, label)),
        onClose: (v) => resolve(done ? v : null) });
    });
  }

  // Sélecteur d'ID (interrupteurs / variables / évents communs / dresseurs…)
  function pickFromList(title, items, current) {
    return new Promise((resolve) => {
      let chosen = null;
      const search = h('input', { class: 'pje-input', placeholder: 'Rechercher…' });
      const list = h('div', { class: 'pje-list', style: { border: '1px solid var(--pje-border)', borderRadius: '8px' } });
      const render = () => {
        list.textContent = '';
        const q = search.value.toLowerCase();
        items.filter((it) => !q || it.label.toLowerCase().includes(q)).slice(0, 800).forEach((it) => {
          const row = h('div', { class: 'pje-item' + (it.value === current ? ' active' : ''), onclick: () => { chosen = it; m.close(it.value); } }, h('span', null, it.label));
          list.appendChild(row);
          if (it.value === current) setTimeout(() => row.scrollIntoView({ block: 'center' }), 0);
        });
      };
      search.addEventListener('input', render);
      const m = openModal({ title, cls: 'pje-idpick', body: [search, list], onClose: (v) => resolve(chosen ? v : null) });
      render();
      setTimeout(() => search.focus(), 0);
    });
  }

  function idItems(names, min = 100) {
    const n = Math.max((names || []).length - 1, min);
    const out = [];
    for (let i = 1; i <= n; i++) out.push({ value: i, label: `${pad(i)} : ${(names && names[i]) || ''}` });
    return out;
  }

  // ---------------------------------------------------------------------------
  // Champs de formulaire
  // ---------------------------------------------------------------------------
  function selectEl(options, value, onchange, attrs = {}) {
    const s = h('select', { class: 'pje-select', ...attrs });
    options.forEach(([v, l]) => s.appendChild(h('option', { value: JSON.stringify(v), selected: JSON.stringify(v) === JSON.stringify(value) }, l)));
    s.addEventListener('change', () => onchange(JSON.parse(s.value)));
    return s;
  }
  function numberEl(value, onchange, min, max, attrs = {}) {
    const i = h('input', { class: 'pje-input num', type: 'number', value: value ?? 0, min, max, ...attrs });
    i.addEventListener('input', () => onchange(clamp(num(i.value, 0), min ?? -999999999, max ?? 999999999)));
    return i;
  }
  function idField(kind, value, onchange) {
    const names = kind === 'switch' ? S.ctx.switches : S.ctx.variables;
    const label = h('span', { class: 'pje-hint' }, names[value] || '');
    const input = numberEl(value, (v) => { label.textContent = names[v] || ''; onchange(v); }, 1, 99999);
    const btn = h('button', { class: 'pje-btn small', onclick: async () => {
      const v = await pickFromList(kind === 'switch' ? 'Choisir un interrupteur' : 'Choisir une variable', idItems(names), num(input.value, 1));
      if (v !== null) { input.value = v; label.textContent = names[v] || ''; onchange(v); }
    } }, '…');
    return h('div', { class: 'pje-row' }, input, btn, label);
  }
  function dbField(list, value, onchange, placeholder) {
    const dl = 'pje-dl-' + Math.random().toString(36).slice(2);
    const input = h('input', { class: 'pje-input', list: dl, value: value || '', placeholder, style: { width: '220px' } });
    const dlist = h('datalist', { id: dl }, (list || []).map((x) => h('option', { value: x.dbSymbol }, x.name !== x.dbSymbol ? x.name : null)));
    const label = h('span', { class: 'pje-hint' }, nameOf(list, value) !== value ? nameOf(list, value) : '');
    input.addEventListener('input', () => { onchange(input.value.trim()); const n = nameOf(list, input.value.trim()); label.textContent = n !== input.value.trim() ? n : ''; });
    const btn = h('button', { class: 'pje-btn small', onclick: async () => {
      const v = await pickFromList('Choisir', (list || []).map((x) => ({ value: x.dbSymbol, label: `${x.id !== undefined ? pad(x.id, 3) + ' : ' : ''}${x.name}${x.name !== x.dbSymbol ? ' (' + x.dbSymbol + ')' : ''}` })), input.value);
      if (v !== null) { input.value = v; onchange(v); const n = nameOf(list, v); label.textContent = n !== v ? n : ''; }
    } }, '…');
    return h('div', { class: 'pje-row' }, input, dlist, btn, label);
  }

  let audioPlayer = null;
  function audioField(folder, value, onchange) {
    const v = value || defaultAudio();
    const files = (S.ctx.audio[folder] || []).map((f) => f.replace(/\.[^.\/]+$/, ''));
    const uniq = [...new Set(files)];
    const sel = selectEl([['', '(aucun)'], ...uniq.map((f) => [f, f])], v.name, (n) => { v.name = n; onchange(v); });
    const vol = numberEl(v.volume, (n) => { v.volume = n; onchange(v); }, 0, 100);
    const pit = numberEl(v.pitch, (n) => { v.pitch = n; onchange(v); }, 50, 150);
    const play = h('button', { class: 'pje-btn small', onclick: () => {
      if (audioPlayer) { audioPlayer.pause(); audioPlayer = null; return; }
      const file = (S.ctx.audio[folder] || []).find((f) => f.replace(/\.[^.\/]+$/, '') === v.name);
      if (!file) return;
      audioPlayer = new Audio(projectUrl(`Audio/${folder.toUpperCase()}/${file}`, 'audio'));
      audioPlayer.volume = clamp((v.volume ?? 100) / 100, 0, 1);
      audioPlayer.playbackRate = clamp((v.pitch ?? 100) / 100, 0.5, 1.5);
      audioPlayer.play().catch(() => toast('Lecture impossible (format non pris en charge ?)', true));
      audioPlayer.onended = () => { audioPlayer = null; };
    } }, '▶ / ■');
    return h('div', { class: 'pje-row' }, sel, h('span', { class: 'pje-hint' }, 'Vol.'), vol, h('span', { class: 'pje-hint' }, 'Tempo'), pit, play);
  }

  function operandField(op, onchange, allowRandom) {
    const wrap = h('div', { class: 'pje-row' });
    const render = () => {
      wrap.textContent = '';
      const types = [['constant', 'Constante'], ['variable', 'Variable']];
      if (allowRandom) types.push(['random', 'Aléatoire']);
      wrap.appendChild(selectEl(types, op.type, (t) => {
        Object.keys(op).forEach((k) => delete op[k]);
        op.type = t;
        if (t === 'constant') op.value = 0; else if (t === 'variable') op.id = 1; else { op.min = 0; op.max = 10; }
        onchange(op); render();
      }));
      if (op.type === 'constant') wrap.appendChild(numberEl(op.value, (v) => { op.value = v; onchange(op); }, -99999999, 99999999));
      else if (op.type === 'variable') wrap.appendChild(idField('variable', op.id, (v) => { op.id = v; onchange(op); }));
      else {
        wrap.appendChild(numberEl(op.min, (v) => { op.min = v; onchange(op); }, -99999999, 99999999));
        wrap.appendChild(h('span', null, 'à'));
        wrap.appendChild(numberEl(op.max, (v) => { op.max = v; onchange(op); }, -99999999, 99999999));
      }
    };
    render();
    return wrap;
  }

  function conditionField(cond, onchange, env) {
    const wrap = h('div', { style: { display: 'flex', flexDirection: 'column', gap: '8px' } });
    const render = () => {
      wrap.textContent = '';
      const types = [['switch', 'Interrupteur'], ['variable', 'Variable'], ['selfSwitch', 'Interrupteur local'], ['facing', 'Direction d\'un personnage'], ['script', 'Script Ruby']];
      wrap.appendChild(selectEl(types, cond.type, (t) => {
        Object.keys(cond).forEach((k) => delete cond[k]);
        cond.type = t;
        if (t === 'switch') Object.assign(cond, { id: 1, value: true });
        if (t === 'variable') Object.assign(cond, { id: 1, operator: '==', operand: { type: 'constant', value: 0 } });
        if (t === 'selfSwitch') Object.assign(cond, { ch: 'A', value: true });
        if (t === 'facing') Object.assign(cond, { target: -1, direction: 2 });
        if (t === 'script') cond.code = '';
        onchange(cond); render();
      }));
      if (cond.type === 'switch') wrap.appendChild(h('div', { class: 'pje-row' }, idField('switch', cond.id, (v) => { cond.id = v; }), h('span', null, 'est'), selectEl([[true, 'ON'], [false, 'OFF']], cond.value, (v) => { cond.value = v; })));
      if (cond.type === 'variable') {
        wrap.appendChild(idField('variable', cond.id, (v) => { cond.id = v; }));
        wrap.appendChild(h('div', { class: 'pje-row' }, selectEl(OPERATORS, cond.operator, (v) => { cond.operator = v; }), operandField(cond.operand, () => {}, false)));
      }
      if (cond.type === 'selfSwitch') wrap.appendChild(h('div', { class: 'pje-row' }, selectEl(SELF, cond.ch, (v) => { cond.ch = v; }), h('span', null, 'est'), selectEl([[true, 'ON'], [false, 'OFF']], cond.value, (v) => { cond.value = v; })));
      if (cond.type === 'facing') wrap.appendChild(h('div', { class: 'pje-row' }, targetField(cond.target, (v) => { cond.target = v; }, env), h('span', null, 'regarde vers'), selectEl(DIRS, cond.direction, (v) => { cond.direction = v; })));
      if (cond.type === 'script') {
        const ta = h('textarea', { class: 'pje-textarea', style: { minHeight: '70px' } }); ta.value = cond.code || '';
        ta.addEventListener('input', () => { cond.code = ta.value; });
        wrap.appendChild(ta);
      }
    };
    render();
    return wrap;
  }

  function targetField(value, onchange, env, noPlayer) {
    const opts = [];
    if (!noPlayer) opts.push([-1, 'Joueur']);
    opts.push([0, 'Cet évent']);
    ((env && env.events) || []).forEach((e) => opts.push([e.id, `#${pad(e.id, 3)} ${e.name}`]));
    if (!opts.some((o) => o[0] === value)) opts.push([value, `#${pad(value, 3)}`]);
    const input = numberEl(value, (v) => { onchange(v); }, -1, 9999, { title: 'ID' });
    const sel = selectEl(opts, value, (v) => { input.value = v; onchange(v); });
    return h('div', { class: 'pje-row' }, sel, input);
  }

  function choicesField(cmd) {
    const wrap = h('div', { style: { display: 'flex', flexDirection: 'column', gap: '6px' } });
    const render = () => {
      wrap.textContent = '';
      cmd.choices.forEach((ch, i) => {
        const inp = h('input', { class: 'pje-input', value: ch.text, style: { flex: '1' } });
        inp.addEventListener('input', () => { ch.text = inp.value; });
        wrap.appendChild(h('div', { class: 'pje-row' }, h('span', { class: 'pje-hint', style: { width: '18px' } }, String(i + 1)), inp,
          h('button', { class: 'pje-btn small', disabled: i === 0, onclick: () => { cmd.choices.splice(i - 1, 0, cmd.choices.splice(i, 1)[0]); render(); } }, '↑'),
          h('button', { class: 'pje-btn small danger', disabled: cmd.choices.length <= 1, onclick: () => { cmd.choices.splice(i, 1); render(); } }, '✕')));
      });
      wrap.appendChild(h('div', { class: 'pje-row' },
        h('button', { class: 'pje-btn small', disabled: cmd.choices.length >= 8, onclick: () => { cmd.choices.push({ text: `Choix ${cmd.choices.length + 1}`, commands: [] }); render(); } }, '+ Ajouter un choix')));
      const cancelOpts = [['disallow', 'Interdite'], ...cmd.choices.map((c, i) => [i + 1, `= choix ${i + 1}`]), ['branch', 'Branche spéciale']];
      wrap.appendChild(h('div', { class: 'pje-row' }, h('span', { class: 'pje-hint' }, 'Annulation (touche retour) :'),
        selectEl(cancelOpts, cmd.cancel, (v) => { cmd.cancel = v; })));
    };
    render();
    return wrap;
  }

  function positionField(cmd, onrender) {
    const label = h('span', null, `${mapLabel(cmd.mapId)} — X ${cmd.x}, Y ${cmd.y}`);
    const btn = h('button', { class: 'pje-btn', onclick: async () => {
      const r = await pickPosition(cmd.mapId, cmd.x, cmd.y, true);
      if (r) { Object.assign(cmd, r); label.textContent = `${mapLabel(cmd.mapId)} — X ${cmd.x}, Y ${cmd.y}`; }
    } }, 'Choisir sur la carte…');
    return h('div', { class: 'pje-row' }, label, btn);
  }

  function xyField(cmd) {
    const label = h('span', null, `X ${cmd.x}, Y ${cmd.y}`);
    const btn = h('button', { class: 'pje-btn', onclick: async () => {
      const r = await pickPosition(S.mapId, cmd.x, cmd.y, false);
      if (r) { cmd.x = r.x; cmd.y = r.y; label.textContent = `X ${cmd.x}, Y ${cmd.y}`; }
    } }, 'Choisir sur la carte…');
    return h('div', { class: 'pje-row' }, label, btn);
  }

  // Formulaire d'une commande -> Promise<cmd|null>
  function editCommand(cmd, env) {
    const def = CMDS[cmd.klass];
    if (!def) return Promise.resolve(null);
    const draft = clone(cmd);
    if (!def.fields.length) return Promise.resolve(draft);
    return new Promise((resolve) => {
      let ok = false;
      const form = h('div', { class: 'pje-form', style: { width: '640px' } });
      def.fields.forEach((f) => {
        let input;
        const set = (v) => { draft[f.key] = v; };
        switch (f.type) {
          case 'text': input = h('input', { class: 'pje-input', value: draft[f.key] || '' }); input.addEventListener('input', () => set(input.value)); break;
          case 'textarea': case 'code': {
            input = h('textarea', { class: 'pje-textarea', style: f.type === 'code' ? { minHeight: '220px' } : {} });
            input.value = draft[f.key] || '';
            input.addEventListener('input', () => set(input.value));
            input.addEventListener('keydown', (e) => { if (e.key === 'Tab' && f.type === 'code') { e.preventDefault(); const s = input.selectionStart; input.setRangeText('  ', s, input.selectionEnd, 'end'); set(input.value); } });
            setTimeout(() => input.focus(), 0);
            break;
          }
          case 'number': input = numberEl(draft[f.key], set, f.min, f.max); break;
          case 'checkbox': {
            const c = h('input', { type: 'checkbox', checked: !!draft[f.key] }); c.addEventListener('change', () => set(c.checked));
            input = h('label', { class: 'pje-check' }, c, f.text || ''); break;
          }
          case 'select': input = selectEl(f.options, draft[f.key], set); break;
          case 'switch': input = idField('switch', draft[f.key], (v) => { set(v); if (f.key === 'from' && draft.to < v) draft.to = v; }); break;
          case 'variable': input = idField('variable', draft[f.key], (v) => { set(v); if (f.key === 'from' && draft.to < v) draft.to = v; }); break;
          case 'commonEvent': {
            const items = commonItems();
            input = h('div', { class: 'pje-row' });
            const lbl = h('span', null, commonLabel(draft.id));
            input.append(lbl, h('button', { class: 'pje-btn small', onclick: async () => { const v = await pickFromList('Évent commun', items, draft.id); if (v !== null) { draft.id = v; lbl.textContent = commonLabel(v); } } }, '…'));
            break;
          }
          case 'pokemon': input = dbField(S.ctx.pokemon, draft[f.key], set, 'ex. bulbasaur'); break;
          case 'item': input = dbField(S.ctx.items, draft[f.key], set, 'ex. potion'); break;
          case 'shop': input = dbField(S.ctx.shops, draft[f.key], set, 'ex. shop_1'); break;
          case 'trainer': {
            input = h('div', { class: 'pje-row' });
            const n = numberEl(draft.trainerId, (v) => { draft.trainerId = v; lbl.textContent = trainerLabel(v); }, 1, 99999);
            const lbl = h('span', { class: 'pje-hint' }, trainerLabel(draft.trainerId));
            input.append(n, h('button', { class: 'pje-btn small', onclick: async () => {
              const v = await pickFromList('Dresseur', S.ctx.trainers.map((t) => ({ value: t.id, label: `${pad(t.id, 3)} : ${t.name}` })), draft.trainerId);
              if (v !== null) { draft.trainerId = v; n.value = v; lbl.textContent = trainerLabel(v); }
            } }, '…'), lbl);
            break;
          }
          case 'audio': input = audioField(f.folder, draft[f.key], set); break;
          case 'operand': input = operandField(draft[f.key], set, f.random); break;
          case 'condition': input = conditionField(draft.condition, () => {}, env); break;
          case 'elseToggle': {
            const c = h('input', { type: 'checkbox', checked: Array.isArray(draft.elseCommands) });
            c.addEventListener('change', () => { draft.elseCommands = c.checked ? (cmd.elseCommands || []) : null; });
            input = h('label', { class: 'pje-check' }, c, 'Ajouter une branche « Sinon »'); break;
          }
          case 'choices': input = choicesField(draft); break;
          case 'position': input = positionField(draft); break;
          case 'xy': input = xyField(draft); break;
          case 'target': input = targetField(draft[f.key], set, env, f.noPlayer); break;
          case 'route': {
            const lbl = h('span', { class: 'pje-hint' }, routeSummary(draft.route));
            input = h('div', { class: 'pje-row' }, h('button', { class: 'pje-btn', onclick: async () => {
              const r = await editRoute(draft.route, true);
              if (r) { draft.route = r; lbl.textContent = routeSummary(r); }
            } }, 'Modifier la route…'), lbl);
            break;
          }
          case 'json': {
            input = h('textarea', { class: 'pje-textarea', style: { minHeight: '260px' } });
            input.value = JSON.stringify(draft[f.key], null, 1);
            input.addEventListener('input', () => { try { set(JSON.parse(input.value)); input.style.borderColor = ''; } catch (e) { input.style.borderColor = 'var(--pje-danger)'; } });
            break;
          }
          default: input = h('span', null, '?');
        }
        form.appendChild(h('label', null, f.label));
        form.appendChild(f.hint ? h('div', null, input, h('div', { class: 'pje-hint', style: { marginTop: '4px' } }, f.hint)) : input);
      });
      if (def.hint) { form.appendChild(h('span')); form.appendChild(h('div', { class: 'pje-hint' }, def.hint)); }
      const m = openModal({ title: def.label, body: form,
        foot: [h('button', { class: 'pje-btn', onclick: () => m.close(null) }, 'Annuler'), h('button', { class: 'pje-btn primary', onclick: () => { ok = true; m.close(draft); } }, 'OK')],
        onClose: (v) => { if (audioPlayer) { audioPlayer.pause(); audioPlayer = null; } resolve(ok ? v : null); } });
      m.el.addEventListener('keydown', (e) => { if (e.key === 'Enter' && e.ctrlKey) { ok = true; m.close(draft); } });
    });
  }

  function commonItems() {
    const ids = new Set();
    const items = [];
    ((S.common && S.common.data && S.common.data.events) || []).forEach((e) => { ids.add(e.id); items.push({ value: e.id, label: `${pad(e.id, 3)} : ${e.name}` }); });
    ((S.common && S.common.rmxp) || []).forEach((e) => { if (!ids.has(e.id)) items.push({ value: e.id, label: `${pad(e.id, 3)} : ${e.name} (RPG Maker)` }); });
    return items.sort((a, b) => a.value - b.value);
  }

  // Choix de la commande à insérer -> Promise<klass|null>
  function pickCommand() {
    return new Promise((resolve) => {
      let chosen = null;
      const grid = h('div', { class: 'pje-cats' }, CATS.map((cat) => h('div', { class: 'pje-cat' },
        h('h4', null, cat),
        Object.entries(CMDS).filter(([, d]) => d.cat === cat).map(([k, d]) =>
          h('button', { class: 'pje-btn', onclick: () => { chosen = k; m.close(k); } }, h('span', { class: 'k-' + d.kind }, '● '), d.label)))));
      const m = openModal({ title: 'Insérer une commande', cls: 'pje-picker', body: grid, onClose: () => resolve(chosen) });
    });
  }

  // ---------------------------------------------------------------------------
  // Liste de commandes (arbre)
  // ---------------------------------------------------------------------------
  let cmdClipboard = null;

  function buildRows(list, depth, rows) {
    list.forEach((cmd, index) => {
      rows.push({ type: 'cmd', list, index, depth, cmd });
      switch (cmd.klass) {
        case 'ConditionalBranch':
          buildRows(cmd.commands, depth + 1, rows);
          if (Array.isArray(cmd.elseCommands)) { rows.push({ type: 'label', depth, text: ': Sinon', kind: 'flow' }); buildRows(cmd.elseCommands, depth + 1, rows); }
          rows.push({ type: 'label', depth, text: ': Fin de la condition', kind: 'flow' });
          break;
        case 'ShowChoices':
          cmd.choices.forEach((ch) => { rows.push({ type: 'label', depth, text: `: Si « ${ch.text} »`, kind: 'msg' }); buildRows(ch.commands, depth + 1, rows); });
          if (cmd.cancel === 'branch') { rows.push({ type: 'label', depth, text: ': Si annulation', kind: 'msg' }); buildRows(cmd.cancelCommands, depth + 1, rows); }
          rows.push({ type: 'label', depth, text: ': Fin des choix', kind: 'msg' });
          break;
        case 'Loop':
          buildRows(cmd.commands, depth + 1, rows);
          rows.push({ type: 'label', depth, text: ': Répéter ↑', kind: 'flow' });
          break;
        default:
      }
    });
    rows.push({ type: 'ins', list, index: list.length, depth });
    return rows;
  }

  function describeCmd(cmd) {
    const def = CMDS[cmd.klass];
    if (!def) return { kind: 'raw', head: cmd.klass, tail: '' };
    const [head, tail] = def.describe(cmd);
    return { kind: def.kind, head, tail };
  }

  // Composant liste de commandes. getList() renvoie le tableau racine (muté sur place).
  function commandList(getList, onChange, env, before = () => {}) {
    const box = h('div', { class: 'pje-cmds', tabindex: '0' });
    let rows = [];
    let sel = 0;
    const render = () => {
      rows = buildRows(getList(), 0, []);
      sel = clamp(sel, 0, rows.length - 1);
      box.textContent = '';
      rows.forEach((r, i) => {
        const indent = '  '.repeat(r.depth);
        let line;
        if (r.type === 'cmd') {
          const d = describeCmd(r.cmd);
          line = h('div', { class: 'pje-cmd' + (i === sel ? ' sel' : '') }, indent + '◆ ', h('span', { class: 'k-' + d.kind }, d.head), d.tail ? ' : ' + d.tail : '');
        } else if (r.type === 'label') {
          line = h('div', { class: 'pje-cmd lbl' + (i === sel ? ' sel' : '') }, indent, h('span', { class: 'k-' + r.kind }, r.text));
        } else {
          line = h('div', { class: 'pje-cmd ins' + (i === sel ? ' sel' : '') }, indent + '◆');
        }
        line.addEventListener('mousedown', () => { setSel(i); box.focus(); });
        line.addEventListener('dblclick', () => { sel = i; activate(); });
        box.appendChild(line);
      });
      const el = box.children[sel]; if (el && el.scrollIntoViewIfNeeded) el.scrollIntoViewIfNeeded(false);
    };
    const setSel = (i) => {
      const prev = box.children[sel]; if (prev) prev.classList.remove('sel');
      sel = clamp(i, 0, rows.length - 1);
      const el = box.children[sel]; if (el) { el.classList.add('sel'); if (el.scrollIntoViewIfNeeded) el.scrollIntoViewIfNeeded(false); }
    };
    const target = () => {
      let r = rows[sel];
      if (r && r.type === 'label') { for (let j = sel + 1; j < rows.length; j++) if (rows[j].type !== 'label') { r = rows[j]; break; } }
      return r;
    };
    const changed = () => { onChange(); render(); };
    const insert = async () => {
      const r = target(); if (!r || !r.list) return;
      const klass = await pickCommand(); if (!klass) return;
      const cmd = await editCommand(CMDS[klass].make(), env()); if (!cmd) { box.focus(); return; }
      before();
      r.list.splice(r.index, 0, cmd);
      sel = rows.indexOf(r) + 1;
      changed();
      sel = Math.min(sel, rows.length - 1);
      box.focus();
    };
    const edit = async () => {
      const r = rows[sel]; if (!r || r.type !== 'cmd') return;
      const res = await editCommand(r.cmd, env());
      if (res) { before(); r.list[r.index] = res; changed(); }
      box.focus();
    };
    const activate = () => { const r = rows[sel]; if (!r) return; if (r.type === 'cmd' && CMDS[r.cmd.klass] && CMDS[r.cmd.klass].fields.length) edit(); else insert(); };
    const remove = () => { const r = rows[sel]; if (!r || r.type !== 'cmd') return; before(); r.list.splice(r.index, 1); changed(); };
    const copy = () => { const r = rows[sel]; if (r && r.type === 'cmd') { cmdClipboard = clone(r.cmd); toast('Commande copiée'); } };
    const paste = () => { const r = target(); if (!r || !r.list || !cmdClipboard) return; before(); r.list.splice(r.index, 0, clone(cmdClipboard)); changed(); };
    const move = (d) => {
      const r = rows[sel]; if (!r || r.type !== 'cmd') return;
      const j = r.index + d; if (j < 0 || j >= r.list.length) return;
      before();
      const [c] = r.list.splice(r.index, 1); r.list.splice(j, 0, c);
      onChange(); rows = buildRows(getList(), 0, []);
      sel = rows.findIndex((x) => x.type === 'cmd' && x.cmd === c); render();
    };
    box.addEventListener('keydown', (e) => {
      if (e.target !== box) return;
      const k = e.key;
      if (k === 'ArrowDown' && !e.altKey) setSel(sel + 1);
      else if (k === 'ArrowUp' && !e.altKey) setSel(sel - 1);
      else if (k === 'ArrowUp' && e.altKey) move(-1);
      else if (k === 'ArrowDown' && e.altKey) move(1);
      else if (k === 'Enter' || k === ' ') activate();
      else if (k === 'Insert') insert();
      else if (k === 'Delete' || k === 'Backspace') remove();
      else if (e.ctrlKey && k.toLowerCase() === 'c') copy();
      else if (e.ctrlKey && k.toLowerCase() === 'x') { copy(); remove(); }
      else if (e.ctrlKey && k.toLowerCase() === 'v') paste();
      else return;
      e.preventDefault(); e.stopPropagation();
    });
    const bar = h('div', { class: 'pje-cmdbar' },
      h('button', { class: 'pje-btn small primary', onclick: insert, title: 'Insérer (Entrée sur ◆ / Inser)' }, '+ Insérer'),
      h('button', { class: 'pje-btn small', onclick: edit, title: 'Modifier (Entrée / double-clic)' }, 'Modifier'),
      h('button', { class: 'pje-btn small', onclick: () => move(-1), title: 'Alt+↑' }, '↑'),
      h('button', { class: 'pje-btn small', onclick: () => move(1), title: 'Alt+↓' }, '↓'),
      h('button', { class: 'pje-btn small', onclick: copy, title: 'Ctrl+C' }, 'Copier'),
      h('button', { class: 'pje-btn small', onclick: paste, title: 'Ctrl+V' }, 'Coller'),
      h('button', { class: 'pje-btn small danger', onclick: remove, title: 'Suppr' }, 'Supprimer'),
      h('span', { class: 'pje-spacer' }),
      h('span', { class: 'pje-hint' }, 'Double-clic sur ◆ pour insérer'));
    render();
    return { bar, box, render, el: h('div', { style: { display: 'flex', flexDirection: 'column', flex: '1', minHeight: '0' } }, bar, box) };
  }

  // ---------------------------------------------------------------------------
  // Éditeur de route
  // ---------------------------------------------------------------------------
  function editRoute(route, withOptions) {
    const r = clone(route || { repeat: true, skippable: false, commands: [] });
    return new Promise((resolve) => {
      let ok = false;
      let sel = r.commands.length;
      const list = h('div', { class: 'pje-cmds', tabindex: '0' });
      const params = h('div', { class: 'pje-row' });
      const render = () => {
        list.textContent = '';
        [...r.commands, null].forEach((mc, i) => {
          const row = h('div', { class: 'pje-cmd' + (i === sel ? ' sel' : '') + (mc ? '' : ' ins') }, mc ? '◆ ' + moveLabel(mc) : '◆');
          row.addEventListener('mousedown', () => { sel = i; render(); list.focus(); });
          list.appendChild(row);
        });
        params.textContent = '';
        const mc = r.commands[sel];
        const info = mc && moveInfo(mc.code);
        if (info && info[2]) {
          info[2].forEach(([t, label, def], pi) => {
            if (mc.parameters[pi] === undefined) mc.parameters[pi] = t === 'se' ? { __rpg: 'AudioFile', name: '', volume: 80, pitch: 100 } : def;
            params.appendChild(h('span', { class: 'pje-hint' }, label));
            if (t === 'n') params.appendChild(numberEl(mc.parameters[pi], (v) => { mc.parameters[pi] = v; refreshLabels(); }, -9999, 99999));
            else if (t === 'se') params.appendChild(audioField('se', mc.parameters[pi], (v) => { mc.parameters[pi] = { __rpg: 'AudioFile', ...v }; refreshLabels(); }));
            else { const i = h('input', { class: 'pje-input', value: mc.parameters[pi] }); i.addEventListener('input', () => { mc.parameters[pi] = i.value; refreshLabels(); }); params.appendChild(i); }
          });
        }
      };
      const refreshLabels = () => { [...list.children].forEach((row, i) => { const mc = r.commands[i]; if (mc) row.textContent = '◆ ' + moveLabel(mc); }); };
      list.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowDown') sel = Math.min(r.commands.length, sel + 1);
        else if (e.key === 'ArrowUp') sel = Math.max(0, sel - 1);
        else if (e.key === 'Delete' || e.key === 'Backspace') { if (sel < r.commands.length) r.commands.splice(sel, 1); }
        else return;
        e.preventDefault(); e.stopPropagation(); render();
      });
      const palette = h('div', { class: 'right' }, MOVES.map(([code, label]) => h('button', { class: 'pje-btn small', style: { textAlign: 'left' }, onclick: () => {
        r.commands.splice(sel, 0, { code, parameters: [] }); sel++; render(); list.focus();
      } }, label)));
      const opts = withOptions ? h('div', { class: 'pje-row' },
        h('label', { class: 'pje-check' }, (() => { const c = h('input', { type: 'checkbox', checked: r.repeat }); c.addEventListener('change', () => { r.repeat = c.checked; }); return c; })(), 'Répéter'),
        h('label', { class: 'pje-check' }, (() => { const c = h('input', { type: 'checkbox', checked: r.skippable }); c.addEventListener('change', () => { r.skippable = c.checked; }); return c; })(), 'Ignorer si bloqué')) : null;
      const left = h('div', { class: 'left' }, opts, list, params,
        h('div', { class: 'pje-row' },
          h('button', { class: 'pje-btn small', onclick: () => { if (sel > 0 && sel < r.commands.length) { r.commands.splice(sel - 1, 0, r.commands.splice(sel, 1)[0]); sel--; render(); } } }, '↑'),
          h('button', { class: 'pje-btn small', onclick: () => { if (sel < r.commands.length - 1) { r.commands.splice(sel + 1, 0, r.commands.splice(sel, 1)[0]); sel++; render(); } } }, '↓'),
          h('button', { class: 'pje-btn small danger', onclick: () => { if (sel < r.commands.length) { r.commands.splice(sel, 1); render(); } } }, 'Supprimer'),
          h('button', { class: 'pje-btn small danger', onclick: () => { r.commands = []; sel = 0; render(); } }, 'Tout effacer')));
      openModal({ title: 'Route de déplacement', cls: 'pje-route', body: [left, palette],
        foot: [h('button', { class: 'pje-btn', onclick: (e) => e.target.closest('.pje-overlay').dispatchEvent(new MouseEvent('mousedown')) }, 'Annuler'),
          h('button', { class: 'pje-btn primary', onclick: () => { ok = true; modalStack[modalStack.length - 1].close(r); } }, 'OK')],
        onClose: (v) => resolve(ok ? v : null) });
      render();
    });
  }

  // ---------------------------------------------------------------------------
  // Choix d'une position sur une carte
  // ---------------------------------------------------------------------------
  function pickPosition(mapId, x, y, allowMapChange) {
    return new Promise((resolve) => {
      let ok = false;
      const res = { mapId, x, y };
      const view = h('div', { class: 'pje-mapwrap' });
      const info = h('span', { class: 'pje-hint' });
      const renderMap = () => {
        const map = S.ctx.maps.find((m) => m.id === res.mapId);
        view.textContent = '';
        info.textContent = map ? `${mapLabel(map.id)} — X ${res.x}, Y ${res.y}` : 'Carte inconnue';
        if (!map) return;
        const T = 16 * S.zoom;
        const el = h('div', { class: 'pje-map', style: { width: map.width * T + 'px', height: map.height * T + 'px', backgroundImage: map.overview ? `url("${projectUrl(map.overview)}")` : 'none' } },
          h('div', { class: 'pje-grid', style: { backgroundSize: `${T}px ${T}px` } }),
          h('div', { class: 'pje-cursor', style: { left: res.x * T + 'px', top: res.y * T + 'px', width: T + 'px', height: T + 'px' } }));
        el.addEventListener('mousedown', (e) => {
          const rect = el.getBoundingClientRect();
          res.x = clamp(Math.floor((e.clientX - rect.left) / T), 0, map.width - 1);
          res.y = clamp(Math.floor((e.clientY - rect.top) / T), 0, map.height - 1);
          renderMap();
        });
        el.addEventListener('dblclick', () => { ok = true; m.close(res); });
        view.appendChild(el);
      };
      const list = h('div', { class: 'pje-list' });
      const pickSearch = h('input', { class: 'pje-input', placeholder: 'Rechercher une carte…' });
      const fillPick = () => fillMapTree(list, { query: pickSearch.value, activeId: res.mapId, rerender: fillPick, onPick: (mp) => { res.mapId = mp.id; fillPick(); renderMap(); } });
      pickSearch.addEventListener('input', fillPick);
      fillPick();
      const listBox = h('div', { class: 'pje-pick-maps' }, pickSearch, list);
      const m = openModal({ title: 'Choisir une position', cls: 'pje-pospick', body: [allowMapChange ? listBox : null, view], head: info,
        foot: [h('span', { class: 'pje-hint' }, 'Clic : choisir la case — double-clic : valider'), h('span', { class: 'pje-spacer' }),
          h('button', { class: 'pje-btn', onclick: () => m.close(null) }, 'Annuler'), h('button', { class: 'pje-btn primary', onclick: () => { ok = true; m.close(res); } }, 'OK')],
        onClose: (v) => resolve(ok ? v : null) });
      renderMap();
    });
  }

  // ---------------------------------------------------------------------------
  // Choix d'apparence (charset)
  // ---------------------------------------------------------------------------
  function pickCharacter(graphic) {
    return new Promise((resolve) => {
      let ok = false;
      const g = clone(graphic);
      const search = h('input', { class: 'pje-input', placeholder: 'Rechercher un charset…', style: { margin: '8px', width: 'calc(100% - 16px)' } });
      const list = h('div', { class: 'pje-list' });
      const sheet = h('div', { class: 'pje-sheet' });
      const renderSheet = async () => {
        sheet.textContent = '';
        if (!g.characterName) { sheet.appendChild(h('div', { class: 'pje-empty' }, 'Aucune apparence : évent invisible.')); return; }
        const img = await loadImage(`Graphics/Characters/${g.characterName}.png`);
        if (!img) { sheet.appendChild(h('div', { class: 'pje-error' }, 'Image introuvable')); return; }
        const sc = img.width > 300 ? 1 : 2;
        const c = h('canvas', { width: img.width * sc, height: img.height * sc });
        const cx = c.getContext('2d'); cx.imageSmoothingEnabled = false;
        cx.drawImage(img, 0, 0, c.width, c.height);
        const fw = c.width / 4, fh = c.height / 4;
        const row = { 2: 0, 4: 1, 6: 2, 8: 3 }[g.direction] ?? 0;
        cx.strokeStyle = '#7d6ff5'; cx.lineWidth = 3; cx.strokeRect(g.pattern * fw + 1.5, row * fh + 1.5, fw - 3, fh - 3);
        c.addEventListener('mousedown', (e) => {
          const rect = c.getBoundingClientRect();
          g.pattern = clamp(Math.floor((e.clientX - rect.left) / fw), 0, 3);
          g.direction = [2, 4, 6, 8][clamp(Math.floor((e.clientY - rect.top) / fh), 0, 3)];
          renderSheet();
        });
        sheet.append(h('div', { class: 'pje-hint', style: { marginBottom: '8px' } }, 'Clique sur une frame : la ligne donne la direction, la colonne le motif.'), c);
      };
      const renderList = () => {
        list.textContent = '';
        const q = search.value.toLowerCase();
        ['', ...S.ctx.characters].filter((n) => !q || n.toLowerCase().includes(q)).forEach((n) => {
          list.appendChild(h('div', { class: 'pje-item' + (n === g.characterName ? ' active' : ''), onclick: () => { g.characterName = n; g.tileId = 0; renderList(); renderSheet(); } }, n || '(Aucune)'));
        });
      };
      search.addEventListener('input', renderList);
      const m = openModal({ title: 'Apparence', cls: 'pje-charpick', body: [h('div', { style: { display: 'flex', flexDirection: 'column', width: '280px', borderRight: '1px solid var(--pje-border)' } }, search, list), sheet],
        foot: [h('button', { class: 'pje-btn', onclick: () => m.close(null) }, 'Annuler'), h('button', { class: 'pje-btn primary', onclick: () => { ok = true; m.close(g); } }, 'OK')],
        onClose: (v) => resolve(ok ? v : null) });
      renderList(); renderSheet();
      const act = list.querySelector('.active'); if (act) act.scrollIntoView({ block: 'center' });
    });
  }

  // ---------------------------------------------------------------------------
  // Dialogue d'édition d'un évent de carte
  // ---------------------------------------------------------------------------
  let pageClipboard = null;
  function openEventDialog(event, env) {
    return new Promise((resolve) => {
      const ev = clone(event);
      let pageIndex = 0;
      let ok = false;
      const pagesBar = h('div', { class: 'pje-pages' });
      const body = h('div', { class: 'pje-evbody' });
      const name = h('input', { class: 'pje-input', value: ev.name, style: { width: '200px' } });
      name.addEventListener('input', () => { ev.name = name.value; });
      const xIn = numberEl(ev.x, (v) => { ev.x = v; }, 0, 999);
      const yIn = numberEl(ev.y, (v) => { ev.y = v; }, 0, 999);

      const renderPages = () => {
        pagesBar.textContent = '';
        ev.pages.forEach((p, i) => pagesBar.appendChild(h('button', { class: 'pje-page-tab' + (i === pageIndex ? ' active' : ''), onclick: () => { pageIndex = i; renderAll(); } }, String(i + 1))));
        pagesBar.append(
          h('span', { style: { width: '12px' } }),
          h('button', { class: 'pje-btn small', onclick: () => { ev.pages.push(newPage()); pageIndex = ev.pages.length - 1; renderAll(); } }, '+ Nouvelle page'),
          h('button', { class: 'pje-btn small', onclick: () => { pageClipboard = clone(ev.pages[pageIndex]); toast('Page copiée'); } }, 'Copier la page'),
          h('button', { class: 'pje-btn small', disabled: !pageClipboard, onclick: () => { ev.pages.splice(pageIndex + 1, 0, clone(pageClipboard)); pageIndex++; renderAll(); } }, 'Coller la page'),
          h('button', { class: 'pje-btn small danger', disabled: ev.pages.length <= 1, onclick: () => { ev.pages.splice(pageIndex, 1); pageIndex = Math.max(0, pageIndex - 1); renderAll(); } }, 'Supprimer la page'),
          h('span', { class: 'pje-spacer' }),
          h('span', { class: 'pje-hint' }, 'La dernière page dont les conditions sont remplies est active.'));
      };

      const check = (label, obj, key, onchange) => {
        const c = h('input', { type: 'checkbox', checked: !!obj[key] });
        c.addEventListener('change', () => { obj[key] = c.checked; if (onchange) onchange(); });
        return h('label', { class: 'pje-check' }, c, label);
      };

      const renderBody = () => {
        body.textContent = '';
        const page = ev.pages[pageIndex];
        const cond = page.conditions;
        // Conditions
        const condBox = h('div', { class: 'pje-box' }, h('div', { class: 't' }, 'Conditions'));
        const condRow = (label, active, onToggle, content) => {
          const c = h('input', { type: 'checkbox', checked: active });
          const holder = h('div', { style: { marginLeft: '24px', display: active ? '' : 'none' } }, content);
          c.addEventListener('change', () => { onToggle(c.checked); holder.style.display = c.checked ? '' : 'none'; });
          condBox.append(h('label', { class: 'pje-check' }, c, label), holder);
        };
        condRow('Interrupteur', cond.switch1 !== null, (v) => { cond.switch1 = v ? (cond.switch1 || 1) : null; }, idField('switch', cond.switch1 || 1, (v) => { cond.switch1 = v; }));
        condRow('Interrupteur', cond.switch2 !== null, (v) => { cond.switch2 = v ? (cond.switch2 || 1) : null; }, idField('switch', cond.switch2 || 1, (v) => { cond.switch2 = v; }));
        const varCond = cond.variable || { id: 1, value: 0 };
        condRow('Variable', cond.variable !== null, (v) => { cond.variable = v ? varCond : null; },
          h('div', null, idField('variable', varCond.id, (v) => { varCond.id = v; }), h('div', { class: 'pje-row', style: { marginTop: '4px' } }, h('span', null, '≥'), numberEl(varCond.value, (v) => { varCond.value = v; }, -99999999, 99999999))));
        condRow('Interrupteur local', cond.selfSwitch !== null, (v) => { cond.selfSwitch = v ? (cond.selfSwitch || 'A') : null; }, selectEl(SELF, cond.selfSwitch || 'A', (v) => { cond.selfSwitch = v; }));

        // Apparence
        const g = page.graphic;
        const prevCanvas = h('canvas');
        const preview = h('div', { class: 'pje-preview', title: "Changer l'apparence", onclick: async () => {
          const r = await pickCharacter(g); if (r) { Object.assign(g, r); renderBody(); }
        } }, prevCanvas);
        drawCharacter(prevCanvas, g, 2).then((okDraw) => { if (!okDraw) preview.appendChild(h('span', { class: 'pje-hint' }, g.characterName ? 'Introuvable' : '(Aucune)')); });
        const gBox = h('div', { class: 'pje-box' }, h('div', { class: 't' }, 'Apparence'),
          h('div', { class: 'pje-row', style: { alignItems: 'flex-start' } }, preview,
            h('div', { style: { display: 'flex', flexDirection: 'column', gap: '6px' } },
              h('span', { class: 'pje-hint' }, g.characterName || '(Aucune)'),
              h('div', { class: 'pje-row' }, h('span', { class: 'pje-hint' }, 'Opacité'), numberEl(g.opacity, (v) => { g.opacity = v; }, 0, 255)),
              h('div', { class: 'pje-row' }, h('span', { class: 'pje-hint' }, 'Fusion'), selectEl([[0, 'Normale'], [1, 'Addition'], [2, 'Soustraction']], g.blendType, (v) => { g.blendType = v; })))));

        // Déplacement
        const routeLbl = h('span', { class: 'pje-hint' }, routeSummary(page.moveRoute));
        const routeBtn = h('button', { class: 'pje-btn small', onclick: async () => { const r = await editRoute(page.moveRoute, true); if (r) { page.moveRoute = r; routeLbl.textContent = routeSummary(r); } } }, 'Route…');
        const routeRow = h('div', { class: 'pje-row', style: { display: page.moveType === 'custom' ? '' : 'none' } }, routeBtn, routeLbl);
        const mBox = h('div', { class: 'pje-box' }, h('div', { class: 't' }, 'Déplacement automatique'),
          h('div', { class: 'pje-form', style: { gridTemplateColumns: '90px 1fr' } },
            h('label', null, 'Type'), selectEl(MOVE_TYPES, page.moveType, (v) => { page.moveType = v; routeRow.style.display = v === 'custom' ? '' : 'none'; }),
            h('label', null, 'Vitesse'), selectEl(SPEEDS, page.moveSpeed, (v) => { page.moveSpeed = v; }),
            h('label', null, 'Fréquence'), selectEl(FREQS, page.moveFrequency, (v) => { page.moveFrequency = v; })),
          routeRow);

        const oBox = h('div', { class: 'pje-box' }, h('div', { class: 't' }, 'Options'),
          check('Animation de marche', page, 'walkAnime'), check('Animation sur place', page, 'stepAnime'),
          check('Direction fixe', page, 'directionFix'), check('Traverser (pas de collision)', page, 'through'), check('Toujours au premier plan', page, 'alwaysOnTop'));
        const tBox = h('div', { class: 'pje-box' }, h('div', { class: 't' }, 'Déclencheur'), selectEl(TRIGGERS, page.trigger, (v) => { page.trigger = v; }));

        const left = h('div', { class: 'pje-evleft' }, condBox, gBox, mBox, oBox, tBox);
        const cl = commandList(() => page.commands, () => {}, () => env);
        const right = h('div', { class: 'pje-evright' }, cl.el);
        body.append(left, right);
        setTimeout(() => cl.box.focus(), 0);
      };
      const renderAll = () => { renderPages(); renderBody(); };

      const m = openModal({
        title: `Évent #${ev.id}`, cls: 'pje-evdlg',
        head: h('div', { class: 'pje-row' }, h('span', { class: 'pje-hint' }, 'Nom'), name, h('span', { class: 'pje-hint' }, 'X'), xIn, h('span', { class: 'pje-hint' }, 'Y'), yIn),
        body: [pagesBar, body],
        foot: [
          h('button', { class: 'pje-btn danger', onclick: async () => {
            const r = await confirmDialog('Supprimer', `Supprimer l'évent #${ev.id} « ${ev.name} » ?`, [[false, 'Annuler'], [true, 'Supprimer', 'primary']]);
            if (r) { ok = true; m.close({ deleted: true }); }
          } }, "Supprimer l'évent"),
          h('span', { class: 'pje-spacer' }),
          h('button', { class: 'pje-btn', onclick: () => m.close(null) }, 'Annuler'),
          h('button', { class: 'pje-btn primary', onclick: () => { ok = true; m.close({ event: ev }); } }, 'OK')],
        onClose: (v) => resolve(ok ? v : null),
      });
      m.body.style.padding = '0'; m.body.style.display = 'flex'; m.body.style.flexDirection = 'column';
      renderAll();
    });
  }

  // ---------------------------------------------------------------------------
  // Données : chargement / sauvegarde
  // ---------------------------------------------------------------------------
  const currentMap = () => S.ctx && S.ctx.maps.find((m) => m.id === S.mapId);
  const currentDoc = () => { const m = currentMap(); return m ? S.docs[m.dbSymbol] : null; };
  const isDirty = () => Object.values(S.docs).some((d) => d.dirty) || (S.common && S.common.dirty);

  function pushUndo(doc) {
    doc.undo.push(JSON.stringify(doc.data));
    if (doc.undo.length > 60) doc.undo.shift();
    doc.dirty = true;
  }
  function undo() {
    const doc = S.tab === 'maps' ? currentDoc() : S.common;
    if (!doc || !doc.undo.length) return toast('Rien à annuler');
    doc.data = JSON.parse(doc.undo.pop());
    doc.dirty = true;
    render();
  }

  async function loadMapDoc(map) {
    if (S.docs[map.dbSymbol]) return S.docs[map.dbSymbol];
    const data = (await call('readMapEvents', { projectPath: S.projectPath, dbSymbol: map.dbSymbol })) || { klass: 'MapEvents', mapId: map.id, mapDbSymbol: map.dbSymbol, events: [] };
    data.mapId = map.id;
    let rmxp = [];
    if (map.hasRmxp) {
      try { rmxp = await call('readRmxpEvents', { projectPath: S.projectPath, mapId: map.id }); } catch (e) { toast('Lecture des évents RPG Maker impossible : ' + e.message, true); }
    }
    S.docs[map.dbSymbol] = { data, rmxp, dirty: false, undo: [] };
    return S.docs[map.dbSymbol];
  }

  async function loadCommon() {
    if (S.common) return S.common;
    const data = (await call('readCommonEvents', { projectPath: S.projectPath })) || { klass: 'CommonEvents', events: [] };
    let rmxp = [];
    if (S.ctx.hasRmxpCommonEvents) { try { rmxp = await call('readRmxpCommonEvents', { projectPath: S.projectPath }); } catch (e) { toast('Lecture de CommonEvents.rxdata impossible : ' + e.message, true); } }
    S.common = { data, rmxp, dirty: false, undo: [] };
    return S.common;
  }

  let saving = false;
  async function saveAll(silent) {
    if (saving) return;
    saving = true;
    try {
      let n = 0;
      for (const [dbSymbol, doc] of Object.entries(S.docs)) {
        if (!doc.dirty) continue;
        doc.data.events.sort((a, b) => a.id - b.id);
        await call('saveMapEvents', { projectPath: S.projectPath, dbSymbol, data: doc.data });
        doc.dirty = false; n++;
        if (!S.ctx.eventMaps.includes(dbSymbol)) S.ctx.eventMaps.push(dbSymbol);
      }
      if (S.common && S.common.dirty) {
        S.common.data.events.sort((a, b) => a.id - b.id);
        await call('saveCommonEvents', { projectPath: S.projectPath, data: S.common.data });
        S.common.dirty = false; n++;
      }
      if (!silent) toast(n ? `Enregistré (${n} fichier${n > 1 ? 's' : ''})` : 'Rien à enregistrer');
      if (silent) updateStatus(); else render();
    } catch (e) { toast('Erreur de sauvegarde : ' + e.message, true); }
    finally { saving = false; }
  }

  // Sauvegarde automatique : dès qu'une modification est faite (hors fenêtre ouverte)
  let lastDirtyAt = 0;
  setInterval(() => {
    if (!S.projectPath || !isDirty()) { lastDirtyAt = 0; return; }
    if (!lastDirtyAt) { lastDirtyAt = Date.now(); return; }
    if (modalStack.length && S.open) return;
    if (Date.now() - lastDirtyAt > 700) { lastDirtyAt = 0; saveAll(true); }
  }, 400);

  function projectList() {
    try { return JSON.parse(localStorage.getItem('projectList') || '[]'); } catch (e) { return []; }
  }

  async function loadProject(projectPath) {
    S.projectPath = projectPath;
    S.docs = {}; S.common = null; S.mapId = null; S.selEventId = null; S.selTile = null; S.error = null;
    imageCache.clear();
    S.ctx = null;
    render();
    try {
      S.ctx = await call('getContext', { projectPath });
      if (S.ctx.maps.length) S.mapId = S.ctx.maps[0].id;
      if (S.mapId) await loadMapDoc(currentMap());
      await loadCommon();
    } catch (e) { S.error = e.message; }
    render();
  }

  // ---------------------------------------------------------------------------
  // Rendu principal
  // ---------------------------------------------------------------------------
  let root = null;
  const nextEventId = (doc) => Math.max(0, ...doc.data.events.map((e) => e.id), ...doc.rmxp.map((e) => e.id)) + 1;
  const mapEnv = (doc) => ({ events: doc ? [...doc.data.events, ...doc.rmxp.filter((r) => !doc.data.events.some((e) => e.id === r.id))].sort((a, b) => a.id - b.id) : [] });

  function render() {
    if (!root) return;
    root.textContent = '';
    const projects = projectList();
    const projSel = h('select', { class: 'pje-select', style: { maxWidth: '320px' } },
      projects.map((p) => h('option', { value: p.projectPath, selected: p.projectPath === S.projectPath }, p.projectTitle || p.title || p.projectPath)));
    projSel.title = S.projectPath || '';
    if (!projects.some((p) => p.projectPath === S.projectPath) && S.projectPath) projSel.appendChild(h('option', { value: S.projectPath, selected: true }, S.projectPath));
    projSel.addEventListener('change', async () => {
      if (isDirty()) { const r = await confirmDialog('Changer de projet', 'Des modifications ne sont pas enregistrées.', [[null, 'Annuler'], ['discard', 'Ignorer'], ['save', 'Enregistrer', 'primary']]); if (!r) { projSel.value = S.projectPath; return; } if (r === 'save') await saveAll(); }
      loadProject(projSel.value);
    });
    const dirty = isDirty();
    root.appendChild(h('div', { class: 'pje-header' },
      h('span', { class: 'pje-title' }, 'Évents'),
      h('div', { class: 'pje-tabs' },
        h('button', { class: 'pje-tab' + (S.tab === 'maps' ? ' active' : ''), onclick: () => { S.tab = 'maps'; render(); } }, 'Évents de carte'),
        h('button', { class: 'pje-tab' + (S.tab === 'common' ? ' active' : ''), onclick: () => { S.tab = 'common'; render(); } }, 'Évents communs')),
      h('span', { class: 'pje-spacer' }),
      h('span', { class: 'pje-status' + (dirty ? ' dirty' : '') }, dirty ? '● Enregistrement…' : '✓ Enregistré automatiquement'),
      projSel,
      h('button', { class: 'pje-btn', onclick: () => S.projectPath && loadProject(S.projectPath), title: 'Relire le projet (cartes, charsets, données)' }, '⟳'),
      h('button', { class: 'pje-btn primary', onclick: saveAll, title: 'Ctrl+S' }, 'Enregistrer')));

    if (!S.projectPath) { root.appendChild(h('div', { class: 'pje-empty' }, 'Ouvre un projet dans Pokémon Studio, puis reviens ici.')); return placeSide(); }
    if (S.error) { root.appendChild(h('div', { class: 'pje-error' }, S.error)); return placeSide(); }
    if (!S.ctx) { root.appendChild(h('div', { class: 'pje-empty' }, 'Chargement…')); return placeSide(); }
    const rt = S.ctx.runtime || {};
    if (!rt.installed || !rt.upToDate) {
      root.appendChild(h('div', { class: 'pje-banner' },
        h('span', null, !rt.installed
          ? "⚠ Le script « 90000 StudioEvents.rb » n'est pas dans le dossier scripts de ce projet : les évents créés ici n'apparaîtront pas en jeu."
          : `⚠ Le script « ${rt.file} » de ce projet n'est pas à jour.`),
        h('button', { class: 'pje-btn small primary', onclick: async () => {
          try { S.ctx.runtime = await call('installRuntime', { projectPath: S.projectPath }); toast('Script installé dans scripts/ — relance le jeu'); render(); } catch (e) { toast(e.message, true); }
        } }, !rt.installed ? 'Installer le script' : 'Mettre à jour le script')));
    }
    root.appendChild(S.tab === 'maps' ? renderMapsTab() : renderCommonTab());
    placeSide();
  }

  // Place la liste de gauche (cartes / évents communs) dans le panneau de Studio
  function placeSide() {
    if (!sideSlot) return;
    sideSlot.textContent = '';
    const side = root && root.querySelector('.pje-body > .pje-side:not(.right)');
    if (side) { side.classList.add('in-studio'); sideSlot.appendChild(side); }
    fit();
  }

  // ---------------------------------------------------------------------------
  // Liste des cartes dans l'ordre de l'onglet Carte de Studio (dossiers, cartes enfants)
  // ---------------------------------------------------------------------------
  // @param query [String] recherche (garde l'arborescence : dossiers et cartes parentes des résultats)
  // @param activeDb [String] carte choisie (ses dossiers sont ouverts)
  // @return [Array<{ key, depth, folder, name, map, hasKids, open, dim }>]
  function mapTreeRows(query, activeDb) {
    const tree = S.ctx.mapTree;
    const bySym = new Map(S.ctx.maps.map((m) => [m.dbSymbol, m]));
    const q = (query || '').trim().toLowerCase();
    const match = (m) => !q || m.name.toLowerCase().includes(q) || String(m.id) === q.replace(/^0+(?=\d)/, '') || pad(m.id, 3).includes(q) || m.dbSymbol.toLowerCase().includes(q);
    const seen = new Set();
    const rows = [];
    if (tree && tree.nodes && tree.nodes[tree.root]) {
      const visiting = new Set();
      // Renvoie [lignes du sous-arbre, contient la carte choisie]
      const walk = (id, depth, all) => {
        const n = tree.nodes[id];
        if (!n || visiting.has(id)) return [[], false];
        visiting.add(id);
        const map = n.type === 'map' ? bySym.get(n.dbSymbol) : null;
        if (map) seen.add(map.dbSymbol);
        const selfMatch = n.type === 'folder' ? !!q && n.name.toLowerCase().includes(q) : !!map && match(map);
        const childDepth = n.type === 'root' || (n.type === 'map' && !map) ? depth : depth + 1;
        let kids = []; let hasActive = !!map && map.dbSymbol === activeDb;
        n.children.forEach((c) => { const [r, a] = walk(c, childDepth, all || (selfMatch && n.type === 'folder')); kids = kids.concat(r); hasActive = hasActive || a; });
        visiting.delete(id);
        if (n.type === 'root' || (n.type === 'map' && !map)) return [kids, hasActive];
        if (q && !all && !selfMatch && !kids.length) return [[], hasActive];
        const key = 'n' + id;
        const open = q ? true : (S.treeOpen[key] !== undefined ? S.treeOpen[key] : (n.expanded || hasActive));
        const row = { key, depth, folder: n.type === 'folder', name: n.type === 'folder' ? n.name : map.name, map, hasKids: kids.length > 0, open, dim: !!q && !all && !selfMatch };
        return [[row, ...(open ? kids : [])], hasActive];
      };
      rows.push(...walk(tree.root, 0, false)[0]);
    }
    // Cartes absentes de l'arborescence (map_info.json manquant ou incomplet) : à la fin, par numéro
    S.ctx.maps.filter((m) => !seen.has(m.dbSymbol) && match(m))
      .forEach((m) => rows.push({ key: 'm' + m.id, depth: 0, folder: false, name: m.name, map: m, hasKids: false, open: false, dim: false }));
    return rows;
  }

  // Remplit une liste de cartes en arbre
  // @param list [HTMLElement]
  // @param opts { query, activeId, onPick(map), badge(map) => Node|null, rerender() }
  function fillMapTree(list, opts) {
    list.textContent = '';
    const active = S.ctx.maps.find((m) => m.id === opts.activeId);
    const rows = mapTreeRows(opts.query, active && active.dbSymbol);
    if (!rows.length) list.appendChild(h('div', { class: 'pje-hint', style: { padding: '8px' } }, 'Aucune carte trouvée.'));
    rows.forEach((r) => {
      const toggle = (e) => { e.stopPropagation(); S.treeOpen[r.key] = !r.open; opts.rerender(); };
      const caret = r.hasKids && !opts.query
        ? h('span', { class: 'pje-caret', onclick: toggle }, r.open ? '▾' : '▸')
        : h('span', { class: 'pje-caret empty' });
      const isActive = r.map && r.map.id === opts.activeId;
      const el = h('div', {
        class: 'pje-item pje-tree' + (r.folder ? ' folder' : '') + (isActive ? ' active' : '') + (r.dim ? ' dim' : ''),
        style: { paddingLeft: 4 + r.depth * 14 + 'px' },
        onclick: r.folder ? (r.hasKids && !opts.query ? toggle : null) : () => opts.onPick(r.map),
        title: r.map ? r.map.dbSymbol : r.name,
      }, caret,
      r.folder ? h('span', { class: 'pje-folder-icon' }) : h('span', { class: 'id' }, pad(r.map.id, 3)),
      h('span', { class: 'label' }, r.name),
      r.map && opts.badge ? opts.badge(r.map) : null);
      list.appendChild(el);
    });
  }

  function renderMapsTab() {
    const body = h('div', { class: 'pje-body' });
    // Liste des cartes
    const search = h('input', { class: 'pje-input', placeholder: 'Rechercher une carte…', value: S.mapFilter });
    const list = h('div', { class: 'pje-list' });
    const renderList = () => {
      const scroll = list.scrollTop;
      fillMapTree(list, {
        query: S.mapFilter, activeId: S.mapId, onPick: (m) => selectMap(m.id), rerender: renderList,
        badge: (m) => {
          const doc = S.docs[m.dbSymbol];
          return doc && doc.dirty ? h('span', { class: 'tag' }, '●') : S.ctx.eventMaps.includes(m.dbSymbol) ? h('span', { class: 'dot', title: 'Contient des évents Studio' }) : null;
        },
      });
      list.scrollTop = scroll;
    };
    search.addEventListener('input', () => { S.mapFilter = search.value; renderList(); });
    renderList();
    body.appendChild(h('div', { class: 'pje-side' }, h('div', { class: 'pje-side-head' }, h('h3', null, 'Cartes'), search), list));

    const center = h('div', { class: 'pje-center' });
    body.appendChild(center);
    const map = currentMap();
    const doc = currentDoc();
    if (!map || !doc) {
      center.appendChild(h('div', { class: 'pje-empty' }, S.ctx.maps.length ? 'Choisis une carte.' : "Aucune carte dans ce projet. Crée d'abord tes cartes dans l'onglet Carte de Studio."));
      return body;
    }
    const T = 16 * S.zoom;
    const studioIds = new Set(doc.data.events.map((e) => e.id));
    const rmShown = S.showRmxp ? doc.rmxp.filter((e) => !studioIds.has(e.id)) : [];

    center.appendChild(h('div', { class: 'pje-toolbar' },
      h('span', { class: 'name' }, mapLabel(map.id)),
      h('span', { class: 'info' }, `${map.width}×${map.height} — ${doc.data.events.length} évent(s) Studio${doc.rmxp.length ? `, ${doc.rmxp.length} RPG Maker` : ''}`),
      h('span', { class: 'pje-spacer' }),
      h('button', { class: 'pje-btn small', title: 'Dézoomer (Ctrl + molette)', onclick: () => zoomStep(-1) }, '−'),
      h('span', { class: 'info pje-zoom' }, `${Math.round(S.zoom * 100)} %`),
      h('button', { class: 'pje-btn small', title: 'Zoomer (Ctrl + molette)', onclick: () => zoomStep(1) }, '+'),
      h('button', { class: 'pje-btn small', title: 'Voir toute la carte', onclick: () => zoomFit(map) }, 'Ajuster'),
      doc.rmxp.length ? h('label', { class: 'pje-check' }, (() => { const c = h('input', { type: 'checkbox', checked: S.showRmxp }); c.addEventListener('change', () => { S.showRmxp = c.checked; render(); }); return c; })(), 'Évents RPG Maker') : null,
      rmShown.length ? h('button', { class: 'pje-btn small', onclick: () => importAllRmxp(doc) }, `Importer les ${rmShown.length} évents RPG Maker`) : null,
      h('button', { class: 'pje-btn small primary', onclick: () => createEventAt(doc, S.selTile ? S.selTile.x : 0, S.selTile ? S.selTile.y : 0) }, '+ Nouvel évent')));

    const wrap = h('div', { class: 'pje-mapwrap' });
    const mapEl = h('div', { class: 'pje-map', style: { width: map.width * T + 'px', height: map.height * T + 'px', backgroundImage: map.overview ? `url("${projectUrl(map.overview)}")` : 'none' } },
      h('div', { class: 'pje-grid', style: { backgroundSize: `${T}px ${T}px` } }));
    if (!map.overview) wrap.appendChild(h('div', { class: 'pje-hint', style: { padding: '8px 24px 0' } }, "Pas d'aperçu pour cette carte : ouvre-la une fois dans l'onglet Carte de Studio pour générer l'aperçu."));
    const cursor = h('div', { class: 'pje-cursor', style: { width: T + 'px', height: T + 'px', display: 'none' } });
    mapEl.appendChild(cursor);
    const markers = new Map();
    const listItems = new Map();
    S._refs = { cursor, markers, listItems, T };

    const addMarker = (ev, isRm) => {
      const page = ev.pages && ev.pages[0];
      const el = h('div', { class: 'pje-ev' + (isRm ? ' rm' : ''), style: { left: ev.x * T + 'px', top: ev.y * T + 'px', width: T + 'px', height: T + 'px' }, title: `#${ev.id} ${ev.name}${isRm ? ' (RPG Maker)' : ''}` },
        h('div', { class: 'box' }));
      if (page && page.graphic && page.graphic.characterName) {
        const c = h('canvas'); el.appendChild(c);
        drawCharacter(c, page.graphic, T / 16);
      }
      if (S.zoom >= 2) el.appendChild(h('div', { class: 'lbl' }, `${isRm ? 'RM ' : ''}#${ev.id}`));
      el.addEventListener('mousedown', (e) => {
        if (e.button !== 0) return;
        e.stopPropagation();
        S.selTile = { x: ev.x, y: ev.y };
        S.selEventId = isRm ? null : ev.id;
        updateSelection();
        if (!isRm) startDrag(e, ev, doc, T, el);
      });
      if (!isRm) markers.set(ev.id, el);
      el.addEventListener('dblclick', (e) => { e.stopPropagation(); isRm ? openRmxpEvent(doc, ev) : openEvent(doc, ev.id); });
      mapEl.appendChild(el);
    };
    rmShown.forEach((ev) => addMarker(ev, true));
    doc.data.events.forEach((ev) => addMarker(ev, false));

    const tileAt = (e) => { const r = mapEl.getBoundingClientRect(); return { x: clamp(Math.floor((e.clientX - r.left) / T), 0, map.width - 1), y: clamp(Math.floor((e.clientY - r.top) / T), 0, map.height - 1) }; };
    mapEl.addEventListener('mousedown', (e) => { if (e.button !== 0) return; S.selTile = tileAt(e); S.selEventId = null; updateSelection(); });
    mapEl.addEventListener('dblclick', (e) => { const t = tileAt(e); createEventAt(doc, t.x, t.y); });
    wrap.appendChild(mapEl);
    center.appendChild(wrap);
    S._wrap = wrap;
    requestAnimationFrame(() => {
      const c = S.zoomCenter;
      S.zoomCenter = null;
      if (c && c.mapId === map.id) {
        // garde le même point de la carte au même endroit après un zoom
        wrap.scrollLeft = c.fx * map.width * T + 24 - c.px;
        wrap.scrollTop = c.fy * map.height * T + 24 - c.py;
      } else if (S.scroll && S.scroll.mapId === map.id) { wrap.scrollLeft = S.scroll.left; wrap.scrollTop = S.scroll.top; }
      S.scroll = { mapId: map.id, left: wrap.scrollLeft, top: wrap.scrollTop };
    });
    wrap.addEventListener('scroll', () => { S.scroll = { mapId: map.id, left: wrap.scrollLeft, top: wrap.scrollTop }; });
    // Ctrl + molette : zoom autour de la souris ; Maj + molette : défilement horizontal
    wrap.addEventListener('wheel', (e) => {
      if (e.ctrlKey) { e.preventDefault(); zoomStep(e.deltaY < 0 ? 1 : -1, e); return; }
      if (e.shiftKey && !e.deltaX) { e.preventDefault(); wrap.scrollLeft += e.deltaY; }
    }, { passive: false });
    // Clic du milieu (ou clic droit) maintenu : déplacer la vue
    wrap.addEventListener('mousedown', (e) => {
      if (e.button !== 1 && e.button !== 2) return;
      e.preventDefault();
      const sx = e.clientX; const sy = e.clientY; const l = wrap.scrollLeft; const t = wrap.scrollTop;
      const button = e.button; let moved = false;
      wrap.classList.add('panning');
      const move = (ev) => { if (Math.abs(ev.clientX - sx) + Math.abs(ev.clientY - sy) > 4) moved = true; wrap.scrollLeft = l - (ev.clientX - sx); wrap.scrollTop = t - (ev.clientY - sy); };
      const up = (ev) => {
        wrap.classList.remove('panning'); window.removeEventListener('mousemove', move); window.removeEventListener('mouseup', up);
        // clic droit sans déplacer la vue : menu Copier / Coller…
        if (button === 2 && !moved && mapEl.contains(ev.target)) eventMenu(ev, doc, tileAt(ev));
      };
      window.addEventListener('mousemove', move);
      window.addEventListener('mouseup', up);
    });
    wrap.addEventListener('contextmenu', (e) => e.preventDefault());

    // Liste des évents de la carte
    const evList = h('div', { class: 'pje-list' });
    mapEnv(doc).events.forEach((ev) => {
      const isRm = !studioIds.has(ev.id);
      const item = h('div', { class: 'pje-item',
        onclick: () => { S.selEventId = isRm ? null : ev.id; S.selTile = { x: ev.x, y: ev.y }; updateSelection(); },
        ondblclick: () => (isRm ? openRmxpEvent(doc, ev) : openEvent(doc, ev.id)) },
        h('span', { class: 'id' }, pad(ev.id, 3)), h('span', null, ev.name), h('span', { class: 'pje-hint' }, `(${ev.x},${ev.y})`), isRm ? h('span', { class: 'tag' }, 'RM') : null);
      if (!isRm) listItems.set(ev.id, item);
      evList.appendChild(item);
    });
    updateSelection();
    const selEv = doc.data.events.find((x) => x.id === S.selEventId);
    const clip = getEventClipboard();
    body.appendChild(h('div', { class: 'pje-side right' }, h('div', { class: 'pje-side-head' }, h('h3', null, 'Évents de la carte'),
      h('div', { class: 'pje-cliprow' },
        h('button', { class: 'pje-btn small', title: 'Copier l\'évent sélectionné (Ctrl+C)', onclick: () => copyEvent(doc.data.events.find((x) => x.id === S.selEventId)) }, 'Copier'),
        h('button', { class: 'pje-btn small', disabled: !clip, title: clip ? `Coller « ${clip.name} » sur la case sélectionnée, ou la plus proche libre (Ctrl+V)` : 'Aucun évent copié', onclick: () => pasteEvent(doc, S.selTile) }, 'Coller'),
        h('button', { class: 'pje-btn small', title: 'Dupliquer à côté (Ctrl+D)', onclick: () => duplicateEvent(doc, doc.data.events.find((x) => x.id === S.selEventId)) }, 'Dupliquer')),
      clip ? h('span', { class: 'pje-hint' }, `Presse-papiers : « ${clip.name} » (${(clip.pages || []).length} page(s))`) : null,
      h('span', { class: 'pje-hint' }, 'Double-clic sur la carte : créer / ouvrir. Glisser : déplacer. Clic droit : copier / coller. Suppr : supprimer. Ctrl+C / X / V / D : copier, couper, coller, dupliquer (aussi d\'une carte à l\'autre). Ctrl+Z : annuler.')), evList));
    return body;
  }

  // Niveaux de zoom (1 = 16 pixels par case)
  const ZOOMS = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4];

  // Mémorise le point de la carte sous la souris (ou au centre de la vue) avant de changer le zoom
  function rememberZoomCenter(e) {
    const map = currentMap(); const wrap = S._wrap;
    if (!map || !wrap || !document.body.contains(wrap)) return;
    const T = 16 * S.zoom;
    const r = wrap.getBoundingClientRect();
    const px = e && e.clientX !== undefined ? e.clientX - r.left : wrap.clientWidth / 2;
    const py = e && e.clientY !== undefined ? e.clientY - r.top : wrap.clientHeight / 2;
    S.zoomCenter = { mapId: map.id, px, py,
      fx: clamp((wrap.scrollLeft + px - 24) / (map.width * T), 0, 1), fy: clamp((wrap.scrollTop + py - 24) / (map.height * T), 0, 1) };
  }

  function zoomStep(dir, e) {
    const next = dir > 0 ? ZOOMS.find((z) => z > S.zoom + 1e-6) : [...ZOOMS].reverse().find((z) => z < S.zoom - 1e-6);
    if (next === undefined) return;
    rememberZoomCenter(e);
    S.zoom = next;
    render();
  }

  // Zoom qui montre toute la carte dans la vue
  function zoomFit(map) {
    const wrap = S._wrap;
    if (!map || !wrap) return;
    const fit = Math.min((wrap.clientWidth - 48) / (map.width * 16), (wrap.clientHeight - 48) / (map.height * 16));
    S.zoom = clamp(Math.floor(fit * 100) / 100, 0.1, 4);
    S.scroll = { mapId: map.id, left: 0, top: 0 };
    render();
  }

  function updateSelection() {
    const r = S._refs; if (!r) return;
    if (S.selTile) Object.assign(r.cursor.style, { display: '', left: S.selTile.x * r.T + 'px', top: S.selTile.y * r.T + 'px' });
    else r.cursor.style.display = 'none';
    r.markers.forEach((el, id) => el.classList.toggle('sel', id === S.selEventId));
    r.listItems.forEach((el, id) => el.classList.toggle('active', id === S.selEventId));
  }

  function startDrag(e, ev, doc, T, el) {
    const sx = e.clientX, sy = e.clientY, ox = ev.x, oy = ev.y;
    const map = currentMap();
    let moved = false;
    const onMove = (m) => {
      const dx = Math.round((m.clientX - sx) / T), dy = Math.round((m.clientY - sy) / T);
      const nx = clamp(ox + dx, 0, map.width - 1), ny = clamp(oy + dy, 0, map.height - 1);
      if (nx !== ev.x || ny !== ev.y || moved) {
        if (!moved) { pushUndo(doc); moved = true; }
        ev.x = nx; ev.y = ny;
        el.style.left = nx * T + 'px'; el.style.top = ny * T + 'px';
      }
    };
    const onUp = () => {
      window.removeEventListener('mousemove', onMove); window.removeEventListener('mouseup', onUp);
      if (moved && ev.x === ox && ev.y === oy) doc.undo.pop();
      S.selTile = { x: ev.x, y: ev.y };
      if (moved) render(); else updateSelection();
    };
    window.addEventListener('mousemove', onMove); window.addEventListener('mouseup', onUp);
  }

  async function selectMap(id) {
    S.mapId = id; S.selEventId = null; S.selTile = null;
    try { await loadMapDoc(currentMap()); } catch (e) { toast(e.message, true); }
    render();
  }

  // --- Copier / coller des évents (entre cartes aussi ; gardé jusqu'à la fermeture de Studio) ---
  const CLIP_KEY = 'pje-event-clipboard';
  function getEventClipboard() {
    if (S.eventClipboard) return S.eventClipboard;
    try { const v = localStorage.getItem(CLIP_KEY); if (v) S.eventClipboard = JSON.parse(v); } catch (e) { /* rien */ }
    return S.eventClipboard || null;
  }
  function copyEvent(ev, cut, doc) {
    if (!ev) return toast('Sélectionne d\'abord un évent', true);
    S.eventClipboard = clone(ev);
    try { localStorage.setItem(CLIP_KEY, JSON.stringify(S.eventClipboard)); } catch (e) { /* rien */ }
    if (cut && doc) {
      pushUndo(doc); doc.data.events.splice(doc.data.events.indexOf(ev), 1); S.selEventId = null; render();
      toast(`Évent « ${ev.name} » coupé`);
    } else { toast(`Évent « ${ev.name} » copié`); render(); }
  }
  // case libre la plus proche de (x, y)
  function freeTile(doc, x, y) {
    const map = currentMap();
    const used = (a, b) => doc.data.events.some((e) => e.x === a && e.y === b);
    for (let r = 0; r < 64; r++) {
      for (let dy = -r; dy <= r; dy++) {
        for (let dx = -r; dx <= r; dx++) {
          if (Math.max(Math.abs(dx), Math.abs(dy)) !== r) continue;
          const a = x + dx; const b = y + dy;
          if (map && (a < 0 || b < 0 || a >= map.width || b >= map.height)) continue;
          if (!used(a, b)) return { x: a, y: b };
        }
      }
    }
    return null;
  }
  function pasteEvent(doc, at) {
    const clip = getEventClipboard();
    if (!clip) return toast('Aucun évent copié', true);
    const pos = freeTile(doc, at ? at.x : clip.x, at ? at.y : clip.y);
    if (!pos) return toast('Aucune case libre', true);
    pushUndo(doc);
    const copy = clone(clip); copy.id = nextEventId(doc); copy.x = pos.x; copy.y = pos.y;
    doc.data.events.push(copy); S.selEventId = copy.id; S.selTile = pos; render();
    toast(`Évent collé en (${pos.x}, ${pos.y})`);
  }
  function duplicateEvent(doc, ev) {
    if (!ev) return toast('Sélectionne d\'abord un évent', true);
    const pos = freeTile(doc, ev.x + 1, ev.y);
    if (!pos) return toast('Aucune case libre', true);
    pushUndo(doc);
    const copy = clone(ev); copy.id = nextEventId(doc); copy.x = pos.x; copy.y = pos.y;
    doc.data.events.push(copy); S.selEventId = copy.id; S.selTile = pos; render();
  }
  function deleteEvent(doc, ev) {
    if (!ev) return;
    confirmDialog('Supprimer', `Supprimer l'évent #${ev.id} « ${ev.name} » ?`, [[false, 'Annuler'], [true, 'Supprimer', 'primary']]).then((r) => {
      if (r) { pushUndo(doc); doc.data.events.splice(doc.data.events.indexOf(ev), 1); S.selEventId = null; render(); }
    });
  }
  // menu du clic droit sur la carte
  function eventMenu(e, doc, tile) {
    closeEventMenu();
    const ev = doc.data.events.find((x) => x.x === tile.x && x.y === tile.y);
    S.selTile = tile; S.selEventId = ev ? ev.id : null; updateSelection();
    const clip = getEventClipboard();
    const item = (label, fn, disabled, hint) => h('button', { class: 'pje-ctx-item', disabled: !!disabled, onclick: () => { closeEventMenu(); fn(); } }, label, hint ? h('span', { class: 'pje-hint' }, hint) : null);
    const menu = h('div', { class: 'pje-ctx', style: { left: e.clientX + 'px', top: e.clientY + 'px' } },
      ev ? item('Modifier', () => openEvent(doc, ev.id), false, 'Entrée') : item('Nouvel évent ici', () => createEventAt(doc, tile.x, tile.y)),
      item('Copier', () => copyEvent(ev), !ev, 'Ctrl+C'),
      item('Couper', () => copyEvent(ev, true, doc), !ev, 'Ctrl+X'),
      item(clip ? `Coller « ${clip.name} » ici` : 'Coller ici', () => pasteEvent(doc, tile), !clip, 'Ctrl+V'),
      item('Dupliquer', () => duplicateEvent(doc, ev), !ev, 'Ctrl+D'),
      item('Supprimer', () => deleteEvent(doc, ev), !ev, 'Suppr'));
    (root || document.body).appendChild(menu);
    const r = menu.getBoundingClientRect();
    if (r.right > window.innerWidth) menu.style.left = Math.max(0, e.clientX - r.width) + 'px';
    if (r.bottom > window.innerHeight) menu.style.top = Math.max(0, e.clientY - r.height) + 'px';
    S._ctx = menu;
    setTimeout(() => window.addEventListener('mousedown', ctxOutside, true), 0);
  }
  function ctxOutside(e) { if (S._ctx && !S._ctx.contains(e.target)) closeEventMenu(); }
  function closeEventMenu() {
    if (S._ctx) { S._ctx.remove(); S._ctx = null; }
    window.removeEventListener('mousedown', ctxOutside, true);
  }

  async function createEventAt(doc, x, y) {
    const existing = doc.data.events.find((e) => e.x === x && e.y === y);
    if (existing) return openEvent(doc, existing.id);
    const ev = newEvent(nextEventId(doc), x, y);
    const r = await openEventDialog(ev, mapEnv(doc));
    if (r && r.event) { pushUndo(doc); doc.data.events.push(r.event); S.selEventId = r.event.id; S.selTile = { x: r.event.x, y: r.event.y }; render(); }
  }

  async function openEvent(doc, id) {
    const ev = doc.data.events.find((e) => e.id === id); if (!ev) return;
    const r = await openEventDialog(ev, mapEnv(doc));
    if (!r) return;
    pushUndo(doc);
    const i = doc.data.events.findIndex((e) => e.id === id);
    if (r.deleted) { doc.data.events.splice(i, 1); S.selEventId = null; } else doc.data.events[i] = r.event;
    render();
  }

  async function openRmxpEvent(doc, ev) {
    const r = await confirmDialog(`Évent RPG Maker #${ev.id}`, `« ${ev.name} » vient de Map${pad(currentMap().id, 3)}.rxdata.\n\nL'importer dans Studio permet de le modifier ici. En jeu, la version Studio remplacera celle de RPG Maker (même ID). Le fichier RPG Maker n'est pas modifié.`,
      [[null, 'Annuler'], ['import', 'Importer et modifier', 'primary']]);
    if (r !== 'import') return;
    pushUndo(doc);
    doc.data.events.push(clone(ev));
    render();
    openEvent(doc, ev.id);
  }

  async function importAllRmxp(doc) {
    const ids = new Set(doc.data.events.map((e) => e.id));
    const todo = doc.rmxp.filter((e) => !ids.has(e.id));
    const r = await confirmDialog('Importer', `Importer ${todo.length} évent(s) RPG Maker de cette carte dans Studio ?\nLes commandes non reconnues sont gardées telles quelles (« Commande RPG Maker »).`, [[false, 'Annuler'], [true, 'Importer', 'primary']]);
    if (!r) return;
    pushUndo(doc);
    todo.forEach((e) => doc.data.events.push(clone(e)));
    toast(`${todo.length} évent(s) importé(s)`);
    render();
  }

  // Évents communs
  function renderCommonTab() {
    const body = h('div', { class: 'pje-body' });
    const doc = S.common;
    const ids = new Set(doc.data.events.map((e) => e.id));
    const list = h('div', { class: 'pje-list' });
    const all = [...doc.data.events.map((e) => ({ e, rm: false })), ...doc.rmxp.filter((e) => !ids.has(e.id)).map((e) => ({ e, rm: true }))].sort((a, b) => a.e.id - b.e.id);
    all.forEach(({ e, rm }) => list.appendChild(h('div', { class: 'pje-item' + (!rm && e.id === S.commonSel ? ' active' : ''), onclick: async () => {
      if (rm) {
        const r = await confirmDialog(`Évent commun RPG Maker #${e.id}`, `Importer « ${e.name} » dans Studio pour le modifier ?`, [[null, 'Annuler'], ['import', 'Importer', 'primary']]);
        if (r !== 'import') return;
        pushUndo(doc); doc.data.events.push(clone(e));
      }
      S.commonSel = e.id; render();
    } }, h('span', { class: 'id' }, pad(e.id, 3)), h('span', null, e.name || '(sans nom)'), rm ? h('span', { class: 'tag' }, 'RM') : null)));
    const rmLeft = doc.rmxp.filter((e) => !ids.has(e.id)).length;
    body.appendChild(h('div', { class: 'pje-side' }, h('div', { class: 'pje-side-head' }, h('h3', null, 'Évents communs'),
      h('button', { class: 'pje-btn small primary', onclick: () => {
        const id = Math.max(0, ...doc.data.events.map((e) => e.id), ...doc.rmxp.map((e) => e.id)) + 1;
        pushUndo(doc); doc.data.events.push({ id, name: `Évent commun ${id}`, trigger: 'none', switchId: 1, commands: [] }); S.commonSel = id; render();
      } }, '+ Nouvel évent commun'),
      rmLeft ? h('button', { class: 'pje-btn small', onclick: async () => {
        const r = await confirmDialog('Importer', `Importer les ${rmLeft} évent(s) commun(s) de CommonEvents.rxdata ?`, [[false, 'Annuler'], [true, 'Importer', 'primary']]);
        if (!r) return; pushUndo(doc); doc.rmxp.filter((e) => !ids.has(e.id)).forEach((e) => doc.data.events.push(clone(e))); render();
      } }, 'Tout importer depuis RPG Maker') : null), list));

    const ce = doc.data.events.find((e) => e.id === S.commonSel);
    const main = h('div', { class: 'pje-common' });
    body.appendChild(main);
    if (!ce) { main.appendChild(h('div', { class: 'pje-empty' }, 'Choisis ou crée un évent commun.\nLes évents communs marqués RM viennent de RPG Maker : clique dessus pour les importer.')); return body; }
    doc._snap = false;
    const touch = () => { if (!doc._snap) { pushUndo(doc); doc._snap = true; } doc.dirty = true; updateStatus(); };
    const name = h('input', { class: 'pje-input', value: ce.name, style: { width: '240px' } });
    name.addEventListener('input', () => { touch(); ce.name = name.value; });
    const swField = idField('switch', ce.switchId, (v) => { touch(); ce.switchId = v; });
    const swLabel = h('span', { class: 'pje-hint' }, 'Interrupteur');
    swField.style.display = swLabel.style.display = ce.trigger === 'none' ? 'none' : '';
    main.appendChild(h('div', { class: 'head' },
      h('span', { class: 'pje-hint' }, `#${pad(ce.id, 3)}`), name,
      h('span', { class: 'pje-hint' }, 'Déclencheur'), selectEl(COMMON_TRIGGERS, ce.trigger, (v) => { touch(); ce.trigger = v; swField.style.display = swLabel.style.display = v === 'none' ? 'none' : ''; }),
      swLabel, swField,
      h('span', { class: 'pje-spacer' }),
      h('button', { class: 'pje-btn small danger', onclick: async () => {
        const r = await confirmDialog('Supprimer', `Supprimer l'évent commun #${ce.id} ?${doc.rmxp.some((e) => e.id === ce.id) ? "\nLa version RPG Maker sera de nouveau utilisée." : ''}`, [[false, 'Annuler'], [true, 'Supprimer', 'primary']]);
        if (!r) return; pushUndo(doc); doc.data.events.splice(doc.data.events.indexOf(ce), 1); S.commonSel = null; render();
      } }, 'Supprimer')));
    const cl = commandList(() => ce.commands, () => { doc.dirty = true; updateStatus(); }, () => ({ events: [] }), () => pushUndo(doc));
    main.appendChild(cl.el);
    return body;
  }

  function updateStatus() {
    const st = root && root.querySelector('.pje-status');
    if (!st) return;
    const d = isDirty();
    st.className = 'pje-status' + (d ? ' dirty' : '');
    st.textContent = d ? '● Enregistrement…' : '✓ Enregistré automatiquement';
  }

  // ---------------------------------------------------------------------------
  // Intégration dans Studio : Monde > Événements (vraie page de Studio)
  // Studio laisse la page et son panneau de gauche à l'éditeur (tools/studio-plugins/patch_studio_pages.py) :
  //   #pj-page-events      : l'éditeur
  //   #pj-page-events-side : la liste à gauche
  // ---------------------------------------------------------------------------
  let sideSlot = null;
  if (!(window.pjPluginPages = window.pjPluginPages || []).some((p) => p.id === 'events')) window.pjPluginPages.push({ id: 'events', label: 'Événements', place: 'world' });
  window.dispatchEvent(new Event('pj-plugin-pages'));

  function fit() {
    if (root) root.style.height = Math.max(200, window.innerHeight - root.getBoundingClientRect().top) + 'px';
    if (sideSlot) sideSlot.style.height = Math.max(150, window.innerHeight - sideSlot.getBoundingClientRect().top - 24) + 'px';
  }

  async function mountIn(page) {
    root = h('div', { id: 'pje-root', class: 'pje-embedded' });
    // les touches tapées dans l'éditeur ne remontent pas jusqu'aux raccourcis de Studio
    ['keydown', 'keypress', 'keyup'].forEach((type) => root.addEventListener(type, (e) => e.stopPropagation()));
    page.appendChild(root);
    S.open = true;
    mountSide();
    fit();
    const projects = projectList();
    const latest = projects[0] && projects[0].projectPath;
    if (!S.projectPath || (latest && latest !== S.projectPath && !isDirty())) await loadProject(latest || null);
    else {
      try { const keep = S.mapId; S.ctx = await call('getContext', { projectPath: S.projectPath }); S.mapId = keep; } catch (e) { S.error = e.message; }
      render();
    }
  }

  // panneau de gauche (peut arriver un peu après la page)
  function mountSide() {
    const side = document.getElementById('pj-page-events-side');
    if (!side || (sideSlot && side.contains(sideSlot))) return false;
    sideSlot = h('div', { class: 'pje-side-slot' });
    sideSlot.addEventListener('keydown', (e) => e.stopPropagation());
    side.appendChild(sideSlot);
    return true;
  }

  let checkScheduled = false;
  function checkMount() {
    checkScheduled = false;
    const page = document.getElementById('pj-page-events');
    if (root && page && page.contains(root)) {
      if (mountSide() && S.ctx) render();
      return;
    }
    if (root) {
      root = null; sideSlot = null; S.open = false; S._refs = null;
      while (modalStack.length) modalStack[modalStack.length - 1].close(null);
      if (isDirty()) saveAll(true);
    }
    if (page) mountIn(page);
  }
  const observer = new MutationObserver(() => { if (!checkScheduled) { checkScheduled = true; requestAnimationFrame(checkMount); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true }); checkMount(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);
  window.addEventListener('resize', fit);

  function goToEvents() {
    if (window.pjNavigate) return window.pjNavigate('/world/events');
    const link = [...document.querySelectorAll('a[href]')].find((a) => /\/world\/events$/.test(a.getAttribute('href')));
    if (link) link.click(); else toast("Ouvre l'onglet Monde puis « Événements »");
  }

  window.addEventListener('keydown', (e) => {
    const k = e.key.toLowerCase();
    if (e.ctrlKey && e.shiftKey && k === 'e') { e.preventDefault(); if (!S.open) goToEvents(); return; }
    if (!S.open) return;
    if (k === 'escape') { e.preventDefault(); e.stopPropagation(); if (modalStack.length) modalStack[modalStack.length - 1].close(null); return; }
    if (e.ctrlKey && k === 's') { e.preventDefault(); e.stopPropagation(); saveAll(); return; }
    if (modalStack.length) return;
    const inField = ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement && document.activeElement.tagName) || (document.activeElement && document.activeElement.classList.contains('pje-cmds'));
    if (inField) return;
    if (e.ctrlKey && k === 'z') { e.preventDefault(); undo(); return; }
    if (S.tab !== 'maps') return;
    const doc = currentDoc(); if (!doc) return;
    const ev = doc.data.events.find((x) => x.id === S.selEventId);
    if ((k === 'delete' || k === 'backspace') && ev) { e.preventDefault(); deleteEvent(doc, ev); }
    else if (e.ctrlKey && k === 'c' && ev) { e.preventDefault(); S._clipHandled = Date.now(); copyEvent(ev); }
    else if (e.ctrlKey && k === 'x' && ev) { e.preventDefault(); S._clipHandled = Date.now(); copyEvent(ev, true, doc); }
    else if (e.ctrlKey && k === 'v') { e.preventDefault(); S._clipHandled = Date.now(); pasteEvent(doc, S.selTile); }
    else if (e.ctrlKey && k === 'd' && ev) { e.preventDefault(); duplicateEvent(doc, ev); }
    else if (k === 'enter' && ev) openEvent(doc, ev.id);
  }, true);

  // Studio peut intercepter Ctrl+C / Ctrl+V par son menu Édition : on écoute aussi les évènements copier / coller
  const clipTarget = () => {
    if (!S.open || modalStack.length || S.tab !== 'maps') return null;
    const a = document.activeElement;
    if (a && (['INPUT', 'TEXTAREA', 'SELECT'].includes(a.tagName) || a.classList.contains('pje-cmds'))) return null;
    if (S._clipHandled && Date.now() - S._clipHandled < 300) return null;
    return currentDoc();
  };
  ['copy', 'cut'].forEach((type) => document.addEventListener(type, (e) => {
    const doc = clipTarget(); if (!doc) return;
    const ev = doc.data.events.find((x) => x.id === S.selEventId); if (!ev) return;
    e.preventDefault(); copyEvent(ev, type === 'cut', doc);
  }, true));
  document.addEventListener('paste', (e) => {
    const doc = clipTarget(); if (!doc) return;
    e.preventDefault(); pasteEvent(doc, S.selTile);
  }, true);

  window.pjEventsEditor = { open: goToEvents, state: S };
})();

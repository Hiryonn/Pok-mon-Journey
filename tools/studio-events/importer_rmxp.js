// Importe d'un coup les évents RPG Maker (Data/MapXXX.rxdata, CommonEvents.rxdata) dans Studio Events
// (Data/studio_events/map_events/<carte>.json et common_events.json), comme le bouton « Importer tout » de la page.
// N'écrase rien : un évent dont le numéro existe déjà côté Studio est laissé tel quel.
// Usage : node importer_rmxp.js <dossier du projet> [--dry]
const fs = require('fs');
const path = require('path');
const m = require('./pj-events-main.js');
const project = path.resolve(process.argv[2] || '.');
const dry = process.argv.includes('--dry');
const h = m.handlers;
const clone = (o) => JSON.parse(JSON.stringify(o));

(async () => {
  const mapsDir = path.join(project, 'Data/Studio/maps');
  const maps = fs.readdirSync(mapsDir).filter((f) => f.endsWith('.json')).map((f) => JSON.parse(fs.readFileSync(path.join(mapsDir, f), 'utf8')))
    .filter((x) => x && x.klass === 'Map').sort((a, b) => a.id - b.id);
  let nMaps = 0, nEvents = 0, nErrors = 0;
  for (const map of maps) {
    if (!fs.existsSync(path.join(project, `Data/Map${String(map.id).padStart(3, '0')}.rxdata`))) continue;
    const rmxp = await h.readRmxpEvents({ projectPath: project, mapId: map.id });
    const data = (await h.readMapEvents({ projectPath: project, dbSymbol: map.dbSymbol })) || { klass: 'MapEvents', mapId: map.id, mapDbSymbol: map.dbSymbol, events: [] };
    data.mapId = map.id;
    const ids = new Set(data.events.map((e) => e.id));
    const add = rmxp.filter((e) => !ids.has(e.id));
    nErrors += add.filter((e) => e.error).length;
    if (!add.length) continue;
    add.forEach((e) => data.events.push(clone(e)));
    data.events.sort((a, b) => a.id - b.id);
    nMaps++; nEvents += add.length;
    if (!dry) await h.saveMapEvents({ projectPath: project, dbSymbol: map.dbSymbol, data });
  }
  let nCommon = 0;
  if (fs.existsSync(path.join(project, 'Data/CommonEvents.rxdata'))) {
    const rmxp = await h.readRmxpCommonEvents({ projectPath: project });
    const data = (await h.readCommonEvents({ projectPath: project })) || { klass: 'CommonEvents', events: [] };
    const ids = new Set(data.events.map((e) => e.id));
    const add = rmxp.filter((e) => !ids.has(e.id));
    add.forEach((e) => data.events.push(clone(e)));
    data.events.sort((a, b) => a.id - b.id);
    nCommon = add.length;
    if (!dry && add.length) await h.saveCommonEvents({ projectPath: project, data });
  }
  console.log(`${dry ? '[essai] ' : ''}${nEvents} évents de ${nMaps} cartes, ${nCommon} évents communs${nErrors ? `, dont ${nErrors} non convertis (champ error)` : ''}`);
})().catch((e) => { console.error(e); process.exit(1); });

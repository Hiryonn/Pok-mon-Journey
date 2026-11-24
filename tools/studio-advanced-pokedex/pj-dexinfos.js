/* eslint-disable */
// =============================================================================
// Infos Pokédex — ajout à la page « Pokémon » de Pokémon Studio (plugin « advanced_pokedex »)
// Ajoute un bloc « Couleur, habitat, corps » (couleur, habitat, apparence du corps) à côté du bloc « Pokédex » du Pokémon affiché.
// Un clic ouvre une fenêtre de réglage ; Valider écrit aussitôt Data/configs/plugins/pokedex_infos.json.
//   { "klass": "PokedexInfosConfig", "creatures": { "bulbasaur": { "color": "green", "habitat": "grassland",
//     "generation": 1, "forms": { "1": { "color": "…" } } } } }
// Génération 0 = Fakemon. Sans génération choisie : celle du n° national (1 à 1025), sinon 0.
// =============================================================================
(() => {
  'use strict';
  if (window.__pjDexInfosLoaded) return;
  window.__pjDexInfosLoaded = true;

  // Listes (les mêmes que PokedexInfos dans le plugin)
  const COLORS = [
    ['red', 'Rouge', '#e0493e'], ['blue', 'Bleu', '#3f7fe0'], ['yellow', 'Jaune', '#efcf3a'], ['green', 'Vert', '#4cb04c'],
    ['black', 'Noir', '#303030'], ['brown', 'Marron', '#9a6b3c'], ['purple', 'Violet', '#9a5bc4'], ['gray', 'Gris', '#9a9aa4'],
    ['white', 'Blanc', '#f0f0f0'], ['pink', 'Rose', '#f08cc0'],
  ];
  const HABITATS = [
    ['grassland', 'Plaine'], ['forest', 'Forêt'], ['waters-edge', "Bord de l'eau"], ['sea', 'Mer'], ['cave', 'Grotte'],
    ['mountain', 'Montagne'], ['rough-terrain', 'Terrain accidenté'], ['urban', 'Ville'], ['rare', 'Rare'],
  ];
  // Dernier n° national de chaque génération
  const GEN_LAST = [151, 251, 386, 493, 649, 721, 809, 905, 1025];
  const autoGeneration = (id) => { const i = GEN_LAST.findIndex((last) => id <= last); return id > 0 && i >= 0 ? i + 1 : 0; };
  const genLabel = (g) => (g === 0 ? 'Génération 0 (Fakemon)' : `Génération ${g}`);
  const colorLabel = (k) => { const c = COLORS.find(([key]) => key === k); return c ? c[1] : k; };
  // Apparence du corps (morphologie) : 15 silhouettes, graphics/pokedex/body_shapes/corps_N.png
  const SHAPES = [
    [1, 'ball', "Sphérique", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABVklEQVR4Xu2WvW3DMBCFX4KsIMBbOKU4gb2EoLTq3CUjpEsaqU62SCZgm2xhQKUKlQqOIIMjYf5YIuCGH0DQ9kn3Ho+0dEChULgxdxv0dwD2gJqJM4BfPSdzrQEu+iiEOHElKeU7gJ9rzKQaMMJHV9SHNvMVq0qKARJvhRCvyXVlSClfAHz6tuY+knSTOKGNt+ysWIQMbBY3hEyEtuAghKA9zIaU8gjgmyf0VYBWTxdbDMPgNROKMSin+dsqfAb2dV2flmWBGX3fo+s6NfPf6XMoxq+lnPrZ8c+DZ0m7eZ6tEH3ngxOKXcCqgM8Apmmy7m2aRpWZZpdQLIbvELZVVX3Ebl7DOI5P+rmg8FXg7FYgI/TOiEL79AZgyTwop3UGQhwyi9NiKGcy5PQ5ownKlbx6Qy4Tq8RzmQiKp7yOCasRAWA1IhdIbkxSDXDcVsxlVWtWKNyMP4tR8VxQtXcYAAAAAElFTkSuQmCC'],
    [2, 'squiggle', "Serpentin", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABy0lEQVR4Xu1WsU7DMBA9EFLXjh36AdlaZcsGE/0FpuyZusEnsMHUGf6CLojNm0X/IUPZMlSJOoFeZFepe2cnaSWWPCmyFN/l3vPd+UI0YMA/46pF/AkRzYjqdUtEG7NeBD4CNvAiSZKljaaUeiWij0sRkQggeJokybMkUyn1RETv557GNRMgGBww5FKTmt7gCMx8yler1SGYsUN99IZLAOoX0tcQPMuyIxLGHn694BKA+kPBtYGx730KN04QrxKrHqvg12xZINi2LgE4eMEEt2CLN9Qtbgo2xqEP2LYNdQt3DzSPcR7HsbcmtNa4mL7jOH7zsdZao7jXro2bAps3m4q11hq3XhpF0YMQALbzsixDpwYCJ9c4R6AJS+Rnt9tJASbT6XTp2a8BmzzPIeaozkIEgNl4PGYDFEWB49+Ggjdw0mUhAvXFVFWVpB6KJtz+fr//Go1Gt47j3NRBsNss7onoV3g+ier9F88+5/vYZX5g2EgE8B4kpH2JGOxBvAY3jLgilHAnbKA2MKoxss8CasCnRFJvFcIfR96065QCwFcHbXIMEvgG0om18+TkVEjKO6trC6tCSgfe91LX5q/YvUjsH7JFcOQOGODDH19CzyDaididAAAAAElFTkSuQmCC'],
    [3, 'fish', "Poisson", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABw0lEQVR4Xu2WO04DMRRFLwgpW6DIHoKmc0cXVpEQpUuVji3QQTU17AI6uqnTzQJSZAFRolSga9mWZ3j+JZEoyJFGDvjzrt/HNnDhwh9zVWj/FsAI0O0GwMq0R3NTOHOklPqwc5qmeQXAv48Wcl0ogDtHXdd6mlJqaQQ9ARgbzxRRKqCDIGRaKuIkARZPyDNQJiJXAF1PF/PDYrHQtm3rC1FKi2CiZpGThDQ+NQuL9IX0whCtnJSApHEfT8gdgE/T1xHfNM2DX7qpELDs6NIiWB0mF8bCfF1JlpgADqTaIDb5JIzhx9h8EgvBqKqq5eFwENeg8fl8rlshBzRVVd0L83mCOkIC9O53u11wA+zzvxzatuXJyVPTEboLxsPh0B25IWK7l1iv1wzJe5YHtttt0LBlMpm4334+hEICuOpwYQiFYLPf78Ukkxan8dls1hEjjRsMBswperaTBxLMgRcA3/2vrutf//PHpPpNeTpCZUiFyRzI4Cs1JlaGzFZm7TInvnZMz/VvZiP+YZZ0vw8vn6jLI/18IzCU9iLjVV38ZuBkLlQqwho/CyUimLjFu8zBulGsDFMxRxk+5VVsOcvr+ML/5QeS1NB0vmBl5QAAAABJRU5ErkJggg=='],
    [4, 'arms', "Bras", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACCUlEQVR4Xu1Wu27CMBS9rSqxZisDH+ANlM1bO8FfwMzUrf2Ejp2Yy1/QCTZvkdj8AUilmwckxNTqWDZyjJ04lqpKFUeK4pDge+65D1+iK674Y9xk2O8T0ZBI313siWhLpO/J6ELAGp5wzp9CFoQQb0S06kIklQCMTznnrymuCSFeiGiZokaIgPUUgKRAsnGLVBI+gZqnRlKKSd6GFBIugUaZF4sFzefzoM2md0KImROKiyS9dXYcxmJsDeDuo+mdwYxzvsKFUPrVYwnA+0mbpDngnD/Y/xkHayRsCMaGYQ1CiI3dIDcEkXKFsx945yrgG0dNv9sfY/EHmt5FAAK6kd2Zxeh0OoW+3SKTy7JMqn8fVVXBCSrLsta48FxVFXJijxCMGWN4uICUEkyRuVPGWCcSUkrbjIBnxliNhJQS1bHUChwOhyapQGAppaTBYJBEYrfbuZ1QSx2wMUIeaAWKoggqACilbMKcz4KiKIJngVIqdBZE98feUOBLKbXu9XqPDQljG4g+8ZRSIJxyGuryPh6PMYX1HmMi+m658E0O2vYeowx9T0JI+cZHW3NbQ323FQMbZxd3nQMMLcFcMUDI70HAnWA+HUvuutOUY5CiWh8EkGDI9HN7NECrtL/buSAXUWVRBfDOeujGrfN85yFJ2dSRLAfuZIW1PVdq88FvEnDhj3k5OXXFP8UPQWTTAMqb8pQAAAAASUVORK5CYII='],
    [5, 'upright', "Tête et base", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABdklEQVR4Xu2XMU7EMBBFP4QqJ+AGKal9guwtto1S0bFHWCq2Ss8t4ARud8vcIE1aS2kC+tEGhZB4xiEIkPZJlgs7npk/tscBLvwyVwvs3wK4A7p+SAXgBHS9mhAHesMbY8z9lAVr7QHAS4gjWgdofGuM2WtCs9buADxr1LhWLBhknJwd3U6k6QsaBVJjDGUNxlq7AfDq+1BSgNFzkaXw2/Fm/YSkwOLoeyQVNAp0FEUxq4JvTFJAcuDDeJ7nk4ZofG5Mg8qBn0TlQB8h+zG+MQ030qS2bbspWZbNTvWNSUgOVE3TSGtIeGuDdAx5hh+SJJm8+yXKsmRtePRdyaICAI7OOcnWHEepHkgOkOobDoilWePAqa7rQxzHQWlwzlF+vg9WIY2i6C2kAUhXsXyGm/EJABfWNM71FqElMCKN8dWjD1UhKHrVVfwX6C6kgBRw7qp7ICT//T5RnYJ/nQJuNr582cZHVJ0CqRgNGf4Rjf+CfGMXvLwD0wGqnFmbJEkAAAAASUVORK5CYII='],
    [6, 'biped_tail', "Bipède à queue", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAB/0lEQVR4Xt1XMW7CQBCcRGnoKBFfoIBQcV1SwRdSkZqKjjyBVElFnTR5A6mS7joSCr6AQkeFReVoLJ9kGZ93z04UKSNZFsK+3Z2dmz0D/wQtAD0guf868sH4e2aMiQEMQ6OfB77AYGNjzEcajAEZfJ6uE8zARUACLrgLdmuMucq97xj4ArAGknspzqQHMpWxchdchLX2EsCn9KDEAKvuAhgZY6bSYg7W2jtN9USZBhzlS1/wxWJxkpO19hHAc90E8v0+AYNPJpPCJELgY6Ab0u8sUrbGWk/wiZCCe5IqcSwUQStCHwPi9iHYAk/w2iJcp2IKhrX2DcBrXRGSgWUcxwi9BoPBdeqSKlcsM6JkJ/T7fbX5ZLFarVRGJDmhM6Jxp9O50fZjs9nQC+41bZCc0IlxF0WRNn4QJAaIYbvdXgatCmC73XIniI4oMcAWjA6HQ2h8NJvN+X6/F3eDlEC30WhMj8djcAJRFFEHop9ICbSqBP9J0NN51Kp6zaSZIDFQF/QQ6ogiLjwhSbuAR6zgHeABNeFOSOojG7N/qNGCstaJ7XEgC1U1IL3X0xzLdwA44TR41zyUQj2y+cWTr+QlTaqoQlJb1jb+R1aTaSmJkEimIpAommDmFFOROJ39EjxN50eyWnx5cCFm7TJPPsdyzKhFlYWGAR/cqOa9cmV/jm9uRv0xB5HCzQAAAABJRU5ErkJggg=='],
    [7, 'head_legs', "Tête et jambes", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABxUlEQVR4Xu1Wu27CMBQ9tTrlAyhzfgA25K2Z4C/Ymbq1n0CXthN7/4Iu7WixtT/AXGVGJFNaHWRHIbLjG8QGR0IB7Hvv8bkPB7jiikvHzYkCDAGMgMOziV8AP8DhKUJfAi7wTGv94ItgjHkDsJYS6UOAweda66XkaMaYJwDvMTWUxJmVWhycsETnnjQdQarAVGtNWXvDGDMD8BEylChA6ekEq9UqSKBjjbbtYq0hITBiwTHAYrHwBupas8XKjvFCQiDIvgeCPiQ1UOffndSHrrWuOpAQIPvHyWTi7fsYNpsN58JzqB1vYw6s4booipMI2KEUnIwSBeo5kKapaAg5bLfb6DCSEiDGAF4Gg0EmUA15nkeDE5IUOAWmSZJku90uGn+/33/Z4RO9lEIEmrcdnQyVUsuyLOvgVVWxuL7tH2OlVF0jSqmsqqq7KNMADlUP4K/x4Ymavz9tShxo89raw3sgCp8CnFrtYrtveWIdTG2HhGTmuuuiXu8INGyetus79/oUa9tQUfFE5UY6bkvqI8J9UsJOkSP4UkBJ3asVr2DHnG3YHEZsM0obvGjODacMi8tJX7doRLFgCvoMohjO9qJ6xWXhH3YWq37RoeXfAAAAAElFTkSuQmCC'],
    [8, 'quadruped', "Quadrupède", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACFElEQVR4XuWXsU4CQRCGf40lLdGKlvK0IdlOK3gLeipjo49ApxW9la+glXab0AAlLRWGloQQCs2/uSXHMns7nJKY+CUXzXo388/s7MwK/HdOFAm4AJDl700AzAFx7SjQ+b0x5osPfwdwKazxvaPQpuPRaOQE5CIehbV2Ve+niQ+lyJiBkMoZKBNAo85Zr9fbOjTGXFeNViJWhHTeNcb0Nc6stR0Ab5p3Q2IZyA5w/g7gs4pzIglg9IxIZDAY7KwbY24AnP+mAEZ/Kxmkc9ZDKCIXXKkQwwyURh8jF9zNG9RBhEXIc//qIyxWv8dnQcJaewVgfIgCUcAhBjzW2gcAz3mrVhMKcMev1Wqpjp9nOBxWck6kPuCHTyfLMrEYi0wmEx7DuzxyDi1fjBxafnhFKZuGbhA1m82kiOl0+kQP4bv5Orc0KqRMAGk3Go1KNVFkNptFtyglwGWhXq8ns5BisViIIs4SH3Ifx6vVKmU/Sa1W6y+XSx5R2tySEuBYr9dJB0r2uqVGwHyz2SjtJ9mJXgtVPwLglewnD23sZSB1IyKuDpRqXwD3qNEIiPEh/IGXErZjCZ4kf7veohGwvZoFcDsk2HR45CQqbQFVS30g1kO4ZcyC644pNBmIUXY5jdXN3inQCJBSygEkUXQQOuO20NYOqVbs8ROSP2mYl1D+M1Ic22GrDb8RB5JWQKyg/PhVjd4/yTft8K+4QyuDhQAAAABJRU5ErkJggg=='],
    [9, 'wings', "Ailes", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACL0lEQVR4Xu1XLVMrMRQ9MNTWsrq6M0XEXMdT8BdQoKtw8BMqUdVgeH+hT/FczAqYqa4FbEXNCpiTSTrpcjeb8HiD4cxkut29yT177keywA++GXuF/isAEz/nCcBL4fx/Ap1ficgbB4CTxGq05XMOXnfiIJMSFzkXkVmm/UREFrS11t4A4LWq2H7Bglvn1toHAK89CjiIyKUnc66pkUOAb38aOxORXwAOOwjQ/qj9zKv3gUQOAcp5qTgjqXZ8Q6g0+0AiJLFDDgE1iTypncVYIRl5skM8h0Cq1DQFkmgT76sCOqistb+93I6MiJwpXtTYd4AquKpINSK19AIZJqK1lgv98eRKypTruLldCqjO47f3REIp5sS+DRe+LgITY8ysaZrOeBpjzuq6pozEqWZb1zWb0KO3OTLGxNXhwqmFwLXc8XisltJ8Psd0Ot0SWy6XN21b3lO6X9hH+Evnamd0zkej0Zs2FouFux9+eQ3gIbbl/L7+HyMOgYt7VVWzzWajSs/78SCqqjperVZ/ATz7hGRSZu+ScQhOhsOh20BSaIcgxnq9Tm48GnYIDAaDXgI5aJrmGsBdiRJOTR8/xvErRuq8sEWcA4wbWbNsQovlrqZWQwaSB5FchJPN/SdU4dbbi77NiKowqzlKQfW+RAWC8Yzzgiei1P/wrDcP+hQIYNdiZgew5mPcArgAwH7w3xCfdBnf8Jah87VVKuqIpdCO3TGBbOelHyYpfOtHyw8+jXc1C+kr8p5F8AAAAABJRU5ErkJggg=='],
    [10, 'tentacles', "Tentacules", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACNUlEQVR4Xu2WvW7bMBDHL0UAr9zagQ/ALYU3bs0kv0Im756yuY/grZ28e3FfoZ3sjZuRbHwADu2mwYsmB39BJ5xpSqQDFChQ/wBBEnXkffCOOqIbN/537t4RgE9E9EDU3iW/ieiVqL0Xc40BrHhmrX1OaXDOfSein9cYUmoAlM+ttasS15xzX4loUxKNDwULXqUcdIbOE9t0Qc6Aq5UzpUbktqCy1mJP341zbkZEv4YWKIlAy3q9HjRi7FtuG3IG9MoXi0VSEZQPfSuhyIC/yZgBSMDPUM4e4h4z9q0Da8SHVs9QErbZP51Oi+o+x+FwGDwXUga0yo0xvXLv/c4Y85hTJPHe740xX3jMe580ImVApbXuSy+EgIkvRLTUWhcbEUL4QUR/tNb9sR1CuCjJ+8greD87Ho/tcF3XONtRw5VS6pHHh6jreq+Uar1WSj1hPgzBczdnMBeYajKZnPjCVsDzaOwbEW2FzE48LxPyUhbrnXERgaZpWADeg5UYw3YgInMxdhLP8HDTNA3uHHq55gW5c0CGbNflQiUWB+gBGChFrzDEaEkCLI7Q84Vwj70j5FhUym0zc6CjJ44AvEGYGXQ38JyR3mGLUv/8OGqoKN5OcJaIsQFQiEVRLrjwLktPtlsoTYDEkh2S3BKeK/+oZy1bnIQAAiwkw8WR4ZICiIg8LTlJQZ+EXeLCISANTBoggbCcKLcgbj7lSfdRGMAOxfItuYYkhhtT6QkbJTviWC6p/MY/wRsb9NUYExxcYQAAAABJRU5ErkJggg=='],
    [11, 'multiple', "Corps multiples", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACBElEQVR4Xu1WoXICMRDd9qqwCM6cPgk2X1B+oYpqFK58AlVFodu/aL8gkqtEn2kFFhfovMyFCWGTS6C0hjeTOUgut5u3b3dDdMU/4+ZC9nMi6hPp5xcRfTbPPwGMPgkhdmbgf+PMES7BwL0Q4t21JKUcEtGHO397AU7AAAd2/u5EB+wYA3ac8ZsDO58aAmN4KISY2FaklHMiAvXfRDoMM7MupZwS0RsnxBQHYHxkf5hDYwyx7sVkQawDUcZjTuwi1gFW2SH4VH9KFuD0SCFaLBZem8wa9vgyIgk4/W65XOrCYp52ofGtQYxtlmLSMN9ut+QOG4G1VgZ8GjDpBuSDweDVhGA8HrOHQgjctaqq2Opng3NAK74sS53Hq9UK+d0ry/KhjU4bzb7ntibEhaBfFMVss9no7xVFManrem7+JwBFyVcV92A1wBir6rqedrvdfXULYb1egzXNZPNeUkvW7bTT6ewwrFZ6MG/W3ScRvWAw82xLjhEharspq3ACo5dl2YEmlFKmF+RZlmnRulBKHYnSl4agDMPQ6FI/V0o9WgZsikdKKV+EWtPShqaciEArN3y3HMTdt8doIgqoYr4PmXmu0oX2Hb0fuhHF0MW9gwso+r8LzGHtADGlOBXQAy4fldWMvGkYcqC1iAQKjRHxWThVhL8KnxPee34qYm5EoRvwFWfjBxHnAibM/v+uAAAAAElFTkSuQmCC'],
    [12, 'biped', "Bipède sans queue", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACKklEQVR4XtVWPU/DMBQ8IpZsGVHHrh1A3bzRKfwFps7txAY/gQlY2hkm/gIstJu3qh26dqxgy9SoS4IuiiUTkvgZ8SFOsuzYjn2+9/yegX+IIwAnQFH/CWKlVA4gtnYnGX6zeBELvnAEs8FZuRm/h0qpJxYAxz5rHvpMtqGUutBaF11sV9QQw5eAsX/dxgb0j2cArxIWPiYwUtun/YRSjaHUFw4kLEvQ+WhjEbTW9BEq0QqpAjw9F/SBcdJvIXBMaafTqZhAaQrnjfBRoBEtxJwxQUqg8OjxePyJBDdnfwMJ502QElhpre/E+gN0Qs5fuf6REuBJnvI8R7WMRiNMJpOitsc4XxILfK4hA8xNv98fuE61WCyuADxICEgjYZFser3eYL/ft+6/Xq9nPpFQokARAbvd7rXr5AabzUasgIRA3Ol0xBHQYLvdiki4TFBEwN1uV6ybJMk8iqLTOiWqY1EUXSdJwqmtvuBSIA7DUHT6NE0fuVsYhuc2wTRNRTmhCcMgCHIWADPTbqoB3FbH2NeWGV1x4DXLMrAAWJp2U81rl2XZnT0OgOm7MSe4fICRzGTBt1KmtvcAfaYu/DpzghR8aFDWtkLJq+P2A/YDXCZwYV4zgQrwChqw3ZgTXCb4Cig3r96y/JmbO7OiBFy4Tl6GXrHkVfiYgJ7c+iD9adCRqid9qem7lL6ICVcktEETUAVzpWhXtu8rDidKwwY+BOpgkyKhb3O4X8M7Y8DxjczaFasAAAAASUVORK5CYII='],
    [13, 'bug_wings', "Insecte ailé", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACHUlEQVR4Xu1WPU/DQAw1qGP2MGeP6BTJI1P7FzrB3IkNfgIjU2dY4C/ABJulTqDsWSF7uqUCvVMdXa75OlohkPqkU9TmbD8/+5wjOuCAf4gTIhoTmeevA0GvmPkLz32QOPJMYcLMT2ojIlMievb0UcPI09iVHQTeieizxQ/2nzpKYW9l40ugBma+FBEo4hLQwFPsccmJyDUR3cPOl0BTprYqnYEVzHwjIm9DCGxJKCK3TlZKCnvP4XxgWQ3xLgUaHYrIo4i8MPPZRsqciCZEzXJ3wBBvOwW92YDIpo5jj6wN7B5oI1A7bm0ACWaeDZEcpSMiU/e+U4Dsp+v1utHvYrGg+Xxu3iVJMkM5kiQ5czcvl0soBMAfguqqHVtXASN9HMeNjaTBbRJpmiKQDiNtWoM4jrfUSdO0OoJuE5rgURTdrFarxuzxv72AKIpmWZahEc08gL0aN/nB+yzLtBQ1BSZhGFZjtg129i7yPIcaJ2EYbpXERp7n1Qi3SzAJgqCXwBAURfECNYIgqJWgKAo0ImJUfWATMCUYjUZDB0knyrK82DSeTspa9yvsQYQN92VZoj5qhO/+1iz3wE5fSj1CmHIPRIQ7gM86H0L0uGcTVEEWP8lkr7cmqGBnjybr+q3vYNeJPgUU6FoMEMWH4/WOiNB0r30BdwEaExlhob6apd4NXZX2cmdsg01GT4xNYHBw30tpF+zvQNc98YC/hW/dY+SFsGWzmQAAAABJRU5ErkJggg=='],
    [14, 'bug', "Insecte", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACG0lEQVR4Xu1XO24CMRB9RGk4QdJwBkKHu6SCK6TaSHRUdMkR6JIG6qTiCkkFndvkDBQhDR1aUW30LDsy3vHiRSul4UmjXfzZeTOejwHO+Ge0EvRfA+jadV8ANgl7knEprAwVdpVS71yntR42TeBCIGAUWqXOcgcSIMHGIBHwQYU/WusnDiqlJgCypkmEoIWPSqmCwncAN8HYoDEXRBCSoNWUpSX13JQXqrLAkZhorVdKqVufrNb6BQCD088MF8B8MluOZk0SgSp32/j4AHAFYGjjxCBC8gAxArQgU0pNU85aa82juYuttSTfpBSOERi43G8KMRJSGtL6YVEUiMlsNovOxfb0+316M6wrYiXs9nq9yX6/F42fz+cYjUbmOR6P6zqoVMTEUpznufkwlTg4ZZzzpSZKfUSKgazT6bz6ykMSp1i/Xq9ZTUuBKHlgs9vtQAnhxrKMNSkd2+12CZhUTfKAScF2uz2VjuBU5HkueqCqFD+3Wq2iSbF95SAQK7thVSpG5lbBOH8v3BiAUirGCDBfXQleVbid/WDhzX8DZsyB/YP9gDHgcHCnkLLANCGPABUwgEK4ZkOy5sZk8WDbtzOA+++DzT0AnzHD2Ot5Xr7wPlAZL956kvd/03r/W5z/iwMpDUMweutcROliv3Xz3X0jqUWTHb3AZOfz2B1Q8ljU4hBiIappcQgGoTvfoxan/C84htq3oDPO8PELxxtR/1uDVigAAAAASUVORK5CYII='],
    [15, 'unknown', "Inconnue", 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAACNklEQVR4Xu2WMYgTQRSG/38NKFgIKsJxaqGIoBBBEjOzGNKpJ7YRFREV9NBeOLCw8RC7q9RKULEQwQNtrlAbcWdSi3gICnIQ0OZAbKKXeTKQwBjNJrs5FCRfsbDMvPf/M/PeMMCYfwxH0a/X62uazeakc24rye/tdnup0Wh8zpIzswGtdSwiUySPAtjfKyYiiyTnAcwZY74MMjOUgVqttq7Val0CME1yN4BHABYBLJOccM5NkjwdionIMoDj1trnaSYGGlBKHQBwl+QuEblorb33p4SlUmlboVB4RnJfd1xElqy123MbUEptJPkewCYAM8aYm2nJPEqpBZKHAxNT1tqFfnFRvwEPyZmOuF/NzrS5AffDnyiKNqfFpRoQkYPdYJIXlFKn0pJ1eNNTC83cBgC8DoNJPqxUKmcH7NqWYPtfGWNe5jZgrb3iz15EEgBffYtFUfQ2LSGAy/4jIh9FZHrA3MFdkIU4jq+KyHUReRFF0ZkkSVK3f1XRWs9qrUVrfXtVEw+DUuqBF1dKzQ0z/5e6yhrQi1LKXz7HALwzxuzJmq+QNSBEa30egBf3PMmTK/UeGIKwynMV3KgGdgQ9v2EIw7+R20CxWFwPILxmc9VTrqAuSql5kt9IPk6S5GmeHfg/KJfLe6vV6kSe1YzUhnEcH3LOnSN5YmVl5Q4A/2rKxEgGnHO3SHbfCUcyKXfI3QUekmsD0R9/3QCAT4Fo32dXGiMdAYAbAE4C+GCMuZaqNGZMH34C2gayeuk/DCUAAAAASUVORK5CYII='],
  ];
  const shapeLabel = (v) => { const s = SHAPES.find(([n, k]) => String(n) === String(v) || k === v); return s ? s[2] : (v ? String(v) : ''); };
  const habitatLabel = (k) => { const c = HABITATS.find(([key]) => key === k); return c ? c[1] : k; };

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
      S.loading = call('getInfos', { projectPath: p }).then((d) => {
        S.data = d && typeof d === 'object' ? d : {};
        if (!S.data.creatures || typeof S.data.creatures !== 'object') S.data.creatures = {};
        S.data.klass = 'PokedexInfosConfig';
        return S.data;
      }).catch((e) => { S.loading = null; throw e; });
    }
    return S.loading;
  }
  // valeurs d'une forme (la forme hérite de l'espèce)
  function infosOf(d, db, form) {
    const base = (d.creatures && d.creatures[db]) || {};
    const own = (base.forms && base.forms[String(form)]) || {};
    const pick = (k) => (own[k] !== undefined && own[k] !== '' && own[k] !== null ? own[k] : base[k]);
    return { color: pick('color') || '', habitat: pick('habitat') || '', shape: pick('shape') || '', generation: pick('generation'), own };
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
      .filter((el) => el.childElementCount === 0 && !(menu && menu.contains(el)) && !el.closest('[data-pjd-block], .pjd-overlay, #pjs-root, #pjv-root, #pjx-root'));
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
        && !el.closest('a, #pjs-root, #pjv-root, #pjx-root, [data-pjd-block], .pjd-overlay') && !(menu && menu.contains(el)));
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

  let current = null; // { db, form, id }
  function update() {
    const found = findPokedexBlock();
    if (!found) return;
    const { block, title } = found;
    let mine = block.parentElement.querySelector(':scope > [data-pjd-block]');
    if (!mine) {
      mine = block.cloneNode(true);
      mine.setAttribute('data-pjd-block', '1');
      mine.removeAttribute('id');
      // titre
      const leaves = [...mine.querySelectorAll('*')].filter((el) => el.childElementCount === 0 && el.textContent.trim());
      const titleLeaf = leaves.find((el) => el.textContent.trim() === 'Pokédex');
      if (titleLeaf) titleLeaf.textContent = 'Couleur, habitat, corps';
      // 3 lignes : libellé / valeur
      const rows = leaves.filter((el) => el !== titleLeaf);
      mine._rows = [];
      for (let i = 0; i + 1 < rows.length && mine._rows.length < 3; i += 2) mine._rows.push([rows[i], rows[i + 1]]);
      ['Couleur', 'Habitat', 'Apparence du corps'].forEach((l, i) => { if (mine._rows[i]) mine._rows[i][0].textContent = l; });
      mine.style.cursor = 'pointer';
      mine.title = 'Couleur, habitat et apparence du corps du Pokémon (plugin Advanced Pokédex)';
      mine.addEventListener('click', (e) => { e.preventDefault(); e.stopPropagation(); openDialog(); });
      // nouvelle case à la fin des blocs de la page Pokémon
      block.parentElement.appendChild(mine);
    }
    // la liste n° -> Pokémon (dans les données) est nécessaire pour savoir quel Pokémon est affiché
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
    data(true).then((d) => { // relu à chaque changement de Pokémon
      if (mine._key !== key) return;
      const inf = infosOf(d, sel.db, sel.form);
      setRows(mine, [
        inf.color ? colorLabel(inf.color) : '—',
        inf.habitat ? habitatLabel(inf.habitat) : '—',
        inf.shape ? shapeLabel(inf.shape) : '—',
      ]);
    }).catch((e) => setRows(mine, ['!', '!', e.message.slice(0, 40)]));
  }
  let version = 0;
  function setRows(mine, values) {
    (mine._rows || []).forEach(([, value], i) => { if (value.textContent !== values[i]) value.textContent = values[i]; });
  }

  // ---------------------------------------------------------------------------
  // Fenêtre de réglage
  // ---------------------------------------------------------------------------
  async function openDialog() {
    const sel = current;
    if (!sel) { toast('Pokémon affiché introuvable', true); return; }
    let d;
    try { d = await data(true); } catch (e) { toast('Lecture impossible : ' + e.message, true); return; }
    const entry = d.creatures[sel.db] || {};
    const formOwn = sel.form !== 0 && entry.forms && entry.forms[String(sel.form)];
    const target = { scope: formOwn ? 'form' : 'species' };
    const read = () => (target.scope === 'form' ? Object.assign({}, entry, (entry.forms || {})[String(sel.form)] || {}) : entry);
    let v = read();

    const overlay = h('div', { class: 'pjd-overlay' });
    const close = () => overlay.remove();
    overlay.addEventListener('mousedown', (e) => { if (e.target === overlay) close(); });

    const colorWrap = h('div', { class: 'pjd-colors' });
    const habitatSel = h('select', { class: 'pjs-select pjd-wide' });
    const habitatFree = h('input', { class: 'pjs-input pjd-wide', placeholder: 'Habitat personnalisé (ex. volcan)' });
    const shapeWrap = h('div', { class: 'pjd-shapes' });
    let shape = '';
    let color = '';
    const fill = () => {
      v = read();
      color = v.color || '';
      colorWrap.textContent = '';
      [['', 'Aucune', null]].concat(COLORS).forEach(([key, label, hex]) => {
        const b = h('button', { class: 'pjd-color' + (color === key ? ' active' : ''), title: label, onclick: () => { color = key; [...colorWrap.children].forEach((c) => c.classList.toggle('active', c === b)); } },
          hex ? h('span', { class: 'pjd-dot', style: { background: hex } }) : null, label);
        colorWrap.appendChild(b);
      });
      const hab = v.habitat || '';
      const known = !hab || HABITATS.some(([k]) => k === hab);
      habitatSel.textContent = '';
      [['', 'Aucun']].concat(HABITATS).concat([['__custom', 'Autre…']]).forEach(([k, l]) => habitatSel.appendChild(h('option', { value: k, selected: known ? k === hab : k === '__custom' }, l)));
      habitatFree.value = known ? '' : hab;
      habitatFree.style.display = known ? 'none' : '';
      shape = v.shape ? String((SHAPES.find(([n, k]) => String(n) === String(v.shape) || k === v.shape) || [''])[0]) : '';
      shapeWrap.textContent = '';
      shapeWrap.appendChild(h('button', { class: 'pjd-shape none' + (shape === '' ? ' active' : ''), title: 'Aucune', onclick: () => pickShape('', null) }, h('span', null, 'Aucune')));
      SHAPES.forEach(([n, k, label, src]) => {
        shapeWrap.appendChild(h('button', { class: 'pjd-shape' + (shape === String(n) ? ' active' : ''), 'data-shape': n, title: label, onclick: () => pickShape(String(n)) },
          h('img', { src }), h('span', null, label)));
      });
    };
    const pickShape = (n) => { shape = n; [...shapeWrap.children].forEach((c) => c.classList.toggle('active', (c.getAttribute('data-shape') || '') === n)); };
    habitatSel.addEventListener('change', () => { habitatFree.style.display = habitatSel.value === '__custom' ? '' : 'none'; if (habitatSel.value === '__custom') habitatFree.focus(); });

    const scope = sel.form !== 0 ? h('div', { class: 'pjs-variants' }, [['species', 'Toute l\'espèce'], [`form`, `Forme ${sel.form} seulement`]].map(([k, l]) => {
      const b = h('button', { class: 'pjs-variant' + (target.scope === k ? ' active' : ''), onclick: () => { target.scope = k; [...b.parentElement.children].forEach((c) => c.classList.toggle('active', c === b)); fill(); } }, l);
      return b;
    })) : null;

    const save = async () => {
      const habitat = habitatSel.value === '__custom' ? habitatFree.value.trim() : habitatSel.value;
      const values = { color: color || undefined, habitat: habitat || undefined, shape: shape ? Number(shape) : undefined };
      const e = d.creatures[sel.db] = d.creatures[sel.db] || {};
      let dest = e;
      if (target.scope === 'form') { e.forms = e.forms || {}; dest = e.forms[String(sel.form)] = e.forms[String(sel.form)] || {}; }
      ['color', 'habitat', 'shape'].forEach((k) => { if (values[k] === undefined) delete dest[k]; else dest[k] = values[k]; });
      if (e.forms) { Object.keys(e.forms).forEach((f) => { if (!Object.keys(e.forms[f]).length) delete e.forms[f]; }); if (!Object.keys(e.forms).length) delete e.forms; }
      if (!Object.keys(e).length) delete d.creatures[sel.db];
      try {
        await call('saveInfos', { projectPath: S.path, data: d });
        version++;
        toast('Couleur, habitat et apparence du corps enregistrés');
        close();
        update();
      } catch (err) { toast('Enregistrement impossible : ' + err.message, true); }
    };

    overlay.appendChild(h('div', { class: 'pjd-dialog' },
      h('div', { class: 'pjd-head' }, h('h2', null, 'Couleur, habitat, corps'), h('span', { class: 'pjs-hint inline' }, `${sel.db}${sel.form ? ` (forme ${sel.form})` : ''}`)),
      scope,
      h('div', { class: 'pjs-label' }, 'Couleur (Pokédex)'), colorWrap,
      h('div', { class: 'pjs-label' }, 'Habitat'), habitatSel, habitatFree,
      h('div', { class: 'pjs-label' }, 'Apparence du corps'), shapeWrap,
      h('div', { class: 'pjs-hint' }, 'Enregistré dans Data/configs/plugins/pokedex_infos.json (en jeu : pokemon.dex_color, dex_habitat, dex_shape). La génération se règle dans le bloc Groupes.'),
      h('div', { class: 'pjd-actions' },
        h('button', { class: 'pjs-btn secondary', onclick: close }, 'Annuler'),
        h('button', { class: 'pjs-btn primary', onclick: save }, 'Valider'))));
    fill();
    overlay.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); if (e.key === 'Enter' && e.target.tagName !== 'SELECT') save(); });
    document.body.appendChild(overlay);
  }

  let scheduled = false;
  const observer = new MutationObserver(() => { if (!scheduled) { scheduled = true; requestAnimationFrame(() => { scheduled = false; try { update(); } catch (e) { /* page en cours de rendu */ } }); } });
  const start = () => { observer.observe(document.body, { childList: true, subtree: true, characterData: true }); update(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);

  window.pjDexInfos = { update, data, autoGeneration };
})();

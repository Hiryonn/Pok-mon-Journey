# Pokémon Studio : vraies pages pour les éditeurs du projet (plugins, générateurs, éditeur d'événements)
#  - onglet « Générateurs » (sous Plugins) : pages des scripts qui s'inscrivent avec place: 'generator'
#  - nouvel onglet « Plugins » dans la barre de gauche (sous Base de données / Textes / Monde), avec son menu
#    (une entrée par page de plugin : Smartphone, Variantes, Triple Triad, Advanced Pokédex… et les suivantes)
#  - Monde > Événements : la page et le panneau de gauche sont laissés à l'éditeur d'événements
# Les pages sont de vraies pages de Studio (plus de page cachée en dessous). Le contenu est fait par les
# scripts pj-*.js, qui s'inscrivent dans window.pjPluginPages ; une nouvelle page de plugin n'a pas besoin
# de relancer ce script.
#  - Monde > carte > onglet « Éditeur » : éditeur de cartes façon Tiled (page « cartes » de tools/studio-cartes)
#  - Monde : bouton « Éditeur » entre « Cartes » et « Événements » (l'arbre des cartes reste à gauche, un clic
#    sur une carte l'ouvre directement dans l'éditeur)
#  - Monde : « Mettre à jour les cartes » marche sans Tiled ; les aperçus (onglet Carte) sont alors faits par
#    l'éditeur de cartes (window.pjCartesOverview), sinon par tmxrasterizer de Tiled comme avant
#  - Données > Personnages (Héros, Alliés, puis les pages des générateurs) : sous-sections visibles quand on l'ouvre ;
#    l'onglet « Générateurs » de la barre de gauche est retiré (/generators/... mène à Données > Personnages)
#  - Données > Pokémon > Variantes (Shiny / Radiant, Métaux) : pages de tools/studio-variantes, visibles quand Pokémon est ouvert
#  - Données > Gimmicks (Méga-gemmes, Capacités Z, Téracristal, Dynamax) : pages de tools/studio-gimmicks
#  - Données > Pokédex > Taille / Poids : page de l'Advanced Pokédex (tools/studio-advanced-pokedex)
#  - onglet « Code » (sous Atelier) : éditeur de code du projet façon VS Code (page « code » de tools/studio-code)
#  - onglet « Atelier » (sous Générateurs) : éditeur d'images du projet (page « atelier » de tools/studio-atelier)
# À relancer après une mise à jour de Studio (Studio doit être fermé).
# Usage : python patch_studio_pages.py   (cherche Studio dans %LOCALAPPDATA%\Programs\pokemon-studio)
#         python patch_studio_pages.py <fichier index-xxxx.js>
import glob, os, re, shutil, sys

if len(sys.argv) > 1:
    path = sys.argv[1]
else:
    base = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Programs/pokemon-studio/resources/app/.vite/renderer/main_window/assets')
    path = next(iter(sorted(glob.glob(os.path.join(base, 'index-*.js')))), None)
if not path or not os.path.exists(path):
    sys.exit('Fichier de Studio introuvable')
s = open(path, encoding='utf-8').read()
done_pages = 'pjPluginsPage' in s
done_generators = 'pjGeneratorsPage' in s
done_atelier = 'pjAtelierPage' in s
done_cartes = 'pjCartesPage' in s
done_world = 'pjWorldEditor' in s
done_world_nav = 'pjWorldNav' in s
done_overview = 'pjGenOverview' in s
done_code = 'pjCodePage' in s
done_characters = 'pjCharactersPage' in s
# sous-pages Héros / Alliés : une zone chacune (sinon React garde la même et la page ne change pas)
done_char_keys = not done_characters or 'pjPageHost,{id:`heros`},`heros`' in s
# Personnages en tête du menu Données (au-dessus de Pokémon)
done_char_top = not done_characters or 'children:[(0,j.jsx)(pjCharactersMenu,{})' in s
done_variants = 'pjPokemonMenu' in s
done_dexsize = 'pjDexMenu' in s
done_gimmicks = 'pjGimmicksMenu' in s
old_aseprite = 'pjAsepritePage' in s
if done_pages and done_generators and done_atelier and done_world and done_world_nav and done_overview and done_code and done_characters and done_char_keys and done_char_top and done_variants and done_dexsize and done_gimmicks:
    sys.exit('Déjà fait : ' + path)
if not os.path.exists(path + '.bak-pages'):
    shutil.copy(path, path + '.bak-pages')


def rep(a, b):
    global s
    if s.count(a) != 1:
        sys.exit('Version de Studio non reconnue (%s)' % a[:60])
    s = s.replace(a, b)


ICON = ('M10.5 4.5c.28 0 .5.22.5.5v2h6v6h2c.28 0 .5.22.5.5s-.22.5-.5.5h-2v6h-2.12c-.68-1.75-2.39-3-4.38-3s-3.7 1.25-4.38 3H4v-2.12'
        'c1.75-.68 3-2.39 3-4.38 0-1.99-1.24-3.7-2.99-4.38L4 7h6V5c0-.28.22-.5.5-.5m0-2C9.12 2.5 8 3.62 8 5H4c-1.1 0-1.99.9-1.99 2v3.8h.29'
        'c1.49 0 2.7 1.21 2.7 2.7s-1.21 2.7-2.7 2.7H2V20c0 1.1.9 2 2 2h3.8v-.3c0-1.49 1.21-2.7 2.7-2.7s2.7 1.21 2.7 2.7v.3H17c1.1 0 2-.9 2-2v-4'
        'c1.38 0 2.5-1.12 2.5-2.5S20.38 11 19 11V7c0-1.1-.9-2-2-2h-4c0-1.38-1.12-2.5-2.5-2.5z')

DEFS = (
    # icône de l'onglet
    ',pjIcon=(Yl.plugins=e=>p.createElement(`svg`,{viewBox:`0 0 24 24`,fill:`currentColor`,xmlns:`http://www.w3.org/2000/svg`,...e},'
    'p.createElement(`path`,{d:`' + ICON + '`,fill:`currentColor`})),0)'
    # pages inscrites par les scripts : window.pjPluginPages = [{id, label, order?, place?}]
    ',pjUseAllPages=()=>{let[e,t]=(0,p.useState)(()=>(window.pjPluginPages||[]).slice());(0,p.useEffect)(()=>{let n=()=>t((window.pjPluginPages||[]).slice());'
    'window.addEventListener(`pj-plugin-pages`,n),n();return()=>window.removeEventListener(`pj-plugin-pages`,n)},[]);'
    'return e.slice().sort((e,t)=>(e.order??500)-(t.order??500)||String(e.label).localeCompare(String(t.label)))}'
    ',pjUsePluginPages=()=>pjUseAllPages().filter(e=>!e.place)'
    # zone remplie par un script (id : pj-page-<id>)
    ',pjPageHost=({id:e,column:t,remember:n})=>((0,p.useEffect)(()=>{if(n)try{sessionStorage.setItem(`lastPluginPage`,e)}catch{}},[e,n]),'
    '(0,j.jsx)(`div`,{id:`pj-page-${e}`,className:`pj-page-host`,"data-pj-page":e,style:t?{display:`flex`,flexDirection:`column`,flex:`1 1 auto`,minHeight:0}:'
    '{display:`flex`,flex:`1 1 auto`,minWidth:0,width:`100%`}}))'
    # navigation pour les raccourcis clavier des scripts : window.pjNavigate('/plugins/variantes')
    ',pjNavBridge=()=>{let e=ra();return(0,p.useEffect)(()=>{window.pjNavigate=e},[e]),null}'
    # onglet Plugins : menu + page
    ',pjPluginsMenu=()=>{let e=pjUsePluginPages();return(0,j.jsx)(z$,{children:(0,j.jsx)(L$,{title:`Plugins`,children:e.length?e.map(e=>(0,j.jsx)(R$,{path:`/plugins/${e.id}`,label:e.label},e.id))'
    ':(0,j.jsx)(`span`,{style:{padding:`8px 16px`,opacity:.6},children:`Aucun plugin`})})})}'
    ',pjPluginsPage=()=>{let e=pjUsePluginPages(),t=null;try{t=sessionStorage.getItem(`lastPluginPage`)}catch{}let n=e.some(e=>e.id===t)?t:e[0]?.id;'
    'return(0,j.jsxs)(Y0a,{children:[(0,j.jsx)(pjPluginsMenu,{}),(0,j.jsxs)(Ma,{children:[...e.map(e=>(0,j.jsx)(Aa,{path:e.id,element:(0,j.jsx)(pjPageHost,{id:e.id,remember:!0},e.id)},e.id)),'
    'n?(0,j.jsx)(Aa,{path:`/`,element:(0,j.jsx)(Oa,{to:n,replace:!0})},`__index`):null]})]})}'
    # Monde > Événements : panneau de gauche de l'éditeur d'événements
    ',pjEventsSide=()=>pjUseAllPages().some(e=>e.id===`events`)?(0,j.jsx)(xco,{children:(0,j.jsx)(pjPageHost,{id:`events-side`,column:!0})}):(0,j.jsx)(Cco,{})'
)

if not done_pages:
    # barre de gauche : onglet Plugins après Monde
    rep('(0,j.jsx)(Fya,{path:`/world`,onMouseLeave:i,onMouseEnter:r(n(`world_management`),`right-center`,!0)})',
        '(0,j.jsx)(Fya,{path:`/world`,onMouseLeave:i,onMouseEnter:r(n(`world_management`),`right-center`,!0)}),'
        '(0,j.jsx)(wl,{path:`/plugins`,onMouseLeave:i,onMouseEnter:r(`Plugins`,`right-center`,!0),children:(0,j.jsx)(Zl,{color:e.colors.navigationIconColor,size:`s`,icon:`plugins`})})')
    # routes
    rep('(0,j.jsx)(Aa,{path:`/texts/*`,element:(0,j.jsx)($2a,{})}),',
        '(0,j.jsx)(Aa,{path:`/texts/*`,element:(0,j.jsx)($2a,{})}),(0,j.jsx)(Aa,{path:`/plugins/*`,element:(0,j.jsx)(pjPluginsPage,{})}),')
    rep('(0,j.jsx)(tba,{}),(0,j.jsxs)(Ma,{children:[(0,j.jsx)(Aa,{path:`/home`,element:(0,j.jsx)(BOa,{})})',
        '(0,j.jsx)(tba,{}),(0,j.jsx)(pjNavBridge,{}),(0,j.jsxs)(Ma,{children:[(0,j.jsx)(Aa,{path:`/home`,element:(0,j.jsx)(BOa,{})})')
    # Monde > Événements
    rep('Xuo=()=>{let{event:e,hasEventAvailable:t}=PAa(),n=Gm();return window.api.isDev?',
        'Xuo=()=>{let{event:e,hasEventAvailable:t}=PAa(),n=Gm(),pjE=pjUseAllPages().some(e=>e.id===`events`);return pjE?(0,j.jsx)(pjPageHost,{id:`events`}):window.api.isDev?')
    rep('case r.events:return(0,j.jsx)(Cco,{});', 'case r.events:return(0,j.jsx)(pjEventsSide,{});')
    # définitions
    rep(',Pdo=()=>(0,j.jsx)(k6a,', DEFS + ',Pdo=()=>(0,j.jsx)(k6a,')


WAND = ('M7.5 5.6L10 7 8.6 4.5 10 2 7.5 3.4 5 2l1.4 2.5L5 7zm12 9.8L17 14l1.4 2.5L17 19l2.5-1.4L22 19l-1.4-2.5L22 14zM22 2l-2.5 1.4L17 2'
        'l1.4 2.5L17 7l2.5-1.4L22 7l-1.4-2.5zm-7.63 5.29c-.39-.39-1.02-.39-1.41 0L1.29 18.96c-.39.39-.39 1.02 0 1.41l2.34 2.34c.39.39 1.02.39 1.41 0'
        'L16.7 11.05c.39-.39.39-1.02 0-1.41l-2.33-2.35zm-1.03 5.49l-2.12-2.12 2.44-2.44 2.12 2.12-2.44 2.44z')
GEN_DEFS = (
    ',pjWand=(Yl.generators=e=>p.createElement(`svg`,{viewBox:`0 0 24 24`,fill:`currentColor`,xmlns:`http://www.w3.org/2000/svg`,...e},'
    'p.createElement(`path`,{d:`' + WAND + '`,fill:`currentColor`})),0)'
    ',pjUseGeneratorPages=()=>pjUseAllPages().filter(e=>e.place===`generator`)'
    ',pjGeneratorsMenu=()=>{let e=pjUseGeneratorPages();return(0,j.jsx)(z$,{children:(0,j.jsx)(L$,{title:`Générateurs`,children:e.length?e.map(e=>(0,j.jsx)(R$,{path:`/generators/${e.id}`,label:e.label},e.id))'
    ':(0,j.jsx)(`span`,{style:{padding:`8px 16px`,opacity:.6},children:`Aucun générateur`})})})}'
    ',pjGeneratorsPage=()=>{let e=pjUseGeneratorPages(),t=null;try{t=sessionStorage.getItem(`lastGeneratorPage`)}catch{}let n=e.some(e=>e.id===t)?t:e[0]?.id;'
    'return(0,j.jsxs)(Y0a,{children:[(0,j.jsx)(pjGeneratorsMenu,{}),(0,j.jsxs)(Ma,{children:[...e.map(e=>(0,j.jsx)(Aa,{path:e.id,element:(0,j.jsx)(pjGenHost,{id:e.id},e.id)},e.id)),'
    'n?(0,j.jsx)(Aa,{path:`/`,element:(0,j.jsx)(Oa,{to:n,replace:!0})},`__index`):null]})]})}'
    ',pjGenHost=({id:e})=>((0,p.useEffect)(()=>{try{sessionStorage.setItem(`lastGeneratorPage`,e)}catch{}},[e]),(0,j.jsx)(pjPageHost,{id:e}))'
)
if not done_generators:
    # onglet Générateurs sous Plugins
    rep('icon:`plugins`})})', 'icon:`plugins`})}),(0,j.jsx)(wl,{path:`/generators`,onMouseLeave:i,onMouseEnter:r(`Générateurs`,`right-center`,!0),children:(0,j.jsx)(Zl,{color:e.colors.navigationIconColor,size:`s`,icon:`generators`})})')
    rep('(0,j.jsx)(Aa,{path:`/plugins/*`,element:(0,j.jsx)(pjPluginsPage,{})}),', '(0,j.jsx)(Aa,{path:`/plugins/*`,element:(0,j.jsx)(pjPluginsPage,{})}),(0,j.jsx)(Aa,{path:`/generators/*`,element:(0,j.jsx)(pjGeneratorsPage,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', GEN_DEFS + ',Pdo=()=>(0,j.jsx)(k6a,')

PALETTE = ('M12 3c-4.97 0-9 4.03-9 9s4.03 9 9 9c.83 0 1.5-.67 1.5-1.5 0-.39-.15-.74-.39-1.01-.23-.26-.38-.61-.38-.99 0-.83.67-1.5 1.5-1.5H16'
           'c2.76 0 5-2.24 5-5 0-4.42-4.03-8-9-8zm-5.5 9c-.83 0-1.5-.67-1.5-1.5S5.67 9 6.5 9 8 9.67 8 10.5 7.33 12 6.5 12zm3-4C8.67 8 8 7.33 8 6.5'
           'S8.67 5 9.5 5s1.5.67 1.5 1.5S10.33 8 9.5 8zm5 0c-.83 0-1.5-.67-1.5-1.5S13.67 5 14.5 5s1.5.67 1.5 1.5S15.33 8 14.5 8zm3 4c-.83 0-1.5-.67-1.5-1.5'
           'S16.67 9 17.5 9s1.5.67 1.5 1.5-.67 1.5-1.5 1.5z')
ATELIER_DEFS = (
    ',pjPalette=(Yl.atelier=e=>p.createElement(`svg`,{viewBox:`0 0 24 24`,fill:`currentColor`,xmlns:`http://www.w3.org/2000/svg`,...e},'
    'p.createElement(`path`,{d:`' + PALETTE + '`,fill:`currentColor`})),0)'
    ',pjAtelierPage=()=>(0,j.jsx)(Y0a,{children:(0,j.jsx)(pjPageHost,{id:`atelier`})})'
)
if old_aseprite:
    # ancienne section « Aseprite » -> « Atelier »
    for a, b in [('Yl.aseprite=', 'Yl.atelier='), ('pjAsepritePage', 'pjAtelierPage'), ('{id:`aseprite`}', '{id:`atelier`}'),
                 ('path:`/aseprite`', 'path:`/atelier`'), ('r(`Aseprite`', 'r(`Atelier`'), ('icon:`aseprite`', 'icon:`atelier`'), ('path:`/aseprite/*`', 'path:`/atelier/*`')]:
        s = s.replace(a, b)
elif not done_atelier:
    # onglet Atelier sous Générateurs
    rep('icon:`generators`})})', 'icon:`generators`})}),(0,j.jsx)(wl,{path:`/atelier`,onMouseLeave:i,onMouseEnter:r(`Atelier`,`right-center`,!0),children:(0,j.jsx)(Zl,{color:e.colors.navigationIconColor,size:`s`,icon:`atelier`})})')
    rep('(0,j.jsx)(Aa,{path:`/generators/*`,element:(0,j.jsx)(pjGeneratorsPage,{})}),', '(0,j.jsx)(Aa,{path:`/generators/*`,element:(0,j.jsx)(pjGeneratorsPage,{})}),(0,j.jsx)(Aa,{path:`/atelier/*`,element:(0,j.jsx)(pjAtelierPage,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', ATELIER_DEFS + ',Pdo=()=>(0,j.jsx)(k6a,')

MAP = ('M20.5 3l-.16.03L15 5.1 9 3 3.36 4.9c-.21.07-.36.25-.36.48V20.5c0 .28.22.5.5.5l.16-.03L9 18.9l6 2.1 5.64-1.9c.21-.07.36-.25.36-.48V3.5'
       'c0-.28-.22-.5-.5-.5zM15 19l-6-2.11V5l6 2.11V19z')
CARTES_DEFS = (
    ',pjMapIcon=(Yl.cartes=e=>p.createElement(`svg`,{viewBox:`0 0 24 24`,fill:`currentColor`,xmlns:`http://www.w3.org/2000/svg`,...e},'
    'p.createElement(`path`,{d:`' + MAP + '`,fill:`currentColor`})),0)'
    ',pjCartesPage=()=>(0,j.jsx)(Y0a,{children:(0,j.jsx)(pjPageHost,{id:`cartes`})})'
)
if False and not done_cartes:
    # (ancien) onglet Cartes sous Atelier
    rep('icon:`atelier`})})', 'icon:`atelier`})}),(0,j.jsx)(wl,{path:`/cartes`,onMouseLeave:i,onMouseEnter:r(`Cartes`,`right-center`,!0),children:(0,j.jsx)(Zl,{color:e.colors.navigationIconColor,size:`s`,icon:`cartes`})})')
    rep('(0,j.jsx)(Aa,{path:`/atelier/*`,element:(0,j.jsx)(pjAtelierPage,{})}),', '(0,j.jsx)(Aa,{path:`/atelier/*`,element:(0,j.jsx)(pjAtelierPage,{})}),(0,j.jsx)(Aa,{path:`/cartes/*`,element:(0,j.jsx)(pjCartesPage,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', CARTES_DEFS + ',Pdo=()=>(0,j.jsx)(k6a,')

WORLD_DEFS = (
    ',pjWorldEditor=()=>{let{map:e,disabledOpenTiled:t}=U1(),{t:n}=M();(0,p.useEffect)(()=>{window.pjWorldMap=e?{dbSymbol:e.dbSymbol,id:e.id,tiledFilename:e.tiledFilename||``}:null;'
    'window.dispatchEvent(new Event(`pj-world-map`))},[e?.dbSymbol,e?.tiledFilename]);'
    'return(0,j.jsxs)(`div`,{style:{display:`flex`,flexDirection:`column`,gap:`12px`,width:`100%`,minWidth:0,height:`calc(100vh - 26px)`,padding:`16px 16px 0 16px`,boxSizing:`border-box`},children:['
    '(0,j.jsxs)(UY,{children:[(0,j.jsx)($so,{}),(0,j.jsx)(n0,{currentTabIndex:2,tabs:[{label:n(`data`),path:`/world/map`},{label:n(`map`),path:`/world/overview`,disabled:t},{label:`Éditeur`,path:`/world/editor`,disabled:t}]})]}),'
    '(0,j.jsx)(`div`,{style:{flex:`1 1 auto`,minHeight:0,display:`flex`},children:(0,j.jsx)(pjPageHost,{id:`cartes`})})]})}'
)
if not done_world:
    # Monde : onglet « Éditeur » à côté de « Données » et « Carte » (la carte choisie dans l'arbre s'ouvre dans l'éditeur)
    rep('tabs:[{label:s(`data`),path:`/world/map`},{label:s(`map`),path:`/world/overview`,disabled:i}]', 'tabs:[{label:s(`data`),path:`/world/map`},{label:s(`map`),path:`/world/overview`,disabled:i},{label:`Éditeur`,path:`/world/editor`,disabled:i}]')
    rep('tabs:[{label:s(`data`),path:`/world/map`},{label:s(`map`),path:`/world/overview`,disabled:t}]', 'tabs:[{label:s(`data`),path:`/world/map`},{label:s(`map`),path:`/world/overview`,disabled:t},{label:`Éditeur`,path:`/world/editor`,disabled:t}]')
    rep('t.pathname.match(/^\\/world\\/(map|overview|maplink)/)', 't.pathname.match(/^\\/world\\/(map|overview|maplink|editor)/)')
    rep('(0,j.jsx)(Aa,{path:`overview`,element:(0,j.jsx)(Pco,{})}),', '(0,j.jsx)(Aa,{path:`overview`,element:(0,j.jsx)(Pco,{})}),(0,j.jsx)(Aa,{path:`editor`,element:(0,j.jsx)(pjWorldEditor,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', WORLD_DEFS + ',Pdo=()=>(0,j.jsx)(k6a,')
    # l'ancien onglet « Cartes » de la barre de gauche est retiré (l'éditeur est dans Monde)
    s = s.replace(',(0,j.jsx)(wl,{path:`/cartes`,onMouseLeave:i,onMouseEnter:r(`Cartes`,`right-center`,!0),children:(0,j.jsx)(Zl,{color:e.colors.navigationIconColor,size:`s`,icon:`cartes`})})', '')
    s = s.replace('(0,j.jsx)(Aa,{path:`/cartes/*`,element:(0,j.jsx)(pjCartesPage,{})}),', '')

if not done_world_nav:
    # Monde : bouton « Éditeur » entre « Cartes » et « Événements » ; l'arbre des cartes reste affiché
    rep('n=!!t.pathname.match(/^\\/world\\/(map|overview|maplink|editor)/),r={events:`/world/events`,map:`/world/map`,maplink:`/world/maplink2`}',
        'n=!!t.pathname.match(/^\\/world\\/(map|overview|maplink)/),r={events:`/world/events`,map:`/world/map`,maplink:`/world/maplink2`,editor:`/world/editor`}')
    rep('(0,j.jsx)(R$,{path:r.map,label:e(`maps`),activeForced:n}),(0,j.jsx)(R$,{path:r.events,label:e(`events`)})',
        '(0,j.jsx)(R$,{path:r.map,label:e(`maps`),activeForced:n}),(0,j.jsx)(R$,{path:r.editor,label:`Éditeur`,"data-pj":`pjWorldNav`}),(0,j.jsx)(R$,{path:r.events,label:e(`events`)})')
    # un clic sur une carte de l'arbre garde l'éditeur ouvert (au lieu de revenir à « Données »)
    rep('d.pathname!==`/world/map`&&d.pathname!==`/world/overview`&&u(`/world/map`)',
        'd.pathname!==`/world/map`&&d.pathname!==`/world/overview`&&d.pathname!==`/world/editor`&&u(`/world/map`)')

if not done_overview:
    # aperçus des cartes : Tiled (tmxrasterizer) s'il est configuré, sinon l'éditeur de cartes du projet
    s = s.replace('window.api.generatingMapOverview(', 'pjGenOverview(')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', ',pjNoOverview=()=>!mY(`tiledPath`)&&!window.pjCartesOverview'
        ',pjGenOverview=(e,t,n)=>{if(mY(`tiledPath`)||!window.pjCartesOverview)return window.api.generatingMapOverview(e,t,n);'
        'window.pjCartesOverview(e.tiledFilename).then(()=>t({}),e=>n({errorMessage:String(e&&e.message||e)}));return()=>{}}'
        ',Pdo=()=>(0,j.jsx)(k6a,')
    # boutons « Mettre à jour les cartes » et « Générer l'aperçu » : plus grisés sans Tiled
    rep('n=Am(),r=!mY(`tiledPath`);return(0,j.jsxs)(Zoo,', 'n=Am(),r=pjNoOverview();return(0,j.jsxs)(Zoo,')
    rep('r=Yoo(),i=Am(),a=!mY(`tiledPath`);', 'r=Yoo(),i=Am(),a=pjNoOverview();')
    rep('disabledGenerating:!mY(`tiledPath`)', 'disabledGenerating:pjNoOverview()')

if not done_code:
    # onglet Code sous Atelier (icône « code » de Studio) ; la route /code de Studio était vide
    rep('icon:`atelier`})})', 'icon:`atelier`})}),(0,j.jsx)(wl,{path:`/code`,onMouseLeave:i,onMouseEnter:r(`Code`,`right-center`,!0),children:(0,j.jsx)(Zl,{color:e.colors.navigationIconColor,size:`s`,icon:`code`})})')
    rep('(0,j.jsx)(Aa,{path:`/code`}),', '(0,j.jsx)(Aa,{path:`/code/*`,element:(0,j.jsx)(pjCodePage,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', ',pjCodePage=()=>(0,j.jsx)(Y0a,{children:(0,j.jsx)(pjPageHost,{id:`code`})}),Pdo=()=>(0,j.jsx)(k6a,')

if not done_char_top:
    rep(',(0,j.jsx)(pjCharactersMenu,{})]})', ']})')
    rep('L$,{title:e(`data`),children:[(0,j.jsx)(R$,{path:`/database/pokemon`,',
        'L$,{title:e(`data`),children:[(0,j.jsx)(pjCharactersMenu,{}),(0,j.jsx)(R$,{path:`/database/pokemon`,')

if not done_char_keys:
    for k in ('heros', 'allies'):
        rep('(0,j.jsx)(pjPageHost,{id:`%s`})' % k, '(0,j.jsx)(pjPageHost,{id:`%s`},`%s`)' % (k, k))

if not done_characters:
    # Données > Personnages : entrée du menu, avec ses sous-sections quand elle est ouverte
    rep('L$,{title:e(`data`),children:[(0,j.jsx)(R$,{path:`/database/pokemon`,',
        'L$,{title:e(`data`),children:[(0,j.jsx)(pjCharactersMenu,{}),(0,j.jsx)(R$,{path:`/database/pokemon`,')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`characters/*`,element:(0,j.jsx)(pjCharactersPage,{})}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', ',pjGenLabel=e=>e.id===`personnages`?`Générateur`:e.label'
        ',pjSubNav=(e,t)=>(0,j.jsx)(R$,{path:`/database/characters/${e}`,label:(0,j.jsx)(`span`,{className:`pj-subnav`,children:t})},e)'
        ',pjCharactersMenu=()=>{let e=ta(),t=e.pathname.startsWith(`/database/characters`),n=pjUseGeneratorPages();'
        'return(0,j.jsxs)(p.Fragment,{children:[(0,j.jsx)(HOa,{to:`/database/characters`,end:!0,children:(0,j.jsx)(VOa,{children:(0,j.jsxs)(`span`,{className:`pj-navparent`+(t?` open`:``),children:[`Personnages`,(0,j.jsx)(`span`,{className:`caret`,children:`▶`})]})})}),'
        't?pjSubNav(`heros`,`Héros`):null,t?pjSubNav(`allies`,`Alliés`):null,...(t?n.map(e=>pjSubNav(e.id,pjGenLabel(e))):[])]})}'
        ',pjCharactersPage=()=>{H$();let e=pjUseGeneratorPages();return(0,j.jsxs)(Ma,{children:[(0,j.jsx)(Aa,{path:`heros`,element:(0,j.jsx)(pjPageHost,{id:`heros`},`heros`)}),'
        '(0,j.jsx)(Aa,{path:`allies`,element:(0,j.jsx)(pjPageHost,{id:`allies`},`allies`)}),...e.map(e=>(0,j.jsx)(Aa,{path:e.id,element:(0,j.jsx)(pjGenHost,{id:e.id},e.id)},e.id)),'
        '(0,j.jsx)(Aa,{path:`*`,element:(0,j.jsx)(Oa,{to:`heros`,replace:!0})})]})}'
        ',pjGenRedirect=()=>{let e=ta().pathname.split(`/`)[2]||``;return(0,j.jsx)(Oa,{to:`/database/characters/${e}`,replace:!0})}'
        ',Pdo=()=>(0,j.jsx)(k6a,')
    # l'onglet « Générateurs » de la barre de gauche devient Données > Personnages
    s = re.sub(r'\(0,j\.jsx\)\(wl,\{path:`/generators`,onMouseLeave:i,onMouseEnter:r\(`Générateurs`,`right-center`,!0\),children:\(0,j\.jsx\)\(Zl,\{color:e\.colors\.navigationIconColor,size:`s`,icon:`generators`\}\)\}\),', '', s, count=1)
    rep('(0,j.jsx)(Aa,{path:`/generators/*`,element:(0,j.jsx)(pjGeneratorsPage,{})})', '(0,j.jsx)(Aa,{path:`/generators/*`,element:(0,j.jsx)(pjGenRedirect,{})})')

if not done_variants:
    # Données > Pokémon : sous-sections Variantes (Shiny / Radiant, Métaux) quand on est sur un Pokémon ou une variante
    rep('(0,j.jsx)(R$,{path:`/database/pokemon`,label:e(`creature`)})', '(0,j.jsx)(pjPokemonMenu,{label:e(`creature`)})')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`variants/shiny`,element:(0,j.jsx)(pjVarHost,{id:`variants-shiny`},`variants-shiny`)}),'
        '(0,j.jsx)(Aa,{path:`variants/metals`,element:(0,j.jsx)(pjVarHost,{id:`variants-metals`},`variants-metals`)}),'
        '(0,j.jsx)(Aa,{path:`variants`,element:(0,j.jsx)(Oa,{to:`shiny`,replace:!0})}),'
        '(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', ',pjSubLink=(e,t)=>(0,j.jsx)(R$,{path:e,label:(0,j.jsx)(`span`,{className:`pj-subnav`,children:t})},e)'
        ',pjPokemonMenu=({label:e})=>{let t=ta().pathname,n=t.startsWith(`/database/pokemon`)||t.startsWith(`/database/variants`);'
        'return(0,j.jsxs)(p.Fragment,{children:[(0,j.jsx)(R$,{path:`/database/pokemon`,label:(0,j.jsxs)(`span`,{className:`pj-navparent`+(n?` open`:``),children:[e,(0,j.jsx)(`span`,{className:`caret`,children:`▶`})]})}),'
        'n?(0,j.jsx)(`div`,{className:`pj-subhead`,children:`Variantes`}):null,n?pjSubLink(`/database/variants/shiny`,`Shiny / Radiant`):null,n?pjSubLink(`/database/variants/metals`,`Métaux`):null]})}'
        ',pjVarHost=({id:e})=>(H$(),(0,j.jsx)(pjPageHost,{id:e}))'
        ',Pdo=()=>(0,j.jsx)(k6a,')

if not done_dexsize:
    # Données > Pokédex : sous-section Taille / Poids (page de l'Advanced Pokédex) quand on est sur le Pokédex
    rep('(0,j.jsx)(R$,{path:`/database/dex`,label:e(`bestiary`)})', '(0,j.jsx)(pjDexMenu,{label:e(`bestiary`)})')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`dex-size`,element:(0,j.jsx)(pjVarHost,{id:`advanced-pokedex`},`advanced-pokedex`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', ',pjDexMenu=({label:e})=>{let t=ta().pathname,n=t.startsWith(`/database/dex`);'
        'return(0,j.jsxs)(p.Fragment,{children:[(0,j.jsx)(HOa,{to:`/database/dex`,end:!0,children:(0,j.jsx)(VOa,{children:(0,j.jsxs)(`span`,{className:`pj-navparent`+(n?` open`:``),children:[e,(0,j.jsx)(`span`,{className:`caret`,children:`▶`})]})})}),'
        'n?pjSubLink(`/database/dex-size`,`Taille / Poids`):null]})}'
        ',Pdo=()=>(0,j.jsx)(k6a,')

if not done_gimmicks:
    # Données > Gimmicks : une sous-section par mécanique, visibles quand on l'ouvre (page de tools/studio-gimmicks)
    rep('(0,j.jsx)(R$,{path:`/database/natures`,label:e(`natures`)})]})', '(0,j.jsx)(R$,{path:`/database/natures`,label:e(`natures`)}),(0,j.jsx)(pjGimmicksMenu,{})]})')
    routes = ''.join('(0,j.jsx)(Aa,{path:`gimmicks/%s`,element:(0,j.jsx)(pjVarHost,{id:`gimmicks-%s`},`gimmicks-%s`)}),' % (k, k, k) for k in ('mega', 'zmove', 'tera', 'dynamax'))
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        routes + '(0,j.jsx)(Aa,{path:`gimmicks`,element:(0,j.jsx)(Oa,{to:`mega`,replace:!0})}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', ',pjGimmicksMenu=()=>{let t=ta().pathname.startsWith(`/database/gimmicks`);'
        'return(0,j.jsxs)(p.Fragment,{children:[(0,j.jsx)(HOa,{to:`/database/gimmicks`,end:!0,children:(0,j.jsx)(VOa,{children:(0,j.jsxs)(`span`,{className:`pj-navparent`+(t?` open`:``),children:[`Gimmicks`,(0,j.jsx)(`span`,{className:`caret`,children:`▶`})]})})}),'
        't?pjSubLink(`/database/gimmicks/mega`,`Méga-gemmes`):null,t?pjSubLink(`/database/gimmicks/zmove`,`Capacités Z`):null,'
        't?pjSubLink(`/database/gimmicks/tera`,`Téracristal`):null,t?pjSubLink(`/database/gimmicks/dynamax`,`Dynamax`):null]})}'
        ',Pdo=()=>(0,j.jsx)(k6a,')

open(path, 'w', encoding='utf-8').write(s)
print('Pages des plugins ajoutées dans Studio (' + path + '). Redémarre Pokémon Studio.')

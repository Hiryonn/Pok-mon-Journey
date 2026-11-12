# Pokémon Studio : vraies pages pour les éditeurs du projet (plugins, générateurs, éditeur d'événements)
#  - onglet « Générateurs » (sous Plugins) : pages des scripts qui s'inscrivent avec place: 'generator'
#  - nouvel onglet « Plugins » dans la barre de gauche (sous Base de données / Textes / Monde), avec son menu
#    (une entrée par page de plugin : Smartphone, Variantes, Triple Triad, Advanced Pokédex… et les suivantes)
#  - Monde > Événements : la page et le panneau de gauche sont laissés à l'éditeur d'événements
# Les pages sont de vraies pages de Studio (plus de page cachée en dessous). Le contenu est fait par les
# scripts pj-*.js, qui s'inscrivent dans window.pjPluginPages ; une nouvelle page de plugin n'a pas besoin
# de relancer ce script.
#  - onglet « Atelier » (sous Générateurs) : éditeur d'images du projet (page « atelier » de tools/studio-atelier)
# À relancer après une mise à jour de Studio (Studio doit être fermé).
# Usage : python patch_studio_pages.py   (cherche Studio dans %LOCALAPPDATA%\Programs\pokemon-studio)
#         python patch_studio_pages.py <fichier index-xxxx.js>
import glob, os, shutil, sys

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
old_aseprite = 'pjAsepritePage' in s
if done_pages and done_generators and done_atelier:
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

open(path, 'w', encoding='utf-8').write(s)
print('Pages des plugins ajoutées dans Studio (' + path + '). Redémarre Pokémon Studio.')

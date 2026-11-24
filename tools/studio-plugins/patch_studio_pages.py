# Pokémon Studio : vraies pages pour les éditeurs du projet (plugins, générateurs, éditeur d'événements)
#  - onglet « Générateurs » (sous Plugins) : pages des scripts qui s'inscrivent avec place: 'generator'
#  - (ancien) onglet « Plugins » dans la barre de gauche, retiré ensuite (sous Base de données / Textes / Monde), avec son menu
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
#  - Données > Statuts : page de tools/studio-statuts
#  - Données > Attaques > Animations : éditeur d'animations des attaques (tools/studio-anim)
#  - Level design > Interface > Smartphone : page de tools/studio-smartphone
#  - Level design > Mini-jeux > Triple Triad : page de tools/studio-triple-triad
#  - Level design > Mini-jeux > Quel est ce Pokémon : page de tools/studio-quelpokemon
#  - Level design > Interface > Succès : page de tools/studio-succes (après Smartphone)
#  - Level design > Magasins : page de tools/studio-magasins (avant Interface)
#  - Level design > Carte de région : page de tools/studio-carte-region (avant Magasins)
#  - Level design : Zones > Groupes, Dresseurs > Classes de dresseurs, Interface > Boutique (magasins) et Quêtes
#  - Level design > Dresseurs > Étui à badges : page de tools/studio-etui-badges (après Classes de dresseurs)
#  - Cartes du monde : l'éditeur de PSDK (menu Jouer) et la position sur la carte du monde des zones sont retirés
#    (tout se fait dans Level design > Carte de région)
#  - Données > Baies > Berrydex : page de tools/studio-berrydex (section après Objets)
#  - Données > Baies > Pots à baies : page de tools/studio-pots-baies (après Berrydex)
#  - Données > Pokémon > Rubans et insignes : page de tools/studio-mementos (après les Variantes)
#  - Données > Pokémon > Réglages : Natures et Statuts (retirés de la liste Données) et Groupes d'Œuf (page de tools/studio-egg-groups)
#  - Données > Pokédex > Taille / Poids : page de l'Advanced Pokédex (tools/studio-advanced-pokedex)
#  - Données > Pokédex > Tâches, Données > Baies > Champs de baies, Données > Gimmicks > Styles PLA,
#    Level design > Mini-jeux > Sac de frappe et Poké Récré : pages de tools/studio-reglages
#  - Données > Gimmicks > Raids et Level design > Carte de région > Cartes d'aventure : pages de tools/studio-reglages
#  - Level design > Dresseurs > Tournois : page de tools/studio-reglages (après Étui à badges)
#  - Données > Gimmicks > Pokémon Obscurs : page de tools/studio-reglages (après Raids)
#  - Données > Personnages > Montures : page de tools/studio-reglages (après Alliés)
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
# repères cherchés avec les noms de la version d'origine (Studio renomme (0,j.jsx) en (0,M.jsx)…)
chk = re.sub(r'\(0,[A-Za-z_$][\w$]*\.(jsxs?)\)', r'(0,j.\1)', s)
done_pages = 'pjPluginsPage' in chk
done_generators = 'pjGeneratorsPage' in chk
done_atelier = 'pjAtelierPage' in chk
done_cartes = 'pjCartesPage' in chk
done_world = 'pjWorldEditor' in chk
done_world_nav = 'pjWorldNav' in chk
done_overview = 'pjGenOverview' in chk
done_code = 'pjCodePage' in chk
done_characters = 'pjCharactersPage' in chk
# sous-pages Héros / Alliés : une zone chacune (sinon React garde la même et la page ne change pas)
done_char_keys = not done_characters or 'pjPageHost,{id:`heros`},`heros`' in chk
# Personnages en tête du menu Données (au-dessus de Pokémon)
# Personnages doit précéder le lien Pokémon dans la liste de Données (d'autres entrées, comme Plugins, peuvent être posées avant lui)
done_char_top = not done_characters or re.search(r'pjCharactersMenu,\{\}\)(?:(?!\]\}\)).){0,400}?(?:/database/pokemon`|pjPokemonMenu)', chk) is not None
done_variants = 'pjPokemonMenu' in chk
done_dexsize = 'pjDexMenu' in chk
done_gimmicks = 'pjGimmicksMenu' in chk
done_interface = 'pjInterfaceMenu' in chk
done_minigames = 'pjMinigamesMenu' in chk
done_statuses = 'database/statuses' in chk
done_moveanim = 'pjMovesMenu' in chk
done_quelpokemon = 'minigames/quel-pokemon' in chk
done_berrydex = 'pjBerriesMenu' in chk
done_succes = 'interface/succes' in chk
done_magasins = 'database/shops' in chk
done_carte = 'database/region-map' in chk
done_menus2 = 'pjZonesMenu' in chk
done_nowm = 'startPSDKWorldmap),children' not in chk
done_badges = 'trainers/badges' in chk
done_pots = 'berries/pots' in chk
done_mementos = 'database/mementos' in chk
done_pokemon_subs = 'database/egg-groups' in chk
done_reglages = 'database/dex-tasks' in chk
done_raids = 'gimmicks/raids' in chk
old_raids = 'minigames/raids-cartes' in chk
done_tournois = 'trainers/tournois' in chk
done_pokeblocs = 'berries/pokeblocs' in chk
done_concours = 'minigames/concours' in chk
done_obscurs = 'gimmicks/obscurs' in chk
old_obscurs = 'trainers/obscurs' in chk
done_montures = 'pjSubNav(`montures`' in chk
old_montures = 'interface/montures' in chk
done_pokeathlon = 'minigames/pokeathlon' in chk
done_dodrio = 'minigames/dodrio' in chk
done_lance_ball = 'minigames/lance_ball' in chk
done_overworld = 'zones/overworld-pokemon' in chk
done_rangs = 'gimmicks/barons-dominants' in chk
done_rangs_label = 'Barons, Monarques et Dominants' in chk
done_modes = 'gimmicks/modes-jeu' in chk
done_base = 'interface/base-secrete' in chk
done_meteo = 'zones/meteo-saisons' in chk
done_verif = 'database/verificateur' in chk
done_plugins = 'database/plugins' in chk
done_types_bal = 'database/types-equilibrage' in chk
done_quetes = 'interface/quetes-photo' in chk
done_tour = 'trainers/tour-combat' in chk
done_reactions = 'interface/reactions-amis' in chk
done_optplus = 'interface/options-plus' in chk
done_online = '/database/online`' in chk and 'interface/en-ligne' not in chk
done_move = 'region-map/base-secrete' in chk
done_amis = 'interface/amis' in chk and 'interface/amis/' not in chk
done_qtabs = 'pjQuestsTabs' not in chk
done_links = re.search(r'pjSubLink\(`/database/interface/(base-secrete|quetes-photo)`', chk) is None
# onglet Plugins de la barre de gauche retiré (toutes les pages ont leur place dans Données / Level design)
done_noplugins = done_pages and 'wl,{path:`/plugins`' not in chk
old_aseprite = 'pjAsepritePage' in chk
if done_pages and done_generators and done_atelier and done_world and done_world_nav and done_overview and done_code and done_characters and done_char_keys and done_char_top and done_variants and done_dexsize and done_gimmicks and done_interface and done_minigames and done_statuses and done_moveanim and done_noplugins and done_quelpokemon and done_berrydex and done_succes and done_magasins and done_carte and done_menus2 and done_nowm and done_badges and done_pots and done_mementos and done_pokemon_subs and done_reglages and done_raids and done_tournois and done_pokeblocs and done_concours and done_obscurs and done_montures and done_pokeathlon and done_dodrio and done_lance_ball and done_overworld and done_rangs and done_rangs_label and done_modes and done_base and done_meteo and done_verif and done_plugins and done_types_bal and done_quetes and done_tour and done_reactions and done_optplus and done_online and done_move and done_amis and done_qtabs and done_links:
    sys.exit('Déjà fait : ' + path)
if not os.path.exists(path + '.bak-pages'):
    shutil.copy(path, path + '.bak-pages')

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'studio-extra'))
from studio_patch import Patcher, PatchError  # noqa: E402
PATCHER = Patcher(s)


def rep(a, b):
    """Remplace le passage a par b (noms du code de Studio retrouvés dans la version installée)."""
    global s
    PATCHER.s = s
    try:
        PATCHER.rep(a, b)
    except PatchError as e:
        sys.exit('Version de Studio non reconnue (%s)' % e)
    s = PATCHER.s


# Menu de gauche : style des sous-sections (en ligne, pour ne dépendre d'aucune feuille de style)
SUBNAV_STYLE = ('style:{display:`flex`,alignItems:`center`,fontSize:`12px`,opacity:.9,marginLeft:`14px`,paddingLeft:`12px`,'
                'borderLeft:`1px solid rgba(160,160,190,.28)`},')
SUBHEAD_STYLE = ('style:{padding:`12px 16px 2px 30px`,fontSize:`10px`,fontWeight:400,letterSpacing:`.1em`,textTransform:`uppercase`,'
                 'opacity:.45,userSelect:`none`},')

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
    for m in re.finditer(r'pjCharactersMenu,\{\}\)', chk):
        print('Repère pjCharactersMenu :', chk[max(0, m.start() - 160):m.end() + 160].replace('\n', ' '))
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
        ',pjSubNav=(e,t)=>(0,j.jsx)(R$,{path:`/database/characters/${e}`,label:(0,j.jsx)(`span`,{className:`pj-subnav`,'+SUBNAV_STYLE+'children:t})},e)'
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
    rep(',Pdo=()=>(0,j.jsx)(k6a,', ',pjSubLink=(e,t)=>(0,j.jsx)(R$,{path:e,label:(0,j.jsx)(`span`,{className:`pj-subnav`,'+SUBNAV_STYLE+'children:t})},e)'
        ',pjPokemonMenu=({label:e})=>{let t=ta().pathname,n=t.startsWith(`/database/pokemon`)||t.startsWith(`/database/variants`);'
        'return(0,j.jsxs)(p.Fragment,{children:[(0,j.jsx)(R$,{path:`/database/pokemon`,label:(0,j.jsxs)(`span`,{className:`pj-navparent`+(n?` open`:``),children:[e,(0,j.jsx)(`span`,{className:`caret`,children:`▶`})]})}),'
        'n?(0,j.jsx)(`div`,{className:`pj-subhead`,'+SUBHEAD_STYLE+'children:`Variantes`}):null,n?pjSubLink(`/database/variants/shiny`,`Shiny / Radiant`):null,n?pjSubLink(`/database/variants/metals`,`Métaux`):null]})}'
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

if not done_interface:
    # Level design > Interface : sous-sections visibles quand on l'ouvre (Smartphone)
    rep('(0,j.jsx)(R$,{path:`/database/quests`,label:e(`quests`)})]})', '(0,j.jsx)(R$,{path:`/database/quests`,label:e(`quests`)}),(0,j.jsx)(pjInterfaceMenu,{})]})')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`interface/smartphone`,element:(0,j.jsx)(pjVarHost,{id:`smartphone`},`smartphone`)}),'
        '(0,j.jsx)(Aa,{path:`interface`,element:(0,j.jsx)(Oa,{to:`smartphone`,replace:!0})}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', ',pjInterfaceMenu=()=>{let t=ta().pathname.startsWith(`/database/interface`);'
        'return(0,j.jsxs)(p.Fragment,{children:[(0,j.jsx)(HOa,{to:`/database/interface`,end:!0,children:(0,j.jsx)(VOa,{children:(0,j.jsxs)(`span`,{className:`pj-navparent`+(t?` open`:``),children:[`Interface`,(0,j.jsx)(`span`,{className:`caret`,children:`▶`})]})})}),'
        't?pjSubLink(`/database/interface/smartphone`,`Smartphone`):null]})}'
        ',Pdo=()=>(0,j.jsx)(k6a,')

if not done_minigames:
    # Level design > Mini-jeux : sous-sections visibles quand on l'ouvre (Triple Triad)
    rep('(0,j.jsx)(pjInterfaceMenu,{})]})', '(0,j.jsx)(pjInterfaceMenu,{}),(0,j.jsx)(pjMinigamesMenu,{})]})')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`minigames/triple-triad`,element:(0,j.jsx)(pjVarHost,{id:`triple-triad`},`triple-triad`)}),'
        '(0,j.jsx)(Aa,{path:`minigames`,element:(0,j.jsx)(Oa,{to:`triple-triad`,replace:!0})}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', ',pjMinigamesMenu=()=>{let t=ta().pathname.startsWith(`/database/minigames`);'
        'return(0,j.jsxs)(p.Fragment,{children:[(0,j.jsx)(HOa,{to:`/database/minigames`,end:!0,children:(0,j.jsx)(VOa,{children:(0,j.jsxs)(`span`,{className:`pj-navparent`+(t?` open`:``),children:[`Mini-jeux`,(0,j.jsx)(`span`,{className:`caret`,children:`▶`})]})})}),'
        't?pjSubLink(`/database/minigames/triple-triad`,`Triple Triad`):null]})}'
        ',Pdo=()=>(0,j.jsx)(k6a,')

if not done_statuses:
    # Données > Statuts (après Natures, avant Gimmicks)
    rep('(0,j.jsx)(R$,{path:`/database/natures`,label:e(`natures`)}),', '(0,j.jsx)(R$,{path:`/database/natures`,label:e(`natures`)}),(0,j.jsx)(R$,{path:`/database/statuses`,label:`Statuts`}),')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`statuses`,element:(0,j.jsx)(pjVarHost,{id:`statuts`},`statuts`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_moveanim:
    # Données > Attaques : sous-section Animations quand on est sur les attaques
    rep('(0,j.jsx)(R$,{path:`/database/moves`,label:e(`moves`)})', '(0,j.jsx)(pjMovesMenu,{label:e(`moves`)})')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`move-animations`,element:(0,j.jsx)(pjVarHost,{id:`move-animations`},`move-animations`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', ',pjMovesMenu=({label:e})=>{let t=ta().pathname,n=t.startsWith(`/database/moves`)||t.startsWith(`/database/move-animations`);'
        'return(0,j.jsxs)(p.Fragment,{children:[(0,j.jsx)(R$,{path:`/database/moves`,label:(0,j.jsxs)(`span`,{className:`pj-navparent`+(n?` open`:``),children:[e,(0,j.jsx)(`span`,{className:`caret`,children:`▶`})]})}),'
        'n?pjSubLink(`/database/move-animations`,`Animations`):null]})}'
        ',Pdo=()=>(0,j.jsx)(k6a,')

if not done_noplugins:
    # plus d'onglet Plugins dans la barre de gauche ; /plugins mène aux Données
    rep('(0,j.jsx)(wl,{path:`/plugins`,onMouseLeave:i,onMouseEnter:r(`Plugins`,`right-center`,!0),children:(0,j.jsx)(Zl,{color:e.colors.navigationIconColor,size:`s`,icon:`plugins`})}),', '')
    rep('(0,j.jsx)(Aa,{path:`/plugins/*`,element:(0,j.jsx)(pjPluginsPage,{})}),', '(0,j.jsx)(Aa,{path:`/plugins/*`,element:(0,j.jsx)(Oa,{to:`/database`,replace:!0})}),')

if not done_quelpokemon:
    # Level design > Mini-jeux : Quel est ce Pokémon (après Triple Triad)
    rep('t?pjSubLink(`/database/minigames/triple-triad`,`Triple Triad`):null', 't?pjSubLink(`/database/minigames/triple-triad`,`Triple Triad`):null,t?pjSubLink(`/database/minigames/quel-pokemon`,`Quel est ce Pokémon`):null')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`minigames/quel-pokemon`,element:(0,j.jsx)(pjVarHost,{id:`quel-pokemon`},`quel-pokemon`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_berrydex:
    # Données > Baies (après Objets) : sous-section Berrydex visible quand on l'ouvre
    rep('(0,j.jsx)(R$,{path:`/database/items`,label:e(`items`)}),', '(0,j.jsx)(R$,{path:`/database/items`,label:e(`items`)}),(0,j.jsx)(pjBerriesMenu,{}),')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`berries/berrydex`,element:(0,j.jsx)(pjVarHost,{id:`berrydex`},`berrydex`)}),'
        '(0,j.jsx)(Aa,{path:`berries`,element:(0,j.jsx)(Oa,{to:`berrydex`,replace:!0})}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')
    rep(',Pdo=()=>(0,j.jsx)(k6a,', ',pjBerriesMenu=()=>{let t=ta().pathname.startsWith(`/database/berries`);'
        'return(0,j.jsxs)(p.Fragment,{children:[(0,j.jsx)(HOa,{to:`/database/berries`,end:!0,children:(0,j.jsx)(VOa,{children:(0,j.jsxs)(`span`,{className:`pj-navparent`+(t?` open`:``),children:[`Baies`,(0,j.jsx)(`span`,{className:`caret`,children:`▶`})]})})}),'
        't?pjSubLink(`/database/berries/berrydex`,`Berrydex`):null]})}'
        ',Pdo=()=>(0,j.jsx)(k6a,')

if not done_succes:
    # Level design > Interface : Succès (après Smartphone) ; ancien lien « Succès » de Level design retiré
    if '(0,j.jsx)(R$,{path:`/database/achievements`,label:`Succès`})' in s:
        rep(',(0,j.jsx)(R$,{path:`/database/achievements`,label:`Succès`})', '')
        rep('(0,j.jsx)(Aa,{path:`achievements`,element:(0,j.jsx)(pjVarHost,{id:`succes`},`succes`)}),', '')
    rep('t?pjSubLink(`/database/interface/smartphone`,`Smartphone`):null', 't?pjSubLink(`/database/interface/smartphone`,`Smartphone`):null,t?pjSubLink(`/database/interface/succes`,`Succès`):null')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`interface/succes`,element:(0,j.jsx)(pjVarHost,{id:`succes`},`succes`)}),'
        '(0,j.jsx)(Aa,{path:`achievements`,element:(0,j.jsx)(Oa,{to:`/database/interface/succes`,replace:!0})}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_magasins:
    # Level design > Magasins (juste avant Interface)
    rep('(0,j.jsx)(pjInterfaceMenu,{}),', '(0,j.jsx)(R$,{path:`/database/shops`,label:`Magasins`}),(0,j.jsx)(pjInterfaceMenu,{}),')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`shops`,element:(0,j.jsx)(pjVarHost,{id:`magasins`},`magasins`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_carte:
    # Level design > Carte de région (juste avant Magasins)
    rep('(0,j.jsx)(R$,{path:`/database/shops`,label:`Magasins`}),', '(0,j.jsx)(R$,{path:`/database/region-map`,label:`Carte de région`}),(0,j.jsx)(R$,{path:`/database/shops`,label:`Magasins`}),')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`region-map`,element:(0,j.jsx)(pjVarHost,{id:`carte-region`},`carte-region`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_menus2:
    # Level design regroupé : Zones > Groupes ; Dresseurs > Classes de dresseurs ; Interface > Boutique, Quêtes
    rep('(0,j.jsx)(R$,{path:`/database/zones`,label:e(`zones`)}),(0,j.jsx)(R$,{path:`/database/groups`,label:e(`groups`)}),',
        '(0,j.jsx)(pjZonesMenu,{label:e(`zones`),sub:e(`groups`)}),')
    rep('(0,j.jsx)(R$,{path:`/database/trainerClasses`,label:e(`trainer_classes`)}),(0,j.jsx)(R$,{path:`/database/trainers`,label:e(`trainers`)}),(0,j.jsx)(R$,{path:`/database/quests`,label:e(`quests`)}),',
        '(0,j.jsx)(pjTrainersMenu,{label:e(`trainers`),sub:e(`trainer_classes`)}),')
    rep('(0,j.jsx)(R$,{path:`/database/shops`,label:`Magasins`}),(0,j.jsx)(pjInterfaceMenu,{}),', '(0,j.jsx)(pjInterfaceMenu,{quests:e(`quests`)}),')
    rep('pjInterfaceMenu=()=>{let t=ta().pathname.startsWith(`/database/interface`);',
        'pjInterfaceMenu=({quests:q})=>{let u=ta().pathname,t=u.startsWith(`/database/interface`)||u.startsWith(`/database/shops`)||u.startsWith(`/database/quests`);')
    rep('t?pjSubLink(`/database/interface/succes`,`Succès`):null',
        't?pjSubLink(`/database/interface/succes`,`Succès`):null,t?pjSubLink(`/database/shops`,`Boutique`):null,t?pjSubLink(`/database/quests`,q):null')
    rep(',Pdo=()=>(0,j.jsx)(k6a,',
        ',pjZonesMenu=({label:e,sub:s})=>{let t=ta().pathname,n=t.startsWith(`/database/zones`)||t.startsWith(`/database/groups`);'
        'return(0,j.jsxs)(p.Fragment,{children:[(0,j.jsx)(R$,{path:`/database/zones`,label:(0,j.jsxs)(`span`,{className:`pj-navparent`+(n?` open`:``),children:[e,(0,j.jsx)(`span`,{className:`caret`,children:`▶`})]})}),'
        'n?pjSubLink(`/database/groups`,s):null]})}'
        ',pjTrainersMenu=({label:e,sub:s})=>{let t=ta().pathname,n=t.startsWith(`/database/trainers`)||t.startsWith(`/database/trainerClasses`);'
        'return(0,j.jsxs)(p.Fragment,{children:[(0,j.jsx)(R$,{path:`/database/trainers`,label:(0,j.jsxs)(`span`,{className:`pj-navparent`+(n?` open`:``),children:[e,(0,j.jsx)(`span`,{className:`caret`,children:`▶`})]})}),'
        'n?pjSubLink(`/database/trainerClasses`,s):null]})}'
        ',Pdo=()=>(0,j.jsx)(k6a,')

if not done_nowm:
    # Menu Jouer : plus d'« éditeur de carte du monde » de PSDK
    rep(',(0,j.jsx)(`span`,{onClick:()=>i(window.api.startPSDKWorldmap),children:r(`play_worldmap_mode`)})', '')
    # Zone : la position sur la carte du monde se règle dans la Carte de région (champ caché, gardé pour l'enregistrement)
    rep('(0,j.jsxs)(kba,{children:[(0,j.jsx)(K,{htmlFor:`position-worldmap`',
        '(0,j.jsxs)(kba,{style:{display:`none`},children:[(0,j.jsx)(K,{htmlFor:`position-worldmap`')

if not done_badges:
    # Level design > Dresseurs > Étui à badges (après Classes de dresseurs) ; ancienne place (Interface) retirée
    if 'interface/badges' in s:
        rep(',t?pjSubLink(`/database/interface/badges`,`Étui à badges`):null', '')
        rep('(0,j.jsx)(Aa,{path:`interface/badges`,element:(0,j.jsx)(pjVarHost,{id:`etui-badges`},`etui-badges`)}),', '')
    rep('n?pjSubLink(`/database/trainerClasses`,s):null]', 'n?pjSubLink(`/database/trainerClasses`,s):null,n?pjSubLink(`/database/trainers/badges`,`Étui à badges`):null]')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`trainers/badges`,element:(0,j.jsx)(pjVarHost,{id:`etui-badges`},`etui-badges`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_pots:
    # Données > Baies > Pots à baies (après Berrydex)
    rep('t?pjSubLink(`/database/berries/berrydex`,`Berrydex`):null', 't?pjSubLink(`/database/berries/berrydex`,`Berrydex`):null,t?pjSubLink(`/database/berries/pots`,`Pots à baies`):null')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`berries/pots`,element:(0,j.jsx)(pjVarHost,{id:`pots-baies`},`pots-baies`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_mementos:
    # Données > Pokémon > Rubans et insignes (sous-section « Souvenirs » après les Variantes)
    rep('n=t.startsWith(`/database/pokemon`)||t.startsWith(`/database/variants`);',
        'n=t.startsWith(`/database/pokemon`)||t.startsWith(`/database/variants`)||t.startsWith(`/database/mementos`);')
    rep('n?pjSubLink(`/database/variants/metals`,`Métaux`):null]',
        'n?pjSubLink(`/database/variants/metals`,`Métaux`):null,n?(0,j.jsx)(`div`,{className:`pj-subhead`,'+SUBHEAD_STYLE+'children:`Souvenirs`}):null,'
        'n?pjSubLink(`/database/mementos`,`Rubans et insignes`):null]')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`mementos`,element:(0,j.jsx)(pjVarHost,{id:`mementos`},`mementos`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_pokemon_subs:
    # Natures et Statuts quittent la liste Données : ce sont maintenant des sous-sections de Pokémon (avec les Groupes d'Œuf)
    rep('(0,j.jsx)(R$,{path:`/database/natures`,label:e(`natures`)}),(0,j.jsx)(R$,{path:`/database/statuses`,label:`Statuts`}),', '')
    rep('||t.startsWith(`/database/mementos`);',
        '||t.startsWith(`/database/mementos`)||t.startsWith(`/database/natures`)||t.startsWith(`/database/statuses`)||t.startsWith(`/database/egg-groups`);')
    rep('n?(0,j.jsx)(`div`,{className:`pj-subhead`,'+SUBHEAD_STYLE+'children:`Variantes`}):null,',
        'n?(0,j.jsx)(`div`,{className:`pj-subhead`,'+SUBHEAD_STYLE+'children:`Réglages`}):null,'
        'n?pjSubLink(`/database/natures`,`Natures`):null,n?pjSubLink(`/database/statuses`,`Statuts`):null,'
        'n?pjSubLink(`/database/egg-groups`,`Groupes d\'Œuf`):null,'
        'n?(0,j.jsx)(`div`,{className:`pj-subhead`,'+SUBHEAD_STYLE+'children:`Variantes`}):null,')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`egg-groups`,element:(0,j.jsx)(pjVarHost,{id:`egg-groups`},`egg-groups`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_reglages:
    # pages de tools/studio-reglages : Pokédex > Tâches, Baies > Champs de baies, Gimmicks > Styles PLA,
    # Mini-jeux > Sac de frappe et Poké Récré
    rep('n?pjSubLink(`/database/dex-size`,`Taille / Poids`):null]', 'n?pjSubLink(`/database/dex-size`,`Taille / Poids`):null,n?pjSubLink(`/database/dex-tasks`,`Tâches`):null]')
    rep('t?pjSubLink(`/database/berries/pots`,`Pots à baies`):null', 't?pjSubLink(`/database/berries/pots`,`Pots à baies`):null,t?pjSubLink(`/database/berries/champs`,`Champs de baies`):null')
    rep('t?pjSubLink(`/database/gimmicks/dynamax`,`Dynamax`):null', 't?pjSubLink(`/database/gimmicks/dynamax`,`Dynamax`):null,t?pjSubLink(`/database/gimmicks/styles`,`Styles PLA`):null')
    rep('t?pjSubLink(`/database/minigames/quel-pokemon`,`Quel est ce Pokémon`):null', 't?pjSubLink(`/database/minigames/quel-pokemon`,`Quel est ce Pokémon`):null,'
        't?pjSubLink(`/database/minigames/sac-de-frappe`,`Sac de frappe`):null,t?pjSubLink(`/database/minigames/poke-recre`,`Poké Récré`):null')
    routes = ''.join('(0,j.jsx)(Aa,{path:`%s`,element:(0,j.jsx)(pjVarHost,{id:`%s`},`%s`)}),' % (r, i, i) for r, i in (
        ('dex-tasks', 'dex-tasks'), ('berries/champs', 'champs-baies'), ('gimmicks/styles', 'styles-pla'),
        ('minigames/sac-de-frappe', 'sac-de-frappe'), ('minigames/poke-recre', 'poke-recre')))
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),', routes + '(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_raids:
    # pages de tools/studio-reglages : Gimmicks > Raids, Carte de région > Cartes d'aventure
    if old_raids:
        # anciens emplacements (Mini-jeux) retirés
        rep(',t?pjSubLink(`/database/minigames/raids`,`Raids`):null,t?pjSubLink(`/database/minigames/raids-cartes`,`Cartes d’aventure`):null', '')
        rep(''.join('(0,j.jsx)(Aa,{path:`%s`,element:(0,j.jsx)(pjVarHost,{id:`%s`},`%s`)}),' % (r, i, i) for r, i in (
            ('minigames/raids', 'raids'), ('minigames/raids-cartes', 'raids-cartes'))), '')
    rep('t?pjSubLink(`/database/gimmicks/styles`,`Styles PLA`):null', 't?pjSubLink(`/database/gimmicks/styles`,`Styles PLA`):null,t?pjSubLink(`/database/gimmicks/raids`,`Raids`):null')
    rep('(0,j.jsx)(R$,{path:`/database/region-map`,label:`Carte de région`})', '(0,j.jsx)(pjRegionMenu,{})')
    rep(',pjMinigamesMenu=()=>{', ',pjRegionMenu=()=>{let t=ta().pathname.startsWith(`/database/region-map`);'
        'return(0,j.jsxs)(p.Fragment,{children:[(0,j.jsx)(HOa,{to:`/database/region-map`,end:!0,children:(0,j.jsx)(VOa,{children:(0,j.jsxs)(`span`,{className:`pj-navparent`+(t?` open`:``),children:[`Carte de région`,(0,j.jsx)(`span`,{className:`caret`,children:`▶`})]})})}),'
        't?pjSubLink(`/database/region-map/aventure`,`Cartes d’aventure`):null]})}'
        ',pjMinigamesMenu=()=>{')
    routes = ''.join('(0,j.jsx)(Aa,{path:`%s`,element:(0,j.jsx)(pjVarHost,{id:`%s`},`%s`)}),' % (r, i, i) for r, i in (
        ('gimmicks/raids', 'raids'), ('region-map/aventure', 'raids-cartes')))
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),', routes + '(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_tournois:
    # page de tools/studio-reglages : Dresseurs > Tournois
    rep('n?pjSubLink(`/database/trainers/badges`,`Étui à badges`):null', 'n?pjSubLink(`/database/trainers/badges`,`Étui à badges`):null,n?pjSubLink(`/database/trainers/tournois`,`Tournois`):null')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`trainers/tournois`,element:(0,j.jsx)(pjVarHost,{id:`tournois`},`tournois`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_pokeblocs:
    # page de tools/studio-reglages : Données > Baies > Pokéblocs (après Champs de baies)
    rep('t?pjSubLink(`/database/berries/champs`,`Champs de baies`):null', 't?pjSubLink(`/database/berries/champs`,`Champs de baies`):null,t?pjSubLink(`/database/berries/pokeblocs`,`Pokéblocs`):null')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`berries/pokeblocs`,element:(0,j.jsx)(pjVarHost,{id:`pokeblocs`},`pokeblocs`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_concours:
    # page de tools/studio-reglages : Level design > Mini-jeux > Concours (après Poké Récré)
    rep('t?pjSubLink(`/database/minigames/poke-recre`,`Poké Récré`):null', 't?pjSubLink(`/database/minigames/poke-recre`,`Poké Récré`):null,t?pjSubLink(`/database/minigames/concours`,`Concours`):null')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`minigames/concours`,element:(0,j.jsx)(pjVarHost,{id:`concours`},`concours`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_obscurs:
    # page de tools/studio-reglages : Gimmicks > Pokémon Obscurs (après Raids)
    if old_obscurs:
        # ancien emplacement (Dresseurs) retiré
        rep(',n?pjSubLink(`/database/trainers/obscurs`,`Pokémon Obscurs`):null', '')
        rep('(0,j.jsx)(Aa,{path:`trainers/obscurs`,element:(0,j.jsx)(pjVarHost,{id:`obscurs`},`obscurs`)}),', '')
    rep('t?pjSubLink(`/database/gimmicks/raids`,`Raids`):null', 't?pjSubLink(`/database/gimmicks/raids`,`Raids`):null,t?pjSubLink(`/database/gimmicks/obscurs`,`Pokémon Obscurs`):null')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`gimmicks/obscurs`,element:(0,j.jsx)(pjVarHost,{id:`obscurs`},`obscurs`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_montures:
    # page de tools/studio-reglages : Personnages > Montures (après Alliés)
    if old_montures:
        # ancien emplacement (Interface) retiré
        rep(',t?pjSubLink(`/database/interface/montures`,`Montures`):null', '')
        rep('(0,j.jsx)(Aa,{path:`interface/montures`,element:(0,j.jsx)(pjVarHost,{id:`montures`},`montures`)}),', '')
    rep('t?pjSubNav(`allies`,`Alliés`):null,', 't?pjSubNav(`allies`,`Alliés`):null,t?pjSubNav(`montures`,`Montures`):null,')
    rep('(0,j.jsx)(Aa,{path:`allies`,element:(0,j.jsx)(pjPageHost,{id:`allies`},`allies`)}),',
        '(0,j.jsx)(Aa,{path:`allies`,element:(0,j.jsx)(pjPageHost,{id:`allies`},`allies`)}),(0,j.jsx)(Aa,{path:`montures`,element:(0,j.jsx)(pjPageHost,{id:`montures`},`montures`)}),')

if not done_pokeathlon:
    # page de tools/studio-reglages : Level design > Mini-jeux > Pokéathlon (après Concours)
    rep('t?pjSubLink(`/database/minigames/concours`,`Concours`):null', 't?pjSubLink(`/database/minigames/concours`,`Concours`):null,t?pjSubLink(`/database/minigames/pokeathlon`,`Pokéathlon`):null')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`minigames/pokeathlon`,element:(0,j.jsx)(pjVarHost,{id:`pokeathlon`},`pokeathlon`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')
if not done_dodrio:
    # page de tools/studio-reglages : Level design > Mini-jeux > Cueillette Dodrio (après Pokéathlon)
    rep('t?pjSubLink(`/database/minigames/pokeathlon`,`Pokéathlon`):null', 't?pjSubLink(`/database/minigames/pokeathlon`,`Pokéathlon`):null,t?pjSubLink(`/database/minigames/dodrio`,`Cueillette Dodrio`):null')
    rep('(0,j.jsx)(Aa,{path:`minigames/pokeathlon`,element:(0,j.jsx)(pjVarHost,{id:`pokeathlon`},`pokeathlon`)}),',
        '(0,j.jsx)(Aa,{path:`minigames/pokeathlon`,element:(0,j.jsx)(pjVarHost,{id:`pokeathlon`},`pokeathlon`)}),(0,j.jsx)(Aa,{path:`minigames/dodrio`,element:(0,j.jsx)(pjVarHost,{id:`dodrio`},`dodrio`)}),')
if not done_lance_ball:
    # page de tools/studio-reglages : Level design > Mini-jeux > Lance-Ball (après Cueillette Dodrio)
    rep('t?pjSubLink(`/database/minigames/dodrio`,`Cueillette Dodrio`):null', 't?pjSubLink(`/database/minigames/dodrio`,`Cueillette Dodrio`):null,t?pjSubLink(`/database/minigames/lance_ball`,`Lance-Ball`):null')
    rep('(0,j.jsx)(Aa,{path:`minigames/dodrio`,element:(0,j.jsx)(pjVarHost,{id:`dodrio`},`dodrio`)}),',
        '(0,j.jsx)(Aa,{path:`minigames/dodrio`,element:(0,j.jsx)(pjVarHost,{id:`dodrio`},`dodrio`)}),(0,j.jsx)(Aa,{path:`minigames/lance_ball`,element:(0,j.jsx)(pjVarHost,{id:`lance_ball`},`lance_ball`)}),')

if not done_overworld:
    # page de tools/studio-reglages : Level design > Zones > Pokémon visibles (plugin overworld_pokemon)
    rep('n?pjSubLink(`/database/groups`,s):null]})}', 'n?pjSubLink(`/database/groups`,s):null,n?pjSubLink(`/database/zones/overworld-pokemon`,`Pokémon visibles`):null]})}')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`zones/overworld-pokemon`,element:(0,j.jsx)(pjVarHost,{id:`overworld-pokemon`},`overworld-pokemon`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_rangs:
    # page de tools/studio-reglages : Données > Gimmicks > Barons et Dominants (après Pokémon Obscurs)
    rep('t?pjSubLink(`/database/gimmicks/obscurs`,`Pokémon Obscurs`):null', 't?pjSubLink(`/database/gimmicks/obscurs`,`Pokémon Obscurs`):null,t?pjSubLink(`/database/gimmicks/barons-dominants`,`Barons, Monarques et Dominants`):null')
    rep('(0,j.jsx)(Aa,{path:`gimmicks/obscurs`,element:(0,j.jsx)(pjVarHost,{id:`obscurs`},`obscurs`)}),',
        '(0,j.jsx)(Aa,{path:`gimmicks/obscurs`,element:(0,j.jsx)(pjVarHost,{id:`obscurs`},`obscurs`)}),(0,j.jsx)(Aa,{path:`gimmicks/barons-dominants`,element:(0,j.jsx)(pjVarHost,{id:`barons-dominants`},`barons-dominants`)}),')

if done_rangs and not done_rangs_label:
    # Studio déjà patché avec l'ancien nom du lien : renommé (les Monarques sont sur la même page)
    rep('`Barons et Dominants`', '`Barons, Monarques et Dominants`')

if not done_modes:
    # page de tools/studio-reglages : Données > Gimmicks > Modes de jeu (après Barons, Monarques et Dominants)
    rep('t?pjSubLink(`/database/gimmicks/barons-dominants`,`Barons, Monarques et Dominants`):null', 't?pjSubLink(`/database/gimmicks/barons-dominants`,`Barons, Monarques et Dominants`):null,t?pjSubLink(`/database/gimmicks/modes-jeu`,`Modes de jeu`):null')
    rep('(0,j.jsx)(Aa,{path:`gimmicks/barons-dominants`,element:(0,j.jsx)(pjVarHost,{id:`barons-dominants`},`barons-dominants`)}),',
        '(0,j.jsx)(Aa,{path:`gimmicks/barons-dominants`,element:(0,j.jsx)(pjVarHost,{id:`barons-dominants`},`barons-dominants`)}),(0,j.jsx)(Aa,{path:`gimmicks/modes-jeu`,element:(0,j.jsx)(pjVarHost,{id:`modes-jeu`},`modes-jeu`)}),')

if not done_base:
    # page de tools/studio-reglages : Données > Interface > Base secrète (après Succès)
    rep('t?pjSubLink(`/database/interface/succes`,`Succès`):null,t?pjSubLink(`/database/shops`', 't?pjSubLink(`/database/interface/succes`,`Succès`):null,t?pjSubLink(`/database/interface/base-secrete`,`Base secrète`):null,t?pjSubLink(`/database/shops`')
    rep('(0,j.jsx)(Aa,{path:`interface/succes`,element:(0,j.jsx)(pjVarHost,{id:`succes`},`succes`)}),',
        '(0,j.jsx)(Aa,{path:`interface/succes`,element:(0,j.jsx)(pjVarHost,{id:`succes`},`succes`)}),(0,j.jsx)(Aa,{path:`interface/base-secrete`,element:(0,j.jsx)(pjVarHost,{id:`base-secrete`},`base-secrete`)}),')

if not done_meteo:
    # page de tools/studio-reglages : Données > Zones > Météo et saisons (après Pokémon visibles)
    rep('n?pjSubLink(`/database/zones/overworld-pokemon`,`Pokémon visibles`):null', 'n?pjSubLink(`/database/zones/overworld-pokemon`,`Pokémon visibles`):null,n?pjSubLink(`/database/zones/meteo-saisons`,`Météo et saisons`):null')
    rep('(0,j.jsx)(Aa,{path:`zones/overworld-pokemon`,element:(0,j.jsx)(pjVarHost,{id:`overworld-pokemon`},`overworld-pokemon`)}),',
        '(0,j.jsx)(Aa,{path:`zones/overworld-pokemon`,element:(0,j.jsx)(pjVarHost,{id:`overworld-pokemon`},`overworld-pokemon`)}),(0,j.jsx)(Aa,{path:`zones/meteo-saisons`,element:(0,j.jsx)(pjVarHost,{id:`meteo-saisons`},`meteo-saisons`)}),')

if not done_verif:
    # page de tools/studio-reglages : Données > Pokédex > Vérificateur de données (après Tâches)
    rep('n?pjSubLink(`/database/dex-tasks`,`Tâches`):null]', 'n?pjSubLink(`/database/dex-tasks`,`Tâches`):null,n?pjSubLink(`/database/verificateur`,`Vérificateur de données`):null]')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`verificateur`,element:(0,j.jsx)(pjVarHost,{id:`verificateur`},`verificateur`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_plugins:
    # page de tools/studio-reglages : Données > Plugins (accueil : versions, dépendances, liens vers les réglages), en tête du menu
    rep('L$,{title:e(`data`),children:[(0,j.jsx)(pjCharactersMenu,{}),',
        'L$,{title:e(`data`),children:[(0,j.jsx)(R$,{path:`/database/plugins`,label:`Plugins`}),(0,j.jsx)(pjCharactersMenu,{}),')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`plugins`,element:(0,j.jsx)(pjVarHost,{id:`plugins`},`plugins`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_types_bal:
    # page de tools/studio-reglages : Données > Pokédex > Équilibrage des types (après le Vérificateur)
    rep('n?pjSubLink(`/database/verificateur`,`Vérificateur de données`):null]', 'n?pjSubLink(`/database/verificateur`,`Vérificateur de données`):null,n?pjSubLink(`/database/types-equilibrage`,`Équilibrage des types`):null]')
    rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),',
        '(0,j.jsx)(Aa,{path:`types-equilibrage`,element:(0,j.jsx)(pjVarHost,{id:`equilibrage-types`},`equilibrage-types`)}),(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')

if not done_quetes:
    # page de tools/studio-reglages : Données > Interface > Quêtes photo (après Base secrète)
    rep('t?pjSubLink(`/database/interface/base-secrete`,`Base secrète`):null', 't?pjSubLink(`/database/interface/base-secrete`,`Base secrète`):null,t?pjSubLink(`/database/interface/quetes-photo`,`Quêtes photo`):null')
    rep('(0,j.jsx)(Aa,{path:`interface/base-secrete`,element:(0,j.jsx)(pjVarHost,{id:`base-secrete`},`base-secrete`)}),',
        '(0,j.jsx)(Aa,{path:`interface/base-secrete`,element:(0,j.jsx)(pjVarHost,{id:`base-secrete`},`base-secrete`)}),(0,j.jsx)(Aa,{path:`interface/quetes-photo`,element:(0,j.jsx)(pjVarHost,{id:`quetes-photo`},`quetes-photo`)}),')

if not done_reactions:
    # page de tools/studio-reglages : Données > Interface > Réactions des amis (après Quêtes photo)
    rep('t?pjSubLink(`/database/interface/quetes-photo`,`Quêtes photo`):null', 't?pjSubLink(`/database/interface/quetes-photo`,`Quêtes photo`):null,t?pjSubLink(`/database/interface/reactions-amis`,`Réactions des amis`):null')
    rep('(0,j.jsx)(Aa,{path:`interface/quetes-photo`,element:(0,j.jsx)(pjVarHost,{id:`quetes-photo`},`quetes-photo`)}),',
        '(0,j.jsx)(Aa,{path:`interface/quetes-photo`,element:(0,j.jsx)(pjVarHost,{id:`quetes-photo`},`quetes-photo`)}),(0,j.jsx)(Aa,{path:`interface/reactions-amis`,element:(0,j.jsx)(pjVarHost,{id:`reactions-amis`},`reactions-amis`)}),')

if not done_optplus:
    # page de tools/studio-reglages : Données > Interface > Options en plus (après Réactions des amis)
    rep('t?pjSubLink(`/database/interface/reactions-amis`,`Réactions des amis`):null', 't?pjSubLink(`/database/interface/reactions-amis`,`Réactions des amis`):null,t?pjSubLink(`/database/interface/options-plus`,`Options en plus`):null')
    rep('(0,j.jsx)(Aa,{path:`interface/reactions-amis`,element:(0,j.jsx)(pjVarHost,{id:`reactions-amis`},`reactions-amis`)}),',
        '(0,j.jsx)(Aa,{path:`interface/reactions-amis`,element:(0,j.jsx)(pjVarHost,{id:`reactions-amis`},`reactions-amis`)}),(0,j.jsx)(Aa,{path:`interface/options-plus`,element:(0,j.jsx)(pjVarHost,{id:`options-plus`},`options-plus`)}),')

def try_rep(a, b):
    """Comme rep, mais renvoie False (sans arrêter) si le passage n'existe pas dans cette version."""
    global s
    PATCHER.s = s
    try:
        PATCHER.rep(a, b)
    except PatchError:
        return False
    s = PATCHER.s
    return True


if not done_online:
    # Jeu en ligne : catégorie de Level design (juste après Carte de région), plus une sous-page de Interface.
    # Selon la version déjà patchée, « Carte de région » est un lien simple ou le menu pjRegionMenu : on essaie
    # plusieurs repères, du plus précis au plus général.
    ONLINE_ROUTE = '(0,j.jsx)(Aa,{path:`online`,element:(0,j.jsx)(pjVarHost,{id:`en-ligne`},`en-ligne`)}),'
    LINK_HOA = '(0,j.jsx)(HOa,{to:`/database/online`,end:!0,children:(0,j.jsx)(VOa,{children:`Jeu en ligne`})}),'
    LINK_R = '(0,j.jsx)(R$,{path:`/database/online`,label:`Jeu en ligne`}),'
    had_old = 'interface/en-ligne' in s
    if had_old:
        rep(',t?pjSubLink(`/database/interface/en-ligne`,`Jeu en ligne`):null', '')
        rep('(0,j.jsx)(Aa,{path:`interface/en-ligne`,element:(0,j.jsx)(pjVarHost,{id:`en-ligne`},`en-ligne`)}),', ONLINE_ROUTE)
    else:
        rep('(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),', ONLINE_ROUTE + '(0,j.jsx)(Aa,{path:`natures`,element:(0,j.jsx)(J0a,{})}),')
    ANCHORS = [
        ('(0,j.jsx)(pjRegionMenu,{}),', LINK_HOA, True),
        ('(0,j.jsx)(R$,{path:`/database/region-map`,label:`Carte de région`}),', LINK_R, True),
        ('(0,j.jsx)(pjInterfaceMenu,{quests:e(`quests`)}),', LINK_HOA, False),
        ('(0,j.jsx)(pjInterfaceMenu,{}),', LINK_HOA, False),
    ]
    placed = any(try_rep(a, (a + link) if after else (link + a)) for a, link, after in ANCHORS)
    if not placed:
        # dernier recours : le lien reste dans Données > Interface (la page marche, seule sa place change)
        placed = try_rep('t?pjSubLink(`/database/interface/options-plus`,`Options en plus`):null',
                         't?pjSubLink(`/database/interface/options-plus`,`Options en plus`):null,t?pjSubLink(`/database/online`,`Jeu en ligne`):null')
        print('Attention : la place de « Carte de région » n\'a pas été reconnue ; « Jeu en ligne » est rangé dans Interface.')
    if not placed:
        sys.exit('Version de Studio non reconnue (aucun repère pour le lien « Jeu en ligne »)')

if not done_tour:
    # page de tools/studio-reglages : Level design > Dresseurs > Tour de Combat (après Tournois)
    rep('n?pjSubLink(`/database/trainers/tournois`,`Tournois`):null', 'n?pjSubLink(`/database/trainers/tournois`,`Tournois`):null,n?pjSubLink(`/database/trainers/tour-combat`,`Tour de Combat`):null')
    rep('(0,j.jsx)(Aa,{path:`trainers/tournois`,element:(0,j.jsx)(pjVarHost,{id:`tournois`},`tournois`)}),',
        '(0,j.jsx)(Aa,{path:`trainers/tournois`,element:(0,j.jsx)(pjVarHost,{id:`tournois`},`tournois`)}),(0,j.jsx)(Aa,{path:`trainers/tour-combat`,element:(0,j.jsx)(pjVarHost,{id:`tour-combat`},`tour-combat`)}),')

if not done_move:
    # Base secrète : sous-section de Level design > Carte de région (à côté de Cartes d'aventure)
    rep('t?pjSubLink(`/database/region-map/aventure`,`Cartes d’aventure`):null]',
        't?pjSubLink(`/database/region-map/aventure`,`Cartes d’aventure`):null,t?pjSubLink(`/database/region-map/base-secrete`,`Base secrète`):null]')
    rep('(0,j.jsx)(Aa,{path:`region-map/aventure`,element:(0,j.jsx)(pjVarHost,{id:`raids-cartes`},`raids-cartes`)}),',
        '(0,j.jsx)(Aa,{path:`region-map/aventure`,element:(0,j.jsx)(pjVarHost,{id:`raids-cartes`},`raids-cartes`)}),(0,j.jsx)(Aa,{path:`region-map/base-secrete`,element:(0,j.jsx)(pjVarHost,{id:`base-secrete`},`base-secrete`)}),')

if not done_amis:
    # Données > Interface > Amis : une seule page à onglets (Contacts et messages, Réactions, Conseils, Troupeaux, Textes)
    AMIS_ROUTE = '(0,j.jsx)(Aa,{path:`interface/amis`,element:(0,j.jsx)(pjVarHost,{id:`reactions-amis`},`reactions-amis`)}),'
    if 'interface/amis/contacts' in chk:
        # version précédente (deux pages sous Amis) → une seule
        for sub in ('contacts`,`↳ Contacts et messages', 'reactions`,`↳ Réactions des amis'):
            rep(',(t&&ta().pathname.startsWith(`/database/interface/amis`))?pjSubLink(`/database/interface/amis/' + sub + '`):null', '')
        rep('(0,j.jsx)(Aa,{path:`interface/amis`,element:(0,j.jsx)(Oa,{to:`/database/interface/amis/contacts`,replace:!0})}),'
            '(0,j.jsx)(Aa,{path:`interface/amis/contacts`,element:(0,j.jsx)(pjVarHost,{id:`amis`},`amis`)}),'
            '(0,j.jsx)(Aa,{path:`interface/amis/reactions`,element:(0,j.jsx)(pjVarHost,{id:`reactions-amis`},`reactions-amis`)}),', AMIS_ROUTE)
    else:
        rep(',t?pjSubLink(`/database/interface/reactions-amis`,`Réactions des amis`):null', '')
        rep('t?pjSubLink(`/database/interface/smartphone`,`Smartphone`):null',
            't?pjSubLink(`/database/interface/smartphone`,`Smartphone`):null,t?pjSubLink(`/database/interface/amis`,`Amis`):null')
        rep('(0,j.jsx)(Aa,{path:`interface/smartphone`,element:(0,j.jsx)(pjVarHost,{id:`smartphone`},`smartphone`)}),',
            '(0,j.jsx)(Aa,{path:`interface/smartphone`,element:(0,j.jsx)(pjVarHost,{id:`smartphone`},`smartphone`)}),' + AMIS_ROUTE)

if not done_qtabs:
    # Quêtes photo : plus d'onglets ni de page à part. Le bloc « Quêtes photo » est ajouté à la page Quêtes par tools/studio-reglages
    s, n = re.subn(r',pjQuestsTabs=\(\{children:c\}\)=>\{.*?\}(?=,pjSubLink=\(e,t\)=>)', '', s, count=1, flags=re.S)
    s, n2 = re.subn(r'element:\(0,(\w+)\.jsx\)\(pjQuestsTabs,\{children:(\(0,\w+\.jsx\)\(\w+,\{\}\))\}\)', r'element:\2', s, count=1)
    if not n or not n2:
        sys.exit("Version de Studio non reconnue (onglets Quêtes / Quêtes photo introuvables)")

if not done_links:
    # Base secrète (→ Carte de région) et Quêtes photo (→ onglet de Quêtes) ne sont plus des liens du menu Interface (toutes les occurrences)
    s, n = re.subn(r',[\w$]+\?pjSubLink\(`/database/interface/(?:base-secrete|quetes-photo)`,`[^`]*`\):null', '', s)
    s, n2 = re.subn(r'[\w$]+\?pjSubLink\(`/database/interface/(?:base-secrete|quetes-photo)`,`[^`]*`\):null,?', '', s)
    print('Liens retirés du menu Interface : %d' % (n + n2))

open(path, 'w', encoding='utf-8').write(s)
print('Pages des plugins ajoutées dans Studio (' + path + '). Redémarre Pokémon Studio.')

# Pokémon Studio Extra : (ré)installe tout d'un coup dans Pokémon Studio, par exemple après une mise à jour de Studio
#   python installer_studio_extra.py [dossier de Studio]   (par défaut %LOCALAPPDATA%\Programs\pokemon-studio)
#   options : --bloquer-maj / --autoriser-maj (mises à jour automatiques de Studio), --sans-icone (garde l'icône du .exe)
#
# Étapes :
#   1. garde une copie des fichiers d'origine de Studio (.vite\.pj-origine) ; si Studio est déjà modifié, repart de
#      cette copie (on peut relancer l'installateur autant de fois qu'on veut)
#   2. toutes les pages : chaque tools\studio-*\installer_*.ps1 (fichiers copiés, index.html, preload.js, index.js)
#   3. code de Studio : pages et menus (patch_studio_pages.py), PV des natures, dossiers des icônes
#   4. thème rouge et nom « Pokémon Studio Extra » (theme_rouge.py), icône et nom du .exe (icone_exe.mjs, avec Node.js)
#   5. mises à jour automatiques de Studio bloquées ou non (une mise à jour efface Studio Extra)
# Les correctifs du code de Studio retrouvent les noms qui changent d'une version à l'autre (studio_patch.py).
import glob
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ORIGIN = '.pj-origine'
# fichiers de Studio modifiés (relatifs à resources\app\.vite)
TOUCHED = ['renderer/main_window/index.html', 'renderer/main_window/assets/index-*.js', 'renderer/main_window/assets/index-*.css',
           'build/index.js', 'build/preload.js']
UPDATE_HOOK = 'ipcMain.once(`studio-check-update`,'


def say(text, color=None):
    codes = {'red': '91', 'green': '92', 'yellow': '93', 'cyan': '96'}
    if color and os.environ.get('NO_COLOR') is None:
        print('\033[%sm%s\033[0m' % (codes[color], text))
    else:
        print(text)
    sys.stdout.flush()


def read(path):
    with open(path, encoding='utf-8-sig') as f:
        return f.read()


def write(path, text):
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(text)


class Installer:
    def __init__(self, studio, block_updates=None, exe_icon=True):
        self.studio = studio
        self.vite = os.path.join(studio, 'resources', 'app', '.vite')
        self.renderer = os.path.join(self.vite, 'renderer', 'main_window')
        self.build = os.path.join(self.vite, 'build')
        self.block_updates = block_updates
        self.exe_icon = exe_icon
        self.problems = []

    # --- 1. fichiers d'origine -----------------------------------------------------------------------
    def touched_files(self, root):
        out = []
        for pattern in TOUCHED:
            for path in glob.glob(os.path.join(root, *pattern.split('/'))):
                if '.bak' not in os.path.basename(path):
                    out.append(os.path.relpath(path, root))
        return sorted(out)

    def is_original(self):
        html = read(os.path.join(self.renderer, 'index.html'))
        preload = read(os.path.join(self.build, 'preload.js'))
        return 'pj-' not in html and 'pj-' not in preload

    def prepare(self):
        origin = os.path.join(self.vite, ORIGIN)
        if self.is_original():
            # Studio tout juste installé ou mis à jour : sa copie d'origine
            if os.path.isdir(origin):
                shutil.rmtree(origin)
            for rel in self.touched_files(self.vite):
                dst = os.path.join(origin, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy2(os.path.join(self.vite, rel), dst)
            say('Copie des fichiers d\'origine de Studio : %s' % origin)
        else:
            saved = self.touched_files(origin) if os.path.isdir(origin) else []
            current = self.touched_files(self.vite)
            if not saved or saved != current:
                raise SystemExit('Studio est déjà modifié et sa copie d\'origine ne correspond pas à cette version.\n'
                                 'Réinstalle Pokémon Studio (ou attends sa mise à jour) puis relance cet installateur.')
            for rel in saved:
                shutil.copy2(os.path.join(origin, rel), os.path.join(self.vite, rel))
            say('Studio remis dans son état d\'origine avant la réinstallation.')
        # anciennes pages et sauvegardes des installateurs
        for path in glob.glob(os.path.join(self.renderer, 'pj-*')):
            shutil.rmtree(path) if os.path.isdir(path) else os.remove(path)
        for path in glob.glob(os.path.join(self.build, 'pj-*')):
            os.remove(path)
        for folder in (self.renderer, os.path.join(self.renderer, 'assets'), self.build):
            for path in glob.glob(os.path.join(folder, '*.bak-*')):
                os.remove(path)

    # --- 2. pages ------------------------------------------------------------------------------------
    @staticmethod
    def page_spec(ps1):
        """Lit un installateur de page (installer_*.ps1) : fichiers copiés, balise de index.html, preload, index.js."""
        text = read(ps1)
        here = os.path.dirname(ps1)
        files = []
        for src, dest in re.findall(r"Copy-Item \(Join-Path \$here '([^']+)'\) (\$build|\(Join-Path \$renderer '[^']+'\))", text):
            if dest == '$build':
                files.append((os.path.join(here, src), 'build', None))
            else:
                sub = re.search(r"'([^']+)'", dest).group(1)
                files.append((os.path.join(here, src), 'renderer', sub))
        tag = re.search(r"\$tag = '(.*?)'\r?\n", text)
        preload = re.search(r"@'\r?\n(.*?)\r?\n'@", text, re.S)
        index = re.search(r'\$s \+= "(.*?)"\r?\n', text)
        if not (files and tag and preload and index):
            raise ValueError('installateur non reconnu : ' + ps1)
        index_text = index.group(1).replace('`n', '\n')
        return {'name': os.path.basename(ps1), 'files': files, 'tag': tag.group(1).replace("''", "'"),
                'preload': preload.group(1).replace('\r\n', '\n'), 'index': index_text}

    def pages(self):
        specs = []
        for ps1 in sorted(glob.glob(os.path.join(TOOLS, 'studio-*', 'installer_*.ps1'))):
            try:
                specs.append(self.page_spec(ps1))
            except (ValueError, OSError) as e:
                self.problems.append(str(e))
        html_path = os.path.join(self.renderer, 'index.html')
        preload_path = os.path.join(self.build, 'preload.js')
        index_path = os.path.join(self.build, 'index.js')
        html, preload, index = read(html_path), read(preload_path), read(index_path)
        tags = []
        for spec in specs:
            for src, where, sub in spec['files']:
                if where == 'build':
                    shutil.copy2(src, self.build)
                else:
                    os.makedirs(os.path.join(self.renderer, sub), exist_ok=True)
                    shutil.copy2(src, os.path.join(self.renderer, sub))
            tags.append('    ' + spec['tag'])
            preload = preload.rstrip() + '\n\n' + spec['preload'] + '\n'
            index += spec['index']
            say('  page : %s' % spec['name'].replace('installer_', '').replace('.ps1', ''))
        if '  </head>' not in html:
            raise SystemExit('index.html de Studio non reconnu')
        html = html.replace('  </head>', '\n'.join(tags) + '\n  </head>', 1)
        write(html_path, html)
        write(preload_path, preload)
        write(index_path, index)
        say('%d pages installées.' % len(specs), 'green')

    # --- 3. code de Studio --------------------------------------------------------------------------
    def bundle(self):
        found = [p for p in glob.glob(os.path.join(self.renderer, 'assets', 'index-*.js')) if '.bak' not in p]
        if len(found) != 1:
            raise SystemExit('Code de Studio introuvable (assets\\index-*.js)')
        return found[0]

    def run_patch(self, script, *args):
        result = subprocess.run([sys.executable, script, *args], capture_output=True, text=True, encoding='utf-8', errors='replace')
        out = (result.stdout + result.stderr).strip()
        ok = result.returncode == 0 or 'Déjà fait' in out
        say('  ' + (out.splitlines()[-1] if out else os.path.basename(script)), None if ok else 'red')
        if not ok:
            self.problems.append('%s : %s' % (os.path.basename(script), out))
        return ok

    def patch_code(self):
        bundle = self.bundle()
        self.run_patch(os.path.join(TOOLS, 'studio-plugins', 'patch_studio_pages.py'), bundle)
        self.run_patch(os.path.join(TOOLS, 'studio-natures', 'patch_natures_hp.py'), bundle)
        self.run_patch(os.path.join(TOOLS, 'studio-plugins', 'patch_studio_icons.py'), bundle)
        for path in glob.glob(os.path.join(self.renderer, 'assets', '*.bak-*')):
            os.remove(path)

    # --- 4. apparence -------------------------------------------------------------------------------
    def theme(self):
        self.run_patch(os.path.join(TOOLS, 'studio-theme', 'theme_rouge.py'), self.renderer)
        for path in glob.glob(os.path.join(self.renderer, '**', '*.bak-rouge'), recursive=True):
            os.remove(path)

    def icon(self):
        exe = os.path.join(self.studio, 'Pokémon Studio.exe')
        if not self.exe_icon or not os.path.exists(exe):
            return
        node = shutil.which('node')
        if not node:
            say('  Node.js introuvable : l\'icône et le nom du .exe restent ceux de Studio.', 'yellow')
            return
        tmp = exe + '.pj-tmp'
        script = os.path.join(TOOLS, 'studio-theme', 'icone_exe.mjs')
        result = subprocess.run([node, script, exe, os.path.join(TOOLS, 'studio-theme', 'icon.ico'), tmp],
                                capture_output=True, text=True, encoding='utf-8', errors='replace')
        if result.returncode == 0 and os.path.exists(tmp):
            os.replace(tmp, exe)
            say('  Icône rouge et nom « Pokémon Studio Extra » pour le .exe.')
        else:
            if os.path.exists(tmp):
                os.remove(tmp)
            say('  Icône du .exe non changée : ' + (result.stderr or result.stdout).strip()[-200:], 'yellow')

    # --- 5. mises à jour ----------------------------------------------------------------------------
    def updates(self):
        if self.block_updates is None:
            return
        path = os.path.join(self.build, 'index.js')
        text = read(path)
        i = text.find(UPDATE_HOOK)
        if i < 0:
            say('  Vérification des mises à jour de Studio non trouvée : réglage ignoré.', 'yellow')
            return
        if self.block_updates:
            # Studio ne cherche plus de mise à jour (une mise à jour remplacerait Studio Extra)
            m = re.compile(re.escape(UPDATE_HOOK) + r'\(\)=>[^)]*?checkForUpdates\(\)\)').match(text, i)
            if m:
                text = text[:m.start()] + UPDATE_HOOK + '()=>null)' + text[m.end():]
                write(path, text)
                say('  Mises à jour automatiques de Studio bloquées.')
            else:
                say('  Vérification des mises à jour de Studio non reconnue : réglage ignoré.', 'yellow')
        else:
            say('  Mises à jour automatiques de Studio laissées actives.')

    def run(self):
        say('Pokémon Studio Extra : installation dans %s' % self.studio, 'cyan')
        self.prepare()
        say('Pages :', 'cyan')
        self.pages()
        say('Code de Studio :', 'cyan')
        self.patch_code()
        say('Apparence :', 'cyan')
        self.theme()
        self.icon()
        self.updates()
        if self.problems:
            say('\nTerminé avec des erreurs :', 'red')
            for p in self.problems:
                say('  - ' + p, 'red')
            return 1
        say('\nPokémon Studio Extra est installé : tu peux ouvrir Studio.', 'green')
        return 0


def studio_running(studio):
    if os.name != 'nt':
        return False
    out = subprocess.run(['tasklist', '/FI', 'IMAGENAME eq Pokémon Studio.exe', '/NH'], capture_output=True, text=True,
                         encoding='mbcs', errors='replace').stdout
    return 'Pok' in out and 'Studio' in out


def main(argv):
    args = [a for a in argv if not a.startswith('--')]
    studio = args[0] if args else os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Programs', 'pokemon-studio')
    if not os.path.isdir(os.path.join(studio, 'resources', 'app', '.vite')):
        raise SystemExit('Pokémon Studio introuvable : ' + studio)
    if studio_running(studio):
        raise SystemExit('Ferme Pokémon Studio (toutes ses fenêtres) puis relance l\'installateur.')
    block = True if '--bloquer-maj' in argv else False if '--autoriser-maj' in argv else None
    return Installer(studio, block_updates=block, exe_icon='--sans-icone' not in argv).run()


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

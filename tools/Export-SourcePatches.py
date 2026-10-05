"""Export modified source without changing any component's real Git index."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import uuid

ROOT = Path(__file__).resolve().parent.parent

def git(repository, *arguments, env=None):
    return subprocess.check_output(['git', '-C', str(repository), *arguments], env=env)

def include(component, name):
    if name.startswith('libs/') or name.endswith(('.aar', '.jar', '.slnx')):
        return False
    if component == 'Pojlib' and name.startswith('src/main/assets/'):
        return name == 'src/main/assets/lwjgl/version'
    if name == 'ProjectSettings/Packages/com.unity.testtools.codecoverage/Settings.json':
        return False
    return True

def main():
    manifest = json.loads((ROOT / 'source-lock.json').read_text())
    (ROOT / 'source-patches').mkdir(exist_ok=True)
    (ROOT / 'build').mkdir(exist_ok=True)
    for component in manifest['components']:
        source = ROOT / 'sources' / component['directory']
        if git(source, 'rev-parse', 'HEAD').decode().strip() != component['commit']:
            raise RuntimeError(f"Update source-lock.json before exporting {source.name}")
        changed = git(source, 'diff', '--name-only', 'HEAD', '-z').split(b'\0')
        new = git(source, 'ls-files', '--others', '--exclude-standard', '-z').split(b'\0')
        names = sorted({p.decode('utf-8') for p in changed + new if p and include(source.name, p.decode('utf-8'))})
        index = ROOT / 'build' / f'export-index-{uuid.uuid4().hex}'
        env = dict(os.environ, GIT_INDEX_FILE=str(index))
        try:
            git(source, 'read-tree', 'HEAD', env=env)
            if names:
                git(source, 'add', '--sparse', '--', *names, env=env)
            git(source, 'diff', '--cached', '--binary', '--full-index', '--no-ext-diff',
                '--output=' + str(ROOT / component['patch']), 'HEAD', env=env)
            print(f'{source.name}: {len(names)} source files exported')
        finally:
            index.unlink(missing_ok=True)
    bridge = ROOT / 'sources' / 'Visor-Android-Bridge'
    target = ROOT / 'bridge-source'
    shutil.copytree(bridge / 'src', target / 'src', dirs_exist_ok=True)
    shutil.copy2(bridge / 'LICENSE.md', target / 'LICENSE.md')
    print('Standalone Android bridge source and license exported')

if __name__ == '__main__':
    main()

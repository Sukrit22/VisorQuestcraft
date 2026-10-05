"""Verify published port patches on pristine pinned Git indexes, without resetting sources."""
import json
import os
from pathlib import Path
import subprocess
import uuid

ROOT = Path(__file__).resolve().parent.parent

def main():
    lock = json.loads((ROOT / 'source-lock.json').read_text())
    (ROOT / 'build').mkdir(exist_ok=True)
    for component in lock['components']:
        repository = ROOT / 'sources' / component['directory']
        index = ROOT / 'build' / f'verify-index-{uuid.uuid4().hex}'
        env = dict(os.environ, GIT_INDEX_FILE=str(index))
        try:
            subprocess.run(['git', '-C', str(repository), 'read-tree', component['commit']], env=env, check=True)
            subprocess.run(['git', '-C', str(repository), 'apply', '--cached', '--check',
                            str(ROOT / component['patch'])], env=env, check=True)
            print(f"PASS patch on pinned base: {component['directory']}")
        finally:
            index.unlink(missing_ok=True)

if __name__ == '__main__':
    main()

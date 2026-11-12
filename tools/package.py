#!/usr/bin/env python3
"""Build the addon after bounded syntax and dependency checks, without game input."""
import argparse
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'SquanchOn'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--working-tree', action='store_true',
                    help='Include untracked addon source for isolated candidate review; never private assembly')
parser.add_argument('--check-only', action='store_true', help='Validate without creating an archive')
args = parser.parse_args()
if args.working_tree:
    files = sorted(path for path in ADDON.rglob('*') if path.is_file() or path.is_symlink())
else:
    tracked = subprocess.check_output(
        ['git', 'ls-files', '-z', '--', 'SquanchOn/'], cwd=ROOT
    ).decode().split('\0')
    files = sorted(ROOT / name for name in tracked if name)
if not files:
    raise SystemExit('No addon source files selected.')
for path in files:
    relative = path.relative_to(ADDON)
    if any(part.casefold() in {'private-media', 'private-provenance', 'wtf', 'savedvariables', '__pycache__'}
           for part in relative.parts) or path.name in {'LocalMedia.lua', 'HordeReticleData.lua'}:
        raise SystemExit(f'Private assembly content cannot enter a public package: {relative}')
for path in files:
    if path.is_symlink() or not path.is_file():
        raise SystemExit(f'Release file must be a regular file: {path.relative_to(ROOT)}')
packaged = set(files)

# Check both notice manifests against their own relative-path roots.
for base in (ROOT, ADDON):
    manifest = json.loads((base / 'reuse-manifest.json').read_text())
    for component in manifest['components']:
        for record in component['files']:
            path = base / record['path']
            if path not in packaged:
                raise SystemExit(f'Unpackaged attributed file: {record["path"]}')
            if hashlib.sha256(path.read_bytes()).hexdigest() != record['sha256']:
                raise SystemExit(f'Reuse hash mismatch: {record["path"]}')
if (ROOT / 'LICENSE').read_bytes() != (ADDON / 'LICENSE').read_bytes():
    raise SystemExit('Root and packaged LICENSE copies differ.')

compiler = shutil.which('luac5.1')
if not compiler:
    raise SystemExit('Install Lua 5.1 (luac5.1) before building this addon.')
for path in files:
    if path.suffix == '.lua':
        subprocess.run([compiler, '-p', str(path)], check=True)
seen = set()
def dependency(path):
    path = path.resolve()
    if path in seen:
        return
    if path not in packaged:
        raise SystemExit(f'Missing tracked load dependency: {path.relative_to(ROOT)}')
    seen.add(path)
    if path.suffix == '.xml':
        for node in ET.parse(path).iter():
            filename = node.attrib.get('file')
            if filename:
                dependency(path.parent / filename.replace('\\', '/'))

toc = ADDON / 'SquanchOn.toc'
for line in toc.read_text().splitlines():
    if line.startswith(('## RequiredDeps:', '## Dependencies:')):
        required = [item.strip() for item in line.split(':', 1)[1].split(',') if item.strip()]
        if required:
            raise SystemExit(f'Standalone SquanchOn cannot require external addons: {required}')

for line in toc.read_text().splitlines():
    if line.strip() and not line.startswith('#'):
        dependency(ADDON / line.strip().replace('\\', '/'))
if args.check_only:
    print(f'Checked {len(seen)} load dependencies, {len(files)} files, Lua syntax and reuse hashes.')
    raise SystemExit(0)
version = next(line.split(':', 1)[1].strip() for line in toc.read_text().splitlines()
               if line.startswith('## Version:'))
output = ROOT / 'dist'
output.mkdir(exist_ok=True)
archive = output / f'SquanchOn-{version}.zip'
temporary = archive.with_suffix('.zip.tmp')
with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED) as package:
    for path in files:
        # Normalize timestamp/permissions so local checkout times do not change the ZIP.
        entry = zipfile.ZipInfo(path.relative_to(ROOT).as_posix(), (1980, 1, 1, 0, 0, 0))
        entry.create_system = 3
        entry.external_attr = 0o100644 << 16
        entry.compress_type = zipfile.ZIP_DEFLATED
        package.writestr(entry, path.read_bytes())
temporary.replace(archive)
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix('.zip.sha256').write_text(f'{digest}  {archive.name}\n')
print(f'Checked {len(seen)} load dependencies and reuse hashes; packaged {len(files)} files; '
      f'built {archive.name}; SHA-256 {digest}')

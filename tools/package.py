#!/usr/bin/env python3
"""Build the addon after bounded syntax and dependency checks, without game input."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'SquanchOn'
compiler = shutil.which('luac5.1')
if not compiler:
    raise SystemExit('Install Lua 5.1 (luac5.1) before building this addon.')
for path in sorted(ADDON.rglob('*.lua')):
    subprocess.run([compiler, '-p', str(path)], check=True)
seen = set()
def dependency(path):
    if path in seen:
        return
    if not path.is_file():
        raise SystemExit(f'Missing load dependency: {path.relative_to(ROOT)}')
    seen.add(path)
    if path.suffix == '.xml':
        for node in ET.parse(path).iter():
            filename = node.attrib.get('file')
            if filename:
                dependency(path.parent / filename.replace('\\', '/'))

toc = ADDON / 'SquanchOn.toc'
for line in toc.read_text().splitlines():
    if line.strip() and not line.startswith('#'):
        dependency(ADDON / line.strip().replace('\\', '/'))
version = next(line.split(':', 1)[1].strip() for line in toc.read_text().splitlines()
               if line.startswith('## Version:'))
output = ROOT / 'dist'
output.mkdir(exist_ok=True)
archive = output / f'SquanchOn-{version}.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as package:
    for path in sorted(ADDON.rglob('*')):
        if path.is_symlink():
            raise SystemExit(f'Symlink is not permitted in release: {path}')
        if path.is_file():
            package.write(path, path.relative_to(ROOT))
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix('.zip.sha256').write_text(f'{digest}  {archive.name}\n')
print(f'Checked {len(seen)} load dependencies; built {archive.name}; SHA-256 {digest}')

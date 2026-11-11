#!/usr/bin/env python3
"""Assemble a PRIVATE offline runtime from explicit, already-scoped originals."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ORIGINALS = ('ElvUI', 'ElvUI_Libraries', 'ElvUI_Options', 'ElvUI_BenikUI')
FOLDERS = (*ORIGINALS, 'SquanchOn')
MAX_FILE = 32 * 1024 * 1024
MAX_TOTAL = 512 * 1024 * 1024
BLOCKED = {'wtf', 'savedvariables', 'credentials', '.git', '.ssh'}
NOTICE = """PRIVATE OWNER-LOCAL RUNTIME — NOT FOR REDISTRIBUTION

Do not publish, upload, attach to an issue, push to GitHub, or redistribute this
ZIP, its extracted original addon trees, or its owner seed. It contains original
third-party components retained for private local assembly; some components or
assets have distribution restrictions. Existing authorship and license files
remain attached. This notice grants no new rights or permission.

The private ElvUI seed may contain owner-specific settings. No WTF directory,
SavedVariables export or credentials are accepted by this tool. The assembly
does not install anything, modify a game, migrate settings, or prove live visual
equivalence. Keep the ZIP and its output directory private.

An explicitly supplied original reticle may override the public reticle only
inside this private ZIP. Its original code, warning artwork, sound and attached
provenance remain private; no redistribution permission is inferred.
"""


def fail(message):
    raise ValueError(message)


def explicit_path(value):
    path = Path(value).expanduser().absolute()
    for item in (path, *path.parents):
        if item.is_symlink():
            fail(f'Symlink input/output path is not accepted: {item}')
    return path.resolve()


def safe_name(value):
    if '\\' in value or ':' in value or '\x00' in value:
        fail(f'Unsafe archive/file path: {value!r}')
    path = PurePosixPath(value)
    if path.is_absolute() or any(part in ('', '.', '..') for part in value.split('/')):
        fail(f'Unsafe archive/file path: {value!r}')
    if any(part.casefold() in BLOCKED or part.lower().endswith('.cred') for part in path.parts):
        fail(f'Private metadata/credential path is not accepted: {value!r}')
    return path.as_posix()


def read_regular(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        record = os.fstat(descriptor)
        if not stat.S_ISREG(record.st_mode) or record.st_size > MAX_FILE:
            fail(f'Expected bounded regular file: {path}')
        with os.fdopen(descriptor, 'rb', closefd=False) as stream:
            data = stream.read(MAX_FILE + 1)
        if len(data) > MAX_FILE:
            fail(f'File exceeds size bound: {path}')
        return data
    finally:
        os.close(descriptor)


def originals(source):
    result = {}
    paths = {}
    total = 0
    for name in ORIGINALS:
        folder = source / name
        if not folder.is_dir() or folder.is_symlink():
            fail(f'Missing regular original addon directory: {folder}')
        for directory, children, filenames in os.walk(folder, followlinks=False):
            for child in children:
                path = Path(directory) / child
                if path.is_symlink() or not path.is_dir():
                    fail(f'Unsafe original directory: {path}')
                safe_name(path.relative_to(source).as_posix())
            for filename in filenames:
                path = Path(directory) / filename
                relative = safe_name(path.relative_to(source).as_posix())
                data = read_regular(path)
                total += len(data)
                if total > MAX_TOTAL:
                    fail('Original addon trees exceed expanded size bound')
                result[relative] = data
                paths[relative] = path
    return result, paths


def addon_package(path):
    result = {}
    with zipfile.ZipFile(path) as archive:
        if sum(entry.file_size for entry in archive.infolist()) > MAX_TOTAL:
            fail('SquanchOn archive exceeds expanded size bound')
        for entry in archive.infolist():
            name = safe_name(entry.filename.rstrip('/') if entry.is_dir() else entry.filename)
            if PurePosixPath(name).parts[0] != 'SquanchOn':
                fail(f'Public package has an unexpected root: {name}')
            mode = entry.external_attr >> 16
            if stat.S_ISLNK(mode) or (stat.S_IFMT(mode) and not
                    (stat.S_ISREG(mode) or entry.is_dir() and stat.S_ISDIR(mode))):
                fail(f'Archive entry is not a regular file/directory: {name}')
            if entry.is_dir():
                continue
            if name in result or entry.file_size > MAX_FILE:
                fail(f'Duplicate or oversized archive entry: {name}')
            result[name] = archive.read(entry)
    return result


def reticle_override(source, files):
    """Read only the observed original reticle and its narrow asset/notice set."""
    if not source.is_dir():
        fail('Explicit original reticle addon directory does not exist')
    selected = {
        'HordeReticle.lua': 'HordeReticle.lua',
        'HordeReticleData.lua': 'HordeReticleData.lua',
    }
    for name in ('Aura104.tga', 'Aura105.tga', 'Aura17.tga', 'Aura22.tga', 'Aura4.tga', 'throwknife.ogg'):
        relative = f'media/horde-reticle/{name}'
        selected[relative] = relative
    # Preserve the existing world-target ring too; the public alpha regenerated it.
    selected['media/Crosshairs/circle-dashed.tga'] = 'media/Crosshairs/circle-dashed.tga'
    # The current installed donor keeps its header-named license/report under
    # licenses/. Accept only these inspected names, never a directory sweep.
    license_name = ('LICENSE-M33-GPLv2.txt' if (source / 'LICENSE-M33-GPLv2.txt').exists()
                    else 'licenses/M33-GPLv2.txt')
    selected[license_name] = 'private-provenance/reticle/LICENSE-M33-GPLv2.txt'
    for original in ('REPORT.md', 'licenses/HordeReticle-PROVENANCE.md', 'licenses/HordeReticle-ASSETS.json'):
        if (source / original).exists():
            selected[original] = f'private-provenance/reticle/{PurePosixPath(original).name}'
    if not any('PROVENANCE' in name or name == 'REPORT.md' for name in selected):
        fail('Original reticle provenance report is missing')
    paths, records = {}, {}
    for relative, destination in selected.items():
        path = explicit_path(source / relative)
        data = read_regular(path)
        output = f'SquanchOn/{destination}'
        previous = files.get(output)
        records[output] = {
            'source_relative': relative, 'sha256': hashlib.sha256(data).hexdigest(),
            'public_package_sha256': hashlib.sha256(previous).hexdigest() if previous is not None else None,
        }
        files[output] = data
        paths[output] = path
    # The original media root uses addonName from WoW's varargs, so changing
    # the folder to SquanchOn needs no edits to original executable Lua bytes.
    code = files['SquanchOn/HordeReticle.lua'].decode('utf-8')
    if ('local addonName, addon = ...' not in code or 'addon.HordeReticleData' not in code
            or '"\\\\media\\\\horde-reticle\\\\"' not in code):
        fail('Original reticle namespace/media contract differs from the inspected source')
    toc_path = 'SquanchOn/SquanchOn.toc'
    if toc_path not in files or 'SquanchOn/ReticleConfig.lua' not in files:
        fail('Public package does not have the expected reticle configuration seam')
    before = files[toc_path]
    lines = before.splitlines(keepends=True)
    locations = [index for index, line in enumerate(lines) if line.strip() == b'ReticleConfig.lua']
    if len(locations) != 1 or any(line.strip() == b'HordeReticleData.lua' for line in lines):
        fail('Public TOC reticle configuration seam is missing or ambiguous')
    index = locations[0]
    if not any(line.strip() == b'HordeReticle.lua' for line in lines[index + 1:]):
        fail('Original reticle data must precede its renderer')
    lines[index] = lines[index].replace(b'ReticleConfig.lua', b'HordeReticleData.lua')
    files[toc_path] = b''.join(lines)
    del files['SquanchOn/ReticleConfig.lua']
    records[toc_path] = {
        'source_relative': None, 'source': 'private-reticle-load-order',
        'sha256': hashlib.sha256(files[toc_path]).hexdigest(),
        'public_package_sha256': hashlib.sha256(before).hexdigest(),
    }
    return paths, {'files': records, 'removed_public_files': ['SquanchOn/ReticleConfig.lua']}


def load_line(line):
    conditions = re.findall(r'\[(AllowLoadGameType|ExcludeLoadGameType)\s+([^\]]+)\]', line)
    for mode, values in conditions:
        matches = 'camelot' in {item.strip() for item in values.split(',')}
        if (mode == 'AllowLoadGameType' and not matches) or (mode == 'ExcludeLoadGameType' and matches):
            return None
    clean = re.sub(r'\[(AllowLoadGameType|ExcludeLoadGameType)\s+[^\]]+\]', '', line).strip()
    if '[' in clean or ']' in clean:
        fail(f'Unsupported executable TOC condition: {line}')
    return clean.replace('\\', '/')


def validate(files):
    # Relative XML references may use .. within their addon; they may not escape
    # to another root or the host filesystem. No extraction or Lua execution.
    def reference(parent, value):
        value = value.replace('\\', '/')
        if value.startswith('/') or ':' in value or '\x00' in value:
            fail(f'Unsafe executable reference: {value!r}')
        pieces = list(PurePosixPath(parent).parent.parts)
        owner = pieces[0]
        for part in value.split('/'):
            if part == '..':
                if len(pieces) <= 1:
                    fail(f'Executable reference escapes addon: {parent}: {value}')
                pieces.pop()
            elif part not in ('', '.'):
                pieces.append(part)
        name = safe_name('/'.join(pieces))
        if pieces[0] != owner or name not in files:
            fail(f'Missing executable dependency: {parent}: {value}')
        return name

    metadata, direct, seen = {}, {}, set()
    for folder in FOLDERS:
        toc = f'{folder}/{folder}.toc'
        if toc not in files:
            fail(f'Missing named addon TOC: {toc}')
        metadata[folder], direct[folder] = {}, []
        for line in files[toc].decode('utf-8-sig').splitlines():
            if line.startswith('##') and ':' in line:
                key, value = line[2:].split(':', 1)
                if '[' not in value:
                    metadata[folder][key.strip()] = value.strip()
            elif line.strip() and not line.lstrip().startswith('#'):
                selected = load_line(line)
                if selected:
                    direct[folder].append(reference(toc, selected))
        for dependency in metadata[folder].get('RequiredDeps', '').split(','):
            if dependency.strip() and dependency.strip() not in FOLDERS:
                fail(f'Unbundled required dependency: {folder}: {dependency.strip()}')

    def visit(name):
        if name in seen:
            return
        seen.add(name)
        if name.lower().endswith('.xml'):
            document = ET.fromstring(files[name])
            for node in document.iter():
                if node.tag.rsplit('}', 1)[-1] in {'Script', 'Include'} and node.get('file'):
                    visit(reference(name, node.get('file')))

    expected = {
        'ElvUI': ['Game/SquancherUnitFramesOnly.xml', 'SquancherUnitFrameMedia.lua',
                  'SquancherUnitFrameSeed.lua', 'SquancherUnitFramesOnly.lua'],
        'ElvUI_Libraries': ['Game/load_forever.xml'],
        'ElvUI_Options': ['Game/SquancherUnitFrameOptions.xml', 'SquancherUnitFrameHeader.lua',
                          'SquancherUnitFramesOnly.lua'],
        'ElvUI_BenikUI': ['SquancherUnitFramesOnly.xml', 'SquancherUnitFramesOnly.lua'],
    }
    for folder, wanted in expected.items():
        if direct[folder] != [f'{folder}/{name}' for name in wanted]:
            fail(f'{folder} is not the expected complete scoped runtime; upstream source archives are insufficient')
    for folder, wanted in {'ElvUI': {'ElvUI_Libraries'}, 'ElvUI_Options': {'ElvUI'},
                           'ElvUI_BenikUI': {'ElvUI'}, 'ElvUI_Libraries': set()}.items():
        actual = {item.strip() for item in metadata[folder].get('RequiredDeps', '').split(',') if item.strip()}
        if actual != wanted:
            fail(f'Original required-dependency contract changed: {folder}')
    native_version = metadata['ElvUI'].get('Version')
    if not native_version or any(metadata[name].get('Version') != native_version
                                 for name in ('ElvUI_Libraries', 'ElvUI_Options')):
        fail('ElvUI core, library and options versions must match exactly')
    version = re.match(r'v?(\d+(?:\.\d+)?)', native_version)
    minimum = metadata['ElvUI_BenikUI'].get('X-ElvuiVersion')
    if not version or not minimum or float(version.group(1)) < float(minimum):
        fail('BenikUI minimum native ElvUI version is not satisfied')
    if metadata['ElvUI_Libraries'].get('X-oUF') != 'ElvUF':
        fail('Original native ElvUF metadata is required')
    if metadata['ElvUI_Options'].get('LoadOnDemand') != '1':
        fail('Original options must retain on-demand loading')
    if not {'ElvUI', 'ElvUI_BenikUI'}.issubset(
            {item.strip() for item in metadata['SquanchOn'].get('RequiredDeps', '').split(',')}):
        fail('SquanchOn must declare its native ElvUI and Benik owners')
    forbidden = {'UnitFrames.lua', 'UnitFrameImport.lua', 'UnitFrameOptions.lua', 'TooltipSkin.lua'}
    if metadata['SquanchOn'].get('X-oUF') or any(PurePosixPath(name).name in forbidden
                                               or '/libs/oUF/' in name for name in direct['SquanchOn']):
        fail('SquanchOn contains a second active alpha frame/tooltip owner')
    for folder, dependencies in direct.items():
        seen.add(f'{folder}/{folder}.toc')
        for name in dependencies:
            visit(name)
    if any(name.startswith('SquanchOn/') and (PurePosixPath(name).name in forbidden
            or '/libs/oUF/' in name) for name in seen):
        fail('Executable XML closure contains a second alpha frame/tooltip owner')
    scope = files['ElvUI/SquancherUnitFramesOnly.lua'].decode('utf-8')
    for marker in ("object.name=='UnitFrames'", "object.name=='Tooltip'", 'function E:RegisterModule'):
        if marker not in scope:
            fail('Expected original owner-confinement lifecycle is absent')
    benik_scope = files['ElvUI_BenikUI/SquancherUnitFramesOnly.lua'].decode('utf-8')
    if "if name=='Units'" not in benik_scope or 'function BUI:InitializeModules()' not in benik_scope:
        fail('Expected Benik unit-frame-only activation scope is absent')
    for path in ('ElvUI/LICENSE.txt', 'ElvUI_Options/LICENSE.txt', 'ElvUI_BenikUI/LICENSE.txt',
                 'ElvUI_Libraries/Game/Shared/oUF/LICENSE.txt',
                 'ElvUI/SquancherMedia/Tukui.blp', 'ElvUI/SquancherMedia/ForcedSquare.ttf',
                 'ElvUI/SquancherMedia/HarryP.ttf',
                 'ElvUI/Game/Shared/Media/Fonts/Expressway.ttf',
                 'ElvUI_BenikUI/media/fonts/homizio_bold.ttf',
                 'SquanchOn/OriginalUnitFramesBridge.lua', 'SquanchOn/LayoutUnitFrames.lua'):
        if path not in files:
            fail(f'Required original media/license/adapter is missing: {path}')
    for adapter in ('OriginalUnitFramesBridge.lua', 'LayoutUnitFrames.lua'):
        if f'SquanchOn/{adapter}' not in seen:
            fail(f'Native adapter is not executable: {adapter}')
    return metadata, sorted(seen)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-addons', required=True, help='Explicit installed scoped originals directory (read-only)')
    parser.add_argument('--squanchon-zip', required=True, help='Candidate ZIP created by tools/package.py')
    parser.add_argument('--output-dir', required=True, help='NEW private output directory outside the repository')
    parser.add_argument('--reticle-addon', help='Optional explicit original SQMS addon directory; private reticle override only')
    args = parser.parse_args()
    source, package, output = map(explicit_path, (args.source_addons, args.squanchon_zip, args.output_dir))
    reticle = explicit_path(args.reticle_addon) if args.reticle_addon else None
    if output.exists() or output.is_relative_to(ROOT) or output.is_relative_to(source):
        fail('Output must be NEW, outside the repository and outside the source addon tree')
    if reticle and output.is_relative_to(reticle):
        fail('Output must be outside the original reticle addon tree')
    if not output.parent.is_dir():
        fail('Output parent must already exist; no implicit directory tree is created')
    if not source.is_dir():
        fail('Explicit source addon directory does not exist')
    if not package.is_file():
        fail('Candidate SquanchOn ZIP is not ready; build it with tools/package.py first')
    package_bytes = read_regular(package)
    files, source_paths = originals(source)
    public_files = addon_package(package)
    public_hashes = {name: {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
                     for name, data in sorted(public_files.items())}
    files.update(public_files)
    overrides = {'files': {}, 'removed_public_files': []}
    reticle_paths = {}
    if reticle:
        reticle_paths, overrides = reticle_override(reticle, files)
        source_paths.update(reticle_paths)
    if sum(map(len, files.values())) > MAX_TOTAL:
        fail('Complete assembly exceeds expanded size bound')
    folded = [name.casefold() for name in files]
    if len(folded) != len(set(folded)):
        fail('Case-insensitive file collisions are unsafe for portable installation')
    metadata, closure = validate(files)
    if reticle and not {'SquanchOn/HordeReticle.lua', 'SquanchOn/HordeReticleData.lua'}.issubset(closure):
        fail('Private original reticle renderer/data are not executable')
    def classification(name):
        if name in overrides['files']:
            return 'owner-local-reticle' if name in reticle_paths else 'private-reticle-load-order'
        return 'scoped-original' if name in source_paths else 'squanchon-package'
    manifest = {
        'private_not_for_redistribution': True, 'format': 2, 'game_type': 'camelot',
        'folders': list(FOLDERS), 'versions': {name: metadata[name].get('Version') for name in FOLDERS},
        'squanchon_input_sha256': hashlib.sha256(package_bytes).hexdigest(),
        'public_package_files': public_hashes, 'private_reticle_override': overrides,
        'executable_closure': closure,
        'files': {name: {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                         'source': classification(name)}
                  for name, data in sorted(files.items())},
    }
    # Re-attest every original and the package after reading/validation, before output.
    if read_regular(package) != package_bytes or any(read_regular(path) != files[name]
                                                   for name, path in source_paths.items()):
        fail('Input changed during assembly; no output was created')
    output.mkdir(mode=0o700)  # Exclusive creation; never overwrite another output.
    os.chmod(output, 0o700)
    notice_path = output / 'PRIVATE-NOT-FOR-REDISTRIBUTION.txt'
    notice_path.write_text(NOTICE)
    manifest_path = output / 'manifest.json'
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    archive_path = output / 'SquanchOn-PRIVATE-local-runtime.zip'
    archived = dict(files)
    archived[notice_path.name] = NOTICE.encode()
    with zipfile.ZipFile(archive_path, 'x', zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(archived.items()):
            entry = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)
    with zipfile.ZipFile(archive_path) as archive:
        for name, data in archived.items():
            if hashlib.sha256(archive.read(name)).digest() != hashlib.sha256(data).digest():
                fail(f'Output hash verification failed: {name}')
    digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
    (output / (archive_path.name + '.sha256')).write_text(f'{digest}  {archive_path.name}\n')
    for path in output.iterdir():
        path.chmod(0o600)
    print(f'PRIVATE assembly verified: {len(files)} files, {len(closure)} executable dependencies; {archive_path}')
    print(f'SHA-256 {digest}; originals unchanged; no installation or live acceptance performed.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, zipfile.BadZipFile, ET.ParseError, UnicodeError) as error:
        raise SystemExit(f'Assembly refused: {error}') from None

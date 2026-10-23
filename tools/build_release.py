#!/usr/bin/env python3
"""Build installable full/patch ZIPs using an explicit runtime allowlist."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

RUNTIME_DIRS = ('assets', 'data', 'gmarc', 'lib', 'nuzlocke', 'qol', 'qoltoggles', 'stadium2', 'touch', 'wilds')
ROOT_FILES = ('manifest.json', 'main.lua', 'kim_main.lua', 'mod.card', 'README.md',
              'README_KIM_ARENA.md', 'OLDER_UPDATE_NOTES.md', 'ASSET_NOTICES.md',
              'THIRD_PARTY_NOTICES.md', 'Gen2_AiO_handoff_spec_v5.md', 'tools/import_hd_pokemon.py')


def build(root, output, tag=None, previous=None):
    manifest = json.loads((root / 'manifest.json').read_text())
    version = manifest['version']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('manifest version must be a numeric semantic version')
    if tag and tag != 'v' + version:
        raise ValueError(f'release tag must be v{version}, got {tag}')
    if manifest.get('github') != 'drglitchyphd/aio-recomp':
        raise ValueError('manifest must enable this repository for updates')
    paths = set(ROOT_FILES)
    for directory in RUNTIME_DIRS:
        folder = root / directory
        if not folder.is_dir() or not any(folder.rglob('*')):
            raise ValueError(f'missing bundled directory: {directory}; restore the full build first')
        for p in folder.rglob('*'):
            if p.is_symlink():
                raise ValueError(f'symlinks are not allowed in a release: {p}')
            if p.is_file() and not any(part.startswith('.') for part in p.relative_to(folder).parts):
                if p.suffix.lower() in ('.gb', '.gbc', '.gba', '.n64', '.z64', '.v64'):
                    raise ValueError(f'ROM file cannot be packaged: {p}')
                paths.add(p.relative_to(root).as_posix())
    files = {name: (root / name).read_bytes() for name in sorted(paths)}
    archives = [(f"{manifest['id']}-{version}.zip", files)]
    if previous:
        with zipfile.ZipFile(previous) as old:
            old_manifest = json.loads(old.read('manifest.json'))
            if old_manifest['id'] != manifest['id']:
                raise ValueError('previous ZIP belongs to a different mod')
            old_version = old_manifest['version']
            if not re.fullmatch(r'\d+\.\d+\.\d+', old_version):
                raise ValueError('invalid previous version')
            if tuple(map(int, old_version.split('.'))) >= tuple(map(int, version.split('.'))):
                raise ValueError('previous ZIP must be older than this build')
            # Patch ZIPs overlay files; deletions need a full installation.
            removed = set(old.namelist()) - set(files)
            removed = {p for p in removed if not p.endswith('/') and not p.endswith('/.gitkeep')}
            if removed:
                raise ValueError('overlay patch cannot delete files: ' + ', '.join(sorted(removed)))
            patch = {name: body for name, body in files.items()
                     if name not in old.namelist() or body != old.read(name)}
        archives.append((f'Gen2-AIO_patch_{old_version}_to_{version}.zip', patch))
    output.mkdir(parents=True, exist_ok=True)
    sums = []
    for name, contents in archives:
        path = output / name
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
            for rel, body in contents.items():
                info = zipfile.ZipInfo(rel, date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                z.writestr(info, body)
        with zipfile.ZipFile(path) as z:
            assert z.testzip() is None
            assert json.loads(z.read('manifest.json'))['version'] == version
            assert 'main.lua' in z.namelist()
        sums.append(hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + name)
        print(f'{path}: {len(contents)} files')
    (output / 'SHA256SUMS').write_text('\n'.join(sums) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, default=Path('dist'))
    parser.add_argument('--tag')
    parser.add_argument('--previous-zip', type=Path)
    args = parser.parse_args()
    build(args.root.resolve(), args.output, args.tag, args.previous_zip)

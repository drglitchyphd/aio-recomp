#!/usr/bin/env python3
"""Build installable full/patch ZIPs using an explicit runtime allowlist.

Every release ships the full ZIP (<id>-<version>.zip). A release built with
--previous-zip also ships an overlay patch (<id>_patch_<old>_to_<new>.zip)
holding only the changed files, for players who unzip over their folder. An
overlay cannot delete files, so a release that removes files, changes the mod
id, or bumps the major version is a *full-install* release: it ships only the
full ZIP. Ask for one with --full-install, or let it follow from the previous
ZIP (a new major version or a known identity change).
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

RUNTIME_DIRS = ('assets', 'data', 'gmarc', 'lib', 'nuzlocke', 'qol', 'qoltoggles', 'stadium2', 'touch', 'wilds')
ROOT_FILES = ('manifest.json', 'main.lua', 'kim_main.lua', 'mod.card', 'README.md',
              'README_CRYSTAL_AIO.md', 'OLDER_UPDATE_NOTES.md', 'ASSET_NOTICES.md',
              'THIRD_PARTY_NOTICES.md', 'FEATURES.md', 'Crystal_AiO_handoff_spec_v5.md', 'tools/import_hd_pokemon.py')
# Former ids of this mod (old -> new). The game installs a mod under its id,
# so a renamed build is a new install beside the old one: never a patch.
IDENTITY_TRANSITIONS = {('KIM_ARENA', 'gen2-aio'), ('gen2-aio', 'crystal-aio')}


def semver(version):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version or ''):
        raise ValueError(f'not a numeric semantic version: {version!r}')
    return tuple(map(int, version.split('.')))


def full_install_reason(old_id, old_version, new_id, new_version):
    """Why a build after (old_id, old_version) cannot be an overlay patch, or None."""
    if old_id != new_id:
        if (old_id, new_id) not in IDENTITY_TRANSITIONS:
            raise ValueError('previous ZIP belongs to a different mod')
        return f'mod id changed from {old_id} to {new_id}'
    if semver(new_version)[0] > semver(old_version)[0]:
        return f'major version {semver(old_version)[0]} -> {semver(new_version)[0]}'
    return None


def build(root, output, tag=None, previous=None, full_install=False):
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
    reason = 'requested (--full-install)' if full_install else None
    if previous and not full_install:
        with zipfile.ZipFile(previous) as old:
            old_manifest = json.loads(old.read('manifest.json'))
            old_version = old_manifest['version']
            if not re.fullmatch(r'\d+\.\d+\.\d+', old_version):
                raise ValueError('invalid previous version')
            if semver(old_version) >= semver(version):
                raise ValueError('previous ZIP must be older than this build')
            reason = full_install_reason(old_manifest['id'], old_version, manifest['id'], version)
            if not reason:
                # Patch ZIPs overlay files; deletions need a full installation.
                removed = set(old.namelist()) - set(files)
                removed = {p for p in removed if not p.endswith('/') and not p.endswith('/.gitkeep')}
                if removed:
                    raise ValueError('overlay patch cannot delete files: ' + ', '.join(sorted(removed))
                                     + ' (release them as a full install: bump the major version'
                                     + ' or pass --full-install)')
                patch = {name: body for name, body in files.items()
                         if name not in old.namelist() or body != old.read(name)}
                archives.append((f"{manifest['id']}_patch_{old_version}_to_{version}.zip", patch))
    if reason:
        print(f'Full-install release ({reason}): full ZIP only, no overlay patch.')
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
            if name == f"{manifest['id']}-{version}.zip":
                assert 'main.lua' in z.namelist()
        sums.append(hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + name)
        print(f'{path}: {len(contents)} files')
    (output / 'SHA256SUMS').write_text('\n'.join(sums) + '\n')
    return [name for name, _ in archives]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, default=Path('dist'))
    parser.add_argument('--tag')
    parser.add_argument('--previous-zip', type=Path)
    parser.add_argument('--full-install', action='store_true',
                        help='ship only the full ZIP (no overlay patch); needed when files are removed')
    args = parser.parse_args()
    build(args.root.resolve(), args.output, args.tag, args.previous_zip, args.full_install)

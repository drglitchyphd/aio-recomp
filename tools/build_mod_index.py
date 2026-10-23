#!/usr/bin/env python3
"""Refresh the custom Gen1Recomp index from published GitHub release metadata."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re


def select_release(releases, mod_id):
    choices = []
    for release in releases:
        if release.get('draft'):
            continue
        match = re.fullmatch(r'v?(\d+\.\d+\.\d+)', release.get('tag_name', ''))
        if not match:
            continue
        version = match[1]
        # Only complete, predictably named builds enter the index, never patches.
        name = f'{mod_id}-{version}.zip'
        asset = next((a for a in release.get('assets', []) if a.get('name') == name), None)
        if asset and asset.get('browser_download_url'):
            choices.append((not release.get('prerelease', False), tuple(map(int, version.split('.'))),
                            version, release, asset))
    if not choices:
        return None
    _, _, version, release, asset = max(choices, key=lambda r: r[:2])
    return {'version': version, 'tag': release['tag_name'], 'name': release.get('name') or version,
            'prerelease': release.get('prerelease', False), 'published_at': release.get('published_at'),
            'zip': {'name': asset['name'], 'url': asset['browser_download_url'], 'size': asset['size']}}


def build(root, releases):
    manifest = json.loads((root / 'manifest.json').read_text())
    output = root / 'site/data/index.json'
    old = json.loads(output.read_text()) if output.exists() else None
    latest = select_release(releases, manifest['id'])
    if latest is None:
        if old and old['mods'][0]['id'] != manifest['id']:
            return  # Keep the old identity installable until the renamed build ships.
        # Preserve the verified Initial/0.9.48 bootstrap until a vX.Y.Z release exists.
        if not old:
            raise ValueError('no published canonical release and no bootstrap index')
        latest = old['mods'][0]['latest']
    if old:
        current = old['mods'][0]['latest']
        if (not current.get('prerelease') and latest.get('prerelease')) or (
            current.get('prerelease', False) == latest.get('prerelease', False)
            and tuple(map(int, current['version'].split('.'))) > tuple(map(int, latest['version'].split('.')))
        ):
            latest = current
    repo = manifest['github']
    entry = {key: manifest[key] for key in ('id', 'api', 'games', 'game_version', 'profile',
             'affects_link', 'permissions', 'dependencies', 'conflicts')}
    entry.update(folder='drglitchyphd@' + manifest['id'], title=manifest['name'], author='drglitchyphd',
                 version=latest['version'], github=repo, repo='https://github.com/' + repo,
                 summary='Crystal all-in-one: HD Pokemon, modern UI, voxel overworld, Kenney scenes, touch controls, followers and optional Nuzlocke rules.',
                 categories=['UI', 'ART', 'QOL', 'GAMEPLAY'], tags=['crystal', 'gen2', 'voxel', 'hd', 'touch'],
                 automatic_version_check=True, downloadURL=latest['zip']['url'],
                 description_url=f'https://raw.githubusercontent.com/{repo}/main/README_GEN2_AIO.md',
                 latest=latest, update_check='ok')
    doc = {'schema_version': 1, 'generated_at': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
           'count': 1, 'categories': entry['categories'], 'mods': [entry]}
    # Avoid a meaningless nightly commit just for the generation timestamp.
    if old and {k: v for k, v in old.items() if k != 'generated_at'} == {k: v for k, v in doc.items() if k != 'generated_at'}:
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(doc, indent=2) + '\n')
    print(f'Index: {entry["id"]} {entry["version"]} -> {entry["downloadURL"]}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--releases', type=Path, required=True, help='GitHub releases API JSON array')
    args = parser.parse_args()
    build(args.root.resolve(), json.loads(args.releases.read_text()))

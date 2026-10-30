"""Release/index rules: run python3 -m unittest discover -s tests -p 'test_*.py'."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import re
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('mod_index', ROOT / 'tools/build_mod_index.py')
index = importlib.util.module_from_spec(spec)
spec.loader.exec_module(index)
spec = importlib.util.spec_from_file_location('build_release', ROOT / 'tools/build_release.py')
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)

MOD_ID = 'crystal-aio'


def release(version, prerelease=False, draft=False, full=True, mod_id=MOD_ID):
    name = f'{mod_id}-{version}.zip'
    assets = [{'name': f'{mod_id}_patch_old_to_{version}.zip', 'browser_download_url': 'https://example.com/patch.zip', 'size': 10}]
    if full:
        assets.append({'name': name, 'browser_download_url': 'https://example.com/' + name, 'size': 100})
    return {'tag_name': 'v' + version, 'prerelease': prerelease, 'draft': draft, 'assets': assets}


def quiet(fn, *args, **kwargs):
    with contextlib.redirect_stdout(io.StringIO()) as out:
        result = fn(*args, **kwargs)
    return result, out.getvalue()


class RepositoryTests(unittest.TestCase):
    def test_manifest_is_crystal_aio_1_0_0(self):
        manifest = json.loads((ROOT / 'manifest.json').read_text())
        self.assertEqual(manifest['id'], MOD_ID)
        self.assertEqual(manifest['name'], 'Crystal-AiO')
        self.assertEqual(manifest['version'], '1.0.0')
        self.assertEqual(manifest['games'], ['gen2'])
        # the old identity installs beside the new one: never both at once
        self.assertIn('gen2-aio', manifest['conflicts'])

    def test_packaged_root_files_exist(self):
        for rel in packager.ROOT_FILES:
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_release_notes_section_for_manifest_version(self):
        # auto-release.yml publishes this section as the release notes
        version = json.loads((ROOT / 'manifest.json').read_text())['version']
        text = (ROOT / 'README_CRYSTAL_AIO.md').read_text(encoding='utf-8')
        self.assertTrue(re.search(r'(?m)^## ' + re.escape(version) + r' changes$', text),
                        f'README_CRYSTAL_AIO.md has no "## {version} changes" section')
        workflow = (ROOT / '.github/workflows/auto-release.yml').read_text()
        self.assertIn('README_CRYSTAL_AIO.md', workflow)

    def test_release_workflow_builds_full_install_without_previous_build(self):
        workflow = (ROOT / '.github/workflows/release.yml').read_text()
        self.assertIn('--full-install', workflow)
        self.assertIn('--previous-zip', workflow)


class IndexTests(unittest.TestCase):
    def test_identity_changes_only_after_new_zip_is_available(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'manifest.json').write_bytes((ROOT / 'manifest.json').read_bytes())
            path = root / 'site/data/index.json'
            path.parent.mkdir(parents=True)
            old = {'mods': [{'id': 'gen2-aio', 'latest': {'version': '0.9.91'}}]}
            path.write_text(json.dumps(old))
            # only gen2-aio releases so far: keep the old identity installable
            index.build(root, [release('0.9.91', mod_id='gen2-aio')])
            self.assertEqual(json.loads(path.read_text()), old)
            _, out = quiet(index.build, root, [release('0.9.91', mod_id='gen2-aio'), release('1.0.0')])
            entry = json.loads(path.read_text())['mods'][0]
            self.assertEqual(entry['id'], MOD_ID)
            self.assertEqual(entry['title'], 'Crystal-AiO')
            self.assertEqual(entry['version'], '1.0.0')
            self.assertEqual(entry['folder'], 'drglitchyphd@crystal-aio')
            self.assertTrue(entry['description_url'].endswith('/README_CRYSTAL_AIO.md'))
            self.assertIn('gen2-aio', entry['conflicts'])

    def test_full_zip_selected_even_when_patch_first(self):
        self.assertEqual(index.select_release([release('1.0.0')], MOD_ID)['zip']['name'], 'crystal-aio-1.0.0.zip')

    def test_old_identity_zip_not_selected_for_new_identity(self):
        self.assertIsNone(index.select_release([release('0.9.91', mod_id='gen2-aio')], MOD_ID))

    def test_draft_patch_only_and_nonsemantic_releases_ignored(self):
        rows = [release('1.0.2', draft=True), release('1.0.1', full=False), release('Initial')]
        self.assertIsNone(index.select_release(rows, MOD_ID))

    def test_latest_stable_preferred_over_newer_prerelease(self):
        rows = [release('1.0.2', prerelease=True), release('1.0.0'), release('1.0.1')]
        self.assertEqual(index.select_release(rows, MOD_ID)['version'], '1.0.1')

    def test_prerelease_available_when_no_stable_exists(self):
        self.assertEqual(index.select_release([release('1.0.0', prerelease=True)], MOD_ID)['version'], '1.0.0')

    def test_feed_tracks_release_and_remains_unchanged_on_repeat(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'manifest.json').write_bytes((ROOT / 'manifest.json').read_bytes())
            quiet(index.build, root, [release('1.0.0')])
            path = root / 'site/data/index.json'
            first = path.read_bytes()
            doc = json.loads(first)
            self.assertEqual(doc['mods'][0]['id'], MOD_ID)
            self.assertEqual(doc['mods'][0]['github'], 'drglitchyphd/aio-recomp')
            self.assertEqual(doc['mods'][0]['version'], '1.0.0')
            index.build(root, [release('1.0.0')])
            self.assertEqual(path.read_bytes(), first)
            index.build(root, [])
            self.assertEqual(path.read_bytes(), first)


class PackageTests(unittest.TestCase):
    def make_repo(self, folder, version='1.0.0', mod_id=MOD_ID):
        root = Path(folder) / 'repo'
        root.mkdir(exist_ok=True)
        for rel in packager.ROOT_FILES:
            p = root / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text('fixture')
        for name in packager.RUNTIME_DIRS:
            (root / name).mkdir(exist_ok=True)
            (root / name / 'main.lua').write_text('return {}')
        self.set_manifest(root, version, mod_id)
        return root

    def set_manifest(self, root, version, mod_id=MOD_ID):
        manifest = json.loads((ROOT / 'manifest.json').read_text())
        manifest['version'], manifest['id'] = version, mod_id
        (root / 'manifest.json').write_text(json.dumps(manifest))

    def test_runtime_allowlist_excludes_workspace_and_development_files(self):
        with tempfile.TemporaryDirectory() as folder:
            root = self.make_repo(folder, '1.0.0')
            for rel in ('.aws/credentials', '.git/config', 'tests/test.lua', 'site/data/index.json', 'tools/build_release.py'):
                p = root / rel
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text('must not ship')
            output = Path(folder) / 'out'
            quiet(packager.build, root, output, 'v1.0.0')
            with zipfile.ZipFile(output / 'crystal-aio-1.0.0.zip') as z:
                names = z.namelist()
                self.assertIn('manifest.json', names)
                self.assertIn('touch/main.lua', names)
                self.assertIn('tools/import_hd_pokemon.py', names)
                self.assertIn('README_CRYSTAL_AIO.md', names)
                self.assertIn('FEATURES.md', names)
                self.assertNotIn('.aws/credentials', names)
                self.assertNotIn('.git/config', names)
                self.assertNotIn('tests/test.lua', names)
                self.assertNotIn('site/data/index.json', names)
                self.assertNotIn('tools/build_release.py', names)
            with self.assertRaises(ValueError):
                packager.build(root, output, 'v1.0.1')

    def test_minor_release_ships_overlay_patch(self):
        with tempfile.TemporaryDirectory() as folder:
            root = self.make_repo(folder, '1.0.0')
            output = Path(folder) / 'out'
            quiet(packager.build, root, output, 'v1.0.0')
            previous = Path(folder) / 'crystal-aio-1.0.0.zip'
            (output / 'crystal-aio-1.0.0.zip').rename(previous)
            self.set_manifest(root, '1.0.1')
            names, _ = quiet(packager.build, root, output, 'v1.0.1', previous)
            self.assertEqual(names, ['crystal-aio-1.0.1.zip', 'crystal-aio_patch_1.0.0_to_1.0.1.zip'])
            with zipfile.ZipFile(output / 'crystal-aio_patch_1.0.0_to_1.0.1.zip') as z:
                self.assertEqual(z.namelist(), ['manifest.json'])

    def test_overlay_patch_refuses_deletions_and_full_install_allows_them(self):
        with tempfile.TemporaryDirectory() as folder:
            root = self.make_repo(folder, '1.0.0')
            (root / 'lib' / 'gone.lua').write_text('return 1')
            output = Path(folder) / 'out'
            quiet(packager.build, root, output, 'v1.0.0')
            previous = Path(folder) / 'crystal-aio-1.0.0.zip'
            (output / 'crystal-aio-1.0.0.zip').rename(previous)
            (root / 'lib' / 'gone.lua').unlink()
            self.set_manifest(root, '1.0.1')
            with self.assertRaisesRegex(ValueError, 'cannot delete files: lib/gone.lua'):
                quiet(packager.build, root, output, 'v1.0.1', previous)
            names, out = quiet(packager.build, root, output, 'v1.0.1', previous, True)
            self.assertEqual(names, ['crystal-aio-1.0.1.zip'])
            self.assertIn('Full-install release', out)
            with zipfile.ZipFile(output / 'crystal-aio-1.0.1.zip') as z:
                self.assertNotIn('lib/gone.lua', z.namelist())
            # a new major version is a full install on its own
            self.set_manifest(root, '2.0.0')
            names, out = quiet(packager.build, root, output, 'v2.0.0', previous)
            self.assertEqual(names, ['crystal-aio-2.0.0.zip'])
            self.assertIn('major version 1 -> 2', out)

    def test_gen2_aio_to_crystal_aio_is_a_full_install(self):
        with tempfile.TemporaryDirectory() as folder:
            root = self.make_repo(folder, '0.9.91', 'gen2-aio')
            (root / 'lib' / 'gen3_frlg.lua').write_text('return 1')
            output = Path(folder) / 'out'
            quiet(packager.build, root, output, 'v0.9.91')
            previous = Path(folder) / 'gen2-aio-0.9.91.zip'
            (output / 'gen2-aio-0.9.91.zip').rename(previous)
            (root / 'lib' / 'gen3_frlg.lua').unlink()
            self.set_manifest(root, '1.0.0')
            names, out = quiet(packager.build, root, output, 'v1.0.0', previous)
            self.assertEqual(names, ['crystal-aio-1.0.0.zip'])
            self.assertIn('mod id changed from gen2-aio to crystal-aio', out)
            self.assertNotIn('gen2-aio_patch_0.9.91_to_1.0.0.zip', [p.name for p in output.iterdir()])
            # a ZIP of some other mod is never a base
            stranger = Path(folder) / 'stranger.zip'
            with zipfile.ZipFile(previous) as src, zipfile.ZipFile(stranger, 'w') as dst:
                for name in src.namelist():
                    body = src.read(name)
                    if name == 'manifest.json':
                        m = json.loads(body); m['id'] = 'other_mod'; body = json.dumps(m)
                    dst.writestr(name, body)
            with self.assertRaisesRegex(ValueError, 'different mod'):
                quiet(packager.build, root, output, 'v1.0.0', stranger)

    def test_full_install_reason(self):
        self.assertIsNone(packager.full_install_reason(MOD_ID, '1.0.0', MOD_ID, '1.2.0'))
        self.assertTrue(packager.full_install_reason(MOD_ID, '1.9.9', MOD_ID, '2.0.0'))
        self.assertTrue(packager.full_install_reason('gen2-aio', '0.9.91', MOD_ID, '1.0.0'))
        self.assertTrue(packager.full_install_reason('KIM_ARENA', '0.9.49', 'gen2-aio', '0.9.50'))
        with self.assertRaises(ValueError):
            packager.full_install_reason('KIM_ARENA', '0.9.49', MOD_ID, '1.0.0')


if __name__ == '__main__':
    unittest.main()

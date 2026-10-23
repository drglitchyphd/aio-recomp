"""Release/index rules: run python3 -m unittest discover -s tests -p 'test_*.py'."""
import importlib.util
import json
from pathlib import Path
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


def release(version, prerelease=False, draft=False, full=True):
    name = f'gen2-aio-{version}.zip'
    assets = [{'name': f'Gen2_AiO_patch_old_to_{version}.zip', 'browser_download_url': 'https://example.com/patch.zip', 'size': 10}]
    if full:
        assets.append({'name': name, 'browser_download_url': 'https://example.com/' + name, 'size': 100})
    return {'tag_name': 'v' + version, 'prerelease': prerelease, 'draft': draft, 'assets': assets}


class IndexTests(unittest.TestCase):
    def test_identity_changes_only_after_new_zip_is_available(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'manifest.json').write_bytes((ROOT / 'manifest.json').read_bytes())
            path = root / 'site/data/index.json'
            path.parent.mkdir(parents=True)
            old = {'mods': [{'id': 'KIM_ARENA', 'latest': {'version': '0.9.49'}}]}
            path.write_text(json.dumps(old))
            index.build(root, [])
            self.assertEqual(json.loads(path.read_text()), old)
            index.build(root, [release('0.9.50')])
            self.assertEqual(json.loads(path.read_text())['mods'][0]['id'], 'gen2-aio')

    def test_full_zip_selected_even_when_patch_first(self):
        self.assertEqual(index.select_release([release('0.9.49')], 'gen2-aio')['zip']['name'], 'gen2-aio-0.9.49.zip')

    def test_draft_patch_only_and_nonsemantic_releases_ignored(self):
        rows = [release('0.9.51', draft=True), release('0.9.50', full=False), release('Initial')]
        self.assertIsNone(index.select_release(rows, 'gen2-aio'))

    def test_latest_stable_preferred_over_newer_prerelease(self):
        rows = [release('0.9.51', prerelease=True), release('0.9.49'), release('0.9.50')]
        self.assertEqual(index.select_release(rows, 'gen2-aio')['version'], '0.9.50')

    def test_prerelease_available_when_no_stable_exists(self):
        self.assertEqual(index.select_release([release('0.9.49', prerelease=True)], 'gen2-aio')['version'], '0.9.49')

    def test_feed_tracks_release_and_remains_unchanged_on_repeat(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'manifest.json').write_bytes((ROOT / 'manifest.json').read_bytes())
            index.build(root, [release('0.9.49')])
            path = root / 'site/data/index.json'
            first = path.read_bytes()
            doc = json.loads(first)
            self.assertEqual(doc['mods'][0]['id'], 'gen2-aio')
            self.assertEqual(doc['mods'][0]['github'], 'drglitchyphd/aio-recomp')
            self.assertEqual(doc['mods'][0]['version'], '0.9.49')
            index.build(root, [release('0.9.49')])
            self.assertEqual(path.read_bytes(), first)
            index.build(root, [])
            self.assertEqual(path.read_bytes(), first)


class PackageTests(unittest.TestCase):
    def test_runtime_allowlist_excludes_workspace_and_development_files(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / 'repo'
            root.mkdir()
            for rel in packager.ROOT_FILES:
                p = root / rel
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text('fixture')
            manifest = json.loads((ROOT / 'manifest.json').read_text())
            manifest['version'] = '0.9.49'
            (root / 'manifest.json').write_text(json.dumps(manifest))
            for name in packager.RUNTIME_DIRS:
                (root / name).mkdir(exist_ok=True)
                (root / name / 'main.lua').write_text('return {}')
            for rel in ('.aws/credentials', '.git/config', 'tests/test.lua', 'site/data/index.json', 'tools/build_release.py'):
                p = root / rel
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text('must not ship')
            output = Path(folder) / 'out'
            packager.build(root, output, 'v0.9.49')
            with zipfile.ZipFile(output / 'gen2-aio-0.9.49.zip') as z:
                names = z.namelist()
                self.assertIn('manifest.json', names)
                self.assertIn('touch/main.lua', names)
                self.assertIn('tools/import_hd_pokemon.py', names)
                self.assertNotIn('.aws/credentials', names)
                self.assertNotIn('.git/config', names)
                self.assertNotIn('tests/test.lua', names)
                self.assertNotIn('site/data/index.json', names)
                self.assertNotIn('tools/build_release.py', names)
            with self.assertRaises(ValueError):
                packager.build(root, output, 'v0.9.50')


if __name__ == '__main__':
    unittest.main()

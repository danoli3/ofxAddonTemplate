"""Exercise the release archive contract without GitHub or network access."""
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest


class LibraryScriptsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.addon = self.root / 'ofxAddonTemplate'
        source = Path(__file__).resolve().parents[1]
        shutil.copytree(source / 'scripts', self.addon / 'scripts')
        self.lib = self.addon / 'libs/necessaryLib'
        (self.lib / 'include').mkdir(parents=True)
        (self.lib / 'include/necessaryLib.h').write_text('// public header\n')
        (self.lib / 'lib/osx').mkdir(parents=True)
        (self.lib / 'lib/osx/.gitkeep').touch()
        self.assets = self.root / 'assets'
        self.assets.mkdir()
        tools = self.root / 'tools'
        tools.mkdir()
        curl = tools / 'curl'
        curl.write_text('''#!/usr/bin/env python3
import os, pathlib, shutil, sys
if os.environ.get('FAKE_DOWNLOAD_ERROR'):
    sys.exit(22)
args = sys.argv[1:]
out = args[args.index('-o') + 1]
asset = args[-1].rsplit('/', 1)[-1]
shutil.copyfile(pathlib.Path(os.environ['TEST_ASSETS']) / asset, out)
''')
        curl.chmod(0o755)
        self.env = dict(os.environ, PATH=str(tools) + os.pathsep + os.environ['PATH'],
                        TEST_ASSETS=str(self.assets), TMPDIR=str(self.root))

    def run_script(self, script, *args, ok=True):
        result = subprocess.run(['bash', str(self.addon / 'scripts' / script), *args],
                                env=self.env, capture_output=True, text=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def package(self, version='1.0.0'):
        # Contents need not be linkable to test packaging; actual addon builds
        # exercise the compiler and linker separately.
        (self.lib / 'lib/osx/libnecessaryLib.a').write_bytes(b'archive fixture')
        self.run_script('build_libs.sh', 'macos', '-v', version)
        name = f'ofxAddonTemplate-libs-osx-{version}.tar.bz2'
        archive = self.addon / 'releases' / name
        shutil.copyfile(archive, self.assets / name)
        return archive

    def test_empty_skeleton_cannot_be_released(self):
        result = self.run_script('build_libs.sh', 'osx', ok=False)
        self.assertIn('No built binaries', result.stderr)
        self.assertFalse((self.addon / 'releases').exists())

    def test_package_download_round_trip_and_alias(self):
        archive = self.package('2.0.0')
        with tarfile.open(archive) as stream:
            self.assertIn('lib/osx/libnecessaryLib.a', stream.getnames())
            self.assertNotIn('lib/osx/.gitkeep', stream.getnames())
        shutil.rmtree(self.lib)
        self.run_script('download_libs.sh', 'macos', '-v', '2.0.0', '-u', 'author/addon')
        self.assertEqual((self.lib / 'lib/osx/libnecessaryLib.a').read_bytes(), b'archive fixture')
        self.assertTrue((self.lib / 'include/necessaryLib.h').is_file())
        self.assertEqual(list(self.root.glob('addon-libs.*')), [])

    def test_build_uses_shared_version_file(self):
        (self.addon / 'scripts/libs_version.txt').write_text('3.2.1\r\n')
        (self.lib / 'lib/osx/libnecessaryLib.a').write_bytes(b'archive fixture')
        self.run_script('build_libs.sh', 'osx')
        self.assertTrue((self.addon / 'releases/ofxAddonTemplate-libs-osx-3.2.1.tar.bz2').is_file())

    def test_missing_values_and_unknown_options(self):
        for script in ('build_libs.sh', 'download_libs.sh'):
            for args in (('-v',), ('-u',), ('--typo',), ('osx', 'ios'), ('unknown',), ('-v', '../bad')):
                with self.subTest(script=script, args=args):
                    self.run_script(script, *args, ok=False)

    def test_unconfigured_repo_fails_before_download(self):
        result = self.run_script('download_libs.sh', 'osx', ok=False)
        self.assertIn('Configure GITHUB_REPO', result.stderr)
        self.assertEqual(list(self.root.glob('addon-libs.*')), [])

    def test_download_failure_preserves_installed_files_and_cleans_temp(self):
        installed = self.lib / 'lib/osx/libnecessaryLib.a'
        installed.write_bytes(b'installed')
        self.env['FAKE_DOWNLOAD_ERROR'] = '1'
        self.run_script('download_libs.sh', 'osx', '-u', 'author/addon', ok=False)
        self.assertEqual(installed.read_bytes(), b'installed')
        self.assertEqual(list(self.root.glob('addon-libs.*')), [])

    def test_wrong_platform_archive_is_rejected(self):
        archive = self.assets / 'ofxAddonTemplate-libs-osx-1.0.0.tar.bz2'
        with tarfile.open(archive, 'w:bz2') as stream:
            stream.add(self.lib / 'include', arcname='include')
        result = self.run_script('download_libs.sh', 'osx', '-u', 'author/addon', ok=False)
        self.assertIn('Archive is missing lib/osx/', result.stderr)
        self.assertEqual(list(self.root.glob('addon-libs.*')), [])


if __name__ == '__main__':
    unittest.main()

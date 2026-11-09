"""Build real Mach-O fixtures and verify XCFramework platforms/architectures."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest


@unittest.skipUnless(sys.platform == 'darwin' and shutil.which('xcodebuild'), 'requires Xcode on macOS')
class XCFrameworkTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture_temp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.fixture_temp.cleanup)
        cls.fixtures = Path(cls.fixture_temp.name)
        source = cls.fixtures / 'fixture.c'
        source.write_text('int fixture_value(void) { return 42; }\n')
        cls.slices = {}
        specs = [
            ('macos', 'arm64', 'macosx', 'arm64-apple-macos12.0'),
            ('macos', 'x86_64', 'macosx', 'x86_64-apple-macos12.0'),
            ('ios', 'arm64', 'iphoneos', 'arm64-apple-ios15.0'),
            ('ios-simulator', 'arm64', 'iphonesimulator', 'arm64-apple-ios15.0-simulator'),
            ('ios-simulator', 'x86_64', 'iphonesimulator', 'x86_64-apple-ios15.0-simulator'),
            ('tvos', 'arm64', 'appletvos', 'arm64-apple-tvos15.0'),
            ('tvos-simulator', 'arm64', 'appletvsimulator', 'arm64-apple-tvos15.0-simulator'),
            ('xros', 'arm64', 'xros', 'arm64-apple-xros1.0'),
            ('xros-simulator', 'arm64', 'xrsimulator', 'arm64-apple-xros1.0-simulator'),
            ('watchos', 'arm64_32', 'watchos', 'arm64_32-apple-watchos8.0'),
            ('watchos-simulator', 'arm64', 'watchsimulator', 'arm64-apple-watchos8.0-simulator'),
            ('catalyst', 'arm64', 'macosx', 'arm64-apple-ios15.0-macabi'),
            ('catalyst', 'x86_64', 'macosx', 'x86_64-apple-ios15.0-macabi'),
        ]
        for group, arch, sdk, target in specs:
            sdk_result = subprocess.run(['xcrun', '--sdk', sdk, '--show-sdk-path'], capture_output=True, text=True)
            if sdk_result.returncode:
                raise unittest.SkipTest(f'Xcode SDK unavailable: {sdk}')
            stem = cls.fixtures / (group + '-' + arch)
            obj = stem.with_suffix('.o')
            archive = stem.with_suffix('.a')
            command = ['xcrun', '--sdk', sdk, 'clang', '-target', target,
                       '-isysroot', sdk_result.stdout.strip(), '-c', str(source), '-o', str(obj)]
            subprocess.run(command, check=True, capture_output=True, text=True)
            subprocess.run(['xcrun', 'libtool', '-static', '-o', str(archive), str(obj)],
                           check=True, capture_output=True, text=True)
            cls.slices[f'{group}/{arch}'] = archive

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.addon = Path(self.temp.name) / 'ofxAddonTemplate'
        source = Path(__file__).resolve().parents[1]
        shutil.copytree(source / 'scripts', self.addon / 'scripts')
        headers = self.addon / 'libs/necessaryLib/include'
        headers.mkdir(parents=True)
        (headers / 'fixture.h').write_text('int fixture_value(void);\n')

    def build(self, *options, keys=None, ok=True):
        if keys is None:
            keys = list(self.slices)
        command = [os.environ.get('TEST_BASH', 'bash'), str(self.addon / 'scripts/build_xcframework.sh'), *options]
        for key in keys:
            command.extend(['--slice', f'{key}={self.slices[key]}'])
        result = subprocess.run(command, capture_output=True, text=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def libraries(self, folder):
        product = self.addon / 'libs/necessaryLib/lib' / folder / 'necessaryLib.xcframework'
        with (product / 'Info.plist').open('rb') as stream:
            entries = plistlib.load(stream)['AvailableLibraries']
        result = {}
        for entry in entries:
            binary = product / entry['LibraryIdentifier'] / entry['LibraryPath']
            archs = subprocess.check_output(['xcrun', 'lipo', '-archs', str(binary)], text=True).split()
            self.assertEqual(set(archs), set(entry['SupportedArchitectures']))
            self.assertTrue((product / entry['LibraryIdentifier'] / entry['HeadersPath'] / 'fixture.h').is_file())
            result[(entry['SupportedPlatform'], entry.get('SupportedPlatformVariant', ''))] = set(archs)
        return result

    def test_macos_universal(self):
        self.build('--platform', 'macos', keys=['macos/arm64', 'macos/x86_64'])
        self.assertEqual(self.libraries('macos'), {('macos', ''): {'arm64', 'x86_64'}})

    def test_ios_device_and_universal_simulator(self):
        self.build('--platform', 'ios', keys=['ios/arm64', 'ios-simulator/arm64', 'ios-simulator/x86_64'])
        self.assertEqual(self.libraries('ios'), {('ios', ''): {'arm64'}, ('ios', 'simulator'): {'arm64', 'x86_64'}})

    def test_all_platforms_in_macos_folder(self):
        self.build()
        self.assertEqual(self.libraries('macos'), {
            ('macos', ''): {'arm64', 'x86_64'},
            ('ios', ''): {'arm64'}, ('ios', 'simulator'): {'arm64', 'x86_64'},
            ('tvos', ''): {'arm64'}, ('tvos', 'simulator'): {'arm64'},
            ('xros', ''): {'arm64'}, ('xros', 'simulator'): {'arm64'},
            ('watchos', ''): {'arm64_32'}, ('watchos', 'simulator'): {'arm64'},
            ('ios', 'maccatalyst'): {'arm64', 'x86_64'},
        })

    def test_duplicate_and_mislabeled_architecture(self):
        result = self.build(keys=['macos/arm64', 'macos/arm64'], ok=False)
        self.assertIn('Duplicate slice', result.stderr)
        result = self.build('--slice', f'macos/x86_64={self.slices["macos/arm64"]}', keys=[], ok=False)
        self.assertIn('must contain only x86_64', result.stderr)

    def test_mislabeled_platform_rejected(self):
        result = self.build('--slice', f'macos/arm64={self.slices["ios/arm64"]}', keys=[], ok=False)
        self.assertIn('platform metadata does not match', result.stderr)
        self.assertFalse((self.addon / 'libs/necessaryLib/lib/macos/necessaryLib.xcframework').exists())

    def test_existing_output_requires_force(self):
        self.build('--platform', 'macos', keys=['macos/arm64'])
        result = self.build('--platform', 'macos', keys=['macos/x86_64'], ok=False)
        self.assertIn('Output exists', result.stderr)
        self.assertEqual(self.libraries('macos'), {('macos', ''): {'arm64'}})
        self.build('--platform', 'macos', '--force', keys=['macos/arm64', 'macos/x86_64'])
        self.assertEqual(self.libraries('macos'), {('macos', ''): {'arm64', 'x86_64'}})

    def test_failed_replacement_preserves_existing_output(self):
        self.build('--platform', 'macos', keys=['macos/arm64'])
        self.build('--force', '--slice', f'macos/arm64={self.slices["ios/arm64"]}', keys=[], ok=False)
        self.assertEqual(self.libraries('macos'), {('macos', ''): {'arm64'}})
        self.assertEqual(list((self.addon / 'libs/necessaryLib/lib/macos').glob('.xcframework-build.*')), [])


if __name__ == '__main__':
    unittest.main()

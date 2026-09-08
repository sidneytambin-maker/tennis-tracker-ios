import io
from pathlib import Path
import plistlib
import unittest
import zipfile
from verify_app_icons import compiled_icons, source_icons


class AppIconTests(unittest.TestCase):
    def archive(self, missing=""):
        raw = io.BytesIO()
        with zipfile.ZipFile(raw, "w") as archive:
            for root in ("Payload/TennisTracker.app/", "Payload/TennisTracker.app/Watch/TennisTrackerWatchApp.app/"):
                info = {"CFBundleIcons": {"CFBundlePrimaryIcon": {"CFBundleIconName": "AppIcon"}}}
                if missing == root + "metadata": info = {}
                archive.writestr(root + "Info.plist", plistlib.dumps(info))
                for name in ("AppIcon60x60@2x.png", "Assets.car"):
                    if missing != root + name: archive.writestr(root + name, b"compiled-test-fixture")
        return zipfile.ZipFile(raw)

    def testBothSourceIconsHaveCorrectSizeFormatAndMatchingBrand(self):
        source_icons(Path(__file__).resolve().parents[1])

    def testCompiledPhoneAndWatchIconsAreRequired(self):
        with self.archive() as archive:
            self.assertEqual(len(compiled_icons(archive)["components"]), 2)

    def testMissingWatchArtworkFails(self):
        with self.archive("Payload/TennisTracker.app/Watch/TennisTrackerWatchApp.app/AppIcon60x60@2x.png") as archive:
            with self.assertRaises(ValueError): compiled_icons(archive)

    def testMissingPhoneMetadataFails(self):
        with self.archive("Payload/TennisTracker.app/metadata") as archive:
            with self.assertRaises(ValueError): compiled_icons(archive)

    def testMissingCompiledAssetCatalogueFails(self):
        with self.archive("Payload/TennisTracker.app/Assets.car") as archive:
            with self.assertRaises(ValueError): compiled_icons(archive)


if __name__ == "__main__": unittest.main()

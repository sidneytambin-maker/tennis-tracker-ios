import plistlib
import tempfile
import unittest
from pathlib import Path
from verify_testflight_release import verify, PHONE_ID, GROUP_ID


class ReleasePrivacyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / "Phone.app"
        self.watch = self.app / "Watch" / "Watch.app"
        self.widget = self.watch / "PlugIns" / "Widget.appex"
        for path, bundle in ((self.app, PHONE_ID), (self.watch, PHONE_ID + ".watchkitapp"), (self.widget, PHONE_ID + ".watchkitapp.widgets")):
            path.mkdir(parents=True, exist_ok=True)
            info = {"CFBundleIdentifier": bundle, "CFBundleExecutable": "Main", "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "30", "TennisSharedAppGroup": GROUP_ID,
                    "WKCompanionAppBundleIdentifier": PHONE_ID, "WKApplication": True, "UIFileSharingEnabled": True, "LSSupportsOpeningDocumentsInPlace": True,
                    "NSExtension": {"NSExtensionPointIdentifier": "com.apple.widgetkit-extension"}}
            (path / "Info.plist").write_bytes(plistlib.dumps(info))
            (path / "PrivacyInfo.xcprivacy").write_bytes(plistlib.dumps({"NSPrivacyTracking": False, "NSPrivacyCollectedDataTypes": []}))
            (path / "Main").write_bytes(b"compiled-test-placeholder")

    def test_clean_structure_passes(self):
        self.assertEqual(len(verify(self.app)["components"]), 3)

    def test_private_database_blocks_release(self):
        (self.watch / "tennis-tracker-data.json").write_text("{}")
        with self.assertRaises(ValueError): verify(self.app)

    def test_test_hooks_block_release(self):
        (self.app / "Main").write_bytes(b"-ui-testing-reset-store")
        with self.assertRaises(ValueError): verify(self.app)

    def test_temporary_identifier_blocks_release(self):
        path = self.watch / "Info.plist"
        info = plistlib.loads(path.read_bytes()); info["CFBundleIdentifier"] += ".dev"
        path.write_bytes(plistlib.dumps(info))
        with self.assertRaises(ValueError): verify(self.app)

    def test_wrong_watch_location_blocks_release(self):
        (self.app / "PlugIns").mkdir()
        self.watch.rename(self.app / "PlugIns" / "Watch.app")
        with self.assertRaises(ValueError): verify(self.app)

    def test_missing_complication_blocks_release(self):
        (self.widget / "Info.plist").unlink()
        with self.assertRaises(FileNotFoundError): verify(self.app)

    def test_missing_private_restore_route_blocks_release(self):
        path = self.app / "Info.plist"
        info = plistlib.loads(path.read_bytes()); info["UIFileSharingEnabled"] = False
        path.write_bytes(plistlib.dumps(info))
        with self.assertRaises(ValueError): verify(self.app)


if __name__ == "__main__": unittest.main()

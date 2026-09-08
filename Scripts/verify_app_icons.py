"""Validate source artwork and the actual compiled icons in both app bundles."""
import argparse
import json
from pathlib import Path
import plistlib
import struct
import zipfile


def source_icons(root):
    images = []
    for target, platform in (("TennisTracker", "ios"), ("TennisTrackerWatchApp", "watchos")):
        folder = root / target / "Assets.xcassets/AppIcon.appiconset"
        contents = json.loads((folder / "Contents.json").read_bytes())
        entry, = contents["images"]
        if (entry["idiom"], entry["platform"], entry["size"]) != ("universal", platform, "1024x1024"):
            raise ValueError("Incorrect single-size app icon catalogue")
        raw = (folder / entry["filename"]).read_bytes()
        if raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR":
            raise ValueError("App icon must be PNG")
        width, height, depth, colour = struct.unpack(">IIBB", raw[16:26])
        if (width, height, depth, colour) != (1024, 1024, 8, 2):
            raise ValueError("App icon must be opaque 1024-square 8-bit RGB artwork")
        images.append(raw)
    if images[0] != images[1]:
        raise ValueError("iPhone and Watch must share the same brand artwork")


def compiled_icons(archive):
    results = []
    for component, root in (("iPhone", "Payload/TennisTracker.app/"),
                            ("Watch", "Payload/TennisTracker.app/Watch/TennisTrackerWatchApp.app/")):
        info = plistlib.loads(archive.read(root + "Info.plist"))
        primary = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
        name = primary.get("CFBundleIconName", info.get("CFBundleIconName"))
        if name != "AppIcon":
            raise ValueError(component + " has no compiled primary AppIcon metadata")
        files = [n.removeprefix(root) for n in archive.namelist() if n.startswith(root)
                 and "/" not in n.removeprefix(root) and n.removeprefix(root).startswith("AppIcon") and n.endswith(".png")]
        if not files or root + "Assets.car" not in archive.namelist():
            raise ValueError(component + " is missing its compiled app icon images")
        results.append({"component": component, "primary_icon": name, "compiled_pngs": sorted(files)})
    return {"app_icons_verified": True, "components": results}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ipa", type=Path)
    args = parser.parse_args()
    source_icons(Path(__file__).resolve().parents[1])
    if args.ipa:
        with zipfile.ZipFile(args.ipa) as archive:
            print(json.dumps(compiled_icons(archive), indent=2))

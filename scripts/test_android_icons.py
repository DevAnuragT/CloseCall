#!/usr/bin/env python3
"""Small, dependency-light checks for generated Android launcher resources."""

from __future__ import annotations

import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "android/assets/Icon.png"
RES = ROOT / "android/app/src/main/res"
EXPECTED = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


class AndroidLauncherIconTest(unittest.TestCase):
    def test_source_is_large_and_has_visible_alpha(self) -> None:
        with Image.open(SOURCE) as image:
            self.assertGreaterEqual(image.width, 512)
            self.assertGreaterEqual(image.height, 512)
            self.assertIsNotNone(image.getchannel("A").point(lambda p: p if p >= 16 else 0).getbbox())

    def test_legacy_density_outputs(self) -> None:
        for directory, size in EXPECTED.items():
            for name in ("ic_launcher.png", "ic_launcher_round.png"):
                path = RES / directory / name
                with self.subTest(path=path), Image.open(path) as image:
                    self.assertEqual(image.size, (size, size))
                    self.assertEqual(image.mode, "RGBA")

    def test_adaptive_resources_and_safe_foreground(self) -> None:
        foreground = RES / "drawable-nodpi/ic_launcher_foreground.png"
        with Image.open(foreground) as image:
            self.assertEqual(image.size, (108, 108))
            alpha = image.getchannel("A")
            bbox = alpha.point(lambda p: p if p >= 8 else 0).getbbox()
            self.assertIsNotNone(bbox)
            left, top, right, bottom = bbox
            self.assertGreaterEqual(left, 18)
            self.assertGreaterEqual(top, 18)
            self.assertLessEqual(right, 90)
            self.assertLessEqual(bottom, 90)

        for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
            xml = (RES / "mipmap-anydpi-v26" / name).read_text()
            self.assertIn("@drawable/ic_launcher_background", xml)
            self.assertIn("@drawable/ic_launcher_foreground", xml)

    def test_manifest_uses_closecall_adaptive_icons(self) -> None:
        manifest = (ROOT / "android/app/src/main/AndroidManifest.xml").read_text()
        self.assertRegex(manifest, r'android:label="CloseCall"')
        self.assertRegex(manifest, r'android:icon="@mipmap/ic_launcher"')
        self.assertRegex(manifest, r'android:roundIcon="@mipmap/ic_launcher_round"')


if __name__ == "__main__":
    unittest.main()

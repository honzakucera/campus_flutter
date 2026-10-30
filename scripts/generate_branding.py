#!/usr/bin/env python3
"""Export app branding from the transparent master with ImageMagick 7."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets/branding/tum-logo-master.png"
BACKGROUND = "#fffdf5"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def magick(*args):
    return subprocess.check_output(
        ["magick", *map(str, args)], text=True
    ).strip()


def write_image(*args, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    magick(*args, "-strip", "-depth", "8", destination)


def main():
    if shutil.which("magick") is None:
        raise SystemExit("Install ImageMagick 7 (magick) before running this script.")

    with tempfile.TemporaryDirectory(prefix="campus-branding-") as directory:
        cropped = Path(directory) / "logo.png"
        # Ignore nearly invisible background alpha when calculating the crop.
        # Keep the master's colors and alpha unchanged within that rectangle.
        bounds = magick(
            MASTER, "-alpha", "extract", "-threshold", "5%", "-format", "%@", "info:"
        )
        magick(MASTER, "-crop", bounds, "+repage", cropped)

        def logo(width, height, destination):
            write_image(
                cropped, "-filter", "Lanczos", "-resize", f"{width}x{height}",
                "-background", "none", "-gravity", "center",
                "-extent", f"{width}x{height}", destination=destination,
            )

        def icon(size, destination, round_icon=False):
            # Leave space for the OS's rounded-square or circular mask.
            artwork = round(size * 0.82)
            args = [
                cropped, "-filter", "Lanczos", "-resize", f"{artwork}x{artwork}",
                "-background", BACKGROUND, "-gravity", "center",
                "-extent", f"{size}x{size}", "-alpha", "remove", "-alpha", "off",
            ]
            if round_icon:
                center = (size - 1) / 2
                args += [
                    "(", "-size", f"{size}x{size}", "xc:none",
                    "-fill", "white", "-draw",
                    f"circle {center},{center} {center},0", ")",
                    "-alpha", "off", "-compose", "CopyOpacity", "-composite",
                ]
            write_image(*args, destination=destination)

        # Flutter automatically chooses the appropriate density variant.
        for scale in (1, 2, 3, 4):
            folder = ROOT / "assets/images/logos"
            if scale != 1:
                folder /= f"{scale}.0x"
            logo(240 * scale, 128 * scale, folder / "tum-logo.png")

        # Existing iPhone/iPad/macOS/marketing slots, including the widget target.
        for target in ("Runner", "CalendarWidget"):
            catalog = ROOT / f"ios/{target}/Assets.xcassets/AppIcon.appiconset"
            images = json.loads((catalog / "Contents.json").read_text())["images"]
            for entry in images:
                size = round(float(entry["size"].split("x")[0]) * float(entry["scale"][:-1]))
                icon(size, catalog / entry["filename"])

        launch = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
        for scale in (1, 2, 3):
            suffix = "" if scale == 1 else f"@{scale}x"
            logo(240 * scale, 128 * scale, launch / f"logo{suffix}.png")

        for density, scale in DENSITIES.items():
            res = ROOT / "android/app/src/main/res"
            folder = res / f"mipmap-{density}"
            size = round(48 * scale)
            icon(size, folder / "ic_launcher.png")
            icon(size, folder / "ic_launcher_round.png", round_icon=True)

            # 108dp adaptive canvas. The full artwork fits inside the central
            # 66dp safe circle, including the leaves, for all launcher masks.
            canvas = round(108 * scale)
            artwork = round(58 * scale)
            foreground = folder / "ic_launcher_foreground.png"
            write_image(
                cropped, "-filter", "Lanczos", "-resize", f"{artwork}x{artwork}",
                "-background", "none", "-gravity", "center",
                "-extent", f"{canvas}x{canvas}", destination=foreground,
            )
            write_image(
                "-size", f"{canvas}x{canvas}", f"xc:{BACKGROUND}",
                "-alpha", "off", destination=folder / "ic_launcher_background.png",
            )
            write_image(
                foreground, "-channel", "RGB", "-evaluate", "set", "0", "+channel",
                destination=folder / "ic_launcher_monochrome.png",
            )
            logo(
                round(240 * scale), round(128 * scale),
                res / f"drawable-{density}/launch_image.png",
            )

    print("Generated Flutter, Android, iOS, widget, macOS, and launch-screen PNGs.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Render the launcher icon from the same art the tray draws.

The tray builds its icon at runtime from pixel-art tables in tray.py. A
separate hand-drawn file for the desktop entry would be a second source of
truth that nobody remembers to update, so this imports the real one.

Importing tray.py means importing pystray, which picks a backend by looking at
the display. There is no display on a build runner, so the dummy backend is
selected explicitly first.

Usage: make-icons.py <output-dir>
"""
import os
import sys

os.environ.setdefault("PYSTRAY_BACKEND", "dummy")

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "companion"))

# Pixel art scales cleanly only by whole numbers with nearest-neighbour, which
# is also the look it wants. 64 is the source, so these are 1x, 2x and 4x.
SIZES = (64, 128, 256)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    try:
        from PIL import Image
        import tray
    except Exception as exc:  # noqa: BLE001 - a build step should say why
        print("cannot render icons: %s" % exc, file=sys.stderr)
        return 1

    # "grey" is the idle colour. The launcher icon is what you see before the
    # app has talked to anything, so idle is the honest state to draw.
    base = tray.make_icon("grey")
    made = []
    for px in SIZES:
        img = base if px == 64 else base.resize((px, px), Image.NEAREST)
        path = os.path.join(out, "yoyu-companion-%d.png" % px)
        img.save(path)
        made.append(path)
    print("\n".join(made))
    return 0


if __name__ == "__main__":
    sys.exit(main())

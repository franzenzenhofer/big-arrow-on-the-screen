#!/usr/bin/env python3
"""Render the README hero offscreen: eight arrows, each drawn with `bigarrow point --png`, laid
out on one light canvas. Nothing is drawn on the screen.

Usage: scripts/hero.py <bigarrow-binary> <out.png>
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

# The canvas in points, rendered on the first display wide enough for it (its own scale).
CANVAS = (1840, 623)
MARGIN = 40
BACKGROUND = (240, 240, 240, 255)

# (sign, target in canvas points, extra arguments)
ARROWS: list[tuple[str, tuple[int, int], list[str]]] = [
    ("Franz, click HERE", (390, 250), ["--from", "top-left", "--color", "red"]),
    ("Sign here", (690, 24), ["--from", "bottom", "--color", "blue", "--corners", "sharp", "--shape", "straight"]),
    ("Over here!", (960, 143), ["--from", "right", "--color", "purple", "--shape", "zigzag"]),
    ("You are here", (1735, 55), ["--from", "bottom-left", "--color", "teal", "--style", "ring"]),
    ("Read this first", (560, 600), ["--from", "top-right", "--color", "yellow"]),
    ("No, the other one", (990, 330), ["--from", "bottom-right", "--color", "black", "--shape", "zigzag"]),
    ("Click Allow", (1805, 447), ["--from", "left", "--color", "green"]),
]
BOX = ("Type your name", (150, 310, 160, 48), ["--from", "bottom", "--color", "orange"])


def wide_display(binary: str) -> dict:
    doctor = json.loads(subprocess.run([binary, "doctor", "--json"], check=True, capture_output=True, text=True).stdout)
    for display in doctor["displays"]:
        if display["width"] >= CANVAS[0] + 2 * MARGIN and display["height"] >= CANVAS[1] + 2 * MARGIN:
            return display
    sys.exit(f"hero.py: needs a display of at least {CANVAS[0] + 2 * MARGIN}x{CANVAS[1] + 2 * MARGIN} points")


def render(binary: str, text: str, target: list[str], extra: list[str], out: Path) -> tuple[Image.Image, tuple[float, float, float]]:
    command = [binary, "point", *target, "--text", text, "--size", "S", "--no-raise", *extra, "--png", str(out), "--json"]
    result = json.loads(subprocess.run(command, check=True, capture_output=True, text=True).stdout)
    x, y, scale = result["image"]
    return Image.open(out).convert("RGBA"), (x, y, scale)


def main() -> None:
    binary, out = sys.argv[1], sys.argv[2]
    display = wide_display(binary)
    origin = (display["x"] + MARGIN, display["y"] + MARGIN)
    jobs = [(text, ["--at", f"{origin[0] + tx},{origin[1] + ty}"], extra) for text, (tx, ty), extra in ARROWS]
    text, (bx, by, bw, bh), extra = BOX
    jobs.append((text, ["--rect", f"{origin[0] + bx},{origin[1] + by},{bw},{bh}"], extra))
    canvas: Image.Image | None = None
    with tempfile.TemporaryDirectory() as work:
        for index, (text, target, extra) in enumerate(jobs):
            image, (x, y, scale) = render(binary, text, target, extra, Path(work) / f"{index}.png")
            if canvas is None:
                canvas = Image.new("RGBA", (int(CANVAS[0] * scale), int(CANVAS[1] * scale)), BACKGROUND)
            canvas.paste(image, (int((x - origin[0]) * scale), int((y - origin[1]) * scale)), image)
    assert canvas is not None
    canvas.convert("RGB").save(out)
    print(out)


if __name__ == "__main__":
    main()

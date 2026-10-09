#!/usr/bin/env python3
"""Render every arrow look offscreen with `bigarrow point --png` and lay them out on contact
sheets, plus zoomed crops of each sign-to-shaft junction. Nothing is drawn on the screen.

Usage: scripts/gallery.py <bigarrow-binary> <out-dir>
Writes <out-dir>/gallery.png (full arrows), <out-dir>/junctions.png (zoomed joints) and
<out-dir>/looks.png (every border style and colour option) and <out-dir>/spirals.png.
"""
from __future__ import annotations

import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

SHEET_TOOL = Path(__file__).with_name("contact-sheet.swift")
TARGET = (760, 460)
ZOOM_HALF = (70, 50)  # points around the junction, width and height halves


@dataclass(frozen=True)
class Case:
    name: str
    args: list[str]


def cases() -> list[Case]:
    directions = ["top-left", "top", "top-right", "right", "bottom-right", "bottom", "bottom-left", "left"]
    result = [Case(f"{d} round", ["--from", d]) for d in directions]
    result += [Case(f"{d} sharp", ["--from", d, "--corners", "sharp", "--color", "blue"]) for d in directions]
    result += [Case(f"size {s}", ["--size", s, "--color", "green"]) for s in ["S", "M", "L"]]
    result += [Case(f"{shape} {d}", ["--shape", shape, "--from", d, "--color", "purple"])
               for shape in ["straight", "zigzag"] for d in ["top-left", "right", "bottom"]]
    result += [Case(f"{c}", ["--color", c, "--from", "bottom-left"]) for c in ["yellow", "white", "black", "purple"]]
    result += [
        Case("ring", ["--style", "ring", "--color", "teal"]),
        Case("box", ["--style", "box", "--color", "orange"]),
        Case("two lines", ["--text", "Franz, please click the blue Continue button down here", "--from", "top-right"]),
        Case("integration test", ["--text", "Integration test", "--at", "680,442"]),
    ]
    return result


def looks() -> list[Case]:
    """Every border style and colour option, for the README's Looks section."""
    return [
        Case("default: white border + shadow", []),
        Case("--border white-black", ["--border", "white-black"]),
        Case("--border black", ["--border", "black"]),
        Case("--close-button", ["--close-button"]),
        Case("--border-color yellow --text-color yellow", ["--color", "blue", "--border-color", "yellow", "--text-color", "yellow"]),
        Case("--close-color black --close-x-color white", ["--close-button", "--close-color", "black", "--close-x-color", "white"]),
        Case("--color black --border white-black", ["--color", "black", "--border", "white-black"]),
        Case("--color white --border black", ["--color", "white", "--border", "black"]),
        Case("--edge-color purple --border white-black", ["--color", "green", "--border", "white-black", "--edge-color", "purple"]),
        Case("--color yellow --close-button", ["--color", "yellow", "--close-button"]),
        Case("--style box --border-color black", ["--style", "box", "--color", "orange", "--border-color", "black"]),
        Case("--style ring --border black", ["--style", "ring", "--color", "teal", "--border", "black"]),
    ]


def spirals() -> list[Case]:
    """`--shape spiral` in a few looks, for the README."""
    return [
        Case("--shape spiral", ["--shape", "spiral"]),
        Case("--shape spiral --color purple --size S", ["--shape", "spiral", "--color", "purple", "--size", "S"]),
        Case("--shape spiral --color green --border white-black", ["--shape", "spiral", "--color", "green", "--border", "white-black"]),
    ]


def render(binary: str, case: Case, out: Path) -> dict:
    args = [binary, "point", "--at", f"{TARGET[0]},{TARGET[1]}", "--text", "Franz, click HERE", "--no-animation"]
    args += case.args + ["--png", str(out), "--json"]
    result = subprocess.run(args, capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def junction(sign: list[float], target: tuple[float, float]) -> tuple[float, float]:
    """Where the ray from the sign centre to the target leaves the sign (the join is near it)."""
    cx, cy = sign[0] + sign[2] / 2, sign[1] + sign[3] / 2
    dx, dy = target[0] - cx, target[1] - cy
    scales = [abs(sign[2] / 2 / dx) if dx else float("inf"), abs(sign[3] / 2 / dy) if dy else float("inf"), 1.0]
    t = min(scales)
    return cx + dx * t, cy + dy * t


def crop(source: Path, result: dict, out: Path) -> None:
    origin_x, origin_y, scale = result["image"]
    target = (result["target"]["x"], result["target"]["y"])
    jx, jy = junction(result["sign"], target)
    width, height = ZOOM_HALF[0] * 2 * scale, ZOOM_HALF[1] * 2 * scale
    left = max((jx - ZOOM_HALF[0] - origin_x) * scale, 0)
    top = max((jy - ZOOM_HALF[1] - origin_y) * scale, 0)
    subprocess.run(
        ["sips", "-c", str(int(height)), str(int(width)), "--cropOffset", str(int(top)), str(int(left)),
         str(source), "--out", str(out)],
        capture_output=True, check=True,
    )


def sheet_tool(out_dir: Path) -> Path:
    """`swift script.swift` cannot link AppKit in JIT mode, so the tool is compiled once."""
    binary = out_dir / "contact-sheet"
    subprocess.run(["swiftc", "-O", str(SHEET_TOOL), "-o", str(binary)], check=True)
    return binary


def sheet(tool: Path, out: Path, columns: int, width: int, items: list[tuple[Path, str]]) -> None:
    entries = [f"{path}:{caption}" for path, caption in items]
    subprocess.run([str(tool), str(out), str(columns), str(width), *entries], check=True)


def main() -> None:
    binary, out_dir = sys.argv[1], Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    full: list[tuple[Path, str]] = []
    zoomed: list[tuple[Path, str]] = []
    for index, case in enumerate(cases()):
        png = out_dir / f"{index:02d}.png"
        zoom = out_dir / f"{index:02d}-junction.png"
        result = render(binary, case, png)
        crop(png, result, zoom)
        full.append((png, case.name))
        zoomed.append((zoom, case.name))
    variants: list[tuple[Path, str]] = []
    for index, case in enumerate(looks()):
        png = out_dir / f"look-{index:02d}.png"
        render(binary, case, png)
        variants.append((png, case.name))
    loops: list[tuple[Path, str]] = []
    for index, case in enumerate(spirals()):
        png = out_dir / f"spiral-{index:02d}.png"
        render(binary, case, png)
        loops.append((png, case.name))
    tool = sheet_tool(out_dir)
    sheet(tool, out_dir / "gallery.png", 4, 520, full)
    sheet(tool, out_dir / "junctions.png", 5, 300, zoomed)
    sheet(tool, out_dir / "looks.png", 3, 600, variants)
    sheet(tool, out_dir / "spirals.png", 3, 600, loops)
    for name in ("gallery.png", "junctions.png", "looks.png", "spirals.png"):
        print(out_dir / name)


if __name__ == "__main__":
    main()

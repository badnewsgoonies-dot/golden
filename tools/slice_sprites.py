#!/usr/bin/env python3
import sys
import os
from pathlib import Path

# Self-install Pillow if missing
try:
    from PIL import Image
except Exception:
    import subprocess, sys as _sys
    subprocess.check_call([_sys.executable, "-m", "pip", "install", "--quiet", "Pillow~=10.4"]) 
    from PIL import Image


def slice_grid(image_path: Path, cols: int, rows: int, out_dir: Path, prefix: str | None = None) -> list[Path]:
    image = Image.open(image_path).convert("RGBA")
    width, height = image.size
    if width % cols != 0 or height % rows != 0:
        raise ValueError(f"Image {image_path} size {width}x{height} not divisible by {cols}x{rows}")

    tile_w = width // cols
    tile_h = height // rows

    saved: list[Path] = []
    for r in range(rows):
        for c in range(cols):
            left = c * tile_w
            upper = r * tile_h
            right = left + tile_w
            lower = upper + tile_h
            tile = image.crop((left, upper, right, lower))
            name = f"{prefix or image_path.stem}_r{r}_c{c}.png"
            out_path = out_dir / name
            tile.save(out_path)
            saved.append(out_path)
    return saved


def main(argv: list[str]) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Slice spritesheet (grid) into sprites")
    parser.add_argument("inputs", nargs="+", help="Input image files")
    parser.add_argument("--cols", type=int, default=4)
    parser.add_argument("--rows", type=int, default=2)
    parser.add_argument("--out", type=str, default="art/sprites/converted")
    args = parser.parse_args(argv)

    out_base = Path(args.out)
    out_base.mkdir(parents=True, exist_ok=True)

    total_saved = 0
    for inp in args.inputs:
        ipath = Path(inp)
        if not ipath.exists():
            print(f"[warn] input not found: {ipath}")
            continue
        subdir = out_base / ipath.stem
        subdir.mkdir(parents=True, exist_ok=True)
        try:
            saved = slice_grid(ipath, args.cols, args.rows, subdir)
        except Exception as exc:
            print(f"[error] failed to slice {ipath}: {exc}")
            continue
        print(f"sliced {ipath} -> {len(saved)} sprites in {subdir}")
        total_saved += len(saved)

    print(f"done. total sprites: {total_saved}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

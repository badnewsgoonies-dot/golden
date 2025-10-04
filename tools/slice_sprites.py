#!/usr/bin/env python3
import argparse
import os
from typing import List, Tuple
from PIL import Image


def ensure_directory(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def compute_cell_size(
    image_width: int,
    image_height: int,
    columns: int,
    rows: int,
    margin: int,
    spacing: int,
) -> Tuple[int, int]:
    usable_width = image_width - (margin * 2) - (spacing * (columns - 1))
    usable_height = image_height - (margin * 2) - (spacing * (rows - 1))
    if usable_width <= 0 or usable_height <= 0:
        raise ValueError(
            f"Invalid margins/spacings for image {image_width}x{image_height}: usable area is non-positive"
        )
    if usable_width % columns != 0 or usable_height % rows != 0:
        # Warn but still floor divide to proceed
        print(
            f"[warn] Usable size {usable_width}x{usable_height} not divisible by {columns}x{rows}. "
            "Cropping will floor; last pixels may be dropped."
        )
    cell_width = usable_width // columns
    cell_height = usable_height // rows
    return cell_width, cell_height


def trim_transparent_border(im: Image.Image) -> Image.Image:
    if "A" in im.getbands():
        alpha = im.split()[3]
        bbox = alpha.getbbox()
        if bbox:
            return im.crop(bbox)
        return im
    # Fallback: use getbbox on composite – may trim based on color
    bbox = im.getbbox()
    return im.crop(bbox) if bbox else im


def slice_grid(
    image_path: str,
    columns: int,
    rows: int,
    output_dir: str,
    prefix: str,
    margin: int = 0,
    spacing: int = 0,
    trim: bool = False,
) -> List[str]:
    with Image.open(image_path) as im:
        im = im.convert("RGBA")
        cell_w, cell_h = compute_cell_size(im.width, im.height, columns, rows, margin, spacing)
        print(
            f"Slicing {os.path.basename(image_path)}: {im.width}x{im.height} -> cells {cell_w}x{cell_h} ({columns}x{rows})"
        )
        ensure_directory(output_dir)
        saved_paths: List[str] = []
        index = 0
        for row in range(rows):
            for col in range(columns):
                left = margin + col * (cell_w + spacing)
                top = margin + row * (cell_h + spacing)
                right = left + cell_w
                bottom = top + cell_h
                tile = im.crop((left, top, right, bottom))
                if trim:
                    tile = trim_transparent_border(tile)
                filename = f"{prefix}_r{row}_c{col}.png"
                out_path = os.path.join(output_dir, filename)
                tile.save(out_path)
                saved_paths.append(out_path)
                index += 1
        return saved_paths


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Slice a grid spritesheet into individual sprites.")
    parser.add_argument("--input", required=True, help="Path to source image")
    parser.add_argument("--cols", type=int, required=True, help="Number of columns in grid")
    parser.add_argument("--rows", type=int, required=True, help="Number of rows in grid")
    parser.add_argument("--outdir", required=True, help="Directory to write sprites")
    parser.add_argument("--prefix", default="sprite", help="Output filename prefix")
    parser.add_argument("--margin", type=int, default=0, help="Outer margin (pixels)")
    parser.add_argument("--spacing", type=int, default=0, help="Spacing between cells (pixels)")
    parser.add_argument("--trim", action="store_true", help="Trim transparent borders around each sprite")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    outputs = slice_grid(
        image_path=args.input,
        columns=args.cols,
        rows=args.rows,
        output_dir=args.outdir,
        prefix=args.prefix,
        margin=args.margin,
        spacing=args.spacing,
        trim=args.trim,
    )
    print(f"Wrote {len(outputs)} sprites to {args.outdir}")


if __name__ == "__main__":
    main()

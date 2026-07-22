#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx", "typer"]
# ///
"""Capture wide title/author banners from paper PDFs, for use as slide figures.

Renders page 1 of each PDF and crops a wide strip from the top — title,
authors, and a little of the abstract — rather than a full portrait page,
which reads badly on a 16:9 slide.

Crop geometry is per-paper because journal layouts differ: `top` and `height`
are fractions of the page, tuned by eye once and then recorded in covers.csv.

Needs `pdftoppm` (poppler) and `magick` (ImageMagick) on PATH.
"""

import asyncio
import csv
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Annotated

import httpx
import typer

HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; talk-figures/1.0)"}
DPI = 200

# A crop fraction never lands exactly between two lines of text, so the banner
# ends on a row of half-height glyphs. These control the search for the last
# clean gap between lines to cut at instead.
MIN_GAP_PX = 8  # a blank band this tall counts as a line gap, not a serif
WHITE = 254.6  # after thresholding, a blank row is essentially all white


def row_means(image: Path) -> list[float]:
    """Mean grey value of each pixel row, via a 1-pixel-wide scaled copy.

    Rows come back as `0,<y>: (<value>)  #RRGGBB  gray(<value>)`, where the
    value is either 0-255 or a percentage depending on the ImageMagick build.
    """
    # Threshold first: a lone superscript in a 1600px-wide row barely moves a
    # grey mean, but after thresholding it costs enough white to be visible.
    txt = subprocess.run(
        [
            "magick",
            image,
            "-colorspace",
            "gray",
            "-threshold",
            "75%",
            "-scale",
            "1x!",
            "txt:-",
        ],
        check=True,
        capture_output=True,
        text=True,
    ).stdout

    means: list[float] = []
    for line in txt.splitlines()[1:]:
        match = re.search(r":\s*\(([\d.]+)(%?)", line)
        if match:
            value = float(match.group(1))
            means.append(value * 2.55 if match.group(2) else value)
    return means


def last_line_gap(image: Path) -> int | None:
    """Row index of the last blank band, so the crop ends between two lines."""
    means = row_means(image)
    if not means:
        return None

    run_end = None
    for y in range(len(means) - 1, -1, -1):
        if means[y] >= WHITE:
            if run_end is None:
                run_end = y
        elif run_end is not None:
            if run_end - y >= MIN_GAP_PX:
                return run_end
            run_end = None
    return None


def render_banner(
    pdf: Path, out_png: Path, top: float, height: float, left: float = 0.0
) -> None:
    """Render page 1 and crop a wide horizontal strip from it.

    `left` trims the gutter — arXiv and bioRxiv stamp a rotated banner down the
    left edge of page 1, which otherwise lands in the crop.
    """
    with tempfile.TemporaryDirectory() as tmp:
        stem = Path(tmp) / "page"
        subprocess.run(
            ["pdftoppm", "-f", "1", "-l", "1", "-r", str(DPI), "-png", pdf, stem],
            check=True,
            capture_output=True,
        )
        page = next(Path(tmp).glob("page*.png"))

        size = subprocess.run(
            ["magick", "identify", "-format", "%w %h", page],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.split()
        width, page_height = int(size[0]), int(size[1])

        rough = Path(tmp) / "rough.png"
        subprocess.run(
            [
                "magick",
                page,
                "-crop",
                f"{width - int(width * left)}x{int(page_height * height)}"
                f"+{int(width * left)}+{int(page_height * top)}",
                "+repage",
                rough,
            ],
            check=True,
            capture_output=True,
        )

        gap = last_line_gap(rough)
        trim = ["-crop", f"x{gap}+0+0", "+repage"] if gap else []

        subprocess.run(
            [
                "magick",
                rough,
                *trim,
                "-resize",
                "1600x",
                "-bordercolor",
                "white",
                "-border",
                "12",
                "-quality",
                "88",
                out_png,
            ],
            check=True,
            capture_output=True,
        )


async def capture_one(
    client: httpx.AsyncClient, row: dict[str, str], out_dir: Path
) -> tuple[str, bool, str]:
    """Download one paper and write its banner PNG."""
    name = row["short_name"]
    out_png = out_dir / f"{name}.png"

    try:
        response = await client.get(row["pdf_url"], headers=HEADERS)
        response.raise_for_status()
    except httpx.HTTPError as exc:
        return name, False, f"{type(exc).__name__}: {exc}"

    if not response.content.startswith(b"%PDF"):
        return name, False, "not a PDF (paywall or block page)"

    with tempfile.NamedTemporaryFile(suffix=".pdf") as tmp_pdf:
        tmp_pdf.write(response.content)
        tmp_pdf.flush()
        try:
            await asyncio.to_thread(
                render_banner,
                Path(tmp_pdf.name),
                out_png,
                float(row.get("crop_top") or 0.05),
                float(row.get("crop_height") or 0.30),
                float(row.get("crop_left") or 0.0),
            )
        except subprocess.CalledProcessError as exc:
            return name, False, f"render failed: {exc.stderr.decode()[:120]}"

    return name, True, f"{out_png.stat().st_size / 1000:.0f} KB"


async def capture_all(csv_path: Path, out_dir: Path) -> list[tuple[str, bool, str]]:
    rows = list(csv.DictReader(csv_path.open(encoding="utf-8")))
    out_dir.mkdir(parents=True, exist_ok=True)

    async with httpx.AsyncClient(timeout=90, follow_redirects=True) as client:
        return await asyncio.gather(*(capture_one(client, row, out_dir) for row in rows))


def main(
    csv_path: Annotated[Path, typer.Option("--csv")] = Path(__file__).parent
    / "covers.csv",
    out_dir: Annotated[Path, typer.Option("--out")] = Path(__file__).parent / "papers",
) -> None:
    """Capture a title banner for every paper listed in the CSV."""
    results = asyncio.run(capture_all(csv_path, out_dir))

    for name, ok, detail in results:
        typer.echo(f"{'ok  ' if ok else 'FAIL'}  {name}  ({detail})")

    failed = [name for name, ok, _ in results if not ok]
    typer.echo(f"\n{len(results) - len(failed)}/{len(results)} captured → {out_dir}")
    if failed:
        raise typer.Exit(code=1)


if __name__ == "__main__":
    typer.run(main)

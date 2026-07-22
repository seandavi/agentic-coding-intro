#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx", "typer"]
# ///
"""Download the open-access PDFs listed in papers.csv.

This is the *fallback* for the live demo — normally the agent does this work
itself from papers.csv. Keep it here so a rehearsal (or a bad conference
network) never blocks the talk.
"""

import asyncio
import csv
from pathlib import Path
from typing import Annotated

import httpx
import typer

# Publisher sites reject the default client UA; a browser UA is enough.
HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; talk-demo/1.0)"}


async def fetch_one(
    client: httpx.AsyncClient, row: dict[str, str], out_dir: Path
) -> tuple[str, bool, str]:
    """Download one paper's PDF. Returns (short_name, ok, detail)."""
    target = out_dir / f"{row['short_name']}.pdf"
    if target.exists():
        return row["short_name"], True, "already present"

    try:
        response = await client.get(row["pdf_url"], headers=HEADERS)
        response.raise_for_status()
    except httpx.HTTPError as exc:
        return row["short_name"], False, f"{type(exc).__name__}: {exc}"

    if not response.content.startswith(b"%PDF"):
        return row["short_name"], False, "response was not a PDF (paywall or block page)"

    target.write_bytes(response.content)
    return row["short_name"], True, f"{len(response.content) / 1_000_000:.1f} MB"


async def fetch_all(csv_path: Path, out_dir: Path) -> list[tuple[str, bool, str]]:
    rows = list(csv.DictReader(csv_path.open(encoding="utf-8")))
    out_dir.mkdir(parents=True, exist_ok=True)

    async with httpx.AsyncClient(timeout=60, follow_redirects=True) as client:
        return await asyncio.gather(*(fetch_one(client, row, out_dir) for row in rows))


def main(
    csv_path: Annotated[Path, typer.Option("--csv", help="Paper list.")] = Path(
        __file__
    ).parent
    / "papers.csv",
    out_dir: Annotated[Path, typer.Option("--out", help="Where to write PDFs.")] = Path(
        __file__
    ).parent
    / "papers",
) -> None:
    """Fetch every PDF in the CSV into the output directory."""
    results = asyncio.run(fetch_all(csv_path, out_dir))

    for name, ok, detail in results:
        typer.echo(f"{'ok  ' if ok else 'FAIL'}  {name}  ({detail})")

    failed = [name for name, ok, _ in results if not ok]
    typer.echo(f"\n{len(results) - len(failed)}/{len(results)} downloaded → {out_dir}")
    if failed:
        raise typer.Exit(code=1)


if __name__ == "__main__":
    typer.run(main)

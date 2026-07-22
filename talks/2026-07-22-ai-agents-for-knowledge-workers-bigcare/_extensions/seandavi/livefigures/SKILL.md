---
name: livefigures
description: Author figures in Quarto documents using the quarto-livefigures extension — editable, version-controlled figure sources (Excalidraw, Vega-Lite, Graphviz, PlantUML, and 14 more) rendered at build time. Use when creating or editing diagrams, charts, schemas, or timing figures in a Quarto project, when the user asks for a figure/diagram in a .qmd document, or when converting static images to maintainable sources.
---

# Authoring figures with quarto-livefigures

The project renders figures from plain-text/JSON sources during
`quarto render`. Never export or commit SVG/PNG for these figures — the
source file (or inline block) IS the figure. Rendered assets go to a
`_livefigures/` cache (gitignored build artifact).

## Two ways to write a figure

**File-referenced** (preferred for reuse or larger sources) — normal
Quarto image syntax pointing at a source file:

```markdown
![Overall architecture](figures/architecture.excalidraw){#fig-arch width=80%}
```

**Inline fenced block** (preferred for small diagrams) — class form, WITH
the leading dot:

````markdown
```{.nomnoml #fig-pipe fig-cap="The pipeline"}
[Filter] -> [Cache] -> [SVG]
```
````

Captions, `#fig-` labels, cross-references (`@fig-pipe`), `width`, and
lightbox behave exactly like native Quarto figures in both forms.
IMPORTANT: `{.nomnoml}` (class syntax) — NOT `{nomnoml}`, which Quarto
treats as an unknown executable engine and rejects.

## Setup (once per project)

```yaml
# _quarto.yml — pre-ast placement is required for crossrefs on inline blocks
filters:
  - at: pre-ast
    path: livefigures
```

Install if missing: `quarto add seandavi/quarto-livefigures`
(requires Node >= 18 on PATH).

## Choosing a format

| You need | Use | Extension / block class | Syntax docs |
| --- | --- | --- | --- |
| Hand-drawn sketch, annotated mockup | Excalidraw | `.excalidraw` / `{.excalidraw}` | <https://docs.excalidraw.com/> (scene JSON) |
| Statistical chart (bar/line/scatter/…) | Vega-Lite | `.vl.json` / `{.vega-lite}` | <https://vega.github.io/vega-lite/docs/> |
| Force-directed network, custom viz | Vega | `.vg.json` / `{.vega}` | <https://vega.github.io/vega/docs/> |
| Dependency graph, state machine, tree | Graphviz | `.dot`, `.gv` / `{.dot}` | <https://graphviz.org/documentation/> |
| Quick boxes-and-arrows, UML-ish | nomnoml | `.noml` / `{.nomnoml}` | <https://nomnoml.com/> |
| Database schema / ER diagram | DBML | `.dbml` / `{.dbml}` | <https://dbml.dbdiagram.io/docs/> |
| Digital timing / register bit-fields | WaveDrom | `.wavedrom.json` / `{.wavedrom}` | <https://wavedrom.com/tutorial.html> |
| Byte/packet layout (RFC-style) | bytefield | `.bytefield` / `{.bytefield}` | <https://bytefield-svg.deepsymmetry.org/> |
| UML sequence/class/activity/state | PlantUML | `.puml` / `{.plantuml}` | <https://plantuml.com/> |
| Modern declarative diagram | D2 | `.d2` / `{.d2}` | <https://d2lang.com/tour/intro> |
| C4 architecture | C4-PlantUML / Structurizr | `.c4` / `{.c4}`, `.structurizr` | <https://github.com/plantuml-stdlib/C4-PlantUML> |
| ER (terse) | erd | `.erd` / `{.erd}` | <https://github.com/BurntSushi/erd> |
| ASCII art → diagram | ditaa / svgbob | `.ditaa`, `.svgbob` | <https://ditaa.sourceforge.net/> |
| PIC-style technical drawing | pikchr | `.pikchr` / `{.pikchr}` | <https://pikchr.org/home/doc/trunk/doc/userman.md> |
| LaTeX/TikZ graphics | TikZ | `.tikz` / `{.tikz}` | <https://tikz.dev/> |

Prefer, in order: (1) a JSON grammar when the figure is data-driven,
(2) Graphviz/D2/PlantUML for structure the reader must trust,
(3) nomnoml for quick sketches. Never hand-place coordinates.

## Options

Per figure (attributes) or project-wide (`livefigures:` metadata):

- `theme=light|dark|auto` — default auto (HTML). Only Excalidraw and
  Vega support true `dark`; other backends hard-fail on it.
- `background=transparent|scene` — Excalidraw/Vega only.
- `livefigures: kroki-url: <url>` — self-hosted kroki endpoint for the
  kroki-backed formats (PlantUML, D2, C4, Structurizr, erd, ditaa,
  pikchr, svgbob, TikZ). These need network on cache misses; all other
  formats render offline.

## Failure modes to expect (all abort the render, by design)

- Corrupt/invalid source → error naming the file. Fix the source.
- `{format}` engine error → you forgot the dot: use `{.format}`.
- `?@fig-x` unresolved crossref on an inline block → the filter isn't at
  `pre-ast`; fix the `filters:` config as above.
- `theme=dark is not supported for …` → that backend has no dark
  variant; drop the option.
- TikZ: source must be a COMPLETE `\documentclass{standalone}` document.
- Kroki formats: network unreachable → cache miss fails; warm cache
  renders offline.
- Excalidraw scenes with CJK text are unsupported (font not bundled).

## Verify what you wrote (don't render blind)

The extension ships a CLI mirroring these checks:

```bash
node _extensions/seandavi/livefigures/cli.mjs validate figures/arch.dot   # exit 1 + error on bad source
node _extensions/seandavi/livefigures/cli.mjs render figures/arch.dot -o /tmp/arch.png  # then LOOK at it
```

Better: connect the livefigures MCP server and its `render` tool returns
the figure as an image in-context (plus `validate`, `list_formats`):

```bash
claude mcp add --transport http livefigures https://mcp.livefigures.seandavis.net/mcp  # public
claude mcp add livefigures -- node _extensions/seandavi/livefigures/mcp.mjs                     # local/offline
```

Full docs: <https://livefigures.seandavis.net> · repo:
<https://github.com/seandavi/quarto-livefigures>

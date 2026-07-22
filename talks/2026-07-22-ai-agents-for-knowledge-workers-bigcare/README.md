# Slides: AI Agents for Knowledge Workers (BigCare, 2026-07-22)

A 50–60 minute talk for a broad audience of clinicians and researchers.
Adapted from the CSHL deck (`../2026-06-18-chatbots-to-coding-agents-cshl/`),
recentered on knowledge work rather than coding: documents, folders of PDFs,
grants, and manuscripts. The audience is mostly basic-science cancer
researchers (genomics and molecular biology) with some clinicians, so examples
lean single-cell and immunotherapy. Tool-agnostic, with a ~10-minute live demo
(DOI list → downloaded PDFs → extraction table + cited synthesis), a
privacy/PHI slide, a section on how agents extend themselves (shell, skills,
MCP, subagents), and a closing section on published biomedical agent systems.

The deck deliberately runs longer than 50-60 minutes so it can be tailored per
audience; the opening slide's speaker notes carry a timing plan and an ordered
cut list.

## Build

Built with [Quarto](https://quarto.org/) + reveal.js. To render the deck:

```bash
quarto render slides.qmd --to revealjs
# produces a self-contained slides.html (open it in any browser)
```

### Citations

Papers are cited by persistent identifier directly in the slide source —
`[@doi:10.1126/science.adz4351]` — and resolved by
[quartobot](https://seandavi.github.io/quartobot/), which `_quarto.yml` runs
as a pre-render hook. It fetches metadata from Crossref/PubMed and writes
`references.resolved.bib` (gitignored, regenerated each render); pandoc formats
the References slide from it using `ama.csl`.

**Rendering therefore requires `quartobot` on PATH**
(`uv tool install git+https://github.com/seandavi/quartobot`). Nothing is
hand-transcribed, so a citation is either correct or fails loudly at render.
To add one, write the `@doi:` key in the slide and re-render.

Note `auto-stretch: false` in the deck's YAML — it is load-bearing. Reveal's
auto-stretch computes a remaining height of 0 for an image that shares a slide
with a caption, which silently makes the image vanish.

Present with `quarto preview slides.qmd`, or open `slides.html` directly.
The rendered `slides.html` and `slides_files/` are git-ignored (regenerate
them locally).

The default build **presents from this directory** — `slides.html` needs
`slides_files/` next to it. For one self-contained file you can email or carry
on a USB stick:

```bash
quarto render slides.qmd --profile share
```

That profile turns the chalkboard off, because reveal's chalkboard plugin
cannot be inlined into self-contained output; everything else, pointer
included, survives. Both builds write to the same `slides.html`, so re-render
without the profile before presenting.

## Presenting

| Key | Does |
| --- | --- |
| `s` | speaker view — notes, next slide, timer |
| `f` / `o` / `g` | fullscreen · slide overview · go to slide number |
| `c` | **draw on the current slide** |
| `b` | **blank board** to work through something from scratch |
| `x` | cycle ink colour (palette also appears at the left) |
| `del` / `backspace` | clear this slide's drawings · clear all |
| `d` | download drawings — otherwise they vanish with the tab |
| `q` | laser pointer (amber dot; hides the mouse cursor) |
| `?` | full keyboard-shortcut overlay |

Drawings are per-session. If a whiteboard explanation turns out well, press
`d` and commit the JSON, then point `chalkboard: src:` in `_quarto.yml` at it
to have it pre-loaded next time.

## Demo materials

See [`demo/README.md`](demo/README.md). In short: `demo/papers.csv` is a list of
10 open-access single-cell / immunotherapy papers (DOIs only, 3 KB). The agent
downloads them live as Act 1, then extracts and synthesizes as Act 2. The PDFs
(~114 MB) are git-ignored and re-fetched on demand; `demo/fetch_papers.py` is
the offline fallback.

## Figures

`figures/` holds the explainer graphics, on a shared palette
(input/context = blue, output = amber, good/lean = green, bloat = coral).
Copied from the CSHL deck; `fig-chatbot-vs-agent.svg` and
`fig-markdown-memory.svg` were relabeled for a document-centric audience
("AI agent", "your real files", notes-file examples instead of code examples).

| File | What it shows |
| --- | --- |
| `fig-chatbot-vs-agent.svg` | chatbot prompt window vs. the agent plan/act/observe loop |
| `fig-tokens.svg` | a sentence split into tokens; the ~4-chars rule |
| `fig-context-window.svg` | the context window as a finite, shared token budget |
| `fig-markdown-memory.svg` | a versioned notes file loaded into every session |
| `fig-context-management.svg` | one bloated session vs. clearing between tasks |
| `fig-skills-vs-monolith.svg` | one large file vs. a small core + playbooks on demand |
| `fig-knowledge-work.svg` | the centerpiece: research, PDF extraction, slides, editing, brainstorming |
| `fig-agent-extensions.svg` | Part 4: shell/tools, skills, MCP, and subagents side by side |
| `fig-api-flow.svg` | request → Semantic Scholar → labelled fields, for the API slide |
| `semantic-scholar.png` | screenshot of the search that produced `demo/papers.csv` |
| `chart-context-rot.svg` | lost-in-the-middle + degradation with length (`charts.R`) |
| `chart-cost.svg` | input vs. output token pricing (unused in this deck; kept for reference) |

### Paper banners

`figures/papers/*.png` are wide title/author crops of page 1 of each paper
cited in the closing section, generated by `capture_covers.py` from the DOIs
and crop geometry in `covers.csv`:

```bash
cd figures && ./capture_covers.py        # needs uv, pdftoppm (poppler), magick
```

Same principle as the demo: the repo stores the *list*, not the PDFs. The
script downloads each paper, renders page 1, crops a wide strip from the top,
and auto-trims to the last clean gap between lines so no banner ends on a row
of half-height glyphs. Tune `crop_top` / `crop_height` / `crop_left` in
`covers.csv` if a journal's layout needs it (`crop_left` removes the rotated
arXiv/bioRxiv stamp down the gutter).

All six are open access (CC BY, CC BY-NC, or arXiv/bioRxiv preprints); every
PDF URL was verified to resolve on 2026-07-21. `txagent.png` is captured but
not currently used in the deck.

The two charts are generated with R/ggplot2:

```bash
cd figures && Rscript charts.R   # needs ggplot2, patchwork; writes the two chart-*.svg
```

Figure numbers (tokens, context-window sizes) are mid-2026 and illustrative —
the shapes and ratios are the durable points.

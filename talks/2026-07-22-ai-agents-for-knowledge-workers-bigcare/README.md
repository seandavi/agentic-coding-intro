# Slides: AI Agents for Knowledge Workers (BigCare, 2026-07-22)

A 50–60 minute talk for a broad audience of clinicians and researchers.
Adapted from the CSHL deck (`../2026-06-18-chatbots-to-coding-agents-cshl/`),
recentered on knowledge work rather than coding: documents, folders of PDFs,
grants, and manuscripts. The audience is mostly basic-science cancer
researchers (genomics and molecular biology) with some clinicians, so examples
lean single-cell and immunotherapy. Tool-agnostic, with a ~10-minute live demo
(DOI list → downloaded PDFs → extraction table + cited synthesis) and a
privacy/PHI slide.

## Build

Built with [Quarto](https://quarto.org/) + reveal.js. To render the deck:

```bash
quarto render slides.qmd --to revealjs
# produces a self-contained slides.html (open it in any browser)
```

Present with `quarto preview slides.qmd`, or open `slides.html` directly.
Speaker notes are in the deck — press **`s`** in the browser to open the
speaker view. The rendered `slides.html` is git-ignored (regenerate it locally).

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
| `chart-context-rot.svg` | lost-in-the-middle + degradation with length (`charts.R`) |
| `chart-cost.svg` | input vs. output token pricing (unused in this deck; kept for reference) |

The two charts are generated with R/ggplot2:

```bash
cd figures && Rscript charts.R   # needs ggplot2, patchwork; writes the two chart-*.svg
```

Figure numbers (tokens, context-window sizes) are mid-2026 and illustrative —
the shapes and ratios are the durable points.

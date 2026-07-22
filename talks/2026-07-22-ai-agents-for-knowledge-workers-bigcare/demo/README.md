# Demo materials

The live demo goes from a **reference list to a synthesis**, in two acts:

1. **Fetch** — the agent reads `papers.csv` and downloads the open-access PDFs
   into `papers/`.
2. **Extract and synthesize** — it reads those PDFs, builds `extraction.csv`,
   and writes a one-page synthesis with the disagreements flagged.

Only the CSV is committed. The PDFs (~114 MB) are git-ignored and re-fetched
on demand — that also keeps us on the right side of "download for reading,
don't redistribute."

## The papers

Ten single-cell studies of the tumor microenvironment and immunotherapy
response, chosen for a genomics-heavy cancer audience. All CC BY or CC BY-NC,
all with a PDF URL verified to be downloadable by script (2026-07-21).

The set contains a real, live scientific disagreement — **what predicts
response to checkpoint blockade?** A pan-cancer stemness signature, a T-cell
exhaustion signature, CAF subpopulations, and myeloid composition each get a
different answer here. That is the tension the synthesis step should surface;
if the agent smooths it over, that is the teachable failure.

There is also one review among the nine primary studies, which has no sample
size — a good test of whether the agent flags a missing field or invents one.

Two otherwise-ideal papers (AACR and BMJ titles on CAFs and immunotherapy
response) were deliberately left out: their sites return 403 to scripted
requests. Worth mentioning during Act 1 as real friction.

## Fallback fetch

Normally the agent downloads the PDFs — that *is* Act 1. This script is the
backup for a rehearsal or a bad conference network:

```bash
./fetch_papers.py            # needs uv; deps are declared inline (PEP 723)
./fetch_papers.py --out /tmp/papers
```

It skips files already present, verifies each response really is a PDF, and
exits non-zero if any fail.

## Before the talk

- [ ] Run `./fetch_papers.py` — confirm 10/10 (last verified 2026-07-21)
- [ ] Do a full rehearsal run; save the outputs to `backup/`
- [ ] Record a screen capture of that run as the wifi fallback
- [ ] Pick the row you will spot-check live, and know what the PDF actually says

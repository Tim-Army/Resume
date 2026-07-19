# Resume build manifest

What gets built, from what, by what. Update this when a source, output, or tool
changes — not on every build.

## Build

| Source | Output | Pages | Built by |
|---|---|---|---|
| `resume/master/Tim-Fox-Resume.md` | `pdf/Tim-Fox-Expanded-Resume.pdf` | 3 (enforced) | `scripts/python/create-full-resume-pdf.py` |

```sh
python3 -m pip install -r scripts/python/requirements.txt
python3 scripts/python/create-full-resume-pdf.py
```

Both arguments are optional and default to the source and output above. The
script fails if the result is not exactly three pages, or if expected content is
missing from the extracted text.

Dependencies are pinned in `scripts/python/requirements.txt`.

## Sources not currently built

- `resume/targeted/private-sector/Tim-Fox-Resume-Private-Sector.md`.
- `resume/targeted/federal-defense/Tim-Fox-Resume-Federal-Defense.md`.

These are maintained as Markdown for tailoring against specific vacancies. No
PDF is generated from them and they are not published to the website.

## Website

The site (`index.html`) is hand-maintained and mirrors the content of
`resume/master/Tim-Fox-Resume.md`. It is not generated from the Markdown, so
content changes must be applied to both.

## Automation

- `scripts/python/` — The current build path.
- `scripts/bash/lint-resume.sh` — Editorial linter, run locally and in CI by
  `.github/workflows/lint-resume.yml`.
- `scripts/bash/zArchive/` — 25 superseded one-shot scripts, retained for
  reference only. See
  [scripts/bash/zArchive/README.md](../scripts/bash/zArchive/README.md); they
  must not be run.

## Editorial rules

Two mechanical rules are enforced across `resume/**/*.md`:

1. Every bullet ends with a period.
2. Every Markdown heading is preceded by a blank line, so that strict
   CommonMark renderers do not absorb it into the preceding block.

The linter is scoped to `resume/` deliberately. Other Markdown in the
repository — notably the `website/` link inventory — legitimately breaks rule 1.

## Retired

- **Concise one-page resume**, retired 2026-07-19. Its Markdown source, PDFs,
  and generator scripts were deleted the same day; earlier versions remain
  recoverable from Git history.

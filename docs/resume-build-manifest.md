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
- `scripts/bash/` — Historical one-shot scripts, retained for reference only.
  See [scripts/bash/README.md](../scripts/bash/README.md); they must not be run.

## Retired

- **Concise one-page resume**, retired 2026-07-19. Source is
  `archive/Tim-Fox-Resume-one-page.md`; last published PDF is
  `pdf/zArchive/Tim-Fox-Concise-Resume-20260719.pdf`.

# Archived automation

Superseded one-shot scripts, retained for reference only.

**Do not run these.** Each hardcodes an absolute repository path and a single
commit message, and several embed a full copy of the resume text in a heredoc.
Those embedded copies are stale — `resume/master/Tim-Fox-Resume.md` is the
source of truth. Their internal path constants still point at
`scripts/bash/<name>.sh`, which is no longer where they live.

Some were kept superficially current through bulk find-and-replace, for example
when the PDFs were renamed. That made them look maintained without making them
safe to run.

## Why they are kept

They document how earlier PDFs were produced, and the current Python builder
descends from `download-resume-to-pdf-and-push.sh` — both share the same
`SimpleDocTemplate` layout, `normalize_text` helper, rule colour, and
right-aligned page footer.

## Notable groups

| Scripts | Note |
|---|---|
| `download-resume-to-pdf-and-push.sh` | Ancestor of `scripts/python/create-full-resume-pdf.py`. |
| `condense-resume-to-three-pages-and-push*.sh` | A separate, denser layout using `BaseDocTemplate`. Not the ancestor. |
| `create-tim-fox-resume-repo.sh`, `-v2.sh` | Byte-identical duplicates. |
| `add-chapter-to-github-project-volume-layout*.sh` | Three variants: plain, `-fixed`, `-resumable`. |

The naming pattern here — `-v2`, `-v3`, `-fixed`, `-resumable`, and timestamped
copies — is what this directory exists to quarantine. Resume content belongs in
`resume/*.md`; behavior changes belong in flags on a single script.

## Current automation

- `scripts/python/create-full-resume-pdf.py` — Builds the resume PDF.
- `scripts/bash/lint-resume.sh` — Enforces the editorial rules.

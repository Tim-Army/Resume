#!/usr/bin/env bash
#
# Download the master Tim Fox resume from GitHub, convert it to PDF, place the
# PDF in the repository's pdf/ directory, then commit and push the update.
#
# Default source:
#   https://github.com/Tim-Army/Resume/blob/main/resume/master/Tim-Fox-Resume.md
#
# Default output:
#   pdf/Tim-Fox-Expanded-Resume.pdf
#

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2026.07.17.1"
readonly EXPECTED_REPO_NAME="Tim-Fox-Resume"
readonly CANONICAL_SCRIPT_NAME="download-resume-to-pdf-and-push.sh"
readonly GITHUB_OWNER="Tim-Army"
readonly GITHUB_REPOSITORY="Tim-Fox-Resume"
readonly DEFAULT_REMOTE_BRANCH="main"
readonly REMOTE_RESUME_PATH="resume/master/Tim-Fox-Resume.md"
readonly DEFAULT_SOURCE_URL="https://github.com/Tim-Army/Resume/blob/main/resume/master/Tim-Fox-Resume.md"
readonly DEFAULT_RAW_URL="https://raw.githubusercontent.com/Tim-Army/Resume/main/resume/master/Tim-Fox-Resume.md"
readonly OUTPUT_RELATIVE_PATH="pdf/Tim-Fox-Expanded-Resume.pdf"
readonly SCRIPT_RELATIVE_PATH="scripts/bash/${CANONICAL_SCRIPT_NAME}"

REPO_ROOT=""
REMOTE_BRANCH="$DEFAULT_REMOTE_BRANCH"
SOURCE_URL="$DEFAULT_SOURCE_URL"
SOURCE_FILE=""
COMMIT_CHANGES=true
PUSH_CHANGES=true
OPEN_PDF=false
INSTALL_DEPS=true
COMMIT_MESSAGE="docs: publish master resume PDF"
SOURCE_SCRIPT=""
TEMP_SELF=""
TEMP_DIR=""
PYTHON_CMD=""

log() {
  printf '[Tim-Fox-Resume PDF] %s\n' "$*" >&2
}

warn() {
  printf '[Tim-Fox-Resume PDF] WARNING: %s\n' "$*" >&2
}

fatal() {
  printf '[Tim-Fox-Resume PDF] ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$TEMP_SELF" && -f "$TEMP_SELF" ]]; then
    rm -f "$TEMP_SELF"
  fi
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
  return 0
}
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Download the master Tim Fox resume from GitHub, convert it to PDF, and push it.

Usage:
  download-resume-to-pdf-and-push.sh [options]

Options:
  --repo PATH          Tim-Fox-Resume repository root. By default, detect with Git.
  --branch NAME        Remote source branch. Default: main.
  --source-url URL     Source GitHub URL shown in logs. The default repository and
                       file path are downloaded through the authenticated GitHub API.
  --source-file PATH   Use a local Markdown file instead of downloading. Useful for
                       testing or offline builds.
  --message TEXT       Git commit message.
                       Default: docs: publish master resume PDF.
  --no-commit          Create the PDF without committing or pushing.
  --no-push            Create and commit the PDF without pushing.
  --no-install-deps    Do not install Python PDF dependencies when missing.
  --open               Open the generated PDF on macOS.
  --version            Show the script version.
  -h, --help           Show this help text.

Output:
  pdf/Tim-Fox-Expanded-Resume.pdf

Repository update:
  The script installs itself as:
  scripts/bash/download-resume-to-pdf-and-push.sh

Dependencies:
  git, python3, and either:
    - GitHub CLI (gh) authenticated to GitHub, or
    - curl for public-repository access.

  Python packages reportlab and pypdf are installed into an isolated cache
  environment on first use unless --no-install-deps is supplied.
USAGE
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fatal "Required command not found: $1"
}

absolute_path() {
  local path="$1"

  if [[ "$path" == "~/"* ]]; then
    path="$HOME/${path#~/}"
  fi

  if [[ "$path" != /* ]]; then
    path="$PWD/$path"
  fi

  local parent base
  parent=$(dirname "$path")
  base=$(basename "$path")
  mkdir -p "$parent"
  parent=$(cd "$parent" && pwd -P)
  printf '%s/%s\n' "$parent" "$base"
}

capture_self() {
  SOURCE_SCRIPT=$(absolute_path "${BASH_SOURCE[0]}")
  TEMP_SELF=$(mktemp "${TMPDIR:-/tmp}/tim-fox-resume-pdf-script.XXXXXX")
  cp "$SOURCE_SCRIPT" "$TEMP_SELF"
  chmod 0755 "$TEMP_SELF"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        [[ $# -ge 2 ]] || fatal "--repo requires a path."
        REPO_ROOT="$2"
        shift 2
        ;;
      --branch)
        [[ $# -ge 2 ]] || fatal "--branch requires a name."
        REMOTE_BRANCH="$2"
        shift 2
        ;;
      --source-url)
        [[ $# -ge 2 ]] || fatal "--source-url requires a URL."
        SOURCE_URL="$2"
        shift 2
        ;;
      --source-file)
        [[ $# -ge 2 ]] || fatal "--source-file requires a path."
        SOURCE_FILE="$2"
        shift 2
        ;;
      --message)
        [[ $# -ge 2 ]] || fatal "--message requires text."
        COMMIT_MESSAGE="$2"
        shift 2
        ;;
      --no-commit)
        COMMIT_CHANGES=false
        PUSH_CHANGES=false
        shift
        ;;
      --no-push)
        PUSH_CHANGES=false
        shift
        ;;
      --no-install-deps)
        INSTALL_DEPS=false
        shift
        ;;
      --open)
        OPEN_PDF=true
        shift
        ;;
      --version)
        printf '%s\n' "$SCRIPT_VERSION"
        exit 0
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fatal "Unknown option: $1"
        ;;
    esac
  done
}

detect_repo_root() {
  if [[ -n "$REPO_ROOT" ]]; then
    REPO_ROOT=$(absolute_path "$REPO_ROOT")
  elif git rev-parse --show-toplevel >/dev/null 2>&1; then
    REPO_ROOT=$(git rev-parse --show-toplevel)
  elif [[ -d "$HOME/Documents/github/$EXPECTED_REPO_NAME/.git" ]]; then
    REPO_ROOT="$HOME/Documents/github/$EXPECTED_REPO_NAME"
  else
    fatal "Could not detect the repository root. Use --repo PATH."
  fi

  [[ -d "$REPO_ROOT/.git" ]] || fatal "Not a Git repository: $REPO_ROOT"

  if [[ "$(basename "$REPO_ROOT")" != "$EXPECTED_REPO_NAME" ]]; then
    warn "Repository directory is named '$(basename "$REPO_ROOT")', not '$EXPECTED_REPO_NAME'."
  fi

  REPO_ROOT=$(cd "$REPO_ROOT" && pwd -P)
}

install_self() {
  local destination="$REPO_ROOT/$SCRIPT_RELATIVE_PATH"
  mkdir -p "$(dirname "$destination")"

  if [[ ! -f "$destination" ]] || ! cmp -s "$TEMP_SELF" "$destination"; then
    cp "$TEMP_SELF" "$destination"
    chmod 0755 "$destination"
    log "Installed script: $SCRIPT_RELATIVE_PATH"
  else
    chmod 0755 "$destination"
    log "Canonical script is already current."
  fi

  bash -n "$destination"
}

prepare_temp_dir() {
  TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tim-fox-resume-pdf.XXXXXX")
}

download_resume() {
  local destination="$1"

  if [[ -n "$SOURCE_FILE" ]]; then
    SOURCE_FILE=$(absolute_path "$SOURCE_FILE")
    [[ -f "$SOURCE_FILE" ]] || fatal "Source Markdown file not found: $SOURCE_FILE"
    cp "$SOURCE_FILE" "$destination"
    log "Using local Markdown source: $SOURCE_FILE"
    return
  fi

  log "Downloading resume from: $SOURCE_URL"

  if command -v gh >/dev/null 2>&1 && gh auth status -h github.com >/dev/null 2>&1; then
    local endpoint
    endpoint="repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/contents/${REMOTE_RESUME_PATH}?ref=${REMOTE_BRANCH}"

    if gh api \
      -H "Accept: application/vnd.github.raw+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$endpoint" > "$destination"; then
      log "Downloaded through authenticated GitHub API."
      return
    fi

    warn "Authenticated GitHub API download failed; attempting raw URL fallback."
  fi

  require_command curl
  local raw_url="https://raw.githubusercontent.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/${REMOTE_BRANCH}/${REMOTE_RESUME_PATH}"

  if ! curl --fail --location --silent --show-error \
    --retry 3 --retry-delay 2 \
    "$raw_url" \
    --output "$destination"; then
    fatal "Could not download the resume. For a private repository, install and authenticate GitHub CLI with: gh auth login"
  fi

  log "Downloaded through raw.githubusercontent.com."
}

validate_markdown() {
  local markdown_file="$1"

  [[ -s "$markdown_file" ]] || fatal "Downloaded Markdown file is empty."

  if grep -Eiq '<!doctype html|<html[ >]' "$markdown_file"; then
    fatal "The download returned HTML instead of Markdown. Check authentication and the source path."
  fi

  grep -Eq '^# +TIM FOX[[:space:]]*$' "$markdown_file" \
    || fatal "Downloaded file does not contain the expected '# TIM FOX' heading."

  grep -Fq 'United States | Open to Remote Roles | timfox2025@tim.army | tim.army' "$markdown_file" \
    || warn "The downloaded resume does not contain the expected contact header."

  log "PASS: Downloaded Markdown content validated."
}

prepare_python_environment() {
  require_command python3

  if python3 -c 'import reportlab, pypdf' >/dev/null 2>&1; then
    PYTHON_CMD="python3"
    log "Using existing Python PDF dependencies."
    return
  fi

  [[ "$INSTALL_DEPS" == true ]] \
    || fatal "Python packages reportlab and pypdf are missing. Rerun without --no-install-deps."

  local cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/tim-fox-resume-pdf"
  local venv_dir="$cache_root/venv"
  mkdir -p "$cache_root"

  if [[ ! -x "$venv_dir/bin/python" ]]; then
    log "Creating isolated Python environment: $venv_dir"
    python3 -m venv "$venv_dir"
  fi

  if ! "$venv_dir/bin/python" -c 'import reportlab, pypdf' >/dev/null 2>&1; then
    log "Installing PDF conversion dependencies into the isolated environment."
    "$venv_dir/bin/python" -m pip install --disable-pip-version-check --quiet \
      'reportlab>=4,<5' 'pypdf>=5,<7'
  fi

  "$venv_dir/bin/python" -c 'import reportlab, pypdf' >/dev/null 2>&1 \
    || fatal "Failed to prepare Python PDF dependencies."

  PYTHON_CMD="$venv_dir/bin/python"
}

write_converter() {
  local converter="$1"

  cat > "$converter" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

from pypdf import PdfReader
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
)


NAVY = colors.HexColor("#17365D")
DARK = colors.HexColor("#222222")
MUTED = colors.HexColor("#555555")
RULE = colors.HexColor("#B8C6D9")


def normalize_text(value: str) -> str:
    replacements = {
        "\u2013": "-",
        "\u2014": "-",
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u00a0": " ",
        "\u2026": "...",
    }
    for old, new in replacements.items():
        value = value.replace(old, new)
    return value.strip()


def inline_markup(value: str) -> str:
    value = normalize_text(value)
    value = html.escape(value, quote=False)

    # Markdown links.
    value = re.sub(
        r"\[([^\]]+)\]\((https?://[^)]+)\)",
        r'<link href="\2" color="#17365D">\1</link>',
        value,
    )

    # Bare email and personal site.
    value = value.replace(
        "timfox2025@tim.army",
        '<link href="mailto:timfox2025@tim.army" color="#17365D">timfox2025@tim.army</link>',
    )
    value = re.sub(
        r"(?<![@\w/])tim\.army(?![\w/])",
        '<link href="https://tim.army" color="#17365D">tim.army</link>',
        value,
    )

    # Inline code, bold, then italics.
    value = re.sub(r"`([^`]+)`", r'<font name="Courier">\1</font>', value)
    value = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", value)
    value = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<i>\1</i>", value)
    return value


def footer(canvas, doc) -> None:
    canvas.saveState()
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.4)
    canvas.line(doc.leftMargin, 0.48 * inch, letter[0] - doc.rightMargin, 0.48 * inch)
    canvas.setFillColor(MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(doc.leftMargin, 0.30 * inch, "Tim Fox - Resume")
    canvas.drawRightString(
        letter[0] - doc.rightMargin,
        0.30 * inch,
        f"Page {doc.page}",
    )
    canvas.restoreState()


def build_pdf(source: Path, destination: Path) -> None:
    styles = getSampleStyleSheet()

    title = ParagraphStyle(
        "ResumeTitle",
        parent=styles["Title"],
        fontName="Helvetica-Bold",
        fontSize=20,
        leading=23,
        textColor=NAVY,
        alignment=TA_CENTER,
        spaceAfter=3,
    )
    subtitle = ParagraphStyle(
        "ResumeSubtitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=10.5,
        leading=13,
        textColor=DARK,
        alignment=TA_CENTER,
        spaceAfter=2,
    )
    contact = ParagraphStyle(
        "ResumeContact",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        leading=11,
        textColor=MUTED,
        alignment=TA_CENTER,
        spaceAfter=10,
    )
    section = ParagraphStyle(
        "ResumeSection",
        parent=styles["Heading2"],
        fontName="Helvetica-Bold",
        fontSize=11.5,
        leading=14,
        textColor=NAVY,
        spaceBefore=9,
        spaceAfter=4,
        borderWidth=0,
        borderPadding=0,
    )
    employer = ParagraphStyle(
        "ResumeEmployer",
        parent=styles["Heading3"],
        fontName="Helvetica-Bold",
        fontSize=10.2,
        leading=12.5,
        textColor=DARK,
        spaceBefore=7,
        spaceAfter=1,
        keepWithNext=True,
    )
    role = ParagraphStyle(
        "ResumeRole",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9.2,
        leading=11.5,
        textColor=DARK,
        spaceAfter=3,
        keepWithNext=True,
    )
    body = ParagraphStyle(
        "ResumeBody",
        parent=styles["BodyText"],
        fontName="Helvetica",
        fontSize=9,
        leading=11.5,
        textColor=DARK,
        alignment=TA_LEFT,
        spaceAfter=4,
    )
    bullet = ParagraphStyle(
        "ResumeBullet",
        parent=body,
        leftIndent=13,
        firstLineIndent=-7,
        bulletIndent=2,
        spaceAfter=2.5,
    )
    note = ParagraphStyle(
        "ResumeNote",
        parent=body,
        fontName="Helvetica-Oblique",
        fontSize=8.7,
        textColor=MUTED,
        spaceBefore=1,
        spaceAfter=4,
    )

    doc = SimpleDocTemplate(
        str(destination),
        pagesize=letter,
        rightMargin=0.55 * inch,
        leftMargin=0.55 * inch,
        topMargin=0.46 * inch,
        bottomMargin=0.62 * inch,
        title="Tim Fox Resume",
        author="Tim Fox",
        subject="Principal Network Engineer and Network Infrastructure Leader",
        creator="Tim-Fox-Resume automated PDF publisher",
        invariant=1,
    )

    lines = source.read_text(encoding="utf-8").splitlines()
    story = []
    paragraph_buffer: list[str] = []
    first_heading_seen = False
    subtitle_seen = False
    contact_seen = False

    def flush_paragraph() -> None:
        nonlocal paragraph_buffer
        if paragraph_buffer:
            text = " ".join(normalize_text(part) for part in paragraph_buffer)
            if text:
                story.append(Paragraph(inline_markup(text), body))
            paragraph_buffer = []

    for raw_line in lines:
        line = raw_line.rstrip()
        stripped = line.strip()

        if not stripped:
            flush_paragraph()
            continue

        if stripped.startswith("```"):
            continue

        if stripped.startswith("# "):
            flush_paragraph()
            story.append(Paragraph(inline_markup(stripped[2:]), title))
            first_heading_seen = True
            continue

        if stripped.startswith("## "):
            flush_paragraph()
            heading = inline_markup(stripped[3:])
            story.append(Spacer(1, 1))
            story.append(Paragraph(heading, section))
            continue

        if stripped.startswith("### "):
            flush_paragraph()
            story.append(Paragraph(inline_markup(stripped[4:]), employer))
            continue

        if stripped.startswith("- "):
            flush_paragraph()
            story.append(
                Paragraph(
                    inline_markup(stripped[2:]),
                    bullet,
                    bulletText="\u2022",
                )
            )
            continue

        if stripped.startswith("*") and stripped.endswith("*") and not stripped.startswith("**"):
            flush_paragraph()
            story.append(Paragraph(inline_markup(stripped), note))
            continue

        if stripped.startswith("**") and stripped.endswith("**"):
            flush_paragraph()
            plain = stripped[2:-2]
            if first_heading_seen and not subtitle_seen:
                story.append(Paragraph(inline_markup(plain), subtitle))
                subtitle_seen = True
            else:
                story.append(Paragraph(inline_markup(stripped), role))
            continue

        if (
            first_heading_seen
            and subtitle_seen
            and not contact_seen
            and "timfox2025@tim.army" in stripped
        ):
            flush_paragraph()
            story.append(Paragraph(inline_markup(stripped), contact))
            contact_seen = True
            continue

        paragraph_buffer.append(stripped)

    flush_paragraph()

    if not story:
        raise RuntimeError("No renderable content was found in the Markdown source.")

    doc.build(story, onFirstPage=footer, onLaterPages=footer)

    reader = PdfReader(str(destination))
    if len(reader.pages) < 1:
        raise RuntimeError("Generated PDF contains no pages.")

    extracted = "\n".join((page.extract_text() or "") for page in reader.pages[:2])
    if "TIM FOX" not in extracted.upper():
        raise RuntimeError("Generated PDF does not contain the expected TIM FOX heading.")

    print(f"pages={len(reader.pages)}")
    print(f"bytes={destination.stat().st_size}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()

    args.destination.parent.mkdir(parents=True, exist_ok=True)
    build_pdf(args.source, args.destination)


if __name__ == "__main__":
    main()
PY

  chmod 0755 "$converter"
}

convert_to_pdf() {
  # PDF_ARCHIVE_HOOK_V1
  "$REPO_ROOT/scripts/bash/archive-current-pdfs.sh" --repo "$REPO_ROOT"
  local markdown_file="$1"
  local output_file="$REPO_ROOT/$OUTPUT_RELATIVE_PATH"
  local temporary_pdf="$TEMP_DIR/Tim-Fox-Expanded-Resume.pdf"
  local converter="$TEMP_DIR/markdown_resume_to_pdf.py"

  mkdir -p "$(dirname "$output_file")"
  write_converter "$converter"

  log "Converting Markdown resume to PDF."
  "$PYTHON_CMD" "$converter" "$markdown_file" "$temporary_pdf"

  [[ -s "$temporary_pdf" ]] || fatal "PDF conversion did not produce a nonempty file."

  if [[ "$(head -c 5 "$temporary_pdf")" != "%PDF-" ]]; then
    fatal "Generated output is not a valid PDF file."
  fi

  mv "$temporary_pdf" "$output_file"
  chmod 0644 "$output_file"
  log "Created: $OUTPUT_RELATIVE_PATH"
}

validate_pdf() {
  local output_file="$REPO_ROOT/$OUTPUT_RELATIVE_PATH"

  "$PYTHON_CMD" - "$output_file" <<'PY'
import sys
from pathlib import Path
from pypdf import PdfReader

path = Path(sys.argv[1])
if not path.exists() or path.stat().st_size < 1024:
    raise SystemExit("PDF is missing or unexpectedly small")

reader = PdfReader(str(path))
if len(reader.pages) < 1:
    raise SystemExit("PDF contains no pages")

text = "\n".join((page.extract_text() or "") for page in reader.pages)
required = ["TIM FOX", "PROFESSIONAL SUMMARY", "PROFESSIONAL EXPERIENCE"]
missing = [item for item in required if item not in text.upper()]
if missing:
    raise SystemExit("PDF is missing expected text: " + ", ".join(missing))

print(f"PASS: PDF validated ({len(reader.pages)} pages, {path.stat().st_size} bytes).")
PY
}

commit_and_push() {
  cd "$REPO_ROOT"

  if [[ "$COMMIT_CHANGES" != true ]]; then
    log "Commit and push disabled."
    return
  fi

  local branch
  branch=$(git branch --show-current)
  [[ -n "$branch" ]] || fatal "Cannot commit from a detached HEAD."

  local -a publish_paths=(
    "$OUTPUT_RELATIVE_PATH"
    "$SCRIPT_RELATIVE_PATH"
    "pdf/zArchive"
    "pdf/zArchive"
    "scripts/bash/archive-current-pdfs.sh"
  )

  git add -- "${publish_paths[@]}"

  if git diff --cached --quiet -- "${publish_paths[@]}"; then
    log "No PDF or script changes require a commit."
  else
    git commit --only -m "$COMMIT_MESSAGE" -- "${publish_paths[@]}"
    log "Committed PDF publication changes."
  fi

  if [[ "$PUSH_CHANGES" == true ]]; then
    git remote get-url origin >/dev/null 2>&1 \
      || fatal "Git remote 'origin' is not configured."
    git push -u origin "$branch"
    log "Pushed branch '$branch' to origin."
  fi
}

remove_downloaded_source() {
  local downloads_dir="$HOME/Downloads"
  local source_parent
  source_parent=$(cd "$(dirname "$SOURCE_SCRIPT")" && pwd -P)

  if [[ "$source_parent" == "$downloads_dir" && "$SOURCE_SCRIPT" != "$REPO_ROOT/$SCRIPT_RELATIVE_PATH" ]]; then
    rm -f "$SOURCE_SCRIPT"
    log "Removed downloaded script after repository installation."
  fi
}

open_generated_pdf() {
  if [[ "$OPEN_PDF" != true ]]; then
    return 0
  fi

  if command -v open >/dev/null 2>&1; then
    open "$REPO_ROOT/$OUTPUT_RELATIVE_PATH"
  else
    warn "The 'open' command is unavailable. PDF location: $REPO_ROOT/$OUTPUT_RELATIVE_PATH"
  fi
}

main() {
  capture_self
  parse_args "$@"
  require_command git
  detect_repo_root
  prepare_temp_dir

  log "Repository root: $REPO_ROOT"
  log "Remote source branch: $REMOTE_BRANCH"

  install_self

  local downloaded_markdown="$TEMP_DIR/Tim-Fox-Resume.md"
  download_resume "$downloaded_markdown"
  validate_markdown "$downloaded_markdown"

  prepare_python_environment
  convert_to_pdf "$downloaded_markdown"
  validate_pdf

  commit_and_push
  remove_downloaded_source
  open_generated_pdf

  printf '\nResume PDF publication completed successfully.\n\n'
  printf '  Source:      %s\n' "$SOURCE_URL"
  printf '  PDF:         %s\n' "$REPO_ROOT/$OUTPUT_RELATIVE_PATH"
  printf '  Script:      %s\n' "$REPO_ROOT/$SCRIPT_RELATIVE_PATH"
  printf '  Git branch:  %s\n' "$(cd "$REPO_ROOT" && git branch --show-current)"
}

main "$@"

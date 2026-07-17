#!/usr/bin/env bash
# Archive current top-level repository PDFs before they are regenerated.

set -Eeuo pipefail
IFS=$'\n\t'

readonly DEFAULT_REPO="$HOME/Documents/github/Tim-Fox-Resume"
REPO_ROOT="$DEFAULT_REPO"

log() {
  printf '[Tim-Fox-Resume PDF Archive] %s\n' "$*" >&2
}

fatal() {
  printf '[Tim-Fox-Resume PDF Archive] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Archive current top-level PDF files.

Usage:
  archive-current-pdfs.sh [--repo PATH]

Backups are stored in pdf/Archive as filename-YYYYMMDD.pdf. When a different
same-day backup already exists, -2, -3, and so on are appended to avoid loss.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || fatal "--repo requires a path."
      REPO_ROOT="$2"
      shift 2
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

if [[ "$REPO_ROOT" == "~/"* ]]; then
  REPO_ROOT="$HOME/${REPO_ROOT#~/}"
fi
[[ "$REPO_ROOT" == /* ]] || REPO_ROOT="$PWD/$REPO_ROOT"
[[ -d "$REPO_ROOT" ]] || fatal "Repository path does not exist: $REPO_ROOT"
REPO_ROOT=$(cd "$REPO_ROOT" && pwd -P)

PDF_DIR="$REPO_ROOT/pdf"
ARCHIVE_DIR="$PDF_DIR/Archive"
ZARCHIVE_DIR="$PDF_DIR/zArchive"
DATE_STAMP=$(date '+%Y%m%d')

mkdir -p "$ARCHIVE_DIR" "$ZARCHIVE_DIR"
: > "$ARCHIVE_DIR/.gitkeep"
: > "$ZARCHIVE_DIR/.gitkeep"

archived=0
skipped=0

while IFS= read -r -d '' source_pdf; do
  filename=$(basename "$source_pdf")
  stem=${filename%.*}
  extension=${filename##*.}
  destination="$ARCHIVE_DIR/${stem}-${DATE_STAMP}.${extension}"

  if [[ -e "$destination" ]]; then
    if cmp -s "$source_pdf" "$destination"; then
      log "Identical dated backup already exists: ${destination#"$REPO_ROOT/"}"
      skipped=$((skipped + 1))
      continue
    fi

    sequence=2
    while [[ -e "$ARCHIVE_DIR/${stem}-${DATE_STAMP}-${sequence}.${extension}" ]]; do
      candidate="$ARCHIVE_DIR/${stem}-${DATE_STAMP}-${sequence}.${extension}"
      if cmp -s "$source_pdf" "$candidate"; then
        log "Identical dated backup already exists: ${candidate#"$REPO_ROOT/"}"
        skipped=$((skipped + 1))
        continue 2
      fi
      sequence=$((sequence + 1))
    done
    destination="$ARCHIVE_DIR/${stem}-${DATE_STAMP}-${sequence}.${extension}"
  fi

  cp -p "$source_pdf" "$destination"
  log "Archived: ${source_pdf#"$REPO_ROOT/"} -> ${destination#"$REPO_ROOT/"}"
  archived=$((archived + 1))
done < <(
  find "$PDF_DIR" -maxdepth 1 -type f -iname '*.pdf' -print0 2>/dev/null
)

log "Archive complete: archived=$archived, already-current=$skipped."

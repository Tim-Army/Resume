#!/usr/bin/env bash
#
# Configure durable PDF backups for the Tim-Fox-Resume repository.
#
# Creates:
#   pdf/zArchive
#   pdf/zArchive
#   scripts/bash/archive-current-pdfs.sh
#
# Before a PDF generator overwrites any top-level pdf/*.pdf file, the helper
# copies the current file to pdf/zArchive with -YYYYMMDD appended. If another
# different backup already exists for that date, a numeric suffix is added.
#

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2026.07.17.1"
readonly SCRIPT_NAME="configure-pdf-archive-and-push.sh"
readonly HELPER_NAME="archive-current-pdfs.sh"
readonly DEFAULT_REPO="$HOME/Documents/github/Tim-Fox-Resume"
readonly SCRIPTS_REL="scripts/bash"
readonly SELF_REL="$SCRIPTS_REL/$SCRIPT_NAME"
readonly HELPER_REL="$SCRIPTS_REL/$HELPER_NAME"
readonly PDF_REL="pdf"
readonly ARCHIVE_REL="pdf/zArchive"
readonly ZARCHIVE_REL="pdf/zArchive"

REPO_ROOT="$DEFAULT_REPO"
COMMIT_CHANGES=true
PUSH_CHANGES=true
COMMIT_MESSAGE="chore: add automatic dated PDF archives"
SOURCE_SCRIPT=""
TEMP_SELF=""

log() {
  printf '[Tim-Fox-Resume] %s\n' "$*" >&2
}

warn() {
  printf '[Tim-Fox-Resume] WARNING: %s\n' "$*" >&2
}

fatal() {
  printf '[Tim-Fox-Resume] ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  [[ -n "$TEMP_SELF" && -f "$TEMP_SELF" ]] && rm -f "$TEMP_SELF"
  return 0
}
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Configure automatic dated PDF backups for Tim-Fox-Resume.

Usage:
  configure-pdf-archive-and-push.sh [options]

Options:
  --repo PATH       Repository root.
                    Default: ~/Documents/github/Tim-Fox-Resume
  --no-commit       Update files without creating a Git commit.
  --no-push         Commit locally without pushing.
  --message TEXT    Git commit message.
  --version         Display the script version.
  -h, --help        Display this help text.

Behavior:
  - Creates pdf/zArchive and pdf/zArchive.
  - Archives each current top-level pdf/*.pdf file to pdf/zArchive.
  - Uses filename-YYYYMMDD.pdf for the first backup of the day.
  - Uses filename-YYYYMMDD-2.pdf, -3.pdf, etc. only when needed to avoid
    overwriting a different same-day backup.
  - Installs scripts/bash/archive-current-pdfs.sh.
  - Regenerates current PDF-producing scripts so they archive before writing.
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
  TEMP_SELF=$(mktemp "${TMPDIR:-/tmp}/configure-pdf-archive.XXXXXX")
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
      --no-commit)
        COMMIT_CHANGES=false
        PUSH_CHANGES=false
        shift
        ;;
      --no-push)
        PUSH_CHANGES=false
        shift
        ;;
      --message)
        [[ $# -ge 2 ]] || fatal "--message requires text."
        COMMIT_MESSAGE="$2"
        shift 2
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

resolve_repository() {
  REPO_ROOT=$(absolute_path "$REPO_ROOT")
  [[ -d "$REPO_ROOT/.git" ]] || fatal "Not a Git repository: $REPO_ROOT"

  local top
  top=$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null) \
    || fatal "Unable to determine repository root."
  REPO_ROOT=$(cd "$top" && pwd -P)
}

install_self() {
  local destination="$REPO_ROOT/$SELF_REL"
  mkdir -p "$(dirname "$destination")"
  cp "$TEMP_SELF" "$destination"
  chmod 0755 "$destination"
  bash -n "$destination" || fatal "Installed configuration script failed Bash validation."
  log "Installed canonical configuration script: $SELF_REL"
}

create_archive_directories() {
  mkdir -p "$REPO_ROOT/$ARCHIVE_REL" "$REPO_ROOT/$ZARCHIVE_REL"
  : > "$REPO_ROOT/$ARCHIVE_REL/.gitkeep"
  : > "$REPO_ROOT/$ZARCHIVE_REL/.gitkeep"
  log "Ensured archive directories: $ARCHIVE_REL and $ZARCHIVE_REL"
}

write_archive_helper() {
  local helper="$REPO_ROOT/$HELPER_REL"

  cat > "$helper" <<'HELPER'
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

Backups are stored in pdf/zArchive as filename-YYYYMMDD.pdf. When a different
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
HELPER

  chmod 0755 "$helper"
  bash -n "$helper" || fatal "Archive helper failed Bash validation."
  log "Generated archive helper: $HELPER_REL"
}

archive_current_pdfs_now() {
  "$REPO_ROOT/$HELPER_REL" --repo "$REPO_ROOT"
}

patch_pdf_generators() {
  python3 - "$REPO_ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
scripts = root / "scripts" / "bash"
helper_call = '  "$REPO_ROOT/scripts/bash/archive-current-pdfs.sh" --repo "$REPO_ROOT"\n'
marker = "# PDF_ARCHIVE_HOOK_V1"

# Independent scripts that directly write a PDF. Other project scripts invoke
# the condensed generator and therefore inherit its archive behavior.
target_functions = {
    "condense-resume-to-three-pages-and-push.sh": "generate_pdf",
    "download-resume-to-pdf-and-push.sh": "convert_to_pdf",
}

for filename, function_name in target_functions.items():
    path = scripts / filename
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8")
    if marker not in text:
        pattern = rf"(?m)^({re.escape(function_name)}\(\) \{{\n)"
        replacement = rf"\1  {marker}\n" + helper_call
        text, count = re.subn(pattern, replacement, text, count=1)
        if count != 1:
            raise SystemExit(f"Unable to add PDF archive hook to {filename}.")

    if filename == "condense-resume-to-three-pages-and-push.sh":
        old = 'git -C "$REPO_ROOT" add -- "$MASTER_REL" "$PDF_REL" "$SCRIPT_REL"'
        new = (
            'git -C "$REPO_ROOT" add -- "$MASTER_REL" "$PDF_REL" "$SCRIPT_REL" '
            '"pdf/zArchive" "pdf/zArchive" "scripts/bash/archive-current-pdfs.sh"'
        )
        if new not in text:
            if old not in text:
                raise SystemExit("Unable to update condensed PDF staging paths.")
            text = text.replace(old, new, 1)

    if filename == "download-resume-to-pdf-and-push.sh":
        if 'local -a publish_paths=(' not in text:
            old_block = '''  git add -- "$OUTPUT_RELATIVE_PATH" "$SCRIPT_RELATIVE_PATH"

  if git diff --cached --quiet -- "$OUTPUT_RELATIVE_PATH" "$SCRIPT_RELATIVE_PATH"; then
    log "No PDF or script changes require a commit."
  else
    git commit --only -m "$COMMIT_MESSAGE" -- \\
      "$OUTPUT_RELATIVE_PATH" "$SCRIPT_RELATIVE_PATH"
    log "Committed PDF publication changes."
  fi'''
            new_block = '''  local -a publish_paths=(
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
  fi'''
            if old_block not in text:
                raise SystemExit("Unable to update download PDF staging block.")
            text = text.replace(old_block, new_block, 1)

    path.write_text(text, encoding="utf-8")

# Ensure the standardization workflow stages newly created archive files.
standardizer = scripts / "standardize-resume-project-and-push.sh"
if standardizer.exists():
    text = standardizer.read_text(encoding="utf-8")
    anchor = '  "$PDF_REL"\n)'
    replacement = '  "$PDF_REL"\n  "$ARCHIVE_REL"\n  "$ZARCHIVE_REL"\n)'
    if 'readonly ARCHIVE_REL="pdf/zArchive"' not in text:
        text = text.replace(
            'readonly PDF_REL="pdf/Tim-Fox-Expanded-Resume.pdf"\n',
            'readonly PDF_REL="pdf/Tim-Fox-Expanded-Resume.pdf"\n'
            'readonly ARCHIVE_REL="pdf/zArchive"\n'
            'readonly ZARCHIVE_REL="pdf/zArchive"\n',
            1,
        )
    if '  "$ARCHIVE_REL"\n' not in text:
        if anchor not in text:
            raise SystemExit("Unable to update standardizer archive staging paths.")
        text = text.replace(anchor, replacement, 1)
    standardizer.write_text(text, encoding="utf-8")
PY

  local failed=0
  local script
  for script in \
    "$REPO_ROOT/$SCRIPTS_REL/condense-resume-to-three-pages-and-push.sh" \
    "$REPO_ROOT/$SCRIPTS_REL/download-resume-to-pdf-and-push.sh" \
    "$REPO_ROOT/$SCRIPTS_REL/standardize-resume-project-and-push.sh"; do
    [[ -f "$script" ]] || continue
    if bash -n "$script"; then
      log "PASS: Bash syntax: ${script#"$REPO_ROOT/"}"
    else
      warn "FAIL: Bash syntax: ${script#"$REPO_ROOT/"}"
      failed=1
    fi
  done
  [[ "$failed" -eq 0 ]] || fatal "A regenerated PDF workflow script failed Bash validation."

  log "Regenerated PDF-producing scripts with automatic archive hooks."
}

validate_configuration() {
  [[ -d "$REPO_ROOT/$ARCHIVE_REL" ]] || fatal "Missing directory: $ARCHIVE_REL"
  [[ -d "$REPO_ROOT/$ZARCHIVE_REL" ]] || fatal "Missing directory: $ZARCHIVE_REL"
  [[ -x "$REPO_ROOT/$HELPER_REL" ]] || fatal "Missing executable helper: $HELPER_REL"

  local generator
  for generator in \
    "$REPO_ROOT/$SCRIPTS_REL/condense-resume-to-three-pages-and-push.sh" \
    "$REPO_ROOT/$SCRIPTS_REL/download-resume-to-pdf-and-push.sh"; do
    [[ -f "$generator" ]] || continue
    grep -Fq '# PDF_ARCHIVE_HOOK_V1' "$generator" \
      || fatal "PDF archive hook is missing from ${generator#"$REPO_ROOT/"}."
  done

  log "PASS: PDF archive directories, helper, and generator hooks validated."
}

commit_and_push() {
  if [[ "$COMMIT_CHANGES" != true ]]; then
    log "Files updated without a Git commit (--no-commit)."
    return 0
  fi

  local -a paths=(
    "$ARCHIVE_REL"
    "$ZARCHIVE_REL"
    "$HELPER_REL"
    "$SELF_REL"
    "$SCRIPTS_REL/condense-resume-to-three-pages-and-push.sh"
    "$SCRIPTS_REL/download-resume-to-pdf-and-push.sh"
    "$SCRIPTS_REL/standardize-resume-project-and-push.sh"
  )

  git -C "$REPO_ROOT" add -A -- "${paths[@]}"

  if git -C "$REPO_ROOT" diff --cached --quiet -- "${paths[@]}"; then
    log "No PDF archive configuration changes require a commit."
  else
    git -C "$REPO_ROOT" commit --only -m "$COMMIT_MESSAGE" -- "${paths[@]}"
    log "Created Git commit: $COMMIT_MESSAGE"
  fi

  if [[ "$PUSH_CHANGES" == true ]]; then
    local branch
    branch=$(git -C "$REPO_ROOT" branch --show-current)
    [[ -n "$branch" ]] || fatal "Cannot push from a detached HEAD."
    git -C "$REPO_ROOT" remote get-url origin >/dev/null 2>&1 \
      || fatal "Git remote 'origin' is not configured."
    git -C "$REPO_ROOT" push -u origin "$branch"
    log "Pushed branch '$branch' to origin."
  else
    log "Push skipped (--no-push)."
  fi
}

remove_downloaded_source() {
  local downloads_dir="$HOME/Downloads"
  local source_parent
  source_parent=$(cd "$(dirname "$SOURCE_SCRIPT")" && pwd -P)

  if [[ "$source_parent" == "$downloads_dir" && "$SOURCE_SCRIPT" != "$REPO_ROOT/$SELF_REL" ]]; then
    rm -f "$SOURCE_SCRIPT"
    log "Removed downloaded script after canonical installation."
  fi
}

main() {
  require_command git
  require_command python3
  require_command find
  require_command cmp

  capture_self
  parse_args "$@"
  resolve_repository

  log "Repository root: $REPO_ROOT"
  install_self
  create_archive_directories
  write_archive_helper
  archive_current_pdfs_now
  patch_pdf_generators
  validate_configuration
  commit_and_push
  remove_downloaded_source

  log "Complete. Future PDF generation will archive current top-level PDFs first."
  log "Backup directory: $REPO_ROOT/$ARCHIVE_REL"
  log "Additional directory: $REPO_ROOT/$ZARCHIVE_REL"
}

main "$@"

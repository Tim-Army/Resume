#!/usr/bin/env bash
#
# Restore the DoD workforce qualification alignment statement to the condensed
# Tim Fox resume, regenerate the three-page PDF, commit the affected files,
# and push the current branch to GitHub.
#
# Default repository:
#   $HOME/Documents/github/Tim-Fox-Resume
#

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2026.07.17.1"
readonly SCRIPT_NAME="add-dod-workforce-alignment-and-push.sh"
readonly DEFAULT_REPO="$HOME/Documents/github/Tim-Fox-Resume"
readonly MASTER_REL="resume/master/Tim-Fox-Resume.md"
readonly PDF_REL="pdf/Tim-Fox-Expanded-Resume.pdf"
readonly CONDENSE_REL="scripts/bash/condense-resume-to-three-pages-and-push.sh"
readonly SCRIPT_REL="scripts/bash/$SCRIPT_NAME"
readonly ALIGNMENT="- **DoD Workforce Qualification Alignment:** DoD 8570 IAT II and IAT III; DoD 8140-aligned qualifications."

REPO_ROOT="$DEFAULT_REPO"
COMMIT_CHANGES=true
PUSH_CHANGES=true
OPEN_PDF=false
COMMIT_MESSAGE="docs: restore DoD workforce qualification alignment"
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
Restore the DoD workforce qualification alignment statement and publish it.

Usage:
  add-dod-workforce-alignment-and-push.sh [options]

Options:
  --repo PATH       Tim-Fox-Resume repository root.
                    Default: ~/Documents/github/Tim-Fox-Resume
  --no-commit       Update the files without creating a Git commit.
  --no-push         Commit locally without pushing to GitHub.
  --message TEXT    Git commit message.
  --open            Open the regenerated PDF on macOS.
  --version         Display the script version.
  -h, --help        Display this help text.

Files created or updated:
  resume/master/Tim-Fox-Resume.md
  pdf/Tim-Fox-Expanded-Resume.pdf
  scripts/bash/condense-resume-to-three-pages-and-push.sh
  scripts/bash/add-dod-workforce-alignment-and-push.sh

The statement is inserted beneath the certification groups as a bold,
certification-style bullet.
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
  [[ -d "$parent" ]] || mkdir -p "$parent"
  parent=$(cd "$parent" && pwd -P)
  printf '%s/%s\n' "$parent" "$base"
}

capture_self() {
  SOURCE_SCRIPT=$(absolute_path "${BASH_SOURCE[0]}")
  TEMP_SELF=$(mktemp "${TMPDIR:-/tmp}/dod-workforce-alignment.XXXXXX")
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

validate_repo() {
  REPO_ROOT=$(absolute_path "$REPO_ROOT")
  [[ -d "$REPO_ROOT/.git" ]] || fatal "Not a Git repository: $REPO_ROOT"

  local top
  top=$(git -C "$REPO_ROOT" rev-parse --show-toplevel)
  REPO_ROOT=$(cd "$top" && pwd -P)

  [[ -f "$REPO_ROOT/$CONDENSE_REL" ]] \
    || fatal "Required three-page generator is missing: $CONDENSE_REL"
}

install_script() {
  local destination="$REPO_ROOT/$SCRIPT_REL"
  mkdir -p "$(dirname "$destination")"

  if [[ ! -f "$destination" ]] || ! cmp -s "$TEMP_SELF" "$destination"; then
    cp "$TEMP_SELF" "$destination"
    chmod 0755 "$destination"
    log "Installed repository script: $SCRIPT_REL"
  else
    chmod 0755 "$destination"
    log "Repository script is already current."
  fi
}

patch_generator() {
  local generator="$REPO_ROOT/$CONDENSE_REL"

  python3 - "$generator" "$ALIGNMENT" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
alignment = sys.argv[2]
text = path.read_text(encoding="utf-8")

if alignment not in text:
    anchor = (
        "- **Cloud, Virtualization, and Data Center:** AWS Certified Cloud Practitioner; "
        "Dell VxRail Deploy Version 2; VMware VCA-DCV.\n"
    )
    if anchor not in text:
        raise SystemExit(
            "Unable to find the certifications anchor in the three-page generator."
        )
    text = text.replace(anchor, anchor + "\n" + alignment + "\n", 1)

cleanup_old = """cleanup() {
  [[ -n "$TEMP_SELF" && -f "$TEMP_SELF" ]] && rm -f "$TEMP_SELF"
  [[ -n "$VENV_DIR" && -d "$VENV_DIR" ]] && rm -rf "$VENV_DIR"
}"""
cleanup_new = """cleanup() {
  [[ -n "$TEMP_SELF" && -f "$TEMP_SELF" ]] && rm -f "$TEMP_SELF"
  [[ -n "$VENV_DIR" && -d "$VENV_DIR" ]] && rm -rf "$VENV_DIR"
  return 0
}"""
if cleanup_old in text:
    text = text.replace(cleanup_old, cleanup_new, 1)

path.write_text(text, encoding="utf-8")

count = text.count(alignment)
if count != 1:
    raise SystemExit(
        f"Expected the qualification statement once in the generator; found {count}."
    )
PY

  chmod 0755 "$generator"
  bash -n "$generator" || fatal "Bash syntax validation failed for $CONDENSE_REL."
  log "Updated the three-page resume generator."
}

regenerate_resume_and_pdf() {
  "$REPO_ROOT/$CONDENSE_REL" \
    --repo "$REPO_ROOT" \
    --no-commit

  log "Regenerated the Markdown resume and three-page PDF."
}

validate_output() {
  local master="$REPO_ROOT/$MASTER_REL"
  local pdf="$REPO_ROOT/$PDF_REL"
  local generator="$REPO_ROOT/$CONDENSE_REL"
  local installed="$REPO_ROOT/$SCRIPT_REL"

  [[ -s "$master" ]] || fatal "Master resume is missing: $MASTER_REL"
  [[ -s "$pdf" ]] || fatal "PDF resume is missing: $PDF_REL"
  [[ -x "$generator" ]] || fatal "Generator is not executable: $CONDENSE_REL"
  [[ -x "$installed" ]] || fatal "Update script is not executable: $SCRIPT_REL"

  local master_count generator_count
  master_count=$(grep -Fxc "$ALIGNMENT" "$master" || true)
  generator_count=$(grep -Fxc "$ALIGNMENT" "$generator" || true)

  [[ "$master_count" -eq 1 ]] \
    || fatal "Expected the qualification statement once in $MASTER_REL; found $master_count."
  [[ "$generator_count" -eq 1 ]] \
    || fatal "Expected the qualification statement once in $CONDENSE_REL; found $generator_count."

  bash -n "$generator" || fatal "Bash syntax validation failed for $CONDENSE_REL."
  bash -n "$installed" || fatal "Bash syntax validation failed for $SCRIPT_REL."

  log "PASS: qualification statement, PDF, and Bash syntax validation."
}

commit_and_push() {
  if [[ "$COMMIT_CHANGES" != true ]]; then
    log "Files updated without a Git commit (--no-commit)."
    return
  fi

  git -C "$REPO_ROOT" add -- \
    "$MASTER_REL" \
    "$PDF_REL" \
    "$CONDENSE_REL" \
    "$SCRIPT_REL"

  if git -C "$REPO_ROOT" diff --cached --quiet; then
    log "No qualification-alignment changes to commit."
  else
    git -C "$REPO_ROOT" commit -m "$COMMIT_MESSAGE"
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

open_pdf() {
  [[ "$OPEN_PDF" == true ]] || return 0

  if command -v open >/dev/null 2>&1; then
    open "$REPO_ROOT/$PDF_REL"
  else
    warn "The 'open' command is unavailable. PDF: $REPO_ROOT/$PDF_REL"
  fi
}

remove_download_copy() {
  local installed="$REPO_ROOT/$SCRIPT_REL"

  if [[ "$SOURCE_SCRIPT" != "$installed" && "$SOURCE_SCRIPT" == "$HOME/Downloads/"* ]]; then
    rm -f "$SOURCE_SCRIPT"
    log "Removed downloaded copy after repository installation."
  fi
}

main() {
  require_command git
  require_command cmp
  require_command grep
  require_command python3

  capture_self
  parse_args "$@"
  validate_repo

  log "Repository root: $REPO_ROOT"
  install_script
  patch_generator
  regenerate_resume_and_pdf
  validate_output
  commit_and_push
  open_pdf
  remove_download_copy

  log "Complete."
  log "Master resume: $REPO_ROOT/$MASTER_REL"
  log "PDF resume:    $REPO_ROOT/$PDF_REL"
}

main "$@"

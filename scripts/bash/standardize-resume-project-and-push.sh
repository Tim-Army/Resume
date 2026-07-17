#!/usr/bin/env bash
#
# Standardize the Tim-Fox-Resume project workflow:
#   1. Store every resume-project shell script in scripts/bash.
#   2. Migrate scripts from Downloads, the historical misspelled project path,
#      and noncanonical locations inside the repository.
#   3. Regenerate the condensed-resume builder without forced page breaks.
#   4. Rebuild the Markdown and PDF resumes using natural pagination.
#   5. Commit and push only the affected resume and script paths.
#
# Canonical repository:
#   $HOME/Documents/github/Tim-Fox-Resume
#
# Historical misspelling handled automatically:
#   $HOME/Documents/github/Tim-Fox-Resue

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2026.07.17.2"
readonly SCRIPT_NAME="standardize-resume-project-and-push.sh"
readonly DEFAULT_REPO="$HOME/Documents/github/Tim-Fox-Resume"
readonly TYPO_REPO="$HOME/Documents/github/Tim-Fox-Resue"
readonly SCRIPTS_REL="scripts/bash"
readonly GENERATOR_REL="$SCRIPTS_REL/condense-resume-to-three-pages-and-push.sh"
readonly MASTER_REL="resume/master/Tim-Fox-Resume.md"
readonly PDF_REL="pdf/Tim-Fox-Resume.pdf"
readonly ARCHIVE_REL="pdf/Archive"
readonly ZARCHIVE_REL="pdf/zArchive"
readonly SCRIPT_REL="$SCRIPTS_REL/$SCRIPT_NAME"

REPO_ROOT="$DEFAULT_REPO"
COMMIT_CHANGES=true
PUSH_CHANGES=true
OPEN_PDF=false
COMMIT_MESSAGE="chore: standardize resume scripts and natural pagination"
SOURCE_SCRIPT=""
TEMP_SELF=""
MOVED_COUNT=0
DEDUP_COUNT=0
RENAMED_COUNT=0

declare -a STAGE_PATHS=(
  "$SCRIPTS_REL"
  "$MASTER_REL"
  "$PDF_REL"
  "$ARCHIVE_REL"
  "$ZARCHIVE_REL"
)

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
Standardize Tim-Fox-Resume scripts and remove forced PDF page breaks.

Usage:
  standardize-resume-project-and-push.sh [options]

Options:
  --repo PATH       Repository root.
                    Default: ~/Documents/github/Tim-Fox-Resume
  --no-commit       Update files without creating a Git commit.
  --no-push         Commit locally without pushing.
  --message TEXT    Git commit message.
  --open            Open the regenerated PDF on macOS.
  --version         Display the script version.
  -h, --help        Display this help text.

Migration sources:
  ~/Downloads/*.sh and ~/Downloads/*.bash
  ~/Documents/github/Tim-Fox-Resue/**
  Shell scripts inside the repository but outside scripts/bash

Canonical destination:
  ~/Documents/github/Tim-Fox-Resume/scripts/bash

Pagination behavior:
  Removes explicit <!-- PAGE BREAK --> markers and lets the PDF renderer flow
  content naturally. The condensed PDF must remain two or three pages.
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
  TEMP_SELF=$(mktemp "${TMPDIR:-/tmp}/standardize-resume-project.XXXXXX")
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

  [[ "$(basename "$REPO_ROOT")" == "Tim-Fox-Resume" ]] \
    || warn "Expected repository directory Tim-Fox-Resume; found $(basename "$REPO_ROOT")."
}

is_inside_repo() {
  local path="$1"
  [[ "$path" == "$REPO_ROOT" || "$path" == "$REPO_ROOT/"* ]]
}

record_stage_source() {
  local source="$1"
  if is_inside_repo "$source"; then
    local relative="${source#"$REPO_ROOT"/}"
    STAGE_PATHS+=("$relative")
  fi
}

unique_destination() {
  local destination="$1"
  local stem extension timestamp candidate counter=1

  timestamp=$(date '+%Y%m%d-%H%M%S')
  extension=""
  stem="$destination"

  if [[ "$destination" == *.* ]]; then
    extension=".${destination##*.}"
    stem="${destination%.*}"
  fi

  candidate="${stem}-${timestamp}${extension}"
  while [[ -e "$candidate" ]]; do
    candidate="${stem}-${timestamp}-${counter}${extension}"
    ((counter += 1))
  done

  printf '%s\n' "$candidate"
}

move_script_file() {
  local source="$1"
  local canonical_dir="$REPO_ROOT/$SCRIPTS_REL"
  local source_abs destination final_destination

  [[ -f "$source" ]] || return 0
  source_abs=$(cd "$(dirname "$source")" && pwd -P)/$(basename "$source")

  if [[ "$source_abs" == "$canonical_dir/"* ]]; then
    chmod 0755 "$source_abs" || true
    return 0
  fi

  destination="$canonical_dir/$(basename "$source_abs")"
  record_stage_source "$source_abs"

  if [[ ! -e "$destination" ]]; then
    mv "$source_abs" "$destination"
    chmod 0755 "$destination"
    ((MOVED_COUNT += 1))
    log "Moved script: $source_abs -> $destination"
    return 0
  fi

  if cmp -s "$source_abs" "$destination"; then
    rm -f "$source_abs"
    chmod 0755 "$destination"
    ((DEDUP_COUNT += 1))
    log "Removed duplicate script: $source_abs"
    return 0
  fi

  # Do not preserve a malformed conflict when a valid canonical script exists.
  # This prevents stale broken downloads from entering scripts/bash and blocking
  # repository-wide Bash validation.
  if ! bash -n "$source_abs" >/dev/null 2>&1 \
      && bash -n "$destination" >/dev/null 2>&1; then
    rm -f "$source_abs"
    chmod 0755 "$destination"
    ((DEDUP_COUNT += 1))
    warn "Removed invalid conflicting script; valid canonical copy retained: $source_abs"
    return 0
  fi

  final_destination=$(unique_destination "$destination")
  mv "$source_abs" "$final_destination"
  chmod 0755 "$final_destination"
  ((RENAMED_COUNT += 1))
  log "Preserved conflicting script as: $final_destination"
}

install_self() {
  local destination="$REPO_ROOT/$SCRIPT_REL"
  mkdir -p "$(dirname "$destination")"

  if [[ ! -f "$destination" ]] || ! cmp -s "$TEMP_SELF" "$destination"; then
    cp "$TEMP_SELF" "$destination"
    chmod 0755 "$destination"
    log "Installed canonical maintenance script: $SCRIPT_REL"
  else
    chmod 0755 "$destination"
    log "Canonical maintenance script is already current."
  fi
}

migrate_download_scripts() {
  local downloads="$HOME/Downloads"
  [[ -d "$downloads" ]] || return 0

  while IFS= read -r -d '' script; do
    move_script_file "$script"
  done < <(
    find "$downloads" -maxdepth 1 -type f \
      \( -name '*.sh' -o -name '*.bash' \) -print0
  )
}

migrate_typo_repository_scripts() {
  [[ -d "$TYPO_REPO" ]] || return 0

  while IFS= read -r -d '' script; do
    move_script_file "$script"
  done < <(
    find "$TYPO_REPO" -type f \
      \( -name '*.sh' -o -name '*.bash' \) \
      ! -path '*/.git/*' -print0
  )
}

migrate_noncanonical_repo_scripts() {
  local canonical_dir="$REPO_ROOT/$SCRIPTS_REL"

  while IFS= read -r -d '' script; do
    move_script_file "$script"
  done < <(
    find "$REPO_ROOT" -type f \
      \( -name '*.sh' -o -name '*.bash' \) \
      ! -path "$REPO_ROOT/.git/*" \
      ! -path "$canonical_dir/*" -print0
  )
}

migrate_all_scripts() {
  mkdir -p "$REPO_ROOT/$SCRIPTS_REL"

  migrate_download_scripts
  migrate_typo_repository_scripts
  migrate_noncanonical_repo_scripts

  log "Script migration summary: moved=$MOVED_COUNT, duplicates=$DEDUP_COUNT, conflicts-preserved=$RENAMED_COUNT."
}

patch_condensed_resume_generator() {
  local generator="$REPO_ROOT/$GENERATOR_REL"
  [[ -f "$generator" ]] || fatal "Missing condensed resume generator: $GENERATOR_REL"

  python3 - "$generator" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

# Remove explicit Markdown page-break markers from the generated resume.
text = re.sub(r"(?m)^\s*<!-- PAGE BREAK -->\s*\n?", "", text)

# Preserve the approved DoD workforce alignment as a bold certification-style bullet.
dod_bullet = (
    "- **DoD Workforce Qualification Alignment:** "
    "DoD 8570 IAT II and IAT III; DoD 8140-aligned qualifications."
)
text = re.sub(
    r"(?m)^\s*-?\s*\*{0,2}DoD Workforce Qualification Alignment:\*{0,2}\s*"
    r"DoD 8570 IAT II and IAT III; DoD 8140-aligned qualifications\.\s*$",
    "",
    text,
)
text = re.sub(r"\n{3,}", "\n\n", text)
cert_anchor = (
    "- **Cloud, Virtualization, and Data Center:** AWS Certified Cloud Practitioner; "
    "Dell VxRail Deploy Version 2; VMware VCA-DCV.\n"
)
if dod_bullet not in text:
    if cert_anchor not in text:
        raise SystemExit("Unable to find the certification anchor for the DoD alignment bullet.")
    text = text.replace(cert_anchor, cert_anchor + dod_bullet + "\n", 1)


# Ensure a successful generator run exits with status 0 even when optional
# temporary paths are already absent during the EXIT trap.
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


# Remove the ReportLab PageBreak import and marker handler.
text = re.sub(r"(?m)^\s*PageBreak,\s*\n", "", text)
text = re.sub(
    r'''(?m)^\s*if line == ["']<!-- PAGE BREAK -->["']:\s*\n\s*story\.append\(PageBreak\(\)\)\s*\n\s*continue\s*\n''',
    "",
    text,
)

# Natural pagination normally produces two pages; retain a three-page upper limit.
text = re.sub(
    r'''if len\(reader\.pages\) != 3:\n\s*raise SystemExit\(f"Expected exactly 3 PDF pages, generated \{len\(reader\.pages\)\}\."\)''',
    '''page_count = len(reader.pages)\nif page_count not in (2, 3):\n    raise SystemExit(f"Expected a naturally paginated 2- or 3-page PDF, generated {page_count}.")''',
    text,
)

# Replace the old explicit-break validation with a zero-marker validation.
text = re.sub(
    r'''\n\s*local breaks\n\s*breaks=\$\(grep -c '\^<!-- PAGE BREAK -->\$' "\$master" \|\| true\)\n\s*\[\[ "\$breaks" -eq 2 \]\] \\\n\s*\|\| fatal "Expected two explicit page breaks in the three-page Markdown resume; found \$breaks\."\n''',
    '''\n  if grep -Eq '^[[:space:]]*<!-- PAGE BREAK -->[[:space:]]*$' "$master"; then\n    fatal "Forced page-break markers remain in the Markdown resume."\n  fi\n  if grep -Eq '^[[:space:]]*<!-- PAGE BREAK -->[[:space:]]*$' "$installed"; then\n    fatal "Forced page-break markers remain in the resume generator."\n  fi\n''',
    text,
)

# Handle already-modified or slightly different validation blocks.
text = re.sub(
    r'''(?ms)\n\s*local breaks\n\s*breaks=.*?\n\s*\[\[ "\$breaks" -eq 2 \]\].*?\n\s*\|\| fatal ".*?"\n''',
    '''\n  if grep -Eq '^[[:space:]]*<!-- PAGE BREAK -->[[:space:]]*$' "$master"; then\n    fatal "Forced page-break markers remain in the Markdown resume."\n  fi\n  if grep -Eq '^[[:space:]]*<!-- PAGE BREAK -->[[:space:]]*$' "$installed"; then\n    fatal "Forced page-break markers remain in the resume generator."\n  fi\n''',
    text,
)

text = text.replace(
    'log "Generated three-page PDF: $PDF_REL"',
    'log "Generated naturally paginated PDF: $PDF_REL"',
)
text = text.replace(
    'log "PASS: header, page structure, PDF, and Bash syntax validation."',
    'log "PASS: header, natural page flow, PDF, and Bash syntax validation."',
)

# Clarify behavior in help/comments while retaining the historical filename.
text = text.replace(
    "Create and publish Tim Fox's condensed three-page resume.",
    "Create and publish Tim Fox's condensed resume with natural pagination.",
)
text = text.replace(
    "Replace the Tim-Fox-Resume master resume with a concise three-page version,",
    "Replace the Tim-Fox-Resume master resume with a concise naturally paginated version,",
)

if re.search(r"(?m)^\s*<!-- PAGE BREAK -->\s*$", text):
    raise SystemExit("Unable to remove every standalone forced page-break marker from the generator.")
if "story.append(PageBreak())" in text:
    raise SystemExit("Unable to remove the ReportLab PageBreak handler.")
if "Expected exactly 3 PDF pages" in text:
    raise SystemExit("Unable to update the strict three-page PDF validation.")

path.write_text(text, encoding="utf-8")
PY

  chmod 0755 "$generator"
  bash -n "$generator" || fatal "Bash syntax validation failed after regenerating $GENERATOR_REL."
  log "Regenerated the condensed resume builder with natural pagination."
}

regenerate_resume_files() {
  local generator="$REPO_ROOT/$GENERATOR_REL"

  "$generator" --repo "$REPO_ROOT" --no-commit

  [[ -s "$REPO_ROOT/$MASTER_REL" ]] || fatal "Master resume was not regenerated."
  [[ -s "$REPO_ROOT/$PDF_REL" ]] || fatal "PDF resume was not regenerated."

  if grep -Eq '^[[:space:]]*<!-- PAGE BREAK -->[[:space:]]*$' "$REPO_ROOT/$MASTER_REL"; then
    fatal "Forced page-break markers remain in the regenerated Markdown resume."
  fi
  if grep -Eq '^[[:space:]]*<!-- PAGE BREAK -->[[:space:]]*$' "$REPO_ROOT/$GENERATOR_REL"; then
    fatal "Forced page-break markers remain in the regenerated resume generator."
  fi

  log "Regenerated the Markdown and PDF resumes without forced page breaks."
}

validate_all_canonical_scripts() {
  local failed=0

  while IFS= read -r -d '' script; do
    if bash -n "$script"; then
      log "PASS: Bash syntax: ${script#"$REPO_ROOT"/}."
    else
      warn "FAIL: Bash syntax: ${script#"$REPO_ROOT"/}."
      failed=1
    fi
  done < <(
    find "$REPO_ROOT/$SCRIPTS_REL" -maxdepth 1 -type f \
      \( -name '*.sh' -o -name '*.bash' \) -print0
  )

  [[ "$failed" -eq 0 ]] || fatal "One or more canonical project scripts failed Bash syntax validation."
}

commit_and_push() {
  if [[ "$COMMIT_CHANGES" != true ]]; then
    log "Files updated without a Git commit (--no-commit)."
    return 0
  fi

  # De-duplicate pathspecs while preserving all moved source paths so tracked
  # deletions outside scripts/bash are included without staging unrelated work.
  local -a unique_paths=()
  local path existing seen
  for path in "${STAGE_PATHS[@]}"; do
    seen=false
    for existing in "${unique_paths[@]:-}"; do
      if [[ "$existing" == "$path" ]]; then
        seen=true
        break
      fi
    done
    [[ "$seen" == true ]] || unique_paths+=("$path")
  done

  git -C "$REPO_ROOT" add -A -- "${unique_paths[@]}"

  if git -C "$REPO_ROOT" diff --cached --quiet; then
    log "No standardized project changes to commit."
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

main() {
  require_command git
  require_command python3
  require_command find
  require_command cmp

  capture_self
  parse_args "$@"
  validate_repo

  log "Repository root: $REPO_ROOT"
  log "Canonical scripts directory: $REPO_ROOT/$SCRIPTS_REL"

  install_self
  migrate_all_scripts
  patch_condensed_resume_generator
  regenerate_resume_files
  validate_all_canonical_scripts
  commit_and_push
  open_pdf

  log "Complete."
  log "Scripts: $REPO_ROOT/$SCRIPTS_REL"
  log "Resume:  $REPO_ROOT/$MASTER_REL"
  log "PDF:     $REPO_ROOT/$PDF_REL"
}

main "$@"

#!/usr/bin/env bash
#
# Repair invalid timestamped script backups created during project standardization,
# harden the canonical standardization script against preserving malformed conflicts,
# rerun resume generation, validate all canonical scripts, and commit/push changes.
#
# Canonical repository:
#   $HOME/Documents/github/Tim-Fox-Resume

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2026.07.17.1"
readonly SCRIPT_NAME="repair-standardization-conflicts-and-push.sh"
readonly DEFAULT_REPO="$HOME/Documents/github/Tim-Fox-Resume"
readonly SCRIPTS_REL="scripts/bash"
readonly STANDARDIZE_REL="$SCRIPTS_REL/standardize-resume-project-and-push.sh"
readonly SELF_REL="$SCRIPTS_REL/$SCRIPT_NAME"

REPO_ROOT="$DEFAULT_REPO"
COMMIT_CHANGES=true
PUSH_CHANGES=true
OPEN_PDF=false
COMMIT_MESSAGE="fix: remove invalid script backup and complete resume update"
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
Repair invalid preserved script conflicts and complete the GitHub update.

Usage:
  repair-standardization-conflicts-and-push.sh [options]

Options:
  --repo PATH       Repository root.
                    Default: ~/Documents/github/Tim-Fox-Resume
  --no-commit       Repair and regenerate without creating a Git commit.
  --no-push         Commit locally without pushing.
  --message TEXT    Git commit message.
  --open            Open the regenerated PDF on macOS.
  --version         Display the script version.
  -h, --help        Display this help text.

The script removes an invalid timestamped backup only when:
  1. The backup fails Bash syntax validation.
  2. Its non-timestamped canonical counterpart exists.
  3. The canonical counterpart passes Bash syntax validation.
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
  TEMP_SELF=$(mktemp "${TMPDIR:-/tmp}/repair-standardization.XXXXXX")
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

resolve_repository() {
  REPO_ROOT=$(absolute_path "$REPO_ROOT")
  [[ -d "$REPO_ROOT/.git" ]] || fatal "Not a Git repository: $REPO_ROOT"

  local top
  top=$(git -C "$REPO_ROOT" rev-parse --show-toplevel)
  REPO_ROOT=$(cd "$top" && pwd -P)

  [[ "$(basename "$REPO_ROOT")" == "Tim-Fox-Resume" ]] \
    || warn "Expected repository directory Tim-Fox-Resume; found $(basename "$REPO_ROOT")."
}

install_self_canonically() {
  local destination="$REPO_ROOT/$SELF_REL"
  mkdir -p "$(dirname "$destination")"

  if [[ ! -f "$destination" ]] || ! cmp -s "$TEMP_SELF" "$destination"; then
    cp "$TEMP_SELF" "$destination"
    chmod 0755 "$destination"
    log "Installed canonical repair script: $SELF_REL"
  else
    chmod 0755 "$destination"
    log "Canonical repair script is already current."
  fi

  # Remove an external downloaded copy before the standardizer scans Downloads.
  if [[ "$SOURCE_SCRIPT" != "$destination" && -f "$SOURCE_SCRIPT" ]]; then
    rm -f "$SOURCE_SCRIPT"
    log "Removed external script copy after canonical installation: $SOURCE_SCRIPT"
  fi
}

harden_standardizer() {
  local standardizer="$REPO_ROOT/$STANDARDIZE_REL"
  [[ -f "$standardizer" ]] || fatal "Missing standardization script: $STANDARDIZE_REL"
  bash -n "$standardizer" || fatal "The canonical standardization script is malformed before repair."

  python3 - "$standardizer" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

text = re.sub(
    r'readonly SCRIPT_VERSION="[^"]+"',
    'readonly SCRIPT_VERSION="2026.07.17.2"',
    text,
    count=1,
)

old = '''  final_destination=$(unique_destination "$destination")
  mv "$source_abs" "$final_destination"
  chmod 0755 "$final_destination"
  ((RENAMED_COUNT += 1))
  log "Preserved conflicting script as: $final_destination"
'''

new = '''  # Do not preserve a malformed conflict when a valid canonical script exists.
  # This prevents stale broken downloads from entering scripts/bash and blocking
  # repository-wide Bash validation.
  if ! bash -n "$source_abs" >/dev/null 2>&1 \\
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
'''

if new not in text:
    if old not in text:
        raise SystemExit("Could not locate the conflict-preservation block in the standardizer.")
    text = text.replace(old, new, 1)

path.write_text(text, encoding="utf-8")
PY

  chmod 0755 "$standardizer"
  bash -n "$standardizer" || fatal "Standardization script failed syntax validation after hardening."
  log "Hardened $STANDARDIZE_REL against malformed conflicting downloads."
}

remove_invalid_timestamped_backups() {
  local scripts_dir="$REPO_ROOT/$SCRIPTS_REL"
  local file base stem extension canonical removed=0

  while IFS= read -r -d '' file; do
    base=$(basename "$file")

    # Match names such as create-resume-project-20260717-005515.sh and
    # optional collision suffixes such as ...-005515-2.sh.
    if [[ "$base" =~ ^(.+)-([0-9]{8})-([0-9]{6})(-[0-9]+)?\.(sh|bash)$ ]]; then
      stem="${BASH_REMATCH[1]}"
      extension="${BASH_REMATCH[5]}"
      canonical="$scripts_dir/$stem.$extension"

      if bash -n "$file" >/dev/null 2>&1; then
        continue
      fi

      if [[ ! -f "$canonical" ]]; then
        fatal "Invalid timestamped script has no canonical counterpart: ${file#"$REPO_ROOT"/}"
      fi

      if ! bash -n "$canonical" >/dev/null 2>&1; then
        fatal "Both timestamped and canonical scripts are invalid: ${canonical#"$REPO_ROOT"/}"
      fi

      rm -f "$file"
      ((removed += 1))
      log "Removed invalid preserved backup: ${file#"$REPO_ROOT"/}"
    fi
  done < <(
    find "$scripts_dir" -maxdepth 1 -type f \
      \( -name '*.sh' -o -name '*.bash' \) -print0
  )

  log "Invalid preserved backups removed: $removed."
}

validate_all_scripts() {
  local scripts_dir="$REPO_ROOT/$SCRIPTS_REL"
  local failed=0 script

  while IFS= read -r -d '' script; do
    if bash -n "$script"; then
      log "PASS: Bash syntax: ${script#"$REPO_ROOT"/}."
    else
      warn "FAIL: Bash syntax: ${script#"$REPO_ROOT"/}."
      failed=1
    fi
  done < <(
    find "$scripts_dir" -maxdepth 1 -type f \
      \( -name '*.sh' -o -name '*.bash' \) -print0
  )

  [[ "$failed" -eq 0 ]] || fatal "One or more canonical project scripts still fail Bash syntax validation."
}

run_standardizer() {
  local standardizer="$REPO_ROOT/$STANDARDIZE_REL"
  local -a args=(--repo "$REPO_ROOT" --message "$COMMIT_MESSAGE")

  if [[ "$COMMIT_CHANGES" != true ]]; then
    args+=(--no-commit)
  elif [[ "$PUSH_CHANGES" != true ]]; then
    args+=(--no-push)
  fi

  [[ "$OPEN_PDF" == true ]] && args+=(--open)

  log "Rerunning canonical project standardization."
  "$standardizer" "${args[@]}"
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
  log "Canonical scripts directory: $REPO_ROOT/$SCRIPTS_REL"

  install_self_canonically
  harden_standardizer
  remove_invalid_timestamped_backups
  validate_all_scripts
  run_standardizer

  log "Repair complete. All canonical scripts are valid."
}

main "$@"

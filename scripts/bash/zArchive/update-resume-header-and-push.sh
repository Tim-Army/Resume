#!/usr/bin/env bash
#
# Update every Tim-Fox-Resume header to the approved value, install this script
# under scripts/bash, commit the affected files, and push the current branch.
#
# Approved header:
#   United States | Open to Remote Roles | timfox2025@tim.army | tim.army
#
# Typical first run from Downloads:
#   chmod +x "$HOME/Downloads/update-resume-header-and-push.sh"
#   "$HOME/Downloads/update-resume-header-and-push.sh" \
#     --repo "$HOME/Documents/github/Tim-Fox-Resume"
#

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2026.07.16.1"
readonly EXPECTED_REPO_NAME="Tim-Fox-Resume"
readonly CANONICAL_SCRIPT_NAME="update-resume-header-and-push.sh"
readonly APPROVED_HEADER="United States | Open to Remote Roles | timfox2025@tim.army | tim.army"

REPO_ROOT=""
PUSH_CHANGES=true
DRY_RUN=false
COMMIT_MESSAGE="docs: update resume contact header"
SOURCE_SCRIPT=""
CANONICAL_SCRIPT=""

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

usage() {
  cat <<'USAGE'
Update the contact header in the Tim-Fox-Resume repository and push it to GitHub.

Usage:
  update-resume-header-and-push.sh [options]

Options:
  --repo PATH       Tim-Fox-Resume repository root. Defaults to Git discovery.
  --no-push         Commit locally without pushing to GitHub.
  --message TEXT    Commit message.
                    Default: docs: update resume contact header
  --dry-run         Show the files and replacements without modifying Git.
  --version         Print the script version.
  -h, --help        Show this help text.

The script updates:
  scripts/bash/create-tim-fox-resume.sh
  resume/master/Tim-Fox-Resume.md
  resume/targeted/private-sector/Tim-Fox-Resume-Private-Sector.md
  resume/targeted/federal-defense/Tim-Fox-Resume-Federal-Defense.md
  scripts/bash/update-resume-header-and-push.sh
USAGE
}

parse_args() {
  while (($#)); do
    case "$1" in
      --repo)
        (($# >= 2)) || fatal "--repo requires a path."
        REPO_ROOT="$2"
        shift 2
        ;;
      --no-push)
        PUSH_CHANGES=false
        shift
        ;;
      --message)
        (($# >= 2)) || fatal "--message requires text."
        COMMIT_MESSAGE="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
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

absolute_path() {
  local input="$1"
  if [[ -d "$input" ]]; then
    (cd -- "$input" >/dev/null 2>&1 && pwd -P)
  else
    return 1
  fi
}

detect_repo_root() {
  if [[ -n "$REPO_ROOT" ]]; then
    REPO_ROOT="$(absolute_path "$REPO_ROOT")" || fatal "Repository directory does not exist: $REPO_ROOT"
  elif git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    REPO_ROOT="$git_root"
  elif [[ -d "$HOME/Documents/github/$EXPECTED_REPO_NAME/.git" ]]; then
    REPO_ROOT="$HOME/Documents/github/$EXPECTED_REPO_NAME"
  else
    fatal "Could not locate the $EXPECTED_REPO_NAME Git repository. Use --repo PATH."
  fi

  [[ -d "$REPO_ROOT/.git" ]] || fatal "Not a Git repository: $REPO_ROOT"
  [[ "$(basename "$REPO_ROOT")" == "$EXPECTED_REPO_NAME" ]] || \
    warn "Repository directory is named '$(basename "$REPO_ROOT")', expected '$EXPECTED_REPO_NAME'."

  REPO_ROOT="$(cd -- "$REPO_ROOT" && pwd -P)"
  CANONICAL_SCRIPT="$REPO_ROOT/scripts/bash/$CANONICAL_SCRIPT_NAME"
  log "Repository root: $REPO_ROOT"
}

install_self() {
  SOURCE_SCRIPT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)/$(basename -- "${BASH_SOURCE[0]}")"
  mkdir -p "$REPO_ROOT/scripts/bash"

  if [[ "$SOURCE_SCRIPT" == "$CANONICAL_SCRIPT" ]]; then
    log "Canonical update script is already in the repository."
    chmod +x "$CANONICAL_SCRIPT"
    return
  fi

  if $DRY_RUN; then
    log "DRY RUN: Would install $SOURCE_SCRIPT as scripts/bash/$CANONICAL_SCRIPT_NAME."
    return
  fi

  cp -- "$SOURCE_SCRIPT" "$CANONICAL_SCRIPT"
  chmod +x "$CANONICAL_SCRIPT"
  log "Installed: scripts/bash/$CANONICAL_SCRIPT_NAME"
}

replace_header_in_file() {
  local file="$1"
  local relative="${file#$REPO_ROOT/}"
  local temp
  local replacements

  [[ -f "$file" ]] || {
    warn "Skipping missing file: $relative"
    return 0
  }

  temp="$(mktemp "${TMPDIR:-/tmp}/resume-header.XXXXXX")"

  awk -v approved="$APPROVED_HEADER" '
    BEGIN { changed = 0 }
    {
      if ($0 ~ /^(Remote, USA|United States \| Open to Remote Roles)[[:space:]]*\|[[:space:]]*timfox2025@tim\.army[[:space:]]*\|/) {
        if ($0 != approved) {
          changed++
        }
        print approved
      } else {
        print
      }
    }
    END { print changed > "/dev/stderr" }
  ' "$file" > "$temp" 2>"$temp.count"

  replacements="$(cat "$temp.count")"
  rm -f "$temp.count"

  if [[ "$replacements" == "0" ]]; then
    if grep -Fqx "$APPROVED_HEADER" "$file"; then
      log "Header already current: $relative"
      rm -f "$temp"
      return 0
    fi

    rm -f "$temp"
    fatal "No recognized resume header was found in $relative."
  fi

  if $DRY_RUN; then
    log "DRY RUN: Would update $replacements header line(s) in $relative."
    rm -f "$temp"
    return 0
  fi

  cat "$temp" > "$file"
  rm -f "$temp"
  log "Updated $replacements header line(s): $relative"
}

validate_file_header() {
  local file="$1"
  local expected_count="$2"
  local relative="${file#$REPO_ROOT/}"
  local actual_count

  [[ -f "$file" ]] || return 0

  actual_count="$(grep -Fxc "$APPROVED_HEADER" "$file" || true)"
  [[ "$actual_count" == "$expected_count" ]] || \
    fatal "$relative contains $actual_count approved header line(s); expected $expected_count."

  if grep -Eq '^(Remote, USA|United States \| Open to Remote Roles)[[:space:]]*\|[[:space:]]*timfox2025@tim\.army[[:space:]]*\|.*\[tim\.army\]|^Remote, USA' "$file"; then
    fatal "$relative still contains an obsolete or linked header variant."
  fi

  log "PASS: Header verified in $relative."
}

update_headers() {
  local generator="$REPO_ROOT/scripts/bash/create-tim-fox-resume.sh"
  local master="$REPO_ROOT/resume/master/Tim-Fox-Resume.md"
  local private="$REPO_ROOT/resume/targeted/private-sector/Tim-Fox-Resume-Private-Sector.md"
  local federal="$REPO_ROOT/resume/targeted/federal-defense/Tim-Fox-Resume-Federal-Defense.md"

  [[ -f "$generator" ]] || fatal "Missing generator: scripts/bash/create-tim-fox-resume.sh"

  replace_header_in_file "$generator"
  replace_header_in_file "$master"
  replace_header_in_file "$private"
  replace_header_in_file "$federal"

  $DRY_RUN && return 0

  bash -n "$generator"
  bash -n "$CANONICAL_SCRIPT"
  log "PASS: Bash syntax validation."

  validate_file_header "$generator" 3
  validate_file_header "$master" 1
  validate_file_header "$private" 1
  validate_file_header "$federal" 1
}

commit_and_push() {
  local branch
  local -a paths=(
    "scripts/bash/create-tim-fox-resume.sh"
    "scripts/bash/$CANONICAL_SCRIPT_NAME"
    "resume/master/Tim-Fox-Resume.md"
    "resume/targeted/private-sector/Tim-Fox-Resume-Private-Sector.md"
    "resume/targeted/federal-defense/Tim-Fox-Resume-Federal-Defense.md"
  )

  $DRY_RUN && {
    log "DRY RUN: Git commit and push skipped."
    return 0
  }

  cd -- "$REPO_ROOT"

  git add -- "${paths[@]}"

  if git diff --cached --quiet; then
    log "No header changes require a commit."
  else
    git commit -m "$COMMIT_MESSAGE"
    log "Committed header update."
  fi

  if ! $PUSH_CHANGES; then
    log "Push disabled by --no-push."
    return 0
  fi

  branch="$(git branch --show-current)"
  [[ -n "$branch" ]] || fatal "Cannot push from a detached HEAD."

  git push -u origin "$branch"
  log "Pushed branch '$branch' to GitHub."
}

remove_downloaded_source() {
  local downloads_prefix="$HOME/Downloads/"

  $DRY_RUN && return 0
  [[ "$SOURCE_SCRIPT" == "$CANONICAL_SCRIPT" ]] && return 0

  if [[ "$SOURCE_SCRIPT" == "$downloads_prefix"* && -f "$SOURCE_SCRIPT" ]]; then
    rm -f -- "$SOURCE_SCRIPT"
    log "Removed downloaded script after repository installation: $SOURCE_SCRIPT"
  fi
}

main() {
  parse_args "$@"
  detect_repo_root
  install_self
  update_headers
  commit_and_push
  remove_downloaded_source

  printf '\nHeader update completed successfully.\n\n'
  printf '  Header:     %s\n' "$APPROVED_HEADER"
  printf '  Repository: %s\n' "$REPO_ROOT"
  printf '  Script:     scripts/bash/%s\n' "$CANONICAL_SCRIPT_NAME"
  printf '  Push:       %s\n' "$PUSH_CHANGES"
}

main "$@"

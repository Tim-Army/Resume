#!/usr/bin/env bash
#
# Lint the resume Markdown sources against the repository's editorial rules.
#
# Rules enforced:
#   1. Every resume bullet ends with a period.
#   2. Every Markdown heading is preceded by a blank line.
#
# Usage:
#   scripts/bash/lint-resume.sh [--repo PATH] [FILE...]
#
# With no FILE arguments, every Markdown file under resume/ is checked.
# Exits non-zero if any rule is violated.
#

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2026.07.19.1"

REPO_ROOT=""
FILES=()
FAILURES=0

log() {
  printf '[lint-resume] %s\n' "$*"
}

fail() {
  printf '[lint-resume] %s\n' "$*" >&2
  FAILURES=$((FAILURES + 1))
}

fatal() {
  printf '[lint-resume] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: lint-resume.sh [OPTIONS] [FILE...]

Options:
  --repo PATH   Repository root (default: the Git toplevel containing this script).
  --version     Print the script version and exit.
  -h, --help    Show this help text.

Checks every Markdown file under resume/ when no FILE is given.
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        [[ $# -ge 2 ]] || fatal "--repo requires a path."
        REPO_ROOT="$2"
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
      -*)
        fatal "Unknown option: $1"
        ;;
      *)
        FILES+=("$1")
        shift
        ;;
    esac
  done
}

resolve_repo() {
  if [[ -z "$REPO_ROOT" ]]; then
    local script_dir
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    REPO_ROOT=$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null) \
      || fatal "Not inside a Git repository. Pass --repo PATH."
  fi

  [[ -d "$REPO_ROOT" ]] || fatal "Repository not found: $REPO_ROOT"
}

collect_files() {
  if [[ ${#FILES[@]} -gt 0 ]]; then
    return
  fi

  [[ -d "$REPO_ROOT/resume" ]] || fatal "No resume/ directory in $REPO_ROOT"

  local file
  while IFS= read -r file; do
    FILES+=("$file")
  done < <(find "$REPO_ROOT/resume" -type f -name '*.md' | sort)

  [[ ${#FILES[@]} -gt 0 ]] || fatal "No Markdown files found under resume/."
}

# Rule 1: resume bullets must end with a period.
#
# README.md files describe the workflow rather than the resume itself, and their
# bullets are filenames and instructions, so they are exempt.
check_bullet_punctuation() {
  local file="$1"

  if [[ "$(basename "$file")" == "README.md" ]]; then
    return
  fi

  # A bullet may wrap across several lines. It ends at a blank line, a heading,
  # or the next bullet, so the period is checked on its final line rather than
  # the line the dash appears on.
  local line_number=0 line trimmed in_fence=false
  local in_bullet=false bullet_start=0 bullet_last_line=0 bullet_last_text=""

  close_bullet() {
    [[ "$in_bullet" == true ]] || return 0
    in_bullet=false

    if [[ "$bullet_last_text" != *. ]]; then
      fail "${file#"$REPO_ROOT"/}:${bullet_last_line}: bullet starting on line ${bullet_start} does not end with a period: ${bullet_last_text}"
    fi
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    trimmed="${line%"${line##*[![:space:]]}"}"

    # Fenced code blocks are literal content, not prose.
    if [[ "$trimmed" =~ ^(\`\`\`|~~~) ]]; then
      close_bullet
      if [[ "$in_fence" == true ]]; then in_fence=false; else in_fence=true; fi
      continue
    fi
    [[ "$in_fence" == true ]] && continue

    if [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
      close_bullet
      in_bullet=true
      bullet_start=$line_number
      bullet_last_line=$line_number
      bullet_last_text="$trimmed"
      continue
    fi

    # Blank line or heading terminates the current bullet.
    if [[ -z "$trimmed" ]] || [[ "$line" =~ ^#{1,6}[[:space:]] ]]; then
      close_bullet
      continue
    fi

    # An indented non-blank line continues the bullet it follows. Unindented
    # prose is treated as a new block, so the bullet is checked as it stands.
    if [[ "$in_bullet" == true ]]; then
      if [[ "$line" =~ ^[[:space:]]+ ]]; then
        bullet_last_line=$line_number
        bullet_last_text="$trimmed"
      else
        close_bullet
      fi
    fi
  done < "$file"

  close_bullet
  unset -f close_bullet
}

# Rule 2: headings must be preceded by a blank line.
#
# A heading glued to the preceding line is absorbed into that block by strict
# CommonMark renderers, which silently corrupts the rendered resume.
check_heading_spacing() {
  local file="$1"
  local line_number=0 line previous="" trimmed in_fence=false

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    trimmed="${line%"${line##*[![:space:]]}"}"

    # Fenced code blocks are literal content; a leading '#' there is a comment.
    if [[ "$trimmed" =~ ^(\`\`\`|~~~) ]]; then
      if [[ "$in_fence" == true ]]; then in_fence=false; else in_fence=true; fi
      previous="$line"
      continue
    fi
    if [[ "$in_fence" == true ]]; then
      previous="$line"
      continue
    fi

    if [[ $line_number -gt 1 ]] \
      && [[ "$line" =~ ^#{1,6}[[:space:]] ]] \
      && [[ -n "$previous" ]]; then
      fail "${file#"$REPO_ROOT"/}:${line_number}: heading needs a blank line before it: ${line}"
    fi

    previous="$line"
  done < "$file"
}

main() {
  parse_args "$@"
  resolve_repo
  collect_files

  local file
  for file in "${FILES[@]}"; do
    [[ -f "$file" ]] || fatal "File not found: $file"
    check_bullet_punctuation "$file"
    check_heading_spacing "$file"
  done

  if [[ $FAILURES -gt 0 ]]; then
    printf '[lint-resume] FAILED: %d issue(s) in %d file(s).\n' "$FAILURES" "${#FILES[@]}" >&2
    exit 1
  fi

  log "PASSED: ${#FILES[@]} file(s) clean."
}

main "$@"

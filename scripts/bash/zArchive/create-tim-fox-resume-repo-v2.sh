#!/usr/bin/env bash
#
# Create, reuse, or repair a GitHub repository named "Tim-Fox-Resume" and
# scaffold a maintainable resume workspace.
#
# Safe rerun behavior:
#   - Reuses an existing GitHub repository.
#   - Uses the current directory when it is already named Tim-Fox-Resume.
#   - Avoids creating Tim-Fox-Resume/Tim-Fox-Resume accidentally.
#   - Does not overwrite scaffold files unless --force is supplied.
#   - Commits and pushes only when changes exist.
#   - Can repair the accidental nested-directory layout with --repair-nested.
#
# Requirements:
#   - git
#   - GitHub CLI (gh), authenticated with repository permissions.
#
# Typical usage:
#   ./scripts/bash/create-tim-fox-resume-repo.sh --open
#   ./scripts/bash/create-tim-fox-resume-repo.sh --owner Tim-Army --open
#   ./scripts/bash/create-tim-fox-resume-repo.sh \
#     --directory "$HOME/Documents/github/Tim-Fox-Resume" --open
#
# Repair an accidental Tim-Fox-Resume/Tim-Fox-Resume layout:
#   ./scripts/bash/create-tim-fox-resume-repo.sh --repair-nested --open
#

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2026.07.16.2"
readonly DEFAULT_REPO_NAME="Tim-Fox-Resume"
readonly DEFAULT_VISIBILITY="private"
readonly DEFAULT_DESCRIPTION="Version-controlled source files, targeted variants, and publishing workflow for Tim Fox's professional resume."
readonly DEFAULT_HOMEPAGE="https://tim.army"

REPO_NAME="$DEFAULT_REPO_NAME"
OWNER=""
VISIBILITY="$DEFAULT_VISIBILITY"
DESCRIPTION="$DEFAULT_DESCRIPTION"
HOMEPAGE="$DEFAULT_HOMEPAGE"
LOCAL_DIR=""
RENAME_FROM=""
OPEN_REPO=false
FORCE=false
NO_PUSH=false
REPAIR_NESTED=false
LOCAL_DIR_EXPLICIT=false
SCRIPT_COPY_SOURCE=""
TEMP_SCRIPT_COPY=""

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
  if [[ -n "$TEMP_SCRIPT_COPY" && -f "$TEMP_SCRIPT_COPY" ]]; then
    rm -f "$TEMP_SCRIPT_COPY"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Create, reuse, or repair the GitHub repository "Tim-Fox-Resume".

Usage:
  create-tim-fox-resume-repo.sh [options]

Options:
  --owner LOGIN             GitHub user or organization that owns the repo.
                            Default: authenticated GitHub user.
  --directory PATH          Local repository directory.
                            Default behavior:
                              * Use the current directory when it is already
                                named Tim-Fox-Resume.
                              * Otherwise use ./Tim-Fox-Resume.
  --visibility VALUE        private, public, or internal for a new repository.
                            Existing repository visibility is preserved.
                            Default: private.
  --description TEXT        GitHub repository description.
  --homepage URL            GitHub repository homepage.
                            Default: https://tim.army.
  --rename-from OWNER/REPO  Rename an existing repository to Tim-Fox-Resume.
  --repair-nested           Repair an accidental directory layout of:
                              Tim-Fox-Resume/Tim-Fox-Resume/.git
                            The outer wrapper is retained as a timestamped
                            backup; it is not deleted.
  --force                   Replace scaffold files created by this script.
  --no-push                 Configure locally without committing or pushing.
  --open                    Open the repository in a browser when complete.
  --version                 Show the script version.
  -h, --help                Show this help text.

Examples:
  ./scripts/bash/create-tim-fox-resume-repo.sh --open

  ./scripts/bash/create-tim-fox-resume-repo.sh \
    --owner Tim-Army \
    --directory "$HOME/Documents/github/Tim-Fox-Resume" \
    --open

  ./scripts/bash/create-tim-fox-resume-repo.sh \
    --directory "$HOME/Documents/github/Tim-Fox-Resume" \
    --repair-nested \
    --open
USAGE
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fatal "Required command not found: $1"
}

capture_script_copy() {
  local source_path source_abs

  source_path="${BASH_SOURCE[0]}"
  source_abs=$(cd "$(dirname "$source_path")" && pwd)/$(basename "$source_path")

  TEMP_SCRIPT_COPY=$(mktemp "${TMPDIR:-/tmp}/create-tim-fox-resume-repo.XXXXXX")
  cp "$source_abs" "$TEMP_SCRIPT_COPY"
  chmod 0755 "$TEMP_SCRIPT_COPY"
  SCRIPT_COPY_SOURCE="$TEMP_SCRIPT_COPY"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --owner)
        [[ $# -ge 2 ]] || fatal "--owner requires a value."
        OWNER="$2"
        shift 2
        ;;
      --directory)
        [[ $# -ge 2 ]] || fatal "--directory requires a path."
        LOCAL_DIR="$2"
        LOCAL_DIR_EXPLICIT=true
        shift 2
        ;;
      --visibility)
        [[ $# -ge 2 ]] || fatal "--visibility requires private, public, or internal."
        VISIBILITY="${2,,}"
        shift 2
        ;;
      --description)
        [[ $# -ge 2 ]] || fatal "--description requires text."
        DESCRIPTION="$2"
        shift 2
        ;;
      --homepage)
        [[ $# -ge 2 ]] || fatal "--homepage requires a URL."
        HOMEPAGE="$2"
        shift 2
        ;;
      --rename-from)
        [[ $# -ge 2 ]] || fatal "--rename-from requires OWNER/REPO."
        RENAME_FROM="$2"
        shift 2
        ;;
      --repair-nested)
        REPAIR_NESTED=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --no-push)
        NO_PUSH=true
        shift
        ;;
      --open)
        OPEN_REPO=true
        shift
        ;;
      --version)
        printf "%s\n" "$SCRIPT_VERSION"
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

validate_inputs() {
  case "$VISIBILITY" in
    private|public|internal) ;;
    *) fatal "Visibility must be private, public, or internal." ;;
  esac

  if [[ -n "$RENAME_FROM" && "$RENAME_FROM" != */* ]]; then
    fatal "--rename-from must use OWNER/REPO format."
  fi

  if [[ -n "$OWNER" && "$OWNER" == */* ]]; then
    fatal "--owner must be a GitHub login, not OWNER/REPO."
  fi
}

check_authentication() {
  gh auth status >/dev/null 2>&1 || fatal "GitHub CLI is not authenticated. Run: gh auth login"
}

detect_owner() {
  if [[ -z "$OWNER" ]]; then
    OWNER=$(gh api user --jq '.login') || fatal "Could not determine the authenticated GitHub user."
  fi

  [[ -n "$OWNER" ]] || fatal "GitHub owner could not be determined."
}

absolute_path() {
  local input="$1"

  if [[ "$input" == "~/"* ]]; then
    input="$HOME/${input#~/}"
  fi

  if [[ "$input" != /* ]]; then
    input="$PWD/$input"
  fi

  # Normalize the parent directory without requiring the final path to exist.
  local parent base
  parent=$(dirname "$input")
  base=$(basename "$input")
  mkdir -p "$parent"
  parent=$(cd "$parent" && pwd -P)
  printf '%s/%s\n' "$parent" "$base"
}

set_local_directory() {
  if [[ "$LOCAL_DIR_EXPLICIT" == false ]]; then
    if [[ "$(basename "$PWD")" == "$REPO_NAME" ]]; then
      LOCAL_DIR="$PWD"
      log "Current directory is already named '$REPO_NAME'; using it as the repository root."
    else
      LOCAL_DIR="$PWD/$REPO_NAME"
    fi
  fi

  LOCAL_DIR=$(absolute_path "$LOCAL_DIR")
}

repo_exists() {
  gh repo view "$1" --json nameWithOwner --jq '.nameWithOwner' >/dev/null 2>&1
}

rename_repository_if_requested() {
  [[ -n "$RENAME_FROM" ]] || return 0

  local target="$OWNER/$REPO_NAME"

  repo_exists "$RENAME_FROM" || fatal "Source repository '$RENAME_FROM' does not exist or is inaccessible."

  if repo_exists "$target"; then
    fatal "Target repository '$target' already exists; refusing to rename '$RENAME_FROM'."
  fi

  local source_owner="${RENAME_FROM%%/*}"
  [[ "$source_owner" == "$OWNER" ]] || fatal \
    "--rename-from owner '$source_owner' must match target owner '$OWNER'."

  log "Renaming '$RENAME_FROM' to '$target'."
  gh repo rename "$REPO_NAME" --repo "$RENAME_FROM" --yes
}

nested_repo_path() {
  printf '%s/%s\n' "$LOCAL_DIR" "$REPO_NAME"
}

has_accidental_nested_repo() {
  local nested
  nested=$(nested_repo_path)
  [[ ! -d "$LOCAL_DIR/.git" && -d "$nested/.git" ]]
}

repair_nested_repository() {
  [[ "$REPAIR_NESTED" == true ]] || return 0

  if ! has_accidental_nested_repo; then
    if [[ -d "$LOCAL_DIR/.git" ]]; then
      log "Repository root is already correct; no nested repair is required."
      return 0
    fi

    fatal "No accidental nested repository was found at '$LOCAL_DIR/$REPO_NAME/.git'."
  fi

  local wrapper nested backup timestamp
  wrapper="$LOCAL_DIR"
  nested=$(nested_repo_path)
  timestamp=$(date '+%Y%m%d-%H%M%S')
  backup="${wrapper}.wrapper-backup-${timestamp}"

  [[ ! -e "$backup" ]] || fatal "Backup path already exists: '$backup'."

  log "Repairing accidental nested repository layout."
  log "Moving wrapper directory to '$backup'."
  mv "$wrapper" "$backup"

  [[ -d "$backup/$REPO_NAME/.git" ]] || fatal \
    "Nested repository was not found after creating backup '$backup'."

  log "Moving the nested Git repository into the intended path '$wrapper'."
  mv "$backup/$REPO_NAME" "$wrapper"

  [[ -d "$wrapper/.git" ]] || fatal "Nested repository repair did not produce '$wrapper/.git'."

  log "Nested repository repair completed."
  warn "The former outer wrapper was retained at '$backup'. Review it before deleting it."
}

refuse_unrepaired_nested_layout() {
  if has_accidental_nested_repo; then
    fatal "Detected an accidental nested repository at '$LOCAL_DIR/$REPO_NAME'. Rerun with --repair-nested. The outer wrapper will be retained as a backup."
  fi
}

prepare_local_workspace() {
  local full_repo="$OWNER/$REPO_NAME"

  if [[ -d "$LOCAL_DIR/.git" ]]; then
    log "Using existing local Git repository at '$LOCAL_DIR'."
    return 0
  fi

  if repo_exists "$full_repo"; then
    if [[ -e "$LOCAL_DIR" ]]; then
      if [[ ! -d "$LOCAL_DIR" ]]; then
        fatal "Local path '$LOCAL_DIR' exists and is not a directory."
      fi

      if [[ -n "$(find "$LOCAL_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
        fatal "Remote '$full_repo' exists, but '$LOCAL_DIR' is a nonempty directory and is not a Git repository."
      fi

      rmdir "$LOCAL_DIR" 2>/dev/null || true
    fi

    mkdir -p "$(dirname "$LOCAL_DIR")"
    log "Cloning existing GitHub repository '$full_repo'."
    gh repo clone "$full_repo" "$LOCAL_DIR"
    return 0
  fi

  mkdir -p "$LOCAL_DIR"
}

write_file() {
  local path="$1"
  local mode="${2:-0644}"

  if [[ -e "$path" && "$FORCE" != true ]]; then
    log "Keeping existing file: ${path#"$LOCAL_DIR"/}"
    cat >/dev/null
    return 0
  fi

  mkdir -p "$(dirname "$path")"
  cat >"$path"
  chmod "$mode" "$path"
  log "Wrote: ${path#"$LOCAL_DIR"/}"
}

create_scaffold() {
  log "Creating resume repository structure in '$LOCAL_DIR'."

  mkdir -p \
    "$LOCAL_DIR/resume/master" \
    "$LOCAL_DIR/resume/targeted/private-sector" \
    "$LOCAL_DIR/resume/targeted/federal-defense" \
    "$LOCAL_DIR/exports/docx" \
    "$LOCAL_DIR/exports/pdf" \
    "$LOCAL_DIR/docs" \
    "$LOCAL_DIR/archive" \
    "$LOCAL_DIR/scripts/bash" \
    "$LOCAL_DIR/.github/ISSUE_TEMPLATE"

  write_file "$LOCAL_DIR/README.md" <<'README'
# Tim-Fox-Resume

Version-controlled source files, targeted variants, and publishing workflow for Tim Fox's professional resume.

## Repository structure

- `resume/master/` — Authoritative master resume source.
- `resume/targeted/private-sector/` — Role-specific private-sector variants.
- `resume/targeted/federal-defense/` — Federal and defense-oriented variants.
- `exports/docx/` — Approved Microsoft Word exports.
- `exports/pdf/` — Approved PDF exports.
- `docs/` — Research, accomplishment metrics, and editorial notes.
- `archive/` — Superseded versions retained for reference.
- `scripts/bash/` — Repository automation scripts.

## Resume workflow

1. Backlog.
2. Ready.
3. Drafting.
4. Technical Review.
5. Editorial Review.
6. Ready to Publish.
7. Published.
8. Complete.

## Working rules

- Treat `resume/master/` as the source of truth.
- Create a targeted copy before tailoring for a vacancy.
- End every resume bullet with a period.
- Verify dates, certifications, security-clearance language, and metrics before publishing.
- Do not commit passwords, tokens, private keys, or classified or controlled information.
README

  write_file "$LOCAL_DIR/.gitignore" <<'GITIGNORE'
# macOS
.DS_Store

# Editors and temporary files
*.swp
*.swo
*~
.vscode/
.idea/

# Microsoft Office temporary files
~$*.docx
~$*.xlsx
~$*.pptx

# Local secrets and credentials
.env
.env.*
*.pem
*.key
*.p12
*.pfx

# Generated scratch content
.tmp/
tmp/
GITIGNORE

  write_file "$LOCAL_DIR/resume/master/README.md" <<'MASTER_README'
# Master resume

Store the authoritative, complete resume source in this directory.

Recommended filename:

- `Tim-Fox-Resume.md`

Create targeted variants from the master; do not tailor the master directly for a single vacancy.
MASTER_README

  write_file "$LOCAL_DIR/resume/targeted/private-sector/README.md" <<'PRIVATE_README'
# Private-sector variants

Store role-specific private-sector resumes here. Name each file for the target role or employer.
PRIVATE_README

  write_file "$LOCAL_DIR/resume/targeted/federal-defense/README.md" <<'FEDERAL_README'
# Federal and defense variants

Store federal, defense-contractor, or clearance-sensitive resume variants here. Verify all program names and disclosure restrictions before publishing.
FEDERAL_README

  write_file "$LOCAL_DIR/docs/accomplishment-metrics.md" <<'METRICS'
# Accomplishment metrics inventory

Capture verified metrics before adding them to the resume.

| Employer | Role | Achievement | Metric | Evidence or source | Approved for resume |
|---|---|---|---|---|---|
|  |  |  |  |  |  |
METRICS

  write_file "$LOCAL_DIR/docs/release-checklist.md" <<'CHECKLIST'
# Resume release checklist

- [ ] Contact information is current.
- [ ] Employment dates and titles are verified.
- [ ] Every bullet ends with a period.
- [ ] Acronyms are expanded on first use when appropriate.
- [ ] Certifications and qualification alignments are accurate.
- [ ] Metrics are supportable and not exaggerated.
- [ ] No classified, controlled, proprietary, or NDA-restricted details are included.
- [ ] ATS keywords match the target vacancy naturally.
- [ ] DOCX formatting was reviewed.
- [ ] PDF text extraction was tested.
- [ ] Final files use professional filenames.
CHECKLIST

  write_file "$LOCAL_DIR/.github/ISSUE_TEMPLATE/resume-task.md" <<'ISSUE_TEMPLATE'
---
name: Resume task
about: Track a resume revision, review, export, or publication task.
title: "[Resume] "
labels: "resume"
assignees: ""
---

## Objective

Describe the requested resume change.

## Target

- [ ] Master resume.
- [ ] Private-sector variant.
- [ ] Federal or defense variant.
- [ ] DOCX export.
- [ ] PDF export.

## Acceptance criteria

- [ ] Content is factually verified.
- [ ] Every bullet ends with a period.
- [ ] Formatting and ATS readability are reviewed.
- [ ] No sensitive or restricted information is exposed.
ISSUE_TEMPLATE

  : >"$LOCAL_DIR/exports/docx/.gitkeep"
  : >"$LOCAL_DIR/exports/pdf/.gitkeep"
  : >"$LOCAL_DIR/archive/.gitkeep"
}

install_script_copy() {
  local target_path

  target_path="$LOCAL_DIR/scripts/bash/create-tim-fox-resume-repo.sh"

  if [[ -e "$target_path" && "$FORCE" != true ]]; then
    if cmp -s "$SCRIPT_COPY_SOURCE" "$target_path"; then
      log "Keeping existing file: scripts/bash/create-tim-fox-resume-repo.sh"
      return 0
    fi

    # The setup script is infrastructure, so update it even without --force.
    log "Updating setup script: scripts/bash/create-tim-fox-resume-repo.sh"
  else
    log "Installing setup script: scripts/bash/create-tim-fox-resume-repo.sh"
  fi

  cp "$SCRIPT_COPY_SOURCE" "$target_path"
  chmod 0755 "$target_path"
}

initialize_git_repository() {
  if [[ -d "$LOCAL_DIR/.git" ]]; then
    log "Using existing local Git repository."
    return 0
  fi

  if [[ -e "$LOCAL_DIR/.git" ]]; then
    fatal "'$LOCAL_DIR/.git' exists but is not a directory."
  fi

  log "Initializing local Git repository."
  git -C "$LOCAL_DIR" init -b main >/dev/null
}

configure_git_identity_if_missing() {
  if ! git -C "$LOCAL_DIR" config user.name >/dev/null 2>&1; then
    local login
    login=$(gh api user --jq '.name // .login')
    git -C "$LOCAL_DIR" config user.name "$login"
    warn "Configured repository-local Git user.name as '$login'."
  fi

  if ! git -C "$LOCAL_DIR" config user.email >/dev/null 2>&1; then
    local user_id login noreply
    user_id=$(gh api user --jq '.id')
    login=$(gh api user --jq '.login')
    noreply="${user_id}+${login}@users.noreply.github.com"
    git -C "$LOCAL_DIR" config user.email "$noreply"
    warn "Configured repository-local Git user.email as '$noreply'."
  fi
}

ensure_origin_remote() {
  local full_repo="$OWNER/$REPO_NAME"
  local protocol remote_url

  protocol=$(gh config get git_protocol --host github.com 2>/dev/null || printf 'https')

  if [[ "$protocol" == "ssh" ]]; then
    remote_url="git@github.com:${full_repo}.git"
  else
    remote_url="https://github.com/${full_repo}.git"
  fi

  if git -C "$LOCAL_DIR" remote get-url origin >/dev/null 2>&1; then
    local current_url
    current_url=$(git -C "$LOCAL_DIR" remote get-url origin)
    if [[ "$current_url" != "$remote_url" ]]; then
      log "Updating origin remote to '$remote_url'."
      git -C "$LOCAL_DIR" remote set-url origin "$remote_url"
    fi
  else
    log "Adding origin remote '$remote_url'."
    git -C "$LOCAL_DIR" remote add origin "$remote_url"
  fi
}

create_remote_repository() {
  local full_repo="$OWNER/$REPO_NAME"
  local visibility_flag="--$VISIBILITY"
  local -a args

  args=(
    repo create "$full_repo"
    "$visibility_flag"
    --description "$DESCRIPTION"
    --source "$LOCAL_DIR"
    --remote origin
  )

  if [[ -n "$HOMEPAGE" ]]; then
    args+=(--homepage "$HOMEPAGE")
  fi

  log "Creating GitHub repository '$full_repo' with $VISIBILITY visibility."
  gh "${args[@]}"
}

configure_remote_repository() {
  local full_repo="$OWNER/$REPO_NAME"
  local -a edit_args

  edit_args=(
    repo edit "$full_repo"
    --description "$DESCRIPTION"
    --enable-issues=true
    --enable-wiki=false
  )

  if [[ -n "$HOMEPAGE" ]]; then
    edit_args+=(--homepage "$HOMEPAGE")
  fi

  log "Applying repository metadata."
  gh "${edit_args[@]}" >/dev/null

  log "Creating or updating the 'resume' label."
  gh label create resume \
    --repo "$full_repo" \
    --color 1D76DB \
    --description "Resume content, review, export, and publishing work." \
    --force \
    >/dev/null
}

synchronize_before_push() {
  if ! git -C "$LOCAL_DIR" remote get-url origin >/dev/null 2>&1; then
    return 0
  fi

  if git -C "$LOCAL_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
    git -C "$LOCAL_DIR" fetch origin --prune

    if git -C "$LOCAL_DIR" show-ref --verify --quiet refs/remotes/origin/main; then
      if ! git -C "$LOCAL_DIR" merge-base --is-ancestor origin/main HEAD; then
        log "Fast-forwarding or rebasing local changes onto origin/main."
        git -C "$LOCAL_DIR" rebase origin/main
      fi
    fi
  fi
}

commit_and_push_changes() {
  if [[ "$NO_PUSH" == true ]]; then
    warn "--no-push supplied; leaving changes uncommitted and unpushed."
    return 0
  fi

  configure_git_identity_if_missing
  synchronize_before_push
  git -C "$LOCAL_DIR" add --all

  if git -C "$LOCAL_DIR" diff --cached --quiet; then
    log "No local changes require a commit."
  else
    if git -C "$LOCAL_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
      git -C "$LOCAL_DIR" commit -m "Update Tim Fox resume repository scaffold" >/dev/null
    else
      git -C "$LOCAL_DIR" commit -m "Initialize Tim Fox resume repository" >/dev/null
    fi
    log "Committed repository changes."
  fi

  if ! git -C "$LOCAL_DIR" remote get-url origin >/dev/null 2>&1; then
    fatal "Origin remote is not configured."
  fi

  local branch
  branch=$(git -C "$LOCAL_DIR" branch --show-current)
  [[ -n "$branch" ]] || branch="main"

  log "Pushing '$branch' to origin."
  git -C "$LOCAL_DIR" push --set-upstream origin "$branch"
}

show_result() {
  local full_repo="$OWNER/$REPO_NAME"
  local repo_url actual_visibility

  repo_url=$(gh repo view "$full_repo" --json url --jq '.url')
  actual_visibility=$(gh repo view "$full_repo" --json visibility --jq '.visibility')

  cat <<EOF

Repository configured successfully.

  Repository: $full_repo
  Local path: $LOCAL_DIR
  Visibility: $actual_visibility
  URL:        $repo_url
EOF

  if [[ "$OPEN_REPO" == true ]]; then
    gh repo view "$full_repo" --web
  fi
}

main() {
  capture_script_copy
  parse_args "$@"
  validate_inputs
  log "Script version: $SCRIPT_VERSION"
  require_command gh
  require_command git
  check_authentication
  detect_owner
  set_local_directory
  rename_repository_if_requested
  repair_nested_repository
  refuse_unrepaired_nested_layout

  local full_repo="$OWNER/$REPO_NAME"

  if repo_exists "$full_repo"; then
    log "Reusing existing GitHub repository '$full_repo'."
  fi

  prepare_local_workspace
  create_scaffold
  install_script_copy
  initialize_git_repository

  if repo_exists "$full_repo"; then
    ensure_origin_remote
  else
    create_remote_repository
  fi

  configure_remote_repository
  commit_and_push_changes
  show_result
}

main "$@"

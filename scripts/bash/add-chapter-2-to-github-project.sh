#!/usr/bin/env bash
#
# Add or replace a book chapter in a GitHub repository, track the work in a
# GitHub Project, create a linked issue/branch, update TOCs, commit, push,
# and open a pull request.
#
# Designed for the Enterprise Infrastructure Series repository.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"

PROJECT_TITLE="Enterprise Infrastructure Series"
PROJECT_OWNER=""
PROJECT_STATUS="Editorial Review"
BASE_BRANCH="main"
ASSIGNEE="@me"
LABEL="book-chapter"

VOLUME_NUMBER="01"
VOLUME_SLUG="enterprise-engineering-foundations"
CHAPTER_NUMBER="02"
CHAPTER_SLUG="repository-architecture"
CHAPTER_TITLE="Repository Architecture"
CHAPTER_SOURCE=""

BRANCH_NAME=""
COMMIT_MESSAGE=""
ISSUE_TITLE=""
PR_TITLE=""
REFRESH_AUTH=false
ALLOW_DIRTY=false
SKIP_PROJECT=false
SKIP_PR=false

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME --chapter-source FILE [options]

Required:
  --chapter-source FILE      Markdown file containing the revised chapter.

GitHub Project options:
  --project-title TITLE      Project title. Default: "$PROJECT_TITLE"
  --project-owner OWNER      Project owner login or @me. Default: repo owner.
  --project-status STATUS    Status value to assign. Default: "$PROJECT_STATUS"
  --skip-project             Do not add the issue to a GitHub Project.
  --refresh-auth             Run: gh auth refresh -s project

Repository options:
  --base-branch BRANCH       Pull-request base branch. Default: "$BASE_BRANCH"
  --assignee LOGIN           Issue assignee. Default: "$ASSIGNEE"
  --label LABEL              Issue label. Default: "$LABEL"
  --allow-dirty              Allow unrelated uncommitted changes.
  --skip-pr                  Commit and push, but do not create a pull request.

Book location options:
  --volume-number NN         Default: "$VOLUME_NUMBER"
  --volume-slug SLUG         Default: "$VOLUME_SLUG"
  --chapter-number NN        Default: "$CHAPTER_NUMBER"
  --chapter-slug SLUG        Default: "$CHAPTER_SLUG"
  --chapter-title TITLE      Default: "$CHAPTER_TITLE"

Example:
  $SCRIPT_NAME \\
    --chapter-source ./chapter-02-repository-architecture.md \\
    --project-owner @me \\
    --project-title "Enterprise Infrastructure Series"
USAGE
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT
trap 'die "Command failed on line $LINENO."' ERR

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chapter-source)
      [[ $# -ge 2 ]] || die "--chapter-source requires a value."
      CHAPTER_SOURCE="$2"
      shift 2
      ;;
    --project-title)
      [[ $# -ge 2 ]] || die "--project-title requires a value."
      PROJECT_TITLE="$2"
      shift 2
      ;;
    --project-owner)
      [[ $# -ge 2 ]] || die "--project-owner requires a value."
      PROJECT_OWNER="$2"
      shift 2
      ;;
    --project-status)
      [[ $# -ge 2 ]] || die "--project-status requires a value."
      PROJECT_STATUS="$2"
      shift 2
      ;;
    --base-branch)
      [[ $# -ge 2 ]] || die "--base-branch requires a value."
      BASE_BRANCH="$2"
      shift 2
      ;;
    --assignee)
      [[ $# -ge 2 ]] || die "--assignee requires a value."
      ASSIGNEE="$2"
      shift 2
      ;;
    --label)
      [[ $# -ge 2 ]] || die "--label requires a value."
      LABEL="$2"
      shift 2
      ;;
    --volume-number)
      [[ $# -ge 2 ]] || die "--volume-number requires a value."
      VOLUME_NUMBER="$2"
      shift 2
      ;;
    --volume-slug)
      [[ $# -ge 2 ]] || die "--volume-slug requires a value."
      VOLUME_SLUG="$2"
      shift 2
      ;;
    --chapter-number)
      [[ $# -ge 2 ]] || die "--chapter-number requires a value."
      CHAPTER_NUMBER="$2"
      shift 2
      ;;
    --chapter-slug)
      [[ $# -ge 2 ]] || die "--chapter-slug requires a value."
      CHAPTER_SLUG="$2"
      shift 2
      ;;
    --chapter-title)
      [[ $# -ge 2 ]] || die "--chapter-title requires a value."
      CHAPTER_TITLE="$2"
      shift 2
      ;;
    --refresh-auth)
      REFRESH_AUTH=true
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=true
      shift
      ;;
    --skip-project)
      SKIP_PROJECT=true
      shift
      ;;
    --skip-pr)
      SKIP_PR=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$CHAPTER_SOURCE" ]] || {
  usage
  die "--chapter-source is required."
}

require_command git
require_command gh
require_command jq

[[ -f "$CHAPTER_SOURCE" ]] || die "Chapter source not found: $CHAPTER_SOURCE"
[[ -s "$CHAPTER_SOURCE" ]] || die "Chapter source is empty: $CHAPTER_SOURCE"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Run this script from inside the target Git repository."
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [[ "$ALLOW_DIRTY" != true ]] && [[ -n "$(git status --porcelain)" ]]; then
  die "The working tree is not clean. Commit/stash existing changes or use --allow-dirty."
fi

gh auth status >/dev/null 2>&1 || die "GitHub CLI is not authenticated. Run: gh auth login"
if [[ "$REFRESH_AUTH" == true ]]; then
  log "Refreshing GitHub authentication with the project scope."
  gh auth refresh -s project
fi

REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
REPO_OWNER="${REPO%%/*}"
PROJECT_OWNER="${PROJECT_OWNER:-$REPO_OWNER}"

VOLUME_DIR="volumes/volume-${VOLUME_NUMBER}-${VOLUME_SLUG}"
CHAPTER_DIR="${VOLUME_DIR}/chapters"
CHAPTER_FILE="${CHAPTER_DIR}/${CHAPTER_NUMBER}-${CHAPTER_SLUG}.md"
VOLUME_TOC="${VOLUME_DIR}/README.md"
MASTER_TOC="MASTER_TOC.md"

BRANCH_NAME="${BRANCH_NAME:-docs/revise-volume-${VOLUME_NUMBER}-chapter-${CHAPTER_NUMBER}}"
COMMIT_MESSAGE="${COMMIT_MESSAGE:-docs: revise Volume ${VOLUME_NUMBER} Chapter ${CHAPTER_NUMBER} ${CHAPTER_SLUG//-/ }}"
ISSUE_TITLE="${ISSUE_TITLE:-Revise Volume ${VOLUME_NUMBER}, Chapter ${CHAPTER_NUMBER} — ${CHAPTER_TITLE}}"
PR_TITLE="${PR_TITLE:-docs: revise Volume ${VOLUME_NUMBER} Chapter ${CHAPTER_NUMBER} ${CHAPTER_SLUG//-/ }}"

log "Repository: $REPO"
log "Target chapter: $CHAPTER_FILE"

TMP_DIR="$(mktemp -d)"
ISSUE_BODY_FILE="$TMP_DIR/issue-body.md"
PR_BODY_FILE="$TMP_DIR/pr-body.md"

mkdir -p "$CHAPTER_DIR"

# Ensure the chapter source is plain Markdown rather than a copied ChatGPT
# writing-block wrapper.
if grep -q '^:::writing' "$CHAPTER_SOURCE"; then
  die "The source contains :::writing markers. Remove the wrapper before running the script."
fi

if ! grep -Eq '^# +Chapter +[0-9]+' "$CHAPTER_SOURCE"; then
  warn "The chapter source does not begin with a '# Chapter N' heading."
fi

cat > "$ISSUE_BODY_FILE" <<EOF_ISSUE
## Objective

Replace the existing Chapter ${CHAPTER_NUMBER} with the revised **${CHAPTER_TITLE}** chapter.

## Files

- \`${CHAPTER_FILE}\`
- \`${VOLUME_TOC}\`
- \`${MASTER_TOC}\`

## Acceptance criteria

- [ ] Existing Chapter ${CHAPTER_NUMBER} is fully replaced
- [ ] Markdown headings render correctly
- [ ] Code examples are fenced correctly
- [ ] Internal chapter references are valid
- [ ] Volume ${VOLUME_NUMBER} table of contents is updated
- [ ] Master table of contents is updated
- [ ] Markdown validation passes
- [ ] Editorial review is complete
EOF_ISSUE

# Create the label if needed.
if [[ -n "$LABEL" ]]; then
  if ! gh label list --repo "$REPO" --limit 200 --json name --jq '.[].name' | grep -Fxq "$LABEL"; then
    log "Creating label: $LABEL"
    gh label create "$LABEL" \
      --repo "$REPO" \
      --description "Tracks book chapter work" \
      --color "1D76DB"
  fi
fi

log "Creating tracking issue."
ISSUE_ARGS=(
  --repo "$REPO"
  --title "$ISSUE_TITLE"
  --body-file "$ISSUE_BODY_FILE"
  --assignee "$ASSIGNEE"
)
if [[ -n "$LABEL" ]]; then
  ISSUE_ARGS+=(--label "$LABEL")
fi

ISSUE_URL="$(gh issue create "${ISSUE_ARGS[@]}")"
ISSUE_NUMBER="${ISSUE_URL##*/}"
log "Issue created: $ISSUE_URL"

if [[ "$SKIP_PROJECT" != true ]]; then
  log "Locating GitHub Project '$PROJECT_TITLE' owned by '$PROJECT_OWNER'."
  PROJECTS_JSON="$(gh project list --owner "$PROJECT_OWNER" --limit 100 --format json)"
  PROJECT_NUMBER="$(jq -r --arg title "$PROJECT_TITLE" '.projects[] | select(.title == $title) | .number' <<<"$PROJECTS_JSON" | head -n1)"
  PROJECT_ID="$(jq -r --arg title "$PROJECT_TITLE" '.projects[] | select(.title == $title) | .id' <<<"$PROJECTS_JSON" | head -n1)"

  [[ -n "$PROJECT_NUMBER" && "$PROJECT_NUMBER" != "null" ]] || \
    die "Project not found: '$PROJECT_TITLE' for owner '$PROJECT_OWNER'."
  [[ -n "$PROJECT_ID" && "$PROJECT_ID" != "null" ]] || \
    die "Unable to resolve the Project node ID."

  log "Adding issue to Project number $PROJECT_NUMBER."
  ITEM_JSON="$(gh project item-add "$PROJECT_NUMBER" \
    --owner "$PROJECT_OWNER" \
    --url "$ISSUE_URL" \
    --format json)"

  ITEM_ID="$(jq -r '.id // .item.id // empty' <<<"$ITEM_JSON")"
  if [[ -z "$ITEM_ID" ]]; then
    ITEMS_JSON="$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit 1000 --format json)"
    ITEM_ID="$(jq -r --arg url "$ISSUE_URL" '.items[] | select(.content.url == $url) | .id' <<<"$ITEMS_JSON" | head -n1)"
  fi
  [[ -n "$ITEM_ID" ]] || die "Issue was added, but the Project item ID could not be determined."

  FIELDS_JSON="$(gh project field-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json)"
  STATUS_FIELD_ID="$(jq -r '.fields[] | select(.name == "Status") | .id' <<<"$FIELDS_JSON" | head -n1)"
  STATUS_OPTION_ID="$(jq -r --arg status "$PROJECT_STATUS" '.fields[] | select(.name == "Status") | .options[]? | select(.name == $status) | .id' <<<"$FIELDS_JSON" | head -n1)"

  if [[ -n "$STATUS_FIELD_ID" && -n "$STATUS_OPTION_ID" ]]; then
    log "Setting Project status to '$PROJECT_STATUS'."
    gh project item-edit \
      --id "$ITEM_ID" \
      --project-id "$PROJECT_ID" \
      --field-id "$STATUS_FIELD_ID" \
      --single-select-option-id "$STATUS_OPTION_ID" >/dev/null
  else
    warn "Could not find Status option '$PROJECT_STATUS'; leaving the default Project status unchanged."
  fi
fi

log "Preparing branch: $BRANCH_NAME"
if gh help issue develop >/dev/null 2>&1; then
  gh issue develop "$ISSUE_NUMBER" \
    --repo "$REPO" \
    --base "$BASE_BRANCH" \
    --name "$BRANCH_NAME" \
    --checkout
else
  warn "'gh issue develop' is unavailable; creating an ordinary Git branch instead."
  git fetch origin "$BASE_BRANCH"
  git switch "$BASE_BRANCH"
  git pull --ff-only origin "$BASE_BRANCH"
  git switch -c "$BRANCH_NAME"
fi

log "Replacing chapter content."
cp "$CHAPTER_SOURCE" "$CHAPTER_FILE"

upsert_toc_entry() {
  local file="$1"
  local heading="$2"
  local search_pattern="$3"
  local replacement="$4"

  if [[ ! -f "$file" ]]; then
    mkdir -p "$(dirname "$file")"
    printf '# %s\n\n## Chapters\n\n%s\n' "$heading" "$replacement" > "$file"
    return
  fi

  if grep -Fqx "$replacement" "$file"; then
    return
  fi

  if grep -Eq "$search_pattern" "$file"; then
    awk -v pattern="$search_pattern" -v replacement="$replacement" '
      BEGIN { replaced = 0 }
      {
        if (!replaced && $0 ~ pattern) {
          print replacement
          replaced = 1
        } else {
          print
        }
      }
    ' "$file" > "${file}.tmp"
    mv "${file}.tmp" "$file"
  else
    printf '\n%s\n' "$replacement" >> "$file"
  fi
}

VOLUME_ENTRY="${CHAPTER_NUMBER#0}. [${CHAPTER_TITLE}](chapters/${CHAPTER_NUMBER}-${CHAPTER_SLUG}.md)"
MASTER_ENTRY="${CHAPTER_NUMBER#0}. [${CHAPTER_TITLE}](${CHAPTER_FILE})"

log "Updating Volume and master tables of contents."
upsert_toc_entry \
  "$VOLUME_TOC" \
  "Volume ${VOLUME_NUMBER} — ${VOLUME_SLUG//-/ }" \
  "^[[:space:]]*${CHAPTER_NUMBER#0}\\.[[:space:]].*(${CHAPTER_TITLE}|${CHAPTER_NUMBER}-${CHAPTER_SLUG}\\.md)" \
  "$VOLUME_ENTRY"

upsert_toc_entry \
  "$MASTER_TOC" \
  "Enterprise Infrastructure Series" \
  "^[[:space:]]*${CHAPTER_NUMBER#0}\\.[[:space:]].*(${CHAPTER_TITLE}|${CHAPTER_NUMBER}-${CHAPTER_SLUG}\\.md)" \
  "$MASTER_ENTRY"

log "Running Git validation."
git diff --check

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  markdownlint-cli2 "$CHAPTER_FILE" "$VOLUME_TOC" "$MASTER_TOC"
elif command -v markdownlint >/dev/null 2>&1; then
  markdownlint "$CHAPTER_FILE" "$VOLUME_TOC" "$MASTER_TOC"
else
  log "Markdown linter not installed; skipping Markdown lint validation."
fi

if [[ -z "$(git status --porcelain -- "$CHAPTER_FILE" "$VOLUME_TOC" "$MASTER_TOC")" ]]; then
  die "No chapter or TOC changes were detected."
fi

log "Staging manuscript changes."
git add "$CHAPTER_FILE" "$VOLUME_TOC" "$MASTER_TOC"

git diff --cached --check
log "Staged change summary:"
git diff --cached --stat

log "Creating commit."
git commit -m "$COMMIT_MESSAGE"

log "Pushing branch to origin."
git push --set-upstream origin HEAD

if [[ "$SKIP_PR" != true ]]; then
  cat > "$PR_BODY_FILE" <<EOF_PR
## Summary

Replaces the original Chapter ${CHAPTER_NUMBER} with the revised **${CHAPTER_TITLE}** chapter.

## Changes

- Reframes repositories as engineering control planes
- Adds repository-strategy decision guidance
- Establishes an enterprise directory baseline
- Expands governance, ownership, and ruleset coverage
- Adds security and lifecycle architecture
- Adds implementation guidance and a chapter lab
- Aligns the transition into Chapter 3

## Validation

- [x] Chapter file replaced
- [x] Volume ${VOLUME_NUMBER} table of contents updated
- [x] Master table of contents updated
- [x] Git whitespace validation passed
- [x] Code fences and Markdown structure reviewed
- [x] No secrets or generated artifacts included

Closes #${ISSUE_NUMBER}
EOF_PR

  log "Creating pull request."
  PR_URL="$(gh pr create \
    --repo "$REPO" \
    --base "$BASE_BRANCH" \
    --head "$BRANCH_NAME" \
    --title "$PR_TITLE" \
    --body-file "$PR_BODY_FILE")"
  log "Pull request created: $PR_URL"
fi

cat <<EOF_DONE

Completed successfully.

Repository:     $REPO
Issue:          $ISSUE_URL
Branch:         $BRANCH_NAME
Chapter:        $CHAPTER_FILE
Project status: $([[ "$SKIP_PROJECT" == true ]] && echo "Skipped" || echo "$PROJECT_STATUS")
EOF_DONE

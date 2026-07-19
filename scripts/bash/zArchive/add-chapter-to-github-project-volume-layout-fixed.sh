#!/usr/bin/env bash
#
# Add, replace, or migrate a book chapter into the Enterprise Infrastructure
# Series volume-first repository layout, track the work with a GitHub issue and
# Project item, create a linked branch, update TOCs, commit, push, and open a PR.
#
# Default migration:
#   chapters/02-repository-architecture.md
#       ->
#   volumes/volume-01-enterprise-engineering-foundations/chapters/
#     02-repository-architecture.md
#
# The chapter filename convention remains: NN-lowercase-hyphenated-title.md

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"

# GitHub workflow defaults.
PROJECT_TITLE="Enterprise Infrastructure Series"
PROJECT_OWNER=""
PROJECT_STATUS="Editorial Review"
BASE_BRANCH="main"
ASSIGNEE="@me"
LABEL="book-chapter"

# Volume and chapter defaults.
VOLUME_NUMBER="01"
VOLUME_SLUG="enterprise-engineering-foundations"
VOLUME_TITLE="Enterprise Engineering Foundations"
CHAPTER_NUMBER="02"
CHAPTER_SLUG="repository-architecture"
CHAPTER_TITLE="Repository Architecture"

# Source behavior.
CHAPTER_SOURCE=""
MOVE_SOURCE_MODE="auto" # auto, move, copy

# Optional controls.
ALLOW_DIRTY=false
REFRESH_AUTH=false
SKIP_PROJECT=false
SKIP_PR=false
DRY_RUN=false

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
  $SCRIPT_NAME [options]

Default behavior:
  Uses chapters/02-repository-architecture.md as the source and moves it to:

    volumes/volume-01-enterprise-engineering-foundations/chapters/
      02-repository-architecture.md

Source options:
  --chapter-source FILE      Source Markdown file. Default:
                             chapters/NN-chapter-slug.md
  --move-source              Move/remove an in-repository source after copying.
  --copy-source              Leave the source file in place.

Volume options:
  --volume-number NN         Default: $VOLUME_NUMBER
  --volume-slug SLUG         Default: $VOLUME_SLUG
  --volume-title TITLE       Default: "$VOLUME_TITLE"

Chapter options:
  --chapter-number NN        Default: $CHAPTER_NUMBER
  --chapter-slug SLUG        Default: $CHAPTER_SLUG
  --chapter-title TITLE      Default: "$CHAPTER_TITLE"

GitHub Project options:
  --project-title TITLE      Default: "$PROJECT_TITLE"
  --project-owner OWNER      User/org login or @me. Default: repository owner.
  --project-status STATUS    Default: "$PROJECT_STATUS"
  --skip-project             Do not add the issue to a GitHub Project.
  --refresh-auth             Run: gh auth refresh -s project

Repository options:
  --base-branch BRANCH       Default: $BASE_BRANCH
  --assignee LOGIN           Default: $ASSIGNEE
  --label LABEL              Default: $LABEL
  --allow-dirty              Permit unrelated working-tree changes.
  --skip-pr                  Commit and push without opening a pull request.
  --dry-run                  Show resolved paths and exit before GitHub changes.
  -h, --help                 Show this help.

Examples:
  # Migrate the current flat Chapter 2 into Volume I.
  $SCRIPT_NAME --project-owner @me

  # Copy a revised external Markdown file into Volume I.
  $SCRIPT_NAME \\
    --chapter-source ~/Documents/02-repository-architecture.md \\
    --copy-source \\
    --project-owner @me

  # Add another chapter while retaining the same filename convention.
  $SCRIPT_NAME \\
    --chapter-source ./drafts/03-automation-architecture.md \\
    --volume-number 01 \\
    --volume-slug enterprise-engineering-foundations \\
    --volume-title "Enterprise Engineering Foundations" \\
    --chapter-number 03 \\
    --chapter-slug automation-architecture \\
    --chapter-title "Automation Architecture"
USAGE
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

absolute_path() {
  local input="$1"
  local directory
  local filename

  directory="$(dirname "$input")"
  filename="$(basename "$input")"
  (
    cd "$directory" 2>/dev/null || exit 1
    printf '%s/%s\n' "$PWD" "$filename"
  )
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
    --move-source)
      MOVE_SOURCE_MODE="move"
      shift
      ;;
    --copy-source)
      MOVE_SOURCE_MODE="copy"
      shift
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
    --volume-title)
      [[ $# -ge 2 ]] || die "--volume-title requires a value."
      VOLUME_TITLE="$2"
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
    --dry-run)
      DRY_RUN=true
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

require_command git
require_command gh
require_command jq

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
  die "Run this script from inside the target Git repository."

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Normalize numbers to two digits while accepting values such as 1 or 01.
[[ "$VOLUME_NUMBER" =~ ^[0-9]+$ ]] || die "Volume number must be numeric."
[[ "$CHAPTER_NUMBER" =~ ^[0-9]+$ ]] || die "Chapter number must be numeric."
printf -v VOLUME_NUMBER '%02d' "$((10#$VOLUME_NUMBER))"
printf -v CHAPTER_NUMBER '%02d' "$((10#$CHAPTER_NUMBER))"

VOLUME_DIR="volumes/volume-${VOLUME_NUMBER}-${VOLUME_SLUG}"
CHAPTER_DIR="${VOLUME_DIR}/chapters"
CHAPTER_FILENAME="${CHAPTER_NUMBER}-${CHAPTER_SLUG}.md"
TARGET_CHAPTER_FILE="${CHAPTER_DIR}/${CHAPTER_FILENAME}"
VOLUME_TOC="${VOLUME_DIR}/README.md"
MASTER_TOC="MASTER_TOC.md"
DEFAULT_FLAT_SOURCE="chapters/${CHAPTER_FILENAME}"

TARGET_ABS="${REPO_ROOT}/${TARGET_CHAPTER_FILE}"
CHAPTER_ALREADY_MIGRATED=false

# When --chapter-source is omitted, search both the legacy flat layout and the
# volume-first destination. This allows the script to resume after a migration
# or a partial previous run.
if [[ -z "$CHAPTER_SOURCE" ]]; then
  if [[ -f "$DEFAULT_FLAT_SOURCE" ]]; then
    CHAPTER_SOURCE="$DEFAULT_FLAT_SOURCE"
  elif [[ -f "$TARGET_CHAPTER_FILE" ]]; then
    CHAPTER_SOURCE="$TARGET_CHAPTER_FILE"
    CHAPTER_ALREADY_MIGRATED=true
  else
    printf 'ERROR: Chapter source not found.\n' >&2
    printf 'Checked:\n' >&2
    printf '  %s\n' "$DEFAULT_FLAT_SOURCE" >&2
    printf '  %s\n' "$TARGET_CHAPTER_FILE" >&2
    exit 1
  fi
fi

[[ -f "$CHAPTER_SOURCE" ]] || die "Chapter source not found: $CHAPTER_SOURCE"
[[ -s "$CHAPTER_SOURCE" ]] || die "Chapter source is empty: $CHAPTER_SOURCE"

SOURCE_ABS="$(absolute_path "$CHAPTER_SOURCE")" || die "Unable to resolve source path: $CHAPTER_SOURCE"

if [[ "$SOURCE_ABS" == "$TARGET_ABS" ]]; then
  CHAPTER_ALREADY_MIGRATED=true
fi

# Determine whether the source is inside the repository.
SOURCE_IN_REPO=false
SOURCE_REL=""
case "$SOURCE_ABS" in
  "$REPO_ROOT"/*)
    SOURCE_IN_REPO=true
    SOURCE_REL="${SOURCE_ABS#${REPO_ROOT}/}"
    ;;
esac

# Auto mode migrates files from the legacy root chapters/ directory, but copies
# external files and files already stored elsewhere.
if [[ "$MOVE_SOURCE_MODE" == "auto" ]]; then
  if [[ "$SOURCE_IN_REPO" == true && "$SOURCE_REL" == chapters/* && "$SOURCE_ABS" != "$TARGET_ABS" ]]; then
    MOVE_SOURCE_MODE="move"
  else
    MOVE_SOURCE_MODE="copy"
  fi
fi

if grep -q '^:::writing' "$CHAPTER_SOURCE"; then
  die "The source contains :::writing markers. Remove the ChatGPT wrapper first."
fi

if ! grep -Eq '^# +Chapter +[0-9]+' "$CHAPTER_SOURCE"; then
  warn "The source does not contain a '# Chapter N' heading near the beginning."
fi

BRANCH_NAME="docs/volume-${VOLUME_NUMBER}-chapter-${CHAPTER_NUMBER}-${CHAPTER_SLUG}"
COMMIT_MESSAGE="docs: update Volume ${VOLUME_NUMBER} Chapter ${CHAPTER_NUMBER} ${CHAPTER_TITLE}"
ISSUE_TITLE="Update Volume ${VOLUME_NUMBER}, Chapter ${CHAPTER_NUMBER} — ${CHAPTER_TITLE}"
PR_TITLE="$COMMIT_MESSAGE"

log "Repository root: $REPO_ROOT"
log "Source:          $CHAPTER_SOURCE"
log "Target:          $TARGET_CHAPTER_FILE"
log "Source action:   $MOVE_SOURCE_MODE"
log "Volume TOC:      $VOLUME_TOC"
log "Master TOC:      $MASTER_TOC"

if [[ "$DRY_RUN" == true ]]; then
  log "Dry run complete. No files or GitHub resources were changed."
  exit 0
fi

if [[ "$ALLOW_DIRTY" != true ]] && [[ -n "$(git status --porcelain)" ]]; then
  die "The working tree is not clean. Commit/stash changes or use --allow-dirty."
fi

gh auth status >/dev/null 2>&1 || die "GitHub CLI is not authenticated. Run: gh auth login"
if [[ "$REFRESH_AUTH" == true ]]; then
  log "Refreshing GitHub authentication with Project access."
  gh auth refresh -s project
fi

REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
REPO_OWNER="${REPO%%/*}"
PROJECT_OWNER="${PROJECT_OWNER:-$REPO_OWNER}"

TMP_DIR="$(mktemp -d)"
ISSUE_BODY_FILE="$TMP_DIR/issue-body.md"
PR_BODY_FILE="$TMP_DIR/pr-body.md"

cat > "$ISSUE_BODY_FILE" <<EOF_ISSUE
## Objective

Place Chapter ${CHAPTER_NUMBER}, **${CHAPTER_TITLE}**, into the volume-first manuscript layout.

## Source and destination

- Source: \`${CHAPTER_SOURCE}\`
- Destination: \`${TARGET_CHAPTER_FILE}\`
- Source action: **${MOVE_SOURCE_MODE}**

## Related files

- \`${VOLUME_TOC}\`
- \`${MASTER_TOC}\`

## Acceptance criteria

- [ ] Chapter uses the \`${CHAPTER_FILENAME}\` naming convention
- [ ] Chapter is stored under the correct volume directory
- [ ] Legacy flat copy is removed when migration mode is selected
- [ ] Volume table of contents is updated
- [ ] Master table of contents links to the volume
- [ ] Markdown and Git whitespace validation pass
- [ ] Editorial review is complete
EOF_ISSUE

# Create/reuse the label.
if [[ -n "$LABEL" ]]; then
  if ! gh label list --repo "$REPO" --limit 200 --json name --jq '.[].name' | grep -Fxq "$LABEL"; then
    log "Creating label: $LABEL"
    gh label create "$LABEL" \
      --repo "$REPO" \
      --description "Tracks book chapter work" \
      --color "1D76DB"
  fi
fi

# Reuse an open issue with the exact title when possible, preventing duplicate
# Project cards if the script is rerun after a partial failure.
EXISTING_ISSUE_JSON="$(gh issue list \
  --repo "$REPO" \
  --state open \
  --limit 100 \
  --json number,title,url \
  --jq ".[] | select(.title == \"$ISSUE_TITLE\")" | head -n1 || true)"

if [[ -n "$EXISTING_ISSUE_JSON" ]]; then
  ISSUE_NUMBER="$(jq -r '.number' <<<"$EXISTING_ISSUE_JSON")"
  ISSUE_URL="$(jq -r '.url' <<<"$EXISTING_ISSUE_JSON")"
  log "Reusing open issue: $ISSUE_URL"
else
  log "Creating tracking issue."
  ISSUE_ARGS=(
    --repo "$REPO"
    --title "$ISSUE_TITLE"
    --body-file "$ISSUE_BODY_FILE"
    --assignee "$ASSIGNEE"
  )
  [[ -n "$LABEL" ]] && ISSUE_ARGS+=(--label "$LABEL")

  ISSUE_URL="$(gh issue create "${ISSUE_ARGS[@]}")"
  ISSUE_NUMBER="${ISSUE_URL##*/}"
  log "Issue created: $ISSUE_URL"
fi

if [[ "$SKIP_PROJECT" != true ]]; then
  log "Locating Project '$PROJECT_TITLE' owned by '$PROJECT_OWNER'."
  PROJECTS_JSON="$(gh project list --owner "$PROJECT_OWNER" --limit 100 --format json)"
  PROJECT_NUMBER="$(jq -r --arg title "$PROJECT_TITLE" '.projects[] | select(.title == $title) | .number' <<<"$PROJECTS_JSON" | head -n1)"
  PROJECT_ID="$(jq -r --arg title "$PROJECT_TITLE" '.projects[] | select(.title == $title) | .id' <<<"$PROJECTS_JSON" | head -n1)"

  [[ -n "$PROJECT_NUMBER" && "$PROJECT_NUMBER" != "null" ]] || \
    die "Project not found: '$PROJECT_TITLE' for '$PROJECT_OWNER'."
  [[ -n "$PROJECT_ID" && "$PROJECT_ID" != "null" ]] || \
    die "Unable to resolve the Project node ID."

  ITEMS_JSON="$(gh project item-list "$PROJECT_NUMBER" \
    --owner "$PROJECT_OWNER" \
    --limit 1000 \
    --format json)"
  ITEM_ID="$(jq -r --arg url "$ISSUE_URL" '.items[] | select(.content.url == $url) | .id' <<<"$ITEMS_JSON" | head -n1)"

  if [[ -z "$ITEM_ID" ]]; then
    log "Adding issue to Project number $PROJECT_NUMBER."
    ITEM_JSON="$(gh project item-add "$PROJECT_NUMBER" \
      --owner "$PROJECT_OWNER" \
      --url "$ISSUE_URL" \
      --format json)"
    ITEM_ID="$(jq -r '.id // .item.id // empty' <<<"$ITEM_JSON")"
  else
    log "Issue is already present in the Project."
  fi

  [[ -n "$ITEM_ID" ]] || die "Unable to determine the Project item ID."

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
    warn "Status option '$PROJECT_STATUS' was not found; leaving status unchanged."
  fi
fi

# Prepare a clean linked branch.
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  die "Local branch already exists: $BRANCH_NAME"
fi
if git ls-remote --exit-code --heads origin "$BRANCH_NAME" >/dev/null 2>&1; then
  die "Remote branch already exists: $BRANCH_NAME"
fi

log "Preparing branch: $BRANCH_NAME"
if gh help issue develop >/dev/null 2>&1; then
  gh issue develop "$ISSUE_NUMBER" \
    --repo "$REPO" \
    --base "$BASE_BRANCH" \
    --name "$BRANCH_NAME" \
    --checkout
else
  warn "'gh issue develop' is unavailable; creating a standard Git branch."
  git fetch origin "$BASE_BRANCH"
  git switch "$BASE_BRANCH"
  git pull --ff-only origin "$BASE_BRANCH"
  git switch -c "$BRANCH_NAME"
fi

mkdir -p "$CHAPTER_DIR"

# Copy first so an existing target can be safely replaced, then remove the
# legacy source only when migration was requested. If the source is already the
# destination, leave it in place and continue with TOC and GitHub processing.
if [[ "$CHAPTER_ALREADY_MIGRATED" == true ]]; then
  log "Chapter is already in the volume layout: $TARGET_CHAPTER_FILE"
else
  log "Writing chapter to volume directory."
  cp "$SOURCE_ABS" "$TARGET_CHAPTER_FILE"
fi

if [[ "$MOVE_SOURCE_MODE" == "move" && "$SOURCE_ABS" != "$TARGET_ABS" ]]; then
  if [[ "$SOURCE_IN_REPO" == true ]]; then
    log "Removing migrated flat source: $SOURCE_REL"
    if git ls-files --error-unmatch "$SOURCE_REL" >/dev/null 2>&1; then
      git rm "$SOURCE_REL" >/dev/null
    else
      rm -f "$SOURCE_REL"
    fi
  else
    warn "Source is outside the repository; it will not be deleted."
  fi
fi

upsert_numbered_link() {
  local file="$1"
  local section_title="$2"
  local number="$3"
  local title="$4"
  local link="$5"
  local entry="${number}. [${title}](${link})"

  if [[ ! -f "$file" ]]; then
    mkdir -p "$(dirname "$file")"
    printf '# %s\n\n## Chapters\n\n%s\n' "$section_title" "$entry" > "$file"
    return
  fi

  if grep -Fqx "$entry" "$file"; then
    return
  fi

  # Replace an existing entry that points to the same file or has the same
  # numbered title. Otherwise append it under the existing document.
  awk \
    -v number="$number" \
    -v title="$title" \
    -v link="$link" \
    -v entry="$entry" '
      BEGIN { replaced = 0 }
      {
        same_number_title = ($0 ~ "^[[:space:]]*" number "\\.[[:space:]]*\\[" title "\\]")
        same_link = (index($0, "(" link ")") > 0)
        if (!replaced && (same_number_title || same_link)) {
          print entry
          replaced = 1
        } else {
          print
        }
      }
      END {
        if (!replaced) {
          print ""
          print entry
        }
      }
    ' "$file" > "${file}.tmp"
  mv "${file}.tmp" "$file"
}

CHAPTER_DISPLAY_NUMBER="$((10#$CHAPTER_NUMBER))"
VOLUME_DISPLAY_NUMBER="$((10#$VOLUME_NUMBER))"
VOLUME_HEADING="Volume ${VOLUME_DISPLAY_NUMBER} — ${VOLUME_TITLE}"

log "Updating volume table of contents."
upsert_numbered_link \
  "$VOLUME_TOC" \
  "$VOLUME_HEADING" \
  "$CHAPTER_DISPLAY_NUMBER" \
  "$CHAPTER_TITLE" \
  "chapters/${CHAPTER_FILENAME}"

log "Updating master table of contents with the volume link."
upsert_numbered_link \
  "$MASTER_TOC" \
  "Enterprise Infrastructure Series" \
  "$VOLUME_DISPLAY_NUMBER" \
  "$VOLUME_TITLE" \
  "${VOLUME_DIR}/README.md"

log "Running Git validation."
git diff --check

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  markdownlint-cli2 "$TARGET_CHAPTER_FILE" "$VOLUME_TOC" "$MASTER_TOC"
elif command -v markdownlint >/dev/null 2>&1; then
  markdownlint "$TARGET_CHAPTER_FILE" "$VOLUME_TOC" "$MASTER_TOC"
else
  log "Markdown linter not installed; skipping Markdown lint validation."
fi

# Stage the volume, master TOC, and any legacy-source deletion.
log "Staging manuscript changes."
git add "$VOLUME_DIR" "$MASTER_TOC"
if [[ "$SOURCE_IN_REPO" == true && "$SOURCE_REL" != "$TARGET_CHAPTER_FILE" ]]; then
  git add -A -- "$SOURCE_REL" 2>/dev/null || true
fi

git diff --cached --check

if git diff --cached --quiet; then
  die "No staged changes were detected."
fi

log "Staged change summary:"
git diff --cached --stat

log "Creating commit."
git commit -m "$COMMIT_MESSAGE"

log "Pushing branch to origin."
git push --set-upstream origin HEAD

if [[ "$SKIP_PR" != true ]]; then
  cat > "$PR_BODY_FILE" <<EOF_PR
## Summary

Places Volume ${VOLUME_NUMBER}, Chapter ${CHAPTER_NUMBER}, **${CHAPTER_TITLE}**, into the volume-first manuscript layout.

## Repository changes

- Uses the filename \`${CHAPTER_FILENAME}\`
- Stores the chapter at \`${TARGET_CHAPTER_FILE}\`
- Updates \`${VOLUME_TOC}\`
- Updates \`${MASTER_TOC}\`
- Source handling: **${MOVE_SOURCE_MODE}**

## Validation

- [x] Git whitespace validation passed
- [x] Chapter is stored under its volume directory
- [x] Volume table of contents was updated
- [x] Master table of contents links to the volume
- [x] No generated artifacts or secrets were added

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

Repository:      $REPO
Issue:           $ISSUE_URL
Branch:          $BRANCH_NAME
Volume:          $VOLUME_DIR
Chapter:         $TARGET_CHAPTER_FILE
Source handling: $MOVE_SOURCE_MODE
Project status:  $([[ "$SKIP_PROJECT" == true ]] && echo "Skipped" || echo "$PROJECT_STATUS")
EOF_DONE

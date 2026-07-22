#!/usr/bin/env bash
#
# Set the Status field for an issue or pull request in a GitHub Project.
#
# Supports the default GitHub status names and this repository's custom aliases:
#   Todo        <-> Backlog
#   In Progress <-> Drafting
#   Done        <-> Complete
#
# Requirements:
#   - GitHub CLI (gh), authenticated with the "project" scope
#   - jq
#
# Example:
#   ./scripts/bash/set-github-project-status.sh \
#     --project-owner @me \
#     --project-title "Enterprise Infrastructure Series" \
#     --issue-url "https://github.com/OWNER/REPO/issues/2" \
#     --status "In Progress"

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
PROJECT_OWNER="@me"
PROJECT_NUMBER=""
PROJECT_TITLE=""
PROJECT_ITEM_ID=""
CONTENT_URL=""
REQUESTED_STATUS=""
ADD_IF_MISSING=false
DRY_RUN=false

log() {
  printf '[%(%H:%M:%S)T] %s\n' -1 "$*"
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

fatal() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<USAGE
Usage:
  $SCRIPT_NAME [options]

Required:
  --status NAME                 Requested project status.

Project selection — provide one:
  --project-number NUMBER       GitHub Project number.
  --project-title TITLE         GitHub Project title.

Item selection — provide one:
  --item-id ID                  Existing ProjectV2 item node ID.
  --issue-url URL               Issue or pull-request URL.

Options:
  --project-owner OWNER         Project owner login; default: @me
  --add-if-missing              Add --issue-url to the project when absent.
  --dry-run                     Resolve everything without changing GitHub.
  -h, --help                    Show this help.

Status aliases:
  Todo        <-> Backlog
  In Progress <-> Drafting
  Done        <-> Complete

Examples:
  $SCRIPT_NAME \\
    --project-owner @me \\
    --project-title "Enterprise Infrastructure Series" \\
    --issue-url "https://github.com/Tim-Army/Enterprise-Infrastructure-Series/issues/2" \\
    --status "In Progress"

  $SCRIPT_NAME \\
    --project-owner @me \\
    --project-number 1 \\
    --item-id PVTI_xxxxxxxxxxxx \\
    --status "Editorial Review"
USAGE
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fatal "Required command '$1' was not found."
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

normalize() {
  local value
  value="$(trim "$1")"
  value="${value//_/ }"
  value="${value//-/ }"
  value="$(tr '[:upper:]' '[:lower:]' <<<"$value")"
  # Collapse repeated whitespace without relying on GNU-only sed behavior.
  awk '{$1=$1; print}' <<<"$value"
}

status_candidates() {
  local requested="$1"
  local normalized
  normalized="$(normalize "$requested")"

  # Always try the user's exact value first.
  printf '%s\n' "$requested"

  case "$normalized" in
    todo|backlog)
      printf '%s\n' "Todo" "Backlog"
      ;;
    "in progress"|drafting)
      printf '%s\n' "In Progress" "Drafting"
      ;;
    done|complete)
      printf '%s\n' "Done" "Complete"
      ;;
  esac
}

resolve_project_number() {
  if [[ -n "$PROJECT_NUMBER" ]]; then
    printf '%s\n' "$PROJECT_NUMBER"
    return 0
  fi

  local projects_json matches
  log "Locating Project '$PROJECT_TITLE' owned by '$PROJECT_OWNER'." >&2

  projects_json="$(
    gh project list \
      --owner "$PROJECT_OWNER" \
      --limit 100 \
      --format json
  )"

  matches="$(
    jq -r \
      --arg title "$PROJECT_TITLE" \
      '.projects[]? | select(.title == $title) | .number' \
      <<<"$projects_json"
  )"

  [[ -n "$matches" ]] || fatal "Project '$PROJECT_TITLE' was not found for owner '$PROJECT_OWNER'."

  if [[ "$(wc -l <<<"$matches" | tr -d ' ')" -gt 1 ]]; then
    fatal "More than one project named '$PROJECT_TITLE' was found. Use --project-number."
  fi

  printf '%s\n' "$matches"
}

resolve_project_item_id() {
  local project_number="$1"

  if [[ -n "$PROJECT_ITEM_ID" ]]; then
    printf '%s\n' "$PROJECT_ITEM_ID"
    return 0
  fi

  local items_json item_id
  log "Locating project item for: $CONTENT_URL" >&2

  items_json="$(
    gh project item-list "$project_number" \
      --owner "$PROJECT_OWNER" \
      --limit 1000 \
      --format json
  )"

  item_id="$(
    jq -r \
      --arg url "$CONTENT_URL" \
      '.items[]?
       | select((.content.url // "") == $url)
       | .id' \
      <<<"$items_json" |
    head -n 1
  )"

  if [[ -n "$item_id" ]]; then
    printf '%s\n' "$item_id"
    return 0
  fi

  if [[ "$ADD_IF_MISSING" != true ]]; then
    fatal "The issue or pull request is not in the project. Re-run with --add-if-missing."
  fi

  if [[ "$DRY_RUN" == true ]]; then
    fatal "The item is absent and cannot be assigned a Project item ID during --dry-run."
  fi

  log "Adding the issue or pull request to the project." >&2
  item_id="$(
    gh project item-add "$project_number" \
      --owner "$PROJECT_OWNER" \
      --url "$CONTENT_URL" \
      --format json \
      --jq '.id'
  )"

  [[ -n "$item_id" ]] || fatal "GitHub did not return a Project item ID after adding the item."
  printf '%s\n' "$item_id"
}

resolve_status_option() {
  local fields_json="$1"
  local requested="$2"
  local candidate normalized_candidate result

  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    normalized_candidate="$(normalize "$candidate")"

    result="$(
      jq -r \
        --arg wanted "$normalized_candidate" \
        '.fields[]?
         | select((.name | ascii_downcase) == "status")
         | .options[]?
         | select(
             (.name
              | ascii_downcase
              | gsub("[_-]"; " ")
              | gsub("[[:space:]]+"; " ")
              | sub("^[[:space:]]+"; "")
              | sub("[[:space:]]+$"; "")) == $wanted
           )
         | [.id, .name]
         | @tsv' \
        <<<"$fields_json" |
      head -n 1
    )"

    if [[ -n "$result" ]]; then
      printf '%s\n' "$result"
      return 0
    fi
  done < <(status_candidates "$requested" | awk '!seen[$0]++')

  return 1
}

list_available_statuses() {
  local fields_json="$1"
  jq -r '
    .fields[]?
    | select((.name | ascii_downcase) == "status")
    | .options[]?
    | "  - " + .name
  ' <<<"$fields_json"
}

while (($# > 0)); do
  case "$1" in
    --project-owner)
      (($# >= 2)) || fatal "--project-owner requires a value."
      PROJECT_OWNER="$2"
      shift 2
      ;;
    --project-number)
      (($# >= 2)) || fatal "--project-number requires a value."
      PROJECT_NUMBER="$2"
      shift 2
      ;;
    --project-title)
      (($# >= 2)) || fatal "--project-title requires a value."
      PROJECT_TITLE="$2"
      shift 2
      ;;
    --item-id)
      (($# >= 2)) || fatal "--item-id requires a value."
      PROJECT_ITEM_ID="$2"
      shift 2
      ;;
    --issue-url|--content-url)
      (($# >= 2)) || fatal "$1 requires a value."
      CONTENT_URL="$2"
      shift 2
      ;;
    --status)
      (($# >= 2)) || fatal "--status requires a value."
      REQUESTED_STATUS="$2"
      shift 2
      ;;
    --add-if-missing)
      ADD_IF_MISSING=true
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
      fatal "Unknown argument: $1. Run '$SCRIPT_NAME --help'."
      ;;
  esac
done

require_command gh
require_command jq
require_command awk

[[ -n "$REQUESTED_STATUS" ]] || fatal "--status is required."

if [[ -n "$PROJECT_NUMBER" && -n "$PROJECT_TITLE" ]]; then
  fatal "Use either --project-number or --project-title, not both."
fi
[[ -n "$PROJECT_NUMBER" || -n "$PROJECT_TITLE" ]] || fatal "Provide --project-number or --project-title."

if [[ -n "$PROJECT_ITEM_ID" && -n "$CONTENT_URL" ]]; then
  fatal "Use either --item-id or --issue-url, not both."
fi
[[ -n "$PROJECT_ITEM_ID" || -n "$CONTENT_URL" ]] || fatal "Provide --item-id or --issue-url."

if ! gh auth status >/dev/null 2>&1; then
  fatal "GitHub CLI is not authenticated. Run: gh auth login"
fi

PROJECT_NUMBER="$(resolve_project_number)"
log "Project number: $PROJECT_NUMBER"

PROJECT_JSON="$(
  gh project view "$PROJECT_NUMBER" \
    --owner "$PROJECT_OWNER" \
    --format json
)"
PROJECT_ID="$(jq -r '.id // empty' <<<"$PROJECT_JSON")"
[[ -n "$PROJECT_ID" ]] || fatal "Unable to resolve the Project node ID."

FIELDS_JSON="$(
  gh project field-list "$PROJECT_NUMBER" \
    --owner "$PROJECT_OWNER" \
    --limit 100 \
    --format json
)"

STATUS_FIELD_ID="$(
  jq -r '
    .fields[]?
    | select((.name | ascii_downcase) == "status")
    | .id
  ' <<<"$FIELDS_JSON" |
  head -n 1
)"

if [[ -z "$STATUS_FIELD_ID" ]]; then
  fatal "A single-select field named 'Status' was not found in the project."
fi

STATUS_RESULT="$(resolve_status_option "$FIELDS_JSON" "$REQUESTED_STATUS" || true)"
if [[ -z "$STATUS_RESULT" ]]; then
  warn "Status option '$REQUESTED_STATUS' was not found."
  printf 'Available Status options:\n' >&2
  list_available_statuses "$FIELDS_JSON" >&2
  exit 2
fi

IFS=$'\t' read -r STATUS_OPTION_ID RESOLVED_STATUS <<<"$STATUS_RESULT"
PROJECT_ITEM_ID="$(resolve_project_item_id "$PROJECT_NUMBER")"

log "Project ID:       $PROJECT_ID"
log "Project item ID:  $PROJECT_ITEM_ID"
log "Status field ID:  $STATUS_FIELD_ID"
log "Requested status: $REQUESTED_STATUS"
log "Resolved status:  $RESOLVED_STATUS"

if [[ "$DRY_RUN" == true ]]; then
  log "Dry run complete; no GitHub data was changed."
  exit 0
fi

gh project item-edit \
  --id "$PROJECT_ITEM_ID" \
  --project-id "$PROJECT_ID" \
  --field-id "$STATUS_FIELD_ID" \
  --single-select-option-id "$STATUS_OPTION_ID" \
  >/dev/null

log "Project status updated successfully: $RESOLVED_STATUS"

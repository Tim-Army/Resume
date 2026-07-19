#!/usr/bin/env bash

set -euo pipefail

# Configure the GitHub Projects v2 Status field for the book-production workflow.
#
# Required environment variables:
#   PROJECT_NUMBER  GitHub project number, for example: 3
#
# Optional environment variables:
#   OWNER           GitHub user or organization login. Defaults to @me.
#
# Example:
#   export PROJECT_NUMBER="3"
#   export OWNER="@me"
#   ./configure-project-status-options.sh

PROJECT_NUMBER="${PROJECT_NUMBER:-}"
OWNER="${OWNER:-@me}"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

command -v gh >/dev/null 2>&1 || fail "GitHub CLI (gh) is not installed."
command -v jq >/dev/null 2>&1 || fail "jq is not installed."

[[ -n "$PROJECT_NUMBER" ]] || fail "PROJECT_NUMBER is not set."

echo "Reading project $PROJECT_NUMBER for owner $OWNER..."

STATUS_JSON="$(
  gh project field-list "$PROJECT_NUMBER" \
    --owner "$OWNER" \
    --format json \
    --jq '.fields[] | select(.name == "Status")'
)"

[[ -n "$STATUS_JSON" ]] || fail "The project does not contain a Status field."

STATUS_FIELD_ID="$(jq -r '.id // empty' <<<"$STATUS_JSON")"
[[ -n "$STATUS_FIELD_ID" ]] || fail "Could not determine the Status field ID."

find_option_id() {
  local option_name="$1"
  jq -r --arg name "$option_name" \
    '.options[]? | select(.name == $name) | .id' \
    <<<"$STATUS_JSON" | head -n 1
}

# Preserve existing option IDs where possible so current project items retain
# their assigned status values. This supports both the original default names
# and repeated runs after the workflow has already been configured.
BACKLOG_ID="$(find_option_id "Backlog")"
[[ -n "$BACKLOG_ID" ]] || BACKLOG_ID="$(find_option_id "Todo")"

DRAFTING_ID="$(find_option_id "Drafting")"
[[ -n "$DRAFTING_ID" ]] || DRAFTING_ID="$(find_option_id "In Progress")"

COMPLETE_ID="$(find_option_id "Complete")"
[[ -n "$COMPLETE_ID" ]] || COMPLETE_ID="$(find_option_id "Done")"

READY_ID="$(find_option_id "Ready")"
TECHNICAL_REVIEW_ID="$(find_option_id "Technical Review")"
LAB_VALIDATION_ID="$(find_option_id "Lab Validation")"
EDITORIAL_REVIEW_ID="$(find_option_id "Editorial Review")"
READY_TO_PUBLISH_ID="$(find_option_id "Ready to Publish")"
PUBLISHED_ID="$(find_option_id "Published")"

build_option() {
  local id="$1"
  local name="$2"
  local color="$3"
  local description="$4"

  if [[ -n "$id" ]]; then
    jq -n \
      --arg id "$id" \
      --arg name "$name" \
      --arg color "$color" \
      --arg description "$description" \
      '{id: $id, name: $name, color: $color, description: $description}'
  else
    jq -n \
      --arg name "$name" \
      --arg color "$color" \
      --arg description "$description" \
      '{name: $name, color: $color, description: $description}'
  fi
}

OPTIONS="$(
  jq -s '.' \
    <(build_option "$BACKLOG_ID" "Backlog" "GRAY" \
      "Work identified but not yet scheduled.") \
    <(build_option "$READY_ID" "Ready" "BLUE" \
      "Ready to begin.") \
    <(build_option "$DRAFTING_ID" "Drafting" "YELLOW" \
      "Content is actively being drafted.") \
    <(build_option "$TECHNICAL_REVIEW_ID" "Technical Review" "ORANGE" \
      "Technical accuracy is being reviewed.") \
    <(build_option "$LAB_VALIDATION_ID" "Lab Validation" "PURPLE" \
      "Commands and labs are being tested.") \
    <(build_option "$EDITORIAL_REVIEW_ID" "Editorial Review" "PINK" \
      "Content is undergoing editorial review.") \
    <(build_option "$READY_TO_PUBLISH_ID" "Ready to Publish" "BLUE" \
      "Approved and ready for publication.") \
    <(build_option "$PUBLISHED_ID" "Published" "GREEN" \
      "Content has been published.") \
    <(build_option "$COMPLETE_ID" "Complete" "GREEN" \
      "All work is complete.")
)"

MUTATION='mutation(
  $fieldId: ID!
  $options: [ProjectV2SingleSelectFieldOptionInput!]!
) {
  updateProjectV2Field(
    input: {
      fieldId: $fieldId
      singleSelectOptions: $options
    }
  ) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        id
        name
        options {
          id
          name
        }
      }
    }
  }
}'

echo "Updating Status options..."

RESPONSE="$(
  jq -n \
    --arg query "$MUTATION" \
    --arg fieldId "$STATUS_FIELD_ID" \
    --argjson options "$OPTIONS" \
    '{
      query: $query,
      variables: {
        fieldId: $fieldId,
        options: $options
      }
    }' |
  gh api graphql --input -
)"

if jq -e '.errors and (.errors | length > 0)' <<<"$RESPONSE" >/dev/null; then
  jq -r '.errors[] | .message' <<<"$RESPONSE" >&2
  fail "GitHub rejected the Status field update."
fi

echo
printf '%-22s %s\n' "STATUS" "OPTION ID"
printf '%-22s %s\n' "----------------------" "---------"
jq -r '
  .data.updateProjectV2Field.projectV2Field.options[]
  | [.name, .id]
  | @tsv
' <<<"$RESPONSE" |
while IFS=$'\t' read -r name id; do
  printf '%-22s %s\n' "$name" "$id"
done

echo
echo "Status workflow configured successfully."

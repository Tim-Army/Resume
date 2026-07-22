#!/usr/bin/env bash
#
# Create and merge Volume I, Chapter 7 — Enterprise Architecture Fundamentals.
#
# Default workflow:
#   1. Fetch and validate origin/main.
#   2. Create or reuse the Chapter 7 branch.
#   3. Create the manuscript and update both tables of contents.
#   4. Create or reuse the GitHub issue and Project item.
#   5. Commit, push, and create or reuse a pull request.
#   6. Validate the pull request and merge it into main.
#   7. Verify Chapter 7 directly from origin/main.
#   8. Synchronize local main and delete the completed branch.
#
# The script never force-pushes or directly pushes content to main.

set -Eeuo pipefail
IFS=$'\n\t'

PROGRAM_NAME="$(basename "$0")"
SCRIPT_ABS="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"

REMOTE="origin"
BASE_BRANCH="main"
EXPECTED_REPO="Tim-Army/Enterprise-Infrastructure-Series"

VOLUME_DIR="volumes/volume-01-enterprise-engineering-foundations"
CHAPTER_DIR="$VOLUME_DIR/chapters"
CHAPTER_PATH="$CHAPTER_DIR/07-enterprise-architecture-fundamentals.md"
VOLUME_TOC="$VOLUME_DIR/README.md"
MASTER_TOC="MASTER_TOC.md"

CHAPTER_NUMBER="7"
CHAPTER_TITLE="Enterprise Architecture Fundamentals"
BRANCH_NAME="docs/volume-01-chapter-07-enterprise-architecture-fundamentals"
ISSUE_TITLE="Draft Volume I, Chapter 7 — $CHAPTER_TITLE"
COMMIT_MESSAGE="docs: create Volume I Chapter 7 enterprise architecture"
PR_TITLE="$COMMIT_MESSAGE"

PROJECT_TITLE="Enterprise Infrastructure Series"
PROJECT_OWNER=""
PROJECT_START_STATUS="Drafting"
PROJECT_FINAL_STATUS="Complete"
ASSIGNEE="@me"
LABEL="book-chapter"
MERGE_METHOD="merge"

DRY_RUN=false
LOCAL_ONLY=false
SKIP_PROJECT=false
KEEP_BRANCH=false
ALLOW_EXTRA_FILES=false
ALLOW_DIRTY=false
FORCE_TARGET=false
STRICT_LINT=false

REPO_ROOT=""
REPO=""
REPO_OWNER=""
SCRIPT_REL=""
TMP_DIR=""
ISSUE_NUMBER=""
ISSUE_URL=""
PR_NUMBER=""
PR_URL=""
PROJECT_NUMBER=""
PROJECT_ID=""
PROJECT_ITEM_ID=""

usage() {
  cat <<USAGE
Usage:
  $PROGRAM_NAME [options]

Creates Volume I, Chapter 7 and merges it into GitHub main through a pull
request.

Options:
  --project-owner OWNER     GitHub user/org or @me. Default: repository owner.
  --project-title TITLE     Default: "$PROJECT_TITLE"
  --start-status STATUS     Initial Project status. Default: "$PROJECT_START_STATUS"
  --final-status STATUS     Post-merge Project status. Default: "$PROJECT_FINAL_STATUS"
  --merge-method METHOD     merge, squash, or rebase. Default: merge.
  --assignee LOGIN          Issue assignee. Default: @me.
  --label LABEL             Issue label. Default: book-chapter.
  --skip-project            Skip GitHub Project integration.
  --keep-branch             Keep local and remote chapter branches after merge.
  --allow-extra-files       Permit unexpected files in the pull request.
  --allow-dirty             Permit unrelated local working-tree changes.
  --force-target            Replace an existing different Chapter 7 manuscript.
  --strict-lint             Treat Markdown-linter findings as fatal.
  --local-only              Create and commit locally; do not call GitHub or merge.
  --dry-run                 Show the plan without changing anything.
  -h, --help                Show this help.

Examples:
  $PROGRAM_NAME --dry-run

  $PROGRAM_NAME \
    --project-owner @me \
    --project-title "Enterprise Infrastructure Series"

  $PROGRAM_NAME \
    --project-owner @me \
    --merge-method merge \
    --keep-branch
USAGE
}

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

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT
trap 'die "Command failed on line $LINENO."' ERR

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    die "Required command not found: $1"
}

status_candidates() {
  local requested="$1"
  printf '%s\n' "$requested"

  case "$requested" in
    Drafting) printf '%s\n' "In Progress" ;;
    "In Progress") printf '%s\n' "Drafting" ;;
    Backlog) printf '%s\n' "Todo" ;;
    Todo) printf '%s\n' "Backlog" ;;
    Complete) printf '%s\n' "Done" ;;
    Done) printf '%s\n' "Complete" ;;
    Published) printf '%s\n' "Complete" "Done" ;;
  esac
}

resolve_status_record() {
  local fields_json="$1"
  local requested="$2"
  local candidate record

  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue

    record="$(
      jq -r --arg wanted "$candidate" '
        .fields[]?
        | select(.name == "Status")
        | .options[]?
        | select(.name == $wanted)
        | [.id, .name]
        | @tsv
      ' <<<"$fields_json" | head -n1
    )"

    if [[ -n "$record" ]]; then
      printf '%s\n' "$record"
      return 0
    fi
  done < <(status_candidates "$requested" | awk '!seen[$0]++')

  return 1
}

set_project_status() {
  local requested="$1"
  local fields_json status_field_id status_record
  local status_option_id resolved_status

  [[ "$SKIP_PROJECT" != true ]] || return 0
  [[ -n "$PROJECT_NUMBER" && -n "$PROJECT_ID" && -n "$PROJECT_ITEM_ID" ]] ||
    return 0

  fields_json="$(
    gh project field-list "$PROJECT_NUMBER" \
      --owner "$PROJECT_OWNER" \
      --format json
  )"

  status_field_id="$(
    jq -r '.fields[]? | select(.name == "Status") | .id' \
      <<<"$fields_json" | head -n1
  )"

  status_record="$(resolve_status_record "$fields_json" "$requested" || true)"

  if [[ -z "$status_field_id" || "$status_field_id" == "null" ||
        -z "$status_record" ]]; then
    warn "No compatible Project status was found for '$requested'; leaving it unchanged."
    return 0
  fi

  IFS=$'\t' read -r status_option_id resolved_status <<<"$status_record"

  log "Setting GitHub Project status to '$resolved_status'."
  gh project item-edit \
    --id "$PROJECT_ITEM_ID" \
    --project-id "$PROJECT_ID" \
    --field-id "$status_field_id" \
    --single-select-option-id "$status_option_id" >/dev/null
}

verify_remote_content() {
  local base_ref="$REMOTE/$BASE_BRANCH"
  local chapter_lines chapter_bytes volume_count master_count

  printf '\nRemote verification\n'

  for path in "$MASTER_TOC" "$VOLUME_TOC" "$CHAPTER_PATH"; do
    if git cat-file -e "$base_ref:$path" 2>/dev/null; then
      printf 'PASS: Present on %s: %s\n' "$base_ref" "$path"
    else
      die "Missing from $base_ref after merge: $path"
    fi
  done

  if [[ -n "$SCRIPT_REL" ]]; then
    if git cat-file -e "$base_ref:$SCRIPT_REL" 2>/dev/null; then
      printf 'PASS: Workflow script is present on %s\n' "$base_ref"
    else
      die "Workflow script is missing from $base_ref: $SCRIPT_REL"
    fi
  fi

  chapter_lines="$(
    git show "$base_ref:$CHAPTER_PATH" |
      wc -l |
      tr -d '[:space:]'
  )"
  chapter_bytes="$(git cat-file -s "$base_ref:$CHAPTER_PATH")"

  if [[ "$chapter_lines" -ge 20 && "$chapter_bytes" -ge 500 ]]; then
    printf 'PASS: Chapter 7 is populated (%s lines, %s bytes)\n' \
      "$chapter_lines" "$chapter_bytes"
  else
    die "Chapter 7 appears incomplete ($chapter_lines lines, $chapter_bytes bytes)"
  fi

  grep -Fq '# Chapter 7' < <(git show "$base_ref:$CHAPTER_PATH") ||
    die "Chapter 7 numbered heading is missing"
  printf 'PASS: Chapter 7 numbered heading is present\n'

  grep -Fq "$CHAPTER_TITLE" < <(git show "$base_ref:$CHAPTER_PATH") ||
    die "Chapter 7 title is missing"
  printf 'PASS: Chapter 7 title is present\n'

  volume_count="$(
    git show "$base_ref:$VOLUME_TOC" |
      grep -Fc '07-enterprise-architecture-fundamentals.md' || true
  )"
  master_count="$(
    git show "$base_ref:$MASTER_TOC" |
      grep -Fc '07-enterprise-architecture-fundamentals.md' || true
  )"

  [[ "$volume_count" -eq 1 ]] ||
    die "Volume I README contains $volume_count Chapter 7 references; expected 1"
  [[ "$master_count" -eq 1 ]] ||
    die "MASTER_TOC.md contains $master_count Chapter 7 references; expected 1"

  printf 'PASS: Volume I README contains exactly one Chapter 7 link\n'
  printf 'PASS: MASTER_TOC.md contains exactly one Chapter 7 link\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-owner)
      [[ $# -ge 2 ]] || die "--project-owner requires a value"
      PROJECT_OWNER="$2"
      shift 2
      ;;
    --project-title)
      [[ $# -ge 2 ]] || die "--project-title requires a value"
      PROJECT_TITLE="$2"
      shift 2
      ;;
    --start-status)
      [[ $# -ge 2 ]] || die "--start-status requires a value"
      PROJECT_START_STATUS="$2"
      shift 2
      ;;
    --final-status)
      [[ $# -ge 2 ]] || die "--final-status requires a value"
      PROJECT_FINAL_STATUS="$2"
      shift 2
      ;;
    --merge-method)
      [[ $# -ge 2 ]] || die "--merge-method requires a value"
      MERGE_METHOD="$2"
      shift 2
      ;;
    --assignee)
      [[ $# -ge 2 ]] || die "--assignee requires a value"
      ASSIGNEE="$2"
      shift 2
      ;;
    --label)
      [[ $# -ge 2 ]] || die "--label requires a value"
      LABEL="$2"
      shift 2
      ;;
    --skip-project)
      SKIP_PROJECT=true
      shift
      ;;
    --keep-branch)
      KEEP_BRANCH=true
      shift
      ;;
    --allow-extra-files)
      ALLOW_EXTRA_FILES=true
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=true
      shift
      ;;
    --force-target)
      FORCE_TARGET=true
      shift
      ;;
    --strict-lint)
      STRICT_LINT=true
      shift
      ;;
    --local-only)
      LOCAL_ONLY=true
      SKIP_PROJECT=true
      KEEP_BRANCH=true
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
      die "Unknown option: $1"
      ;;
  esac
done

case "$MERGE_METHOD" in
  merge|squash|rebase) ;;
  *) die "Unsupported merge method: $MERGE_METHOD" ;;
esac

require_command git
require_command python3

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" ||
  die "Run this script inside the Enterprise-Infrastructure-Series repository"
cd "$REPO_ROOT"

case "$SCRIPT_ABS" in
  "$REPO_ROOT"/*) SCRIPT_REL="${SCRIPT_ABS#"$REPO_ROOT"/}" ;;
esac

if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
  die "A Git merge is currently in progress."
fi

if [[ -n "$(git diff --name-only --diff-filter=U)" ]]; then
  die "The working tree contains unresolved conflicts."
fi

if [[ "$LOCAL_ONLY" != true ]]; then
  require_command gh
  require_command jq

  gh auth status >/dev/null 2>&1 ||
    die "GitHub CLI is not authenticated. Run: gh auth login"

  REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
  [[ "$REPO" == "$EXPECTED_REPO" ]] ||
    die "Expected '$EXPECTED_REPO', but gh resolved '$REPO'"

  REPO_OWNER="${REPO%%/*}"
  PROJECT_OWNER="${PROJECT_OWNER:-$REPO_OWNER}"

  REMOTE_URL="$(git remote get-url "$REMOTE")"
  REMOTE_SLUG="$(
    printf '%s' "$REMOTE_URL" |
      sed -E \
        -e 's#^git@github\.com:##' \
        -e 's#^ssh://git@github\.com/##' \
        -e 's#^https?://github\.com/##' \
        -e 's#\.git$##'
  )"
  [[ "$REMOTE_SLUG" == "$EXPECTED_REPO" ]] ||
    die "$REMOTE points to '$REMOTE_SLUG'; expected '$EXPECTED_REPO'"

  log "Fetching current GitHub state."
  git fetch "$REMOTE" --prune

  git rev-parse --verify "$REMOTE/$BASE_BRANCH^{commit}" >/dev/null 2>&1 ||
    die "Remote base branch does not exist: $REMOTE/$BASE_BRANCH"
fi

log "Repository:      $REPO_ROOT"
log "Chapter:         $CHAPTER_TITLE"
log "Target:          $CHAPTER_PATH"
log "Work branch:     $BRANCH_NAME"
log "Merge method:    $MERGE_METHOD"
log "Project status:  $PROJECT_START_STATUS -> $PROJECT_FINAL_STATUS"

if [[ "$DRY_RUN" == true ]]; then
  log "Would create or reuse Chapter 7 and update both TOCs."
  log "Would create/reuse the issue, Project item, branch, and pull request."
  log "Would validate and merge the pull request into $BASE_BRANCH."
  log "Would verify origin/$BASE_BRANCH and synchronize local $BASE_BRANCH."
  [[ "$KEEP_BRANCH" == true ]] ||
    log "Would delete the completed local and remote chapter branches."
  exit 0
fi

# Allow the installed workflow script itself, but reject unrelated dirt.
if [[ "$ALLOW_DIRTY" != true ]]; then
  DIRTY_OUTPUT="$(git status --porcelain --untracked-files=all)"

  if [[ -n "$DIRTY_OUTPUT" ]]; then
    DIRTY_OUTPUT="$(
      printf '%s\n' "$DIRTY_OUTPUT" |
        awk \
          -v script="$SCRIPT_REL" \
          -v chapter="$CHAPTER_PATH" \
          -v volume="$VOLUME_TOC" \
          -v master="$MASTER_TOC" '
            {
              path = substr($0, 4)
              if (path == script || path == chapter ||
                  path == volume || path == master) next
              print
            }
          '
    )"
  fi

  if [[ -n "$DIRTY_OUTPUT" ]]; then
    printf '%s\n' "$DIRTY_OUTPUT" >&2
    die "Unrelated working-tree changes exist. Commit/stash them or use --allow-dirty."
  fi
fi

# Chapter 6 must be merged before Chapter 7 begins.
CHAPTER_06="$CHAPTER_DIR/06-understanding-enterprise-infrastructure.md"
if [[ "$LOCAL_ONLY" == true ]]; then
  [[ -s "$CHAPTER_06" ]] ||
    die "Chapter 6 is missing locally: $CHAPTER_06"
else
  git cat-file -e "$REMOTE/$BASE_BRANCH:$CHAPTER_06" 2>/dev/null ||
    die "Chapter 6 is not present on $REMOTE/$BASE_BRANCH"
fi

START_POINT="$BASE_BRANCH"
if [[ "$LOCAL_ONLY" != true ]]; then
  START_POINT="$REMOTE/$BASE_BRANCH"
fi

# Create or reuse the chapter branch before writing files.
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  log "Reusing local branch: $BRANCH_NAME"
  git switch "$BRANCH_NAME"
elif [[ "$LOCAL_ONLY" != true ]] &&
     git ls-remote --exit-code --heads "$REMOTE" "$BRANCH_NAME" >/dev/null 2>&1; then
  log "Reusing remote branch: $REMOTE/$BRANCH_NAME"
  git fetch "$REMOTE" "$BRANCH_NAME"
  git switch --track -c "$BRANCH_NAME" "$REMOTE/$BRANCH_NAME"
else
  log "Creating $BRANCH_NAME from $START_POINT"
  git switch -c "$BRANCH_NAME" "$START_POINT"
fi

# Update an interrupted branch with current main before touching Chapter 7.
if [[ "$LOCAL_ONLY" != true ]]; then
  BEHIND_COUNT="$(git rev-list --count "$BRANCH_NAME..$REMOTE/$BASE_BRANCH")"
  if [[ "$BEHIND_COUNT" -gt 0 ]]; then
    log "Merging current $REMOTE/$BASE_BRANCH into the chapter branch."
    if ! git merge --no-edit "$REMOTE/$BASE_BRANCH"; then
      die "The chapter branch conflicts with current main. Resolve or abort the merge, then rerun."
    fi
  fi
fi

mkdir -p "$CHAPTER_DIR"

if [[ -f "$CHAPTER_PATH" && "$FORCE_TARGET" != true ]]; then
  log "Chapter 7 already exists; preserving its current manuscript."
else
  cat > "$CHAPTER_PATH" <<'CHAPTER_EOF'
# Chapter 7
# Enterprise Architecture Fundamentals

> Enterprise architecture connects organizational strategy, business
> capabilities, information, applications, technology, security, and
> operations through explicit principles, models, standards, and decisions.

---

## Introduction

Enterprise infrastructure cannot be designed effectively as a sequence of
isolated product selections. A server, cloud service, network, identity
platform, or storage system is valuable only when it supports an organizational
capability and fits the surrounding architecture.

Enterprise architecture provides the methods used to connect strategy and
technology. It helps leaders and engineers describe the current environment,
define a desired future state, make defensible decisions, manage transition,
and govern change across many teams and systems.

This chapter introduces the architecture concepts used throughout the series.
It focuses on practical infrastructure engineering rather than treating
architecture as a purely theoretical or documentation activity.

---

## Learning Objectives

After completing this chapter, you will be able to:

- Define enterprise architecture and its purpose.
- Distinguish enterprise, solution, infrastructure, and technical architecture.
- Connect strategy, outcomes, capabilities, services, and technology.
- Describe business, data, application, technology, and security viewpoints.
- Model current, transition, and target states.
- Apply architecture principles, standards, patterns, and guardrails.
- Record architecture decisions and their consequences.
- Identify stakeholders, concerns, assumptions, constraints, and risks.
- Use reference architectures and building blocks.
- Conduct a practical architecture review.

---

# 1. Architecture as a Decision System

Architecture is not merely a diagram. It is a system for making and preserving
important decisions.

Architecture should explain:

- What the organization is trying to achieve
- Which capabilities are required
- Which constraints must be respected
- How major components relate
- Which standards and patterns apply
- Which risks are accepted
- How the current environment will evolve
- Who owns the decisions

A useful architecture makes future engineering work more consistent and less
dependent on individual memory.

---

# 2. Architecture Scope and Levels

Architecture exists at several levels.

## Enterprise Architecture

Coordinates capabilities, information, applications, technology, security, and
governance across the organization.

## Domain Architecture

Focuses on a major area such as networking, identity, cloud, security, data, or
end-user computing.

## Solution Architecture

Defines how a specific business or technical solution satisfies requirements.

## Infrastructure Architecture

Defines compute, storage, networking, platform, identity, security,
observability, automation, and operational services.

## Technical Design

Specifies implementation details for a bounded component or deployment.

The levels should align rather than operate as unrelated documents.

---

# 3. Strategy, Outcomes, and Capabilities

Architecture begins with organizational intent.

A useful traceability chain is:

```text
Strategy
   │
   ▼
Business Outcomes
   │
   ▼
Business Capabilities
   │
   ▼
Services and Products
   │
   ▼
Applications and Data
   │
   ▼
Infrastructure Capabilities
   │
   ▼
Technology Components
```

This chain helps prevent product-first design.

---

# 4. Stakeholders and Concerns

Architecture serves stakeholders with different concerns.

Examples include:

- Executives: value, cost, risk, timing
- Service owners: outcomes, availability, support
- Security teams: threats, controls, evidence
- Engineers: interfaces, dependencies, standards
- Operations teams: monitoring, recovery, ownership
- Finance teams: investment and consumption
- Auditors: policy, traceability, compliance
- Users: performance, usability, continuity

An architecture should make these concerns visible and resolve conflicts
explicitly.

---

# 5. Requirements, Assumptions, and Constraints

Architecture inputs should be classified.

## Requirements

Conditions the solution must satisfy.

## Assumptions

Statements treated as true until validated.

## Constraints

Limits that restrict available choices.

Examples include:

- Regulatory obligations
- Existing contracts
- Approved vendors
- Available skills
- Facility limitations
- Migration windows
- Budget
- Data residency
- Legacy dependencies

Unstated assumptions are a common source of architecture failure.

---

# 6. Architecture Domains

A common enterprise model includes several connected domains.

## Business Architecture

Capabilities, value streams, organization, services, and outcomes.

## Data Architecture

Information ownership, classification, flow, retention, and quality.

## Application Architecture

Applications, services, interfaces, dependencies, and lifecycle.

## Technology Architecture

Infrastructure platforms, networks, compute, storage, cloud, and tooling.

## Security Architecture

Identity, trust, controls, segmentation, detection, and recovery.

These domains should be analyzed together.

---

# 7. Architecture Viewpoints and Views

A viewpoint defines the concerns and conventions used to describe a system. A
view is the resulting representation.

Useful infrastructure views include:

- Context view
- Capability view
- Logical component view
- Physical deployment view
- Network view
- Data-flow view
- Trust-boundary view
- Identity view
- Availability view
- Operational view
- Recovery view
- Cost view
- Transition view

No single diagram can answer every stakeholder question.

---

# 8. Current, Transition, and Target States

Architecture describes change over time.

## Current State

What exists today, including debt, risks, and constraints.

## Target State

The desired future architecture.

## Transition States

Intermediate architectures required to move safely from current to target.

A target architecture without a transition plan is an aspiration rather than an
executable design.

---

# 9. Architecture Principles

Principles guide repeated decisions.

A useful principle includes:

- Name
- Statement
- Rationale
- Implications
- Exceptions

Example:

```text
Principle:
Automate Repeatable Infrastructure Changes

Statement:
Supported infrastructure changes must be executable through reviewed,
version-controlled automation whenever practical.

Rationale:
Automation improves consistency, traceability, and recovery.

Implications:
Teams require supported modules, testing, secrets management, and rollback.
Manual emergency changes must be reconciled into source control.
```

Principles should influence actual decisions.

---

# 10. Standards, Patterns, and Guardrails

Architecture governance uses several control types.

## Standards

Required technologies, configurations, interfaces, or practices.

## Patterns

Reusable approaches proven to satisfy common requirements.

## Guardrails

Boundaries within which teams can make local decisions.

## Guidelines

Recommended practices that allow justified variation.

## Exceptions

Time-bounded approvals to deviate from established controls.

Clear classification prevents every recommendation from being treated as an
absolute rule.

---

# 11. Reference Architectures

A reference architecture provides an approved model for a recurring problem.

Examples include:

- Secure branch office
- Highly available application platform
- Hybrid identity
- Enterprise landing zone
- Kubernetes platform
- Backup and recovery
- Administrative access
- Observability platform

Reference architectures reduce repeated design effort while preserving room for
solution-specific decisions.

---

# 12. Architecture Building Blocks

Building blocks are reusable capabilities or components.

Examples include:

- Identity provider
- Certificate service
- DNS service
- Network segment
- Load balancer
- Logging pipeline
- Backup service
- Virtualization cluster
- Cloud account
- Automation runner

Building blocks should have defined interfaces, ownership, service levels, and
lifecycle status.

---

# 13. Logical and Physical Architecture

Logical architecture explains responsibilities and relationships without
binding every element to a specific product or location.

Physical architecture maps those responsibilities to actual platforms,
devices, regions, sites, clusters, and networks.

Keeping both views prevents implementation detail from obscuring architectural
intent.

---

# 14. Dependencies and Interfaces

Architectures should make dependencies explicit.

For each dependency, document:

- Provider
- Consumer
- Interface
- Protocol
- Authentication
- Data exchanged
- Availability expectation
- Failure behavior
- Monitoring
- Owner
- Versioning

Interfaces are architecture boundaries and should be managed accordingly.

---

# 15. Quality Attributes

Quality attributes describe how well a system must operate.

Common attributes include:

- Availability
- Recoverability
- Performance
- Scalability
- Security
- Maintainability
- Interoperability
- Portability
- Observability
- Supportability
- Usability
- Cost efficiency

Tradeoffs between attributes should be recorded rather than hidden.

---

# 16. Risk and Tradeoff Analysis

Architecture is the management of tradeoffs under constraints.

A decision record should explain:

- Options considered
- Evaluation criteria
- Benefits
- Costs
- Risks
- Dependencies
- Reversibility
- Chosen option
- Rejected alternatives
- Review date

The goal is not to eliminate every risk. The goal is to make risk visible and
owned.

---

# 17. Architecture Decision Records

Architecture decision records preserve significant choices.

A practical record includes:

```markdown
# ADR-0007: Adopt a Regional Hub Network Model

## Status
Accepted

## Context
The organization requires controlled connectivity between cloud regions,
on-premises sites, and shared security services.

## Decision
Use a regional hub model with centrally governed transit and local spoke
networks.

## Consequences
Shared routing and inspection become critical services. Regional teams consume
standard connectivity patterns and cannot create unmanaged transitive paths.
```

Decision records should be stored with the system or repository they govern.

---

# 18. Architecture Governance

Governance ensures decisions remain aligned over time.

Mechanisms include:

- Architecture review boards
- Peer design reviews
- Standards catalogs
- Decision records
- Exception management
- Compliance automation
- Technology lifecycle reviews
- Reference architectures
- Design checkpoints
- Operational-readiness reviews

Governance should accelerate safe decisions rather than create undocumented
approval queues.

---

# 19. Architecture Review

A practical architecture review evaluates:

## Alignment

- Does the design support required outcomes?
- Are capabilities and services explicit?

## Structure

- Are boundaries, dependencies, and interfaces clear?
- Are current and target states distinguished?

## Quality

- Are availability, recovery, performance, security, and supportability
  measurable?

## Risk

- Are assumptions and constraints validated?
- Are major tradeoffs and exceptions recorded?

## Operations

- Are monitoring, ownership, support, backup, and recovery defined?

## Transition

- Can the organization move from current to target through controlled stages?

The review should produce decisions and actions, not only comments.

---

# 20. Enterprise Architecture Anti-Patterns

Common anti-patterns include:

- Product-first architecture
- Diagrams without decisions
- Target state without transition states
- Standards without ownership
- Exceptions without expiration
- Hidden assumptions
- Unmeasured quality attributes
- Architecture disconnected from operations
- Repeated decisions without records
- Governance based only on meetings
- Technology retained without lifecycle status
- Reference architectures that are never validated

Recognizing these patterns improves architecture maturity.

---

# 21. Architecture Repository

Architecture artifacts should be version controlled.

A practical structure is:

```text
docs/
└── architecture/
    ├── principles/
    ├── standards/
    ├── reference-architectures/
    ├── current-state/
    ├── target-state/
    ├── transition-states/
    ├── decisions/
    ├── diagrams/
    └── reviews/
```

The repository should identify artifact owners and review dates.

---

# 22. Chapter Lab

## Objective

Create a practical enterprise architecture package for one infrastructure
service.

## Tasks

1. Select an infrastructure service.
2. Identify stakeholders and concerns.
3. Define business outcomes and required capabilities.
4. Record requirements, assumptions, and constraints.
5. Document the current state.
6. Define the target state.
7. Create at least one transition state.
8. Produce context, logical, physical, trust-boundary, and operational views.
9. Identify dependencies and interfaces.
10. Define measurable quality attributes.
11. Record two significant architecture decisions.
12. Identify risks and owners.
13. Define applicable standards, patterns, and guardrails.
14. Conduct an architecture review.
15. Create a prioritized transition roadmap.

## Completion Criteria

The lab is complete when:

- Strategy and outcomes trace to technical capabilities.
- Stakeholders and concerns are explicit.
- Current, transition, and target states are documented.
- Dependencies and interfaces have owners.
- Quality attributes are measurable.
- Significant tradeoffs are recorded.
- Risks and exceptions have accountable owners.
- The transition roadmap is executable.

---

# Review Questions

1. What is the purpose of enterprise architecture?
2. How do enterprise and solution architecture differ?
3. Why should strategy trace to infrastructure capabilities?
4. What is the difference between a viewpoint and a view?
5. Why are transition states necessary?
6. What makes an architecture principle useful?
7. How do standards, patterns, guardrails, and guidelines differ?
8. What is a reference architecture?
9. Why should dependencies and interfaces be explicit?
10. What are quality attributes?
11. Why must architecture document tradeoffs?
12. What belongs in an architecture decision record?
13. How should architecture governance support engineering teams?
14. Which artifacts are required for an architecture review?
15. Why should architecture artifacts be version controlled?

---

# Key Takeaways

- Enterprise architecture connects strategy, capabilities, services,
  information, applications, infrastructure, security, and operations.
- Architecture is a decision system, not merely a collection of diagrams.
- Current, transition, and target states make change executable.
- Principles, standards, patterns, and guardrails guide repeated decisions.
- Quality attributes and tradeoffs must be explicit and measurable.
- Dependencies, interfaces, assumptions, risks, and ownership require
  documentation.
- Architecture decision records preserve context and consequences.
- Governance should accelerate safe, consistent engineering.
- Architecture artifacts belong in version control and require lifecycle
  ownership.

---

# Chapter Summary

Enterprise architecture provides the structure needed to translate strategy
into coordinated technical change.

In this chapter, you learned how architecture operates across enterprise,
domain, solution, infrastructure, and technical-design levels. You connected
outcomes to capabilities and technology, organized architecture into business,
data, application, technology, and security domains, and used viewpoints to
address different stakeholder concerns.

You also learned how principles, standards, patterns, guardrails, reference
architectures, building blocks, quality attributes, decision records, and
governance support consistent engineering. Finally, you developed a practical
review and lab process for documenting current, transition, and target states.

The next chapter, **Infrastructure Lifecycle Management**, applies these
architecture foundations across planning, acquisition, deployment, operation,
improvement, and retirement.
CHAPTER_EOF
  log "Generated structured Chapter 7 manuscript."
fi

# Insert the Chapter 7 links exactly once, immediately after Chapter 6.
python3 - "$VOLUME_TOC" "$MASTER_TOC" <<'PY'
from pathlib import Path
import sys

volume_path = Path(sys.argv[1])
master_path = Path(sys.argv[2])

volume_entry = (
    "7. [Enterprise Architecture Fundamentals]"
    "(chapters/07-enterprise-architecture-fundamentals.md)"
)
master_entry = (
    "   - [Chapter 7 — Enterprise Architecture Fundamentals]"
    "(volumes/volume-01-enterprise-engineering-foundations/chapters/"
    "07-enterprise-architecture-fundamentals.md)"
)

def update(path: Path, anchor: str, entry: str) -> None:
    if not path.exists():
        raise SystemExit(f"Missing required TOC: {path}")

    lines = path.read_text(encoding="utf-8").splitlines()
    lines = [
        line for line in lines
        if "07-enterprise-architecture-fundamentals.md" not in line
    ]

    indexes = [i for i, line in enumerate(lines) if anchor in line]
    if not indexes:
        raise SystemExit(f"Chapter 6 anchor missing from {path}")

    lines.insert(indexes[-1] + 1, entry)
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")

update(
    volume_path,
    "06-understanding-enterprise-infrastructure.md",
    volume_entry,
)
update(
    master_path,
    "06-understanding-enterprise-infrastructure.md",
    master_entry,
)
PY

grep -Fq '# Chapter 7' "$CHAPTER_PATH" ||
  die "Chapter 7 numbered heading is missing"
grep -Fq "$CHAPTER_TITLE" "$CHAPTER_PATH" ||
  die "Chapter 7 title is missing"

[[ "$(grep -Fc '07-enterprise-architecture-fundamentals.md' "$VOLUME_TOC")" -eq 1 ]] ||
  die "Volume I README must contain exactly one Chapter 7 reference"
[[ "$(grep -Fc '07-enterprise-architecture-fundamentals.md' "$MASTER_TOC")" -eq 1 ]] ||
  die "MASTER_TOC.md must contain exactly one Chapter 7 reference"

git diff --check

if command -v markdownlint >/dev/null 2>&1; then
  if ! markdownlint "$CHAPTER_PATH" "$VOLUME_TOC" "$MASTER_TOC"; then
    if [[ "$STRICT_LINT" == true ]]; then
      die "Markdown linting failed."
    fi
    warn "Markdown linting reported findings; continuing without --strict-lint."
  fi
else
  log "markdownlint is not installed; Markdown linting skipped."
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/chapter07-workflow.XXXXXX")"

if [[ "$LOCAL_ONLY" != true ]]; then
  ISSUE_BODY="$TMP_DIR/issue.md"
  cat > "$ISSUE_BODY" <<EOF_ISSUE
## Objective

Create Volume I, Chapter 7 — **$CHAPTER_TITLE**.

## Canonical path

- \`$CHAPTER_PATH\`

## Scope

- Enterprise, domain, solution, infrastructure, and technical architecture
- Strategy, capabilities, stakeholders, requirements, assumptions, and constraints
- Architecture domains, viewpoints, current state, transition states, and target state
- Principles, standards, patterns, guardrails, and reference architectures
- Building blocks, dependencies, interfaces, quality attributes, and tradeoffs
- Architecture decision records, governance, review, lab, and exercises

## Acceptance criteria

- [ ] Chapter 7 exists at the canonical Volume I path
- [ ] Volume I README lists Chapters 1–7 in order
- [ ] MASTER_TOC.md lists Chapters 1–7 under Volume I
- [ ] Chapter and workflow validation pass
- [ ] Pull request is merged into main
EOF_ISSUE

  if [[ -n "$LABEL" ]] &&
     ! gh label list --repo "$REPO" --limit 200 --json name \
       --jq '.[].name' | grep -Fxq "$LABEL"; then
    log "Creating GitHub label: $LABEL"
    gh label create "$LABEL" \
      --repo "$REPO" \
      --description "Tracks book chapter work" \
      --color "1D76DB"
  fi

  ISSUE_RECORD="$(
    gh issue list \
      --repo "$REPO" \
      --state all \
      --limit 200 \
      --json number,state,title,url |
      jq -c --arg title "$ISSUE_TITLE" \
        'map(select(.title == $title)) | sort_by(.number) | last // empty'
  )"

  if [[ -n "$ISSUE_RECORD" ]]; then
    ISSUE_NUMBER="$(jq -r '.number' <<<"$ISSUE_RECORD")"
    ISSUE_STATE="$(jq -r '.state' <<<"$ISSUE_RECORD")"
    ISSUE_URL="$(jq -r '.url' <<<"$ISSUE_RECORD")"

    if [[ "$ISSUE_STATE" == "CLOSED" ]]; then
      log "Reopening existing issue #$ISSUE_NUMBER."
      gh issue reopen "$ISSUE_NUMBER" --repo "$REPO" >/dev/null
    else
      log "Reusing open issue: $ISSUE_URL"
    fi
  else
    ISSUE_ARGS=(
      --repo "$REPO"
      --title "$ISSUE_TITLE"
      --body-file "$ISSUE_BODY"
      --assignee "$ASSIGNEE"
    )
    [[ -n "$LABEL" ]] && ISSUE_ARGS+=(--label "$LABEL")

    ISSUE_URL="$(gh issue create "${ISSUE_ARGS[@]}")"
    ISSUE_NUMBER="${ISSUE_URL##*/}"
    log "Issue created: $ISSUE_URL"
  fi

  if [[ "$SKIP_PROJECT" != true ]]; then
    PROJECTS_JSON="$(
      gh project list \
        --owner "$PROJECT_OWNER" \
        --limit 100 \
        --format json
    )"

    PROJECT_NUMBER="$(
      jq -r --arg title "$PROJECT_TITLE" \
        '.projects[]? | select(.title == $title) | .number' \
        <<<"$PROJECTS_JSON" | head -n1
    )"
    PROJECT_ID="$(
      jq -r --arg title "$PROJECT_TITLE" \
        '.projects[]? | select(.title == $title) | .id' \
        <<<"$PROJECTS_JSON" | head -n1
    )"

    if [[ -z "$PROJECT_NUMBER" || "$PROJECT_NUMBER" == "null" ]]; then
      warn "GitHub Project '$PROJECT_TITLE' was not found; continuing without it."
      SKIP_PROJECT=true
    else
      ITEMS_JSON="$(
        gh project item-list "$PROJECT_NUMBER" \
          --owner "$PROJECT_OWNER" \
          --limit 1000 \
          --format json
      )"

      PROJECT_ITEM_ID="$(
        jq -r --arg url "$ISSUE_URL" \
          '.items[]? | select(.content.url == $url) | .id' \
          <<<"$ITEMS_JSON" | head -n1
      )"

      if [[ -z "$PROJECT_ITEM_ID" || "$PROJECT_ITEM_ID" == "null" ]]; then
        ITEM_JSON="$(
          gh project item-add "$PROJECT_NUMBER" \
            --owner "$PROJECT_OWNER" \
            --url "$ISSUE_URL" \
            --format json
        )"
        PROJECT_ITEM_ID="$(
          jq -r '.id // .item.id // empty' <<<"$ITEM_JSON"
        )"
        log "Added Chapter 7 issue to GitHub Project."
      else
        log "Chapter 7 issue is already present in the GitHub Project."
      fi

      set_project_status "$PROJECT_START_STATUS"
    fi
  fi
fi

STAGE_PATHS=("$CHAPTER_PATH" "$VOLUME_TOC" "$MASTER_TOC")
if [[ -n "$SCRIPT_REL" && -f "$SCRIPT_REL" ]]; then
  STAGE_PATHS+=("$SCRIPT_REL")
fi

git add -- "${STAGE_PATHS[@]}"
git diff --cached --check

if git diff --cached --quiet; then
  log "No new Chapter 7 changes require a commit."
else
  git commit -m "$COMMIT_MESSAGE"
  log "Created Chapter 7 commit."
fi

if [[ "$LOCAL_ONLY" == true ]]; then
  printf '\nRESULT: CHAPTER 7 CREATED LOCALLY\n'
  printf 'Branch:  %s\n' "$(git branch --show-current)"
  printf 'Chapter: %s\n' "$CHAPTER_PATH"
  exit 0
fi

log "Pushing Chapter 7 branch."
git push -u "$REMOTE" "$BRANCH_NAME"

PR_RECORD="$(
  gh pr list \
    --repo "$REPO" \
    --state all \
    --base "$BASE_BRANCH" \
    --head "$BRANCH_NAME" \
    --limit 100 \
    --json number,state,title,url \
    --jq 'sort_by(.number) | last // empty'
)"

if [[ -n "$PR_RECORD" ]]; then
  PR_NUMBER="$(jq -r '.number' <<<"$PR_RECORD")"
  PR_STATE="$(jq -r '.state' <<<"$PR_RECORD")"
  PR_URL="$(jq -r '.url' <<<"$PR_RECORD")"

  case "$PR_STATE" in
    OPEN)
      log "Reusing open pull request: $PR_URL"
      ;;
    CLOSED)
      log "Reopening pull request #$PR_NUMBER."
      gh pr reopen "$PR_NUMBER" --repo "$REPO" >/dev/null
      ;;
    MERGED)
      log "Pull request #$PR_NUMBER is already merged; continuing with verification."
      ;;
  esac
else
  PR_BODY="$TMP_DIR/pr.md"
  cat > "$PR_BODY" <<EOF_PR
## Summary

Creates Volume I, Chapter 7 — **$CHAPTER_TITLE**.

## Changes

- Adds \`$CHAPTER_PATH\`
- Updates \`$VOLUME_TOC\`
- Updates \`$MASTER_TOC\`
- Adds the reusable Chapter 7 workflow script

## Validation

- Git whitespace validation passed
- Chapter heading and title validated
- Both TOCs contain exactly one Chapter 7 link

Closes #$ISSUE_NUMBER
EOF_PR

  PR_URL="$(
    gh pr create \
      --repo "$REPO" \
      --base "$BASE_BRANCH" \
      --head "$BRANCH_NAME" \
      --title "$PR_TITLE" \
      --body-file "$PR_BODY"
  )"
  PR_NUMBER="${PR_URL##*/}"
  PR_STATE="OPEN"
  log "Pull request created: $PR_URL"
fi

if [[ "$PR_STATE" != "MERGED" ]]; then
  PR_JSON="$(
    gh pr view "$PR_NUMBER" \
      --repo "$REPO" \
      --json state,headRefName,baseRefName,mergeable,mergeStateStatus,url,title
  )"

  PR_HEAD="$(jq -r '.headRefName' <<<"$PR_JSON")"
  PR_BASE="$(jq -r '.baseRefName' <<<"$PR_JSON")"
  PR_MERGEABLE="$(jq -r '.mergeable' <<<"$PR_JSON")"
  PR_MERGE_STATE="$(jq -r '.mergeStateStatus' <<<"$PR_JSON")"

  [[ "$PR_HEAD" == "$BRANCH_NAME" ]] ||
    die "Pull request head is '$PR_HEAD'; expected '$BRANCH_NAME'"
  [[ "$PR_BASE" == "$BASE_BRANCH" ]] ||
    die "Pull request base is '$PR_BASE'; expected '$BASE_BRANCH'"

  EXPECTED_FILES="$TMP_DIR/expected-files.txt"
  PR_FILES="$TMP_DIR/pr-files.txt"
  EXTRA_FILES="$TMP_DIR/extra-files.txt"
  MISSING_FILES="$TMP_DIR/missing-files.txt"

  {
    printf '%s\n' "$MASTER_TOC"
    printf '%s\n' "$VOLUME_TOC"
    printf '%s\n' "$CHAPTER_PATH"
    [[ -n "$SCRIPT_REL" ]] && printf '%s\n' "$SCRIPT_REL"
  } | sort -u > "$EXPECTED_FILES"

  gh pr diff "$PR_NUMBER" \
    --repo "$REPO" \
    --name-only |
    sort -u > "$PR_FILES"

  comm -23 "$PR_FILES" "$EXPECTED_FILES" > "$EXTRA_FILES"
  comm -13 "$PR_FILES" "$EXPECTED_FILES" > "$MISSING_FILES"

  printf '\nPull-request files\n'
  sed 's/^/  /' "$PR_FILES"

  if [[ -s "$MISSING_FILES" ]]; then
    printf '\nMissing expected files:\n' >&2
    sed 's/^/  /' "$MISSING_FILES" >&2
    die "The Chapter 7 pull request is incomplete."
  fi

  if [[ -s "$EXTRA_FILES" ]]; then
    printf '\nUnexpected pull-request files:\n' >&2
    sed 's/^/  /' "$EXTRA_FILES" >&2

    if [[ "$ALLOW_EXTRA_FILES" != true ]]; then
      die "Refusing unexpected files. Review them or use --allow-extra-files."
    fi

    warn "Proceeding with extra files because --allow-extra-files was supplied."
  fi

  case "$PR_MERGEABLE" in
    CONFLICTING)
      die "The Chapter 7 pull request has merge conflicts."
      ;;
    UNKNOWN)
      warn "GitHub has not finished calculating pull-request mergeability."
      ;;
  esac

  case "$PR_MERGE_STATE" in
    DIRTY)
      die "The Chapter 7 pull request has merge conflicts."
      ;;
    BLOCKED)
      warn "The pull request is blocked by a review, rule, or status check."
      ;;
    BEHIND)
      warn "The pull request is behind main; GitHub may require an update."
      ;;
  esac

  CHECK_OUTPUT="$TMP_DIR/checks.txt"
  if gh pr checks "$PR_NUMBER" --repo "$REPO" >"$CHECK_OUTPUT" 2>&1; then
    cat "$CHECK_OUTPUT"
  elif grep -qiE 'no checks|no check runs|no status checks' "$CHECK_OUTPUT"; then
    cat "$CHECK_OUTPUT"
    warn "No pull-request checks are configured; continuing with content validation."
  else
    cat "$CHECK_OUTPUT" >&2
    die "One or more required pull-request checks have not passed."
  fi

  log "Merging pull request #$PR_NUMBER using '$MERGE_METHOD'."
  case "$MERGE_METHOD" in
    merge)
      gh pr merge "$PR_NUMBER" --repo "$REPO" --merge
      ;;
    squash)
      gh pr merge "$PR_NUMBER" --repo "$REPO" --squash
      ;;
    rebase)
      gh pr merge "$PR_NUMBER" --repo "$REPO" --rebase
      ;;
  esac
fi

log "Refreshing origin after merge."
git fetch "$REMOTE" --prune
verify_remote_content

# Verify that no Chapter 7 content remains unmerged.
if git rev-parse --verify "$REMOTE/$BRANCH_NAME^{commit}" >/dev/null 2>&1; then
  AHEAD_COUNT="$(
    git rev-list --count "$REMOTE/$BASE_BRANCH..$REMOTE/$BRANCH_NAME"
  )"

  if [[ "$AHEAD_COUNT" -eq 0 ]]; then
    printf 'PASS: Chapter 7 branch has no commits missing from main\n'
  elif git diff --quiet \
      "$REMOTE/$BASE_BRANCH" \
      "$REMOTE/$BRANCH_NAME" \
      -- "$MASTER_TOC" "$VOLUME_TOC" "$CHAPTER_PATH" ${SCRIPT_REL:+"$SCRIPT_REL"}; then
    printf 'PASS: Chapter 7 content matches main despite non-ancestor history\n'
    warn "This is consistent with a squash or rebase merge."
  else
    die "The Chapter 7 branch still differs from main after merge."
  fi
fi

set_project_status "$PROJECT_FINAL_STATUS"

printf '\nLocal main synchronization\n'
if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
  die "The working tree is not clean; refusing to switch and update main."
fi

git switch "$BASE_BRANCH"
git pull --ff-only "$REMOTE" "$BASE_BRANCH"

DIVERGENCE="$(
  git rev-list --left-right --count "$REMOTE/$BASE_BRANCH...$BASE_BRANCH"
)"
REMOTE_ONLY="$(awk '{print $1}' <<<"$DIVERGENCE")"
LOCAL_ONLY_COUNT="$(awk '{print $2}' <<<"$DIVERGENCE")"

[[ "$REMOTE_ONLY" == "0" && "$LOCAL_ONLY_COUNT" == "0" ]] ||
  die "Local main does not match origin/main"

printf 'PASS: Local main matches origin/main\n'

if [[ "$KEEP_BRANCH" != true ]]; then
  printf '\nBranch cleanup\n'

  if git rev-parse --verify "$REMOTE/$BRANCH_NAME^{commit}" >/dev/null 2>&1; then
    git push "$REMOTE" --delete "$BRANCH_NAME"
    printf 'PASS: Deleted remote Chapter 7 branch\n'
  else
    printf 'PASS: Remote Chapter 7 branch is already absent\n'
  fi

  if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    git branch -D "$BRANCH_NAME"
    printf 'PASS: Deleted local Chapter 7 branch\n'
  else
    printf 'PASS: Local Chapter 7 branch is already absent\n'
  fi

  git fetch "$REMOTE" --prune
fi

printf '\nRESULT: CHAPTER 7 CREATED, MERGED, AND VERIFIED\n'
printf 'Chapter:      %s\n' "$CHAPTER_PATH"
printf 'Pull request: #%s\n' "$PR_NUMBER"
printf 'GitHub main:  %s/%s\n' "$REMOTE" "$BASE_BRANCH"

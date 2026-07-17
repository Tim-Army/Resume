#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
  pwd
)"

show_help() {
  cat <<'HELP'
create-resume-project.sh

Compatibility wrapper for the Tim-Fox-Resume automation scripts.

Usage:
  create-resume-project.sh repo [options]
  create-resume-project.sh resume [options]
  create-resume-project.sh --help

Commands:
  repo      Run create-tim-fox-resume-repo.sh.
  resume    Run create-tim-fox-resume.sh.

Examples:
  ./scripts/bash/create-resume-project.sh repo --help
  ./scripts/bash/create-resume-project.sh resume --skip-script-move
HELP
}

case "${1:-}" in
  repo|--repo)
    shift
    exec "${SCRIPT_DIR}/create-tim-fox-resume-repo.sh" "$@"
    ;;

  resume|--resume)
    shift
    exec "${SCRIPT_DIR}/create-tim-fox-resume.sh" "$@"
    ;;

  -h|--help|"")
    show_help
    ;;

  *)
    printf 'ERROR: Unknown command: %s\n\n' "$1" >&2
    show_help >&2
    exit 2
    ;;
esac

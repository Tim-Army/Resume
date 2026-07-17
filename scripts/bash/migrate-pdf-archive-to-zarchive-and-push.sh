#!/usr/bin/env bash
set -euo pipefail

PROGRAM_NAME="migrate-pdf-archive-to-zarchive-and-push.sh"
DEFAULT_REPO="${HOME}/Documents/github/Tim-Fox-Resume"
REPO_DIR="${DEFAULT_REPO}"
DO_COMMIT=true
DO_PUSH=true
OPEN_REPO=false
COMMIT_MESSAGE="chore: migrate PDF archive to zArchive"

log() {
  printf '[Tim-Fox-Resume] %s\n' "$*"
}

error() {
  printf '[Tim-Fox-Resume] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
migrate-pdf-archive-to-zarchive-and-push.sh

Migrates archived PDFs from pdf/Archive to pdf/zArchive, removes the old
folder when empty, and regenerates the PDF backup helper so all future
backups use pdf/zArchive.

Usage:
  migrate-pdf-archive-to-zarchive-and-push.sh [options]

Options:
  --repo PATH         Repository path.
  --message TEXT      Git commit message.
  --no-commit         Make changes without creating a commit.
  --no-push           Commit locally without pushing.
  --open              Open the repository page after a successful push.
  -h, --help          Show this help.

Backup naming:
  pdf/zArchive/NAME-YYYYMMDD.pdf

Same-day conflicts are retained as:
  NAME-YYYYMMDD-2.pdf
  NAME-YYYYMMDD-3.pdf
EOF
}

while (($#)); do
  case "$1" in
    --repo)
      (($# >= 2)) || error "--repo requires a path."
      REPO_DIR="$2"
      shift 2
      ;;
    --message)
      (($# >= 2)) || error "--message requires text."
      COMMIT_MESSAGE="$2"
      shift 2
      ;;
    --no-commit)
      DO_COMMIT=false
      DO_PUSH=false
      shift
      ;;
    --no-push)
      DO_PUSH=false
      shift
      ;;
    --open)
      OPEN_REPO=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      ;;
  esac
done

command -v git >/dev/null 2>&1 || error "git is required."
command -v python3 >/dev/null 2>&1 || error "python3 is required."

[[ -d "${REPO_DIR}" ]] || error "Repository directory does not exist: ${REPO_DIR}"
REPO_DIR="$(cd "${REPO_DIR}" && pwd -P)"
git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || error "Not a Git repository: ${REPO_DIR}"

GIT_ROOT="$(git -C "${REPO_DIR}" rev-parse --show-toplevel)"
[[ "${GIT_ROOT}" == "${REPO_DIR}" ]] \
  || error "Expected repository root ${REPO_DIR}, but Git reports ${GIT_ROOT}"

SCRIPTS_DIR="${REPO_DIR}/scripts/bash"
PDF_DIR="${REPO_DIR}/pdf"
OLD_ARCHIVE="${PDF_DIR}/Archive"
NEW_ARCHIVE="${PDF_DIR}/zArchive"
CANONICAL_SCRIPT="${SCRIPTS_DIR}/${PROGRAM_NAME}"
SOURCE_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"

mkdir -p "${SCRIPTS_DIR}" "${PDF_DIR}" "${NEW_ARCHIVE}"
touch "${NEW_ARCHIVE}/.gitkeep"

if [[ "${SOURCE_SCRIPT}" != "${CANONICAL_SCRIPT}" ]]; then
  cp "${SOURCE_SCRIPT}" "${CANONICAL_SCRIPT}"
  chmod +x "${CANONICAL_SCRIPT}"
  log "Installed canonical migration script: scripts/bash/${PROGRAM_NAME}"
fi

move_with_conflict_protection() {
  local source_file="$1"
  local relative_path destination_dir destination_file stem extension counter

  relative_path="${source_file#${OLD_ARCHIVE}/}"
  destination_dir="${NEW_ARCHIVE}/$(dirname "${relative_path}")"
  [[ "$(dirname "${relative_path}")" == "." ]] && destination_dir="${NEW_ARCHIVE}"
  mkdir -p "${destination_dir}"

  destination_file="${destination_dir}/$(basename "${relative_path}")"

  if [[ ! -e "${destination_file}" ]]; then
    mv "${source_file}" "${destination_file}"
    log "Moved archive file: ${relative_path}"
    return
  fi

  if cmp -s "${source_file}" "${destination_file}"; then
    rm -f "${source_file}"
    log "Removed duplicate archive file: ${relative_path}"
    return
  fi

  extension=""
  stem="$(basename "${destination_file}")"
  if [[ "${stem}" == *.* ]]; then
    extension=".${stem##*.}"
    stem="${stem%.*}"
  fi

  counter=2
  while [[ -e "${destination_dir}/${stem}-${counter}${extension}" ]]; do
    ((counter++))
  done

  mv "${source_file}" "${destination_dir}/${stem}-${counter}${extension}"
  log "Moved conflicting archive file as: ${stem}-${counter}${extension}"
}

if [[ -d "${OLD_ARCHIVE}" ]]; then
  while IFS= read -r -d '' file; do
    move_with_conflict_protection "${file}"
  done < <(find "${OLD_ARCHIVE}" -type f -print0)

  find "${OLD_ARCHIVE}" -depth -type d -empty -delete

  if [[ -d "${OLD_ARCHIVE}" ]]; then
    error "pdf/Archive still contains unsupported non-file content."
  fi

  log "Removed empty legacy directory: pdf/Archive"
else
  log "Legacy directory pdf/Archive does not exist; no migration needed."
fi

cat > "${SCRIPTS_DIR}/archive-current-pdfs.sh" <<'ARCHIVE_HELPER'
#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:-${HOME}/Documents/github/Tim-Fox-Resume}"
PDF_DIR="${REPO_DIR}/pdf"
ARCHIVE_DIR="${PDF_DIR}/zArchive"
DATE_STAMP="$(date +%Y%m%d)"

log() {
  printf '[Tim-Fox-Resume] %s\n' "$*"
}

[[ -d "${REPO_DIR}" ]] || {
  printf '[Tim-Fox-Resume] ERROR: Repository not found: %s\n' "${REPO_DIR}" >&2
  exit 1
}

mkdir -p "${ARCHIVE_DIR}"
touch "${ARCHIVE_DIR}/.gitkeep"

archive_one_pdf() {
  local source="$1"
  local filename stem candidate counter

  filename="$(basename "${source}")"
  stem="${filename%.pdf}"
  candidate="${ARCHIVE_DIR}/${stem}-${DATE_STAMP}.pdf"

  if [[ -e "${candidate}" ]]; then
    if cmp -s "${source}" "${candidate}"; then
      log "Archive already contains identical PDF: ${candidate#${REPO_DIR}/}"
      return
    fi

    counter=2
    while [[ -e "${ARCHIVE_DIR}/${stem}-${DATE_STAMP}-${counter}.pdf" ]]; do
      if cmp -s "${source}" "${ARCHIVE_DIR}/${stem}-${DATE_STAMP}-${counter}.pdf"; then
        log "Archive already contains identical PDF: ${stem}-${DATE_STAMP}-${counter}.pdf"
        return
      fi
      ((counter++))
    done
    candidate="${ARCHIVE_DIR}/${stem}-${DATE_STAMP}-${counter}.pdf"
  fi

  cp -p "${source}" "${candidate}"
  log "Archived PDF: ${candidate#${REPO_DIR}/}"
}

found=false
while IFS= read -r -d '' pdf_file; do
  found=true
  archive_one_pdf "${pdf_file}"
done < <(find "${PDF_DIR}" -maxdepth 1 -type f -iname '*.pdf' -print0)

if [[ "${found}" == false ]]; then
  log "No top-level PDF files found to archive."
fi
ARCHIVE_HELPER

chmod +x "${SCRIPTS_DIR}/archive-current-pdfs.sh"

python3 - "${SCRIPTS_DIR}" <<'PY'
from pathlib import Path
import sys

scripts_dir = Path(sys.argv[1])
replacements = (
    ("pdf/Archive", "pdf/zArchive"),
    ("/pdf/Archive", "/pdf/zArchive"),
    ('${PDF_DIR}/Archive', '${PDF_DIR}/zArchive'),
)

for path in scripts_dir.iterdir():
    if not path.is_file() or path.suffix not in {".sh", ".bash"}:
        continue
    if path.name == "migrate-pdf-archive-to-zarchive-and-push.sh":
        continue
    text = path.read_text(encoding="utf-8")
    updated = text
    for old, new in replacements:
        updated = updated.replace(old, new)
    if updated != text:
        path.write_text(updated, encoding="utf-8")
PY

# Ensure known PDF generators call the shared backup helper before replacement.
for generator in \
  "${SCRIPTS_DIR}/condense-resume-to-three-pages-and-push.sh" \
  "${SCRIPTS_DIR}/download-resume-to-pdf-and-push.sh" \
  "${SCRIPTS_DIR}/standardize-resume-project-and-push.sh"
do
  [[ -f "${generator}" ]] || continue

  if ! grep -Eq 'PDF_(Z)?ARCHIVE_HOOK_V1' "${generator}"; then
    python3 - "${generator}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
hook = '''
# PDF_ZARCHIVE_HOOK_V1
if [[ -x "${REPO_DIR}/scripts/bash/archive-current-pdfs.sh" ]]; then
  "${REPO_DIR}/scripts/bash/archive-current-pdfs.sh" "${REPO_DIR}"
fi
# PDF_ZARCHIVE_HOOK_V1_END

'''

anchors = ('mkdir -p "${PDF_DIR}"', 'mkdir -p "$PDF_DIR"')
for anchor in anchors:
    idx = text.find(anchor)
    if idx != -1:
        line_end = text.find("\n", idx)
        if line_end == -1:
            line_end = len(text)
        text = text[:line_end + 1] + hook + text[line_end + 1:]
        break
else:
    strict = "set -euo pipefail\n"
    idx = text.find(strict)
    if idx == -1:
        text = hook + text
    else:
        idx += len(strict)
        text = text[:idx] + "\n" + hook + text[idx:]

path.write_text(text, encoding="utf-8")
PY
  fi
done

rm -f "${OLD_ARCHIVE}/.gitkeep" 2>/dev/null || true
rmdir "${OLD_ARCHIVE}" 2>/dev/null || true

[[ -d "${NEW_ARCHIVE}" ]] || error "pdf/zArchive was not created."
[[ ! -d "${OLD_ARCHIVE}" ]] || error "pdf/Archive still exists."

# Remove invalid timestamped conflict backups when a valid canonical script exists.
while IFS= read -r -d '' candidate; do
  if bash -n "${candidate}" >/dev/null 2>&1; then
    continue
  fi

  filename="$(basename "${candidate}")"
  canonical_name="$(printf '%s' "${filename}" | sed -E 's/-[0-9]{8}-[0-9]{6}(\.(sh|bash))$/\1/')"
  canonical_path="${SCRIPTS_DIR}/${canonical_name}"

  if [[ "${canonical_path}" != "${candidate}" && -f "${canonical_path}" ]]     && bash -n "${canonical_path}" >/dev/null 2>&1; then
    rm -f "${candidate}"
    log "Removed invalid timestamped backup: scripts/bash/${filename}"
  fi
done < <(
  find "${SCRIPTS_DIR}" -maxdepth 1 -type f     \( -name '*.sh' -o -name '*.bash' \) -print0
)

if find "${SCRIPTS_DIR}" -maxdepth 1 -type f   \( -name '*.sh' -o -name '*.bash' \)   ! -name "${PROGRAM_NAME}" -print0   | xargs -0 grep -Il 'pdf/Archive' 2>/dev/null   | grep -q .; then
  error "At least one project script still references pdf/Archive."
fi

validation_failed=false
while IFS= read -r -d '' script_file; do
  if bash -n "${script_file}"; then
    log "PASS: Bash syntax: ${script_file#${REPO_DIR}/}."
  else
    log "WARNING: FAIL: Bash syntax: ${script_file#${REPO_DIR}/}."
    validation_failed=true
  fi
done < <(
  find "${SCRIPTS_DIR}" -maxdepth 1 -type f \
    \( -name '*.sh' -o -name '*.bash' \) -print0
)

if [[ "${validation_failed}" == true ]]; then
  error "One or more canonical project scripts failed Bash syntax validation."
fi

log "PASS: pdf/zArchive is the only configured PDF backup directory."

if [[ "${DO_COMMIT}" == false ]]; then
  log "Changes completed without a Git commit (--no-commit)."
  exit 0
fi

git -C "${REPO_DIR}" add -A -- pdf scripts/bash

if git -C "${REPO_DIR}" diff --cached --quiet; then
  log "No changes to commit."
else
  git -C "${REPO_DIR}" commit -m "${COMMIT_MESSAGE}"
  log "Created Git commit."
fi

if [[ "${DO_PUSH}" == true ]]; then
  current_branch="$(git -C "${REPO_DIR}" branch --show-current)"
  [[ -n "${current_branch}" ]] || error "Cannot push from a detached HEAD."
  git -C "${REPO_DIR}" push -u origin "${current_branch}"
  log "Pushed ${current_branch} to origin."
fi

if [[ "${OPEN_REPO}" == true ]]; then
  if command -v gh >/dev/null 2>&1; then
    (cd "${REPO_DIR}" && gh repo view --web) || true
  else
    log "GitHub CLI is not installed; skipping --open."
  fi
fi

if [[ "${SOURCE_SCRIPT}" != "${CANONICAL_SCRIPT}" && -f "${SOURCE_SCRIPT}" ]]; then
  rm -f "${SOURCE_SCRIPT}"
  log "Removed downloaded migration script after canonical installation."
fi

log "Complete."
log "PDF archive: ${NEW_ARCHIVE}"

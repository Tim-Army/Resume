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

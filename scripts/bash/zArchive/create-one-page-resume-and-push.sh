#!/usr/bin/env bash
#
# Create and publish Tim Fox's one-page resume.
#
# Canonical repository location:
#   $HOME/Documents/github/Tim-Fox-Resume/scripts/bash
#
# Outputs:
#   resume/master/Tim-Fox-Resume-one-page.md
#   pdf/Tim-Fox-Concise-Resume.pdf
#

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2026.07.17.1"
readonly SCRIPT_NAME="create-one-page-resume-and-push.sh"
readonly DEFAULT_REPO="$HOME/Documents/github/Tim-Fox-Resume"
readonly MARKDOWN_REL="resume/master/Tim-Fox-Resume-one-page.md"
readonly PDF_REL="pdf/Tim-Fox-Concise-Resume.pdf"
readonly SCRIPT_REL="scripts/bash/$SCRIPT_NAME"
readonly HEADER="United States | Open to Remote and Onsite Roles | timfox2025@tim.army | https://github.com/derg20"

REPO_ROOT="$DEFAULT_REPO"
COMMIT_CHANGES=true
PUSH_CHANGES=true
OPEN_PDF=false
COMMIT_MESSAGE="docs: publish one-page resume"
SOURCE_SCRIPT=""
TEMP_SELF=""
VENV_DIR=""

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
  [[ -n "$TEMP_SELF" && -f "$TEMP_SELF" ]] && rm -f "$TEMP_SELF" || true
  [[ -n "$VENV_DIR" && -d "$VENV_DIR" ]] && rm -rf "$VENV_DIR" || true
  return 0
}
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Create and publish Tim Fox's one-page resume.

Usage:
  create-one-page-resume-and-push.sh [options]

Options:
  --repo PATH       Tim-Fox-Resume repository root.
                    Default: ~/Documents/github/Tim-Fox-Resume
  --no-commit       Update files without creating a Git commit.
  --no-push         Commit locally without pushing to GitHub.
  --message TEXT    Git commit message.
  --open            Open the generated PDF on macOS.
  --version         Display the script version.
  -h, --help        Display this help text.

Files created or updated:
  resume/master/Tim-Fox-Resume-one-page.md
  pdf/Tim-Fox-Concise-Resume.pdf
  scripts/bash/create-one-page-resume-and-push.sh

Before PDF generation, all current top-level files in pdf/ are backed up to:
  pdf/zArchive/*-YYYYMMDD.pdf
USAGE
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fatal "Required command not found: $1"
}

absolute_path() {
  local path="$1"

  if [[ "$path" == "~/"* ]]; then
    path="$HOME/${path#~/}"
  fi

  if [[ "$path" != /* ]]; then
    path="$PWD/$path"
  fi

  local parent base
  parent=$(dirname "$path")
  base=$(basename "$path")
  [[ -d "$parent" ]] || mkdir -p "$parent"
  parent=$(cd "$parent" && pwd -P)
  printf '%s/%s\n' "$parent" "$base"
}

capture_self() {
  SOURCE_SCRIPT=$(absolute_path "${BASH_SOURCE[0]}")
  TEMP_SELF=$(mktemp "${TMPDIR:-/tmp}/one-page-resume.XXXXXX")
  cp "$SOURCE_SCRIPT" "$TEMP_SELF"
  chmod 0755 "$TEMP_SELF"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        [[ $# -ge 2 ]] || fatal "--repo requires a path."
        REPO_ROOT="$2"
        shift 2
        ;;
      --no-commit)
        COMMIT_CHANGES=false
        PUSH_CHANGES=false
        shift
        ;;
      --no-push)
        PUSH_CHANGES=false
        shift
        ;;
      --message)
        [[ $# -ge 2 ]] || fatal "--message requires text."
        COMMIT_MESSAGE="$2"
        shift 2
        ;;
      --open)
        OPEN_PDF=true
        shift
        ;;
      --version)
        printf '%s\n' "$SCRIPT_VERSION"
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

validate_repo() {
  REPO_ROOT=$(absolute_path "$REPO_ROOT")
  git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fatal "Not a Git repository: $REPO_ROOT"

  local top
  top=$(git -C "$REPO_ROOT" rev-parse --show-toplevel)
  REPO_ROOT=$(cd "$top" && pwd -P)

  [[ "$(basename "$REPO_ROOT")" == "Tim-Fox-Resume" ]] \
    || warn "Repository directory is named '$(basename "$REPO_ROOT")'."
}

install_script() {
  local destination="$REPO_ROOT/$SCRIPT_REL"
  mkdir -p "$(dirname "$destination")"

  if [[ ! -f "$destination" ]] || ! cmp -s "$TEMP_SELF" "$destination"; then
    cp "$TEMP_SELF" "$destination"
    chmod 0755 "$destination"
    log "Installed canonical script: $SCRIPT_REL"
  else
    chmod 0755 "$destination"
    log "Canonical script is already current."
  fi
}

archive_current_pdfs_fallback() {
  local pdf_dir="$REPO_ROOT/pdf"
  local archive_dir="$pdf_dir/zArchive"
  local date_stamp
  date_stamp=$(date +%Y%m%d)

  mkdir -p "$archive_dir"
  touch "$archive_dir/.gitkeep"

  local found=false pdf_file filename stem candidate counter
  while IFS= read -r -d '' pdf_file; do
    found=true
    filename=$(basename "$pdf_file")
    stem=${filename%.pdf}
    candidate="$archive_dir/${stem}-${date_stamp}.pdf"

    if [[ -e "$candidate" ]]; then
      if cmp -s "$pdf_file" "$candidate"; then
        log "Archive already contains identical PDF: ${candidate#${REPO_ROOT}/}"
        continue
      fi

      counter=2
      while [[ -e "$archive_dir/${stem}-${date_stamp}-${counter}.pdf" ]]; do
        if cmp -s "$pdf_file" "$archive_dir/${stem}-${date_stamp}-${counter}.pdf"; then
          candidate="$archive_dir/${stem}-${date_stamp}-${counter}.pdf"
          break
        fi
        ((counter++))
      done

      if [[ ! -e "$archive_dir/${stem}-${date_stamp}-${counter}.pdf" ]]; then
        candidate="$archive_dir/${stem}-${date_stamp}-${counter}.pdf"
      fi

      if cmp -s "$pdf_file" "$candidate"; then
        log "Archive already contains identical PDF: ${candidate#${REPO_ROOT}/}"
        continue
      fi
    fi

    cp -p "$pdf_file" "$candidate"
    log "Archived PDF: ${candidate#${REPO_ROOT}/}"
  done < <(find "$pdf_dir" -maxdepth 1 -type f -iname '*.pdf' -print0)

  if [[ "$found" == false ]]; then
    log "No top-level PDF files found to archive."
  fi
}

archive_current_pdfs() {
  local helper="$REPO_ROOT/scripts/bash/archive-current-pdfs.sh"

  if [[ -x "$helper" ]]; then
    "$helper" "$REPO_ROOT"
  else
    archive_current_pdfs_fallback
  fi
}

write_resume() {
  local target="$REPO_ROOT/$MARKDOWN_REL"
  mkdir -p "$(dirname "$target")"

  cat > "$target" <<'RESUME'
# TIM FOX

**Principal Network Engineer | Network Infrastructure Leader**

United States | Open to Remote and Onsite Roles | timfox2025@tim.army | https://github.com/derg20

## PROFESSIONAL SUMMARY

Principal Network Engineer and people leader with more than 20 years of experience designing, deploying, securing, and supporting mission-critical enterprise, data center, healthcare, and federal networks. Combines hands-on multi-vendor engineering, architecture, Tier 3 troubleshooting, technical mentoring, and an MBA.

## CORE EXPERTISE

**Networking:** BGP, OSPF, MPLS, IPv4/IPv6, VLANs, ACLs, Cisco IOS/IOS-XE/IOS-XR, ACI/APIC, and Juniper JUNOS.  
**Security and Data Center:** Palo Alto, F5, Gigamon, HAIPE, Dell VxRail, VMware, Linux, and Red Hat Enterprise Linux.  
**Leadership and Delivery:** People management, team development, architecture, deployment planning, documentation, stakeholder communication, and escalation management.

## CERTIFICATIONS

- **Networking and Security:** Cisco CCNP Enterprise, Cisco CCNA, Juniper JNCIA-Junos, GIAC GCED, CompTIA Security+ CE, and Fortinet Certified Associate in Cybersecurity.
- **Cloud and Data Center:** AWS Certified Cloud Practitioner, Dell VxRail Deploy Version 2, and VMware VCA-DCV.
- **DoD Workforce Qualification Alignment:** DoD 8570 IAT II and IAT III; DoD 8140-aligned qualifications.

## PROFESSIONAL EXPERIENCE

### LEIDOS INC. | Supervisor / Principal Network Engineer | March 2026-Present

- Lead 2 direct reports within an approximately 12-person infrastructure engineering team; remove operational blockers and provide technical development across Cisco, Juniper, Dell, and Red Hat technologies.
- Provide senior technical direction for complex multi-vendor network and infrastructure escalations.

### FEDITC | Senior Network Engineer | July 2025-March 2026

- Co-designed Air Force aircraft networks, evaluated pre-release HAIPE equipment, and delivered Tier 3 support for executive aircraft communications.
- Resolved Cisco IOS-XE, Palo Alto, routing, switching, firewall, and virtual-network issues in mission-critical environments.

### AKIMA / TUNDRA LLC | Senior Deployment Network Engineer | April 2024-July 2025

- Authored designs, implementation plans, test procedures, and technical documentation while deploying Cisco, Dell, and VMware infrastructure and mentoring engineering teams.

### MSM TECHNOLOGY INC. | Senior Data Center Network Engineer | November 2022-March 2024

- Engineered Cisco ACI, Juniper, F5, Gigamon, routing, switching, security, and IPv6 access-control solutions across enterprise data center environments.

### LEIDOS INC. | Lead Infrastructure Network Engineer | November 2019-November 2022

- Led multi-vendor engineering and Tier 3 escalation support for BGP, OSPF, MPLS, firewalls, load balancers, Linux, routers, switches, and servers.

### BJC HEALTHCARE | Senior Cisco Network Engineer SME | July 2017-January 2019

- Served in a lead engineering role for a $9.7 million hospital network modernization supporting 2 hospitals and more than 40 clinics.

### LEIDOS / LOCKHEED MARTIN | Senior Network Engineer SME | March 2016-July 2017

- Supported DISA Joint Regional Security Stack engineering through a contract transition, troubleshooting Cisco, Juniper, Palo Alto, F5, Gigamon, Linux, BGP, OSPF, and MPLS environments.

### UNITED STATES ARMY | Information Technology Specialist | April 1999-March 2006

- Managed 2 Internet cafes with 100% availability, supported approximately 800 users, and earned recognition for deploying the Defense Messaging System in Germany.

## EDUCATION AND DEVELOPMENT

**Master of Business Administration**, Webster University, March 2025 | **BS, Computer Networking and Systems Administration**, Michigan Technological University, 2014 | **AAS, Computer Information Systems**, Jefferson Community College, 2010.  
Full-time education and technical development, 2006-2016 | CCIE Enterprise Infrastructure Advanced Training, 2025 | Multi-vendor Cisco, Dell VxRail, VMware, Linux, and security lab.
RESUME

  log "Created one-page Markdown resume: $MARKDOWN_REL"
}

create_python_environment() {
  require_command python3

  if python3 - <<'PY' >/dev/null 2>&1
import reportlab
import pypdf
PY
  then
    printf '%s\n' "$(command -v python3)"
    return
  fi

  VENV_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tim-fox-one-page-pdf.XXXXXX")
  python3 -m venv "$VENV_DIR/venv" \
    || fatal "Unable to create the temporary Python environment."

  local python="$VENV_DIR/venv/bin/python"
  local pip="$VENV_DIR/venv/bin/pip"

  "$pip" install --disable-pip-version-check --quiet reportlab pypdf \
    || fatal "Unable to install PDF dependencies. Check your Internet connection."

  printf '%s\n' "$python"
}

generate_pdf() {
  local source="$REPO_ROOT/$MARKDOWN_REL"
  local output="$REPO_ROOT/$PDF_REL"
  mkdir -p "$(dirname "$output")"

  local python
  python=$(create_python_environment)

  "$python" - "$source" "$output" <<'PY'
import html
import re
import sys
from pathlib import Path

from pypdf import PdfReader
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas
from reportlab.platypus import BaseDocTemplate, Frame, PageTemplate, Paragraph

source = Path(sys.argv[1])
output = Path(sys.argv[2])
text = source.read_text(encoding="utf-8")

class InvariantCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        kwargs["invariant"] = 1
        super().__init__(*args, **kwargs)

    def save(self):
        self.setTitle("Tim Fox One-Page Resume")
        self.setAuthor("Tim Fox")
        super().save()


def inline_markup(value: str) -> str:
    value = value.replace("  ", " ")
    parts = re.split(r"(\*\*.*?\*\*)", value)
    rendered = []
    for part in parts:
        if part.startswith("**") and part.endswith("**"):
            rendered.append(f"<b>{html.escape(part[2:-2])}</b>")
        else:
            escaped = html.escape(part)
            escaped = re.sub(
                r"(https://[^\s<]+)",
                r'<link href="\1" color="#1f4e79">\1</link>',
                escaped,
            )
            rendered.append(escaped)
    return "".join(rendered)

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="ResumeTitle",
    parent=styles["Title"],
    fontName="Helvetica-Bold",
    fontSize=18.0,
    leading=19.0,
    alignment=TA_CENTER,
    spaceAfter=0.8,
    textColor=colors.HexColor("#17365D"),
))
styles.add(ParagraphStyle(
    name="ResumeSubtitle",
    parent=styles["Normal"],
    fontName="Helvetica-Bold",
    fontSize=10.0,
    leading=10.8,
    alignment=TA_CENTER,
    spaceAfter=0.6,
))
styles.add(ParagraphStyle(
    name="ResumeContact",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=8.0,
    leading=8.8,
    alignment=TA_CENTER,
    spaceAfter=2.4,
))
styles.add(ParagraphStyle(
    name="ResumeSection",
    parent=styles["Heading2"],
    fontName="Helvetica-Bold",
    fontSize=10.0,
    leading=10.7,
    spaceBefore=2.7,
    spaceAfter=1.1,
    textColor=colors.HexColor("#17365D"),
    keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="ResumeEmployer",
    parent=styles["Heading3"],
    fontName="Helvetica-Bold",
    fontSize=8.55,
    leading=9.35,
    spaceBefore=1.35,
    spaceAfter=0.25,
    keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="ResumeBody",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=8.1,
    leading=9.25,
    alignment=TA_LEFT,
    spaceAfter=0.9,
))
styles.add(ParagraphStyle(
    name="ResumeBullet",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=8.0,
    leading=9.15,
    leftIndent=8.5,
    firstLineIndent=-6.0,
    bulletIndent=0.5,
    spaceAfter=0.55,
))

left = 0.42 * inch
right = 0.42 * inch
top = 0.34 * inch
bottom = 0.34 * inch
frame = Frame(
    left,
    bottom,
    LETTER[0] - left - right,
    LETTER[1] - top - bottom,
    id="one-page-resume-frame",
    leftPadding=0,
    rightPadding=0,
    topPadding=0,
    bottomPadding=0,
)

doc = BaseDocTemplate(
    str(output),
    pagesize=LETTER,
    leftMargin=left,
    rightMargin=right,
    topMargin=top,
    bottomMargin=bottom,
    title="Tim Fox One-Page Resume",
    author="Tim Fox",
    subject="Principal Network Engineer one-page resume",
)
doc.addPageTemplates([PageTemplate(id="resume", frames=[frame])])

story = []
for raw in text.splitlines():
    line = raw.strip()
    if not line:
        continue
    if line.startswith("# "):
        story.append(Paragraph(inline_markup(line[2:]), styles["ResumeTitle"]))
    elif line.startswith("## "):
        story.append(Paragraph(inline_markup(line[3:]), styles["ResumeSection"]))
    elif line.startswith("### "):
        story.append(Paragraph(inline_markup(line[4:]), styles["ResumeEmployer"]))
    elif line.startswith("- "):
        story.append(Paragraph(inline_markup(line[2:]), styles["ResumeBullet"], bulletText="-"))
    elif line.startswith("**") and line.endswith("**"):
        content = line[2:-2]
        style = styles["ResumeSubtitle"] if len(story) < 2 else styles["ResumeBody"]
        story.append(Paragraph(inline_markup(content), style))
    elif line.startswith("United States | Open to"):
        story.append(Paragraph(inline_markup(line), styles["ResumeContact"]))
    else:
        story.append(Paragraph(inline_markup(line), styles["ResumeBody"]))

output.parent.mkdir(parents=True, exist_ok=True)
doc.build(story, canvasmaker=InvariantCanvas)

reader = PdfReader(str(output))
page_count = len(reader.pages)
if page_count != 1:
    raise SystemExit(f"Expected exactly 1 PDF page, generated {page_count}.")

page_text = reader.pages[0].extract_text() or ""
for required in [
    "TIM FOX",
    "Supervisor / Principal Network Engineer",
    "DoD Workforce Qualification Alignment",
    "UNITED STATES ARMY",
    "Master of Business Administration",
]:
    if required not in page_text:
        raise SystemExit(f"Required PDF content missing: {required}")

print(f"Generated {output} ({page_count} page)")
PY

  [[ -s "$output" ]] || fatal "PDF generation failed: $output"
  log "Generated one-page PDF: $PDF_REL"
}

validate_output() {
  local markdown="$REPO_ROOT/$MARKDOWN_REL"
  local pdf="$REPO_ROOT/$PDF_REL"
  local installed="$REPO_ROOT/$SCRIPT_REL"

  [[ -s "$markdown" ]] || fatal "One-page Markdown resume was not created."
  [[ -s "$pdf" ]] || fatal "One-page PDF was not created."
  [[ -x "$installed" ]] || fatal "Canonical script is not executable."

  [[ "$(basename "$markdown")" == *one-page* ]] \
    || fatal "Markdown filename does not include 'one-page'."
  [[ "$(basename "$pdf")" == *one-page* ]] \
    || fatal "PDF filename does not include 'one-page'."

  grep -Fqx "$HEADER" "$markdown" \
    || fatal "The required header is missing."
  grep -Fq -- '- **DoD Workforce Qualification Alignment:**' "$markdown" \
    || fatal "The DoD workforce alignment bullet is missing."

  bash -n "$installed" || fatal "Bash syntax validation failed for $SCRIPT_REL."
  log "PASS: one-page filenames, content, PDF page count, and Bash syntax validation."
}

commit_and_push() {
  if [[ "$COMMIT_CHANGES" != true ]]; then
    log "Files updated without a Git commit (--no-commit)."
    return
  fi

  git -C "$REPO_ROOT" add -- \
    "$MARKDOWN_REL" \
    "$PDF_REL" \
    "$SCRIPT_REL" \
    "pdf/zArchive"

  if git -C "$REPO_ROOT" diff --cached --quiet; then
    log "No one-page resume changes to commit."
  else
    git -C "$REPO_ROOT" commit -m "$COMMIT_MESSAGE"
    log "Created Git commit: $COMMIT_MESSAGE"
  fi

  if [[ "$PUSH_CHANGES" == true ]]; then
    local branch
    branch=$(git -C "$REPO_ROOT" branch --show-current)
    [[ -n "$branch" ]] || fatal "Cannot push from a detached HEAD."
    git -C "$REPO_ROOT" remote get-url origin >/dev/null 2>&1 \
      || fatal "Git remote 'origin' is not configured."
    git -C "$REPO_ROOT" push -u origin "$branch"
    log "Pushed branch '$branch' to origin."
  else
    log "Push skipped (--no-push)."
  fi
}

open_pdf() {
  [[ "$OPEN_PDF" == true ]] || return 0

  if command -v open >/dev/null 2>&1; then
    open "$REPO_ROOT/$PDF_REL"
  else
    warn "The 'open' command is unavailable. PDF: $REPO_ROOT/$PDF_REL"
  fi
}

remove_external_source() {
  local canonical="$REPO_ROOT/$SCRIPT_REL"

  if [[ "$SOURCE_SCRIPT" != "$canonical" && -f "$SOURCE_SCRIPT" ]]; then
    rm -f "$SOURCE_SCRIPT"
    log "Removed external script after canonical installation."
  fi
}

main() {
  require_command git
  require_command cmp
  require_command grep
  require_command find

  capture_self
  parse_args "$@"
  validate_repo

  log "Repository root: $REPO_ROOT"
  install_script
  archive_current_pdfs
  write_resume
  generate_pdf
  validate_output
  commit_and_push
  open_pdf
  remove_external_source

  log "Complete."
  log "One-page Markdown: $REPO_ROOT/$MARKDOWN_REL"
  log "One-page PDF:      $REPO_ROOT/$PDF_REL"
}

main "$@"

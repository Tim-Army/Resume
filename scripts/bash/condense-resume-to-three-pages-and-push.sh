#!/usr/bin/env bash
#
# Replace the Tim-Fox-Resume master resume with a concise naturally paginated version,
# generate a matching three-page PDF, commit the changes, and push to GitHub.
#
# Default repository:
#   $HOME/Documents/github/Tim-Fox-Resume
#
# Usage:
#   ./condense-resume-to-three-pages-and-push.sh
#   ./condense-resume-to-three-pages-and-push.sh --repo /path/to/Tim-Fox-Resume
#

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2026.07.17.1"
readonly SCRIPT_NAME="condense-resume-to-three-pages-and-push.sh"
readonly DEFAULT_REPO="$HOME/Documents/github/Tim-Fox-Resume"
readonly MASTER_REL="resume/master/Tim-Fox-Resume.md"
readonly PDF_REL="pdf/Tim-Fox-Resume.pdf"
readonly SCRIPT_REL="scripts/bash/$SCRIPT_NAME"
readonly HEADER="United States | Open to Remote and Onsite Roles | timfox2025@tim.army | https://github.com/derg20"

REPO_ROOT="$DEFAULT_REPO"
COMMIT_CHANGES=true
PUSH_CHANGES=true
OPEN_PDF=false
COMMIT_MESSAGE="docs: publish condensed three-page resume"
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
  [[ -n "$TEMP_SELF" && -f "$TEMP_SELF" ]] && rm -f "$TEMP_SELF"
  [[ -n "$VENV_DIR" && -d "$VENV_DIR" ]] && rm -rf "$VENV_DIR"
  return 0
}
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Create and publish Tim Fox's condensed resume with natural pagination.

Usage:
  condense-resume-to-three-pages-and-push.sh [options]

Options:
  --repo PATH       Tim-Fox-Resume repository root.
                    Default: ~/Documents/github/Tim-Fox-Resume
  --no-commit       Update the files without creating a Git commit.
  --no-push         Commit locally without pushing to GitHub.
  --message TEXT    Git commit message.
  --open            Open the generated PDF on macOS.
  --version         Display the script version.
  -h, --help        Display this help text.

Files created or updated:
  resume/master/Tim-Fox-Resume.md
  pdf/Tim-Fox-Resume.pdf
  scripts/bash/condense-resume-to-three-pages-and-push.sh

The script stages only these three files. It does not validate or modify unrelated
legacy scripts in the repository.
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
  TEMP_SELF=$(mktemp "${TMPDIR:-/tmp}/three-page-resume.XXXXXX")
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
  [[ -d "$REPO_ROOT/.git" ]] || fatal "Not a Git repository: $REPO_ROOT"

  local top
  top=$(git -C "$REPO_ROOT" rev-parse --show-toplevel)
  REPO_ROOT=$(cd "$top" && pwd -P)

  if [[ "$(basename "$REPO_ROOT")" != "Tim-Fox-Resume" ]]; then
    warn "Repository directory is named '$(basename "$REPO_ROOT")'."
  fi
}

install_script() {
  local destination="$REPO_ROOT/$SCRIPT_REL"
  mkdir -p "$(dirname "$destination")"

  if [[ ! -f "$destination" ]] || ! cmp -s "$TEMP_SELF" "$destination"; then
    cp "$TEMP_SELF" "$destination"
    chmod 0755 "$destination"
    log "Installed repository script: $SCRIPT_REL"
  else
    chmod 0755 "$destination"
    log "Repository script is already current."
  fi
}

write_resume() {
  local target="$REPO_ROOT/$MASTER_REL"
  mkdir -p "$(dirname "$target")"

  cat > "$target" <<'RESUME'
# TIM FOX

**Principal Network Engineer | Network Infrastructure Leader**

United States | Open to Remote and Onsite Roles | timfox2025@tim.army | https://github.com/derg20

## PROFESSIONAL SUMMARY

Principal Network Engineer and technical leader with more than 20 years of experience designing, deploying, securing, and supporting mission-critical enterprise, data center, healthcare, and federal networks. Combines hands-on multi-vendor engineering expertise with people leadership, an MBA, and a record of mentoring teams through complex infrastructure deployments and operational challenges.

## CORE COMPETENCIES

**Network Engineering:** BGP, OSPF, MPLS, IPv4, IPv6, VLANs, access control lists, routing, switching, architecture, implementation, troubleshooting, and Tier 3 support.

**Platforms:** Cisco IOS, IOS-XE, IOS-XR, Catalyst, ASR, ACI, APIC, Cisco 1001-X, Cisco 8000v, Juniper JUNOS, Palo Alto Networks, F5, Gigamon, TACLANE, Dell, VMware, VxRail, Linux, and Red Hat Enterprise Linux.

**Leadership and Delivery:** People management, mentoring, technical training, design reviews, implementation planning, documentation, stakeholder communication, escalation management, and operational support.

## CERTIFICATIONS

- **Advanced Networking:** Cisco CCNP Enterprise; Cisco CCNA; Juniper JNCIA-Junos.
- **Cybersecurity:** GIAC GCED; CompTIA Security+ CE; Fortinet Certified Associate in Cybersecurity.
- **Cloud, Virtualization, and Data Center:** AWS Certified Cloud Practitioner; Dell VxRail Deploy Version 2; VMware VCA-DCV.
- **DoD Workforce Qualification Alignment:** DoD 8570 IAT II and IAT III; DoD 8140-aligned qualifications.

## PROFESSIONAL EXPERIENCE

### LEIDOS INC.
**Supervisor / Principal Network Engineer** | March 2026-Present

- Lead and develop 2 direct reports within an infrastructure engineering team of approximately 12 professionals.
- Deliver technical training and knowledge transfer covering Dell servers, Red Hat Enterprise Linux, Juniper routers, and Cisco routing and switching platforms.
- Remove technical and operational blockers by coordinating equipment, access, documentation, training, and cross-team assistance.
- Support employee development, team readiness, operational success, and positive team morale through hands-on leadership and mentoring.
- Provide senior guidance for complex network and infrastructure issues across multi-vendor environments.

### FEDITC
**Senior Network Engineer** | July 2025-March 2026

- Co-designed classified and unclassified network architectures supporting Air Force aircraft communications.
- Translated mission, security, availability, and interoperability requirements into deployable technical designs.
- Conducted pre-release testing of TACLANE encryption equipment and documented operational findings and deployment considerations.
- Delivered Tier 3 engineering support for the Executive Aircraft Communications Network.
- Resolved complex routing, switching, firewall, and virtual-network issues in a mission-critical environment.
- Supported Cisco 1001-X, Cisco 8000v, IOS-XE routing and switching platforms, Palo Alto firewalls, and virtual-network environments.

### AKIMA / TUNDRA LLC
**Senior Deployment Network Engineer** | April 2024-July 2025

- Authored and reviewed network designs, implementation plans, test procedures, and technical documentation aligned with customer and acceptance requirements.
- Planned, installed, configured, and validated Cisco, Dell, and VMware infrastructure.
- Improved team deployment capability through technical mentoring, demonstrations, and reusable engineering documentation.
- Equipped team members with the knowledge needed to perform deployments and troubleshoot multi-vendor infrastructure.
- Coordinated deployment activities across engineering teams, customer stakeholders, and onsite personnel.
## PROFESSIONAL EXPERIENCE - CONTINUED

### MSM TECHNOLOGY INC.
**Senior Data Center Network Engineer** | November 2022-March 2024

- Engineered and supported routers, switches, firewalls, load balancers, packet brokers, and Cisco ACI data center environments.
- Served as a technical consultant across Cisco APIC and IOS-XE, Juniper JUNOS, F5, and Gigamon platforms.
- Designed and implemented IPv6 access control lists and supported complex multi-vendor configurations.
- Provided engineering support for complex configurations across enterprise and data center networks.
- Developed technical documentation and training materials that improved knowledge transfer and troubleshooting readiness.
- Mentored team members through demonstrations, technical training, and engineering documentation.

### LEIDOS INC.
**Lead Infrastructure Network Engineer** | November 2019-November 2022

- Led engineering support for Cisco IOS-XR and IOS-XE, Juniper, F5, Gigamon, Linux, firewalls, load balancers, routers, switches, and servers.
- Served as a senior escalation resource for BGP, OSPF, MPLS, static routing, traffic management, and network availability issues.
- Advised engineering and operational teams on design decisions, configuration changes, troubleshooting strategies, and implementation risks.
- Provided engineering support for router, switch, firewall, load balancer, and server configurations.
- Produced technical documentation and delivered training that strengthened team readiness and knowledge transfer.
- Mentored team members through impromptu technical training, demonstrations, and documentation.

### BJC HEALTHCARE
**Senior Cisco Network Engineer Subject-Matter Expert** | July 2017-January 2019

- Served in a lead engineering role for a $9.7 million hospital network modernization initiative.
- Supported network architecture, implementation, migration, validation, and technical coordination for the hospital upgrade.
- Engineered and supported Cisco routing and switching infrastructure serving 2 hospitals and more than 40 clinics.
- Supported Cisco 2921 routers and Catalyst 9410 and 4510 switches in a highly available healthcare environment.
- Mentored engineers and project managers on technical dependencies, implementation risks, and network requirements.
- Served as a Cisco network engineering subject-matter expert for enterprise healthcare infrastructure.

### LEIDOS INC.
**Senior Network Engineer Subject-Matter Expert** | July 2016-July 2017

- Continued the same DISA Joint Regional Security Stack role without interruption after the supporting contract transitioned from Lockheed Martin to Leidos.
- Supported Defense Information Systems Agency Joint Regional Security Stack engineering and operations in a complex multi-vendor defense environment.
- Advised teams on Cisco, Juniper, Palo Alto Networks, F5, Gigamon, and Linux technologies.
- Engineered and troubleshot BGP, OSPF, MPLS, and static-routing configurations while delivering senior troubleshooting and training support.
- Supported Cisco IOS, IOS-XE, and IOS-XR routing and switching platforms.

### LOCKHEED MARTIN
**Senior Network Engineer Subject-Matter Expert** | March 2016-July 2016

- Began the DISA Joint Regional Security Stack assignment later transitioned to Leidos.
- Supported Cisco IOS, IOS-XE, and IOS-XR routing and switching platforms in a complex defense environment.
- Advised cross-functional teams on multi-vendor routing, security, traffic-management, and Linux technologies.
- Served as a senior technical contributor and trainer for engineering and operations teams.
## EDUCATION AND TECHNICAL DEVELOPMENT

**Full-Time Education and Career Development** | 2006-2016

- Pursued higher education and advanced technical development while transitioning from military service to civilian network engineering.
- Earned associate and bachelor’s degrees focused on information systems, networking, systems administration, and cybersecurity.
- Developed hands-on routing, switching, systems-administration, and network-security skills through formal education and technical lab work.

## UNITED STATES ARMY

**Information Technology Specialist** | April 1999-March 2006

- Managed 2 Internet cafes supporting 50 computers and sustained 100% service availability.
- Administered 2 Cisco routers, 1 Cisco switch, specialty fiber-optic cabling, and communications equipment.
- Served as a Windows domain administrator and provided technical support for approximately 800 users.
- Contributed to the successful deployment of the Defense Messaging System, an encrypted email capability, in Germany.
- Earned formal recognition for successful completion of the Defense Messaging System deployment project.
- Supported network, systems, end-user, and communications requirements in military operational environments.

## EDUCATION

### WEBSTER UNIVERSITY
**Master of Business Administration** | March 2025

Coursework included business and financial analysis, accounting, business strategy, and Securities and Exchange Commission filings.

### MICHIGAN TECHNOLOGICAL UNIVERSITY - Houghton, Michigan
**Bachelor of Science, Computer Networking and Systems Administration** | 2011-2014

Coursework included project management, Cisco enterprise networking, network security engineering, Linux administration, and Windows Server administration.

### JEFFERSON COMMUNITY COLLEGE - Watertown, New York
**Associate of Applied Science, Computer Information Systems** | 2007-2010

Foundational studies included information systems, computer networking, systems administration, and technical support.

## PROFESSIONAL DEVELOPMENT

- CCIE Enterprise Infrastructure Advanced Training, Micronics Training | December 2025.
- AWS Certified Cloud Practitioner Essentials, Amazon Web Services | May 2025.
- Dell VxRail Installation and Implementation Training | October 2024.
- CCIE Routing and Switching Advanced Training, Micronics Training | February 2017.
- Developing the Leader Within Workshop, Atlanta, Georgia | August 2006.
- Studied the five levels of leadership as a framework for leadership development and organizational success.

## TECHNICAL LAB

- Maintain a multi-vendor infrastructure lab incorporating Cisco routing and switching, Dell VxRail, virtualization technologies, servers, and network-security appliances.
- Use the lab for engineering, configuration, troubleshooting, integration, testing, and continuous technical development.
RESUME

  log "Updated condensed master resume: $MASTER_REL"
}

create_python_environment() {
  require_command python3

  VENV_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tim-fox-resume-pdf.XXXXXX")
  python3 -m venv "$VENV_DIR/venv" || fatal "Unable to create the temporary Python environment."

  local python="$VENV_DIR/venv/bin/python"
  local pip="$VENV_DIR/venv/bin/pip"

  "$pip" install --disable-pip-version-check --quiet reportlab pypdf \
    || fatal "Unable to install the temporary PDF dependencies. Check your Internet connection."

  printf '%s\n' "$python"
}

generate_pdf() {
  # PDF_ARCHIVE_HOOK_V1
  "$REPO_ROOT/scripts/bash/archive-current-pdfs.sh" --repo "$REPO_ROOT"
  local source="$REPO_ROOT/$MASTER_REL"
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
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    PageTemplate,
    Paragraph,
    Spacer,
)

source = Path(sys.argv[1])
output = Path(sys.argv[2])
text = source.read_text(encoding="utf-8")

class InvariantCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        kwargs["invariant"] = 1
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        page_count = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_number(page_count)
            super().showPage()
        super().save()

    def draw_page_number(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 7.5)
        self.setFillColor(colors.HexColor("#555555"))
        self.drawCentredString(LETTER[0] / 2, 0.28 * inch, f"Tim Fox | Page {self._pageNumber} of {page_count}")
        self.restoreState()

def inline_markup(value: str) -> str:
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
    fontSize=18,
    leading=20,
    alignment=TA_CENTER,
    spaceAfter=2,
    textColor=colors.HexColor("#17365D"),
))
styles.add(ParagraphStyle(
    name="ResumeSubtitle",
    parent=styles["Normal"],
    fontName="Helvetica-Bold",
    fontSize=10.2,
    leading=12,
    alignment=TA_CENTER,
    spaceAfter=2,
))
styles.add(ParagraphStyle(
    name="ResumeContact",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=8.4,
    leading=10,
    alignment=TA_CENTER,
    spaceAfter=6,
))
styles.add(ParagraphStyle(
    name="ResumeSection",
    parent=styles["Heading2"],
    fontName="Helvetica-Bold",
    fontSize=10.4,
    leading=12,
    spaceBefore=4,
    spaceAfter=2,
    textColor=colors.HexColor("#17365D"),
    borderWidth=0,
    borderPadding=0,
    keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="ResumeEmployer",
    parent=styles["Heading3"],
    fontName="Helvetica-Bold",
    fontSize=9.2,
    leading=10.6,
    spaceBefore=3,
    spaceAfter=0,
    keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="ResumeRole",
    parent=styles["Normal"],
    fontName="Helvetica-BoldOblique",
    fontSize=8.6,
    leading=10.2,
    spaceAfter=1,
    keepWithNext=True,
))
styles.add(ParagraphStyle(
    name="ResumeBody",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=8.55,
    leading=10.35,
    alignment=TA_LEFT,
    spaceAfter=2,
))
styles.add(ParagraphStyle(
    name="ResumeBullet",
    parent=styles["Normal"],
    fontName="Helvetica",
    fontSize=8.4,
    leading=10.15,
    leftIndent=10,
    firstLineIndent=-6,
    bulletIndent=2,
    spaceAfter=1.2,
))

left = 0.48 * inch
right = 0.48 * inch
top = 0.42 * inch
bottom = 0.45 * inch
frame = Frame(
    left,
    bottom,
    LETTER[0] - left - right,
    LETTER[1] - top - bottom,
    id="resume-frame",
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
    title="Tim Fox Resume",
    author="Tim Fox",
    subject="Principal Network Engineer resume",
)
doc.addPageTemplates([PageTemplate(id="resume", frames=[frame])])

story = []
lines = text.splitlines()
nonempty_index = 0
for raw in lines:
    line = raw.strip()
    if not line:
        continue
    if line.startswith("# "):
        story.append(Paragraph(inline_markup(line[2:]), styles["ResumeTitle"]))
        continue
    if line.startswith("## "):
        story.append(Paragraph(inline_markup(line[3:]), styles["ResumeSection"]))
        continue
    if line.startswith("### "):
        story.append(Paragraph(inline_markup(line[4:]), styles["ResumeEmployer"]))
        continue
    if line.startswith("- "):
        story.append(Paragraph(inline_markup(line[2:]), styles["ResumeBullet"], bulletText="•"))
        continue
    if line.startswith("**") and line.endswith("**"):
        content = line[2:-2]
        style = styles["ResumeSubtitle"] if not any(story) or len(story) < 2 else styles["ResumeRole"]
        story.append(Paragraph(inline_markup(content), style))
        continue
    if line.startswith("*") and line.endswith("*"):
        story.append(Paragraph(f"<i>{html.escape(line[1:-1])}</i>", styles["ResumeBody"]))
        continue

    # The first ordinary line following title/subtitle is the contact header.
    if line.startswith("United States | Open to"):
        story.append(Paragraph(inline_markup(line), styles["ResumeContact"]))
    else:
        story.append(Paragraph(inline_markup(line), styles["ResumeBody"]))

output.parent.mkdir(parents=True, exist_ok=True)
doc.build(story, canvasmaker=InvariantCanvas)

reader = PdfReader(str(output))
page_count = len(reader.pages)
if page_count not in (2, 3):
    raise SystemExit(f"Expected a naturally paginated 2- or 3-page PDF, generated {page_count}.")

for required in [
    "United States | Open to Remote and Onsite Roles",
    "Supervisor / Principal Network Engineer",
    "UNITED STATES ARMY",
]:
    if required not in text:
        raise SystemExit(f"Required resume content missing: {required}")

print(f"Generated {output} ({len(reader.pages)} pages)")
PY

  [[ -s "$output" ]] || fatal "PDF generation failed: $output"
  log "Generated naturally paginated PDF: $PDF_REL"
}

validate_output() {
  local master="$REPO_ROOT/$MASTER_REL"
  local pdf="$REPO_ROOT/$PDF_REL"
  local installed="$REPO_ROOT/$SCRIPT_REL"

  [[ -s "$master" ]] || fatal "Master resume was not created."
  [[ -s "$pdf" ]] || fatal "PDF was not created."
  [[ -x "$installed" ]] || fatal "Repository script is not executable."

  grep -Fqx "$HEADER" "$master" \
    || fatal "The requested header is missing from the master resume."
  if grep -Eq '^[[:space:]]*<!-- PAGE BREAK -->[[:space:]]*$' "$master"; then
    fatal "Forced page-break markers remain in the Markdown resume."
  fi
  if grep -Eq '^[[:space:]]*<!-- PAGE BREAK -->[[:space:]]*$' "$installed"; then
    fatal "Forced page-break markers remain in the resume generator."
  fi

  bash -n "$installed" || fatal "Bash syntax validation failed for $SCRIPT_REL."
  log "PASS: header, natural page flow, PDF, and Bash syntax validation."
}

commit_and_push() {
  if [[ "$COMMIT_CHANGES" != true ]]; then
    log "Files updated without a Git commit (--no-commit)."
    return
  fi

  git -C "$REPO_ROOT" add -- "$MASTER_REL" "$PDF_REL" "$SCRIPT_REL" "pdf/Archive" "pdf/zArchive" "scripts/bash/archive-current-pdfs.sh"

  if git -C "$REPO_ROOT" diff --cached --quiet; then
    log "No resume changes to commit."
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

main() {
  require_command git
  require_command cmp
  require_command grep

  capture_self
  parse_args "$@"
  validate_repo

  log "Repository root: $REPO_ROOT"
  install_script
  write_resume
  generate_pdf
  validate_output
  commit_and_push
  open_pdf

  log "Complete."
  log "Master resume: $REPO_ROOT/$MASTER_REL"
  log "PDF resume:    $REPO_ROOT/$PDF_REL"
}

main "$@"

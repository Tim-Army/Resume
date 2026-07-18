#!/usr/bin/env bash
#
# Build Tim Fox's resume repository content from the current repository layout.
#
# The script:
#   1. Detects the Tim-Fox-Resume Git repository root.
#   2. Ensures the established repository directory structure exists.
#   3. Moves all .sh and .bash files from ~/Downloads into scripts/bash/.
#   4. Installs itself as scripts/bash/create-tim-fox-resume.sh.
#   5. Generates master, private-sector, and federal/defense Markdown resumes.
#   6. Validates that every generated resume bullet ends with a period.
#   7. Optionally commits and pushes the resulting changes.
#
# Typical usage from anywhere inside the repository:
#   ./scripts/bash/create-tim-fox-resume.sh
#
# First run from Downloads:
#   chmod +x "$HOME/Downloads/create-tim-fox-resume.sh"
#   "$HOME/Downloads/create-tim-fox-resume.sh" \
#     --repo "$HOME/Documents/github/Tim-Fox-Resume" \
#     --commit --push
#

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_VERSION="2026.07.16.1"
readonly EXPECTED_REPO_NAME="Tim-Fox-Resume"
readonly CANONICAL_SCRIPT_NAME="create-tim-fox-resume.sh"

REPO_ROOT=""
DOWNLOADS_DIR="${HOME}/Downloads"
MOVE_DOWNLOAD_SCRIPTS=true
COMMIT_CHANGES=false
PUSH_CHANGES=false
DRY_RUN=false
OPEN_FILES=false
COMMIT_MESSAGE="docs: create Tim Fox resume sources"
TEMP_SELF=""
SOURCE_SCRIPT=""

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
}
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Create Tim Fox's resume files in the current Tim-Fox-Resume repository.

Usage:
  create-tim-fox-resume.sh [options]

Options:
  --repo PATH             Repository root. By default, detect it with Git.
  --downloads PATH        Downloads directory containing shell scripts.
                          Default: ~/Downloads.
  --skip-script-move      Do not move .sh and .bash files from Downloads.
  --commit                Commit generated and moved files when changes exist.
  --push                  Push the current branch after committing. Implies --commit.
  --message TEXT          Commit message.
                          Default: docs: create Tim Fox resume sources.
  --open                  Open the generated master resume on macOS.
  --dry-run               Show script moves without moving them. Resume files are
                          still generated so they can be validated.
  --version               Show the script version.
  -h, --help              Show this help text.

Generated files:
  resume/master/Tim-Fox-Resume.md
  resume/targeted/private-sector/Tim-Fox-Resume-Private-Sector.md
  resume/targeted/federal-defense/Tim-Fox-Resume-Federal-Defense.md
  docs/resume-build-manifest.md

Script policy:
  All .sh and .bash files found directly in Downloads are moved into
  scripts/bash/. Name conflicts are preserved with a timestamp suffix.
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
  mkdir -p "$parent"
  parent=$(cd "$parent" && pwd -P)
  printf '%s/%s\n' "$parent" "$base"
}

capture_self() {
  SOURCE_SCRIPT=$(absolute_path "${BASH_SOURCE[0]}")
  TEMP_SELF=$(mktemp "${TMPDIR:-/tmp}/create-tim-fox-resume.XXXXXX")
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
      --downloads)
        [[ $# -ge 2 ]] || fatal "--downloads requires a path."
        DOWNLOADS_DIR="$2"
        shift 2
        ;;
      --skip-script-move)
        MOVE_DOWNLOAD_SCRIPTS=false
        shift
        ;;
      --commit)
        COMMIT_CHANGES=true
        shift
        ;;
      --push)
        COMMIT_CHANGES=true
        PUSH_CHANGES=true
        shift
        ;;
      --message)
        [[ $# -ge 2 ]] || fatal "--message requires text."
        COMMIT_MESSAGE="$2"
        shift 2
        ;;
      --open)
        OPEN_FILES=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
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

detect_repo_root() {
  if [[ -n "$REPO_ROOT" ]]; then
    REPO_ROOT=$(absolute_path "$REPO_ROOT")
  elif git rev-parse --show-toplevel >/dev/null 2>&1; then
    REPO_ROOT=$(git rev-parse --show-toplevel)
  elif [[ "$(basename "$PWD")" == "$EXPECTED_REPO_NAME" ]]; then
    REPO_ROOT="$PWD"
  else
    fatal "Could not detect the repository root. Use --repo PATH."
  fi

  [[ -d "$REPO_ROOT" ]] || fatal "Repository directory does not exist: $REPO_ROOT"

  if [[ "$(basename "$REPO_ROOT")" != "$EXPECTED_REPO_NAME" ]]; then
    warn "Repository directory is named '$(basename "$REPO_ROOT")', not '$EXPECTED_REPO_NAME'."
  fi

  if [[ ! -d "$REPO_ROOT/.git" ]]; then
    fatal "'$REPO_ROOT' is not a Git repository. Repair or clone the repository first."
  fi

  DOWNLOADS_DIR=$(absolute_path "$DOWNLOADS_DIR")
}

ensure_structure() {
  mkdir -p \
    "$REPO_ROOT/resume/master" \
    "$REPO_ROOT/resume/targeted/private-sector" \
    "$REPO_ROOT/resume/targeted/federal-defense" \
    "$REPO_ROOT/exports/docx" \
    "$REPO_ROOT/exports/pdf" \
    "$REPO_ROOT/docs" \
    "$REPO_ROOT/archive" \
    "$REPO_ROOT/scripts/bash"

  : > "$REPO_ROOT/exports/docx/.gitkeep"
  : > "$REPO_ROOT/exports/pdf/.gitkeep"
  : > "$REPO_ROOT/archive/.gitkeep"
}

collision_safe_destination() {
  local destination="$1"

  if [[ ! -e "$destination" ]]; then
    printf '%s\n' "$destination"
    return 0
  fi

  local directory filename stem extension timestamp candidate counter
  directory=$(dirname "$destination")
  filename=$(basename "$destination")
  timestamp=$(date '+%Y%m%d-%H%M%S')

  if [[ "$filename" == *.* ]]; then
    stem="${filename%.*}"
    extension=".${filename##*.}"
  else
    stem="$filename"
    extension=""
  fi

  candidate="$directory/${stem}-${timestamp}${extension}"
  counter=1
  while [[ -e "$candidate" ]]; do
    candidate="$directory/${stem}-${timestamp}-${counter}${extension}"
    ((counter += 1))
  done

  printf '%s\n' "$candidate"
}

install_self() {
  local destination="$REPO_ROOT/scripts/bash/$CANONICAL_SCRIPT_NAME"

  if [[ -f "$destination" ]] && cmp -s "$TEMP_SELF" "$destination"; then
    chmod 0755 "$destination"
    log "Canonical build script is already current."
  else
    cp "$TEMP_SELF" "$destination"
    chmod 0755 "$destination"
    log "Installed: scripts/bash/$CANONICAL_SCRIPT_NAME"
  fi
}

move_download_scripts() {
  [[ "$MOVE_DOWNLOAD_SCRIPTS" == true ]] || {
    log "Skipping Downloads script migration."
    return 0
  }

  if [[ ! -d "$DOWNLOADS_DIR" ]]; then
    warn "Downloads directory does not exist: $DOWNLOADS_DIR"
    return 0
  fi

  local source destination basename_source moved_count=0 duplicate_count=0

  while IFS= read -r -d '' source; do
    basename_source=$(basename "$source")

    # The executing script is installed from its protected temporary copy.
    if [[ "$source" == "$SOURCE_SCRIPT" ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: remove downloaded source after installing canonical copy: $source"
      else
        rm -f "$source"
        log "Removed downloaded source after repository installation: $basename_source"
      fi
      ((moved_count += 1))
      continue
    fi

    destination="$REPO_ROOT/scripts/bash/$basename_source"

    if [[ -f "$destination" ]] && cmp -s "$source" "$destination"; then
      if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: remove duplicate Downloads script: $source"
      else
        rm -f "$source"
        log "Removed duplicate Downloads script: $basename_source"
      fi
      ((duplicate_count += 1))
      continue
    fi

    if [[ -e "$destination" ]]; then
      destination=$(collision_safe_destination "$destination")
      warn "Name conflict for '$basename_source'; preserving it as '$(basename "$destination")'."
    fi

    if [[ "$DRY_RUN" == true ]]; then
      log "DRY RUN: move '$source' -> '$destination'"
    else
      mv "$source" "$destination"
      chmod 0755 "$destination"
      log "Moved Downloads script: $(basename "$destination")"
    fi
    ((moved_count += 1))
  done < <(find "$DOWNLOADS_DIR" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.bash' \) -print0)

  log "Downloads script migration complete: $moved_count moved, $duplicate_count duplicates removed."
}

write_master_resume() {
  cat > "$REPO_ROOT/resume/master/Tim-Fox-Resume.md" <<'RESUME'
# TIM FOX

**Principal Network Engineer | Infrastructure Engineering Supervisor | Multi-Vendor Enterprise and Defense Networks**

United States | Open to Remote Roles | timfox2025@tim.army | tim.army

## PROFESSIONAL SUMMARY

Principal Network Engineer and technical leader with more than 20 years of military, academic, and professional technology experience supporting mission-critical enterprise, data center, healthcare, and federal environments. Leads engineers, develops technical talent, produces architecture and design documentation, and delivers multi-vendor infrastructure across Cisco, Juniper, Palo Alto Networks, F5, Gigamon, Dell, VMware, Red Hat, and Linux platforms. Combines hands-on expertise in routing, switching, network security, IPv6, encrypted communications, data center technologies, and network modernization with an MBA and a sustained record of technical mentorship.

## CORE COMPETENCIES

- **Network Engineering:** BGP, OSPF, MPLS, IPv4, IPv6, VLANs, access control lists, routing, switching, network architecture, implementation, troubleshooting, and Tier 3 support.
- **Network Platforms:** Cisco IOS, IOS-XE, IOS-XR, Catalyst, ASR, Cisco ACI, Cisco APIC, Cisco 1001-X, Cisco 8000v, and Juniper JUNOS.
- **Security and Traffic Management:** Palo Alto Networks, F5, TACLANE, Gigamon, network segmentation, encrypted communications, IPv6 security policies, and firewall engineering.
- **Data Center and Systems:** Dell servers and switches, Dell VxRail, VMware, virtualization, Linux, Red Hat Enterprise Linux, load balancers, and packet brokers.
- **Leadership and Delivery:** People management, technical mentoring, team development, technical training, architecture documentation, design reviews, implementation planning, project leadership, stakeholder communication, and operational support.

## CERTIFICATIONS

### Advanced Networking

- Cisco Certified Network Professional — Enterprise.
- Cisco Certified Network Associate.
- Juniper Networks Certified Associate — Junos.

### Cybersecurity

- GIAC Certified Enterprise Defender.
- CompTIA Security+ CE.
- Fortinet Certified Associate in Cybersecurity.

### Cloud, Virtualization, and Data Center

- AWS Certified Cloud Practitioner.
- Dell VxRail Deploy Version 2.
- VMware Certified Associate — Data Center Virtualization.

**DoD Workforce Qualification Alignment:** DoD 8570 IAT II and IAT III; DoD 8140-aligned qualifications.

## PROFESSIONAL EXPERIENCE

### LEIDOS INC.

**Supervisor / Principal Network Engineer** | March 2026–Present

- Lead and develop 2 direct reports within a growing infrastructure engineering team of approximately 12 professionals.
- Provide technical training and knowledge transfer covering Dell servers, Red Hat Enterprise Linux, Juniper routers, and Cisco routing and switching platforms.
- Remove technical and operational blockers by coordinating equipment, access, documentation, training, and cross-team assistance.
- Support employee development, team readiness, operational success, and positive team morale through hands-on leadership and mentoring.
- Provide senior technical guidance for complex network and infrastructure issues across multi-vendor environments.

### FEDITC

**Senior Network Engineer** | July 2025–March 2026

- Co-designed classified and unclassified network architectures supporting Air Force aircraft communications.
- Translated mission, security, availability, and interoperability requirements into deployable technical designs.
- Conducted pre-release testing of TACLANE encryption equipment and documented operational findings, interoperability risks, and deployment considerations.
- Delivered Tier 3 engineering support for the Executive Aircraft Communications Network.
- Resolved complex routing, switching, firewall, and virtual-network issues in a mission-critical environment.
- Supported Cisco 1001-X, Cisco 8000v, additional IOS-XE routing and switching platforms, and Palo Alto Networks firewalls.

### AKIMA / TUNDRA LLC

**Senior Deployment Network Engineer** | April 2024–July 2025

- Authored, reviewed, and submitted network designs, implementation plans, test procedures, and technical documentation aligned with customer, engineering, security, and acceptance requirements.
- Planned, installed, configured, and validated Cisco, Dell, and VMware infrastructure, including enterprise switches, servers, and virtualized platforms.
- Improved team capability through technical mentoring, demonstrations, deployment guidance, and reusable engineering documentation.
- Equipped team members with the technical knowledge needed to perform deployments and troubleshoot multi-vendor infrastructure.
- Coordinated deployment activities across engineering teams, customer stakeholders, and onsite personnel to reduce implementation risk and support successful acceptance.

### MSM TECHNOLOGY INC.

**Senior Data Center Network Engineer** | November 2022–March 2024

- Engineered and supported data center infrastructure spanning routers, switches, firewalls, load balancers, packet brokers, and Cisco ACI environments.
- Provided engineering support for complex configurations across multi-vendor enterprise and data center networks.
- Served as a technical consultant across Cisco APIC, Cisco IOS-XE, Juniper JUNOS, F5, and Gigamon platforms.
- Designed and implemented IPv6 access control lists to strengthen network security enforcement and support IPv6 adoption.
- Developed technical documentation and training materials to improve knowledge transfer and team troubleshooting capability.
- Mentored team members through technical training, demonstrations, and engineering documentation.

### LEIDOS INC.

**Lead Infrastructure Network Engineer** | November 2019–November 2022

- Led engineering support for multi-vendor infrastructure incorporating Cisco IOS-XR, Cisco IOS-XE, Juniper, F5, Gigamon, Linux, firewalls, load balancers, routers, switches, and servers.
- Served as a senior escalation resource for BGP, OSPF, MPLS, static routing, traffic management, and network availability issues.
- Provided engineering support for router, switch, firewall, load balancer, and server configurations.
- Advised engineering and operational teams on design decisions, configuration changes, troubleshooting strategies, and implementation risks.
- Produced technical documentation and delivered informal training that strengthened team readiness and knowledge transfer.
- Mentored team members through impromptu technical training, demonstrations, and documentation.

### BJC HEALTHCARE

**Senior Cisco Network Engineer Subject-Matter Expert** | July 2017–January 2019

- Served in a lead engineering role for a $9.7 million hospital network modernization initiative.
- Supported network architecture, implementation, migration, validation, and technical coordination for the hospital upgrade.
- Engineered and supported Cisco routing and switching infrastructure serving 2 hospitals and more than 40 clinics.
- Supported Cisco 2921 routers and Cisco Catalyst 9410 and 4510 switches across a highly available healthcare environment.
- Mentored engineers and project managers on technical dependencies, implementation risks, and network requirements.
- Served as a Cisco network engineering subject-matter expert for enterprise healthcare infrastructure.

### LEIDOS INC.

**Senior Network Engineer Subject-Matter Expert** | July 2016–July 2017

### LOCKHEED MARTIN

**Senior Network Engineer Subject-Matter Expert** | March 2016–July 2016

*Position continued without interruption after the supporting contract transitioned from Lockheed Martin to Leidos.*

- Supported Defense Information Systems Agency Joint Regional Security Stack engineering and operations as a senior network subject-matter expert.
- Provided engineering and technical support in a complex, multi-vendor defense environment.
- Advised cross-functional teams on Cisco, Juniper, Palo Alto Networks, F5, Gigamon, and Linux technologies.
- Engineered and troubleshot BGP, OSPF, MPLS, and static-routing configurations across mission-critical infrastructure.
- Supported Cisco IOS, IOS-XE, and IOS-XR routing and switching platforms.
- Delivered technical training and senior-level troubleshooting support to engineering and operations teams.
- Served as a senior team contributor and trainer supporting DISA JRSS and its customers.

### EDUCATION AND TECHNICAL DEVELOPMENT

**Full-Time Education and Career Development** | 2006–2016

- Pursued higher education and technical development while transitioning from military service to civilian network engineering.
- Earned associate and bachelor's degrees focused on information systems, computer networking, systems administration, cybersecurity, and enterprise infrastructure.
- Developed hands-on routing, switching, systems administration, and network security skills through formal education and technical lab work.

### UNITED STATES ARMY

**Information Technology Specialist** | April 1999–March 2006

- Managed 2 Internet cafés supporting 25 computers each and sustained 100% service availability.
- Administered 2 Cisco routers, 1 Cisco switch, specialty fiber-optic cabling, and communications equipment for 2 years.
- Served as a Windows domain administrator and provided technical support for approximately 800 users in a team environment.
- Contributed to the successful deployment of the Defense Messaging System, an encrypted email capability, in Germany.
- Earned formal recognition for successful completion of the Defense Messaging System deployment project.
- Supported network, systems, end-user, and communications requirements in military operational environments.

## EDUCATION

### WEBSTER UNIVERSITY

**Master of Business Administration** | March 2025

- Coursework included business and financial analysis, accounting, business strategy, and Securities and Exchange Commission filings.

### MICHIGAN TECHNOLOGICAL UNIVERSITY — Houghton, Michigan

**Bachelor of Science, Computer Networking and Systems Administration** | 2011–2014

- Coursework included project management, Cisco enterprise networking, network security engineering, Linux administration, and Windows Server administration.

### JEFFERSON COMMUNITY COLLEGE — Watertown, New York

**Associate of Applied Science, Computer Information Systems** | 2007–2010

- Completed foundational studies in information systems, computer networking, systems administration, and technical support.

## PROFESSIONAL DEVELOPMENT

- CCIE Enterprise Infrastructure Advanced Training, Micronics Training | December 2025.
- AWS Certified Cloud Practitioner Essentials, Amazon Web Services | May 2025.
- Dell VxRail Installation and Implementation Training | October 2024.
- CCIE Routing and Switching Advanced Training, Micronics Training | February 2017.
- Developing the Leader Within Workshop, Atlanta, Georgia | August 2006.
- Studied the five levels of leadership as a framework for leadership development and organizational success.

## TECHNICAL LAB

- Maintain and continuously expand a multi-vendor infrastructure lab incorporating Cisco routers and switches, Dell VxRail servers, virtualization technologies, and network security appliances.
- Use the lab to strengthen hands-on engineering, configuration, troubleshooting, integration, testing, and technical development skills.
RESUME
}

write_private_sector_resume() {
  cat > "$REPO_ROOT/resume/targeted/private-sector/Tim-Fox-Resume-Private-Sector.md" <<'RESUME'
# TIM FOX

**Principal Network Engineer | Network Infrastructure Leader**

United States | Open to Remote Roles | timfox2025@tim.army | tim.army

## EXECUTIVE PROFILE

Principal Network Engineer and people leader with extensive experience designing, modernizing, and supporting enterprise, data center, healthcare, and secure multi-vendor networks. Combines hands-on Cisco, Juniper, Palo Alto Networks, F5, Gigamon, Dell, VMware, Red Hat, and Linux expertise with team leadership, technical training, architecture documentation, and an MBA. Known for developing engineers, resolving complex escalations, and translating technical requirements into reliable implementation plans.

## EXPERTISE

- **Networking:** BGP, OSPF, MPLS, IPv4, IPv6, routing, switching, VLANs, access control lists, Cisco ACI, and Tier 3 troubleshooting.
- **Platforms:** Cisco IOS, IOS-XE, IOS-XR, Catalyst, ASR, APIC, Juniper JUNOS, Palo Alto Networks, F5, and Gigamon.
- **Data Center:** Dell servers and switches, VxRail, VMware, Linux, Red Hat Enterprise Linux, load balancing, and packet brokering.
- **Leadership:** People management, mentoring, technical training, design reviews, deployment planning, documentation, and stakeholder communication.

## SELECTED CERTIFICATIONS

- Cisco Certified Network Professional — Enterprise.
- Cisco Certified Network Associate.
- Juniper Networks Certified Associate — Junos.
- GIAC Certified Enterprise Defender.
- CompTIA Security+ CE.
- AWS Certified Cloud Practitioner.
- Dell VxRail Deploy Version 2.

## EXPERIENCE

### LEIDOS INC. — Supervisor / Principal Network Engineer
**March 2026–Present**

- Lead and develop 2 direct reports within an infrastructure engineering team of approximately 12 professionals.
- Deliver technical training across Dell servers, Red Hat Enterprise Linux, Juniper routing, and Cisco routing and switching platforms.
- Remove technical and operational blockers by coordinating access, equipment, documentation, training, and cross-team support.
- Provide senior technical guidance for complex network and infrastructure issues across multi-vendor environments.

### FEDITC — Senior Network Engineer
**July 2025–March 2026**

- Co-designed secure network architectures supporting mission-critical aircraft communications.
- Translated security, availability, and interoperability requirements into deployable technical designs.
- Conducted pre-release testing of encryption equipment and documented interoperability risks and deployment considerations.
- Delivered Tier 3 support across Cisco IOS-XE routing and switching, virtual routers, and Palo Alto Networks firewalls.

### AKIMA / TUNDRA LLC — Senior Deployment Network Engineer
**April 2024–July 2025**

- Authored and reviewed network designs, implementation plans, test procedures, and customer-facing technical documentation.
- Planned, installed, configured, and validated Cisco, Dell, and VMware infrastructure.
- Reduced deployment risk through technical mentoring, reusable documentation, demonstrations, and cross-team coordination.

### MSM TECHNOLOGY INC. — Senior Data Center Network Engineer
**November 2022–March 2024**

- Engineered and supported routers, switches, firewalls, load balancers, packet brokers, and Cisco ACI environments.
- Consulted across Cisco APIC and IOS-XE, Juniper JUNOS, F5, and Gigamon platforms.
- Designed and implemented IPv6 access control lists to strengthen security enforcement and support IPv6 adoption.

### LEIDOS INC. — Lead Infrastructure Network Engineer
**November 2019–November 2022**

- Led engineering support across Cisco IOS-XR and IOS-XE, Juniper, F5, Gigamon, Linux, firewalls, routers, switches, and servers.
- Served as a senior escalation resource for BGP, OSPF, MPLS, static routing, traffic management, and network availability.
- Advised teams on design choices, configuration changes, troubleshooting strategies, and implementation risks.

### BJC HEALTHCARE — Senior Cisco Network Engineer SME
**July 2017–January 2019**

- Served in a lead engineering role for a $9.7 million hospital network modernization initiative.
- Engineered Cisco infrastructure serving 2 hospitals and more than 40 clinics.
- Supported Cisco 2921 routers and Catalyst 9410 and 4510 switches in a highly available healthcare environment.

### LOCKHEED MARTIN / LEIDOS — Senior Network Engineer SME
**March 2016–July 2017**

- Continued in the same role without interruption after the supporting contract transitioned from Lockheed Martin to Leidos.
- Supported complex multi-vendor network engineering across Cisco, Juniper, Palo Alto Networks, F5, Gigamon, and Linux.
- Engineered and troubleshot BGP, OSPF, MPLS, and static-routing configurations.

### UNITED STATES ARMY — Information Technology Specialist
**April 1999–March 2006**

- Managed 2 Internet cafés supporting 50 total computers and sustained 100% service availability.
- Served as a Windows domain administrator and supported approximately 800 users.
- Contributed to the successful deployment of the Defense Messaging System in Germany.

## EDUCATION

- **Master of Business Administration**, Webster University | March 2025.
- **Bachelor of Science, Computer Networking and Systems Administration**, Michigan Technological University | 2011–2014.
- **Associate of Applied Science, Computer Information Systems**, Jefferson Community College | 2007–2010.
RESUME
}

write_federal_resume() {
  cat > "$REPO_ROOT/resume/targeted/federal-defense/Tim-Fox-Resume-Federal-Defense.md" <<'RESUME'
# TIM FOX

**Principal Network Engineer | Federal and Defense Infrastructure Leader**

United States | Open to Remote Roles | timfox2025@tim.army | tim.army

## PROFESSIONAL SUMMARY

Principal Network Engineer and technical leader with military, federal-contractor, healthcare, and enterprise experience supporting mission-critical and secure network environments. Provides people leadership, architecture support, technical training, Tier 3 troubleshooting, implementation planning, and multi-vendor engineering across Cisco, Juniper, Palo Alto Networks, F5, Gigamon, Dell, VMware, Red Hat, and Linux. Experienced with classified and unclassified networks, encrypted communications, DISA JRSS, Air Force aircraft communications, routing protocols, IPv6 security controls, data center infrastructure, and customer technical documentation.

## TECHNICAL QUALIFICATIONS

- **Routing and Switching:** BGP, OSPF, MPLS, static routing, IPv4, IPv6, VLANs, access control lists, Cisco IOS, IOS-XE, IOS-XR, Catalyst, ASR, Cisco 1001-X, Cisco 8000v, and Juniper JUNOS.
- **Security and Visibility:** Palo Alto Networks, F5, TACLANE, Gigamon, encrypted communications, firewall engineering, packet brokers, segmentation, and IPv6 security policies.
- **Data Center and Systems:** Cisco ACI and APIC, Dell servers and switches, Dell VxRail, VMware, Linux, Red Hat Enterprise Linux, load balancers, and virtualized platforms.
- **Program Delivery:** Technical leadership, direct supervision, mentoring, training, architecture documentation, implementation plans, test procedures, technical reviews, stakeholder coordination, and Tier 3 escalation support.

## CERTIFICATIONS AND QUALIFICATIONS

- Cisco Certified Network Professional — Enterprise.
- Cisco Certified Network Associate.
- Juniper Networks Certified Associate — Junos.
- GIAC Certified Enterprise Defender.
- CompTIA Security+ CE.
- Fortinet Certified Associate in Cybersecurity.
- AWS Certified Cloud Practitioner.
- Dell VxRail Deploy Version 2.
- VMware Certified Associate — Data Center Virtualization.
- DoD 8570 IAT II and IAT III; DoD 8140-aligned qualifications.

## PROFESSIONAL EXPERIENCE

### LEIDOS INC.
**Supervisor / Principal Network Engineer** | March 2026–Present

- Lead and develop 2 direct reports within a growing infrastructure engineering team of approximately 12 professionals.
- Provide technical training and knowledge transfer covering Dell servers, Red Hat Enterprise Linux, Juniper routers, and Cisco routing and switching platforms.
- Remove technical and operational blockers by coordinating equipment, access, documentation, training, and cross-team assistance.
- Support employee development, team readiness, operational success, and positive team morale through hands-on leadership and mentoring.
- Provide senior technical guidance for complex network and infrastructure issues across multi-vendor environments.

### FEDITC
**Senior Network Engineer** | July 2025–March 2026

- Co-designed classified and unclassified network architectures supporting Air Force aircraft communications.
- Translated mission, security, availability, and interoperability requirements into deployable technical designs.
- Conducted pre-release testing of TACLANE encryption equipment and documented operational findings, interoperability risks, and deployment considerations.
- Delivered Tier 3 engineering support for the Executive Aircraft Communications Network.
- Resolved complex routing, switching, firewall, and virtual-network issues in a mission-critical environment.
- Supported Cisco 1001-X, Cisco 8000v, additional IOS-XE routing and switching platforms, and Palo Alto Networks firewalls.

### AKIMA / TUNDRA LLC
**Senior Deployment Network Engineer** | April 2024–July 2025

- Authored, reviewed, and submitted network designs, implementation plans, test procedures, and technical documentation aligned with customer, engineering, security, and acceptance requirements.
- Planned, installed, configured, and validated Cisco, Dell, and VMware infrastructure, including enterprise switches, servers, and virtualized platforms.
- Improved team capability through technical mentoring, demonstrations, deployment guidance, and reusable engineering documentation.
- Coordinated deployment activities across engineering teams, customer stakeholders, and onsite personnel to reduce implementation risk and support successful acceptance.

### MSM TECHNOLOGY INC.
**Senior Data Center Network Engineer** | November 2022–March 2024

- Engineered and supported data center infrastructure spanning routers, switches, firewalls, load balancers, packet brokers, and Cisco ACI environments.
- Provided engineering support for complex configurations across multi-vendor enterprise and data center networks.
- Served as a technical consultant across Cisco APIC, Cisco IOS-XE, Juniper JUNOS, F5, and Gigamon platforms.
- Designed and implemented IPv6 access control lists to strengthen network security enforcement and support IPv6 adoption.
- Developed technical documentation and training materials to improve knowledge transfer and team troubleshooting capability.

### LEIDOS INC.
**Lead Infrastructure Network Engineer** | November 2019–November 2022

- Led engineering support for multi-vendor infrastructure incorporating Cisco IOS-XR, Cisco IOS-XE, Juniper, F5, Gigamon, Linux, firewalls, load balancers, routers, switches, and servers.
- Served as a senior escalation resource for BGP, OSPF, MPLS, static routing, traffic management, and network availability issues.
- Advised engineering and operational teams on design decisions, configuration changes, troubleshooting strategies, and implementation risks.
- Produced technical documentation and delivered informal training that strengthened team readiness and knowledge transfer.

### BJC HEALTHCARE
**Senior Cisco Network Engineer Subject-Matter Expert** | July 2017–January 2019

- Served in a lead engineering role for a $9.7 million hospital network modernization initiative.
- Supported network architecture, implementation, migration, validation, and technical coordination for the hospital upgrade.
- Engineered and supported Cisco routing and switching infrastructure serving 2 hospitals and more than 40 clinics.
- Supported Cisco 2921 routers and Cisco Catalyst 9410 and 4510 switches across a highly available healthcare environment.

### LEIDOS INC.
**Senior Network Engineer Subject-Matter Expert** | July 2016–July 2017

### LOCKHEED MARTIN
**Senior Network Engineer Subject-Matter Expert** | March 2016–July 2016

*Position continued without interruption after the supporting contract transitioned from Lockheed Martin to Leidos.*

- Supported Defense Information Systems Agency Joint Regional Security Stack engineering and operations as a senior network subject-matter expert.
- Advised cross-functional teams on Cisco, Juniper, Palo Alto Networks, F5, Gigamon, and Linux technologies.
- Engineered and troubleshot BGP, OSPF, MPLS, and static-routing configurations across mission-critical infrastructure.
- Supported Cisco IOS, IOS-XE, and IOS-XR routing and switching platforms.
- Delivered technical training and senior-level troubleshooting support to engineering and operations teams.

### EDUCATION AND TECHNICAL DEVELOPMENT
**Full-Time Education and Career Development** | 2006–2016

- Pursued higher education and technical development while transitioning from military service to civilian network engineering.
- Earned associate and bachelor's degrees focused on information systems, networking, systems administration, cybersecurity, and enterprise infrastructure.
- Developed hands-on routing, switching, systems administration, and network security skills through formal education and technical lab work.

### UNITED STATES ARMY
**Information Technology Specialist** | April 1999–March 2006

- Managed 2 Internet cafés supporting 25 computers each and sustained 100% service availability.
- Administered 2 Cisco routers, 1 Cisco switch, specialty fiber-optic cabling, and communications equipment for 2 years.
- Served as a Windows domain administrator and provided technical support for approximately 800 users in a team environment.
- Contributed to the successful deployment of the Defense Messaging System, an encrypted email capability, in Germany.
- Earned formal recognition for successful completion of the Defense Messaging System deployment project.

## EDUCATION

- **Master of Business Administration**, Webster University | March 2025.
- **Bachelor of Science, Computer Networking and Systems Administration**, Michigan Technological University — Houghton, Michigan | 2011–2014.
- **Associate of Applied Science, Computer Information Systems**, Jefferson Community College — Watertown, New York | 2007–2010.

## PROFESSIONAL DEVELOPMENT

- CCIE Enterprise Infrastructure Advanced Training, Micronics Training | December 2025.
- AWS Certified Cloud Practitioner Essentials, Amazon Web Services | May 2025.
- Dell VxRail Installation and Implementation Training | October 2024.
- CCIE Routing and Switching Advanced Training, Micronics Training | February 2017.
- Developing the Leader Within Workshop, Atlanta, Georgia | August 2006.
RESUME
}

write_scripts_readme() {
  cat > "$REPO_ROOT/scripts/bash/README.md" <<'README'
# Bash automation

This directory is the canonical location for all repository Bash automation.

## Current build script

- `create-tim-fox-resume.sh` — Generates the master and targeted Markdown resumes, validates bullet punctuation, and migrates shell scripts from `~/Downloads` into this directory.

## Policy

- Do not run permanent repository scripts from `~/Downloads`.
- Move `.sh` and `.bash` files into this directory before committing them.
- Run `bash -n scripts/bash/<script>.sh` before execution.
- Make committed scripts executable with `chmod +x`.
- Do not store credentials, tokens, private keys, or controlled information in scripts.
README
}

write_manifest() {
  local generated_at branch commit
  generated_at=$(date '+%Y-%m-%d %H:%M:%S %Z')
  branch=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || printf 'unknown')
  commit=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || printf 'uncommitted')

  cat > "$REPO_ROOT/docs/resume-build-manifest.md" <<MANIFEST
# Resume build manifest

- **Generated:** $generated_at.
- **Script version:** $SCRIPT_VERSION.
- **Repository:** $REPO_ROOT.
- **Branch:** $branch.
- **Starting commit:** $commit.

## Generated resume sources

- \`resume/master/Tim-Fox-Resume.md\`.
- \`resume/targeted/private-sector/Tim-Fox-Resume-Private-Sector.md\`.
- \`resume/targeted/federal-defense/Tim-Fox-Resume-Federal-Defense.md\`.

## Automation location

All Bash scripts are maintained in \`scripts/bash/\`. Shell scripts found directly in \`$DOWNLOADS_DIR\` are migrated there unless \`--skip-script-move\` is used.
MANIFEST
}

validate_bullet_periods() {
  local file failures=0
  local files=(
    "$REPO_ROOT/resume/master/Tim-Fox-Resume.md"
    "$REPO_ROOT/resume/targeted/private-sector/Tim-Fox-Resume-Private-Sector.md"
    "$REPO_ROOT/resume/targeted/federal-defense/Tim-Fox-Resume-Federal-Defense.md"
  )

  for file in "${files[@]}"; do
    if awk '
      /^- / {
        if ($0 !~ /\.[[:space:]]*$/) {
          printf "%s:%d: bullet does not end with a period: %s\n", FILENAME, NR, $0
          bad=1
        }
      }
      END { exit bad }
    ' "$file"; then
      log "PASS: Every bullet ends with a period in ${file#"$REPO_ROOT/"}."
    else
      failures=1
    fi
  done

  (( failures == 0 )) || fatal "Resume bullet punctuation validation failed."
}

validate_required_content() {
  local master="$REPO_ROOT/resume/master/Tim-Fox-Resume.md"
  local required=(
    "TIM FOX"
    "Supervisor / Principal Network Engineer"
    "Defense Messaging System"
    "Jefferson Community College"
    "Michigan Technological University"
    "Lockheed Martin"
    "Leidos"
  )

  local item
  for item in "${required[@]}"; do
    grep -Fiq "$item" "$master" || fatal "Required resume content is missing: $item"
  done

  log "PASS: Required resume sections and corrected employment and education details are present."
}

validate_scripts() {
  local script failures=0

  while IFS= read -r -d '' script; do
    if bash -n "$script"; then
      log "PASS: Bash syntax: ${script#"$REPO_ROOT/"}."
    else
      failures=1
    fi
  done < <(find "$REPO_ROOT/scripts/bash" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.bash' \) -print0)

  (( failures == 0 )) || fatal "One or more scripts failed Bash syntax validation."
}

commit_and_push() {
  [[ "$COMMIT_CHANGES" == true ]] || return 0

  if [[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    log "No repository changes require a commit."
  else
    git -C "$REPO_ROOT" add \
      resume \
      docs/resume-build-manifest.md \
      scripts/bash \
      exports/docx/.gitkeep \
      exports/pdf/.gitkeep \
      archive/.gitkeep

    git -C "$REPO_ROOT" commit -m "$COMMIT_MESSAGE"
    log "Committed resume sources and repository scripts."
  fi

  if [[ "$PUSH_CHANGES" == true ]]; then
    local branch
    branch=$(git -C "$REPO_ROOT" branch --show-current)
    [[ -n "$branch" ]] || fatal "Cannot push from a detached HEAD."

    git -C "$REPO_ROOT" push -u origin "$branch"
    log "Pushed branch '$branch' to origin."
  fi
}

open_master_resume() {
  [[ "$OPEN_FILES" == true ]] || return 0

  if command -v open >/dev/null 2>&1; then
    open "$REPO_ROOT/resume/master/Tim-Fox-Resume.md"
  else
    warn "The macOS 'open' command is unavailable."
  fi
}

print_result() {
  cat <<RESULT

RESULT: TIM FOX RESUME CREATED AND VALIDATED

Repository:       $REPO_ROOT
Master resume:    resume/master/Tim-Fox-Resume.md
Private sector:   resume/targeted/private-sector/Tim-Fox-Resume-Private-Sector.md
Federal/defense:  resume/targeted/federal-defense/Tim-Fox-Resume-Federal-Defense.md
Scripts:          scripts/bash/

Next review:
  git -C "$REPO_ROOT" status --short
  sed -n '1,220p' "$REPO_ROOT/resume/master/Tim-Fox-Resume.md"
RESULT
}

main() {
  require_command git
  require_command awk
  require_command find

  capture_self
  parse_args "$@"
  detect_repo_root

  log "Repository root: $REPO_ROOT"
  ensure_structure
  install_self
  move_download_scripts

  write_master_resume
  write_private_sector_resume
  write_federal_resume
  write_scripts_readme
  write_manifest

  validate_bullet_periods
  validate_required_content
  validate_scripts
  commit_and_push
  open_master_resume
  print_result
}

main "$@"

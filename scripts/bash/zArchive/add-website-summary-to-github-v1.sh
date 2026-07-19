#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="add-website-summary-to-github-v1.sh"
readonly SCRIPT_VERSION="2026.07.17.1"
readonly DEFAULT_REPO="${HOME}/Documents/github/Tim-Fox-Resume"
readonly WEBSITE_FILENAME="tim-army-site-summary-and-internal-links.md"
readonly EXPECTED_SHA256="e4f1791cef87cc5267e7edfaf44558f577f6e4688b56bc73ba4927ee193f7658"

REPO_DIR="${DEFAULT_REPO}"
DO_COMMIT=true
DO_PUSH=true
OPEN_REPO=false
COMMIT_MESSAGE="docs: add tim.army website inventory"

log() {
  printf '[Tim-Fox-Resume] %s\n' "$*"
}

error() {
  printf '[Tim-Fox-Resume] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'HELP'
add-website-summary-to-github-v1.sh

Creates the repository website directory and adds:
  website/tim-army-site-summary-and-internal-links.md

Usage:
  add-website-summary-to-github-v1.sh [options]

Options:
  --repo PATH       Repository root.
                    Default: $HOME/Documents/github/Tim-Fox-Resume
  --message TEXT    Git commit message.
  --no-commit       Write files without committing or pushing.
  --no-push         Commit locally without pushing.
  --open            Open the GitHub repository after a successful push.
  --version         Show the script version.
  -h, --help        Show this help.
HELP
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
    --version)
      printf '%s\n' "${SCRIPT_VERSION}"
      exit 0
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
command -v shasum >/dev/null 2>&1 || error "shasum is required."

[[ -d "${REPO_DIR}" ]] || error "Repository directory does not exist: ${REPO_DIR}"
REPO_DIR="$(cd "${REPO_DIR}" && pwd -P)"

git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || error "Not a Git repository: ${REPO_DIR}"

GIT_ROOT="$(git -C "${REPO_DIR}" rev-parse --show-toplevel)"
[[ "${GIT_ROOT}" == "${REPO_DIR}" ]] \
  || error "Expected repository root ${REPO_DIR}, but Git reports ${GIT_ROOT}"

SCRIPTS_DIR="${REPO_DIR}/scripts/bash"
WEBSITE_DIR="${REPO_DIR}/website"
TARGET_FILE="${WEBSITE_DIR}/${WEBSITE_FILENAME}"
CANONICAL_SCRIPT="${SCRIPTS_DIR}/${SCRIPT_NAME}"
SOURCE_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"

mkdir -p "${SCRIPTS_DIR}" "${WEBSITE_DIR}"

if [[ "${SOURCE_SCRIPT}" != "${CANONICAL_SCRIPT}" ]]; then
  cp "${SOURCE_SCRIPT}" "${CANONICAL_SCRIPT}"
  chmod +x "${CANONICAL_SCRIPT}"
  log "Installed canonical script: scripts/bash/${SCRIPT_NAME}"
fi

cat > "${TARGET_FILE}" <<'WEBSITE_CONTENT_EOF'
# tim.army Website Summary and Internal-Link Inventory

**Unique content-page URLs inventoried:** 235

## Website summary

- **Site type:** A public DokuWiki knowledge base titled *Tim's Technology Gauntlet Wiki*.
- **Primary purpose:** Preserve and share technical notes, commands, configurations, labs, study material, and troubleshooting references.
- **Main emphasis:** Enterprise networking, especially Cisco technologies, BGP, routing, switching, MPLS, security, IOS/IOS-XE/IOS-XR labs, and certification study material.
- **Additional technical areas:** Juniper, Linux, VMware, Dell, EVE-NG, Raspberry Pi, Windows, software tools, automation, programming, service-provider networking, and homelab documentation.
- **Professional profile:** The About Me page describes an Army and enterprise-networking background, education, engineering experience, and professional certifications.
- **Personal and community content:** Veteran resources, 3D-print tracking, recipes, photographs, books, movies, and miscellaneous reference pages.

## Scope and method

- Inventory built from the public DokuWiki sitemap and expanded namespaces.
- Repeated namespace/index entries were deduplicated.
- DokuWiki utility URLs—login, old revisions, backlinks, page source, media manager, and query variants—are excluded.
- External links to other domains are excluded.

## Internal content links

### Core and top-level pages

- [`3d_prints`](https://tim.army/doku/doku.php?id=3d_prints)
- [`aboutme`](https://tim.army/doku/doku.php?id=aboutme)
- [`acronyms`](https://tim.army/doku/doku.php?id=acronyms)
- [`apc`](https://tim.army/doku/doku.php?id=apc)
- [`automation`](https://tim.army/doku/doku.php?id=automation)
- [`books`](https://tim.army/doku/doku.php?id=books)
- [`cisco`](https://tim.army/doku/doku.php?id=cisco)
- [`college`](https://tim.army/doku/doku.php?id=college)
- [`constitution`](https://tim.army/doku/doku.php?id=constitution)
- [`dell`](https://tim.army/doku/doku.php?id=dell)
- [`device_list`](https://tim.army/doku/doku.php?id=device_list)
- [`dokuwiki`](https://tim.army/doku/doku.php?id=dokuwiki)
- [`eve-ng`](https://tim.army/doku/doku.php?id=eve-ng)
- [`f5`](https://tim.army/doku/doku.php?id=f5)
- [`favorite_links`](https://tim.army/doku/doku.php?id=favorite_links)
- [`food`](https://tim.army/doku/doku.php?id=food)
- [`fun`](https://tim.army/doku/doku.php?id=fun)
- [`gigamon`](https://tim.army/doku/doku.php?id=gigamon)
- [`homelab`](https://tim.army/doku/doku.php?id=homelab)
- [`hp_switch`](https://tim.army/doku/doku.php?id=hp_switch)
- [`juniper`](https://tim.army/doku/doku.php?id=juniper)
- [`linux`](https://tim.army/doku/doku.php?id=linux)
- [`macos`](https://tim.army/doku/doku.php?id=macos)
- [`movies`](https://tim.army/doku/doku.php?id=movies)
- [`otdr`](https://tim.army/doku/doku.php?id=otdr)
- [`pics`](https://tim.army/doku/doku.php?id=pics)
- [`playground`](https://tim.army/doku/doku.php?id=playground)
- [`programming`](https://tim.army/doku/doku.php?id=programming)
- [`raspberrypi`](https://tim.army/doku/doku.php?id=raspberrypi)
- [`sdwan`](https://tim.army/doku/doku.php?id=sdwan)
- [`service_provider`](https://tim.army/doku/doku.php?id=service_provider)
- [`software`](https://tim.army/doku/doku.php?id=software)
- [`start`](https://tim.army/doku/doku.php?id=start)
- [`training_resources`](https://tim.army/doku/doku.php?id=training_resources)
- [`trunks`](https://tim.army/doku/doku.php?id=trunks)
- [`ui`](https://tim.army/doku/doku.php?id=ui)
- [`veterans`](https://tim.army/doku/doku.php?id=veterans)
- [`virl`](https://tim.army/doku/doku.php?id=virl)
- [`vlans`](https://tim.army/doku/doku.php?id=vlans)
- [`vmware`](https://tim.army/doku/doku.php?id=vmware)
- [`windows`](https://tim.army/doku/doku.php?id=windows)
- [`xponology`](https://tim.army/doku/doku.php?id=xponology)

### Acronyms

- [`acronyms:a`](https://tim.army/doku/doku.php?id=acronyms%3Aa)
- [`acronyms:b`](https://tim.army/doku/doku.php?id=acronyms%3Ab)
- [`acronyms:c`](https://tim.army/doku/doku.php?id=acronyms%3Ac)
- [`acronyms:d`](https://tim.army/doku/doku.php?id=acronyms%3Ad)
- [`acronyms:e`](https://tim.army/doku/doku.php?id=acronyms%3Ae)
- [`acronyms:f`](https://tim.army/doku/doku.php?id=acronyms%3Af)
- [`acronyms:g`](https://tim.army/doku/doku.php?id=acronyms%3Ag)
- [`acronyms:h`](https://tim.army/doku/doku.php?id=acronyms%3Ah)
- [`acronyms:i`](https://tim.army/doku/doku.php?id=acronyms%3Ai)
- [`acronyms:j`](https://tim.army/doku/doku.php?id=acronyms%3Aj)
- [`acronyms:k`](https://tim.army/doku/doku.php?id=acronyms%3Ak)
- [`acronyms:l`](https://tim.army/doku/doku.php?id=acronyms%3Al)
- [`acronyms:m`](https://tim.army/doku/doku.php?id=acronyms%3Am)
- [`acronyms:n`](https://tim.army/doku/doku.php?id=acronyms%3An)
- [`acronyms:o`](https://tim.army/doku/doku.php?id=acronyms%3Ao)
- [`acronyms:p`](https://tim.army/doku/doku.php?id=acronyms%3Ap)
- [`acronyms:q`](https://tim.army/doku/doku.php?id=acronyms%3Aq)
- [`acronyms:r`](https://tim.army/doku/doku.php?id=acronyms%3Ar)
- [`acronyms:s`](https://tim.army/doku/doku.php?id=acronyms%3As)
- [`acronyms:t`](https://tim.army/doku/doku.php?id=acronyms%3At)
- [`acronyms:u`](https://tim.army/doku/doku.php?id=acronyms%3Au)
- [`acronyms:v`](https://tim.army/doku/doku.php?id=acronyms%3Av)
- [`acronyms:w`](https://tim.army/doku/doku.php?id=acronyms%3Aw)
- [`acronyms:x`](https://tim.army/doku/doku.php?id=acronyms%3Ax)
- [`acronyms:y`](https://tim.army/doku/doku.php?id=acronyms%3Ay)
- [`acronyms:z`](https://tim.army/doku/doku.php?id=acronyms%3Az)
- [`acronyms:others`](https://tim.army/doku/doku.php?id=acronyms%3Aothers)

### Automation

- [`automation:getting-started`](https://tim.army/doku/doku.php?id=automation%3Agetting-started)

### Cisco — main

- [`cisco:acl`](https://tim.army/doku/doku.php?id=cisco%3Aacl)
- [`cisco:ad`](https://tim.army/doku/doku.php?id=cisco%3Aad)
- [`cisco:asa`](https://tim.army/doku/doku.php?id=cisco%3Aasa)
- [`cisco:bgp`](https://tim.army/doku/doku.php?id=cisco%3Abgp)
- [`cisco:books`](https://tim.army/doku/doku.php?id=cisco%3Abooks)
- [`cisco:certification_topics`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics)
- [`cisco:dmvpn`](https://tim.army/doku/doku.php?id=cisco%3Admvpn)
- [`cisco:dnac`](https://tim.army/doku/doku.php?id=cisco%3Adnac)
- [`cisco:http_server`](https://tim.army/doku/doku.php?id=cisco%3Ahttp_server)
- [`cisco:ios_xr_notes`](https://tim.army/doku/doku.php?id=cisco%3Aios_xr_notes)
- [`cisco:l2_notes`](https://tim.army/doku/doku.php?id=cisco%3Al2_notes)
- [`cisco:l3_notes`](https://tim.army/doku/doku.php?id=cisco%3Al3_notes)
- [`cisco:labs`](https://tim.army/doku/doku.php?id=cisco%3Alabs)
- [`cisco:lacp_rtr_sw`](https://tim.army/doku/doku.php?id=cisco%3Alacp_rtr_sw)
- [`cisco:layer_2`](https://tim.army/doku/doku.php?id=cisco%3Alayer_2)
- [`cisco:links`](https://tim.army/doku/doku.php?id=cisco%3Alinks)
- [`cisco:mpls`](https://tim.army/doku/doku.php?id=cisco%3Ampls)
- [`cisco:nat64`](https://tim.army/doku/doku.php?id=cisco%3Anat64)
- [`cisco:nexus`](https://tim.army/doku/doku.php?id=cisco%3Anexus)
- [`cisco:redistribution`](https://tim.army/doku/doku.php?id=cisco%3Aredistribution)
- [`cisco:security`](https://tim.army/doku/doku.php?id=cisco%3Asecurity)
- [`cisco:services`](https://tim.army/doku/doku.php?id=cisco%3Aservices)
- [`cisco:term_serv`](https://tim.army/doku/doku.php?id=cisco%3Aterm_serv)
- [`cisco:vlans`](https://tim.army/doku/doku.php?id=cisco%3Avlans)
- [`cisco:vpls`](https://tim.army/doku/doku.php?id=cisco%3Avpls)
- [`cisco:vrf`](https://tim.army/doku/doku.php?id=cisco%3Avrf)

### Cisco — ASA

- [`cisco:asa:9300_conversion_from_5585`](https://tim.army/doku/doku.php?id=cisco%3Aasa%3A9300_conversion_from_5585)
- [`cisco:asa:base-config`](https://tim.army/doku/doku.php?id=cisco%3Aasa%3Abase-config)

### Cisco — BGP

- [`cisco:bgp:bgp_notes`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Abgp_notes)
- [`cisco:bgp:ip_routing_notes`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Aip_routing_notes)
- [`cisco:bgp:lesson_1`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Alesson_1)
- [`cisco:bgp:lessons`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Alessons)
- [`cisco:bgp:path_attributes`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Apath_attributes)
- [`cisco:bgp:ip_routing_notes:chapter_10`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Aip_routing_notes%3Achapter_10)
- [`cisco:bgp:ios-xe_labs:lab1`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Aios-xe_labs%3Alab1)
- [`cisco:bgp:ios-xe_labs:lab2`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Aios-xe_labs%3Alab2)
- [`cisco:bgp:ios-xe_labs:lab3`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Aios-xe_labs%3Alab3)
- [`cisco:bgp:ios-xe_labs:lab13`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Aios-xe_labs%3Alab13)
- [`cisco:bgp:ios-xe_labs:lab14`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Aios-xe_labs%3Alab14)
- [`cisco:bgp:ios-xe_labs:lab15`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Aios-xe_labs%3Alab15)
- [`cisco:bgp:ios-xe_labs:lab1:lab1_answer`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Aios-xe_labs%3Alab1%3Alab1_answer)
- [`cisco:bgp:ios-xe_labs:lab2:lab2_answer`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Aios-xe_labs%3Alab2%3Alab2_answer)
- [`cisco:bgp:ios-xr:lab3`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Aios-xr%3Alab3)
- [`cisco:bgp:ios-xr:lab4`](https://tim.army/doku/doku.php?id=cisco%3Abgp%3Aios-xr%3Alab4)

### Cisco — books

- [`cisco:books:ccie_bridging_the_gap`](https://tim.army/doku/doku.php?id=cisco%3Abooks%3Accie_bridging_the_gap)
- [`cisco:books:ccnp_300-730`](https://tim.army/doku/doku.php?id=cisco%3Abooks%3Accnp_300-730)
- [`cisco:books:ccie_bridging_the_gap:ch2`](https://tim.army/doku/doku.php?id=cisco%3Abooks%3Accie_bridging_the_gap%3Ach2)
- [`cisco:books:ccie_bridging_the_gap:ch10`](https://tim.army/doku/doku.php?id=cisco%3Abooks%3Accie_bridging_the_gap%3Ach10)
- [`cisco:books:ccie_bridging_the_gap:template`](https://tim.army/doku/doku.php?id=cisco%3Abooks%3Accie_bridging_the_gap%3Atemplate)
- [`cisco:books:ccie_bridging_the_gap:ch10:lab10-1`](https://tim.army/doku/doku.php?id=cisco%3Abooks%3Accie_bridging_the_gap%3Ach10%3Alab10-1)
- [`cisco:books:ccie_bridging_the_gap:ch10:lab10-2-1`](https://tim.army/doku/doku.php?id=cisco%3Abooks%3Accie_bridging_the_gap%3Ach10%3Alab10-2-1)
- [`cisco:books:ccie_bridging_the_gap:ch10:lab10-2`](https://tim.army/doku/doku.php?id=cisco%3Abooks%3Accie_bridging_the_gap%3Ach10%3Alab10-2)
- [`cisco:books:ccnp_300-730:ch3`](https://tim.army/doku/doku.php?id=cisco%3Abooks%3Accnp_300-730%3Ach3)

### Cisco — certification topics

- [`cisco:certification_topics:ccie-ei`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Accie-ei)
- [`cisco:certification_topics:ccna_security`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Accna_security)
- [`cisco:certification_topics:ccnp_route`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Accnp_route)
- [`cisco:certification_topics:ccnp_switch`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Accnp_switch)
- [`cisco:certification_topics:general`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Ageneral)
- [`cisco:certification_topics:ccie-ei:1.1.ai`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Accie-ei%3A1.1.ai)
- [`cisco:certification_topics:ccie-ei:1.1.aii`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Accie-ei%3A1.1.aii)
- [`cisco:certification_topics:ccie-ei:1.1.aiii`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Accie-ei%3A1.1.aiii)
- [`cisco:certification_topics:ccie-ei:1.1.aiv`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Accie-ei%3A1.1.aiv)
- [`cisco:certification_topics:ccie-ei:1.1.bi`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Accie-ei%3A1.1.bi)
- [`cisco:certification_topics:ccie-ei:1.1.biii`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Accie-ei%3A1.1.biii)
- [`cisco:certification_topics:ccie-ei:1.3.e`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Accie-ei%3A1.3.e)
- [`cisco:certification_topics:ccna_security:1.0`](https://tim.army/doku/doku.php?id=cisco%3Acertification_topics%3Accna_security%3A1.0)

### Cisco — labs and routing

- [`cisco:dmvpn:eigrp_phase_1-2`](https://tim.army/doku/doku.php?id=cisco%3Admvpn%3Aeigrp_phase_1-2)
- [`cisco:labs:00000`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3A00000)
- [`cisco:labs:00100`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3A00100)
- [`cisco:labs:00200`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3A00200)
- [`cisco:labs:00300`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3A00300)
- [`cisco:labs:00400`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3A00400)
- [`cisco:labs:00500`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3A00500)
- [`cisco:labs:00600`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3A00600)
- [`cisco:labs:00800`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3A00800)
- [`cisco:labs:01000`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3A01000)
- [`cisco:labs:ios`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios)
- [`cisco:labs:ios_xr`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios_xr)
- [`cisco:labs:ios-xe`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios-xe)
- [`cisco:labs:ios:lab1`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios%3Alab1)
- [`cisco:labs:ios:lab2`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios%3Alab2)
- [`cisco:labs:ios_xr:lab_misc_1`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios_xr%3Alab_misc_1)
- [`cisco:labs:ios_xr:lab1`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios_xr%3Alab1)
- [`cisco:labs:ios_xr:lab2`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios_xr%3Alab2)
- [`cisco:labs:ios_xr:lab3`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios_xr%3Alab3)
- [`cisco:labs:ios_xr:lab4`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios_xr%3Alab4)
- [`cisco:labs:ios_xr:lab5`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios_xr%3Alab5)
- [`cisco:labs:ios_xr:lab6`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios_xr%3Alab6)
- [`cisco:labs:ios_xr:lab7`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios_xr%3Alab7)
- [`cisco:labs:ios_xr:lab8`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios_xr%3Alab8)
- [`cisco:labs:ios_xr:lab9`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios_xr%3Alab9)
- [`cisco:labs:ios-xe:lab16`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios-xe%3Alab16)
- [`cisco:labs:ios-xe:lab17`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios-xe%3Alab17)
- [`cisco:labs:ios-xe:lab18`](https://tim.army/doku/doku.php?id=cisco%3Alabs%3Aios-xe%3Alab18)
- [`cisco:layer_2:stp`](https://tim.army/doku/doku.php?id=cisco%3Alayer_2%3Astp)
- [`cisco:mpls:commands`](https://tim.army/doku/doku.php?id=cisco%3Ampls%3Acommands)
- [`cisco:redistribution:commands`](https://tim.army/doku/doku.php?id=cisco%3Aredistribution%3Acommands)
- [`cisco:redistribution:labs`](https://tim.army/doku/doku.php?id=cisco%3Aredistribution%3Alabs)
- [`cisco:redistribution:pat_manipulation`](https://tim.army/doku/doku.php?id=cisco%3Aredistribution%3Apat_manipulation)
- [`cisco:redistribution:rip_eigrp_ospf`](https://tim.army/doku/doku.php?id=cisco%3Aredistribution%3Arip_eigrp_ospf)
- [`cisco:redistribution:route_maps`](https://tim.army/doku/doku.php?id=cisco%3Aredistribution%3Aroute_maps)
- [`cisco:redistribution:routing_loops`](https://tim.army/doku/doku.php?id=cisco%3Aredistribution%3Arouting_loops)
- [`cisco:redistribution:labs:lab1`](https://tim.army/doku/doku.php?id=cisco%3Aredistribution%3Alabs%3Alab1)
- [`cisco:security:1`](https://tim.army/doku/doku.php?id=cisco%3Asecurity%3A1)
- [`cisco:security:2`](https://tim.army/doku/doku.php?id=cisco%3Asecurity%3A2)
- [`cisco:security:3`](https://tim.army/doku/doku.php?id=cisco%3Asecurity%3A3)
- [`cisco:security:template`](https://tim.army/doku/doku.php?id=cisco%3Asecurity%3Atemplate)
- [`cisco:services:dns`](https://tim.army/doku/doku.php?id=cisco%3Aservices%3Adns)

### Other technical sections

- [`college:mba`](https://tim.army/doku/doku.php?id=college%3Amba)
- [`constitution:a13`](https://tim.army/doku/doku.php?id=constitution%3Aa13)
- [`dell:idrac`](https://tim.army/doku/doku.php?id=dell%3Aidrac)
- [`dell:nim`](https://tim.army/doku/doku.php?id=dell%3Anim)
- [`eve-ng:eve_change_log`](https://tim.army/doku/doku.php?id=eve-ng%3Aeve_change_log)
- [`eve-ng:images_supported`](https://tim.army/doku/doku.php?id=eve-ng%3Aimages_supported)
- [`homelab:current-pics`](https://tim.army/doku/doku.php?id=homelab%3Acurrent-pics)
- [`homelab:obsolete-pics`](https://tim.army/doku/doku.php?id=homelab%3Aobsolete-pics)
- [`homelab:power`](https://tim.army/doku/doku.php?id=homelab%3Apower)
- [`juniper:cli_basics`](https://tim.army/doku/doku.php?id=juniper%3Acli_basics)
- [`juniper:commands`](https://tim.army/doku/doku.php?id=juniper%3Acommands)
- [`juniper:managing_configurations`](https://tim.army/doku/doku.php?id=juniper%3Amanaging_configurations)
- [`juniper:os_upgrade`](https://tim.army/doku/doku.php?id=juniper%3Aos_upgrade)
- [`juniper:route_preferences`](https://tim.army/doku/doku.php?id=juniper%3Aroute_preferences)
- [`juniper:routing_tables`](https://tim.army/doku/doku.php?id=juniper%3Arouting_tables)
- [`juniper:tshoot_bad`](https://tim.army/doku/doku.php?id=juniper%3Atshoot_bad)
- [`juniper:tshoot_good`](https://tim.army/doku/doku.php?id=juniper%3Atshoot_good)
- [`juniper:os_upgrade:log`](https://tim.army/doku/doku.php?id=juniper%3Aos_upgrade%3Alog)
- [`linux:centos7`](https://tim.army/doku/doku.php?id=linux%3Acentos7)
- [`linux:general`](https://tim.army/doku/doku.php?id=linux%3Ageneral)
- [`linux:ostinato`](https://tim.army/doku/doku.php?id=linux%3Aostinato)
- [`linux:rhel`](https://tim.army/doku/doku.php?id=linux%3Arhel)
- [`linux:ubuntu`](https://tim.army/doku/doku.php?id=linux%3Aubuntu)
- [`linux:vcenter8`](https://tim.army/doku/doku.php?id=linux%3Avcenter8)
- [`programming:python`](https://tim.army/doku/doku.php?id=programming%3Apython)
- [`raspberrypi:kodi_media_server`](https://tim.army/doku/doku.php?id=raspberrypi%3Akodi_media_server)
- [`raspberrypi:switch`](https://tim.army/doku/doku.php?id=raspberrypi%3Aswitch)
- [`raspberrypi:switch:source_backup`](https://tim.army/doku/doku.php?id=raspberrypi%3Aswitch%3Asource_backup)
- [`service_provider:connections_diagrams_and_applications`](https://tim.army/doku/doku.php?id=service_provider%3Aconnections_diagrams_and_applications)
- [`service_provider:stp_and_flex_links`](https://tim.army/doku/doku.php?id=service_provider%3Astp_and_flex_links)
- [`software:makemkv`](https://tim.army/doku/doku.php?id=software%3Amakemkv)
- [`software:netbox`](https://tim.army/doku/doku.php?id=software%3Anetbox)
- [`software:securecrt`](https://tim.army/doku/doku.php?id=software%3Asecurecrt)
- [`software:microsoft:win11`](https://tim.army/doku/doku.php?id=software%3Amicrosoft%3Awin11)
- [`training_resources:cisco`](https://tim.army/doku/doku.php?id=training_resources%3Acisco)
- [`training_resources:comptia`](https://tim.army/doku/doku.php?id=training_resources%3Acomptia)
- [`vmware:vcenter8`](https://tim.army/doku/doku.php?id=vmware%3Avcenter8)
- [`wiki:dokuwiki`](https://tim.army/doku/doku.php?id=wiki%3Adokuwiki)
- [`wiki:syntax`](https://tim.army/doku/doku.php?id=wiki%3Asyntax)
- [`wiki:welcome`](https://tim.army/doku/doku.php?id=wiki%3Awelcome)
- [`windows:autounattend`](https://tim.army/doku/doku.php?id=windows%3Aautounattend)
- [`windows:powershell`](https://tim.army/doku/doku.php?id=windows%3Apowershell)
- [`windows:right-click`](https://tim.army/doku/doku.php?id=windows%3Aright-click)
- [`xponology:hp_microserver`](https://tim.army/doku/doku.php?id=xponology%3Ahp_microserver)
- [`xponology:hp_microserver:bios_pics`](https://tim.army/doku/doku.php?id=xponology%3Ahp_microserver%3Abios_pics)

### Food, photos, and miscellaneous

- [`food:food_i_dont_like`](https://tim.army/doku/doku.php?id=food%3Afood_i_dont_like)
- [`food:recipes`](https://tim.army/doku/doku.php?id=food%3Arecipes)
- [`food:recipes:blt_popovers`](https://tim.army/doku/doku.php?id=food%3Arecipes%3Ablt_popovers)
- [`food:recipes:bread_pudding`](https://tim.army/doku/doku.php?id=food%3Arecipes%3Abread_pudding)
- [`food:recipes:choc_fluff_roll`](https://tim.army/doku/doku.php?id=food%3Arecipes%3Achoc_fluff_roll)
- [`food:recipes:granola`](https://tim.army/doku/doku.php?id=food%3Arecipes%3Agranola)
- [`food:recipes:lemon_meringue_pie`](https://tim.army/doku/doku.php?id=food%3Arecipes%3Alemon_meringue_pie)
- [`food:recipes:sos`](https://tim.army/doku/doku.php?id=food%3Arecipes%3Asos)
- [`recipes:food_i_dont_like`](https://tim.army/doku/doku.php?id=recipes%3Afood_i_dont_like)
- [`pics:personal`](https://tim.army/doku/doku.php?id=pics%3Apersonal)
- [`pics:sunsets`](https://tim.army/doku/doku.php?id=pics%3Asunsets)
- [`playground:playground`](https://tim.army/doku/doku.php?id=playground%3Aplayground)
WEBSITE_CONTENT_EOF

actual_sha256="$(shasum -a 256 "${TARGET_FILE}" | awk '{print $1}')"
[[ "${actual_sha256}" == "${EXPECTED_SHA256}" ]] \
  || error "Website file integrity validation failed."

log "Created website file: website/${WEBSITE_FILENAME}"
log "PASS: SHA-256 validation."

bash -n "${CANONICAL_SCRIPT}"
log "PASS: Bash syntax validation."

if [[ "${DO_COMMIT}" == false ]]; then
  log "Files created without a Git commit (--no-commit)."
  exit 0
fi

git -C "${REPO_DIR}" add -- \
  "website/${WEBSITE_FILENAME}" \
  "scripts/bash/${SCRIPT_NAME}"

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
    (
      cd "${REPO_DIR}"
      gh repo view --web
    ) || true
  else
    log "GitHub CLI is not installed; skipping --open."
  fi
fi

if [[ "${SOURCE_SCRIPT}" != "${CANONICAL_SCRIPT}" && -f "${SOURCE_SCRIPT}" ]]; then
  rm -f "${SOURCE_SCRIPT}"
  log "Removed downloaded script after canonical installation."
fi

log "Complete."
log "Website file: ${TARGET_FILE}"

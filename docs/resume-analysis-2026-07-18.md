# Resume Improvement Checklist

**Created:** July 18, 2026  
**Repository:** `Tim-Army/Resume`  
**Scope:** Master resume, ~~private-sector variant, federal/defense variant,~~ public website, PDF layout, ATS extraction, and application readiness. The one-page constraint is intentionally excluded.

> **Update, July 19, 2026.** Struck items no longer apply. The concise one-page resume and both targeted variants were deleted that day, leaving `resume/master/Tim-Fox-Resume.md` as the only resume source, and several chronology, homelab, and professional-development items were completed. See `docs/resume-build-manifest.md`.

## Baseline Review

- [x] Review the full master resume and source.
- [x] Review the private-sector variant.
- [x] Review the federal/defense variant.
- [x] Render and visually inspect the full PDF.
- [x] Confirm that the PDF uses a clean, single-column layout.
- [x] Confirm that the PDF text is selectable and generally machine-readable.
- [x] Confirm strong keyword coverage across networking, security, data center, virtualization, and leadership.
- [x] Exclude the one-page constraint from the recommendations.

## Priority 0: Resolve Before the Next Application

### Experience-Duration Claim

- [ ] Verify the total number of years of professional IT and network-engineering experience.
- [ ] Identify any professional employment omitted from the current 2006-2016 education and development period.
- [ ] If omitted professional experience exists, add it to the master resume with accurate dates and scope.
- [ ] If the chronology is complete, replace the current "more than 20 years of experience" claim with accurate wording.
- [ ] Choose and use one verified formulation consistently:
  - [ ] "Technology experience spanning more than 20 years."
  - [ ] "17+ years of professional IT and network-engineering experience."
  - [ ] Another factually supported duration statement.
- [ ] Apply the verified wording consistently across the master resume, ~~targeted variants,~~ PDFs, website metadata, and website summary.

### Primary Career Positioning

- [ ] Choose the primary target for each application:
  - [x] Principal Network Engineer
  - [ ] Network Architect
  - [ ] Infrastructure Engineering Supervisor
  - [ ] Engineering Manager
- [x] Align the default headline with the selected target.
- [x] Replace broad branding such as "Strategist, Innovator, and Coach" with job-searchable language.
- [x] Use this headline as the starting point:
  - [x] `Principal Network Engineer | Infrastructure Engineering Supervisor | Multi-Vendor Enterprise and Defense Networks`
- [x] Keep the Principal Network Engineer positioning as the default unless stronger management evidence is added.
- [ ] Align the summary, competencies, and first-page accomplishments with each selected application target.

## Priority 1: Build an Evidence-Based Accomplishment Record

### Complete the Metrics Inventory

- [ ] Populate `docs/accomplishment-metrics.md` with verified accomplishments.
- [ ] Record the evidence or source for every metric.
- [ ] Mark each metric as approved or not approved for resume use.
- [ ] Do not add estimated figures unless they are clearly labeled and defensible.

### Metrics to Collect

- [ ] Number of deployments completed.
- [ ] Number of sites, networks, devices, or environments supported.
- [ ] Number of users or customers affected.
- [ ] Availability or uptime achieved.
- [ ] Outage duration or restoration time.
- [ ] Mean time to resolution or comparable incident metric.
- [ ] Number and severity of escalations resolved.
- [ ] Engineers mentored or trained.
- [ ] Training sessions or hours delivered.
- [ ] Designs, implementation plans, procedures, or documents produced.
- [ ] Acceptance-test pass rate or customer acceptance results.
- [ ] Schedule improvement or avoided rework.
- [ ] Program or project value.
- [ ] Cost, labor, or time savings.
- [ ] Security, reliability, or operational-risk improvement with supporting evidence.

### Employer-Specific Metric Review

- [ ] Leidos, 2026-present: capture team, supervisory, training, escalation, and delivery outcomes.
- [ ] FEDITC: capture architecture scope, testing results, incidents restored, and mission impact that may be disclosed.
- [ ] Akima / Tundra: capture deployment count, acceptance results, documentation volume, and avoided rework.
- [ ] MSM Technology: capture IPv6 scope, ACL volume, environments supported, and security or readiness outcomes.
- [ ] Leidos, 2019-2022: capture escalation volume, restoration results, service scope, and training impact.
- [ ] BJC Healthcare: preserve the verified $9.7 million, 2-hospital, and 40-plus-clinic scope; add devices, migrations, availability, or schedule results if verified.
- [ ] Lockheed Martin / Leidos, 2016-2017: capture supported infrastructure scale, escalation volume, and training outcomes that may be disclosed.
- [ ] U.S. Army: preserve the verified 100% availability and approximately 800-user support scope; verify the timeframe and source.

### Rewrite Bullets Around Evidence

- [ ] Give every important bullet a clear action.
- [ ] Add scope where available.
- [ ] Add a verified result or mission/business effect where available.
- [x] Lead each recent role with its strongest accomplishment rather than a general responsibility.
- [ ] Replace unsupported claims such as "reduced risk," "strengthened security," and "improved readiness" with evidence.
- [x] Remove duplicated technology lists when the same keywords already appear in the competencies section.
- [x] Keep approximately 3-5 high-value bullets for recent roles.
- [x] Keep older roles concise unless directly relevant to the target vacancy.

## Priority 1: Strengthen the Leadership Case

- [ ] Quantify current supervisory responsibility: 2 direct reports within an approximately 12-person team.
- [ ] Add verified employee-development outcomes.
- [ ] Add performance-management responsibility if applicable.
- [ ] Add hiring, interviewing, or onboarding responsibility if applicable.
- [ ] Add work-planning and prioritization responsibility if applicable.
- [ ] Add staffing or capacity decisions if applicable.
- [ ] Add delivery accountability if applicable.
- [ ] Add roadmap, budget, or resource ownership if applicable.
- [ ] Add cross-functional organizational influence if applicable.
- [ ] Avoid implying broader management authority than the position actually carries.

## Priority 1: Explain Career Chronology

- [ ] Verify all employers, titles, and month/year dates.
- [ ] Identify which recent roles were contract assignments.
- [x] ~~Identify which roles ended because of program completion, contract transition, recompete, or customer decision.~~
- [x] ~~Add concise context where it reduces the appearance of voluntary job-hopping.~~
- [x] ~~Preserve the Lockheed Martin-to-Leidos continuity explanation.~~
- [x] ~~Decide whether the 2006-2016 education and career-development period should remain a separate experience entry.~~
- [ ] ~~If retained, explain the period concisely and factually.~~
- [x] ~~If removed from a commercial version, ensure the education dates still explain the chronology sufficiently.~~

## Priority 1: Review Public Disclosure and Privacy

### Defense and Customer Information

- [ ] Review references to secure networks.
- [ ] Review references to Air Force executive aircraft.
- [ ] Review references to pre-release HAIPE equipment.
- [ ] Review references to the DISA Joint Regional Security Stack.
- [ ] Review references to encrypted communications deployments.
- [ ] Confirm each reference complies with employer, customer, nondisclosure, proprietary-information, and operational-security requirements.
- [ ] Replace uncertain public details with approved generalized language.
- [ ] Keep controlled or sensitive specifics out of the public website and public repository.

### Contact Information

- [ ] Create a private application version that includes a phone number.
- [ ] Add city/state or another useful regional location to the application version.
- [ ] Include email, LinkedIn, and portfolio/GitHub links in application versions.
- [ ] Decide which contact details are appropriate for the public website.
- [ ] Remember that the email remains visible in public Markdown even if the webpage masks it.
- [ ] Remove or replace the public Markdown email if reducing scraping exposure is a goal.

## Priority 2: Improve Content Allocation

### Education and Professional Development

- [ ] Remove or condense MBA coursework unless a vacancy makes it relevant.
- [ ] Remove or condense bachelor's-degree coursework.
- [ ] Remove or condense associate-degree foundational studies.
- [ ] Remove the 2006 leadership workshop unless directly relevant.
- [x] ~~Remove or condense the 2017 CCIE training entry unless directly relevant.~~
- [ ] Keep recent professional development that supports the target job.
- [ ] Use the recovered space for recent accomplishments and leadership outcomes.

### Certifications and Qualifications

- [ ] Verify that every listed certification is current or clearly labeled if expired.
- [ ] Verify the exact names of all certifications.
- [ ] Verify the wording of DoD 8570 IAT II and IAT III qualification claims.
- [ ] Replace vague "DoD 8140-aligned qualifications" wording with a specific, verified work-role or qualification statement when possible.
- [ ] Prioritize advanced and role-relevant credentials.
- [ ] Consider omitting entry-level or redundant credentials when space or focus matters.
- [ ] Keep certifications requested by the target vacancy even when they are otherwise redundant.

### Homelab and Portfolio

- [ ] ~~Rename "Technical Lab" to "Selected Projects" when appropriate.~~ Renamed to Homelab.
- [ ] Reduce the section to 1-2 high-value projects.
- [ ] Describe the architecture or infrastructure created.
- [ ] Identify the technologies integrated.
- [ ] Describe useful automation developed.
- [ ] Explain who benefits from the project.
- [x] Add a direct link to the Enterprise Infrastructure Encyclopedia repository.
- [x] Identify where low-value implementation detail is concentrated:
  - ~~Concise resume, Homelab: the automation bullet enumerates issues, labels, milestones, chapter migration, status configuration, synchronization, and validation.~~
  - ~~Concise resume, Homelab: the Git/GitHub bullet enumerates branching, commits, pull requests, review, changelogs, contribution standards, and project tracking.~~
  - ~~Concise resume, Homelab: the publishing bullet enumerates GitHub Pages, PDF, DOCX, print-ready editions, validation, and planned release automation.~~
  - ~~Expanded resume and website, Homelab: the repository-automation and publishing bullets retain lower-level workflow mechanics that may distract from network-engineering outcomes.~~
- [x] ~~Remove or compress those details unless targeting a role that values developer tooling, documentation systems, or publishing automation.~~
- [x] ~~Replace "planned" automation with completed, demonstrable work where possible.~~

## Priority 2: Improve PDF and ATS Quality

### Readability and Page Flow

- [x] Increase full-PDF body and bullet text to 10 points with readable 12.2-point leading.
- [x] Review forced page breaks; remove both explicit markers and the redundant continued-experience heading.
- [x] Reduce unnecessary blank space across pages 2-3 through natural pagination and tighter vertical rhythm.
- [x] Balance section transitions so page 2 begins with the complete Akima role and page 3 begins with the complete U.S. Army section.
- [x] Keep each employer, role heading, and its bullets together.
- [x] Prevent isolated headings, orphaned bullets, clipping, and overlaps through grouped flowables and rendered-page review.
- [x] Retain page numbers and the restrained rule-and-text footer.
- [x] Keep the expanded resume at three pages because the larger text and balanced content justify the length.

### ATS and Accessibility

- [ ] Replace PDF bullet characters that extract as control characters with standard bullets or simple hyphens.
- [ ] Re-extract PDF text and verify the reading order.
- [ ] Adjust PDF generation order so the footer does not precede the main header in extracted text, if practical.
- [ ] Add PDF tagging or provide an accessible alternative document.
- [ ] Verify conventional section headings remain intact.
- [ ] Verify employer, title, date, and bullet text extract correctly.
- [ ] Verify no important content depends on logos, color, or images.
- [ ] Verify all email, LinkedIn, GitHub, and portfolio links are active.
- [ ] Verify the PDF opens correctly in multiple viewers.

## Version-Specific Checklists

### Master Resume

- [ ] Keep the master as the complete, verified source of truth.
- [ ] Preserve all approved accomplishments and metrics.
- [ ] Remove unsupported claims.
- [ ] Keep comprehensive technical keywords without excessive duplication.
- [ ] Maintain purposeful page flow across three or four pages.
- [ ] Regenerate and inspect the PDF after every meaningful content change.

### ~~Private-Sector Variant~~ (variant deleted 2026-07-19)

- [ ] ~~Tailor the headline and summary to the specific job.~~
- [ ] ~~Match the job description's terminology where accurate.~~
- [ ] ~~Emphasize scale, reliability, delivery, leadership, and business value.~~
- [ ] ~~Generalize defense details that are unnecessary for the commercial role.~~
- [ ] ~~Keep the strongest recent accomplishments on the first page.~~
- [ ] ~~Use two or three pages when needed; do not optimize for a one-page requirement.~~
- [ ] ~~Include application contact information.~~

### ~~Federal/Defense Variant~~ (variant deleted 2026-07-19)

- [ ] ~~Keep the resume at two pages when required by USAJOBS or the vacancy announcement.~~
- [ ] ~~Add hours worked per week for relevant positions when required.~~
- [ ] ~~Use month/year dates.~~
- [ ] ~~Address the announcement's specialized-experience requirements directly.~~
- [ ] ~~Include series and grade for any federal positions, if applicable.~~
- [ ] ~~Include only approved, publicly releasable program information.~~
- [ ] ~~Follow the specific announcement when it differs from general guidance.~~
- [ ] ~~Review [OPM applicant guidance](https://www.opm.gov/policy-data-oversight/hiring-information/merit-hiring-plan-resources/applicant-guidance-on-the-two-page-resume-limit/).~~
- [ ] ~~Review [USAJOBS resume requirements](https://help.usajobs.gov/faq/application/documents/resume/what-to-include).~~

### Public Website

- [x] Align the website headline with the primary target role.
- [x] Replace "Engineering Leader, Strategist, Innovator, and Coach" with more specific, searchable positioning.
- [ ] Keep the website summary synchronized with the verified master.
- [ ] Keep public content free of unapproved defense, customer, or pre-release-equipment details.
- [ ] Verify download links point to the latest PDFs.
- [ ] Verify the email, LinkedIn, GitHub, and portfolio links.
- [ ] Test desktop, mobile, print, light mode, and dark mode.
- [ ] Confirm the canonical URL represents the intended professional profile.

## Summary Rewrite Checklist

Before rewriting the summary:

- [ ] Verify the years-of-experience figure.
- [ ] Select the target role.
- [ ] Select 1-2 quantified accomplishments.
- [ ] Select the most relevant advanced certifications.
- [ ] Decide whether current supervision should appear in the first sentence.
- [ ] Keep the summary to approximately 3-4 concise lines.
- [ ] Avoid unsupported adjectives such as "innovative," "strategic," or "results-driven."
- [ ] Avoid repeating the complete skills inventory.

Confirm that the final summary communicates:

- [ ] Principal-level network engineering.
- [ ] Current supervisory responsibility.
- [ ] Mission-critical multi-vendor infrastructure.
- [ ] Defense, healthcare, enterprise, and data-center experience.
- [ ] Advanced networking and security credentials.
- [ ] MBA or business perspective.
- [ ] At least one verified example of scale or impact.

Candidate positioning statement to revise after verification:

> Principal Network Engineer and infrastructure supervisor who leads engineers and delivers mission-critical, multi-vendor networks across defense, healthcare, enterprise, and data-center environments. Combines hands-on Cisco, Juniper, Palo Alto Networks, F5, Gigamon, Dell, VMware, and Red Hat expertise with an MBA, advanced networking and security credentials, and engineering leadership for a $9.7 million modernization serving 2 hospitals and more than 40 clinics.

## Final Quality Assurance

- [ ] Proofread spelling, grammar, capitalization, and punctuation.
- [ ] Verify every date and job title.
- [ ] Verify every number and outcome against a reliable source.
- [ ] Verify all certification names and statuses.
- [ ] Verify all links.
- [ ] Compare each generated PDF with its source file.
- [ ] Extract the final PDF text and inspect the reading order.
- [ ] Inspect every rendered page visually.
- [ ] Confirm the resume remains legible when printed.
- [ ] Confirm the public and private versions contain the intended contact information.
- [ ] Confirm the resume is tailored to the target vacancy.
- [ ] Have a trusted technical peer review technical accuracy.
- [ ] Have a hiring manager or recruiter review the opening and first-page impact.

## Definition of Done

- [ ] The experience-duration claim matches the documented chronology.
- [ ] The target role is unmistakable within the first five seconds.
- [ ] Recent roles lead with verified accomplishments.
- [ ] Short tenures have appropriate context.
- [ ] The leadership scope is accurate and supported.
- [ ] Public defense information has been reviewed for disclosure.
- [ ] The application version contains complete contact information.
- [ ] The PDF is readable, balanced, accessible, and machine-extractable.
- [ ] ~~The private-sector and federal versions meet their respective application requirements.~~
- [ ] All generated documents are synchronized with the verified master.

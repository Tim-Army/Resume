# Tim Fox Resume

A lightweight static website for presenting Tim Fox's full professional experience, technical expertise, education, and contact information. The site provides both a concise one-page PDF and an expanded four-page PDF resume.

The site defaults to a dark theme with `#090` text. An upper-right theme link switches between dark and light modes and remembers the visitor's choice. The header presents the professional title as one bullet. Contact, profile, and resume resource links open in a new tab, while the theme control, accessibility skip link, and footer's back-to-top link remain within the current page. Email links are masked in the static HTML and restored in the browser for visitors with JavaScript enabled.

## Site files

- `index.html` — Resume website content and metadata.
- `styles.css` — Responsive screen and print styles.
- `theme.js` — Dark/light theme switching and saved visitor preference.
- `email.js` — Restores masked email links in the visitor's browser.
- `.nojekyll` — Tells GitHub Pages to serve the static files without Jekyll processing.
- `assets/flag-of-the-united-states.svg` — Public-domain American flag used in the site header.
- `assets/business-logos/` — Employer logos displayed on transparent containers only in business entries in the webpage experience section.
- `assets/certification-badges/` — Eight earned certification badges displayed in a circular, webpage-only row.
- `assets/college-favicons/` — Official college favicons displayed on transparent containers to the right of each school name in the webpage education section.
- `assets/service-logos/` — U.S. Army mark displayed only with Tim's Army experience entry.
- `assets/favicon/` — Browser and device icons.
- `pdf/Tim-Fox-Resume-one-page.pdf` — Concise one-page resume.
- `pdf/Tim-Fox-Resume.pdf` — Full four-page resume.
- `resume/master/Tim-Fox-Resume.md` — Full resume source and webpage content reference.
- `resume/master/Tim-Fox-Resume-one-page.md` — Concise resume source.
- `scripts/python/create-full-resume-pdf.py` — Generates the four-page PDF from the full source.
- `scripts/python/requirements.txt` — Pinned dependencies for generating the full PDF.

## Preview locally

No build step or dependencies are required. Open `index.html` in a browser, or run a local web server from the repository root:

```sh
python3 -m http.server 8000
```

Then visit `http://localhost:8000`.

## Deployment

The site is published at [derg20.github.io/Tim-Fox-Resume](https://derg20.github.io/Tim-Fox-Resume/) with HTTPS enforced.

GitHub Pages publishes the `main` branch from the repository root. The repository includes `.nojekyll`, so Pages serves the static files without applying Jekyll transformations. Future pushes to `main` automatically republish the site. See GitHub's [publishing-source guide](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site) for configuration and troubleshooting details.

The canonical professional profile is [tim.army](https://tim.army/doku/doku.php?id=aboutme).

To use another static host, publish `index.html`, `styles.css`, `assets/`, and `pdf/` together while preserving their directory structure.

The header uses the public-domain [Flag of the United States](https://commons.wikimedia.org/wiki/File:Flag_of_the_United_States.svg) from Wikimedia Commons.

The webpage education section uses the official favicon or touch-icon artwork published by [Webster University](https://www.webster.edu/), [Michigan Technological University](https://www.mtu.edu/), and [Jefferson Community College](https://sunyjefferson.edu/). These institutional marks remain the property of their respective owners and are used only to identify Tim's alma maters.

The webpage experience section uses employer marks from the official [FEDITC](https://feditc.com/), [Akima](https://www.akima.com/), [MSM Technology](https://www.msmtechinc.com/), and [BJC](https://www.bjc.org/) sites, plus the [Leidos](https://commons.wikimedia.org/wiki/File:Leidos_logo_2013.svg) and [Lockheed Martin](<https://commons.wikimedia.org/wiki/File:Lockheed_Martin_logo_(2).svg>) text logos published on Wikimedia Commons. The Army experience entry uses the stacked [U.S. Army logo provided by MWR Brand Central](https://www.mwrbrandcentral.com/assets/26).

The credentials section presents eight earned badges in circular frames. Badge sources are the corresponding Credly listings for [CCNP Enterprise](https://www.credly.com/org/cisco/badge/cisco-certified-network-professional-enterprise-ccnp-enterprise), [JNCIA-Junos](https://www.credly.com/embedded_badge/02b57c68-b80b-4dcc-be70-a4f12721750d), [GIAC GCED](https://www.credly.com/org/global-information-assurance-certification-giac/badge/giac-certified-enterprise-defender-gced), [CompTIA Security+ CE](https://www.credly.com/org/comptia/badge/comptia-security-ce-certification), [Fortinet Certified Associate Cybersecurity](https://www.credly.com/org/fortinet/badge/fortinet-certified-associate-cybersecurity.1), [AWS Certified Cloud Practitioner](https://www.credly.com/org/amazon-web-services/badge/aws-certified-cloud-practitioner), [Dell VxRail Deploy Version 2](https://www.credly.com/org/delltechnologies/badge/dell-vxrail-deploy-version-2/), and VMware VCA-DCV. CCNA remains listed in the certification text, but its badge is intentionally omitted. DoD workforce alignment remains text-only because it is an alignment rather than a separate certification.

All employer, service, certification, and college marks are excluded from print output and the downloadable PDFs. Trademarks remain the property of their respective owners and are used only for identification; no endorsement or affiliation is implied.

## Updating the resume

Treat `resume/master/Tim-Fox-Resume.md` as the source of truth for the webpage and full PDF. Regenerate the expanded PDF after editing it:

```sh
python3 -m pip install -r scripts/python/requirements.txt
python3 scripts/python/create-full-resume-pdf.py
```

Keep `resume/master/Tim-Fox-Resume-one-page.md` and its concise PDF synchronized separately.

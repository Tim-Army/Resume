# Tim Fox Resume

A lightweight static website for presenting Tim Fox's full professional experience, technical expertise, education, and contact information. The site provides both a concise one-page PDF and an expanded four-page PDF resume.

## Site files

- `index.html` — Resume website content and metadata.
- `styles.css` — Responsive screen and print styles.
- `.nojekyll` — Tells GitHub Pages to serve the static files without Jekyll processing.
- `assets/flag-of-the-united-states.svg` — Public-domain American flag used in the site header.
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

## Updating the resume

Treat `resume/master/Tim-Fox-Resume.md` as the source of truth for the webpage and full PDF. Regenerate the expanded PDF after editing it:

```sh
python3 -m pip install -r scripts/python/requirements.txt
python3 scripts/python/create-full-resume-pdf.py
```

Keep `resume/master/Tim-Fox-Resume-one-page.md` and its concise PDF synchronized separately.

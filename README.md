# Tim Fox Resume

A lightweight static website for presenting Tim Fox's professional experience, technical expertise, education, and contact information. The site also provides a downloadable one-page PDF resume.

## Site files

- `index.html` — Resume website content and metadata.
- `styles.css` — Responsive screen and print styles.
- `.nojekyll` — Tells GitHub Pages to serve the static files without Jekyll processing.
- `assets/favicon/` — Browser and device icons.
- `pdf/Tim-Fox-Resume-one-page.pdf` — Downloadable resume.
- `resume/master/Tim-Fox-Resume-one-page.md` — Source resume content.

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

## Updating the resume

Treat `resume/master/Tim-Fox-Resume-one-page.md` as the source of truth. Keep the website content and downloadable PDF synchronized with it.

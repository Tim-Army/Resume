# Resume Site Recommended Changes

Keep this repository intentionally small: a static HTML/CSS site with a downloadable PDF is sufficient.

## Content

- [ ] Add the current resume content to the site.
- [ ] Put name, target role, contact links, experience, skills, and education in a clear scanning order.
- [ ] Review all wording for concise, achievement-focused bullet points with measurable outcomes where possible.
- [ ] Remove unnecessary personal information such as a full street address.
- [ ] Check spelling, grammar, dates, job titles, and contact links.

## Site

- [ ] Create a single semantic `index.html` page.
- [ ] Add a responsive `styles.css` suitable for desktop and mobile screens.
- [ ] Add a prominent link to download the resume as a PDF.
- [ ] Give the PDF a professional filename, such as `Timothy-Lastname-Resume.pdf`.
- [ ] Add print styles that hide website controls and prevent awkward page breaks.
- [ ] Keep the site lightweight and avoid a JavaScript framework unless the scope grows.

## Accessibility and quality

- [ ] Use a logical heading structure and semantic HTML elements.
- [ ] Ensure readable font sizes and sufficient color contrast.
- [ ] Make every link keyboard-accessible with a visible focus state.
- [ ] Use descriptive link text and accessible labels where needed.
- [ ] Test the page on mobile and desktop screen sizes.
- [ ] Test printing and PDF download behavior.

## Metadata and publishing

- [ ] Add a descriptive page title and meta description.
- [ ] Add a favicon, canonical URL, and social-sharing metadata.
- [ ] Add a short `README.md` with the site purpose and deployment instructions.
- [ ] Add `.nojekyll` if publishing with GitHub Pages without Jekyll.
- [ ] Deploy through GitHub Pages or another static host.
- [ ] Optionally connect a professional custom domain.
- [ ] Verify that the deployed site uses HTTPS and has no broken links.

## Suggested structure

```text
index.html
styles.css
assets/
  Timothy-Lastname-Resume.pdf
  favicon.svg
README.md
.nojekyll
```

Editable website files should remain outside `sources/`, which is read-only synced reference material.

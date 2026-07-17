# Resume Site Recommended Changes

Keep this repository intentionally small: a static HTML/CSS site with a downloadable PDF is sufficient.

## Content

- [x] Add the current full resume content to the site from `resume/master/Tim-Fox-Resume.md`.
- [x] Put name, target role, contact links, experience, skills, and education in a clear scanning order.
- [x] Review all wording for concise, achievement-focused bullet points with measurable outcomes where possible.
- [x] Remove unnecessary personal information such as a full street address.
- [x] Check spelling, grammar, dates, job titles, and contact links.

## Site

- [x] Create a single semantic `index.html` page.
- [x] Add a responsive `styles.css` suitable for desktop and mobile screens.
- [x] Add prominent links to download concise and full PDF resumes.
- [x] Style both PDF download links as matching primary buttons.
- [x] Give both PDFs professional filenames.
- [x] Expand the webpage and full PDF to the reviewed four-page resume content.
- [x] Add an American flag header while preserving readable text contrast.
- [x] Reduce the professional summary body font by 10%.
- [x] Present the combined professional headline as exactly three title bullets.
- [x] Open contact, profile, and resume resource links in new tabs.
- [x] Add a bottom-right back-to-top link.
- [x] Add print styles that hide website controls and prevent awkward page breaks.
- [x] Keep the site lightweight and avoid a JavaScript framework unless the scope grows.

## Accessibility and quality

- [x] Use a logical heading structure and semantic HTML elements.
- [x] Ensure readable font sizes and sufficient color contrast.
- [x] Make every link keyboard-accessible with a visible focus state.
- [x] Use descriptive link text and accessible labels where needed.
- [ ] Test the page on mobile and desktop screen sizes.
- [ ] Test printing and PDF download behavior.

## Metadata and publishing

- [x] Add a descriptive page title and meta description.
- [x] Add a favicon, canonical URL, and social-sharing metadata.
- [x] Add a short `README.md` with the site purpose and deployment instructions.
- [x] Add `.nojekyll` if publishing with GitHub Pages without Jekyll.
- [x] Deploy through GitHub Pages or another static host.
- [x] Optionally connect a professional custom domain.
- [x] Verify that the deployed site uses HTTPS and has no broken links.

## Suggested structure

```text
index.html
styles.css
assets/
  flag-of-the-united-states.svg
pdf/
  Tim-Fox-Resume-one-page.pdf
  Tim-Fox-Resume.pdf
README.md
.nojekyll
```

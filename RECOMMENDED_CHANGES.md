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
- [x] Label the downloads as One-Page Resume PDF and Multi-Page Resume PDF.
- [x] Give both PDFs professional filenames.
- [x] Expand the webpage and full PDF to the reviewed full-resume content.
- [x] Add an American flag header while preserving readable text contrast.
- [x] Reduce the professional summary body font by 10%.
- [x] Present the professional headline as one title bullet.
- [x] Open contact, profile, and resume resource links in new tabs.
- [x] Add a bottom-right back-to-top link.
- [x] Make dark mode the default with `#090` text.
- [x] Add an upper-right light-mode link with a saved visitor preference.
- [x] Mask email links in the static webpage source.
- [x] Replace college logos with official favicons in the webpage education section.
- [x] Replace certification vendor marks with earned badges in one row beneath the Certifications title.
- [x] Add employer logos to each business entry in the webpage experience section.
- [x] Add the specified U.S. Army logo to the Army experience entry.
- [x] Present certification badges in circular frames, include Security+ CE, AWS CCP, and Dell VxRail Deploy v2, and omit the CCNA badge.
- [x] Place college favicons to the right of school names on transparent backgrounds.
- [x] Use transparent backgrounds for business logos.
- [x] Place business logos to the right of each business name, matching the education heading layout.
- [x] Treat the U.S. Army as a business/employer and place its borderless logo in the same right-side layout.
- [x] Right-align every employer logo as the final heading element and remove all framing from the Army mark.
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
  Tim-Fox-Concise-Resume.pdf
  Tim-Fox-Expanded-Resume.pdf
README.md
.nojekyll
```

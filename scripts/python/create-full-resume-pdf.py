#!/usr/bin/env python3
"""Generate the full resume PDF from the master Markdown source."""

from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

from pypdf import PdfReader
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfgen.canvas import Canvas
from reportlab.platypus import KeepTogether, Paragraph, SimpleDocTemplate


NAVY = colors.HexColor("#17365D")
DARK = colors.HexColor("#202832")
MUTED = colors.HexColor("#566474")
MARGIN_LEFT = 0.58 * inch
MARGIN_RIGHT = 0.58 * inch
RULE = colors.HexColor("#B8C6D9")


def normalize_text(value: str) -> str:
    replacements = {
        "\u2013": "-",
        "\u2014": "-",
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u00a0": " ",
        "\u2026": "...",
    }
    for old, new in replacements.items():
        value = value.replace(old, new)
    return value.strip()


def inline_markup(value: str) -> str:
    links: list[tuple[str, str, str]] = []

    def stash_link(match: re.Match[str]) -> str:
        token = f"RESUMELINKTOKEN{len(links)}"
        links.append((token, match.group(1), match.group(2)))
        return token

    value = re.sub(r"\[([^\]]+)\]\((https://[^)]+)\)", stash_link, normalize_text(value))
    value = html.escape(value, quote=False)
    value = re.sub(r"`([^`]+)`", r'<font name="Courier">\1</font>', value)
    value = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", value)
    value = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<i>\1</i>", value)

    email = "timfox2025@tim.army"
    value = value.replace(
        email,
        f'<link href="mailto:{email}" color="#17365D">{email}</link>',
    )
    for url in (
        "https://github.com/derg20",
        "https://www.linkedin.com/in/timarmy",
    ):
        value = value.replace(
            url,
            f'<link href="{url}" color="#17365D">{url}</link>',
        )
    for token, label, url in links:
        value = value.replace(
            token,
            f'<link href="{html.escape(url, quote=True)}" color="#17365D">{html.escape(label)}</link>',
        )
    return value


class NumberedCanvas(Canvas):
    """Stamps "Page N of M" once the real page total is known.

    The total is only available after the whole story is laid out, so pages
    are buffered and the footer is drawn during save().
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_pages: list[dict] = []

    def showPage(self) -> None:
        self._saved_pages.append(dict(self.__dict__))
        self._startPage()

    def save(self) -> None:
        total = len(self._saved_pages)
        for state in self._saved_pages:
            self.__dict__.update(state)
            self._draw_footer(total)
            super().showPage()
        super().save()

    def _draw_footer(self, total: int) -> None:
        self.saveState()
        self.setStrokeColor(RULE)
        self.setLineWidth(0.45)
        self.line(MARGIN_LEFT, 0.47 * inch, letter[0] - MARGIN_RIGHT, 0.47 * inch)
        self.setFillColor(MUTED)
        self.setFont("Helvetica", 8)
        self.drawString(MARGIN_LEFT, 0.29 * inch, "Tim Fox")
        self.drawRightString(
            letter[0] - MARGIN_RIGHT, 0.29 * inch, f"Page {self._pageNumber} of {total}"
        )
        self.restoreState()


def build_styles() -> dict[str, ParagraphStyle]:
    samples = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "ResumeTitle",
            parent=samples["Title"],
            fontName="Helvetica-Bold",
            fontSize=21,
            leading=24,
            textColor=NAVY,
            alignment=TA_CENTER,
            spaceAfter=1.8,
        ),
        "subtitle": ParagraphStyle(
            "ResumeSubtitle",
            parent=samples["Normal"],
            fontName="Helvetica-Bold",
            fontSize=10.5,
            leading=13,
            textColor=DARK,
            alignment=TA_CENTER,
            spaceAfter=2,
        ),
        "contact": ParagraphStyle(
            "ResumeContact",
            parent=samples["Normal"],
            fontName="Helvetica",
            fontSize=8.1,
            leading=10,
            textColor=MUTED,
            alignment=TA_CENTER,
            spaceAfter=4.5,
        ),
        "section": ParagraphStyle(
            "ResumeSection",
            parent=samples["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=11.5,
            leading=14,
            textColor=NAVY,
            spaceBefore=3.2,
            spaceAfter=1.4,
            keepWithNext=True,
        ),
        "employer": ParagraphStyle(
            "ResumeEmployer",
            parent=samples["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=10.2,
            leading=12.5,
            textColor=DARK,
            spaceBefore=2.6,
            spaceAfter=0.8,
            keepWithNext=True,
        ),
        "role": ParagraphStyle(
            "ResumeRole",
            parent=samples["Normal"],
            fontName="Helvetica-Oblique",
            fontSize=9.3,
            leading=11.4,
            textColor=MUTED,
            spaceAfter=0.9,
            keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "ResumeBody",
            parent=samples["BodyText"],
            fontName="Helvetica",
            fontSize=10,
            leading=11.4,
            textColor=DARK,
            alignment=TA_LEFT,
            spaceAfter=1.8,
            allowWidows=0,
            allowOrphans=0,
        ),
        "bullet": ParagraphStyle(
            "ResumeBullet",
            parent=samples["BodyText"],
            fontName="Helvetica",
            fontSize=10,
            leading=11.4,
            textColor=DARK,
            leftIndent=13,
            firstLineIndent=-7,
            bulletIndent=2,
            spaceAfter=0.63,
            allowWidows=0,
            allowOrphans=0,
        ),
    }


def build_pdf(source: Path, destination: Path) -> None:
    source_text = source.read_text(encoding="utf-8")

    styles = build_styles()
    doc = SimpleDocTemplate(
        str(destination),
        pagesize=letter,
        leftMargin=MARGIN_LEFT,
        rightMargin=MARGIN_RIGHT,
        topMargin=0.40 * inch,
        bottomMargin=0.50 * inch,
        title="Tim Fox Full Resume",
        author="Tim Fox",
        subject="Principal Network Engineer | Infrastructure Engineering Supervisor | Multi-Vendor Enterprise and Defense Networks",
        creator="Tim-Fox-Resume PDF generator",
        invariant=1,
    )

    story = []
    group_buffer = []
    paragraph_buffer: list[str] = []
    title_seen = False
    subtitle_seen = False
    contact_seen = False

    def append_flowable(flowable) -> None:
        target = group_buffer if group_buffer else story
        target.append(flowable)

    def flush_group() -> None:
        nonlocal group_buffer
        if group_buffer:
            story.append(KeepTogether(group_buffer))
            group_buffer = []

    def flush_paragraph() -> None:
        nonlocal paragraph_buffer
        if paragraph_buffer:
            paragraph = " ".join(normalize_text(part) for part in paragraph_buffer)
            if paragraph:
                append_flowable(Paragraph(inline_markup(paragraph), styles["body"]))
            paragraph_buffer = []

    for raw_line in source_text.splitlines():
        line = raw_line.strip()
        if not line:
            flush_paragraph()
            continue
        if line.startswith("# "):
            flush_paragraph()
            flush_group()
            story.append(Paragraph(inline_markup(line[2:]), styles["title"]))
            title_seen = True
            continue
        if line.startswith("## "):
            flush_paragraph()
            flush_group()
            story.append(Paragraph(inline_markup(line[3:]), styles["section"]))
            continue
        if line.startswith("### "):
            flush_paragraph()
            flush_group()
            group_buffer.append(Paragraph(inline_markup(line[4:]), styles["employer"]))
            continue
        if line.startswith("- "):
            flush_paragraph()
            append_flowable(Paragraph(inline_markup(line[2:]), styles["bullet"], bulletText="•"))
            continue
        if line.startswith("**") and line.endswith("**") and line.count("**") == 2:
            flush_paragraph()
            plain = line[2:-2]
            if title_seen and not subtitle_seen:
                append_flowable(Paragraph(inline_markup(plain), styles["subtitle"]))
                subtitle_seen = True
            else:
                append_flowable(Paragraph(inline_markup(plain), styles["role"]))
            continue
        if title_seen and subtitle_seen and not contact_seen and "timfox2025@tim.army" in line:
            flush_paragraph()
            append_flowable(Paragraph(inline_markup(line), styles["contact"]))
            contact_seen = True
            continue
        paragraph_buffer.append(line)

    flush_paragraph()
    flush_group()
    destination.parent.mkdir(parents=True, exist_ok=True)
    doc.build(story, canvasmaker=NumberedCanvas)

    reader = PdfReader(str(destination))
    extracted = "\n".join((page.extract_text() or "") for page in reader.pages)
    required = (
        "TIM FOX",
        "PROFESSIONAL SUMMARY",
        "PROFESSIONAL EXPERIENCE",
        "UNITED STATES ARMY",
        "EDUCATION",
        "HOMELAB",
    )
    missing = [item for item in required if item not in extracted.upper()]
    if missing:
        raise RuntimeError("Generated PDF is missing expected content: " + ", ".join(missing))
    print(f"Created {destination} ({len(reader.pages)} pages, {destination.stat().st_size} bytes).")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "source",
        nargs="?",
        type=Path,
        default=Path("resume/master/Tim-Fox-Resume.md"),
    )
    parser.add_argument(
        "destination",
        nargs="?",
        type=Path,
        default=Path("pdf/Tim-Fox-Expanded-Resume.pdf"),
    )
    args = parser.parse_args()
    build_pdf(args.source, args.destination)


if __name__ == "__main__":
    main()

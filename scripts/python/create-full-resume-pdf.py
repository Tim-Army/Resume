#!/usr/bin/env python3
"""Generate the four-page full resume PDF from the master Markdown source."""

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
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer


NAVY = colors.HexColor("#17365D")
DARK = colors.HexColor("#202832")
MUTED = colors.HexColor("#566474")
RULE = colors.HexColor("#B8C6D9")
EXPECTED_PAGES = 4
PAGE_BREAK_MARKER = "<!-- PAGE BREAK -->"


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
    value = html.escape(normalize_text(value), quote=False)
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
    return value


def draw_footer(canvas: Canvas, doc: SimpleDocTemplate) -> None:
    canvas.saveState()
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.45)
    canvas.line(doc.leftMargin, 0.47 * inch, letter[0] - doc.rightMargin, 0.47 * inch)
    canvas.setFillColor(MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(doc.leftMargin, 0.29 * inch, "Tim Fox - Principal Network Engineer")
    canvas.drawRightString(letter[0] - doc.rightMargin, 0.29 * inch, f"Page {doc.page} of {EXPECTED_PAGES}")
    canvas.restoreState()


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
            spaceAfter=3,
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
            spaceAfter=7,
        ),
        "section": ParagraphStyle(
            "ResumeSection",
            parent=samples["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=11.5,
            leading=14,
            textColor=NAVY,
            spaceBefore=7,
            spaceAfter=3,
            keepWithNext=True,
        ),
        "employer": ParagraphStyle(
            "ResumeEmployer",
            parent=samples["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=10.2,
            leading=12.5,
            textColor=DARK,
            spaceBefore=5.5,
            spaceAfter=1,
            keepWithNext=True,
        ),
        "role": ParagraphStyle(
            "ResumeRole",
            parent=samples["Normal"],
            fontName="Helvetica-Oblique",
            fontSize=9.3,
            leading=11.4,
            textColor=MUTED,
            spaceAfter=2.5,
            keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "ResumeBody",
            parent=samples["BodyText"],
            fontName="Helvetica",
            fontSize=9.4,
            leading=12,
            textColor=DARK,
            alignment=TA_LEFT,
            spaceAfter=3.5,
        ),
        "bullet": ParagraphStyle(
            "ResumeBullet",
            parent=samples["BodyText"],
            fontName="Helvetica",
            fontSize=9.3,
            leading=11.9,
            textColor=DARK,
            leftIndent=13,
            firstLineIndent=-7,
            bulletIndent=2,
            spaceAfter=2.2,
        ),
    }


def build_pdf(source: Path, destination: Path) -> None:
    source_text = source.read_text(encoding="utf-8")
    if source_text.count(PAGE_BREAK_MARKER) != EXPECTED_PAGES - 1:
        raise RuntimeError("The master resume must contain exactly three page-break markers.")

    styles = build_styles()
    doc = SimpleDocTemplate(
        str(destination),
        pagesize=letter,
        leftMargin=0.58 * inch,
        rightMargin=0.58 * inch,
        topMargin=0.48 * inch,
        bottomMargin=0.61 * inch,
        title="Tim Fox Full Resume",
        author="Tim Fox",
        subject="Principal Network Engineer | Infrastructure Engineering Supervisor | Multi-Vendor Enterprise and Defense Networks",
        creator="Tim-Fox-Resume four-page PDF generator",
        invariant=1,
    )

    story = []
    paragraph_buffer: list[str] = []
    title_seen = False
    subtitle_seen = False
    contact_seen = False

    def flush_paragraph() -> None:
        nonlocal paragraph_buffer
        if paragraph_buffer:
            paragraph = " ".join(normalize_text(part) for part in paragraph_buffer)
            if paragraph:
                story.append(Paragraph(inline_markup(paragraph), styles["body"]))
            paragraph_buffer = []

    for raw_line in source_text.splitlines():
        line = raw_line.strip()
        if not line:
            flush_paragraph()
            continue
        if line == PAGE_BREAK_MARKER:
            flush_paragraph()
            story.append(PageBreak())
            continue
        if line.startswith("# "):
            flush_paragraph()
            story.append(Paragraph(inline_markup(line[2:]), styles["title"]))
            title_seen = True
            continue
        if line.startswith("## "):
            flush_paragraph()
            story.append(Paragraph(inline_markup(line[3:]), styles["section"]))
            continue
        if line.startswith("### "):
            flush_paragraph()
            story.append(Paragraph(inline_markup(line[4:]), styles["employer"]))
            continue
        if line.startswith("- "):
            flush_paragraph()
            story.append(Paragraph(inline_markup(line[2:]), styles["bullet"], bulletText="•"))
            continue
        if line.startswith("**") and line.endswith("**") and line.count("**") == 2:
            flush_paragraph()
            plain = line[2:-2]
            if title_seen and not subtitle_seen:
                story.append(Paragraph(inline_markup(plain), styles["subtitle"]))
                subtitle_seen = True
            else:
                story.append(Paragraph(inline_markup(plain), styles["role"]))
            continue
        if title_seen and subtitle_seen and not contact_seen and "timfox2025@tim.army" in line:
            flush_paragraph()
            story.append(Paragraph(inline_markup(line), styles["contact"]))
            contact_seen = True
            continue
        paragraph_buffer.append(line)

    flush_paragraph()
    destination.parent.mkdir(parents=True, exist_ok=True)
    doc.build(story, onFirstPage=draw_footer, onLaterPages=draw_footer)

    reader = PdfReader(str(destination))
    if len(reader.pages) != EXPECTED_PAGES:
        raise RuntimeError(f"Expected {EXPECTED_PAGES} pages, generated {len(reader.pages)} pages.")
    extracted = "\n".join((page.extract_text() or "") for page in reader.pages)
    required = (
        "TIM FOX",
        "PROFESSIONAL SUMMARY",
        "PROFESSIONAL EXPERIENCE",
        "UNITED STATES ARMY",
        "EDUCATION",
        "TECHNICAL LAB",
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
        default=Path("pdf/Tim-Fox-Resume.pdf"),
    )
    args = parser.parse_args()
    build_pdf(args.source, args.destination)


if __name__ == "__main__":
    main()

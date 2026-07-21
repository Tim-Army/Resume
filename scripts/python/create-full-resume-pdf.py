#!/usr/bin/env python3
"""Generate the three-page full resume PDF from the master Markdown source."""

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
RULE = colors.HexColor("#B8C6D9")
EXPECTED_PAGES = 3


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


def draw_footer(canvas: Canvas, doc: SimpleDocTemplate) -> None:
    canvas.saveState()
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.45)
    canvas.line(doc.leftMargin, 0.47 * inch, letter[0] - doc.rightMargin, 0.47 * inch)
    canvas.setFillColor(MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(doc.leftMargin, 0.29 * inch, "Tim Fox")
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
            leading=10.26,
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
        leftMargin=0.58 * inch,
        rightMargin=0.58 * inch,
        topMargin=0.40 * inch,
        bottomMargin=0.50 * inch,
        title="Tim Fox Full Resume",
        author="Tim Fox",
        subject="Principal Network Engineer | Infrastructure Engineering Supervisor | Multi-Vendor Enterprise and Defense Networks",
        creator="Tim-Fox-Resume three-page PDF generator",
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

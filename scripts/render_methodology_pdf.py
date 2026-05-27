"""Render the report and method Markdown files to PDF.

This project stores written papers as Markdown because Markdown is easy to
review in git. The final PDFs need a little more work because they must lay out
tables and figures cleanly. This script reads one of the project Markdown files,
converts the basic Markdown structures used by this project into ReportLab
objects, and saves the finished PDF.
"""

from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

from PIL import Image as PILImage
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    Image,
    KeepTogether,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DOCUMENTS = {
    "report": {
        "markdown": PROJECT_ROOT / "output" / "reports" / "bvlgari_review_analysis_report.md",
        "pdf": PROJECT_ROOT / "output" / "pdf" / "bvlgari_review_analysis_report.pdf",
        "footer": "TripAdvisor Review Analytics Report for Bvlgari Resort Bali",
    },
    "methods": {
        "markdown": PROJECT_ROOT / "output" / "reports" / "bvlgari_review_analysis_methods.md",
        "pdf": PROJECT_ROOT / "output" / "pdf" / "bvlgari_review_analysis_methods.pdf",
        "footer": "Methods: TripAdvisor Review Sentiment Analysis for Bvlgari Resort Bali",
    },
    "methods_id": {
        "markdown": PROJECT_ROOT / "output" / "reports" / "bvlgari_review_analysis_methods_id.md",
        "pdf": PROJECT_ROOT / "output" / "pdf" / "bvlgari_review_analysis_methods_id.pdf",
        "footer": "Metode: Analisis Sentimen Ulasan TripAdvisor untuk Bvlgari Resort Bali",
    },
}

PAGE_WIDTH, _PAGE_HEIGHT = letter
LEFT_MARGIN = RIGHT_MARGIN = TOP_MARGIN = BOTTOM_MARGIN = 0.62 * inch
USABLE_WIDTH = PAGE_WIDTH - LEFT_MARGIN - RIGHT_MARGIN


def build_styles():
    """Create the paragraph styles used throughout the PDF."""
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            "PaperTitle",
            parent=styles["Title"],
            fontName="Helvetica-Bold",
            fontSize=16,
            leading=19,
            alignment=TA_CENTER,
            spaceAfter=14,
            textColor=colors.HexColor("#1f2933"),
        )
    )
    styles.add(
        ParagraphStyle(
            "Heading2Custom",
            parent=styles["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=12.5,
            leading=15,
            spaceBefore=12,
            spaceAfter=6,
            textColor=colors.HexColor("#1f2933"),
        )
    )
    styles.add(
        ParagraphStyle(
            "Heading3Custom",
            parent=styles["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=10.5,
            leading=13,
            spaceBefore=9,
            spaceAfter=5,
            textColor=colors.HexColor("#334155"),
        )
    )
    styles.add(
        ParagraphStyle(
            "BodyCustom",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=8.8,
            leading=12.2,
            spaceAfter=6,
        )
    )
    styles.add(
        ParagraphStyle(
            "BulletCustom",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=8.6,
            leading=11.6,
            leftIndent=14,
            firstLineIndent=-8,
            spaceAfter=3,
        )
    )
    styles.add(
        ParagraphStyle(
            "FigureCaption",
            parent=styles["BodyText"],
            fontName="Helvetica-Oblique",
            fontSize=7.4,
            leading=9.2,
            alignment=TA_CENTER,
            textColor=colors.HexColor("#475569"),
            spaceBefore=3,
            spaceAfter=9,
        )
    )
    styles.add(
        ParagraphStyle(
            "SmallTable",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=6.2,
            leading=7.4,
            wordWrap="CJK",
        )
    )
    styles.add(
        ParagraphStyle(
            "TinyTable",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=5.6,
            leading=6.7,
            wordWrap="CJK",
        )
    )
    styles.add(
        ParagraphStyle(
            "HeaderTable",
            parent=styles["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=6.4,
            leading=7.6,
            wordWrap="CJK",
            textColor=colors.white,
        )
    )
    styles.add(
        ParagraphStyle(
            "TinyHeaderTable",
            parent=styles["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=5.7,
            leading=6.8,
            wordWrap="CJK",
            textColor=colors.white,
        )
    )
    styles.add(
        ParagraphStyle(
            "CodeBlock",
            parent=styles["Code"],
            fontName="Courier",
            fontSize=7.4,
            leading=9,
            backColor=colors.HexColor("#f6f8fa"),
            borderColor=colors.HexColor("#d0d7de"),
            borderWidth=0.4,
            borderPadding=5,
            spaceAfter=7,
        )
    )
    return styles


STYLES = build_styles()


def inline_markup(text: str) -> str:
    """Convert the small amount of inline Markdown used in the report."""
    escaped = html.escape(text.strip())
    escaped = re.sub(
        r"`([^`]+)`",
        lambda match: f'<font name="Courier">{match.group(1)}</font>',
        escaped,
    )
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)
    escaped = re.sub(r"\*([^*]+)\*", r"<i>\1</i>", escaped)
    return escaped


def split_table_row(line: str) -> list[str]:
    """Split one Markdown table row into cell strings."""
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def is_table_separator(line: str) -> bool:
    """Identify the Markdown row made of dashes between header and body."""
    return all(
        re.fullmatch(r":?-{3,}:?", cell.strip())
        for cell in split_table_row(line)
    )


def table_widths(column_count: int, header: list[str]) -> list[float]:
    """Choose readable column widths for the table shapes used in the paper."""
    if column_count == 9 and "year" in header[0].lower():
        return [
            0.46 * inch,
            0.48 * inch,
            2.75 * inch,
            0.52 * inch,
            0.29 * inch,
            0.29 * inch,
            0.29 * inch,
            0.29 * inch,
            0.29 * inch,
        ]
    if column_count == 6 and header[0].lower() == "aspect":
        return [1.1 * inch, 0.78 * inch, 0.7 * inch, 0.62 * inch, 0.62 * inch, 1.18 * inch]
    if column_count == 5:
        return [1.15 * inch, 1.0 * inch, 1.0 * inch, 1.0 * inch, 1.0 * inch]
    if column_count == 4:
        return [1.15 * inch, 1.45 * inch, 1.95 * inch, 1.95 * inch]
    if column_count == 3:
        return [1.28 * inch, 2.1 * inch, USABLE_WIDTH - 3.38 * inch]
    if column_count == 2:
        return [2.05 * inch, USABLE_WIDTH - 2.05 * inch]
    return [USABLE_WIDTH / column_count] * column_count


def make_table(lines: list[str]) -> list:
    """Convert a Markdown table into a ReportLab table."""
    rows = [split_table_row(line) for line in lines if not is_table_separator(line)]
    if not rows:
        return []

    column_count = max(len(row) for row in rows)
    rows = [row + [""] * (column_count - len(row)) for row in rows]
    use_tiny_text = column_count >= 6 or len(rows) > 12
    body_style = STYLES["TinyTable"] if use_tiny_text else STYLES["SmallTable"]
    header_style = STYLES["TinyHeaderTable"] if use_tiny_text else STYLES["HeaderTable"]

    table_data = []
    for row_index, row in enumerate(rows):
        cell_style = header_style if row_index == 0 else body_style
        table_data.append([Paragraph(inline_markup(cell), cell_style) for cell in row])

    widths = table_widths(column_count, rows[0])
    total_width = sum(widths)
    if total_width > USABLE_WIDTH:
        widths = [width * USABLE_WIDTH / total_width for width in widths]

    table = Table(table_data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#334155")),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#cbd5e1")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 3),
                ("RIGHTPADDING", (0, 0), (-1, -1), 3),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                (
                    "ROWBACKGROUNDS",
                    (0, 1),
                    (-1, -1),
                    [colors.white, colors.HexColor("#f8fafc")],
                ),
            ]
        )
    )
    return [table, Spacer(1, 7)]


def resolve_image_path(markdown_image_path: str, markdown_path: Path) -> Path:
    """Resolve an image path written relative to the Markdown file."""
    candidate = markdown_path.parent / markdown_image_path
    if candidate.exists():
        return candidate.resolve()

    candidate = PROJECT_ROOT / markdown_image_path
    if candidate.exists():
        return candidate.resolve()

    raise FileNotFoundError(f"Could not find image referenced by Markdown: {markdown_image_path}")


def make_figure(line: str, markdown_path: Path) -> list:
    """Convert one Markdown image line into a scaled image plus caption."""
    match = re.fullmatch(r"!\[(.*?)\]\((.*?)\)", line.strip())
    if match is None:
        return []

    caption, image_path = match.groups()
    resolved = resolve_image_path(image_path, markdown_path)
    with PILImage.open(resolved) as image_file:
        pixel_width, pixel_height = image_file.size

    # Keep charts wide enough to read, but short enough that a caption and some
    # surrounding text still fit comfortably on a page.
    max_width = USABLE_WIDTH
    max_height = 4.65 * inch
    scale = min(max_width / pixel_width, max_height / pixel_height)
    draw_width = pixel_width * scale
    draw_height = pixel_height * scale

    figure = Image(str(resolved), width=draw_width, height=draw_height, hAlign="CENTER")
    caption_paragraph = Paragraph(inline_markup(caption), STYLES["FigureCaption"])
    return [KeepTogether([figure, caption_paragraph])]


def markdown_to_story(markdown_text: str, markdown_path: Path) -> list:
    """Turn the limited Markdown used by this report into PDF flowables."""
    story = []
    lines = markdown_text.splitlines()
    index = 0
    in_code_block = False
    code_lines: list[str] = []

    while index < len(lines):
        line = lines[index]

        if line.strip().startswith("```"):
            if in_code_block:
                story.append(Preformatted("\n".join(code_lines), STYLES["CodeBlock"]))
                code_lines = []
                in_code_block = False
            else:
                in_code_block = True
            index += 1
            continue

        if in_code_block:
            code_lines.append(line)
            index += 1
            continue

        if not line.strip():
            index += 1
            continue

        if line.strip().startswith("|"):
            table_lines = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                table_lines.append(lines[index])
                index += 1
            story.extend(make_table(table_lines))
            continue

        if line.strip().startswith("!["):
            story.extend(make_figure(line, markdown_path))
        elif line.startswith("# "):
            story.append(Paragraph(inline_markup(line[2:]), STYLES["PaperTitle"]))
        elif line.startswith("## "):
            story.append(Paragraph(inline_markup(line[3:]), STYLES["Heading2Custom"]))
        elif line.startswith("### "):
            story.append(Paragraph(inline_markup(line[4:]), STYLES["Heading3Custom"]))
        elif re.match(r"^\d+\.\s+", line):
            text = re.sub(r"^\d+\.\s+", "", line)
            story.append(Paragraph("&bull; " + inline_markup(text), STYLES["BulletCustom"]))
        elif line.startswith("- "):
            story.append(Paragraph("&bull; " + inline_markup(line[2:]), STYLES["BulletCustom"]))
        else:
            paragraph = line.strip()
            next_index = index + 1
            while (
                next_index < len(lines)
                and lines[next_index].strip()
                and not lines[next_index].startswith(("#", "|", "- "))
                and not re.match(r"^\d+\.\s+", lines[next_index])
                and not lines[next_index].strip().startswith("```")
                and not lines[next_index].strip().startswith("![")
            ):
                paragraph += " " + lines[next_index].strip()
                next_index += 1
            story.append(Paragraph(inline_markup(paragraph), STYLES["BodyCustom"]))
            index = next_index - 1

        index += 1

    return story


def add_footer_factory(footer_text: str):
    """Create a footer function with the document-specific title text."""

    def add_footer(canvas, document) -> None:
        """Add a simple footer to every page."""
        canvas.saveState()
        canvas.setFont("Helvetica", 7)
        canvas.setFillColor(colors.HexColor("#64748b"))
        canvas.drawString(LEFT_MARGIN, 0.36 * inch, footer_text)
        canvas.drawRightString(
            PAGE_WIDTH - RIGHT_MARGIN,
            0.36 * inch,
            f"Page {document.page}",
        )
        canvas.restoreState()

    return add_footer


def build_pdf(markdown_path: Path, pdf_path: Path, footer_text: str) -> None:
    """Build one PDF from one Markdown file."""
    pdf_path.parent.mkdir(parents=True, exist_ok=True)
    story = markdown_to_story(markdown_path.read_text(encoding="utf-8"), markdown_path)
    document = SimpleDocTemplate(
        str(pdf_path),
        pagesize=letter,
        rightMargin=RIGHT_MARGIN,
        leftMargin=LEFT_MARGIN,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
    )
    footer = add_footer_factory(footer_text)
    document.build(story, onFirstPage=footer, onLaterPages=footer)
    print(pdf_path)


def main() -> None:
    """Build the selected PDF file or all configured PDF files."""
    parser = argparse.ArgumentParser(
        description="Render project Markdown papers to PDF."
    )
    parser.add_argument(
        "document",
        nargs="?",
        choices=["all", "method", *DOCUMENTS.keys()],
        default="all",
        help="Which document to render. Defaults to all.",
    )
    args = parser.parse_args()

    selected = DOCUMENTS.keys() if args.document == "all" else [args.document]
    for name in selected:
        if name == "method":
            name = "methods"
        config = DOCUMENTS[name]
        build_pdf(config["markdown"], config["pdf"], config["footer"])


if __name__ == "__main__":
    main()

"""
PDF generation pipeline for exam papers, DPPs, and chapter tests.

Two output variants per paper (point #6 and #9):
  - "screen" version: normal-size, comfortable for reading before print
  - "print" version: tighter margins/line-height, smaller images, fewer
    pages, used for the max-3-downloads-a-day feature

Both use the same two-column template; JEE Advanced always renders as a
single column per the spec.
"""
from django.template.loader import render_to_string
from django.core.files.base import ContentFile
from weasyprint import HTML

from apps.exams.models import ExamPaper, ExamPaperQuestion
from .latex_render import render_mixed_body


def _header_title_for(paper: ExamPaper) -> tuple[str, str]:
    """Returns (bold_header_title, subheading) per point #6's rules:
    DPP -> 'DAILY PRACTICE SHEET' / class
    JEE Adv -> 'JEE ADVANCED' / paper no
    Chapter module -> chapter+module name / module no
    """
    mapping = {
        'DPP': ('DAILY PRACTICE SHEET', f'Class {paper.class_level}'),
        'CHAPTER_TEST': (paper.title.upper(), f'Class {paper.class_level}'),
        'PYQ': (paper.title.upper(), f'{paper.exam_style.replace("_", " ")}'),
        'PAIC': ('PREMIUM ALL INDIA CONTEST', paper.title),
        'BAIC': ('BIWEEKLY ALL INDIA CONTEST', paper.title),
        'WEEKLY_PERSONAL': ('PERSONALISED WEEKLY TEST', paper.title),
        'MOCK_FULL': (paper.title.upper(), paper.exam_style.replace('_', ' ')),
    }
    return mapping.get(paper.paper_type, (paper.title.upper(), ''))


def _build_categories_context(paper: ExamPaper, with_solutions: bool):
    """Groups the paper's questions by QuestionCategory in order, computing
    a running display number and rendering each body/options through the
    LaTeX-aware renderer."""
    pq_qs = (
        ExamPaperQuestion.objects
        .filter(paper=paper)
        .select_related('question', 'question__category')
        .order_by('order')
    )

    latex_fontsize = 18  # point #6: LaTeX rendered larger than body text

    categories = {}
    order_index = {}
    running_number = 1

    for pq in pq_qs:
        q = pq.question
        cat = q.category
        if cat.id not in categories:
            categories[cat.id] = {
                'name': cat.name,
                'instructions_text': cat.instructions_text,
                'questions': [],
            }
            order_index[cat.id] = len(categories)

        options = []
        for i, opt in enumerate(q.options or []):
            options.append({
                'label': chr(65 + i),
                'rendered_text': render_mixed_body(opt.get('text', ''), latex_fontsize),
                'is_correct': opt.get('is_correct', False) if with_solutions else None,
            })

        categories[cat.id]['questions'].append({
            'display_number': running_number,
            'question_type': cat.question_type,
            'rendered_body': render_mixed_body(q.body, latex_fontsize),
            'image_url': q.image.url if q.image else None,
            'options': options,
            'solution_html': render_mixed_body(q.solution_text, latex_fontsize) if with_solutions else None,
            'solution_image_url': (q.solution_image.url if with_solutions and q.solution_image else None),
        })
        running_number += 1

    return sorted(categories.values(), key=lambda c: order_index[id(c)] if False else 0) or list(categories.values())


def render_paper_pdf(paper: ExamPaper, variant: str = 'screen', with_solutions: bool = False) -> bytes:
    """Renders the given paper to PDF bytes. variant: 'screen' | 'print'."""
    title, subtitle = _header_title_for(paper)
    is_single_column = paper.exam_style == 'JEE_ADV'

    base_font_size = 11 if variant == 'screen' else 9.5
    latex_font_size = 15 if variant == 'screen' else 12

    context = {
        'header_title': title,
        'header_subtitle': subtitle,
        'footer_text': f'{paper.title} — {"Solutions" if with_solutions else "Question Paper"}',
        'column_count': 1 if is_single_column else 2,
        'base_font_size': base_font_size,
        'latex_font_size': latex_font_size,
        'categories': _build_categories_context(paper, with_solutions),
    }

    html_string = render_to_string('pdfgen/exam_paper.html', context)
    pdf_bytes = HTML(string=html_string).write_pdf()
    return pdf_bytes


def generate_and_store_paper_pdfs(paper: ExamPaper):
    """Generates the question paper PDF (print-optimized, for the downloadable
    variant used by point #9) and a separate solution PDF, then saves both
    to the paper's FileFields — which upload to Backblaze B2 automatically
    via the configured S3Storage backend."""
    question_pdf = render_paper_pdf(paper, variant='print', with_solutions=False)
    paper.question_paper_pdf.save(
        f'paper_{paper.id}_questions.pdf', ContentFile(question_pdf), save=False
    )

    solution_pdf = render_paper_pdf(paper, variant='screen', with_solutions=True)
    paper.solution_pdf.save(
        f'paper_{paper.id}_solutions.pdf', ContentFile(solution_pdf), save=False
    )

    paper.save(update_fields=['question_paper_pdf', 'solution_pdf'])
    return paper

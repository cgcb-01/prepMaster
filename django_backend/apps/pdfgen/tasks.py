from celery import shared_task
from django.utils import timezone
from django.core.exceptions import PermissionDenied

from apps.exams.models import ExamPaper, DownloadLog
from .services import generate_and_store_paper_pdfs, render_paper_pdf


@shared_task
def generate_paper_pdfs_task(paper_id: int):
    """Run PDF generation off the request/response cycle — admin triggers
    this after publishing/editing a paper (point #19: admin can update
    question/solution content and PDFs regenerate)."""
    paper = ExamPaper.objects.get(id=paper_id)
    generate_and_store_paper_pdfs(paper)
    return paper.id


def request_download(user, paper: ExamPaper) -> bytes:
    """
    Enforces point #9 (max 3 downloads/day) and point #5/12 (no downloading
    a currently-running AIC/PAIC). Returns the print-optimized PDF bytes,
    or raises PermissionDenied.
    """
    if not paper.is_downloadable:
        raise PermissionDenied("This paper is not available for download.")

    if paper.paper_type in ('PAIC', 'BAIC') and paper.is_currently_running:
        raise PermissionDenied("Cannot download while the contest is live.")

    today = timezone.now().date()
    todays_downloads = DownloadLog.objects.filter(user=user, downloaded_at__date=today).count()
    if todays_downloads >= 3:
        raise PermissionDenied("Daily download limit (3) reached.")

    DownloadLog.objects.create(user=user, paper=paper)

    if paper.question_paper_pdf:
        return paper.question_paper_pdf.read()
    # Fallback: render on the fly if not pre-generated yet
    return render_paper_pdf(paper, variant='print', with_solutions=False)

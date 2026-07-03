"""
Admin authoring interface (point #19/#20/#22). Rather than building a
separate custom UI, we lean on Django admin — heavily customized — since
it's the fastest way to give staff a reliable question/paper editor with
inline previews. A Flutter admin UI (screens/admin/) can call the same
models via a thin DRF layer later if a native mobile authoring flow is
needed; this file is the source of truth for authoring UX in the meantime.
"""
from django.contrib import admin
from django.utils.html import format_html

from apps.content.models import Subject, Chapter, Module, QuestionCategory, Question
from apps.exams.models import ExamPaper, ExamPaperQuestion, DownloadLog


@admin.register(Subject)
class SubjectAdmin(admin.ModelAdmin):
    list_display = ['name', 'exam']
    list_filter = ['exam']


class ModuleInline(admin.TabularInline):
    model = Module
    extra = 1


@admin.register(Chapter)
class ChapterAdmin(admin.ModelAdmin):
    list_display = ['name', 'subject', 'class_level', 'difficulty', 'order']
    list_filter = ['subject__exam', 'class_level', 'difficulty']
    search_fields = ['name']
    inlines = [ModuleInline]
    ordering = ['subject', 'order']


@admin.register(QuestionCategory)
class QuestionCategoryAdmin(admin.ModelAdmin):
    """Point #22: admin defines marking scheme per category, reused across
    every paper that includes questions from it (with optional per-paper
    overrides via ExamPaperQuestion)."""
    list_display = ['name', 'exam', 'question_type', 'marks_correct', 'marks_incorrect', 'marks_partial']
    list_filter = ['exam', 'question_type']


@admin.register(Question)
class QuestionAdmin(admin.ModelAdmin):
    """
    Point #20: every question supports mixed text/LaTeX/image, editable at
    any time. `body_preview` renders a quick approximation inline so staff
    can sanity-check LaTeX without generating a full PDF.
    """
    list_display = ['id', 'subject', 'chapter', 'category', 'short_body', 'year', 'updated_at']
    list_filter = ['subject', 'category', 'year']
    search_fields = ['body']
    readonly_fields = ['body_preview', 'created_at', 'updated_at']
    fieldsets = (
        (None, {'fields': ('subject', 'chapter', 'category')}),
        ('Question Content', {'fields': ('body', 'body_preview', 'image', 'options')}),
        ('Answer / Solution', {'fields': ('numerical_answer', 'solution_text', 'solution_image')}),
        ('PYQ Metadata', {'fields': ('year', 'exam_shift')}),
        ('Meta', {'fields': ('created_by', 'created_at', 'updated_at')}),
    )

    def short_body(self, obj):
        return (obj.body[:60] + '…') if len(obj.body) > 60 else obj.body

    def body_preview(self, obj):
        """Renders the mixed text/LaTeX body as an inline preview image
        using the same renderer the PDF pipeline uses, so what staff see
        here matches the eventual paper output."""
        if not obj.body:
            return '(nothing to preview yet — save the question first)'
        from apps.pdfgen.latex_render import render_mixed_body
        html = render_mixed_body(obj.body, latex_fontsize=14)
        return format_html('<div style="border:1px solid #ccc;padding:10px;max-width:500px">{}</div>', html)
    body_preview.short_description = 'Rendered preview'


class ExamPaperQuestionInline(admin.TabularInline):
    """The paper-builder UI: admin drags questions into a paper, sets order
    and optional per-question marking overrides (point #19/22)."""
    model = ExamPaperQuestion
    extra = 1
    autocomplete_fields = ['question']
    ordering = ['order']


@admin.register(ExamPaper)
class ExamPaperAdmin(admin.ModelAdmin):
    list_display = [
        'title', 'paper_type', 'exam_style', 'class_level', 'is_premium',
        'is_live_contest', 'scheduled_start', 'scheduled_end',
    ]
    list_filter = ['paper_type', 'exam_style', 'class_level', 'is_premium', 'is_live_contest']
    search_fields = ['title']
    inlines = [ExamPaperQuestionInline]
    readonly_fields = ['question_paper_pdf', 'solution_pdf']
    actions = ['generate_pdfs']

    def generate_pdfs(self, request, queryset):
        from apps.pdfgen.tasks import generate_paper_pdfs_task
        for paper in queryset:
            generate_paper_pdfs_task.delay(paper.id)
        self.message_user(request, f"Queued PDF generation for {queryset.count()} paper(s).")
    generate_pdfs.short_description = "Generate question paper + solution PDFs"


@admin.register(DownloadLog)
class DownloadLogAdmin(admin.ModelAdmin):
    list_display = ['user', 'paper', 'downloaded_at']
    list_filter = ['downloaded_at']
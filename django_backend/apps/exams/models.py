from django.db import models


class ExamPaper(models.Model):
    """Covers DPP, Chapter Test, PAIC, BAIC, PYQ sets, and the weekly
    personalized test — one flexible model, admin-configured per point #12/19."""
    PAPER_TYPES = [
        ('DPP', 'Daily Practice Sheet'),
        ('CHAPTER_TEST', 'Chapterwise Test'),
        ('PYQ', 'Past Year Question Set'),
        ('PAIC', 'Premium All India Contest'),
        ('BAIC', 'Biweekly All India Contest'),
        ('WEEKLY_PERSONAL', 'Personalized Weekly Test'),
        ('MOCK_FULL', 'Full Mock Test'),
    ]
    EXAM_STYLE = [('JEE_MAIN', 'JEE Main'), ('JEE_ADV', 'JEE Advanced'), ('NEET', 'NEET')]

    title = models.CharField(max_length=200)
    paper_type = models.CharField(max_length=20, choices=PAPER_TYPES)
    exam_style = models.CharField(max_length=10, choices=EXAM_STYLE)
    class_level = models.CharField(max_length=4, choices=[('11', '11'), ('12', '12'), ('DROP', 'Dropper')])

    questions = models.ManyToManyField('content.Question', through='ExamPaperQuestion')

    duration_minutes = models.PositiveIntegerField(default=180)
    total_marks = models.PositiveIntegerField(default=300)
    is_premium = models.BooleanField(default=False)
    is_downloadable = models.BooleanField(default=True)

    scheduled_start = models.DateTimeField(null=True, blank=True)  # for PAIC/BAIC live windows
    scheduled_end = models.DateTimeField(null=True, blank=True)
    is_live_contest = models.BooleanField(default=False)

    # Generated, print-optimized PDF + solution PDF, stored on Backblaze B2
    question_paper_pdf = models.FileField(upload_to='papers/', null=True, blank=True)
    solution_pdf = models.FileField(upload_to='solutions/', null=True, blank=True)

    created_by = models.ForeignKey('users.User', on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @property
    def is_currently_running(self):
        if not (self.scheduled_start and self.scheduled_end):
            return False
        from django.utils import timezone
        now = timezone.now()
        return self.scheduled_start <= now <= self.scheduled_end


class ExamPaperQuestion(models.Model):
    """Through-table: preserves question order + per-question marks override
    within a specific paper (marking can differ paper to paper, point #22)."""
    paper = models.ForeignKey(ExamPaper, on_delete=models.CASCADE)
    question = models.ForeignKey('content.Question', on_delete=models.CASCADE)
    order = models.PositiveIntegerField()
    marks_correct_override = models.FloatField(null=True, blank=True)
    marks_incorrect_override = models.FloatField(null=True, blank=True)

    class Meta:
        ordering = ['order']
        unique_together = ('paper', 'order')


class DownloadLog(models.Model):
    """Enforces point #9: max 3 downloads/day per user."""
    user = models.ForeignKey('users.User', on_delete=models.CASCADE)
    paper = models.ForeignKey(ExamPaper, on_delete=models.CASCADE)
    downloaded_at = models.DateTimeField(auto_now_add=True)
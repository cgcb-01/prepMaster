from django.db import models


class Announcement(models.Model):
    """Backs the Home screen feed (point #3): contest schedule/date-change
    posts, result/solution releases, and topper lists. Posted by admins via
    the /api/news/ or Django admin; the ExamPaper it's about is optional
    (some announcements, e.g. topper lists, are informational only)."""
    CATEGORY_CHOICES = [
        ('CONTEST', 'Upcoming Contest'),
        ('DATE_CHANGE', 'Contest Date Change'),
        ('RESULT', 'Result / Solution Released'),
        ('TOPPER', 'Topper Announcement'),
        ('GENERAL', 'General'),
    ]
    title = models.CharField(max_length=255)
    body = models.TextField(blank=True)
    exam_type = models.CharField(max_length=15, choices=CATEGORY_CHOICES, default='GENERAL')
    related_paper = models.ForeignKey('exams.ExamPaper', null=True, blank=True, on_delete=models.SET_NULL)
    created_by = models.ForeignKey('users.User', on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class Subject(models.Model):
    name = models.CharField(max_length=50)  # Physics, Chemistry, Mathematics, Biology
    exam = models.CharField(max_length=4, choices=[('JEE', 'JEE'), ('NEET', 'NEET')])

    class Meta:
        unique_together = ('name', 'exam')

    def __str__(self):
        return f"{self.name} ({self.exam})"


class Chapter(models.Model):
    subject = models.ForeignKey(Subject, related_name='chapters', on_delete=models.CASCADE)
    name = models.CharField(max_length=150)
    order = models.PositiveIntegerField(default=0)
    class_level = models.CharField(max_length=4, choices=[('11', '11'), ('12', '12'), ('DROP', 'Dropper')])
    difficulty = models.CharField(
        max_length=10,
        choices=[('EASY', 'Easy'), ('MEDIUM', 'Medium'), ('HARD', 'Hard')],
        default='MEDIUM',
    )
    estimated_hours = models.FloatField(default=4.0)

    class Meta:
        ordering = ['order']


class Module(models.Model):
    """A chapter is broken into modules: Theory, Formula Sheet, DPP, PYQ,
    Chapter Test, Advanced Problems, etc. — admin-configurable per point #19/22."""
    MODULE_TYPES = [
        ('THEORY', 'Theory'), ('FORMULA', 'Formula Sheet'),
        ('SOLVED', 'Solved Examples'), ('DPP', 'DPP'), ('PYQ', 'PYQ'),
        ('REVISION', 'Revision Notes'), ('TEST', 'Chapter Test'),
        ('ADVANCED', 'Advanced Problems'),
    ]
    chapter = models.ForeignKey(Chapter, related_name='modules', on_delete=models.CASCADE)
    module_type = models.CharField(max_length=10, choices=MODULE_TYPES)
    title = models.CharField(max_length=150)
    order = models.PositiveIntegerField(default=0)
    is_premium = models.BooleanField(default=False)  # point #18: admin decides premium status
    linked_paper = models.ForeignKey(
        'exams.ExamPaper', null=True, blank=True, on_delete=models.SET_NULL,
        help_text="The test/DPP/etc. that represents 'completing' this module. "
                  "Used by the To-Do feature to detect when a linked task is done.",
    )

    class Meta:
        ordering = ['order']


class QuestionCategory(models.Model):
    """Admin-defined category controlling marking scheme per point #20/22:
    e.g. MCQ Single Correct (+4/-1), Multiple Correct (+4/0/-2),
    Numerical (+4/0), Match the Column (+3/-1), Assertion-Reason, etc."""
    name = models.CharField(max_length=100)
    exam = models.CharField(max_length=4, choices=[('JEE', 'JEE'), ('NEET', 'NEET')])
    question_type = models.CharField(max_length=20, choices=[
        ('MCQ_SINGLE', 'MCQ Single Correct'),
        ('MCQ_MULTIPLE', 'MCQ Multiple Correct'),
        ('NUMERICAL', 'Numerical/Integer'),
        ('MATCH_COLUMN', 'Match the Column'),
        ('ASSERTION_REASON', 'Assertion & Reason'),
    ])
    marks_correct = models.FloatField(default=4)
    marks_incorrect = models.FloatField(default=-1)
    marks_partial = models.FloatField(default=0)  # for multi-correct partial marking
    instructions_text = models.TextField(
        blank=True,
        help_text="Auto-prepended before this category's questions begin in generated PDFs.",
    )


class Question(models.Model):
    """A question body can mix plain text, LaTeX, and images simultaneously
    (point #20). `body` stores markdown-like text where LaTeX is wrapped in
    $...$ / $$...$$ and rendered by flutter_math_fork on the client."""
    subject = models.ForeignKey(Subject, on_delete=models.PROTECT)
    chapter = models.ForeignKey(Chapter, on_delete=models.PROTECT, null=True, blank=True)
    category = models.ForeignKey(QuestionCategory, on_delete=models.PROTECT)

    body = models.TextField()
    image = models.ImageField(upload_to='questions/', null=True, blank=True)  # -> B2

    # Options stored as JSON: [{"text": "...", "image": null, "is_correct": true}, ...]
    options = models.JSONField(default=list, blank=True)
    numerical_answer = models.FloatField(null=True, blank=True)
    solution_text = models.TextField(blank=True)
    solution_image = models.ImageField(upload_to='solutions/', null=True, blank=True)

    year = models.PositiveIntegerField(null=True, blank=True)   # for PYQs
    exam_shift = models.CharField(max_length=50, blank=True)    # e.g. "JEE Main 2023 Shift 1"

    created_by = models.ForeignKey('users.User', on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

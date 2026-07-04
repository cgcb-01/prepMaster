from django.db import models


class Attempt(models.Model):
    STATUS = [('IN_PROGRESS', 'In Progress'), ('SUBMITTED', 'Submitted'), ('AUTO_SUBMITTED', 'Auto Submitted')]

    user = models.ForeignKey('users.User', related_name='attempts', on_delete=models.CASCADE)
    paper = models.ForeignKey('exams.ExamPaper', related_name='attempts', on_delete=models.CASCADE)
    started_at = models.DateTimeField(auto_now_add=True)
    submitted_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=15, choices=STATUS, default='IN_PROGRESS')
    is_offline_attempt = models.BooleanField(default=False)  # My Library offline mode

    total_score = models.FloatField(null=True, blank=True)
    accuracy_percent = models.FloatField(null=True, blank=True)
    rank_in_paper = models.PositiveIntegerField(null=True, blank=True)  # for PAIC/BAIC leaderboard

    proctoring_enabled = models.BooleanField(default=False)
    proctoring_flag_count = models.PositiveIntegerField(default=0)  # multiple faces / no face detected

    class Meta:
        indexes = [models.Index(fields=['user', 'paper'])]


class Answer(models.Model):
    STATUS = [
        ('NOT_VISITED', 'Not Visited'), ('NOT_ANSWERED', 'Not Answered'),
        ('ANSWERED', 'Answered'), ('MARKED', 'Marked for Review'),
        ('ANSWERED_MARKED', 'Answered & Marked'),
    ]
    attempt = models.ForeignKey(Attempt, related_name='answers', on_delete=models.CASCADE)
    question = models.ForeignKey('content.Question', on_delete=models.CASCADE)

    selected_options = models.JSONField(default=list, blank=True)  # supports multi-correct
    numerical_response = models.FloatField(null=True, blank=True)
    omr_bubble = models.CharField(max_length=1, blank=True)  # 'A'/'B'/'C'/'D' for NEET OMR mode

    status = models.CharField(max_length=16, choices=STATUS, default='NOT_VISITED')
    is_correct = models.BooleanField(null=True)
    marks_awarded = models.FloatField(default=0)
    is_marked_for_personal_review = models.BooleanField(default=False)  # feeds weekly test generator

    time_spent_seconds = models.PositiveIntegerField(default=0)

    class Meta:
        unique_together = ('attempt', 'question')


class DailyActivity(models.Model):
    """One row per user per day — powers streaks, heatmap, and the DPP
    attempted/missed calendar markers."""
    user = models.ForeignKey('users.User', related_name='daily_activity', on_delete=models.CASCADE)
    date = models.DateField()
    submissions_count = models.PositiveIntegerField(default=0)
    dpp_attempted = models.BooleanField(default=False)

    class Meta:
        unique_together = ('user', 'date')
        indexes = [models.Index(fields=['user', 'date'])]

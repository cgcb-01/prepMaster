from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """Extends Django's auth user with exam-platform profile fields."""

    CLASS_CHOICES = [('11', 'Class 11'), ('12', 'Class 12'), ('DROP', 'Dropper')]
    EXAM_CHOICES = [('JEE', 'JEE'), ('NEET', 'NEET'), ('BOTH', 'Both')]

    roll_no = models.CharField(max_length=20, unique=True, editable=False)  # app-generated
    photo = models.ImageField(upload_to='profile_photos/', null=True, blank=True)  # -> B2
    school_name = models.CharField(max_length=255, blank=True)
    state = models.CharField(max_length=100, blank=True)
    country = models.CharField(max_length=100, default='India')
    student_class = models.CharField(max_length=4, choices=CLASS_CHOICES, default='12')
    target_exam = models.CharField(max_length=4, choices=EXAM_CHOICES, default='BOTH')

    is_premium = models.BooleanField(default=False)
    premium_expires_at = models.DateTimeField(null=True, blank=True)

    last_seen_at = models.DateTimeField(null=True, blank=True)
    registered_at = models.DateTimeField(auto_now_add=True)

    # Denormalized counters, updated by signals/celery tasks for fast dashboard reads
    current_streak_days = models.PositiveIntegerField(default=0)
    max_streak_days = models.PositiveIntegerField(default=0)
    max_submissions_in_a_day = models.PositiveIntegerField(default=0)

    def save(self, *args, **kwargs):
        if not self.roll_no:
            self.roll_no = self._generate_roll_no()
        super().save(*args, **kwargs)

    def _generate_roll_no(self):
        from django.utils.crypto import get_random_string
        return f"PM{get_random_string(7, allowed_chars='0123456789')}"

    @property
    def is_online(self):
        if not self.last_seen_at:
            return False
        from django.utils import timezone
        return (timezone.now() - self.last_seen_at).total_seconds() < 300


class Friendship(models.Model):
    STATUS = [('PENDING', 'Pending'), ('ACCEPTED', 'Accepted')]
    from_user = models.ForeignKey(User, related_name='sent_requests', on_delete=models.CASCADE)
    to_user = models.ForeignKey(User, related_name='received_requests', on_delete=models.CASCADE)
    status = models.CharField(max_length=10, choices=STATUS, default='PENDING')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('from_user', 'to_user')


class WeakArea(models.Model):
    """Private per-user weak subject/chapter tracking, feeds the weekly
    personalized test generator (see apps.exams.tasks.generate_weekly_test)."""
    user = models.ForeignKey(User, related_name='weak_areas', on_delete=models.CASCADE)
    chapter = models.ForeignKey('content.Chapter', on_delete=models.CASCADE)
    mistake_count = models.PositiveIntegerField(default=0)
    last_updated = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'chapter')
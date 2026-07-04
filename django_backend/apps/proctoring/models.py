from django.db import models


class ProctoringSession(models.Model):
    """One row per attempt where the optional proctoring toggle was on
    (point #8: 'just checks no outside people, only that user sitting and
    no one else, that's all it must check')."""
    attempt = models.OneToOneField('submissions.Attempt', related_name='proctoring_session', on_delete=models.CASCADE)
    started_at = models.DateTimeField(auto_now_add=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    total_flags = models.PositiveIntegerField(default=0)


class ProctoringFlag(models.Model):
    FLAG_TYPES = [
        ('NO_FACE', 'No face detected'),
        ('MULTIPLE_FACES', 'Multiple faces detected'),
        ('FACE_MISMATCH', 'Face does not match registered profile photo'),
        ('AUDIO_VOICE', 'Additional voice detected'),
        ('TAB_SWITCH', 'App switched to background'),
    ]
    session = models.ForeignKey(ProctoringSession, related_name='flags', on_delete=models.CASCADE)
    flag_type = models.CharField(max_length=20, choices=FLAG_TYPES)
    # Thumbnail evidence snapshot, stored on Backblaze B2, auto-deleted after
    # a retention window via a scheduled cleanup task — never a full recording.
    snapshot = models.ImageField(upload_to='proctoring_flags/', null=True, blank=True)
    timestamp_in_exam_seconds = models.PositiveIntegerField()
    created_at = models.DateTimeField(auto_now_add=True)

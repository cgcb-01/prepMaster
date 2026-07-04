from django.db import models


class LibraryItem(models.Model):
    """Record of a paper a user has downloaded into 'My Library'. The actual
    PDF bytes are cached client-side (Hive/local storage on Flutter) after
    being fetched once from Backblaze B2; this row is the source of truth
    for entitlement (e.g. revoke access when premium expires — point #23)."""
    user = models.ForeignKey('users.User', related_name='library_items', on_delete=models.CASCADE)
    paper = models.ForeignKey('exams.ExamPaper', on_delete=models.CASCADE)
    downloaded_at = models.DateTimeField(auto_now_add=True)
    was_premium_at_download = models.BooleanField(default=False)
    still_accessible = models.BooleanField(default=True)  # flipped False when premium lapses

    class Meta:
        unique_together = ('user', 'paper')

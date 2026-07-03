from django.db import models


class ContestLeaderboardEntry(models.Model):
    """Materialized leaderboard row per (paper, user), recomputed on every
    submission during a live PAIC/BAIC and finalized once the contest ends
    and solutions release (point #16)."""
    paper = models.ForeignKey('exams.ExamPaper', related_name='leaderboard_entries', on_delete=models.CASCADE)
    user = models.ForeignKey('users.User', on_delete=models.CASCADE)
    attempt = models.OneToOneField('submissions.Attempt', on_delete=models.CASCADE)

    score = models.FloatField(default=0)
    accuracy = models.FloatField(default=0)
    time_taken_seconds = models.PositiveIntegerField(default=0)
    rank = models.PositiveIntegerField(null=True, blank=True)
    is_finalized = models.BooleanField(default=False)  # True once contest ends + solutions released

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('paper', 'user')
        ordering = ['-score', 'time_taken_seconds']
        indexes = [models.Index(fields=['paper', 'rank'])]


def compute_rank_order_key(entry: ContestLeaderboardEntry):
    """
    JEE/NEET-style tie-break rule (point #16):
    1. Higher score wins.
    2. On tie: higher accuracy (fewer wrong attempts relative to attempted) wins.
    3. On tie: less total time taken wins.
    (Exact NTA tie-break for negative-marked exams also considers
    attempted-vs-correct ratios per subject; extend here if needed.)
    """
    return (-entry.score, -entry.accuracy, entry.time_taken_seconds)


def recompute_ranks(paper_id: int):
    entries = list(ContestLeaderboardEntry.objects.filter(paper_id=paper_id))
    entries.sort(key=compute_rank_order_key)
    for i, entry in enumerate(entries, start=1):
        entry.rank = i
    ContestLeaderboardEntry.objects.bulk_update(entries, ['rank'])
    return entries
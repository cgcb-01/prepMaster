from django.db import models


class RatingHistory(models.Model):
    """One entry per rated event (PAIC/BAIC result, or periodic DPP/chapter
    performance recalculation). Powers the Codeforces-style rating graph."""
    user = models.ForeignKey('users.User', related_name='rating_history', on_delete=models.CASCADE)
    paper = models.ForeignKey('exams.ExamPaper', null=True, blank=True, on_delete=models.SET_NULL)
    rating_before = models.IntegerField()
    rating_after = models.IntegerField()
    delta = models.IntegerField()
    reason = models.CharField(max_length=30, choices=[
        ('PAIC', 'PAIC Result'), ('BAIC', 'BAIC Result'),
        ('DPP_STREAK', 'DPP Streak'), ('CHAPTER_PERF', 'Chapterwise Performance'),
        ('TODO_MISS', 'To-Do Missed'), ('TODO_DONE', 'To-Do Completed'),
    ])
    created_at = models.DateTimeField(auto_now_add=True)


RATING_TITLES = [
    (0, 'Newcomer'), (1000, 'Pupil'), (1300, 'Specialist'), (1600, 'Expert'),
    (1900, 'Candidate Master'), (2100, 'Diamond Warrior'), (2400, 'Master'), (2700, 'Grandmaster'),
]


def title_for_rating(rating: int) -> str:
    title = RATING_TITLES[0][1]
    for threshold, name in RATING_TITLES:
        if rating >= threshold:
            title = name
    return title


def compute_rating_delta(user, event_type: str, performance_ratio: float, weight: float) -> int:
    """
    Simplified, tunable rating engine implementing the priority order in
    point #17:
      1. Performance in PAIC/BAIC (highest weight)
      2. Performance vs. own previous attempts (accuracy trend)
      3. Performance vs. other users in the same window
      4. Daily sheet / chapterwise consistency (lowest weight)

    `performance_ratio`: -1.0 (much worse) .. +1.0 (much better) relative to
    the comparison baseline for this event_type.
    `weight`: per-event-type multiplier set by admin config (PAIC/BAIC >> DPP).
    Full formula intentionally kept server-side only (point #21: users see
    what it depends on and the priority order, not the exact formula).
    """
    BASE_SWING = 40
    return round(BASE_SWING * weight * performance_ratio)

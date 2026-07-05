"""
Server-side To-Do completion for module-linked tasks (point #15 as
clarified: "user adds a present module inside the to-do... when all
questions of that module are completed it's marked done by the server;
rating drops if the deadline passes first; rating also reflects
performance, not just completion").
"""
from django.utils import timezone
from .models import TodoItem


def check_and_complete_module_todos(attempt):
    """
    Called right after an Attempt is scored (apps.submissions.scoring).
    Finds any not-yet-completed, module-linked TodoItem for this user whose
    module's linked_paper is the paper just submitted, marks it complete,
    and applies a rating delta sized by how well they actually did
    (accuracy), not just a flat "showed up" bonus.
    """
    from apps.rating.models import RatingHistory, compute_rating_delta

    todos = TodoItem.objects.filter(
        user=attempt.user,
        module__linked_paper=attempt.paper,
        is_completed=False,
    )
    if not todos.exists():
        return

    accuracy = attempt.accuracy_percent or 0.0
    # Map 0-100% accuracy to a -0.5..+1.0 performance ratio: finishing with
    # low accuracy still completes the to-do (it was attempted before the
    # deadline) but earns less rating than a strong performance.
    performance_ratio = max(-0.5, min(1.0, (accuracy - 40) / 60))

    latest = RatingHistory.objects.filter(user=attempt.user).order_by('-created_at').first()
    rating_before = latest.rating_after if latest else 1000

    for todo in todos:
        delta = compute_rating_delta(
            attempt.user, 'TODO_DONE', performance_ratio=performance_ratio, weight=0.25,
        )
        RatingHistory.objects.create(
            user=attempt.user,
            rating_before=rating_before,
            rating_after=rating_before + delta,
            delta=delta,
            reason='TODO_DONE',
        )
        rating_before += delta  # so multiple todos completed by one attempt stack correctly

        todo.is_completed = True
        todo.completed_at = timezone.now()
        todo.rating_impact_applied = True
        todo.save(update_fields=['is_completed', 'completed_at', 'rating_impact_applied'])
